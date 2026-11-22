#!/usr/bin/env python3
"""Draws the office girl's case sticker: her company's asset tag, a silver label with a blue ASSET band
and a barcode, as a small pixel-art PNG.
Usage: make_asset_tag.py Godot/materials/textures"""
import os
import random
import struct
import sys
import zlib

W, H = 48, 20
SILVER = (196, 198, 204)
BLUE = (36, 64, 150)
INK = (28, 28, 34)
WHITE = (246, 244, 236)
FONT = {
    "A": ".###.|#...#|#...#|#####|#...#|#...#|#...#",
    "E": "#####|#....|#....|####.|#....|#....|#####",
    "S": ".####|#....|#....|.###.|....#|....#|####.",
    "T": "#####|..#..|..#..|..#..|..#..|..#..|..#..",
}


def main(folder):
    px = [[SILVER] * W for _ in range(H)]
    for y in range(9):
        for x in range(W):
            px[y][x] = BLUE
    word = "ASSET"
    left = (W - (len(word) * 6 - 1)) // 2
    for i, ch in enumerate(word):
        for row, line in enumerate(FONT[ch].split("|")):
            for col, bit in enumerate(line):
                if bit == "#":
                    px[1 + row][left + i * 6 + col] = WHITE
    rng = random.Random("asset_tag")
    x = 4
    while x < W - 4:
        bar = rng.choice((1, 1, 2))
        for bx in range(x, min(x + bar, W - 4)):
            for y in range(11, H - 2):
                px[y][bx] = INK
        x += bar + rng.choice((1, 1, 2))
    for y in range(H):
        for x in range(W):
            if x in (0, W - 1) or y in (0, H - 1):
                px[y][x] = tuple(round(v * 0.8) for v in px[y][x])
    rows = [b"\0" + bytes(v for c in row for v in c) for row in px]
    chunk = lambda kind, data: struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
    with open(os.path.join(folder, "sticker_asset_tag.png"), "wb") as f:
        f.write(png)


main(sys.argv[1])
