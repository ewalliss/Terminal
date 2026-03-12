#!/usr/bin/env zsh
# ─────────────────────────────────────────────────────────────────────────────
# Revert to default terminal — undoes everything install.sh did
# Handles all edge cases: missing backups, partial installs, corrupt files,
# multiple shells, iTerm2 plist, pre-existing tools, etc.
# ─────────────────────────────────────────────────────────────────────────────
# NOTE: run WITHOUT set -e so individual failures don't abort the whole revert
setopt NO_ERR_EXIT 2>/dev/null; set +e

SCRIPT_DIR="${0:A:h}"
BACKUP_DIR="$SCRIPT_DIR/backup"
MANIFEST="$BACKUP_DIR/manifest.txt"
STARSHIP_CONFIG="$HOME/.config/starship.toml"
TOGGLE_SCRIPT="$HOME/.local/bin/toggle-starship-theme"
ITERM2_PLIST="$HOME/Library/Preferences/com.googlecode.iterm2.plist"

print_step() { print -P "%F{141}===>%f $1"; }
print_ok()   { print -P "%F{114} $1%f"; }
print_warn() { print -P "%F{214}  $1%f"; }
print_err()  { print -P "%F{196}  ERROR: $1%f"; }

ERRORS=()
note_error() { ERRORS+=("$1"); print_err "$1"; }

# ── Helper: read a value from manifest ───────────────────────────────────────
manifest_get() {
  # manifest_get KEY → prints value, empty string if not found
  [[ -f "$MANIFEST" ]] && grep "^$1=" "$MANIFEST" | cut -d= -f2- || echo ""
}

# ── Helper: validate a backup file ───────────────────────────────────────────
backup_valid() {
  local f="$1"
  [[ -f "$f" && -s "$f" ]]   # exists and non-empty
}

# ── Helper: strip starship init lines from any file ──────────────────────────
strip_starship_from() {
  local rcfile="$1"
  [[ -f "$rcfile" ]] || return 0
  if grep -q 'starship init\|starship init fish' "$rcfile" 2>/dev/null; then
    sed -i '' \
      -e '/# Starship prompt/{N; /eval.*starship init/d; /starship init fish | source/d;}' \
      -e '/# Starship prompt/d' \
      -e '/eval "$(starship init zsh)"/d' \
      -e '/eval "$(starship init bash)"/d' \
      -e '/starship init fish | source/d' \
      "$rcfile" 2>/dev/null
    sed -i '' -e '/starship init/d' "$rcfile" 2>/dev/null
    print_ok "  stripped starship init from $rcfile"
  fi
}

