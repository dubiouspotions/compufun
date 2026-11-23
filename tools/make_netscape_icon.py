#!/usr/bin/env python3
"""Draws Netscape Navigator's icon in the style of 1996: a white "N" with a black outline over a
night sky, stars and the curve of the earth. Usage: make_netscape_icon.py <folder>; it writes
netscape_32.png and netscape_16.png there."""
import math
import os
import struct
import sys
import zlib

SKY_TOP, SKY_BOTTOM = (0, 0, 72), (16, 64, 160)
EARTH, EARTH_RIM = (0, 112, 112), (64, 192, 176)
N_FILL, N_SHADE, INK, STAR = (255, 255, 255), (160, 208, 232), (0, 0, 0), (255, 255, 200)
STARS = [(0.12, 0.10), (0.30, 0.20), (0.82, 0.12), (0.90, 0.36), (0.08, 0.42), (0.62, 0.06)]


def draw(size):
    s = size / 32  # the 32 px design, scaled
    left, right, top, bottom, stem = round(7 * s), round(25 * s), round(5 * s), round(24 * s), max(2, round(4 * s))

    def in_n(x, y):
        if not (top <= y < bottom and left <= x < right):
            return False
        if x < left + stem or x >= right - stem:
            return True
        diagonal = left + (y - top) / (bottom - 1 - top) * (right - left - stem)
        return diagonal <= x < diagonal + stem

    pixels = []
    for y in range(size):
        row = []
        for x in range(size):
            t = y / (size - 1)
            colour = tuple(round(a + (b - a) * t) for a, b in zip(SKY_TOP, SKY_BOTTOM))
            if any(abs(x - fx * size) < 0.5 and abs(y - fy * size) < 0.5 for fx, fy in STARS):
                colour = STAR
            distance = math.hypot(x + 0.5 - size / 2, y + 0.5 - size * 1.9)
            if distance < size * 1.05:
                colour = EARTH_RIM if distance > size * 1.05 - max(1, s * 1.5) else EARTH
            if in_n(x, y):
                colour = N_SHADE if x >= right - stem else N_FILL
            elif size >= 32 and any(in_n(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):  # too thick at 16
                colour = INK
            if x in (0, size - 1) or y in (0, size - 1):
                colour = INK
            row.append(colour)
        pixels.append(row)
    return pixels


def write_png(path, pixels):
    height, width = len(pixels), len(pixels[0])
    raw = b"".join(b"\x00" + bytes(c for px in row for c in px) for row in pixels)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    for size in (32, 16):
        write_png(os.path.join(sys.argv[1], "netscape_%d.png" % size), draw(size))
