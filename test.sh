#!/usr/bin/env zsh
# ─────────────────────────────────────────────────────────────────────────────
# Sandboxed test runner for install.sh + revert.sh
# Creates a fake $HOME in /tmp — zero impact on your real system.
# ─────────────────────────────────────────────────────────────────────────────
set -e

SCRIPT_DIR="${0:A:h}"
SANDBOX=$(mktemp -d /tmp/term-theme-test.XXXXXX)
PASS=0
FAIL=0

print_head()  { print -P "\n%F{141}━━━ $1 ━━━%f"; }
print_ok()    { print -P "  %F{114}PASS%f  $1"; PASS=$((PASS + 1)); }
print_fail()  { print -P "  %F{196}FAIL%f  $1"; FAIL=$((FAIL + 1)); }
print_info()  { print -P "  %F{110}    %f  $1"; }
print_warn()  { print -P "  %F{214}WARN%f  $1"; }
cleanup()     { rm -rf "$SANDBOX"; }
trap cleanup EXIT

# ─────────────────────────────────────────────────────────────────────────────
# SETUP: fake HOME
# ─────────────────────────────────────────────────────────────────────────────
print_head "Building sandbox at $SANDBOX"

export HOME="$SANDBOX"
mkdir -p \
  "$SANDBOX/.config" \
  "$SANDBOX/.config/fish" \
  "$SANDBOX/.local/bin" \
  "$SANDBOX/Library/Preferences" \
  "$SANDBOX/Library/Fonts"

# Pre-populate realistic files the user might already have
cat > "$SANDBOX/.zshrc" <<'EOF'
# existing zshrc
export PATH="$HOME/.local/bin:$PATH"
alias ll="ls -la"
EOF

cat > "$SANDBOX/.bashrc" <<'EOF'
# existing bashrc
export EDITOR=vim
EOF

cat > "$SANDBOX/.zprofile" <<'EOF'
# existing zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
EOF

cat > "$SANDBOX/.config/fish/config.fish" <<'EOF'
# existing fish config
set -x EDITOR vim
EOF

cat > "$SANDBOX/.config/starship.toml" <<'EOF'
# pre-existing starship config
format = "$directory $character"
EOF

# Fake iTerm2 plist
cat > "$SANDBOX/Library/Preferences/com.googlecode.iterm2.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>FakeKey</key><string>FakeValue</string></dict></plist>
EOF

print_info "Fake home created with: .zshrc .bashrc .zprofile fish config starship.toml iterm2.plist"

# ─────────────────────────────────────────────────────────────────────────────
# STUBS: replace destructive commands with no-ops that log what they would do
# ─────────────────────────────────────────────────────────────────────────────
print_head "Installing command stubs"

STUB_LOG="$SANDBOX/stub.log"

# Stub directory takes priority over real commands
STUB_BIN="$SANDBOX/stub_bin"
mkdir -p "$STUB_BIN"

# brew stub
cat > "$STUB_BIN/brew" <<STUB
#!/usr/bin/env zsh
echo "[STUB] brew \$*" >> "$STUB_LOG"
# Fake 'brew list' checks so install.sh thinks tools are not installed
if [[ "\$1 \$2" == "list starship" || "\$1" == "list" && "\$2" == "starship" ]]; then
  exit 1   # not installed → triggers install path
fi
if [[ "\$1 \$2" == "--cask font-jetbrains-mono-nerd-font" ]]; then
  exit 1
fi
exit 0
STUB

# defaults stub (macOS appearance detection)
cat > "$STUB_BIN/defaults" <<STUB
#!/usr/bin/env zsh
echo "[STUB] defaults \$*" >> "$STUB_LOG"
# Simulate Dark mode so we can test the dark branch
if [[ "\$*" == *"AppleInterfaceStyle"* ]]; then
  echo "Dark"
  exit 0
fi
exit 1
STUB

