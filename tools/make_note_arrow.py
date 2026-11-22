#!/usr/bin/env python3
"""Draws the hand-drawn arrow on the taped note: a slightly wobbly pen stroke pointing right with an
open arrowhead, white on transparent (the material colours it), 1 px per mm.
Usage: make_note_arrow.py Godot/materials/textures/note_arrow.png"""
import math
import struct
import sys
import zlib

W, H = 160, 48


def shaft_y(x):
    return 24 + 2.2 * math.sin(x * 0.04 + 0.3) + 0.8 * math.sin(x * 0.15 + 1.0)


def strokes():
    shaft = [(x, shaft_y(x), 4.6 - 0.8 * x / W) for x in range(6, 151)]
    tip_x, tip_y = 151, shaft_y(151)
    # Each barb bows a little, as a pen pulled back from the tip does.
    upper = [(tip_x - 32 * t, tip_y - 16 * t + 1.5 * math.sin(math.pi * t), 4.4) for t in (i / 30 for i in range(31))]
    lower = [(tip_x - 30 * t, tip_y + 16 * t + 1.2 * math.sin(math.pi * t), 4.2) for t in (i / 30 for i in range(31))]
    return shaft + upper + lower


def main(path):
    alpha = [[0] * W for _ in range(H)]
    for cx, cy, r in strokes():
        for y in range(max(0, int(cy - r - 1)), min(H, int(cy + r + 2))):
            for x in range(max(0, int(cx - r - 1)), min(W, int(cx + r + 2))):
                if math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= r:
                    alpha[y][x] = 255
    rows = [b"\0" + bytes(c for a in row for c in (255, 255, 255, a)) for row in alpha]
    chunk = lambda kind, data: struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


main(sys.argv[1])
