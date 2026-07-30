#!/usr/bin/env python3
"""
Generate a macOS Terminal.app profile (.terminal file) from a Catppuccin palette.

Usage:
    build-terminal-profile.py <palette: latte|frappe|macchiato|mocha> <out.terminal>

The output is an XML plist of one "Window Settings" profile:
  - name    = "EwallisTerminal"  (constant — all palettes share ONE profile slot,
              mirroring the single-Guid design of the iTerm2 dynamic profile)
  - Font    = JetBrainsMonoNFM-Regular 13
  - Colors  = ANSI 0-15 + fg/bg/cursor/selection from the palette

Color and font values are NSKeyedArchiver-encoded blobs (that's the on-disk
format Terminal.app uses). We hand-craft the keyed archive with plistlib —
no PyObjC needed. NSColorSpace=1 is calibrated RGB; NSRGB carries the
components as a NUL-terminated ASCII C-string, matching Terminal's own exports.

A user can double-click the .terminal file to import it manually; ew-setup /
ew-theme / ew-uninstall manage it programmatically via `defaults`.
"""
from __future__ import annotations
import plistlib
import re
import sys
from pathlib import Path

PROFILE_NAME = "EwallisTerminal"
FONT_NAME = "JetBrainsMonoNFM-Regular"
FONT_SIZE = 13.0

# "Liquid glass" background: translucent + blurred (Terminal renders what's
# behind the window through a frosted layer). 1.0/0.0 = solid, no blur.
BG_ALPHA = 0.60
BG_BLUR = 0.7

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

# ANSI 0-15 mapping — same as the iTerm2 profile (Catppuccin official spec)
ANSI_KEYS = [
    ("ANSIBlackColor",         "surface1"),
    ("ANSIRedColor",           "red"),
    ("ANSIGreenColor",         "green"),
    ("ANSIYellowColor",        "yellow"),
    ("ANSIBlueColor",          "blue"),
    ("ANSIMagentaColor",       "pink"),
    ("ANSICyanColor",          "teal"),
    ("ANSIWhiteColor",         "subtext1"),
    ("ANSIBrightBlackColor",   "surface2"),
    ("ANSIBrightRedColor",     "red"),
    ("ANSIBrightGreenColor",   "green"),
    ("ANSIBrightYellowColor",  "yellow"),
    ("ANSIBrightBlueColor",    "blue"),
    ("ANSIBrightMagentaColor", "pink"),
    ("ANSIBrightCyanColor",    "teal"),
    ("ANSIBrightWhiteColor",   "subtext0"),
]


def archived_color(hex_: str, alpha: float = 1.0) -> bytes:
    """NSKeyedArchiver blob for an NSColor (calibrated RGB)."""
    if not re.match(r"^#[0-9a-fA-F]{6}$", hex_):
        raise ValueError(f"bad hex: {hex_!r}")
    r = int(hex_[1:3], 16) / 255.0
    g = int(hex_[3:5], 16) / 255.0
    b = int(hex_[5:7], 16) / 255.0
    comps = f"{r:.6g} {g:.6g} {b:.6g}"
    if alpha != 1.0:
        comps += f" {alpha:.6g}"
    archive = {
        "$version": 100000,
        "$archiver": "NSKeyedArchiver",
        "$top": {"root": plistlib.UID(1)},
        "$objects": [
            "$null",
            {
                "$class": plistlib.UID(2),
                "NSColorSpace": 1,
                "NSRGB": comps.encode("ascii") + b"\x00",
            },
            {"$classname": "NSColor", "$classes": ["NSColor", "NSObject"]},
        ],
    }
    return plistlib.dumps(archive, fmt=plistlib.FMT_BINARY)


def archived_font(name: str, size: float) -> bytes:
    """NSKeyedArchiver blob for an NSFont."""
    archive = {
        "$version": 100000,
        "$archiver": "NSKeyedArchiver",
        "$top": {"root": plistlib.UID(1)},
        "$objects": [
            "$null",
            {
                "$class": plistlib.UID(3),
                "NSName": plistlib.UID(2),
                "NSSize": float(size),
                "NSfFlags": 16,
            },
            name,
            {"$classname": "NSFont", "$classes": ["NSFont", "NSObject"]},
        ],
    }
    return plistlib.dumps(archive, fmt=plistlib.FMT_BINARY)


def build_profile(palette_name: str) -> dict:
    if palette_name not in PALETTES:
        raise SystemExit(f"unknown palette: {palette_name!r}")
    p = PALETTES[palette_name]
    C = archived_color  # alias

    profile: dict = {
        "name": PROFILE_NAME,
        "type": "Window Settings",
        "ProfileCurrentVersion": 2.07,
        "BackgroundColor":  C(p["base"], alpha=BG_ALPHA),
        "BackgroundBlur":   BG_BLUR,
        "TextColor":        C(p["text"]),
        "TextBoldColor":    C(p["text"]),
        "CursorColor":      C(p["rosewater"]),
        "SelectionColor":   C(p["surface2"]),
        "Font":             archived_font(FONT_NAME, FONT_SIZE),
        "FontAntialias":    True,
        "FontWidthSpacing": 1.0,
        "FontHeightSpacing": 1.05,
        "UseBoldFonts":     True,
        "UseBrightBold":    False,
        "BlinkText":        False,
        "CursorType":       0,
        "CursorBlink":      False,
        "ShouldLimitScrollback": 1,
        "ScrollbackLines":  10000,
        "TerminalType":     "xterm-256color",
        "Bell":             False,
        "VisualBell":       False,
        # Window + behavior — a complete profile, not just colors
        "columnCount":      120,
        "rowCount":         32,
        "useOptionAsMetaKey": True,
        "ShowWindowSettingsNameInTitle": False,
        "ShowActiveProcessInTitle":      True,
        "ShowActiveProcessArgumentsInTitle": False,
        "ShowDimensionsInTitle":         False,
        "ShowShellCommandInTitle":       False,
        "ShowTTYNameInTitle":            False,
        "shellExitAction":  1,
    }
    for key, color_name in ANSI_KEYS:
        profile[key] = C(p[color_name])
    return profile


def main() -> None:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    palette, out = sys.argv[1], Path(sys.argv[2])
    out.write_bytes(plistlib.dumps(build_profile(palette), fmt=plistlib.FMT_XML))
    print(f"  wrote {out}")


if __name__ == "__main__":
    main()
