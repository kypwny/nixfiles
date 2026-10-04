#!/usr/bin/env python3
"""Port the ahoka GTK3 theme to the base16 "Classic Dark" palette.

    python3 port.py <ahodesuka/dotfiles checkout> [out-dir]

Reads  <checkout>/.themes/ahoka/gtk-3.0/{gtk.css,assets/*.png}
Writes <out-dir>/gtk-3.0/{gtk.css,assets/*.png}   (default: this directory)

This was run once to seed themes/psyche-gtk/gtk-3.0; the output is committed and
is now hand-maintained. Keep this script so the mapping stays reviewable and the
port can be redone (e.g. against a new palette) without guessing what it did.
Needs Pillow only for the PNG assets.

How colours move
  * Greys (low saturation) stay neutral and are re-levelled through GREY_MAP so
    ahoka's #1b1b1b window / #222222 view / #e9e6e6 text land on base00 / base01 /
    base05 and everything in between keeps its order.
  * Saturated colours switch to the base16 accent of their hue family
    (ahoka's red selection becomes base08 and so on), keeping their relative
    lightness and saturation so hover/active/insensitive shades still differ.
  * Alpha channels are untouched.
"""

import colorsys
import re
import sys
from pathlib import Path

# base16 classic-dark (theme/classic-dark.nix)
PALETTE = {
    "base00": "151515", "base01": "202020", "base02": "303030", "base03": "505050",
    "base04": "b0b0b0", "base05": "d0d0d0", "base06": "e0e0e0", "base07": "f5f5f5",
    "base08": "ac4142", "base09": "d28445", "base0A": "f4bf75", "base0B": "90a959",
    "base0C": "75b5aa", "base0D": "6a9fb5", "base0E": "aa759f", "base0F": "8f5536",
}  # fmt: skip


def hls(hexstr):
    r, g, b = (int(hexstr[i : i + 2], 16) / 255 for i in (0, 2, 4))
    return colorsys.rgb_to_hls(r, g, b)  # (h, l, s), each 0..1


def to_hex(h, l, s):
    r, g, b = colorsys.hls_to_rgb(h, min(max(l, 0), 1), min(max(s, 0), 1))
    return "%02x%02x%02x" % tuple(round(c * 255) for c in (r, g, b))


def lerp_map(x, anchors):
    """Piecewise-linear interpolation through (src, dst) anchor pairs."""
    if x <= anchors[0][0]:
        return anchors[0][1]
    for (x0, y0), (x1, y1) in zip(anchors, anchors[1:]):
        if x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return anchors[-1][1]


L = {k: hls(v)[1] for k, v in PALETTE.items()}

# ahoka source lightness -> classic-dark lightness
GREY_MAP = [
    (0.000, 0.000),
    (0.047, 0.040),  # #0c0c0c borders/shadows
    (0.106, L["base00"]),  # #1b1b1b window background
    (0.133, L["base01"]),  # #222222 view background
    (0.208, L["base02"]),  # #353535 hover
    (0.450, L["base03"]),  # mid greys, separators
    (0.730, L["base04"]),  # #bcb9b9 dim text / osd
    (0.910, L["base05"]),  # #e9e6e6 text
    (1.000, L["base07"]),
]

# hue family -> accent slot; ranges in degrees
FAMILIES = [
    (15, "base08"),   # red (also wraps from 335)
    (45, "base09"),   # orange
    (70, "base0A"),   # yellow
    (170, "base0B"),  # green
    (200, "base0C"),  # cyan
    (260, "base0D"),  # blue
    (335, "base0E"),  # magenta
]  # fmt: skip
REF_L, REF_S = 0.40, 0.43  # ahoka's selection red (#87353d) is the yardstick


def family(h_deg):
    for upper, slot in FAMILIES:
        if h_deg < upper:
            return slot
    return "base08"


def map_color(hexstr):
    h, l, s = hls(hexstr)
    if s <= 0.15 or l <= 0.03 or l >= 0.97:
        g = lerp_map(l, GREY_MAP)
        return to_hex(0, g, 0)
    ah, al, as_ = hls(PALETTE[family(h * 360)])
    nl = al * (l / REF_L)
    ns = min(as_ * 1.5, as_ * (s / REF_S))
    return to_hex(ah, min(max(nl, 0.04), 0.96), ns)


HEX6 = re.compile(r"#([0-9a-fA-F]{6})\b")
HEX3 = re.compile(r"#([0-9a-fA-F]{3})\b")
RGBA = re.compile(r"rgb(a?)\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*([\d.]+)\s*)?\)")


def port_css(css):
    def hex3(m):
        d = m.group(1)
        return "#" + map_color("".join(c * 2 for c in d))

    def rgba(m):
        r, g, b = (int(m.group(i)) for i in (2, 3, 4))
        out = map_color("%02x%02x%02x" % (r, g, b))
        rr, gg, bb = (int(out[i : i + 2], 16) for i in (0, 2, 4))
        if m.group(1):
            return "rgba(%d, %d, %d, %s)" % (rr, gg, bb, m.group(5) or "1")
        return "rgb(%d, %d, %d)" % (rr, gg, bb)

    css = HEX6.sub(lambda m: "#" + map_color(m.group(1).lower()), css)
    css = HEX3.sub(hex3, css)
    return RGBA.sub(rgba, css)


def port_png(src, dst):
    from PIL import Image

    im = Image.open(src).convert("RGBA")
    cache = {}
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            key = (r, g, b)
            if key not in cache:
                m = map_color("%02x%02x%02x" % key)
                cache[key] = tuple(int(m[i : i + 2], 16) for i in (0, 2, 4))
            px[x, y] = (*cache[key], a)
    im.save(dst)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = Path(sys.argv[1]) / ".themes/ahoka/gtk-3.0"
    out = Path(sys.argv[2] if len(sys.argv) > 2 else Path(__file__).parent) / "gtk-3.0"
    (out / "assets").mkdir(parents=True, exist_ok=True)
    css = (src / "gtk.css").read_text()
    (out / "gtk.css").write_text(port_css(css))
    n = 0
    for png in sorted((src / "assets").glob("*.png")):
        port_png(png, out / "assets" / png.name)
        n += 1
    print(f"ported gtk.css and {n} assets -> {out}")


if __name__ == "__main__":
    main()
