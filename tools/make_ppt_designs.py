#!/usr/bin/env python3
"""Draws the backgrounds of the in-game PowerPoint's design templates, after Office 97's Dadstie,
Fireball and Highvolt as Apply Design previews them (docs/ppt.md): our own drawings, not
Microsoft's pictures.
Usage: make_ppt_designs.py Godot/win95/office/designs"""
import math
import os
import random
import struct
import sys
import zlib

W, H = 480, 360


def write_png(path, pixels):
    raw = b"".join(b"\x00" + bytes(c for px in row for c in px) for row in pixels)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def dadstie():
    """White, with a strip of tie fabric down the left edge: squares of blues, black and pale gold."""
    rng = random.Random(1997)
    colours = [(0, 0, 128), (0, 128, 192), (64, 160, 224), (0, 0, 0), (232, 216, 152), (32, 64, 160), (160, 200, 232)]
    strip = 30
    cells = [[rng.choice(colours) for _ in range(3)] for _ in range(H // 10 + 1)]
    pixels = []
    for y in range(H):
        row = []
        for x in range(W):
            if x < strip:
                colour = cells[y // 10][x // 10]
                if (x + y) % 4 == 0:
                    colour = mix(colour, (255, 255, 255), 0.25)  # the weave
            elif x < strip + 2:
                colour = (128, 128, 128)
            else:
                colour = (255, 255, 255)
            row.append(colour)
        pixels.append(row)
    return pixels


def fireball():
    """Black, with a comet streaking right along the title: a thin blue trail that turns magenta,
    then red, into an orange and yellow head."""
    pixels = []
    cy, head_x = 0.19 * H, 0.86 * W
    for y in range(H):
        row = []
        for x in range(W):
            colour = (0, 0, 0)
            along = x / head_x
            if 0.05 < along <= 1.0:
                thickness = 1.0 + along ** 3 * 20
                dy = abs(y - cy)
                if dy < thickness:
                    heat = along ** 2
                    tail = mix((40, 40, 200), (220, 30, 160), heat * 1.6) if heat < 0.6 else mix((220, 30, 160), (255, 120, 0), (heat - 0.6) * 2.5)
                    colour = mix(tail, (0, 0, 0), dy / thickness)
            head = math.hypot((x - head_x) / 1.4, y - cy)
            if head < 26:
                colour = mix((255, 255, 120), (255, 80, 0), head / 26)
            row.append(colour)
        pixels.append(row)
    return pixels


def highvolt():
    """Mid blue with a fine texture, ribbons of cyan and white slanting down a strip at the left,
    and a dark rule under the title."""
    rng = random.Random(1996)
    pixels = []
    for y in range(H):
        row = []
        for x in range(W):
            colour = (48, 80, 200) if (x + y) % 2 else (40, 64, 176)
            if rng.random() < 0.04:
                colour = (96, 160, 232)
            if x < 34:
                band = ((y + x * 0.9) % 28) / 28
                colour = (232, 248, 255) if band < 0.18 else (64, 200, 232) if band < 0.45 else (24, 48, 144)
            elif 34 <= x < 37:
                colour = (16, 24, 96)
            if 0.265 * H < y < 0.265 * H + 3 and x > 44:
                colour = (16, 24, 96)
            row.append(colour)
        pixels.append(row)
    return pixels


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, draw in [("dadstie", dadstie), ("fireball", fireball), ("highvolt", highvolt)]:
        write_png(os.path.join(out, name + ".png"), draw())
