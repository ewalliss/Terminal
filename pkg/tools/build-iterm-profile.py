#!/usr/bin/env python3
"""
Generate an iTerm2 Dynamic Profile JSON file from a Catppuccin palette.

Usage:
    build-iterm-profile.py <palette: latte|frappe|macchiato|mocha> <out.json>

The output is a single-profile Dynamic Profile file with:
  - Name        = "Catppuccin <Palette>"
  - Guid        = stable, derived from palette name
  - Font        = JetBrainsMonoNFM-Regular 13
  - Colors      = ANSI 0-15 + fg/bg/cursor/selection/link from the palette
"""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path

# Catppuccin Color Spec  (https://github.com/catppuccin/catppuccin)
PALETTES = {
    "latte": {
        "rosewater": "#dc8a78", "flamingo": "#dd7878", "pink": "#ea76cb",
        "mauve":     "#8839ef", "red":      "#d20f39", "maroon":  "#e64553",
        "peach":     "#fe640b", "yellow":   "#df8e1d", "green":   "#40a02b",
        "teal":      "#179299", "sky":      "#04a5e5", "sapphire":"#209fb5",
        "blue":      "#1e66f5", "lavender": "#7287fd", "text":    "#4c4f69",
        "subtext1":  "#5c5f77", "subtext0": "#6c6f85", "overlay2":"#7c7f93",
        "overlay1":  "#8c8fa1", "overlay0": "#9ca0b0", "surface2":"#acb0be",
        "surface1":  "#bcc0cc", "surface0": "#ccd0da", "base":    "#eff1f5",
        "mantle":    "#e6e9ef", "crust":    "#dce0e8",
    },
    "frappe": {
        "rosewater": "#f2d5cf", "flamingo": "#eebebe", "pink":    "#f4b8e4",
        "mauve":     "#ca9ee6", "red":      "#e78284", "maroon":  "#ea999c",
        "peach":     "#ef9f76", "yellow":   "#e5c890", "green":   "#a6d189",
        "teal":      "#81c8be", "sky":      "#99d1db", "sapphire":"#85c1dc",
        "blue":      "#8caaee", "lavender": "#babbf1", "text":    "#c6d0f5",
        "subtext1":  "#b5bfe2", "subtext0": "#a5adce", "overlay2":"#949cbb",
        "overlay1":  "#838ba7", "overlay0": "#737994", "surface2":"#626880",
        "surface1":  "#51576d", "surface0": "#414559", "base":    "#303446",
        "mantle":    "#292c3c", "crust":    "#232634",
    },
    "macchiato": {
        "rosewater": "#f4dbd6", "flamingo": "#f0c6c6", "pink":    "#f5bde6",
        "mauve":     "#c6a0f6", "red":      "#ed8796", "maroon":  "#ee99a0",
        "peach":     "#f5a97f", "yellow":   "#eed49f", "green":   "#a6da95",
        "teal":      "#8bd5ca", "sky":      "#91d7e3", "sapphire":"#7dc4e4",
        "blue":      "#8aadf4", "lavender": "#b7bdf8", "text":    "#cad3f5",
        "subtext1":  "#b8c0e0", "subtext0": "#a5adcb", "overlay2":"#939ab7",
        "overlay1":  "#8087a2", "overlay0": "#6e738d", "surface2":"#5b6078",
        "surface1":  "#494d64", "surface0": "#363a4f", "base":    "#24273a",
        "mantle":    "#1e2030", "crust":    "#181926",
    },
    "mocha": {
        "rosewater": "#f5e0dc", "flamingo": "#f2cdcd", "pink":    "#f5c2e7",
        "mauve":     "#cba6f7", "red":      "#f38ba8", "maroon":  "#eba0ac",
        "peach":     "#fab387", "yellow":   "#f9e2af", "green":   "#a6e3a1",
        "teal":      "#94e2d5", "sky":      "#89dceb", "sapphire":"#74c7ec",
        "blue":      "#89b4fa", "lavender": "#b4befe", "text":    "#cdd6f4",
        "subtext1":  "#bac2de", "subtext0": "#a6adc8", "overlay2":"#9399b2",
        "overlay1":  "#7f849c", "overlay0": "#6c7086", "surface2":"#585b70",
        "surface1":  "#45475a", "surface0": "#313244", "base":    "#1e1e2e",
        "mantle":    "#181825", "crust":    "#11111b",
    },
}

