# EwallisTerminal

A polished, opinionated terminal setup for macOS — Catppuccin colors, Starship prompt with Material Design icons, zsh productivity plugins, and a single `ew` CLI to control everything.

Two ways to use it:

1. **Just the looks** — import a ready-made Terminal.app profile (colors + font + window settings in one `.terminal` file). No installer, no shell changes, removable with one click.
2. **The full experience** — a `.pkg` installer that adds the Starship prompt, welcome banner, zsh plugins, and the `ew` CLI, with atomic backups, full uninstall, and self-service updates.

---

## Quick start: just the profile (no install)

Each Catppuccin palette ships as a standalone Terminal.app profile carrying **all** visual settings — 16 ANSI colors + background/text/cursor/selection, JetBrainsMono Nerd Font 13, 120×32 window, block cursor, 10k scrollback, Option-as-Meta:

```
pkg/payload/usr/local/share/ewallis-terminal/terminal/
├── EwallisTerminal-latte.terminal      light
├── EwallisTerminal-frappe.terminal     dark · low contrast
├── EwallisTerminal-macchiato.terminal  dark · mid contrast
└── EwallisTerminal-mocha.terminal      dark · high contrast
```

```sh
# 1. Install the font once (the only thing a profile file can't embed)
brew install --cask font-jetbrains-mono-nerd-font

# 2. Plug in — the profile appears in Terminal → Settings → Profiles
open pkg/payload/usr/local/share/ewallis-terminal/terminal/EwallisTerminal-mocha.terminal
```

Click **Default** in the Profiles pane to make it stick. To remove: select it, press **−**. Nothing else on your system is touched.

A Terminal profile only carries *looks* — the Starship prompt, banner, and zsh plugins are shell features and need the `.pkg` below.

---

## Highlights

- **One CLI to rule them all** — `ew theme · welcome · doctor · setup · update · uninstall · banner-on/off`
- **Live palette switching** — `ew theme latte` flips Terminal.app + iTerm2 colors + Starship + plugin highlights *without* reinstalling
- **Terminal.app native** — a managed "EwallisTerminal" profile in Terminal → Settings → Profiles; also available as standalone `.terminal` files for manual import (see Quick start)
- **4 Catppuccin palettes** — Latte (light), Frappé (dark/low), Macchiato (dark/mid), Mocha (dark/high)
- **Welcome banner** — Catppuccin-themed startup splash inspired by Claude Code v2 (toggle with `ew banner-on/off`)
- **ESC×2 session history picker** — when prompt is empty, double-ESC opens an fzf-powered picker of commands typed in this terminal tab; when prompt has text, double-ESC clears it
- **Ctrl+F path picker** — fzf browser for the path under your cursor (or the current directory on an empty line); explicit keybinding only, never auto-triggers while you type
- **Zsh productivity stack** — vendored `zsh-autosuggestions` + `zsh-syntax-highlighting` + `fzf` integration (offline-safe, palette-themed)
- **Self-service updates** — `ew update` pulls latest from GitHub Releases, SHA256-verifies, installs
- **Atomic, reversible** — every change is backed up; `ew uninstall` restores your prior state byte-for-byte
- **Pre-flight checks** — `ew doctor` detects + offers to brew-install missing deps (starship, fzf, JetBrains Mono Nerd Font)
- **`ew doctor --self-test`** — 11-step sandboxed install → theme → uninstall cycle for regression catching

---

## Install (full experience)

