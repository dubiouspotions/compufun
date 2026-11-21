#!/usr/bin/env python3
"""Draws the face of the red phone's rotary dial as a 64 x 64 pixel-art texture: the clear finger
wheel with ten holes over cream, a number mark in each, the yellow and white label in the middle,
and the steel finger stop. The corners are clear; the material cuts them away.
Usage: make_phone_dial.py Godot/props/textures/phone_dial.png"""
import math
import struct
import sys
import zlib

SIZE = 64
CLEAR = (0, 0, 0, 0)
RIM, WHEEL, HOLE, MARK = (196, 32, 38, 255), (226, 222, 210, 255), (246, 242, 232, 255), (30, 28, 30, 255)
YELLOW, LABEL, LINE, STEEL = (206, 176, 62, 255), (240, 236, 226, 255), (150, 140, 120, 255), (176, 178, 186, 255)


def draw():
    c = (SIZE - 1) / 2
    px = [[CLEAR] * SIZE for _ in range(SIZE)]
    for y in range(SIZE):
        for x in range(SIZE):
            r = math.hypot(x - c, y - c)
            if r <= 31.5:
                px[y][x] = RIM
            if r <= 29.5:
                px[y][x] = WHEEL
            if r <= 14.5:
                px[y][x] = YELLOW if y < c else LABEL
            if r <= 14.5 and abs(y - c) < 0.6:
                px[y][x] = LINE
    # Ten finger holes round the wheel, from the top right clockwise, with the gap at the bottom right.
    for n in range(10):
        angle = math.radians(-60 - n * 30)
        hx, hy = c + 22 * math.cos(angle), c - 22 * math.sin(angle)
        for y in range(SIZE):
            for x in range(SIZE):
                d = math.hypot(x - hx, y - hy)
                if d <= 5.2:
                    px[y][x] = HOLE
                if d <= 1.4:
                    px[y][x] = MARK
    for r in range(23, 31):  # the finger stop
        x, y = c + r * math.cos(math.radians(-35)), c - r * math.sin(math.radians(-35))
        px[int(round(y))][int(round(x))] = STEEL
    return px


def save(px, path):
    raw = b"".join(b"\x00" + b"".join(bytes(p) for p in row) for row in px)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    print("wrote", path)


save(draw(), sys.argv[1])
