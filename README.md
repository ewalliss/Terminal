# EwallisTerminal

A polished, opinionated terminal setup for macOS — Catppuccin colors, Starship prompt with Material Design icons, zsh productivity plugins, and a single `ew` CLI to control everything.

Ships as a signed `.pkg` installer with atomic backups, full uninstall, and self-service updates.

---

## Highlights

- **One CLI to rule them all** — `ew theme · welcome · doctor · setup · update · uninstall · banner-on/off`
- **Live palette switching** — `ew theme latte` flips iTerm2 colors + Starship + plugin highlights *without* reinstalling
- **4 Catppuccin palettes** — Latte (light), Frappé (dark/low), Macchiato (dark/mid), Mocha (dark/high)
- **Welcome banner** — Catppuccin-themed startup splash inspired by Claude Code v2 (toggle with `ew banner-on/off`)
- **ESC×2 session history picker** — when prompt is empty, double-ESC opens an fzf-powered picker of commands typed in this terminal tab; when prompt has text, double-ESC clears it
- **Zsh productivity stack** — vendored `zsh-autosuggestions` + `zsh-syntax-highlighting` + `fzf` integration (offline-safe, palette-themed)
- **Self-service updates** — `ew update` pulls latest from GitHub Releases, SHA256-verifies, installs
- **Atomic, reversible** — every change is backed up; `ew uninstall` restores your prior state byte-for-byte
- **Pre-flight checks** — `ew doctor` detects + offers to brew-install missing deps (starship, fzf, JetBrains Mono Nerd Font)
- **`ew doctor --self-test`** — 11-step sandboxed install → theme → uninstall cycle for regression catching

---

## Install

One-line install (downloads + verifies + runs Apple's installer):

```sh
curl -fLO https://github.com/ewalliss/Terminal/releases/latest/download/EwallisTerminal-2.1.0.pkg
sudo installer -pkg EwallisTerminal-2.1.0.pkg -target /
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
├── plugin-themes/                4 palette-specific zsh files (autosuggest + syntax-highlight + fzf colors)
├── plugins/
│   ├── zsh-autosuggestions/      vendored v0.7.1 (offline-safe)
│   └── zsh-syntax-highlighting/  vendored 0.8.0
├── snippets/                     zshrc.sh, zprofile.sh, bashrc.sh, fish.fish
├── VERSION                       2.1.0
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

---

## Productivity features

### ESC × 2

| Buffer state | Action |
|---|---|
| Empty | Open fzf picker of commands typed in this terminal tab (most recent 50, deduped, newest first) — type to filter, Enter to load into prompt |
| Has text | Clear the line instantly |

The picker shows **session-only history**, not your full `~/.zsh_history` — exactly what you typed in *this* tab since it opened.

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

`ew uninstall` reads the install manifest, restores every pre-existing file from backup, strips the marker block from shell rcs, removes any file we deployed, and prunes empty directories. Zero residue.

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
# → dist/EwallisTerminal-2.1.0.pkg + .sha256 sidecar
```

The build script vendors plugins (clones pinned tags), generates 4 iTerm2 profiles + 4 plugin themes + 2 merged Starship configs from Catppuccin palette data, then runs `pkgbuild`.

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
