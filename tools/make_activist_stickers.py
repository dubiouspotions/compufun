#!/usr/bin/env python3
"""Draws the activist's case stickers as small pixel-art PNGs, a little faded, scuffed and peeling.
Usage: make_activist_stickers.py Godot/materials/textures"""
import math
import os
import random
import struct
import sys
import zlib

BACKING = (238, 234, 222)  # the white back of a sticker, where a corner curls up

FONT = {
    "A": ".###.|#...#|#...#|#####|#...#|#...#|#...#",
    "C": ".###.|#...#|#....|#....|#....|#...#|.###.",
    "E": "#####|#....|#....|####.|#....|#....|#####",
    "F": "#####|#....|#....|####.|#....|#....|#....",
    "H": "#...#|#...#|#...#|#####|#...#|#...#|#...#",
    "I": ".###.|..#..|..#..|..#..|..#..|..#..|.###.",
    "K": "#...#|#..#.|#.#..|##...|#.#..|#..#.|#...#",
    "L": "#....|#....|#....|#....|#....|#....|#####",
    "M": "#...#|##.##|#.#.#|#.#.#|#...#|#...#|#...#",
    "N": "#...#|##..#|#.#.#|#..##|#...#|#...#|#...#",
    "O": ".###.|#...#|#...#|#...#|#...#|#...#|.###.",
    "P": "####.|#...#|#...#|####.|#....|#....|#....",
    "R": "####.|#...#|#...#|####.|#.#..|#..#.|#...#",
    "S": ".####|#....|#....|.###.|....#|....#|####.",
    "T": "#####|..#..|..#..|..#..|..#..|..#..|..#..",
    "U": "#...#|#...#|#...#|#...#|#...#|#...#|.###.",
    "V": "#...#|#...#|#...#|#...#|#...#|.#.#.|..#..",
    " ": ".....|.....|.....|.....|.....|.....|.....",
}

FIST = """
................
..##.##.##.##...
..##g##g##g##...
..##g##g##g###..
..##g##g##g###..
..##g##g##g###..
..############..
..#gggggg#####..
..############..
...##########...
....########....
....########....
....########....
....########....
....########....
...SSSSSSSSSS...
...SSSSSSSSSS...
...SSSSSSSSSS...
...SSSSSSSSSS...
................
"""


class Canvas:
    def __init__(self, w, h, fill):
        self.w, self.h = w, h
        self.px = [[fill] * w for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def text(self, s, x, y, c, wobble=None):
        for i, ch in enumerate(s):
            dy = wobble(i) if wobble else 0
            for row, line in enumerate(FONT[ch].split("|")):
                for col, bit in enumerate(line):
                    if bit == "#":
                        self.set(x + i * 6 + col, y + row + dy, c)

    def text_width(self, s):
        return len(s) * 6 - 1

    def shape(self, inside, c):
        """Fills the pixels whose centre [param inside] accepts, at 4 x 4 samples per pixel."""
        for y in range(self.h):
            for x in range(self.w):
                hits = sum(inside(x + (i + 0.5) / 4, y + (j + 0.5) / 4) for i in range(4) for j in range(4))
                if hits >= 8:
                    self.set(x, y, c)

    def wear(self, seed, fade, scuffs, peel):
        """Fades towards grey, scuffs single pixels lighter, dirties the edge and curls up [param peel]
        pixels of one corner (0 none; the corner comes from the seed)."""
        rng = random.Random(seed)
        grey = (200, 196, 186)
        for y in range(self.h):
            for x in range(self.w):
                c = tuple(round(v + (g - v) * fade) for v, g in zip(self.px[y][x], grey))
                if x in (0, self.w - 1) or y in (0, self.h - 1):
                    c = tuple(round(v * 0.82) for v in c)
                elif rng.random() < scuffs:
                    c = tuple(round(v + (255 - v) * 0.3) for v in c)
                self.px[y][x] = c
        if peel:
            flip_x, flip_y = rng.random() < 0.5, rng.random() < 0.5
            for y in range(peel + 1):
                for x in range(peel + 1 - y):
                    px = self.w - 1 - x if flip_x else x
                    py = self.h - 1 - y if flip_y else y
                    self.set(px, py, (150, 146, 138) if x + y == peel else BACKING)

    def save(self, path):
        rows = [b"\0" + bytes(v for c in row for v in c) for row in self.px]
        chunk = lambda kind, data: struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
        png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0))
        png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
        with open(path, "wb") as f:
            f.write(png)


def hsv(h, s, v):
    i = int(h * 6) % 6
    f = h * 6 - int(h * 6)
    p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    r, g, b = [(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)][i]
    return (round(r * 255), round(g * 255), round(b * 255))


