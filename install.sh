#!/usr/bin/env zsh
# ─────────────────────────────────────────────────────────────────────────────
# Catppuccin Terminal Setup — macOS / iTerm2 + Starship
# ─────────────────────────────────────────────────────────────────────────────
set -e

SCRIPT_DIR="${0:A:h}"
STARSHIP_DIR="$SCRIPT_DIR/starship"
ITERM_DIR="$SCRIPT_DIR/iterm2"
BACKUP_DIR="$SCRIPT_DIR/backup"
STARSHIP_CONFIG="$HOME/.config/starship.toml"
TOGGLE_SCRIPT="$HOME/.local/bin/toggle-starship-theme"
ITERM2_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
MANIFEST="$BACKUP_DIR/manifest.txt"

print_step() { print -P "%F{141}===>%f $1"; }
print_ok()   { print -P "%F{114} $1%f"; }
print_warn() { print -P "%F{214}  $1%f"; }

mkdir -p "$BACKUP_DIR"

# ── Record pre-existing state (used by revert.sh) ────────────────────────────
{
  echo "install_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  command -v starship &>/dev/null && echo "starship=pre-existing" || echo "starship=installed-by-us"
  local _nf=( "$HOME/Library/Fonts"/JetBrainsMonoNerdFont*(N) /Library/Fonts/JetBrainsMonoNerdFont*(N) )
  [[ ${#_nf} -gt 0 ]] && echo "nerd_font=pre-existing" || echo "nerd_font=installed-by-us"
  [[ -f "$STARSHIP_CONFIG" ]] && echo "starship_toml=existed" || echo "starship_toml=none"
  [[ -f "$ITERM2_PLIST" ]] && echo "iterm2_plist=existed" || echo "iterm2_plist=none"
} > "$MANIFEST"
print_ok "Manifest saved → $MANIFEST"

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
  print_step "Installing Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  print_ok "Homebrew already installed"
fi

# ── 2. Starship ───────────────────────────────────────────────────────────────
if ! command -v starship &>/dev/null; then
  print_step "Installing Starship…"
  brew install starship
else
  print_ok "Starship already installed"
fi

# ── 3. JetBrainsMono Nerd Font ────────────────────────────────────────────────
local _installed_fonts=( "$HOME/Library/Fonts"/JetBrainsMonoNerdFont*(N) /Library/Fonts/JetBrainsMonoNerdFont*(N) )
if [[ ${#_installed_fonts} -gt 0 ]]; then
  print_ok "JetBrainsMono Nerd Font already installed"
else
  print_step "Installing JetBrainsMono Nerd Font…"
  brew install --cask font-jetbrains-mono-nerd-font
fi

# ── 4. Backup ─────────────────────────────────────────────────────────────────
print_step "Backing up configs…"
[[ -f "$HOME/.zshrc" ]]       && cp "$HOME/.zshrc"       "$BACKUP_DIR/.zshrc.bak"       && print_ok "  ~/.zshrc backed up"
[[ -f "$STARSHIP_CONFIG" ]]   && cp "$STARSHIP_CONFIG"   "$BACKUP_DIR/starship.toml.bak" && print_ok "  starship.toml backed up"
[[ -f "$ITERM2_PLIST" ]]      && plutil -convert xml1 -o "$BACKUP_DIR/iterm2.plist.bak" "$ITERM2_PLIST" 2>/dev/null \
                               || cp "$ITERM2_PLIST" "$BACKUP_DIR/iterm2.plist.bak" 2>/dev/null

# ── 5. Deploy Starship config ─────────────────────────────────────────────────
mkdir -p "$HOME/.config"
APPEARANCE=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")
if [[ "$APPEARANCE" == "Dark" ]]; then
  print_step "System is Dark — deploying Catppuccin Mocha (Style B)"
  cp "$STARSHIP_DIR/starship-mocha-b.toml" "$STARSHIP_CONFIG"
else
  print_step "System is Light — deploying Catppuccin Latte (Style B)"
  cp "$STARSHIP_DIR/starship-latte-b.toml" "$STARSHIP_CONFIG"
fi
print_ok "Starship config → $STARSHIP_CONFIG"

# ── 6. Inject starship init into ~/.zshrc ────────────────────────────────────
if [[ -f "$HOME/.zshrc" && -w "$HOME/.zshrc" ]]; then
  if ! grep -q 'starship init zsh' "$HOME/.zshrc"; then
    printf '\n# Starship prompt\neval "$(starship init zsh)"\n' >> "$HOME/.zshrc"
    print_ok "starship init injected → ~/.zshrc"
  else
    print_ok "starship init already in ~/.zshrc"
  fi
else
  print_warn "~/.zshrc not found or not writable — skipped"
fi

# ── 7. iTerm2 color profiles ──────────────────────────────────────────────────
ITERM2_APP=""
[[ -d "/Applications/iTerm.app" ]]  && ITERM2_APP="/Applications/iTerm.app"
[[ -d "/Applications/iTerm2.app" ]] && ITERM2_APP="/Applications/iTerm2.app"

if [[ -n "$ITERM2_APP" ]]; then
  print_step "Opening iTerm2 color profiles for import…"
  open "$ITERM_DIR/catppuccin-mocha.itermcolors"
  open "$ITERM_DIR/catppuccin-latte.itermcolors"
  print_ok "Color profiles opened — accept the import prompt in iTerm2"
  print -P ""
  print -P "%F{141}  iTerm2 setup:%f"
  print -P "  1. Cmd+, → Profiles → Colors → Color Presets… → pick Catppuccin"
  print -P "  2. Profiles → Text → Font → JetBrainsMono Nerd Font, size 13"
else
  print_warn "iTerm2 not found — skipping color profile import"
fi

# ── 8. Toggle script ──────────────────────────────────────────────────────────
mkdir -p "$HOME/.local/bin"
cat > "$TOGGLE_SCRIPT" <<TOGGLE
#!/usr/bin/env zsh
# Usage:
#   toggle-starship-theme            — sync to macOS dark/light mode
#   toggle-starship-theme --style A  — powerline backgrounds
#   toggle-starship-theme --style B  — text-only colors

APPEARANCE=\$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")
STARSHIP_CONFIG="\$HOME/.config/starship.toml"
THEME_DIR="$STARSHIP_DIR"

[[ -f "\$STARSHIP_CONFIG" ]] && grep -q 'bg:mauve' "\$STARSHIP_CONFIG" 2>/dev/null \
  && CURRENT_STYLE="A" || CURRENT_STYLE="B"

STYLE="\$CURRENT_STYLE"
[[ "\$1" == "--style" && -n "\$2" ]] && STYLE="\${2:u}"

if [[ "\$APPEARANCE" == "Dark" ]]; then
  [[ "\$STYLE" == "A" ]] && SRC="starship-mocha.toml" || SRC="starship-mocha-b.toml"
  cp "\$THEME_DIR/\$SRC" "\$STARSHIP_CONFIG"
  echo "Switched to Catppuccin Mocha — Style \$STYLE"
else
  [[ "\$STYLE" == "A" ]] && SRC="starship-latte.toml" || SRC="starship-latte-b.toml"
  cp "\$THEME_DIR/\$SRC" "\$STARSHIP_CONFIG"
  echo "Switched to Catppuccin Latte — Style \$STYLE"
fi
TOGGLE
chmod +x "$TOGGLE_SCRIPT"
print_ok "Toggle script → $TOGGLE_SCRIPT"

print -P ""
print -P "%F{141}✓ Done! Run: source ~/.zshrc%f"
