#!/usr/bin/env python3
"""Draws Netscape Navigator 2.0's pictures for the in-game browser, after screenshots of the real
one: the logo (a white serif N over a dark planet in a teal glow) at 16, 32, 48 and 96 px, the
toolbar and status bar icons, and the splash (a ship's wheel under a starfield).
Usage: make_netscape_art.py Godot/win95/netscape"""
import math
import os
import random
import struct
import sys
import zlib

BLACK, WHITE = (0, 0, 0), (255, 255, 255)
GLOW, DEEP = (40, 150, 150), (0, 22, 30)  # the logo's sky, from its centre to its edges
RIM = (60, 170, 160)  # the planet's lit edge
PALETTE = {
    "k": (0, 0, 0), "w": (255, 255, 255), "g": (128, 128, 128), "s": (192, 192, 192), "d": (64, 64, 64),
    "y": (255, 255, 0), "Y": (128, 128, 0), "b": (0, 0, 255), "B": (0, 0, 128), "r": (255, 0, 0),
    "R": (128, 0, 0), "c": (0, 255, 255), "C": (0, 128, 128), "G": (0, 128, 0), "l": (0, 255, 0),
}

# Toolbar icons, as in Navigator 2.0's "Pictures and Text" toolbar. "." is clear.
ICONS = {
    "back": [
        "......k.........",
        ".....kk.........",
        "....kyk.........",
        "...kyykkkkkkkkk.",
        "..kyyyyyyyyyyyk.",
        ".kyyyyyyyyyyyyk.",
        "..kyyyyyyyyyyyk.",
        "...kyykkkkkkkkk.",
        "....kyk.........",
        ".....kk.........",
        "......k.........",
    ],
    "home": [
        ".......kk.......",
        "......kRRk......",
        ".....kRRRRk.kk..",
        "....kRRRRRRkdk..",
        "...kRRRRRRRRkk..",
        "..kRRRRRRRRRRk..",
        ".kkkkkkkkkkkkkk.",
        "..kwwwwwwwwwwk..",
        "..kwccwwwkkkwk..",
        "..kwccwwwkYkwk..",
        "..kwwwwwwkYkwk..",
        "..kwwwwwwkYkwk..",
        "..kkkkkkkkkkkk..",
    ],
    "images": [
        "kkkkkkkkkkkkkkkk",
        "kcccccccccccyyck",
        "kcccccccccccyyck",
        "kccccccccccccccc",
        "kccccccGccccccck",
        "kcccccGGGcccGcck",
        "kccccGGGGGcGGGck",
        "kcccGGGGGGGGGGck",
        "kccGGGGGGGGGGGGk",
        "kGGGGGGGGGGGGGGk",
        "kkkkkkkkkkkkkkkk",
    ],
    "open": [
        "..kkkkkkkk......",
        "..kwwwwwwkk.....",
        "..kwBBBBwkwk....",
        "..kwwwwwwkkkk...",
        "..kwBBBBBBBwk...",
        "..kwwwwwwwwwk...",
        "..kwBBBBBBBwk...",
        "..kwwwwwwwwwk...",
        "..kwBBBBBwwwk.k.",
        "..kwwwwwwwwwkkk.",
        "..kwBBBBBBkkkkkk",
        "..kwwwwwwwwwkkk.",
        "..kkkkkkkkkkk.k.",
    ],
    "print": [
        "....kkkkkkkk....",
        "....kwwwwwwk....",
        "....kwBBBBwk....",
        "....kwwwwwwk....",
        ".kkkkkkkkkkkkkk.",
        "kssssssssssssssk",
        "ksssssssssssllsk",
        "kggggggggggggggk",
        "kgkkkkkkkkkkkkgk",
        "kgkwwwwwwwwwwkgk",
        "kkkwBBBBBBBBwkkk",
        "...kwwwwwwwwk...",
        "...kkkkkkkkkk...",
    ],
    "find": [
        ".kkkk....kkkk...",
        ".kddk....kddk...",
        "kkddkk..kkddkk..",
        "kddddkkkkddddk..",
        "kddddkddkddddk..",
        "kkkkkkddkkkkkkk.",
        "kcbbkkkkkkcbbkk.",
        "kcbbbkkkkcbbbk..",
        "kbbbbk..kbbbbk..",
        ".kkkk....kkkk...",
    ],
    "stop": [
        "....kkkkkk....",
        "...krrrrrrk...",
        "..krrrrrrrrk..",
        ".krrrrrrrrrrk.",
        "krrrrrrrrrrrrk",
        "krwwwwwwwwwwrk",
        "krwwwwwwwwwwrk",
        "krrrrrrrrrrrrk",
        ".krrrrrrrrrrk.",
        "..krrrrrrrrk..",
        "...krrrrrrk...",
        "....kkkkkk....",
    ],
    # The picture that could not load, as Netscape showed it with Auto Load Images on.
    "broken": [
        "kkkkkkkkkk....",
        "kwwwwwwwwkk...",
        "kwrrwwwwwkwk..",
        "kwrrwwGwwkkkk.",
        "kwwwwGGGwwwwk.",
        "kwwwGGGGGwwwk.",
        "kwwwwwwwwwwwk.",
        "kwbbwwwwwwwwk.",
        "kbbbbwwwwwwwk.",
        "kwbbwwwwwwwwk.",
        "kwwwwwwwwwwwk.",
        "kkkkkkkkkkkkk.",
    ],
    # The arrow of the Location box's list of visited pages.
    "drop": [
        "kkkkkkk",
        ".kkkkk.",
        "..kkk..",
        "...k...",
    ],
    # The status bar: the broken key of a document that is not secure, and the mail.
    "key": [
        "................",
        "..kkk...........",
        ".kBBBk..........",
        "kBkkkBk..k.k....",
        "kBk.kBkkkk.kkkk.",
        "kBkkkBbbbk..bbbk",
        ".kBBBkkkkk.kkkk.",
        "..kkk......k.k..",
    ],
    "mail": [
        "kkkkkkkkkkkkkk",
        "kwkwwwwwwwwkwk",
        "kwwkwwwwwwkwwk",
        "kwwwkwwwwkwwwk",
        "kwwwwkkkkwwwwk",
        "kwwwkwwwwkwwwk",
        "kwwkwwwwwwkwwk",
        "kkkkkkkkkkkkkk",
    ],
}