# ── Helper: strip path-picker source line from any file ───────────────────────
strip_path_picker_from() {
  local rcfile="$1"
  [[ -f "$rcfile" ]] || return 0
  if grep -q 'path-picker.zsh' "$rcfile" 2>/dev/null; then
    sed -i '' \
      -e '/# Path picker (fzf Tab completion)/d' \
      -e '/path-picker\.zsh/d' \
      "$rcfile" 2>/dev/null
    print_ok "  stripped path-picker from $rcfile"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
print_step "Reading install manifest…"
if [[ ! -f "$MANIFEST" ]]; then
  print_warn "No manifest found at $MANIFEST"
  print_warn "install.sh may not have been run, or backup/ was deleted."
  print_warn "Proceeding with best-effort revert (will NOT uninstall pre-existing tools)."
fi

STARSHIP_ORIGIN=$(manifest_get "starship")        # "installed-by-us" | "pre-existing" | ""
FONT_ORIGIN=$(manifest_get "nerd_font")           # same
STARSHIP_TOML_STATE=$(manifest_get "starship_toml") # "existed" | "none" | ""
ITERM2_STATE=$(manifest_get "iterm2_plist")       # "existed" | "none" | ""

# ─────────────────────────────────────────────────────────────────────────────
# 1. RESTORE STARSHIP CONFIG
# ─────────────────────────────────────────────────────────────────────────────
print_step "Reverting starship config…"

if backup_valid "$BACKUP_DIR/starship.toml.bak"; then
  cp "$BACKUP_DIR/starship.toml.bak" "$STARSHIP_CONFIG" \
    && print_ok "Restored starship.toml from backup" \
    || note_error "Failed to copy starship.toml backup"

elif [[ "$STARSHIP_TOML_STATE" == "none" || -z "$STARSHIP_TOML_STATE" ]]; then
  # It didn't exist before install → remove it
  rm -f "$STARSHIP_CONFIG" \
    && print_ok "Removed starship.toml (did not exist before install)" \
    || note_error "Could not remove $STARSHIP_CONFIG"

else
  # Backup file is missing/empty but manifest says it existed — last resort:
  # write a blank (valid) starship config so starship shows a plain prompt
  print_warn "Backup starship.toml is missing or empty."
  print_warn "Writing a minimal fallback config (no segments, plain prompt)."
  mkdir -p "$HOME/.config"
  cat > "$STARSHIP_CONFIG" <<'FALLBACK'
# Minimal fallback — restored by revert.sh
# Starship will show a basic prompt with no custom segments.
format = "$all$character"
[character]
success_symbol = "[❯](green)"
error_symbol   = "[❯](red)"
FALLBACK
  print_ok "Fallback starship.toml written → $STARSHIP_CONFIG"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 2. RESTORE SHELL CONFIG FILES
# ─────────────────────────────────────────────────────────────────────────────
print_step "Reverting shell config files…"

_revert_shell_file() {
  local filename="$1"    # e.g. ".zshrc"
  local rcfile="$HOME/$filename"
  local bakfile="$BACKUP_DIR/$filename.bak"

  if backup_valid "$bakfile"; then
    cp "$bakfile" "$rcfile" \
      && print_ok "  Restored ~/$filename from backup" \
      || note_error "Failed to restore ~/$filename"
  else
    # No valid backup — strip only the lines we added
    strip_starship_from "$rcfile"
    strip_path_picker_from "$rcfile"
    if [[ ! -f "$rcfile" ]]; then
      print_ok "  ~/$filename did not exist — nothing to revert"
    fi
  fi
}

_revert_shell_file ".zshrc"
_revert_shell_file ".zprofile"
_revert_shell_file ".bashrc"
_revert_shell_file ".bash_profile"
_revert_shell_file ".profile"

# Fish
FISH_CONFIG="$HOME/.config/fish/config.fish"
FISH_BAK="$BACKUP_DIR/config.fish.bak"
if backup_valid "$FISH_BAK"; then
  cp "$FISH_BAK" "$FISH_CONFIG" \
    && print_ok "  Restored fish config from backup" \
    || note_error "Failed to restore fish config"
else
  strip_starship_from "$FISH_CONFIG"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 3. RESTORE iTerm2 PREFERENCES
# ─────────────────────────────────────────────────────────────────────────────
print_step "Reverting iTerm2 preferences…"
ITERM2_BAK="$BACKUP_DIR/iterm2.plist.bak"

if backup_valid "$ITERM2_BAK"; then
  # Validate the plist before overwriting
  if plutil -lint "$ITERM2_BAK" &>/dev/null; then
    # iTerm2 must not be running for the plist to take effect cleanly
    if pgrep -x iTerm2 &>/dev/null; then
      print_warn "iTerm2 is running. Quit it first, then run:"
      print_warn "  plutil -convert binary1 -o \"$ITERM2_PLIST\" \"$ITERM2_BAK\""
      print_warn "  killall cfprefsd"
    else
      plutil -convert binary1 -o "$ITERM2_PLIST" "$ITERM2_BAK" \
        && killall cfprefsd 2>/dev/null; true \
        && print_ok "Restored iTerm2 plist from backup" \
        || note_error "Failed to restore iTerm2 plist"
    fi
  else
    note_error "Backup iTerm2 plist is corrupt ($ITERM2_BAK). Skipping."
    print_warn "Manual fix: Preferences → Profiles → Colors → Color Presets… → Dark/Light Background"
  fi

elif [[ "$ITERM2_STATE" == "none" ]]; then
  # iTerm2 plist didn't exist before — removing it resets to factory defaults
  if [[ -f "$ITERM2_PLIST" ]]; then
    if pgrep -x iTerm2 &>/dev/null; then
      print_warn "iTerm2 is running. Quit it, then run: rm \"$ITERM2_PLIST\""
    else
      rm -f "$ITERM2_PLIST" && killall cfprefsd 2>/dev/null; true \
        && print_ok "Removed iTerm2 plist → factory defaults on next launch" \
        || note_error "Could not remove iTerm2 plist"
    fi
  fi

else
  # Backup missing — give precise manual steps
  print_warn "No iTerm2 plist backup found. Manual steps to reset colors:"
  print -P "  1. Open iTerm2 → Cmd+, → Profiles → Colors"
  print -P "  2. Color Presets… → Solarized Dark (or Light Background) → Apply"
  print -P "  3. Color Presets… → select Catppuccin Mocha → Delete (repeat for Latte)"
  print -P "  4. Profiles → Text → reset font to Monaco or your previous font"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 4. REMOVE TOGGLE SCRIPT
# ─────────────────────────────────────────────────────────────────────────────
print_step "Removing toggle-starship-theme…"
if [[ -f "$TOGGLE_SCRIPT" ]]; then
  rm -f "$TOGGLE_SCRIPT" \
    && print_ok "Removed $TOGGLE_SCRIPT" \
    || note_error "Could not remove $TOGGLE_SCRIPT"
else
  print_ok "Toggle script not found — already removed"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 5. CONDITIONALLY UNINSTALL STARSHIP + FONT
# ─────────────────────────────────────────────────────────────────────────────
print_step "Checking installed packages…"

if [[ "$STARSHIP_ORIGIN" == "installed-by-us" ]]; then
  if command -v brew &>/dev/null && brew list starship &>/dev/null 2>&1; then
    brew uninstall starship \
      && print_ok "Uninstalled starship" \
      || note_error "Failed to uninstall starship"
  fi
elif [[ "$STARSHIP_ORIGIN" == "pre-existing" ]]; then
  print_ok "Starship was pre-existing — keeping it"
else
  # No manifest → safe default: don't uninstall
  print_warn "Unknown starship origin (no manifest). Keeping it to be safe."
  print -P "  To remove manually: brew uninstall starship"
fi

if [[ "$FONT_ORIGIN" == "installed-by-us" ]]; then
  if command -v brew &>/dev/null && brew list --cask font-jetbrains-mono-nerd-font &>/dev/null 2>&1; then
    brew uninstall --cask font-jetbrains-mono-nerd-font \
      && print_ok "Uninstalled JetBrainsMono Nerd Font" \
      || note_error "Failed to uninstall font"
  fi
elif [[ "$FONT_ORIGIN" == "pre-existing" ]]; then
  print_ok "Nerd Font was pre-existing — keeping it"
else
  print_warn "Unknown font origin. Keeping it to be safe."
  print -P "  To remove manually: brew uninstall --cask font-jetbrains-mono-nerd-font"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 6. TERMINAL.APP FALLBACK (if user isn't on iTerm2)
# ─────────────────────────────────────────────────────────────────────────────
if [[ ! -d "/Applications/iTerm.app" ]]; then
  print_warn "iTerm2 not found — you may be using Terminal.app."
  print -P "  To reset Terminal.app colors:"
  print -P "  Shell → Edit Profile… → choose 'Basic' (light) or 'Pro' (dark)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 7. SUMMARY
# ─────────────────────────────────────────────────────────────────────────────
print -P ""
if [[ ${#ERRORS[@]} -gt 0 ]]; then
  print -P "%F{196}Revert completed with ${#ERRORS[@]} error(s):%f"
  for err in "${ERRORS[@]}"; do
    print -P "  %F{196}• $err%f"
  done
  print -P ""
  print -P "Fix the errors above manually, then restart your terminal."
else
  print -P "%F{114}✓ Revert complete — no errors.%f"
  print -P "Restart your terminal or run: source ~/.zshrc"
fi
