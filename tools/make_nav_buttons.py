#!/usr/bin/env python3
"""Draws the view buttons' PS1 D-pad look as pixel-art PNGs, at 3 screen pixels per art pixel:
the button in three states (a 9-slice with a 4-pixel bevel and a grained middle that tiles) and
the four embossed arrows.
Usage: make_nav_buttons.py Godot/ui/nav_buttons"""
import os
import random
import struct
import sys
import zlib

SCALE = 3
CLEAR = (0, 0, 0, 0)
OUTLINE = (12, 12, 14, 255)

# Per state: the body, the top-left bevel and the bottom-right bevel. Each bevel is 2 solid pixels
# of one tone, so the edge reads hard. Pressed swaps light and dark, so the plastic looks pushed in.
STATES = {
    "normal": ((62, 62, 68), (170, 170, 180), (10, 10, 12)),
    "hover": ((74, 74, 81), (200, 200, 212), (12, 12, 14)),
    "pressed": ((50, 50, 55), (10, 10, 12), (150, 150, 160)),
}
# How strongly the bevel and the arrows stand out from the plastic: 1 is the full light and dark
# tones, lower blends them toward the body. The edges stay hard at any value.
EMBOSS_OPACITY = 0.6
ARROW_ALPHA = round(255 * EMBOSS_OPACITY)
ARROW, LIT, SHADOW = (128, 128, 136, ARROW_ALPHA), (226, 226, 236, ARROW_ALPHA), (8, 8, 10, ARROW_ALPHA)


def grain(size):
    """Per pixel, how much lighter or darker the plastic is there: fine noise and a few specks.
    Seeded, so every state has the same grain and hover does not make it flicker."""
    rng = random.Random(1995)
    shades = []
    for _ in range(size):
        row = []
        for _ in range(size):
            roll = rng.random()
            row.append(-14 if roll < 0.07 else 12 if roll < 0.10 else rng.randint(-5, 5))
        shades.append(row)
    return shades


def shade(colour, by):
    return tuple(max(0, min(255, c + by)) for c in colour) + (255,)


def blend(body, tone):
    return tuple(round(b + (t - b) * EMBOSS_OPACITY) for b, t in zip(body, tone))


def button(body, light, dark):
    # 24 art pixels: a 4-pixel edge round a 16-pixel middle, which tiles across the button.
    light, dark = blend(body, light), blend(body, dark)
    size = 24
    noise = grain(size)
    px = [[shade(body, noise[y][x]) for x in range(size)] for y in range(size)]
    for i in range(1, size - 1):
        for edge in (1, 2):
            px[edge][i] = px[i][edge] = light + (255,)
            px[size - 1 - edge][i] = px[i][size - 1 - edge] = dark + (255,)
    for i in range(size):
        px[0][i] = px[size - 1][i] = px[i][0] = px[i][size - 1] = OUTLINE
    for y, x in ((0, 0), (0, size - 1), (size - 1, 0), (size - 1, size - 1)):
        px[y][x] = CLEAR
    return px


def triangle_up():
    """Where a triangle 13 wide and 7 high, pointing up, covers a 14 x 14 grid."""
    size = 14
    inside = [[False] * size for _ in range(size)]
    for row in range(7):
        for x in range(6 - row, 7 + row):
            inside[row + 3][x] = True
    return inside


def raised(inside):
    """The shape raised out of the plastic, lit from the top left: the edges that face up or left
    are lit, those that face down or right are in shadow, with no blend between."""
    size = len(inside)

    def filled(y, x):
        return 0 <= y < size and 0 <= x < size and inside[y][x]

    px = [[CLEAR] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            if not inside[y][x]:
                continue
            if not filled(y + 1, x) or not filled(y, x + 1):
                px[y][x] = SHADOW
            elif not filled(y - 1, x) or not filled(y, x - 1):
                px[y][x] = LIT
            else:
                px[y][x] = ARROW
    return px


def rotate(px):  # a quarter turn clockwise
    return [list(row) for row in zip(*px[::-1])]


def save(px, path):
    height, width = len(px) * SCALE, len(px[0]) * SCALE
    raw = b""
    for row in px:
        line = b"\x00" + b"".join(bytes(p) * SCALE for p in row)
        raw += line * SCALE

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    print("wrote", path)


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for name, colours in STATES.items():
        save(button(*colours), os.path.join(out, f"button_{name}.png"))
    # Turn the shape, not the picture, so the light comes from the top left on every arrow.
    up = triangle_up()
    right = rotate(up)
    down = rotate(right)
    left = rotate(down)
    for name, shape in (("up", up), ("right", right), ("down", down), ("left", left)):
        save(raised(shape), os.path.join(out, f"arrow_{name}.png"))


main()
