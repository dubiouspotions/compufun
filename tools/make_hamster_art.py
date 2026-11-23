#!/usr/bin/env python3
"""Draws the nice lady's hamster sticker, on her computer's case.
Usage: make_hamster_art.py Godot"""
import os
import random
import struct
import sys
import zlib

class Canvas:
    def __init__(self, w, h, fill):
        self.w, self.h = w, h
        self.px = [[fill] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c(x, y) if callable(c) else c

    def shape(self, inside, c):
        """Fills the pixels whose centre [param inside] accepts, at 4 x 4 samples per pixel. [param c] is
        a colour, or a function of x and y that gives one (for a dither)."""
        for y in range(self.h):
            for x in range(self.w):
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


def ellipse(cx, cy, rx, ry):
    return lambda x, y: ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0


def hamster(c, cx, cy, s, ink, fur, white, pink, eye, blush=None):
    """A round hamster face, [param s] pixels from its middle to its cheek."""
    for side in (-1, 1):
        c.shape(ellipse(cx + side * 0.62 * s, cy - 0.7 * s, 0.33 * s, 0.33 * s), ink)
        c.shape(ellipse(cx + side * 0.62 * s, cy - 0.7 * s, 0.24 * s, 0.24 * s), fur)
        c.shape(ellipse(cx + side * 0.62 * s, cy - 0.72 * s, 0.14 * s, 0.14 * s), pink)
    c.shape(ellipse(cx, cy, 1.05 * s, 0.88 * s), ink)
    c.shape(ellipse(cx, cy, 0.95 * s, 0.78 * s), fur)
    c.shape(ellipse(cx, cy + 0.3 * s, 0.66 * s, 0.42 * s), white)
    c.shape(ellipse(cx, cy - 0.3 * s, 0.13 * s, 0.32 * s), white)
    if blush:
        for side in (-1, 1):
            c.shape(ellipse(cx + side * 0.58 * s, cy + 0.2 * s, 0.14 * s, 0.09 * s), blush)
    for side in (-1, 1):
        c.shape(ellipse(cx + side * 0.36 * s, cy - 0.06 * s, 0.12 * s, 0.14 * s), eye)
        c.set(round(cx + side * 0.36 * s - 0.1 * s), round(cy - 0.14 * s), white)
    c.shape(ellipse(cx, cy + 0.12 * s, 0.1 * s, 0.07 * s), pink)
    c.shape(lambda x, y: abs(x - cx) <= 0.04 * s + 0.5 and cy + 0.15 * s <= y <= cy + 0.3 * s, ink)


def sticker():
    """A cute hamster on pink, with a white border, a little faded and scuffed."""
    c = Canvas(32, 32, (250, 246, 238))
    c.shape(lambda x, y: 2 <= x <= 30 and 2 <= y <= 30, (255, 200, 214))
    hamster(c, 16, 17.5, 11, (92, 52, 28), (226, 150, 70), (250, 246, 238), (236, 120, 150), (30, 24, 24), (244, 160, 170))
    rng = random.Random("hamster")
    grey = (200, 196, 186)
    for y in range(32):
        for x in range(32):
            v = c.px[y][x]
            v = tuple(round(a + (g - a) * 0.1) for a, g in zip(v, grey))
            if x in (0, 31) or y in (0, 31):
                v = tuple(round(a * 0.85) for a in v)
            elif rng.random() < 0.015:
                v = tuple(round(a + (255 - a) * 0.3) for a in v)
            c.px[y][x] = v
    return c


def main(godot):
    sticker().save(os.path.join(godot, "materials/textures/sticker_hamster.png"))


main(sys.argv[1])
