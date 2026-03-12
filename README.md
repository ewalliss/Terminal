# Catppuccin Terminal Theme for macOS

A complete [Catppuccin](https://github.com/catppuccin/catppuccin) terminal setup for macOS — iTerm2 color profiles + Starship prompt with Material Design icons. Auto-switches between dark (Mocha) and light (Latte) based on your macOS appearance.

---

## Preview

### Style A — Powerline (solid background segments)

```
  dangnguyen  󰉋 loubot   󰘬 main 󰏭 󰋗    󰌠 v3.12   󰎙 v20.11        󱎫 12s  󰥔 22:31
❯
```

### Style B — Text only (colored, no backgrounds)

```
  dangnguyen  󰉋 loubot  󰘬 main  󰌠 v3.12  󰎙 v20.11               󱎫 12s  󰥔 22:31
❯
```

---

## Requirements

| Tool | Install |
|------|---------|
| [Homebrew](https://brew.sh) | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| [Starship](https://starship.rs) | installed automatically by `install.sh` |
| [JetBrainsMono Nerd Font](https://www.nerdfonts.com/) | installed automatically by `install.sh` |
| iTerm2 (recommended) | [iterm2.com](https://iterm2.com) |

---

## Install

```zsh
git clone https://github.com/ewalliss/Terminal.git ~/custom_theme
cd ~/custom_theme
zsh install.sh
source ~/.zshrc
```

`install.sh` will:
- Install Starship and JetBrainsMono Nerd Font if not present
- Back up all your existing shell configs and `starship.toml`
- Inject `starship init` into `.zshrc`, `.zprofile`, `.bashrc`, and fish
- Deploy the correct theme (dark or light) based on your current macOS appearance
- Create a `toggle-starship-theme` command in `~/.local/bin`
- Open iTerm2 color profiles for import

---

## Preview Before Installing

Run a fully sandboxed demo — **nothing on your real system is touched:**

```zsh
zsh preview.sh
```

A new terminal window opens showing all prompt styles, languages, DevOps segments, and the install/revert flow live.

---

## Switch Styles

```zsh
# Switch to Style A (powerline solid backgrounds)
toggle-starship-theme --style A

# Switch to Style B (text-only colors)
toggle-starship-theme --style B

# Sync to current macOS dark/light mode (keep current style)
toggle-starship-theme
```

---

## Segments & Icons

All icons use the [Material Design](https://pictogrammers.com/library/mdi/) Nerd Font set (`nf-md-*`). Segments appear automatically when the relevant tool is detected in your current directory.

| Segment | Icon | Color |
|---------|------|-------|
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

## Revert / Uninstall

Restores everything to exactly how it was before install:

```zsh
zsh revert.sh
```

Handles all edge cases: missing backups, corrupt iTerm2 plist, iTerm2 running, tools that were pre-installed vs installed by this script.

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

## File Structure

```
custom_theme/
├── install.sh                  — main installer
├── revert.sh                   — full uninstaller / restore
├── preview.sh                  — sandboxed demo runner
├── test.sh                     — automated test suite (38 assertions)
├── iterm2/
│   ├── catppuccin-mocha.itermcolors   — dark color profile
│   └── catppuccin-latte.itermcolors   — light color profile
└── starship/
    ├── starship-mocha.toml     — Style A dark
    ├── starship-latte.toml     — Style A light
    ├── starship-mocha-b.toml   — Style B dark
    └── starship-latte-b.toml   — Style B light
```

---

## Colors

### Mocha (dark)
| Role | Hex |
|------|-----|
| Background | `#1e1e2e` |
| Text | `#cdd6f4` |
| Mauve | `#cba6f7` |
| Blue | `#89b4fa` |
| Green | `#a6e3a1` |
| Teal | `#94e2d5` |
| Peach | `#fab387` |
| Red | `#f38ba8` |

### Latte (light)
| Role | Hex |
|------|-----|
| Background | `#eff1f5` |
| Text | `#4c4f69` |
| Mauve | `#8839ef` |
| Blue | `#1e66f5` |
| Green | `#40a02b` |
| Teal | `#179299` |
| Peach | `#fe640b` |
| Red | `#d20f39` |

---

## License

MIT — use freely, modify as needed.
