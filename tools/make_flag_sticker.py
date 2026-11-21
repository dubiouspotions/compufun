#!/usr/bin/env python3
"""Draws a South Korean flag sticker as a 72 x 48 pixel-art PNG, built from the flag's official
proportions. Usage: make_flag_sticker.py Godot/materials/textures/sticker_korea.png"""
import math
import struct
import sys
import zlib

W, H = 72, 48
D = H / 2  # diameter of the taegeuk circle
PAPER, RED, BLUE, INK, EDGE = (236, 232, 220), (198, 12, 48), (0, 52, 120), (24, 22, 26), (180, 176, 166)
# Trigrams from the top-left corner clockwise; each is three bars from the circle outward, True whole.
TRIGRAMS = [((-3, -2), (True, True, True)), ((3, -2), (False, True, False)),
            ((3, 2), (False, False, False)), ((-3, 2), (True, False, True))]
BAR, GAP = D / 12, D / 24  # bar thickness and the space between bars and inside a broken bar


def colour(x, y):
    px, py = x - W / 2, y - H / 2
    diagonal = (3 / math.hypot(3, 2), 2 / math.hypot(3, 2))  # top-left to bottom-right corner
    u = px * diagonal[0] + py * diagonal[1]
    v = px * diagonal[1] - py * diagonal[0]  # toward the top-right
    if math.hypot(px, py) <= D / 2:
        if math.hypot(u + D / 4, v) <= D / 4:
            return RED
        if math.hypot(u - D / 4, v) <= D / 4:
            return BLUE
        return RED if v > 0 else BLUE
    for (dx, dy), bars in TRIGRAMS:
        n = math.hypot(dx, dy)
        out = (dx / n, dy / n)
        along = px * out[0] + py * out[1] - (D / 2 + D / 4)  # distance from the trigram's inner edge
        across = px * -out[1] + py * out[0]
        for i, whole in enumerate(bars):
            start = i * (BAR + GAP)
            if start <= along < start + BAR and abs(across) <= D / 4 and (whole or abs(across) > GAP / 2):
                return INK
    return PAPER


def main(path):
    rows = []
    for y in range(H):
        row = []
        for x in range(W):
            edge = x in (0, W - 1) or y in (0, H - 1)
            row.append(EDGE if edge else colour(x + 0.5, y + 0.5))
        rows.append(b"\0" + bytes(c for p in row for c in p))
    chunk = lambda kind, data: struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


main(sys.argv[1])