One-line install (downloads + verifies + runs Apple's installer):

```sh
curl -fLO https://github.com/ewalliss/Terminal/releases/latest/download/EwallisTerminal-2.3.0.pkg
sudo installer -pkg EwallisTerminal-2.3.0.pkg -target /
```

Or download the `.pkg` from the [latest release](https://github.com/ewalliss/Terminal/releases/latest) and double-click.

After install, open a **new** terminal tab — the welcome banner appears, and `ew` is on PATH.

### Upgrade

```sh
ew update          # fetches latest from GitHub Releases, sha256-verifies, installs
ew update --check  # just check; don't install
```

---

## The `ew` CLI

```
ew                      Show current status (palette, banner state, version)
ew theme <palette>      Switch palette: latte | frappe | macchiato | mocha
ew theme --auto         Follow macOS Dark/Light mode
ew theme --style A|B    Powerline (A) or text-only (B) Starship segments
ew welcome              Print the Catppuccin welcome banner right now
ew banner-on            Show banner on every new shell (default)
ew banner-off           Disable banner
ew banner-toggle        Flip current state
ew doctor               Check deps; offer to brew-install missing ones
ew doctor --self-test   Sandboxed install/theme/uninstall regression test
ew setup                Re-run per-user setup (rc inject, plugin theme deploy)
ew update               Pull latest release from GitHub + install
ew uninstall            User-level removal (restores all backups)
ew uninstall --system   Full removal including system files (requires sudo)
ew help                 Full subcommand reference
ew version              Installed version
```

---

## Palettes & Styles

### Palette aliases

| Command | Resolved palette | Mode | Contrast |
|---|---|---|---|
| `ew theme latte`     | `catppuccin_latte`     | light | — |
| `ew theme frappe`    | `catppuccin_frappe`    | dark  | low |
| `ew theme macchiato` | `catppuccin_macchiato` | dark  | mid |
| `ew theme mocha`     | `catppuccin_mocha`     | dark  | high |
| `ew theme light`     | latte                  | light | — |
| `ew theme dark`      | mocha                  | dark  | high |
| `ew theme --mode dark --contrast low`  | frappe    | dark | low |
| `ew theme --mode dark --contrast high` | mocha     | dark | high |

### Style A — Powerline (solid background segments)

```
  dangnguyen  󰉋 loubot   󰘬 main 󰏭 󰋗    󰌠 v3.12   󰎙 v20.11        󱎫 12s  󰥔 22:31
❯
```

### Style B — Text-only (colored, no backgrounds) — *default*

```
  dangnguyen  󰉋 loubot  󰘬 main  󰌠 v3.12  󰎙 v20.11               󱎫 12s  󰥔 22:31
❯
```

Switch with `ew theme --style A` or `ew theme --style B`.

---

## What gets installed

Everything ships under one directory plus one PATH binary:

```
/usr/local/share/ewallis-terminal/
├── bin/                          ew, ew-theme, ew-welcome, ew-doctor, ew-setup, ew-uninstall
├── configs/                      starship-style-a.toml, starship-style-b.toml (all 4 palettes baked in)
├── iterm2/                       4 dynamic profile JSONs + 2 .itermcolors presets
├── terminal/                     4 Terminal.app .terminal profiles (also manually importable)
├── plugin-themes/                4 palette-specific zsh files (autosuggest + syntax-highlight + fzf colors)
├── plugins/
│   ├── zsh-autosuggestions/      vendored v0.7.1 (offline-safe)
│   └── zsh-syntax-highlighting/  vendored 0.8.0
├── snippets/                     zshrc.sh, zprofile.sh, bashrc.sh, fish.fish
├── VERSION                       2.3.0
└── update-source.toml            GitHub repo for `ew update`

/usr/local/bin/ew                  → /usr/local/share/.../bin/ew    (single PATH binary)
```

Per-user state:

```
~/.config/ewallis-terminal/
├── state.toml                    palette, style, schema_version
├── plugin-theme.zsh              regenerated on every `ew theme`
├── fzf-prefix                    cached `brew --prefix fzf` (saves ~80ms / shell startup)
└── banner.disabled               (only exists when banner is off)

~/.local/share/ewallis-terminal/
├── install.manifest              TSV of every deployed/backed-up file
├── backups/<timestamp>/          atomic copies of any file we modified
├── needs-doctor                  (only exists when deps are missing)
└── postinstall.log               install transcript
```

Your shell rc files (`.zshrc`, `.zprofile`, `.bashrc`, fish config) get a single marker-bounded block injected:

```sh
# >>> ewallis-terminal >>>
# Managed block — do not edit between these markers.
# ... plugins, starship init, ESC widget, banner trigger ...
# <<< ewallis-terminal <<<
```

Your existing content is backed up before injection, and `ew uninstall` strips the block cleanly.

Terminal.app gets a managed **"EwallisTerminal"** profile (imported via `defaults`, set as your default profile — your previous default is recorded in the manifest and restored on uninstall). `ew theme` rewrites this single profile slot in place, so palette switches never accumulate duplicate profiles.

---

## Productivity features

### ESC × 2

| Buffer state | Action |
|---|---|
| Empty | Open fzf picker of commands typed in this terminal tab (most recent 50, deduped, newest first) — type to filter, Enter to load into prompt |
| Has text | Clear the line instantly |

The picker shows **session-only history**, not your full `~/.zsh_history` — exactly what you typed in *this* tab since it opened.

### Ctrl+F path picker

Press **Ctrl+F** while typing a path (after `cd`, `ls`, `vim`, …) — or on an empty line — to open an fzf browser of the target directory, grouped into Folders / Files / Other. Selecting a folder drills into it; selecting a file inserts it into your command line. Deliberately bound to an explicit key only: it never auto-opens while you type.

### Welcome banner

Inspired by Claude Code v2's `LogoV2` layout — rounded box with inset title, two columns separated by a divider, ASCII robot mascot on the left, tips + what's new on the right. Colors flip automatically when you change palette.

Disable with `ew banner-off`. Per-shell skip: `EWALLIS_NO_BANNER=1 zsh`.

### Plugins

- **zsh-autosuggestions** — ghost-text completion from your history
- **zsh-syntax-highlighting** — command coloring as you type
- **fzf** integration — `Ctrl-R` for history, `Ctrl-T` for files, `Alt-C` for directories (binary not vendored — installed via `brew`; `ew doctor` will offer to install it)

All three are palette-themed: their colors are regenerated by `ew theme` so they match your active Catppuccin variant.

---

## Requirements

| Tool | Required? | Auto-installed via `ew doctor` |
|---|---|---|
| macOS | yes | — |
| Homebrew | yes | no (run `brew.sh` install first) |
| Starship | yes | ✓ `brew install starship` |
| fzf | recommended | ✓ `brew install fzf` |
| JetBrainsMono Nerd Font | recommended | ✓ `brew install --cask font-jetbrains-mono-nerd-font` |
| iTerm2 | recommended | ✓ `brew install --cask iterm2` (soft-warn only) |

Run `ew doctor` after install and accept the install prompt — it handles all of the above.

---

## Uninstall

```sh
ew uninstall              # restore your prior state (shell rcs, starship.toml, iTerm2 profile)
ew uninstall --system     # same, plus remove /usr/local/share/ewallis-terminal/ (needs sudo)
ew uninstall --dry-run    # show what would happen, don't change anything
```

`ew uninstall` reads the install manifest, restores every pre-existing file from backup, strips the marker block from shell rcs, removes any file we deployed, removes the Terminal.app profile (restoring your previous default profile), and prunes empty directories. Zero residue.

---

## Architecture notes

- **Atomic writes** — every file is written to `<dst>.tmp.$$` then `mv -f` into place. Crash-safe.
- **Marker-bounded injection** — shell rcs get a single managed block; outside markers is yours. Re-runs strip + replace the block, never duplicate.
- **Manifest-driven uninstall** — TSV log of every action (deployed/injected/backup) drives the reversal.
- **Concurrency lock** — `mkdir`-based atomic lock prevents torn writes when two tabs run `ew theme` simultaneously.
- **Plugin double-load guards** — `(( $+functions[_zsh_highlight] ))` skip if you already have it from oh-my-zsh or brew.
- **SHA256-verified updates** — `ew update` refuses to install a `.pkg` whose sidecar SHA doesn't match.
- **Schema version** — `state.toml` carries `schema_version = 2` for forward compatibility.
- **No daemons, no LaunchAgents** — pure file-based state. Nothing runs in the background.

---

## Colors

### Mocha (dark · default)

| Role | Hex |
|---|---|
| Background | `#1e1e2e` |
| Text | `#cdd6f4` |
| Peach (border, mascot) | `#fab387` |
| Pink (mascot eyes) | `#f38ba8` |
| Mauve | `#cba6f7` |
| Blue | `#89b4fa` |
| Green | `#a6e3a1` |
| Teal | `#94e2d5` |

### Latte (light)

| Role | Hex |
|---|---|
| Background | `#eff1f5` |
| Text | `#4c4f69` |
| Peach (border, mascot) | `#fe640b` |
| Red (mascot eyes) | `#d20f39` |
| Mauve | `#8839ef` |
| Blue | `#1e66f5` |
| Green | `#40a02b` |
| Teal | `#179299` |

Frappé and Macchiato fall between these — full palette data in `pkg/tools/build-iterm-profile.py`.

---

## Building from source

If you want to rebuild the `.pkg` yourself:

```sh
git clone https://github.com/ewalliss/Terminal.git ~/Terminal
cd ~/Terminal
zsh pkg/build.sh
# → dist/EwallisTerminal-2.3.0.pkg + .sha256 sidecar
```

The build script vendors plugins (clones pinned tags), generates 4 iTerm2 profiles + 4 Terminal.app profiles + 4 plugin themes + 2 merged Starship configs from Catppuccin palette data, then runs `pkgbuild`.

---

## IDE Terminal Icons

If icons appear as boxes `?` in your IDE's terminal, set the font to **JetBrainsMono Nerd Font Mono**:

**VS Code / Cursor** — `settings.json`:
```json
"terminal.integrated.fontFamily": "JetBrainsMono Nerd Font Mono"
```

**Zed** — `~/.config/zed/settings.json`:
```json
"terminal": { "font_family": "JetBrainsMono Nerd Font Mono" }
```

**JetBrains IDEs** — Settings → Tools → Terminal → Font

---

## Segments & Icons

All icons use the [Material Design](https://pictogrammers.com/library/mdi/) Nerd Font set (`nf-md-*`). Segments appear automatically when the relevant tool is detected in your current directory.

| Segment | Icon | Color |
|---|---|---|
| OS (Apple) | `` | Mauve |
| Username | — | Mauve |
| Directory | `󰉋` | Pink |
| Git branch | `󰘬` | Blue |
| Git modified | `󰏭` | Blue |
| Git staged | `󰐕` | Blue |
| Git untracked | `󰋗` | Blue |
| Git ahead/behind | `󰜷` `󰜮` | Blue |
| Python | `󰌠` | Green |
| Node.js | `󰎙` | Teal |
| Rust | `󱘗` | Peach |
| Go | `󰟓` | Sky |
| Java | `󰬷` | Yellow |
| Ruby | `󰴭` | Red |
| PHP | `󰌟` | Mauve |
| Swift | `󰛥` | Peach |
| Kotlin | `󱈙` | Mauve |
| Docker | `󰡨` | Blue |
| Kubernetes | `󱃾` | Blue |
| AWS | `󰸏` | Peach |
| GCP | `󱇶` | Blue |
| Azure | `󰠅` | Blue |
| Terraform | `󱁢` | Mauve |
| Command duration | `󱎫` | Yellow |
| Clock | `󰥔` | Subtext |

---

## License

MIT — use freely, modify as needed.

---

## Acknowledgments

- [Catppuccin](https://github.com/catppuccin/catppuccin) — the gorgeous color palettes
- [Starship](https://starship.rs) — the prompt engine
- [Nerd Fonts](https://www.nerdfonts.com/) — JetBrainsMono Nerd Font + Material Design icons
- [fzf](https://github.com/junegunn/fzf) — the fuzzy finder powering the history picker
- [zsh-users](https://github.com/zsh-users) — autosuggestions and syntax-highlighting plugins
- Claude Code v2 — inspiration for the welcome banner layout