def segment_distance(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
    return math.hypot(px - ax - t * dx, py - ay - t * dy)


def peace():
    """A white peace sign on tie-dye."""
    c = Canvas(32, 32, (0, 0, 0))
    cx = cy = 16
    for y in range(32):
        for x in range(32):
            a = math.atan2(y - cy, x - cx)
            r = math.hypot(x - cx, y - cy)
            c.set(x, y, hsv((a / (2 * math.pi) + r / 22) % 1.0, 0.7, 0.85))
    white = (246, 244, 236)
    c.shape(lambda x, y: 10.5 <= math.hypot(x - cx, y - cy) <= 13.5, white)
    arms = [(cx, cy - 12), (cx, cy + 12), (cx - 8.5, cy + 8.5), (cx + 8.5, cy + 8.5)]
    c.shape(lambda x, y: any(segment_distance(x, y, cx, cy, ax, ay) <= 1.4 for ax, ay in arms), white)
    c.wear("peace", 0.18, 0.02, 4)
    return c


def no_nukes():
    """NO NUKES in black on yellow, with a red border."""
    c = Canvas(56, 22, (240, 200, 40))
    red = (196, 30, 30)
    for y in range(22):
        for x in range(56):
            if x < 2 or x > 53 or y < 2 or y > 19:
                c.set(x, y, red)
    s = "NO NUKES"
    c.text(s, (56 - c.text_width(s)) // 2, 7, (20, 18, 16))
    c.wear("no_nukes", 0.15, 0.025, 3)
    return c


def smiley():
    """A yellow smiley on black."""
    c = Canvas(20, 20, (24, 22, 26))
    c.shape(lambda x, y: math.hypot(x - 10, y - 10) <= 8.6, (250, 214, 40))
    ink = (24, 22, 26)
    for x, y in [(7, 6), (7, 7), (7, 8), (12, 6), (12, 7), (12, 8)]:
        c.set(x, y, ink)
    c.shape(lambda x, y: 4.3 <= math.hypot(x - 10, y - 9.5) <= 5.6 and y > 11.5, ink)
    c.wear("smiley", 0.12, 0.015, 0)
    return c


def recycle():
    """Three green arrows chasing each other round a triangle, on white."""
    c = Canvas(28, 28, (240, 240, 232))
    green = (36, 136, 64)
    corners = [(14 + 11 * math.cos(math.radians(a)), 15.5 + 11 * math.sin(math.radians(a))) for a in (-90, 30, 150)]
    for i in range(3):
        (ax, ay), (bx, by) = corners[i], corners[(i + 1) % 3]
        dx, dy = bx - ax, by - ay
        s0, s1, tip = (ax + dx * 0.12, ay + dy * 0.12), (ax + dx * 0.6, ay + dy * 0.6), (ax + dx * 0.9, ay + dy * 0.9)
        c.shape(lambda x, y: segment_distance(x, y, *s0, *s1) <= 1.6, green)
        n = math.hypot(dx, dy)
        ux, uy = dx / n, dy / n
        base = (ax + dx * 0.58, ay + dy * 0.58)
        head = [tip, (base[0] - uy * 4, base[1] + ux * 4), (base[0] + uy * 4, base[1] - ux * 4)]

        def in_head(x, y, h=head):
            signs = []
            for k in range(3):
                (x1, y1), (x2, y2) = h[k], h[(k + 1) % 3]
                signs.append((x2 - x1) * (y - y1) - (y2 - y1) * (x - x1) >= 0)
            return all(signs) or not any(signs)

        c.shape(in_head, green)
    c.wear("recycle", 0.2, 0.025, 3)
    return c


def rainforest():
    """SAVE THE RAINFOREST lettered by hand in green marker beside a tree, on cream paper."""
    c = Canvas(72, 32, (236, 228, 200))
    ink = (34, 110, 48)
    c.shape(lambda x, y: math.hypot(x - 7, y - 8) <= 5.5 or math.hypot(x - 4, y - 11) <= 3.5 or math.hypot(x - 10, y - 11) <= 3.5, (52, 150, 60))
    for y in range(13, 19):
        c.set(6, y, (110, 72, 40))
        c.set(7, y, (110, 72, 40))
    c.text("SAVE THE", 17, 4, ink, wobble=lambda i: (0, 1, 0, -1, 0, 1, 1, 0)[i])
    c.text("RAINFOREST", 6, 21, ink, wobble=lambda i: (1, 0, 0, 1, -1, 0, 0, 1, 0, -1)[i])
    c.wear("rainforest", 0.14, 0.03, 4)
    return c


def fist():
    """A raised black fist on red."""
    red, black, crease, sleeve = (186, 28, 32), (22, 20, 24), (84, 70, 70), (60, 56, 64)
    rows = FIST.strip().split("\n")
    c = Canvas(32, 40, red)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            colour = {"#": black, "g": crease, "S": sleeve}.get(ch)
            if colour:
                for dy in (0, 1):
                    for dx in (0, 1):
                        c.set(x * 2 + dx, y * 2 + dy, colour)
    c.wear("fist", 0.16, 0.02, 5)
    return c


def computers_for_people():
    """COMPUTERS / FOR PEOPLE in white on blue, between yellow stripes."""
    c = Canvas(68, 22, (30, 60, 150))
    for x in range(68):
        c.set(x, 1, (240, 200, 40))
        c.set(x, 20, (240, 200, 40))
    white = (246, 244, 236)
    for s, y in (("COMPUTERS", 3), ("FOR PEOPLE", 12)):
        c.text(s, (68 - c.text_width(s)) // 2, y, white)
    c.wear("computers_for_people", 0.15, 0.02, 0)
    return c


def main(folder):
    for name, draw in [("peace", peace), ("no_nukes", no_nukes), ("smiley", smiley), ("recycle", recycle),
                       ("rainforest", rainforest), ("fist", fist), ("computers_for_people", computers_for_people)]:
        draw().save(os.path.join(folder, "sticker_%s.png" % name))


main(sys.argv[1])
