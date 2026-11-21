#!/usr/bin/env python3
"""Draws the view buttons' PS1 D-pad look as pixel-art PNGs, at 3 screen pixels per art pixel:
the button in three states (a 9-slice with a 4-pixel bevel) and the four embossed arrows.
Usage: make_nav_buttons.py Godot/ui/nav_buttons"""
import os
import struct
import sys
import zlib

SCALE = 3
CLEAR = (0, 0, 0, 0)
OUTLINE = (12, 12, 14, 255)

# Per state: the body, then the two top-left bevel rows (outer, inner), then the two bottom-right
# rows (inner, outer). Pressed swaps light and dark, so the plastic looks pushed in.
STATES = {
    "normal": ((60, 60, 66), (122, 122, 130), (86, 86, 94), (38, 38, 42), (26, 26, 30)),
    "hover": ((72, 72, 79), (148, 148, 158), (102, 102, 110), (44, 44, 49), (28, 28, 32)),
    "pressed": ((50, 50, 55), (24, 24, 28), (34, 34, 38), (70, 70, 77), (96, 96, 104)),
}
ARROW, EMBOSS = (168, 168, 176, 255), (14, 14, 16, 255)


def button(body, light, light_inner, dark_inner, dark):
    size = 12
    px = [[body + (255,)] * size for _ in range(size)]
    for i in range(size):
        px[0][i] = px[size - 1][i] = px[i][0] = px[i][size - 1] = OUTLINE
    for i in range(1, size - 1):
        px[1][i] = px[i][1] = light + (255,)
        px[size - 2][i] = px[i][size - 2] = dark + (255,)
    for i in range(2, size - 2):
        px[2][i] = px[i][2] = light_inner + (255,)
        px[size - 3][i] = px[i][size - 3] = dark_inner + (255,)
    for y, x in ((0, 0), (0, size - 1), (size - 1, 0), (size - 1, size - 1)):
        px[y][x] = CLEAR
    return px


def arrow_up():
    size = 14
    px = [[CLEAR] * size for _ in range(size)]
    # A triangle 13 wide and 7 high, with its shadow one pixel down and right.
    rows = [(6 - i, 6 + i) for i in range(7)]
    for dy, dx, colour in ((4, 1, EMBOSS), (3, 0, ARROW)):
        for row, (a, b) in enumerate(rows):
            for x in range(a, b + 1):
                px[row + dy][x + dx] = colour
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
    up = arrow_up()
    right = rotate(up)
    down = rotate(right)
    left = rotate(down)
    for name, px in (("up", up), ("right", right), ("down", down), ("left", left)):
        save(px, os.path.join(out, f"arrow_{name}.png"))


main()
