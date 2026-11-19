#!/usr/bin/env python3
"""scale-grub-theme.py SRC DST SCALE: write GRUB theme.txt SRC to DST with pixel sizes multiplied by SCALE.

Upstream themes are drawn for 1920x1080; GRUB on a Retina MacBook runs at the native 2560x1600, where their fonts
and rows are too small to read. Scaled: font sizes ("<Family> <Style> <size>"), the boot menu's row/icon/padding
pixels, a progress bar's height and its "100%-<px>" offset. The background is cropped instead of stretched (16:9 on
a 16:10 screen). Prints the font sizes the theme now needs (one per line), so the caller can grub-mkfont them, and
CHANGED on stderr when DST was rewritten.
"""

import re
import sys

src, dst, scale = sys.argv[1], sys.argv[2], float(sys.argv[3])


def px(n):
    return str(max(1, round(int(n) * scale)))


text = open(src).read()
text = re.sub(r'(desktop-image-scale-method:\s*)"stretch"', r'\1"crop"', text)
text = re.sub(
    r'("[^"\n]*? )(\d+)(")',
    lambda m: m[1] + px(m[2]) + m[3] if re.search(r'(Regular|Bold|Italic|Medium) \d+"$', m[0]) else m[0],
    text,
)
text = re.sub(
    r"(?m)^(\s*(?:item_height|item_padding|item_spacing|icon_width|icon_height|item_icon_space|height)"
    r"\s*=\s*)(\d+)\s*$",
    lambda m: m[1] + px(m[2]),
    text,
)
text = re.sub(r"(?m)^(\s*top\s*=\s*100%-)(\d+)\s*$", lambda m: m[1] + px(m[2]), text)

try:
    old = open(dst).read()
except FileNotFoundError:
    old = None
if text != old:
    open(dst, "w").write(text)
    print("CHANGED", file=sys.stderr)
for size in sorted({int(s) for s in re.findall(r'"[^"\n]*? (\d+)"', text)}):
    print(size)
