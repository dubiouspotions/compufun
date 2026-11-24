#!/usr/bin/env python3
"""Draws the floppy disk's whole surface as one texture for the BoxMesh of props/floppy_disk.tscn:
the dark plastic, the paper label with a waving Windows 95 flag and its trail on top, and the metal
shutter with its window at the end that goes into the drive. Painted into one surface, the label and
the shutter can't z-fight with the disk under the PSX vertex snap.

Each PNG is BoxMesh's 3 x 2 layout, one 90 x 94 pixel cell per face (1 pixel per millimetre of the
top): +z, +x, -z on the first row; -x, top, bottom on the second. floppy_disk_blank.png has a blank
label, for a disk with a printed one (FloppyDisk.label).
Usage: make_floppy_disk.py Godot/materials/textures
Reads dark_plastic.png and metal.png there, and writes floppy_disk.png and floppy_disk_blank.png."""
import math
import os
import struct
import sys
import zlib

SIZE_X, SIZE_Z = 90, 94  # the disk, in millimetres; also one cell, in pixels
LABEL = (-37, 37, -10, 44)  # x from, x to, z from, z to, in millimetres from the disk's middle
SHUTTER = (-25, 25, -47, -16)
WINDOW = (2, 14, -44, -22)
DARK_REPEAT, METAL_REPEAT = 3, 2  # repeats per metre, as the shared materials tile them

W, H = 74, 54  # the label's flag picture, 1 pixel per millimetre
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


def label(x, y):
    return flag(x, y) or trail(x, y) or PAPER


def read_png(path):
    """The pixels of an 8-bit RGB PNG, as rows of (r, g, b)."""
    data = open(path, "rb").read()
    pos, idat = 8, b""
    while pos < len(data):
        length, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            width, height, depth, colour_type = struct.unpack(">IIBB", body[:10])
            if depth != 8 or colour_type != 2:
                sys.exit(f"{path}: only 8-bit RGB PNGs, not depth {depth} colour type {colour_type}")
        elif kind == b"IDAT":
            idat += body
    raw, stride, rows, previous, i = zlib.decompress(idat), width * 3, [], bytearray(width * 3), 0
    for _ in range(height):
        kind, line = raw[i], bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - 3] if x >= 3 else 0
            b = previous[x]
            c = previous[x - 3] if x >= 3 else 0
            if kind == 1:
                line[x] = (line[x] + a) & 255
            elif kind == 2:
                line[x] = (line[x] + b) & 255
            elif kind == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif kind == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append([tuple(line[x:x + 3]) for x in range(0, stride, 3)])
        previous = line
    return rows


def tiled(texture, repeat, u_mm, v_mm):
    """The texel of a texture that repeats [repeat] times per metre, at u, v millimetres."""
    size = len(texture)
    return texture[int(v_mm * repeat * size / 1000) % size][int(u_mm * repeat * size / 1000) % size]


def inside(area, x, z):
    return area[0] <= x < area[1] and area[2] <= z < area[3]


def face(dark, metal, x, z, top, flagged):
    """The colour of the top or bottom at x, z millimetres from the disk's middle."""
    if top and inside(LABEL, x, z):
        return label(x - LABEL[0], z - LABEL[2]) if flagged else PAPER  # the picture's top is toward the shutter, -z
    if inside(SHUTTER, x, z) and not inside(WINDOW, x, z):
        return tiled(metal, METAL_REPEAT, x + 100, z + 100)
    return tiled(dark, DARK_REPEAT, x + 100, z + 100)


def cell(dark, metal, flagged, column, row, c, r):
    """The colour at pixel c, r of the face in the cell at column, row."""
    x_left = SIZE_X / 2 - (c + 0.5)  # x where u runs from +x to -x
    x_right = -SIZE_X / 2 + (c + 0.5)
    z = SIZE_Z / 2 - (r + 0.5)
    if (column, row) == (1, 1):
        return face(dark, metal, x_left, z, True, flagged)
    if (column, row) == (2, 1):
        return face(dark, metal, x_right, z, False, flagged)
    if (column, row) == (2, 0) and inside(SHUTTER, x_left, SHUTTER[2]):  # the shutter wraps round the -z end
        return tiled(metal, METAL_REPEAT, x_left + 100, r)
    return tiled(dark, DARK_REPEAT, c, r)


def main(textures):
    dark, metal = read_png(os.path.join(textures, "dark_plastic.png")), read_png(os.path.join(textures, "metal.png"))
    write(os.path.join(textures, "floppy_disk.png"), dark, metal, True)
    write(os.path.join(textures, "floppy_disk_blank.png"), dark, metal, False)


def write(path, dark, metal, flagged):
    rows = []
    for y in range(SIZE_Z * 2):
        row = [cell(dark, metal, flagged, x // SIZE_X, y // SIZE_Z, x % SIZE_X, y % SIZE_Z) for x in range(SIZE_X * 3)]
        rows.append(b"\0" + bytes(c for p in row for c in p))
    chunk = lambda kind, data: struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE_X * 3, SIZE_Z * 2, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(b"".join(rows), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


main(sys.argv[1])
