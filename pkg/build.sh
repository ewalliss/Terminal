#!/usr/bin/env zsh
# ─────────────────────────────────────────────────────────────────────────────
# build.sh — produce EwallisTerminal-<VERSION>.pkg
#
# Composes the payload tree from the repo's starship/ + iterm2/ assets,
# then invokes pkgbuild to create the installer.
#
# Output: dist/EwallisTerminal-<VERSION>.pkg
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail
IFS=$'\n\t'
export LANG="${LANG:-en_US.UTF-8}"

PKG_VERSION="1.0.0"
PKG_ID="com.ewalliss.ewallis-terminal"
PKG_NAME="EwallisTerminal"
INSTALL_LOCATION="/"

SCRIPT_DIR="${0:A:h}"
REPO_DIR="${SCRIPT_DIR:h}"
PAYLOAD_ROOT="$SCRIPT_DIR/payload"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
DIST_DIR="$REPO_DIR/dist"

PKG_SHARE="$PAYLOAD_ROOT/usr/local/share/ewallis-terminal"

say()  { print -P -- "%F{141}==>%f $*"; }
ok()   { print -P -- "%F{114}  ok%f $*"; }
err()  { print -P -- "%F{196}  err%f $*"; }

# ─── 1. Sanity checks ────────────────────────────────────────────────────────
say "Sanity checks"
[[ -x /usr/bin/pkgbuild ]] || { err "pkgbuild not found (install Xcode Command Line Tools)"; exit 1; }
[[ -d "$REPO_DIR/starship" ]] || { err "missing $REPO_DIR/starship"; exit 1; }
[[ -d "$REPO_DIR/iterm2" ]]   || { err "missing $REPO_DIR/iterm2"; exit 1; }
ok "tools + repo layout"

# ─── 2. Compose payload from repo assets ─────────────────────────────────────
say "Composing payload"

# Starship configs — generate merged style A + style B (each containing all 4 palettes)
mkdir -p "$PKG_SHARE/configs"
/usr/bin/python3 "$SCRIPT_DIR/tools/build-merged-config.py" \
  "$REPO_DIR/starship/starship-mocha.toml" mocha \
  "$PKG_SHARE/configs/starship-style-a.toml"
/usr/bin/python3 "$SCRIPT_DIR/tools/build-merged-config.py" \
  "$REPO_DIR/starship/starship-mocha-b.toml" mocha \
  "$PKG_SHARE/configs/starship-style-b.toml"
ok "configs/  (2 merged .toml, each with 4 palettes)"

# iTerm2 color presets — kept for users who want them at Profiles → Color Presets
mkdir -p "$PKG_SHARE/iterm2"
for col in catppuccin-mocha.itermcolors catppuccin-latte.itermcolors; do
  src="$REPO_DIR/iterm2/$col"
  [[ -f "$src" ]] || { err "missing iterm2 color preset: $src"; exit 1; }
  cp -p "$src" "$PKG_SHARE/iterm2/$col"
done
# Generate all four iTerm2 Dynamic Profile JSONs from the Catppuccin palette data
for palette in latte frappe macchiato mocha; do
  /usr/bin/python3 "$SCRIPT_DIR/tools/build-iterm-profile.py" \
    "$palette" "$PKG_SHARE/iterm2/catppuccin-$palette.json"
done
ok "iterm2/  (2 .itermcolors + 4 dynamic profile .json)"

# Validate dynamic-profile JSON before shipping (python3 ships with CLT)
for json in "$PKG_SHARE"/iterm2/*.json; do
  if ! /usr/bin/python3 -m json.tool "$json" >/dev/null 2>&1; then
    err "invalid JSON: $json"
    exit 1
  fi
done
ok "dynamic profiles are valid JSON"

# Validate snippets exist
for snip in zshrc.sh zprofile.sh bashrc.sh fish.fish; do
  [[ -f "$PKG_SHARE/snippets/$snip" ]] || { err "missing snippet: $snip"; exit 1; }
done
ok "snippets/  (4 files)"

# Validate bin scripts
for b in ewallis-terminal-setup-user ewallis-terminal-uninstall ewallis-theme toggle-starship-theme; do
  [[ -f "$PKG_SHARE/bin/$b" ]] || { err "missing bin: $b"; exit 1; }
done
ok "bin/  (4 scripts)"

# Ship a VERSION file so installed users can identify it
print -- "$PKG_VERSION" > "$PKG_SHARE/VERSION"
ok "VERSION → $PKG_VERSION"

# Ship LICENSE if present
[[ -f "$REPO_DIR/LICENSE" ]] && cp -p "$REPO_DIR/LICENSE" "$PKG_SHARE/LICENSE" && ok "LICENSE"

# ─── 3. Strip macOS metadata + fix permissions on payload ────────────────────
say "Cleaning macOS metadata + setting permissions"
# Strip AppleDouble (._*) and .DS_Store — these contaminate pkgbuild output
find "$PAYLOAD_ROOT" \( -name '._*' -o -name '.DS_Store' \) -delete
# Strip xattrs (com.apple.* metadata) from every file
xattr -rc "$PAYLOAD_ROOT" 2>/dev/null || true
# Directories: 0755, regular files: 0644, scripts: 0755
find "$PAYLOAD_ROOT" -type d -exec chmod 0755 {} \;
find "$PAYLOAD_ROOT" -type f -exec chmod 0644 {} \;
chmod 0755 "$PKG_SHARE"/bin/*
ok "metadata stripped, 0755 dirs, 0644 files, 0755 bin/"

# ─── 4. Fix permissions on installer scripts ─────────────────────────────────
chmod 0755 "$SCRIPTS_DIR/preinstall" "$SCRIPTS_DIR/postinstall"
ok "preinstall + postinstall are 0755"

# ─── 5. Build the pkg ────────────────────────────────────────────────────────
mkdir -p "$DIST_DIR"
OUT="$DIST_DIR/${PKG_NAME}-${PKG_VERSION}.pkg"
rm -f "$OUT"

say "Running pkgbuild → $OUT"
/usr/bin/pkgbuild \
  --root "$PAYLOAD_ROOT" \
  --scripts "$SCRIPTS_DIR" \
  --identifier "$PKG_ID" \
  --version "$PKG_VERSION" \
  --install-location "$INSTALL_LOCATION" \
  --ownership recommended \
  "$OUT"

# ─── 6. Verify ───────────────────────────────────────────────────────────────
say "Verifying pkg"
/usr/sbin/pkgutil --check-signature "$OUT" 2>/dev/null | sed 's/^/  /' || true

n_payload="$(/usr/sbin/pkgutil --payload-files "$OUT" 2>/dev/null | wc -l | tr -d ' ')"
ok "payload files: $n_payload"

pkg_size=$(/usr/bin/stat -f%z "$OUT")
ok "pkg size: $pkg_size bytes"

print -- ""
ok "Built: $OUT"
print -P -- "  Install:  %F{141}sudo /usr/sbin/installer -pkg \"$OUT\" -target /%f"
print -P -- "  Or:       %F{141}open \"$OUT\"%f  (uses Installer.app GUI)"
print -P -- "  Uninstall:%F{141}ewallis-terminal-uninstall --system%f"
