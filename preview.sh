#!/usr/bin/env zsh
# ─────────────────────────────────────────────────────────────────────────────
# preview.sh — open a sandboxed terminal and demo the theme live
# Launches a new iTerm2 / Terminal.app window running the demo inside /tmp
# ─────────────────────────────────────────────────────────────────────────────

SCRIPT_DIR="${0:A:h}"
DEMO_SCRIPT="$SCRIPT_DIR/preview_demo.sh"
SANDBOX=$(mktemp -d /tmp/theme-preview.XXXXXX)

# ── Write the demo that runs inside the new window ────────────────────────────
cat > "$DEMO_SCRIPT" <<DEMO
#!/usr/bin/env zsh
SANDBOX="$SANDBOX"
SCRIPT_DIR="$SCRIPT_DIR"

# ── colours ──────────────────────────────────────────────────────────────────
C_MAUVE="\033[38;5;141m"
C_GREEN="\033[38;5;114m"
C_PEACH="\033[38;5;215m"
C_TEAL="\033[38;5;116m"
C_RED="\033[38;5;203m"
C_DIM="\033[38;5;240m"
C_BOLD="\033[1m"
C_RST="\033[0m"

banner()  { print "\n\${C_MAUVE}\${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\${C_RST}"; \
            print "\${C_MAUVE}\${C_BOLD}  \$1\${C_RST}"; \
            print "\${C_MAUVE}\${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\${C_RST}"; }
step()    { print "\n\${C_PEACH}  ▶  \$1\${C_RST}"; sleep 0.4; }
ok()      { print "\${C_GREEN}  ✓  \$1\${C_RST}"; }
info()    { print "\${C_DIM}     \$1\${C_RST}"; }
pause()   { print "\n\${C_TEAL}  [ press Enter to continue ]\${C_RST}"; read -r; }

clear
banner "Catppuccin Theme — Sandbox Preview"
print "\${C_DIM}  Sandbox: \$SANDBOX\${C_RST}"
print "\${C_DIM}  Source:  \$SCRIPT_DIR\${C_RST}"
print "\${C_DIM}  Nothing outside this sandbox is touched.\${C_RST}"
pause

# ────────────────────────────────────────────────────────────────────────────
# 1. BUILD FAKE HOME
# ────────────────────────────────────────────────────────────────────────────
banner "Step 1 — Fake home structure"
step "Creating fake \$HOME at \$SANDBOX …"

export HOME="\$SANDBOX"
mkdir -p "\$SANDBOX"/{.config/fish,.local/bin,Library/{Preferences,Fonts}}

cat > "\$SANDBOX/.zshrc"           <<'ZSH'
# existing zshrc
export PATH="\$HOME/.local/bin:\$PATH"
alias ll="ls -la"
alias gs="git status"
ZSH

cat > "\$SANDBOX/.zprofile"        <<'ZSH'
# existing zprofile
eval "\$(/opt/homebrew/bin/brew shellenv)"
ZSH

cat > "\$SANDBOX/.bashrc"          <<'ZSH'
# existing bashrc
export EDITOR=vim
ZSH

cat > "\$SANDBOX/.config/fish/config.fish" <<'FISH'
# existing fish config
set -x EDITOR vim
FISH

cat > "\$SANDBOX/.config/starship.toml" <<'TOML'
# pre-existing starship config
format = "\$directory \$character"
[character]
success_symbol = "[>](green)"
TOML

cat > "\$SANDBOX/Library/Preferences/com.googlecode.iterm2.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>OldTheme</key><string>Default</string></dict></plist>
PLIST

ok ".zshrc, .zprofile, .bashrc, fish config, starship.toml, iTerm2 plist — created"
step "Snapshot of files BEFORE install:"
print ""
print "\${C_DIM}  ~/.zshrc:\${C_RST}"
sed 's/^/     /' "\$SANDBOX/.zshrc"
print "\${C_DIM}  ~/.config/starship.toml:\${C_RST}"
sed 's/^/     /' "\$SANDBOX/.config/starship.toml"
pause

# ────────────────────────────────────────────────────────────────────────────
# 2. STUB DESTRUCTIVE COMMANDS
# ────────────────────────────────────────────────────────────────────────────
banner "Step 2 — Stubbing destructive commands"
step "Installing stubs for: brew  defaults  plutil  killall  pgrep  open …"

