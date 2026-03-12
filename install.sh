#!/usr/bin/env zsh
# ─────────────────────────────────────────────────────────────────────────────
# Catppuccin Terminal Setup — macOS / iTerm2 + Starship
# Light (Latte) & Dark (Mocha) with Apple  icon
# ─────────────────────────────────────────────────────────────────────────────
set -e

SCRIPT_DIR="${0:A:h}"
ITERM_DIR="$SCRIPT_DIR/iterm2"
STARSHIP_DIR="$SCRIPT_DIR/starship"
BACKUP_DIR="$SCRIPT_DIR/backup"
STARSHIP_CONFIG="$HOME/.config/starship.toml"
TOGGLE_SCRIPT="$HOME/.local/bin/toggle-starship-theme"
ITERM2_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"
MANIFEST="$BACKUP_DIR/manifest.txt"

print_step() { print -P "%F{141}===>%f $1"; }
print_ok()   { print -P "%F{114} $1%f"; }
print_warn() { print -P "%F{214}  $1%f"; }

mkdir -p "$BACKUP_DIR"

# ── Record pre-existing state in manifest ────────────────────────────────────
# This lets revert.sh know what was already there vs what we installed,
# so it never removes tools you already had.
{
  echo "install_date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # starship
  if command -v starship &>/dev/null; then
    echo "starship=pre-existing"
  else
    echo "starship=installed-by-us"
  fi

  # Nerd Font — use (N) glob modifier so unmatched globs expand to empty, not error
  local _nf=( "$HOME/Library/Fonts"/JetBrainsMonoNerdFont*(N) /Library/Fonts/JetBrainsMonoNerdFont*(N) )
  if [[ ${#_nf} -gt 0 ]]; then
    echo "nerd_font=pre-existing"
  else
    echo "nerd_font=installed-by-us"
  fi

  # Which shell configs existed
  local existed=()
  for f in .zshrc .zprofile .bashrc .bash_profile .profile; do
    [[ -f "$HOME/$f" ]] && existed+=("$f")
  done
  echo "shell_configs_existed=${(j:,:)existed}"

  # Fish
  [[ -f "$HOME/.config/fish/config.fish" ]] && echo "fish_config=existed" || echo "fish_config=none"

  # starship.toml
  [[ -f "$STARSHIP_CONFIG" ]] && echo "starship_toml=existed" || echo "starship_toml=none"

  # iTerm2 plist
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

# ── 4. Backup all shell configs ───────────────────────────────────────────────
print_step "Backing up shell configs…"
for f in .zshrc .zprofile .bashrc .bash_profile .profile; do
  if [[ -f "$HOME/$f" ]]; then
    cp "$HOME/$f" "$BACKUP_DIR/$f.bak"
    print_ok "  $HOME/$f → $BACKUP_DIR/$f.bak"
  fi
done

# Fish
if [[ -f "$HOME/.config/fish/config.fish" ]]; then
  cp "$HOME/.config/fish/config.fish" "$BACKUP_DIR/config.fish.bak"
  print_ok "  fish config → $BACKUP_DIR/config.fish.bak"
fi

# Starship config
mkdir -p "$HOME/.config"
if [[ -f "$STARSHIP_CONFIG" ]]; then
  cp "$STARSHIP_CONFIG" "$BACKUP_DIR/starship.toml.bak"
  print_ok "  starship.toml → $BACKUP_DIR/starship.toml.bak"
fi

# iTerm2 preferences plist
if [[ -f "$ITERM2_PLIST" ]]; then
  # Export as XML so it's human-readable and format-stable
  plutil -convert xml1 -o "$BACKUP_DIR/iterm2.plist.bak" "$ITERM2_PLIST" 2>/dev/null \
    || cp "$ITERM2_PLIST" "$BACKUP_DIR/iterm2.plist.bak"
  print_ok "  iTerm2 plist → $BACKUP_DIR/iterm2.plist.bak"
fi

# ── 5. Deploy Starship config ─────────────────────────────────────────────────
APPEARANCE=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")
if [[ "$APPEARANCE" == "Dark" ]]; then
  print_step "System is Dark — using Catppuccin Mocha (Style B)"
  cp "$STARSHIP_DIR/starship-mocha-b.toml" "$STARSHIP_CONFIG"
else
  print_step "System is Light — using Catppuccin Latte (Style B)"
  cp "$STARSHIP_DIR/starship-latte-b.toml" "$STARSHIP_CONFIG"
fi
print_ok "Starship config → $STARSHIP_CONFIG"

# ── 6. Inject starship init into shell configs ────────────────────────────────
_inject_starship_zsh() {
  local rcfile="$1"
  [[ -f "$rcfile" ]] || return 0
  [[ -w "$rcfile" ]] || { print_warn "  skipping $rcfile (not writable)"; return 0; }
  if ! grep -q 'starship init zsh' "$rcfile"; then
    printf '\n# Starship prompt\neval "$(starship init zsh)"\n' >> "$rcfile"
    print_ok "  starship init → $rcfile"
  fi
}
_inject_starship_bash() {
  local rcfile="$1"
  [[ -f "$rcfile" ]] || return 0
  [[ -w "$rcfile" ]] || { print_warn "  skipping $rcfile (not writable)"; return 0; }
  if ! grep -q 'starship init bash' "$rcfile"; then
    printf '\n# Starship prompt\neval "$(starship init bash)"\n' >> "$rcfile"
    print_ok "  starship init → $rcfile"
  fi
}

print_step "Injecting starship init…"
_inject_starship_zsh "$HOME/.zshrc"
_inject_starship_zsh "$HOME/.zprofile"
_inject_starship_bash "$HOME/.bashrc"
_inject_starship_bash "$HOME/.bash_profile"

# Fish
if [[ -f "$HOME/.config/fish/config.fish" ]] && \
   ! grep -q 'starship init fish' "$HOME/.config/fish/config.fish"; then
  printf '\n# Starship prompt\nstarship init fish | source\n' >> "$HOME/.config/fish/config.fish"
  print_ok "  starship init → fish config"
fi

# ── 7. iTerm2 color profiles ──────────────────────────────────────────────────
print_step "Opening iTerm2 color profiles for import…"
if [[ -d "/Applications/iTerm.app" ]]; then
  open "$ITERM_DIR/catppuccin-mocha.itermcolors"
  open "$ITERM_DIR/catppuccin-latte.itermcolors"
  print_ok "Color files opened — iTerm2 will prompt for import"
  print -P ""
  print -P "%F{141}iTerm2 steps:%f"
  print -P "  1. Cmd+, → Profiles → Colors → Color Presets… → select the preset"
  print -P "  2. Profiles → Text → set font to JetBrainsMono Nerd Font, size 13"
else
  print_warn "iTerm2 not found at /Applications/iTerm.app"
fi

# ── 8. Auto-switch toggle script ──────────────────────────────────────────────
mkdir -p "$HOME/.local/bin"
cat > "$TOGGLE_SCRIPT" <<TOGGLE
#!/usr/bin/env zsh
# Usage:
#   toggle-starship-theme          — sync to current macOS dark/light mode
#   toggle-starship-theme --style A  — switch to Style A (powerline backgrounds)
#   toggle-starship-theme --style B  — switch to Style B (text-only colors)

APPEARANCE=\$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")
STARSHIP_CONFIG="\$HOME/.config/starship.toml"
THEME_DIR="$STARSHIP_DIR"

# Detect current style from active config (default to B)
if [[ -f "\$STARSHIP_CONFIG" ]] && grep -q 'bg:mauve' "\$STARSHIP_CONFIG" 2>/dev/null; then
  CURRENT_STYLE="A"
else
  CURRENT_STYLE="B"
fi

# Parse --style argument
STYLE="\$CURRENT_STYLE"
if [[ "\$1" == "--style" && -n "\$2" ]]; then
  STYLE="\${2:u}"   # uppercase
fi

if [[ "\$APPEARANCE" == "Dark" ]]; then
  [[ "\$STYLE" == "A" ]] && SRC="starship-mocha.toml" || SRC="starship-mocha-b.toml"
  cp "\$THEME_DIR/\$SRC" "\$STARSHIP_CONFIG"
  echo "Switched to Catppuccin Mocha — Style \$STYLE (dark)"
else
  [[ "\$STYLE" == "A" ]] && SRC="starship-latte.toml" || SRC="starship-latte-b.toml"
  cp "\$THEME_DIR/\$SRC" "\$STARSHIP_CONFIG"
  echo "Switched to Catppuccin Latte — Style \$STYLE (light)"
fi
TOGGLE
chmod +x "$TOGGLE_SCRIPT"
print_ok "Toggle script → $TOGGLE_SCRIPT"

print -P ""
print -P "%F{141}✓ Done! Run: source ~/.zshrc%f"
