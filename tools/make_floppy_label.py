#!/usr/bin/env python3
"""Draws the plain floppy label, a waving Windows 95 flag with its trail on paper, as a 74 x 54
pixel-art PNG (1 pixel per millimetre of the label on props/floppy_disk.tscn).
Usage: make_floppy_label.py Godot/materials/textures/floppy_label.png"""
import math
import struct
import sys
import zlib

W, H = 74, 54
PAPER, INK = (242, 240, 224), (16, 16, 16)  # PAPER is materials/paper.tres
RED, GREEN, BLUE, YELLOW = (230, 40, 30), (40, 170, 60), (30, 70, 200), (250, 210, 20)
FX, FY, FW, FH = 27, 7, 41, 38  # the flag's box: left, top, width, height
WAVE = 2.5  # how far the flag waves up and down, in pixels
GAP = 0.09  # the black cross between the panes, as a fraction of the flag
TRAIL = [(21, 4, 3), (15, 3, 2), (10, 2, 2), (6, 2, 1)]  # the trail's columns left of the flag: x, square size, squares per pane


def wave(u):
    return WAVE * math.sin(2 * math.pi * u)


def flag(x, y):
    u = (x - FX) / FW
    if not 0 <= u <= 1:
        return None
    v = (y - FY - wave(u)) / FH
    if not 0 <= v <= 1:
        return None
    if min(u, 1 - u) * FW < 1 or min(v, 1 - v) * FH < 1 or abs(u - 0.5) < GAP / 2 or abs(v - 0.5) < GAP / 2:
        return INK
    if v < 0.5:
        return RED if u < 0.5 else GREEN
    return BLUE if u < 0.5 else YELLOW


def trail(x, y):
    for left, size, count in TRAIL:
        if left <= x < left + size:
            for colour, middle in ((RED, 0.25), (BLUE, 0.75)):
                start = FY + middle * FH - (count * (size + 1) - 1) / 2
                if start <= y < start + count * (size + 1) and (y - start) % (size + 1) < size:
                    return colour
    return None


def colour(x, y):
    return flag(x, y) or trail(x, y) or PAPER


def main(path):
    rows = []
    for y in range(H):
        row = [colour(x + 0.5, y + 0.5) for x in range(W)]
        rows.append(b"\0" + bytes(c for p in row for c in p))
    chunk = lambda kind, data: struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


main(sys.argv[1])
