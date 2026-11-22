#!/usr/bin/env python3
"""Draws the hand-drawn arrow on the taped note: a slightly wobbly pen stroke that runs down a little from
under step 1, bends, and runs right, past the end of step 2, to an open arrowhead that points right. White on transparent (the
material colours it), 1 px per mm. Usage: make_note_arrow.py Godot/materials/textures/note_arrow.png"""
import math
import struct
import sys
import zlib

W, H = 120, 88
TOP = (10, 12)  # where the pen starts, under step 1
CORNER = (10, 63)
TIP = (112, 63)  # the arrowhead's point, near the paper's right edge
BEND = 14  # the radius of the bend


def path():
    """The pen's centre line, one point per mm, from TOP down, round the bend, right to TIP."""
    points = [(TOP[0], y) for y in range(TOP[1], CORNER[1] - BEND)]
    for i in range(23):
        a = math.pi / 2 * i / 22  # quarter circle from heading down to heading right
        points.append((CORNER[0] + BEND - BEND * math.cos(a), CORNER[1] - BEND + BEND * math.sin(a)))
    points += [(x, CORNER[1]) for x in range(CORNER[0] + BEND, TIP[0] + 1)]
    # The hand wobbles across the stroke: sideways on the way down, up and down on the way left.
    wobbled = []
    for i, (x, y) in enumerate(points):
        w = 1.6 * math.sin(i * 0.07 + 0.4) + 0.6 * math.sin(i * 0.19 + 1.3)
        wobbled.append((x + w, y) if y < CORNER[1] - BEND else (x, y + w))
    return wobbled


def strokes():
    line = path()
    n = len(line)
    stroke = [(x, y, 4.6 - 1.0 * i / n) for i, (x, y) in enumerate(line)]
    tip_x, tip_y = line[-1]
    # Each barb bows a little, as a pen pulled back from the tip does.
    upper = [(tip_x - 26 * t, tip_y - 15 * t - 1.5 * math.sin(math.pi * t), 4.2) for t in (i / 30 for i in range(31))]
    lower = [(tip_x - 24 * t, tip_y + 15 * t + 1.2 * math.sin(math.pi * t), 4.0) for t in (i / 30 for i in range(31))]
    return stroke + upper + lower


def main(out):
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
    with open(out, "wb") as f:
        f.write(png)


main(sys.argv[1])