STUB_BIN="\$SANDBOX/stub_bin"
mkdir -p "\$STUB_BIN"

cat > "\$STUB_BIN/brew" <<'STUB'
#!/usr/bin/env zsh
echo "  [brew stub]  brew \$*"
[[ "\$*" == *"list starship"* ]] && exit 1
[[ "\$*" == *"list --cask font"* ]] && exit 1
exit 0
STUB

cat > "\$STUB_BIN/defaults" <<'STUB'
#!/usr/bin/env zsh
echo "  [defaults stub]  defaults \$*"
[[ "\$*" == *"AppleInterfaceStyle"* ]] && { echo "Dark"; exit 0; }
exit 1
STUB

cat > "\$STUB_BIN/plutil" <<'STUB'
#!/usr/bin/env zsh
echo "  [plutil stub]  plutil \$*"
[[ "\$1" == "-lint" ]] && exit 0
# -convert: just copy last arg to -o destination
if [[ "\$1" == "-convert" ]]; then
  local out="" found=0
  for a in "\$@"; do
    (( found )) && { out="\$a"; found=0; }
    [[ "\$a" == "-o" ]] && found=1
  done
  [[ -n "\$out" ]] && cp "\${@[-1]}" "\$out" 2>/dev/null
fi
exit 0
STUB

for cmd in killall pgrep open curl; do
  printf '#!/usr/bin/env zsh\necho "  [%s stub]  %s \$*"\nexit 0\n' "\$cmd" "\$cmd" > "\$STUB_BIN/\$cmd"
done
# pgrep: iTerm2 not running
printf '#!/usr/bin/env zsh\necho "  [pgrep stub]  pgrep \$*"\nexit 1\n' > "\$STUB_BIN/pgrep"

