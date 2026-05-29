# Syntax Highlight Colors

All colors are Catppuccin palette tokens. Hex values change per palette; the
role (token name) stays the same across all four palettes.

Source of truth: `pkg/tools/build-plugin-theme.py`
Regenerated on every palette switch by `ew theme <palette>`.

---

## Command Types

| Token | Color Role | What it highlights |
|---|---|---|
| `command` | **green** | External commands — `ls`, `git`, `curl` |
| `builtin` | **teal** | Shell builtins — `cd`, `echo`, `export`, `source` |
| `function` | **blue** | Shell functions defined in your config |
| `alias` | **teal** | Aliases — `ll`, `gs`, etc. |
| `suffix-alias` | **teal** | Suffix aliases — `.py` → run with python |
| `global-alias` | **teal** | Global aliases |
| `hashed-command` | **green** | Commands found via hash table |
| `precommand` | **green** *italic* | Precommand modifiers — `sudo`, `env`, `time` |
| `reserved-word` | **mauve** | zsh keywords — `if`, `then`, `for`, `while`, `do` |
| `arg0` | **green** | First argument (when parsed as a command) |
| `unknown-token` | **red** | Unrecognised / misspelled command |

---

## Paths & Files

| Token | Color Role | What it highlights |
|---|---|---|
| `path` | **text** | Valid path that exists on disk |
| `path_prefix` | **text** | Partial path (prefix of a real path) |
| `path_pathseparator` | **pink** | The `/` separator inside a path |

> No underline. Paths are colored text-only — same foreground as the default
> text color so they blend in, only the separators pop in pink.

---

## Arguments & Flags

| Token | Color Role | What it highlights |
|---|---|---|
| `single-hyphen-option` | **peach** | Short flags — `-v`, `-rf` |
| `double-hyphen-option` | **peach** | Long flags — `--verbose`, `--output` |
| `globbing` | **yellow** | Glob patterns — `*.txt`, `**/*.zsh` |
| `assign` | **text** | Variable assignments — `FOO=bar` |
| `redirection` | **pink** | Redirections — `>`, `>>`, `<`, `2>&1` |
| `commandseparator` | **pink** | `;`, `&&`, `\|\|`, `\|` |

---

## Strings & Quotes

| Token | Color Role | What it highlights |
|---|---|---|
| `single-quoted-argument` | **yellow** | `'literal string'` |
| `double-quoted-argument` | **yellow** | `"interpolated string"` |
| `dollar-quoted-argument` | **yellow** | `$'escape sequences'` |
| `back-quoted-argument` | **mauve** | `` `command substitution` `` |
| `dollar-double-quoted-argument` | **lavender** | `$var` inside double quotes |
| `back-double-quoted-argument` | **lavender** | `\x` escapes inside double quotes |
| `history-expansion` | **mauve** | `!!`, `!$`, `!cmd` |

---

## Brackets

| Token | Color Role | What it highlights |
|---|---|---|
| `bracket-level-1` | **yellow** | Outermost bracket pair |
| `bracket-level-2` | **green** | Second nesting level |
| `bracket-level-3` | **blue** | Third nesting level |
| `bracket-level-4` | **mauve** | Fourth nesting level |
| `bracket-level-5` | **pink** | Fifth nesting level |
| `bracket-error` | **red** | Unmatched bracket |
| `cursor-matchingbracket` | **base** on **rosewater** bg | Bracket under cursor and its match |

---

## Other

| Token | Color Role | What it highlights |
|---|---|---|
| `default` | **text** | Anything not matched by another rule |
| `comment` | **overlay1** *italic* | `# inline comments` |

---

## Ghost Text (zsh-autosuggestions)

| Element | Color Role | What it shows |
|---|---|---|
| Suggestion | **overlay0** | Greyed-out completion hint after cursor |

overlay0 is intentionally faint — visible but not distracting.

---

## fzf Picker Colors

| Element | Color Role |
|---|---|
| Background | **base** |
| Selected row bg | **surface1** |
| Active row bg | **surface0** |
| Foreground / text | **text** |
| Highlighted match | **red** |
| Highlighted match (selected) | **red** |
| Prompt `history >` | **mauve** |
| Info line | **mauve** |
| Pointer `>` | **rosewater** |
| Marker | **lavender** |
| Header text | **red** |
| Border | **surface2** |
| Label | **text** |

---

## Palette Hex Values (for reference)

| Role | Latte (light) | Frappé | Macchiato | Mocha (dark) |
|---|---|---|---|---|
| text | `#4c4f69` | `#c6d0f5` | `#cad3f5` | `#cdd6f4` |
| green | `#40a02b` | `#a6d189` | `#a6da95` | `#a6e3a1` |
| blue | `#1e66f5` | `#8caaee` | `#8aadf4` | `#89b4fa` |
| teal | `#179299` | `#81c8be` | `#8bd5ca` | `#94e2d5` |
| mauve | `#8839ef` | `#ca9ee6` | `#c6a0f6` | `#cba6f7` |
| pink | `#ea76cb` | `#f4b8e4` | `#f5bde6` | `#f5c2e7` |
| peach | `#fe640b` | `#ef9f76` | `#f5a97f` | `#fab387` |
| yellow | `#df8e1d` | `#e5c890` | `#eed49f` | `#f9e2af` |
| red | `#d20f39` | `#e78284` | `#ed8796` | `#f38ba8` |
| lavender | `#7287fd` | `#babbf1` | `#b7bdf8` | `#b4befe` |
| rosewater | `#dc8a78` | `#f2d5cf` | `#f4dbd6` | `#f5e0dc` |
| overlay0 | `#9ca0b0` | `#737994` | `#6e738d` | `#6c7086` |
| overlay1 | `#8c8fa1` | `#838ba7` | `#8087a2` | `#7f849c` |
| surface0 | `#ccd0da` | `#414559` | `#363a4f` | `#313244` |
| surface1 | `#bcc0cc` | `#51576d` | `#494d64` | `#45475a` |
| surface2 | `#acb0be` | `#626880` | `#5b6078` | `#585b70` |
| base | `#eff1f5` | `#303446` | `#24273a` | `#1e1e2e` |

Switch palette: `ew theme mocha` · `ew theme latte` · `ew theme frappe` · `ew theme macchiato`
