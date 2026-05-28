#!/usr/bin/env python3
"""
Generate a merged starship.toml that contains all four Catppuccin palettes
(latte / frappe / macchiato / mocha). Switching at runtime is then a single
`palette = 'catppuccin_<name>'` edit — no re-install needed.

Usage:
    build-merged-config.py <source.toml> <default-palette> <out.toml>

The source file must already have ONE Catppuccin palette block named
`[palettes.catppuccin_mocha]` (or any of the four). We strip that block and
replace with all four.
"""
from __future__ import annotations
import re
import sys
from pathlib import Path

CATPPUCCIN_PALETTES = {
    "latte": """\
[palettes.catppuccin_latte]
rosewater = "#dc8a78"
flamingo  = "#dd7878"
pink      = "#ea76cb"
mauve     = "#8839ef"
red       = "#d20f39"
maroon    = "#e64553"
peach     = "#fe640b"
yellow    = "#df8e1d"
green     = "#40a02b"
teal      = "#179299"
sky       = "#04a5e5"
sapphire  = "#209fb5"
blue      = "#1e66f5"
lavender  = "#7287fd"
text      = "#4c4f69"
subtext1  = "#5c5f77"
subtext0  = "#6c6f85"
overlay2  = "#7c7f93"
overlay1  = "#8c8fa1"
overlay0  = "#9ca0b0"
surface2  = "#acb0be"
surface1  = "#bcc0cc"
surface0  = "#ccd0da"
base      = "#eff1f5"
mantle    = "#e6e9ef"
crust     = "#dce0e8"
""",
    "frappe": """\
[palettes.catppuccin_frappe]
rosewater = "#f2d5cf"
flamingo  = "#eebebe"
pink      = "#f4b8e4"
mauve     = "#ca9ee6"
red       = "#e78284"
maroon    = "#ea999c"
peach     = "#ef9f76"
yellow    = "#e5c890"
green     = "#a6d189"
teal      = "#81c8be"
sky       = "#99d1db"
sapphire  = "#85c1dc"
blue      = "#8caaee"
lavender  = "#babbf1"
text      = "#c6d0f5"
subtext1  = "#b5bfe2"
subtext0  = "#a5adce"
overlay2  = "#949cbb"
overlay1  = "#838ba7"
overlay0  = "#737994"
surface2  = "#626880"
surface1  = "#51576d"
surface0  = "#414559"
base      = "#303446"
mantle    = "#292c3c"
crust     = "#232634"
""",
    "macchiato": """\
[palettes.catppuccin_macchiato]
rosewater = "#f4dbd6"
flamingo  = "#f0c6c6"
pink      = "#f5bde6"
mauve     = "#c6a0f6"
red       = "#ed8796"
maroon    = "#ee99a0"
peach     = "#f5a97f"
yellow    = "#eed49f"
green     = "#a6da95"
teal      = "#8bd5ca"
sky       = "#91d7e3"
sapphire  = "#7dc4e4"
blue      = "#8aadf4"
lavender  = "#b7bdf8"
text      = "#cad3f5"
subtext1  = "#b8c0e0"
subtext0  = "#a5adcb"
overlay2  = "#939ab7"
overlay1  = "#8087a2"
overlay0  = "#6e738d"
surface2  = "#5b6078"
surface1  = "#494d64"
surface0  = "#363a4f"
base      = "#24273a"
mantle    = "#1e2030"
crust     = "#181926"
""",
    "mocha": """\
[palettes.catppuccin_mocha]
rosewater = "#f5e0dc"
flamingo  = "#f2cdcd"
pink      = "#f5c2e7"
mauve     = "#cba6f7"
red       = "#f38ba8"
maroon    = "#eba0ac"
peach     = "#fab387"
yellow    = "#f9e2af"
green     = "#a6e3a1"
teal      = "#94e2d5"
sky       = "#89dceb"
sapphire  = "#74c7ec"
blue      = "#89b4fa"
lavender  = "#b4befe"
text      = "#cdd6f4"
subtext1  = "#bac2de"
subtext0  = "#a6adc8"
overlay2  = "#9399b2"
overlay1  = "#7f849c"
overlay0  = "#6c7086"
surface2  = "#585b70"
surface1  = "#45475a"
surface0  = "#313244"
base      = "#1e1e2e"
mantle    = "#181825"
crust     = "#11111b"
""",
}

# Match the palette-selector line AND the single existing palette block,
# stopping at the first blank line (or comment line at column 0) that follows.
# We use re.DOTALL so .*? can span lines.
PATTERN = re.compile(
    r"palette\s*=\s*'catppuccin_[a-z]+'\s*\n+"
    r"\[palettes\.catppuccin_[a-z]+\][^\[]*?"
    r"crust\s*=\s*\"[^\"]+\"\s*\n",
    re.DOTALL,
)


def merge(src: Path, default: str, out: Path) -> None:
    if default not in CATPPUCCIN_PALETTES:
        raise SystemExit(f"unknown default palette: {default!r}")

    text = src.read_text(encoding="utf-8")

    all_palettes = "\n".join(CATPPUCCIN_PALETTES[name].strip()
                             for name in ("latte", "frappe", "macchiato", "mocha"))
    replacement = (
        f"palette = 'catppuccin_{default}'\n\n"
        f"{all_palettes}\n"
    )

    new_text, n = PATTERN.subn(replacement, text, count=1)
    if n != 1:
        raise SystemExit(
            f"could not locate palette block in {src} "
            f"(matched {n} times; expected 1)"
        )

    out.write_text(new_text, encoding="utf-8")
    print(f"  wrote {out} (default palette: catppuccin_{default})")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    merge(Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3]))