chmod +x "\$STUB_BIN"/*
export PATH="\$STUB_BIN:\$PATH"
ok "All stubs ready — real brew/defaults/etc. will NOT be called"
pause

# ────────────────────────────────────────────────────────────────────────────
# 3. RUN INSTALL
# ────────────────────────────────────────────────────────────────────────────
banner "Step 3 — Running install.sh (sandboxed)"
sleep 0.5
zsh "\$SCRIPT_DIR/install.sh"

pause

# ────────────────────────────────────────────────────────────────────────────
# 4. SHOW WHAT CHANGED
# ────────────────────────────────────────────────────────────────────────────
banner "Step 4 — What install.sh changed"

step "backup/manifest.txt:"
sed 's/^/     /' "\$SCRIPT_DIR/backup/manifest.txt" 2>/dev/null || echo "     (not found)"

step "~/.zshrc after install:"
sed 's/^/     /' "\$SANDBOX/.zshrc"

step "~/.config/starship.toml (first 30 lines):"
head -30 "\$SANDBOX/.config/starship.toml" | sed 's/^/     /'

step "backup files created:"
ls -lh "\$SCRIPT_DIR/backup/" | sed 's/^/     /'

step "toggle script:"
cat "\$SANDBOX/.local/bin/toggle-starship-theme" 2>/dev/null | sed 's/^/     /' || echo "     (not found)"

pause

# ────────────────────────────────────────────────────────────────────────────
# helpers
# ────────────────────────────────────────────────────────────────────────────

# segment BG_CODE FG_CODE " text " NEXT_BG_CODE
seg() {
  local bg="\033[48;5;\${1}m" fg="\033[38;5;\${2}m" nbg="\033[48;5;\${4}m"
  printf "\${bg}\${fg} \${3} \033[0m"
  [[ -n "\$4" ]] && printf "\033[38;5;\${1}m\${nbg}\033[0m"
}
segend() { printf "\033[38;5;\${1}m\033[0m\n"; }   # closing arrow
prompt() { printf "  "; }
cursor() { print "  \033[38;5;114m❯\033[0m \$*"; }

# ── Segments: colours ──
M=141   # mauve bg
PK=218  # pink bg
BL=111  # blue bg
GR=114  # green bg
TL=116  # teal bg
S0=236  # surface0 bg
FG=235  # dark fg (on coloured bg)

# ────────────────────────────────────────────────────────────────────────────
# 5a — BASE PROMPT (OS, user, dir, git)
# ────────────────────────────────────────────────────────────────────────────
banner "5a — Base prompt: OS · user · directory · git"
print ""
print "  \033[38;5;240m  ~/projects  (no language detected)\033[0m"
prompt; seg \$M  \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 ~/projects" \$BL
        seg \$BL \$FG "󰘬 main" ""
        segend \$BL
cursor "_"
print ""

print "  \033[38;5;240m  git: modified + untracked files\033[0m"
prompt; seg \$M  \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 loubot" \$BL
        seg \$BL \$FG "󰘬 main 󰏭 󰋗 " ""
        segend \$BL
cursor "_"
print ""

print "  \033[38;5;240m  git: staged + ahead of remote\033[0m"
prompt; seg \$M  \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 loubot" \$BL
        seg \$BL \$FG "󰘬 main 󰐕 󰜷2" ""
        segend \$BL
cursor "_"
print ""

print "  \033[38;5;240m  git: behind + conflicted\033[0m"
prompt; seg \$M  \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 loubot" \$BL
        seg \$BL \$FG "󰘬 main 󰀨 󰜮3" ""
        segend \$BL
cursor "_"
print ""

print "  \033[38;5;240m  read-only directory\033[0m"
prompt; seg \$M  \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 /etc 󰌾" \$BL
        seg \$BL \$FG "󰘬 main" ""
        segend \$BL
cursor "_"
print ""
pause

# ────────────────────────────────────────────────────────────────────────────
# 5b — LANGUAGE SEGMENTS
# ────────────────────────────────────────────────────────────────────────────
banner "5b — Language segments (appear when detected)"
print ""

print "  \033[38;5;240m  Python project\033[0m"
prompt; seg \$M  \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 loubot" \$BL
        seg \$BL \$FG "󰘬 main" \$GR
        seg \$GR \$FG "󰌠 v3.12 (venv)" \$TL
        segend \$TL
cursor "_"
print ""

print "  \033[38;5;240m  Node.js project\033[0m"
prompt; seg \$M  \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 my-app" \$BL
        seg \$BL \$FG "󰘬 main" \$GR
        seg \$GR \$FG "󰌠 v3.12" \$TL
        seg \$TL \$FG "󰎙 v20.11" \$S0
        segend \$S0
cursor "_"
print ""

print "  \033[38;5;240m  Rust project\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 my-crate" \$BL
        seg \$BL \$FG "󰘬 main" \$GR
        seg \$GR \$FG "󰌠 v3.12" \$TL
        seg \$TL \$FG "󰎙 v20.11" \$S0
        seg \$S0 215  "󱘗 v1.77" ""
        segend \$S0
cursor "_"
print ""

print "  \033[38;5;240m  Go project\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 my-service" \$BL
        seg \$BL \$FG "󰘬 main" \$GR
        seg \$GR \$FG "󰌠 v3.12" \$TL
        seg \$TL \$FG "󰎙 v20.11" \$S0
        seg \$S0 116  "󰟓 v1.22" ""
        segend \$S0
cursor "_"
print ""

print "  \033[38;5;240m  Java project\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 spring-app" \$BL
        seg \$BL \$FG "󰘬 main" \$TL
        seg \$TL \$FG "󰎙 v20.11" \$S0
        seg \$S0 229  "󰬷 v21" ""
        segend \$S0
cursor "_"
print ""

print "  \033[38;5;240m  Ruby · PHP · Swift · Kotlin · Lua\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 rails-app" \$S0
        seg \$S0 203  "󰴭 v3.3" \$S0
        seg \$S0 141  "󰌟 v8.3" \$S0
        seg \$S0 215  "󰛥 v5.10" \$S0
        seg \$S0 141  "󱈙 v1.9" \$S0
        seg \$S0 111  "󰢱 v5.4" ""
        segend \$S0
cursor "_"
print ""

print "  \033[38;5;240m  Elixir · Erlang · Scala · Haskell · Zig\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 phoenix" \$S0
        seg \$S0 141  " v1.16" \$S0
        seg \$S0 203  " v26" \$S0
        seg \$S0 203  " v3.4" \$S0
        seg \$S0 141  "󰲒 v9.8" \$S0
        seg \$S0 215  " v0.13" ""
        segend \$S0
cursor "_"
print ""
pause

# ────────────────────────────────────────────────────────────────────────────
# 5c — DEVOPS / CLOUD SEGMENTS
# ────────────────────────────────────────────────────────────────────────────
banner "5c — DevOps & Cloud segments"
print ""

print "  \033[38;5;240m  Docker context active\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 loubot" \$BL
        seg \$BL \$FG "󰘬 main" \$GR
        seg \$GR \$FG "󰌠 v3.12" \$S0
        seg \$S0 111  "󰡨 desktop-linux" ""
        segend \$S0
cursor "_"
print ""

print "  \033[38;5;240m  Kubernetes context\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 k8s-app" \$BL
        seg \$BL \$FG "󰘬 main" \$GR
        seg \$GR \$FG "󰌠 v3.12" \$S0
        seg \$S0 111  "󱃾 prod [default]" ""
        segend \$S0
cursor "_"
print ""

print "  \033[38;5;240m  AWS profile\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 infra" \$BL
        seg \$BL \$FG "󰘬 main" \$S0
        seg \$S0 215  "󰸏 prod [us-east-1]" ""
        segend \$S0
cursor "_"
print ""

print "  \033[38;5;240m  GCP project\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 infra" \$S0
        seg \$S0 111  "󱇶 my-project [us-central1]" ""
        segend \$S0
cursor "_"
print ""

print "  \033[38;5;240m  Azure subscription\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 infra" \$S0
        seg \$S0 111  "󰠅 my-subscription" ""
        segend \$S0
cursor "_"
print ""

print "  \033[38;5;240m  Terraform workspace\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 terraform" \$BL
        seg \$BL \$FG "󰘬 main" \$S0
        seg \$S0 141  "󱁢 staging" ""
        segend \$S0
cursor "_"
print ""

print "  \033[38;5;240m  Conda env + package version\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 ml-project" \$BL
        seg \$BL \$FG "󰘬 main" \$GR
        seg \$GR \$FG "󰌠 v3.12" \$S0
        seg \$S0 114  "󰏗 myenv" \$S0
        seg \$S0 215  "󰏗 v0.1.0" ""
        segend \$S0
cursor "_"
print ""
pause

# ────────────────────────────────────────────────────────────────────────────
# 5d — RIGHT SIDE: duration + time
# ────────────────────────────────────────────────────────────────────────────
banner "5d — Right side: command duration + clock"
print ""
print "  \033[38;5;240m  Normal command (no duration shown < 500ms)\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 loubot" \$BL
        seg \$BL \$FG "󰘬 main" \$GR
        seg \$GR \$FG "󰌠 v3.12" ""
        segend \$GR
printf "                          "
print "\033[38;5;245m󰥔 22:31\033[0m"
cursor "_"
print ""

print "  \033[38;5;240m  Long command (duration shown ≥ 500ms)\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 loubot" \$BL
        seg \$BL \$FG "󰘬 main" \$GR
        seg \$GR \$FG "󰌠 v3.12" ""
        segend \$GR
printf "           "
print "\033[38;5;229m󱎫 12s342ms\033[0m  \033[38;5;245m󰥔 22:31\033[0m"
cursor "_"
print ""

print "  \033[38;5;240m  Error exit (prompt turns red)\033[0m"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 loubot" \$BL
        seg \$BL \$FG "󰘬 main" \$GR
        seg \$GR \$FG "󰌠 v3.12" ""
        segend \$GR
printf "                          "
print "\033[38;5;245m󰥔 22:31\033[0m"
print "  \033[38;5;203m❯\033[0m _"
print ""
pause

# ────────────────────────────────────────────────────────────────────────────
# 5e — LIGHT MODE (Latte)
# ────────────────────────────────────────────────────────────────────────────
banner "5e — Light mode: Catppuccin Latte palette"
print ""
print "  \033[38;5;240m  Same structure, lighter palette\033[0m"
print ""
# Latte colours (approximate in 256-color)
LM=135   # mauve
LPK=170  # pink
LBL=27   # blue
LGR=34   # green
LTL=30   # teal
LS0=252  # surface0
LFG=255  # light fg

print "  \033[38;5;240m  Python + git — Latte\033[0m"
prompt
printf "\033[48;5;135m\033[38;5;255m  dangnguyen \033[0m"
printf "\033[38;5;135m\033[48;5;170m\033[0m"
printf "\033[48;5;170m\033[38;5;255m 󰉋 loubot \033[0m"
printf "\033[38;5;170m\033[48;5;27m\033[0m"
printf "\033[48;5;27m\033[38;5;255m 󰘬 main \033[0m"
printf "\033[38;5;27m\033[48;5;34m\033[0m"
printf "\033[48;5;34m\033[38;5;255m 󰌠 v3.12 \033[0m"
printf "\033[38;5;34m\033[0m"
print ""
print "  \033[38;5;34m❯\033[0m _"
print ""

print "  \033[38;5;240m  Docker + AWS — Latte\033[0m"
prompt
printf "\033[48;5;135m\033[38;5;255m  dangnguyen \033[0m"
printf "\033[38;5;135m\033[48;5;170m\033[0m"
printf "\033[48;5;170m\033[38;5;255m 󰉋 infra \033[0m"
printf "\033[38;5;170m\033[48;5;27m\033[0m"
printf "\033[48;5;27m\033[38;5;255m 󰘬 main \033[0m"
printf "\033[38;5;27m\033[48;5;252m\033[0m"
printf "\033[48;5;252m\033[38;5;27m 󰡨 desktop \033[0m"
printf "\033[38;5;252m\033[48;5;252m\033[0m"
printf "\033[48;5;252m\033[38;5;202m 󰸏 prod \033[0m"
printf "\033[38;5;252m\033[0m"
print ""
print "  \033[38;5;34m❯\033[0m _"
print ""
pause

# ────────────────────────────────────────────────────────────────────────────
# 5f — LIVE COMMANDS
# ────────────────────────────────────────────────────────────────────────────
banner "5f — Live command simulation"
print ""

cursor "\033[38;5;229mcd ~/projects/loubot\033[0m"
print ""
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 loubot" \$BL
        seg \$BL \$FG "󰘬 release" \$GR
        seg \$GR \$FG "󰌠 v3.11" ""
        segend \$GR
cursor "\033[38;5;229mls -a\033[0m"
print "  \033[38;5;116m.git\033[0m         \033[38;5;229mDockerfile\033[0m    \033[38;5;114mloubot\033[0m       \033[38;5;203mscripts\033[0m"
print "  \033[38;5;116m.gitignore\033[0m   \033[38;5;229mREADME.md\033[0m     \033[38;5;114mpoetry.lock\033[0m  \033[38;5;203mtests\033[0m"
print "  \033[38;5;116m.dockerignore\033[0m \033[38;5;229mk8s/\033[0m         \033[38;5;114mpyproject.toml\033[0m"
print "  \033[38;5;116m.vscode/\033[0m     \033[38;5;229mREADME.md\033[0m     \033[38;5;114mpoetry.lock\033[0m"
print ""
cursor "\033[38;5;229mgit status\033[0m"
print "  \033[38;5;240mOn branch \033[0m\033[38;5;111mrelease\033[0m"
print "  \033[38;5;114mnothing to commit, working tree clean\033[0m"
print ""
cursor "\033[38;5;229mgit log --oneline -3\033[0m"
print "  \033[38;5;229mf3a1c9b\033[0m \033[38;5;114mfeat: add async message handler\033[0m"
print "  \033[38;5;229ma7d2e31\033[0m \033[38;5;116mfix: retry logic on timeout\033[0m"
print "  \033[38;5;229m91bc44f\033[0m \033[38;5;245mchore: update dependencies\033[0m"
print ""
cursor "\033[38;5;229mpython --version\033[0m"
print "  Python 3.11.8"
print ""
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 loubot" \$BL
        seg \$BL \$FG "󰘬 release" \$GR
        seg \$GR \$FG "󰌠 v3.11" ""
        segend \$GR
printf "                "
print "\033[38;5;229m󱎫 42ms\033[0m  \033[38;5;245m󰥔 22:31\033[0m"
cursor "_"
print ""
pause

# ────────────────────────────────────────────────────────────────────────────
# 5g — STYLE B: text-only colors (no background blocks)
# ────────────────────────────────────────────────────────────────────────────
banner "5g — Style B: text-only colors, no background"
print ""
print "  \${C_DIM}  Each segment is plain colored text — no filled blocks\${C_RST}"
print ""

# Style B helpers — fg only, no bg
sb_user()  { printf "\033[38;5;141m  \$1\033[0m"; }         # mauve
sb_dir()   { printf "  \033[38;5;218m󰉋 \$1\033[0m"; }       # pink
sb_git()   { printf "  \033[38;5;111m󰘬 \$1\033[0m"; }       # blue
sb_py()    { printf "  \033[38;5;114m󰌠 \$1\033[0m"; }       # green
sb_node()  { printf "  \033[38;5;116m󰎙 \$1\033[0m"; }       # teal
sb_rust()  { printf "  \033[38;5;215m󱘗 \$1\033[0m"; }       # peach
sb_go()    { printf "  \033[38;5;116m󰟓 \$1\033[0m"; }       # sky/teal
sb_java()  { printf "  \033[38;5;229m󰬷 \$1\033[0m"; }       # yellow
sb_docker(){ printf "  \033[38;5;111m󰡨 \$1\033[0m"; }       # blue
sb_k8s()   { printf "  \033[38;5;111m󱃾 \$1\033[0m"; }       # blue
sb_aws()   { printf "  \033[38;5;215m󰸏 \$1\033[0m"; }       # peach
sb_dur()   { printf "  \033[38;5;229m󱎫 \$1\033[0m"; }       # yellow
sb_time()  { printf "  \033[38;5;245m󰥔 \$1\033[0m"; }       # subtext
sb_nl_ok() { printf "\n  \033[38;5;114m❯\033[0m "; }        # green ❯
sb_nl_err(){ printf "\n  \033[38;5;203m❯\033[0m "; }        # red ❯

print "  \${C_DIM}  basic dir + git\${C_RST}"
printf "  "; sb_user "dangnguyen"; sb_dir "~/projects"; sb_git "main"; sb_nl_ok; print "_\n"

print "  \${C_DIM}  git: modified + untracked\${C_RST}"
printf "  "; sb_user "dangnguyen"; sb_dir "loubot"
printf "  \033[38;5;111m󰘬 main  \033[38;5;215m󰏭 󰋗\033[0m"
sb_nl_ok; print "_\n"

print "  \${C_DIM}  git: staged + ahead of remote\${C_RST}"
printf "  "; sb_user "dangnguyen"; sb_dir "loubot"
printf "  \033[38;5;111m󰘬 main  \033[38;5;114m󰐕  \033[38;5;229m󰜷2\033[0m"
sb_nl_ok; print "_\n"

print "  \${C_DIM}  Python + Node.js\${C_RST}"
printf "  "; sb_user "dangnguyen"; sb_dir "loubot"; sb_git "main"
sb_py "v3.12 (venv)"; sb_node "v20.11"; sb_nl_ok; print "_\n"

print "  \${C_DIM}  Python + Rust + Go\${C_RST}"
printf "  "; sb_user "dangnguyen"; sb_dir "my-crate"; sb_git "main"
sb_py "v3.12"; sb_rust "v1.77"; sb_go "v1.22"; sb_nl_ok; print "_\n"

print "  \${C_DIM}  Java + Ruby + Swift\${C_RST}"
printf "  "; sb_user "dangnguyen"; sb_dir "spring-app"; sb_git "main"; sb_java "v21"
printf "  \033[38;5;203m󰴭 v3.3\033[0m"
printf "  \033[38;5;215m󰛥 v5.10\033[0m"
sb_nl_ok; print "_\n"

print "  \${C_DIM}  Docker + Kubernetes + AWS\${C_RST}"
printf "  "; sb_user "dangnguyen"; sb_dir "infra"; sb_git "main"
sb_docker "desktop-linux"; sb_k8s "prod[default]"; sb_aws "prod[us-east-1]"
sb_nl_ok; print "_\n"

print "  \${C_DIM}  command duration + clock (right side)\${C_RST}"
printf "  "; sb_user "dangnguyen"; sb_dir "loubot"; sb_git "release"; sb_py "v3.11"
printf "               "; sb_dur "12s342ms"; sb_time "22:31"
sb_nl_ok; print "_\n"

print "  \${C_DIM}  error exit (❯ turns red)\${C_RST}"
printf "  "; sb_user "dangnguyen"; sb_dir "loubot"; sb_git "main"
sb_nl_err; print "_\n"

pause

# ────────────────────────────────────────────────────────────────────────────
# STYLE CHOICE REMINDER
# ────────────────────────────────────────────────────────────────────────────
banner "Style comparison"
print ""
print "  \${C_MAUVE}\${C_BOLD}Style A — Powerline (solid backgrounds):\${C_RST}"
prompt; seg \$M \$FG "  dangnguyen" \$PK
        seg \$PK \$FG "󰉋 loubot" \$BL
        seg \$BL \$FG "󰘬 main" \$GR
        seg \$GR \$FG "󰌠 v3.12" ""
        segend \$GR
print ""
print ""
print "  \${C_MAUVE}\${C_BOLD}Style B — Text only (no backgrounds):\${C_RST}"
printf "  "; sb_user "dangnguyen"; sb_dir "loubot"; sb_git "main"; sb_py "v3.12"
sb_nl_ok; print "_"
print ""
print "  \${C_TEAL}Tell Claude which style you want installed!\${C_RST}"
print ""
pause

# ────────────────────────────────────────────────────────────────────────────
# 6. RUN REVERT
# ────────────────────────────────────────────────────────────────────────────
banner "Step 6 — Running revert.sh (sandboxed)"
sleep 0.5
zsh "\$SCRIPT_DIR/revert.sh"

pause

# ────────────────────────────────────────────────────────────────────────────
# 7. SHOW WHAT REVERT RESTORED
# ────────────────────────────────────────────────────────────────────────────
banner "Step 7 — What revert.sh restored"

step "~/.zshrc after revert:"
sed 's/^/     /' "\$SANDBOX/.zshrc"

step "~/.config/starship.toml after revert:"
sed 's/^/     /' "\$SANDBOX/.config/starship.toml" 2>/dev/null || echo "     (file removed — did not exist before install)"

step "toggle script after revert:"
[[ -f "\$SANDBOX/.local/bin/toggle-starship-theme" ]] \
  && echo "     still exists (unexpected)" \
  || ok "toggle script removed"

print ""
print "\${C_GREEN}\${C_BOLD}  Preview complete! Your real system was never touched.\${C_RST}"
print "\${C_DIM}  Sandbox \$SANDBOX will be cleaned up automatically.\${C_RST}"
print ""
print "  When you'\''re ready to install for real, run:"
print "  \${C_MAUVE}  cd \$SCRIPT_DIR && zsh install.sh\${C_RST}"
print ""

# cleanup sandbox + demo script
rm -rf "\$SANDBOX"
rm -f "\$SCRIPT_DIR/preview_demo.sh"
rm -rf "\$SCRIPT_DIR/backup"   # wipe test backup so real install is clean
print "\${C_DIM}  [ sandbox cleaned — you can close this window ]\${C_RST}\n"
DEMO

chmod +x "$DEMO_SCRIPT"

# ── Ensure JetBrainsMono Nerd Font is installed (required for icons) ──────────
FONT_NAME="JetBrainsMonoNFM-Regular 13"
local _nf=( "$HOME/Library/Fonts"/JetBrainsMonoNerdFont*(N) /Library/Fonts/JetBrainsMonoNerdFont*(N) )
if [[ ${#_nf} -eq 0 ]]; then
  print -P "%F{141}===>%f Installing JetBrainsMono Nerd Font (needed to render icons)…"
  if command -v brew &>/dev/null; then
    brew install --cask font-jetbrains-mono-nerd-font
  else
    print -P "%F{214}  brew not found — icons may not render. Install JetBrainsMono Nerd Font manually.%f"
    FONT_NAME=""
  fi
else
  print -P "%F{114} JetBrainsMono Nerd Font already installed%f"
fi

# ── Launch in iTerm2 or fall back to Terminal.app ─────────────────────────────
if [[ -d "/Applications/iTerm.app" ]]; then
  osascript <<APPLE
    tell application "iTerm2"
      activate
      set newWindow to (create window with default profile)
      tell current session of newWindow
        set normal font to "$FONT_NAME"
        write text "zsh '$DEMO_SCRIPT'"
      end tell
    end tell
APPLE
elif [[ -d "/Applications/Utilities/Terminal.app" || -d "/System/Applications/Utilities/Terminal.app" ]]; then
  osascript <<APPLE
    tell application "Terminal"
      activate
      do script "zsh '$DEMO_SCRIPT'"
    end tell
APPLE
else
  # Fallback: just run inline
  echo "No GUI terminal found — running inline:"
  zsh "$DEMO_SCRIPT"
fi