# Stable GUIDs per palette so iTerm2 keeps the profile-id stable across rebuilds
GUIDS = {
    "latte":      "F4B6D3B2-EFF1-F5EF-F1F5-EWALLISTERM-LT",
    "frappe":     "F4B6D3B2-3034-4630-3446-EWALLISTERM-FR",
    "macchiato":  "F4B6D3B2-2427-3A24-273A-EWALLISTERM-MC",
    "mocha":      "F4B6D3B2-1E1E-2E1E-1E2E-EWALLISTERM-MO",
}

# ANSI 0-15 mapping per Catppuccin's official iTerm2 spec.
# https://github.com/catppuccin/iterm
ANSI = [
    "surface1",  # 0  black
    "red",       # 1  red
    "green",     # 2  green
    "yellow",    # 3  yellow
    "blue",      # 4  blue
    "pink",      # 5  magenta
    "teal",      # 6  cyan
    "subtext1",  # 7  white
    "surface2",  # 8  bright black
    "red",       # 9  bright red
    "green",     # 10 bright green
    "yellow",    # 11 bright yellow
    "blue",      # 12 bright blue
    "pink",      # 13 bright magenta
    "teal",      # 14 bright cyan
    "subtext0",  # 15 bright white
]


def hex_to_rgb_dict(hex_: str, alpha: float = 1.0) -> dict:
    if not re.match(r"^#[0-9a-fA-F]{6}$", hex_):
        raise ValueError(f"bad hex: {hex_!r}")
    r = int(hex_[1:3], 16) / 255.0
    g = int(hex_[3:5], 16) / 255.0
    b = int(hex_[5:7], 16) / 255.0
    return {
        "Color Space": "sRGB",
        "Red Component":   round(r, 6),
        "Green Component": round(g, 6),
        "Blue Component":  round(b, 6),
        "Alpha Component": float(alpha),
    }


def build_profile(palette_name: str) -> dict:
    if palette_name not in PALETTES:
        raise SystemExit(f"unknown palette: {palette_name!r}")
    p = PALETTES[palette_name]
    H = hex_to_rgb_dict  # alias

    profile: dict = {
        "Name": f"Catppuccin {palette_name.title()}",
        "Guid": GUIDS[palette_name],
        "Dynamic Profile Parent Name": "Default",
        "Custom Command":              "No",
        "Custom Directory":            "No",
        "Working Directory":           "",
        "Normal Font":                 "JetBrainsMonoNFM-Regular 13",
        "Use Non-Ascii Font":          False,
        "ASCII Anti Aliased":          True,
        "Non-ASCII Anti Aliased":      True,
        "Use Bold Font":               True,
        "Use Bright Bold":             False,
        "Use Italic Font":             True,
        "Horizontal Spacing":          1.0,
        "Vertical Spacing":            1.05,
        "Minimum Contrast":            0.0,
        "Transparency":                0.0,
        "Blur":                        False,
        "Background Color":     H(p["base"]),
        "Foreground Color":     H(p["text"]),
        "Bold Color":           H(p["text"]),
        "Link Color":           H(p["sapphire"]),
        "Selection Color":      H(p["surface2"]),
        "Selected Text Color":  H(p["text"]),
        "Cursor Color":         H(p["rosewater"]),
        "Cursor Text Color":    H(p["base"]),
        "Badge Color":          H(p["red"], alpha=0.5),
        "Cursor Type":          2,
        "Blinking Cursor":      False,
        "Mouse Reporting":      True,
        "Unlimited Scrollback": False,
        "Scrollback Lines":     10000,
        "Terminal Type":        "xterm-256color",
        "Character Encoding":   4,
        "Silence Bell":         True,
        "Visual Bell":          False,
    }
    for i, color_name in enumerate(ANSI):
        profile[f"Ansi {i} Color"] = H(p[color_name])
    return profile


def main() -> None:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    palette, out = sys.argv[1], Path(sys.argv[2])
    doc = {"Profiles": [build_profile(palette)]}
    out.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    print(f"  wrote {out}")


if __name__ == "__main__":
    main()