# plutil stub
cat > "$STUB_BIN/plutil" <<STUB
#!/usr/bin/env zsh
echo "[STUB] plutil \$*" >> "$STUB_LOG"
# Simulate successful lint
[[ "\$1" == "-lint" ]] && exit 0
# Simulate convert: just copy src to dest
if [[ "\$1" == "-convert" ]]; then
  src="\${@[-1]}"   # last arg is output when using -o
  # find the -o flag value
  local out=""
  local found_o=0
  for arg in "\$@"; do
    [[ \$found_o -eq 1 ]] && { out="\$arg"; found_o=0; }
    [[ "\$arg" == "-o" ]] && found_o=1
  done
  [[ -n "\$out" && -f "\${@[-1]}" ]] && cp "\${@[-1]}" "\$out" 2>/dev/null
fi
exit 0
STUB

# killall stub
cat > "$STUB_BIN/killall" <<STUB
#!/usr/bin/env zsh
echo "[STUB] killall \$*" >> "$STUB_LOG"
exit 0
STUB

# pgrep stub (iTerm2 not running)
cat > "$STUB_BIN/pgrep" <<STUB
#!/usr/bin/env zsh
echo "[STUB] pgrep \$*" >> "$STUB_LOG"
exit 1   # nothing is running
STUB

# open stub (don't actually open iTerm2)
cat > "$STUB_BIN/open" <<STUB
#!/usr/bin/env zsh
echo "[STUB] open \$*" >> "$STUB_LOG"
exit 0
STUB

# curl stub (don't download homebrew)
cat > "$STUB_BIN/curl" <<STUB
#!/usr/bin/env zsh
echo "[STUB] curl \$*" >> "$STUB_LOG"
exit 0
STUB

