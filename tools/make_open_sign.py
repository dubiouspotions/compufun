#!/usr/bin/env python3
"""Draws the two faces of the shop's Open sign as 40 x 16 pixel-art PNGs.
Usage: make_open_sign.py Godot/materials/textures/open_sign_open.png Godot/materials/textures/open_sign_closed.png"""
import struct
import sys
import zlib

W, H = 40, 16
FONT = {  # 5 x 7 glyphs, one string per row
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "C": [".####", "#....", "#....", "#....", "#....", "#....", ".####"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
}
CREAM, RED, GREY = (236, 228, 204), (196, 30, 36), (70, 66, 74)


def draw(word, ink, path):
    pixels = [[CREAM] * W for _ in range(H)]
    for x in range(W):
        pixels[0][x] = pixels[H - 1][x] = ink
    for y in range(H):
        pixels[y][0] = pixels[y][W - 1] = ink
    x = (W - (len(word) * 6 - 1)) // 2
    for ch in word:
        for row, bits in enumerate(FONT[ch]):
            for col, bit in enumerate(bits):
                if bit == "#":
                    pixels[4 + row][x + col] = ink
        x += 6
    raw = b"".join(b"\x00" + bytes(c for p in row for c in p) for row in pixels)
    chunk = lambda tag, data: struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


draw("OPEN", RED, sys.argv[1])
draw("CLOSED", GREY, sys.argv[2])
