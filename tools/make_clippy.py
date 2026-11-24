#!/usr/bin/env python3
"""Draws our own Office Assistant, a paper clip with eyes, in the 16-colour style of Office 97's:
one PNG per pose (assistant.gd strings the poses into animations), the lightbulb lit and unlit,
and the balloon's bullet.
Usage: make_clippy.py Godot/win95/office/assistant"""
import math
import os
import struct
import sys
import zlib

W, H = 40, 68
S = 0.8  # the clip is drawn on a 48 x 84 grid and scaled to fit the assistant's 92 x 69 stage
EYE = (5.0, 4.2)  # the eyes' radii
BLACK, GREY, SILVER, WHITE = (0, 0, 0), (128, 128, 128), (192, 192, 192), (255, 255, 255)
CLEAR = None


def png(path, rows):
    raw = b""
    for row in rows:
        raw += b"\0" + b"".join(bytes(c + (255,)) if c else b"\0\0\0\0" for c in row)
    chunk = lambda kind, data: struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", len(rows[0]), len(rows), 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def wire_path():
    """The clip's wire as points along it, from the inner end to the outer end."""
    pts = []

    def line(x0, y0, x1, y1):
        n = int(max(abs(x1 - x0), abs(y1 - y0)) * 4) + 1
        pts.extend((S * (x0 + (x1 - x0) * i / n), S * (y0 + (y1 - y0) * i / n)) for i in range(n + 1))

    def bend(cx, cy, r, a0, a1):  # y grows down: from pi to 0 through pi/2 runs along the bottom
        n = int(abs(a1 - a0) * r * 4) + 1
        pts.extend((S * (cx + r * math.cos(a0 + (a1 - a0) * i / n)), S * (cy + r * math.sin(a0 + (a1 - a0) * i / n))) for i in range(n + 1))

    line(18, 30, 18, 58)  # the inner left leg, down
    bend(23.5, 58, 5.5, math.pi, 0)  # the small bottom bend
    line(29, 58, 29, 15)  # the inner right leg, up
    bend(19.5, 15, 9.5, 0, -math.pi)  # the top bend
    line(10, 15, 10, 66)  # the outer left leg, down
    bend(23.5, 66, 13.5, math.pi, 0)  # the big bottom bend
    line(37, 66, 37, 34)  # the outer right leg, up to the end
    return pts


WIRE = wire_path()


def wire_distance(x, y):
    return min(math.hypot(x - px, y - py) for px, py in WIRE)


def ellipse(x, y, cx, cy, rx, ry):
    return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2


def pose(look=(0, 0), lid=0.0, brow=0.0, frown=0.0):
    """One picture: [param look] moves the pupils, [param lid] closes the eyes (0 to 1), [param brow]
    lifts the eyebrows in pixels and [param frown] tilts them toward the middle."""
    rows = [[CLEAR] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            d = wire_distance(x + 0.5, y + 0.5)
            if d <= 1.0:
                rows[y][x] = SILVER
            elif d <= 1.8:
                rows[y][x] = SILVER if x < 24 else GREY
            elif d <= 2.7:
                rows[y][x] = BLACK
    eyes = ((12.5, 20.0), (24.5, 20.0))
    for ex, ey in eyes:
        for y in range(H):
            for x in range(W):
                e = ellipse(x + 0.5, y + 0.5, ex, ey, *EYE)
                if e > 1.45:
                    continue
                if e > 1.0:
                    rows[y][x] = BLACK
                    continue
                top = ey - EYE[1] + 2 * EYE[1] * lid
                if y + 0.5 < top:
                    rows[y][x] = SILVER  # the lid
                elif lid > 0.9 and abs(y + 0.5 - ey) < 0.8:
                    rows[y][x] = BLACK  # a closed eye is a line
                else:
                    rows[y][x] = WHITE
                    dx, dy = abs(x + 0.5 - (ex + 2 * look[0])), abs(y + 0.5 - (ey + 0.5 + 1.5 * look[1]))
                    if lid < 0.9 and dx <= 1.5 and dy <= 2.0 and not (dx > 1 and dy > 1.5):
                        rows[y][x] = BLACK  # the pupil, 3 x 4 with its corners off
        if 0.1 < lid < 0.9:
            ly = int(ey - EYE[1] + 2 * EYE[1] * lid)
            for x in range(int(ex - EYE[0]), int(ex + EYE[0]) + 1):
                if 0 <= x < W and ellipse(x + 0.5, ly + 0.5, ex, ey, *EYE) <= 1.0:
                    rows[ly][x] = BLACK
        # The eyebrow: a thick dark arc above the eye.
        inner = 1 if ex < 24 else -1
        for i in range(-5, 6):
            bx = ex + i
            by = ey - 6.5 - brow + 0.08 * i * i + frown * inner * i * 0.3
            for t in (0, 1):
                yy, xx = int(by + t), int(bx)
                if 0 <= xx < W and 0 <= yy < H:
                    rows[yy][xx] = BLACK
    return rows


POSES = {
    "rest": pose(),
    "blink_half": pose(lid=0.5),
    "blink_shut": pose(lid=1.0),
    "look_left": pose(look=(-1, 0)),
    "look_right": pose(look=(1, 0)),
    "look_up": pose(look=(0, -1), brow=1),
    "look_down": pose(look=(0, 1)),
    "brows_up": pose(brow=2),
    "brows_high": pose(look=(0, -0.5), brow=4),
    "frown": pose(look=(0, 0.5), frown=1.5),
}

BULB = [  # 15 x 24; "o" is the glass, "h" its highlight
    ".....kkkkk.....",
    "...kkoooookk...",
    "..koooooooook..",
    ".kooohhoooooook",
    ".koohhooooooook",
    "kooohoooooooook",
    "kooohoooooooook",
    "koooooooooooook",
    "koooooooooooook",
    ".koooooooooook.",
    ".koooooooooook.",
    "..koooooooook..",
    "...koooooook...",
    "....kooooook...",
    "....kooooook...",
    "....kkkkkkkk...",
    "....kwwwwwwk...",
    "....kggggggk...",
    "....kwwwwwwk...",
    "....kggggggk...",
    ".....kwwwwk....",
    "......kkkk.....",
    "...............",
    "...............",
]

BULLET = [  # 11 x 11: the blue ball before each choice in a balloon
    "...kkkkk...",
    "..kBBBBBk..",
    ".kBBcwBBBk.",
    "kBBcwwcBBBk",
    "kBBcwcBBBBk",
    "kBBBBBBBBBk",
    "kBBBBBBBBBk",
    "kBBBBBBBBBk",
    ".kBBBBBBBk.",
    "..kBBBBBk..",
    "...kkkkk...",
]


def from_text(lines, colours):
    return [[colours.get(ch) for ch in line] for line in lines]


def main(out):
    os.makedirs(out, exist_ok=True)
    for name, rows in POSES.items():
        png(os.path.join(out, "clippy_%s.png" % name), rows)
    base = {".": CLEAR, "k": BLACK, "w": WHITE, "g": GREY, "h": WHITE}
    png(os.path.join(out, "bulb_lit.png"), from_text(BULB, dict(base, o=(255, 255, 0))))
    png(os.path.join(out, "bulb_unlit.png"), from_text(BULB, dict(base, o=SILVER)))
    png(os.path.join(out, "bullet.png"), from_text(BULLET, {".": CLEAR, "k": (0, 0, 128), "B": (0, 0, 255), "c": (0, 255, 255), "w": WHITE}))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
