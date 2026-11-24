#!/usr/bin/env python3
"""Draws the tile of the office girl's Win95 wallpaper: daisies and little hearts on blue, in the 16
VGA colours that her display adapter shows.
Usage: make_office_girl_art.py Godot"""
import math
import os
import struct
import sys
import zlib

# The 16 colours of a Standard VGA display adapter, the ones that this tile uses.
NAVY, BLUE, GREEN = (0, 0, 128), (0, 0, 255), (0, 128, 0)
OLIVE, YELLOW, SILVER, WHITE = (128, 128, 0), (255, 255, 0), (192, 192, 192), (255, 255, 255)
MAROON, RED = (128, 0, 0), (255, 0, 0)


class Canvas:
    def __init__(self, w, h, fill):
        self.w, self.h = w, h
        self.px = [[fill] * w for _ in range(h)]

    def set(self, x, y, c):
        self.px[y % self.h][x % self.w] = c(x, y) if callable(c) else c

    def shape(self, inside, c, box):
        """Fills the pixels in [param box] (x0, y0, x1, y1) whose centre [param inside] accepts, at
        4 x 4 samples per pixel, wrapping round the tile's edges. [param c] is a colour, or a function
        of x and y that gives one (for a dither)."""
        x0, y0, x1, y1 = (math.floor(v) for v in box)
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                hits = sum(inside(x + (i + 0.5) / 4, y + (j + 0.5) / 4) for i in range(4) for j in range(4))
                if hits >= 8:
                    self.set(x, y, c)

    def save(self, path):
        rows = [b"\0" + bytes(v for c in row for v in c) for row in self.px]
        chunk = lambda kind, data: struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)


def ellipse(cx, cy, rx, ry, tilt=0.0):
    def inside(x, y):
        u = (x - cx) * math.cos(tilt) + (y - cy) * math.sin(tilt)
        v = -(x - cx) * math.sin(tilt) + (y - cy) * math.cos(tilt)
        return (u / rx) ** 2 + (v / ry) ** 2 <= 1.0
    return inside


def daisy(c, cx, cy, r, turn):
    """A daisy [param r] pixels from its middle to its petal tips, turned by [param turn] radians."""
    box = (cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1)
    petals = 11
    for i in range(petals):
        a = turn + i * 2 * math.pi / petals
        px, py = cx + math.cos(a) * r * 0.58, cy + math.sin(a) * r * 0.58
        c.shape(ellipse(px, py, r * 0.46, r * 0.2, a), SILVER, box)
        c.shape(ellipse(px - math.cos(a) * 0.6, py - math.sin(a) * 0.6, r * 0.38, r * 0.13, a), WHITE, box)
    gold = lambda x, y: OLIVE if (x + 2 * y) % 5 == 0 else YELLOW
    c.shape(ellipse(cx, cy, r * 0.3, r * 0.3), OLIVE, box)
    c.shape(ellipse(cx - 0.4, cy - 0.4, r * 0.24, r * 0.24), gold, box)


def leaf(c, cx, cy, length, tilt):
    box = (cx - length, cy - length, cx + length, cy + length)
    c.shape(ellipse(cx, cy, length, length * 0.32, tilt), GREEN, box)


def heart(c, cx, cy, s):
    """A heart [param s] pixels wide, with a dark edge: two round lobes over a point."""
    def inside(x, y, grow=0.0):
        r = s / 4 + grow
        lobes = any((x - (cx + side * s / 4)) ** 2 + (y - cy) ** 2 <= r * r for side in (-1, 1))
        point = y >= cy and abs(x - cx) <= (s / 2 + grow) * (1 - (y - cy) / (s * 0.6 + grow * 1.5))
        return lobes or point
    box = (cx - s, cy - s, cx + s, cy + s)
    c.shape(lambda x, y: inside(x, y, 0.8), MAROON, box)
    c.shape(inside, RED, box)


def wallpaper():
    """Daisies with a leaf or two and a few small hearts on a dithered blue that stays dark enough
    for the white icon names. The tile wraps, so a flower over its edge carries on at the other."""
    c = Canvas(128, 128, NAVY)
    for y in range(128):
        for x in range(128):
            if x % 2 == 0 and y % 2 == (x // 2) % 2:
                c.set(x, y, BLUE)
    for cx, cy, length, tilt in ((6, 82, 7, 0.9), (20, 78, 6, -0.6), (82, 14, 7, 0.5), (94, 2, 6, -1.1)):
        leaf(c, cx, cy, length, tilt)
    # Placed so that no daisy covers an icon name in the desktop's first column.
    for cx, cy, r, turn in ((12, 70, 13, 0.1), (84, 2, 14, 0.5), (50, 98, 8, 0.3)):
        daisy(c, cx, cy, r, turn)
    for cx, cy, s in ((80, 68, 10), (28, 2, 9), (102, 94, 7), (120, 104, 7)):
        heart(c, cx, cy, s)
    return c


def main(godot):
    wallpaper().save(os.path.join(godot, "customers/office_girl/daisies.png"))


main(sys.argv[1])