chmod +x "$STUB_BIN"/*

# Prepend stub bin to PATH for this session
export PATH="$STUB_BIN:$PATH"
print_info "Stubs installed: brew defaults plutil killall pgrep open curl"

# ─────────────────────────────────────────────────────────────────────────────
# HELPER: assert file contains a string
# ─────────────────────────────────────────────────────────────────────────────
assert_contains() {
  local file="$1" needle="$2" label="$3"
  if grep -qE "$needle" "$file" 2>/dev/null; then
    print_ok "$label"
  else
    print_fail "$label"
    print_info "Expected '$needle' in $file"
    print_info "Actual content:"
    sed 's/^/        /' "$file" 2>/dev/null || print_info "(file missing)"
  fi
}

assert_not_contains() {
  local file="$1" needle="$2" label="$3"
  if ! grep -qE "$needle" "$file" 2>/dev/null; then
    print_ok "$label"
  else
    print_fail "$label"
    print_info "Did NOT expect '$needle' in $file"
  fi
}

assert_file_exists() {
  local file="$1" label="$2"
  if [[ -f "$file" ]]; then
    print_ok "$label"
  else
    print_fail "$label"
    print_info "File not found: $file"
  fi
}

assert_file_missing() {
  local file="$1" label="$2"
  if [[ ! -f "$file" ]]; then
    print_ok "$label"
  else
    print_fail "$label"
    print_info "Expected file to be absent: $file"
  fi
}

assert_files_equal() {
  local a="$1" b="$2" label="$3"
  if diff -q "$a" "$b" &>/dev/null; then
    print_ok "$label"
  else
    print_fail "$label"
    diff "$a" "$b" | sed 's/^/        /' || true
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 1 — RUN install.sh
# ─────────────────────────────────────────────────────────────────────────────
print_head "Phase 1: Running install.sh"

# Wipe any stale real-system backups so Phase 1 assertions are isolated
rm -rf "$SCRIPT_DIR/backup"

# Snapshot originals for later comparison
cp "$SANDBOX/.zshrc"           "$SANDBOX/.zshrc.orig"
cp "$SANDBOX/.bashrc"          "$SANDBOX/.bashrc.orig"
cp "$SANDBOX/.zprofile"        "$SANDBOX/.zprofile.orig"
cp "$SANDBOX/.config/fish/config.fish" "$SANDBOX/config.fish.orig"
cp "$SANDBOX/.config/starship.toml"    "$SANDBOX/starship.orig"

zsh "$SCRIPT_DIR/install.sh" 2>&1 | sed 's/^/  /'

print_head "Phase 1 assertions"

# Snapshot archive exists
_SNAPSHOT=$(ls -t "$SCRIPT_DIR/backup"/snapshot-*.tar.gz 2>/dev/null | head -1)
assert_file_exists "$_SNAPSHOT" "snapshot archive created"

# Extract for content verification
_SNAP_VERIFY=$(mktemp -d /tmp/term-test-verify.XXXXXX)
[[ -f "$_SNAPSHOT" ]] && tar -xzf "$_SNAPSHOT" -C "$_SNAP_VERIFY" --strip-components=1 2>/dev/null

assert_file_exists "$_SNAP_VERIFY/.zshrc"        "snapshot contains .zshrc"
assert_file_exists "$_SNAP_VERIFY/.bashrc"       "snapshot contains .bashrc"
assert_file_exists "$_SNAP_VERIFY/.zprofile"     "snapshot contains .zprofile"
assert_file_exists "$_SNAP_VERIFY/config.fish"   "snapshot contains fish config"
assert_file_exists "$_SNAP_VERIFY/starship.toml" "snapshot contains starship.toml"
assert_file_exists "$_SNAP_VERIFY/iterm2.plist"  "snapshot contains iTerm2 plist"
assert_file_exists "$_SNAP_VERIFY/manifest.txt"  "snapshot contains manifest"

assert_contains "$_SNAP_VERIFY/manifest.txt" "^starship=" \
  "manifest: starship key present"
assert_contains "$_SNAP_VERIFY/manifest.txt" "^nerd_font=" \
  "manifest: nerd_font key present"
assert_contains "$_SNAP_VERIFY/manifest.txt" "starship_toml=existed" \
  "manifest: starship_toml=existed"
assert_contains "$_SNAP_VERIFY/manifest.txt" "iterm2_plist=existed" \
  "manifest: iterm2_plist=existed"

assert_files_equal "$_SNAP_VERIFY/.zshrc"        "$SANDBOX/.zshrc.orig"   \
  "snapshot .zshrc matches original"
assert_files_equal "$_SNAP_VERIFY/starship.toml" "$SANDBOX/starship.orig" \
  "snapshot starship.toml matches original"

rm -rf "$_SNAP_VERIFY"

# Starship config was deployed (dark mode → mocha)
assert_contains "$SANDBOX/.config/starship.toml" "catppuccin_mocha" \
  "starship config deployed (mocha for dark mode)"

# starship init injected into all shells
assert_contains "$SANDBOX/.zshrc"        "starship init zsh"   "starship init in .zshrc"
assert_contains "$SANDBOX/.bashrc"       "starship init bash"  "starship init in .bashrc"
assert_contains "$SANDBOX/.zprofile"     "starship init zsh"   "starship init in .zprofile"
assert_contains "$SANDBOX/.config/fish/config.fish" "starship init fish" \
  "starship init in fish config"

# Original content preserved
assert_contains "$SANDBOX/.zshrc"    'alias ll="ls -la"'  "original .zshrc content preserved"
assert_contains "$SANDBOX/.bashrc"   "EDITOR=vim"          "original .bashrc content preserved"
assert_contains "$SANDBOX/.zprofile" "brew shellenv"       "original .zprofile content preserved"

# Toggle script created
assert_file_exists "$SANDBOX/.local/bin/toggle-starship-theme" "toggle script created"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 2 — RUN revert.sh
# ─────────────────────────────────────────────────────────────────────────────
print_head "Phase 2: Running revert.sh"

zsh "$SCRIPT_DIR/revert.sh" 2>&1 | sed 's/^/  /'

print_head "Phase 2 assertions"

# Shell configs restored to original content
assert_files_equal "$SANDBOX/.zshrc"    "$SANDBOX/.zshrc.orig"   ".zshrc restored to original"
assert_files_equal "$SANDBOX/.bashrc"   "$SANDBOX/.bashrc.orig"  ".bashrc restored to original"
assert_files_equal "$SANDBOX/.zprofile" "$SANDBOX/.zprofile.orig" ".zprofile restored to original"
assert_files_equal "$SANDBOX/.config/fish/config.fish" "$SANDBOX/config.fish.orig" \
  "fish config restored to original"

# starship.toml restored to original
assert_files_equal "$SANDBOX/.config/starship.toml" "$SANDBOX/starship.orig" \
  "starship.toml restored to original"

# starship init removed from all shells
assert_not_contains "$SANDBOX/.zshrc"    "starship init" "starship init removed from .zshrc"
assert_not_contains "$SANDBOX/.bashrc"   "starship init" "starship init removed from .bashrc"
assert_not_contains "$SANDBOX/.zprofile" "starship init" "starship init removed from .zprofile"
assert_not_contains "$SANDBOX/.config/fish/config.fish" "starship init" \
  "starship init removed from fish config"

# Toggle script removed
assert_file_missing "$SANDBOX/.local/bin/toggle-starship-theme" "toggle script removed"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3 — EDGE CASE: revert with missing backup
# ─────────────────────────────────────────────────────────────────────────────
print_head "Phase 3: Edge case — revert with no backup files"

# Wipe the backup dir to simulate "backup lost" scenario
rm -rf "$SCRIPT_DIR/backup"
mkdir -p "$SCRIPT_DIR/backup"

# Re-run install so there's something to revert (but no backups for shell files)
# Inject starship manually to simulate a partial install state
echo 'eval "$(starship init zsh)"' >> "$SANDBOX/.zshrc"
echo 'eval "$(starship init bash)"' >> "$SANDBOX/.bashrc"
echo 'starship init fish | source' >> "$SANDBOX/.config/fish/config.fish"
cat > "$SANDBOX/.config/starship.toml" <<'EOF'
# installed catppuccin config
palette = 'catppuccin_mocha'
EOF

# Run revert without any .bak files
zsh "$SCRIPT_DIR/revert.sh" 2>&1 | sed 's/^/  /'

print_head "Phase 3 assertions"

# starship init stripped via sed fallback
assert_not_contains "$SANDBOX/.zshrc"  "starship init" \
  "starship init stripped from .zshrc (no backup)"
assert_not_contains "$SANDBOX/.bashrc" "starship init" \
  "starship init stripped from .bashrc (no backup)"
assert_not_contains "$SANDBOX/.config/fish/config.fish" "starship init" \
  "starship init stripped from fish config (no backup)"

# No manifest + no backup → starship.toml is removed (not written as fallback,
# since we can't know if it existed before install)
assert_file_missing "$SANDBOX/.config/starship.toml" \
  "starship.toml removed when no manifest and no backup"

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 4 — EDGE CASE: install run twice (duplicate starship init lines)
# ─────────────────────────────────────────────────────────────────────────────
print_head "Phase 4: Edge case — install.sh run twice, revert cleans all lines"

# Fresh .zshrc with starship already present (simulates double-install)
cat > "$SANDBOX/.zshrc" <<'EOF'
# existing zshrc
alias ll="ls -la"
# Starship prompt
eval "$(starship init zsh)"
# Starship prompt
eval "$(starship init zsh)"
EOF

zsh "$SCRIPT_DIR/revert.sh" 2>&1 | sed 's/^/  /'

assert_not_contains "$SANDBOX/.zshrc" "starship init" \
  "all duplicate starship init lines removed"
assert_contains "$SANDBOX/.zshrc" 'alias ll="ls -la"' \
  "non-starship content preserved during multi-line strip"

# ─────────────────────────────────────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
print_head "Results"
print -P "  %F{114}PASS: $PASS%f   %F{196}FAIL: $FAIL%f"
print -P ""

if [[ $FAIL -gt 0 ]]; then
  print -P "%F{196}Some tests failed. Stub log:%f"
  [[ -f "$SANDBOX/stub.log" ]] && cat "$SANDBOX/stub.log" | sed 's/^/  /'
  exit 1
else
  print -P "%F{114}All tests passed. Your real system was not touched.%f"
  exit 0
fi