def mirror(rows):
    return [row[::-1] for row in rows]


def grid(rows):
    width = max(len(row) for row in rows)
    return [[PALETTE.get(ch) for ch in row.ljust(width, ".")] for row in rows]


def reload_icon():
    """A circular arrow, drawn rather than gridded: a ring with a gap and an arrowhead."""
    size = 16
    pixels = [[None] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - 8, y + 0.5 - 8.5
            r, angle = math.hypot(dx, dy), math.degrees(math.atan2(dy, dx))
            if 4 <= r <= 7 and not (-80 < angle < -20):
                pixels[y][x] = BLACK if r < 4.8 or r > 6.2 else PALETTE["C"]
    for y, row in enumerate(["kkkkk", ".kCk.", "..k.."]):  # the head, at the gap, pointing down
        for x, ch in enumerate(row):
            if ch != ".":
                pixels[3 + y][10 + x] = PALETTE[ch]
    return pixels


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(round(p + (q - p) * t) for p, q in zip(a, b))


def serif_n(size):
    """The pixels of a serif N filling the middle of a size x size square: thin stems, a thick
    diagonal, serifs at the top of both stems and the foot of the left one."""
    s = size / 48
    left, right, top, bottom = 13 * s, 35 * s, 10 * s, 33 * s
    thin, thick, serif = max(1.0, 2.2 * s), max(1.5, 5 * s), max(1.0, 2 * s)
    inside = set()
    for y in range(size):
        for x in range(size):
            px, py = x + 0.5, y + 0.5
            if not top <= py <= bottom:
                continue
            on = left <= px <= left + thin  # the left stem
            on |= right - thin <= px <= right and py <= bottom - thick * 0.6  # the right stem
            t = (py - top) / (bottom - top)
            diagonal = left + t * (right - left - thick)
            on |= diagonal <= px <= diagonal + thick
            on |= py <= top + serif and (left - 3 * s <= px <= left + thick + s or right - thin - 3 * s <= px <= right + 3 * s)
            on |= py >= bottom - serif and left - 3 * s <= px <= left + thin + 3 * s
            if on:
                inside.add((x, y))
    return inside


def logo(size):
    """The 1996 logo: a teal glow over a dark planet, and the white N."""
    n = serif_n(size)
    pixels = []
    for y in range(size):
        row = []
        for x in range(size):
            u, v = (x + 0.5) / size, (y + 0.5) / size
            colour = mix(GLOW, DEEP, math.hypot(u - 0.5, (v - 0.62) * 1.3) * 1.9)
            planet = math.hypot(u - 0.5, (v - 1.55) * 0.9)
            if planet < 0.82:
                colour = mix(RIM, BLACK, (0.82 - planet) * 30) if size >= 32 else BLACK
            if (x, y) in n:
                colour = WHITE
            row.append(colour)
        pixels.append(row)
    return pixels


def splash():
    """210 x 316, after the 2.0 splash: a dithered teal starfield with faint green rays from the
    top left, the boxed logo at the top, and a ship's wheel rising from the bottom. The game
    writes its text over it."""
    w, h = 210, 316
    rng = random.Random(1996)
    bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    cx, cy = w / 2, 300  # the wheel's hub, at the bottom
    spokes = [(math.cos(math.radians(d)), math.sin(math.radians(d))) for d in range(0, 360, 45)]
    pixels = []
    for y in range(h):
        row = []
        for x in range(w):
            glow = max(0.0, 1.0 - math.hypot(x - cx, (y - 250) * 1.3) / 150)
            level = glow * 0.9 + (bayer[y % 4][x % 4] / 16 - 0.5) * 0.35
            colour = mix((0, 20, 24), (40, 170, 170), level)
            angle = math.atan2(y, x)
            if abs((angle * 9) % 1.0 - 0.5) < 0.012 and y < 200:
                colour = mix(colour, (60, 160, 60), 0.6)  # the rays
            px, py = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(px, py)
            on_wheel = 88 <= r <= 99 or r <= 30  # the rim and the hub
            for dx, dy in spokes:
                along, off = px * dx + py * dy, abs(px * dy - py * dx)
                on_wheel |= off < 3 and 28 < along < 136  # a spoke
                on_wheel |= off < 5.5 - abs(along - 148) * 0.25 and 134 < along < 162  # its handle
            if on_wheel:
                shade = 0.75 + (bayer[y % 4][x % 4] / 16) * 0.25
                colour = mix((30, 120, 120), (230, 255, 250), shade)
            if y >= 266:  # the dark band that the copyright stands on
                colour = mix((0, 30, 34), (0, 8, 10), (y - 266) / 50)
            row.append(colour)
        pixels.append(row)
    for _ in range(90):
        x, y = rng.randrange(w), rng.randrange(170)
        pixels[y][x] = WHITE
    box = logo(48)
    for y in range(48):  # the boxed logo, with a light frame
        for x in range(48):
            pixels[12 + y][81 + x] = box[y][x]
    for i in range(50):
        for (x, y) in ((80 + i, 11), (80 + i, 60), (80, 11 + i), (129, 11 + i)):
            pixels[y][x] = (200, 230, 230)
    return pixels


def write_png(path, pixels):
    height, width = len(pixels), len(pixels[0])
    raw = b"".join(b"\x00" + bytes(c for px in row for c in ((*px, 255) if px else (0, 0, 0, 0))) for row in pixels)

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    for size in (16, 32, 48, 96):
        write_png(os.path.join(out, "logo_%d.png" % size), logo(size))
    for name, rows in ICONS.items():
        write_png(os.path.join(out, name + ".png"), grid(rows))
    write_png(os.path.join(out, "forward.png"), grid(mirror(ICONS["back"])))
    write_png(os.path.join(out, "reload.png"), reload_icon())
    write_png(os.path.join(out, "splash.png"), splash())
