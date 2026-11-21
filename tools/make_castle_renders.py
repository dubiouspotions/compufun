#!/usr/bin/env python3
"""Renders Pierre's three castle pictures (Godot/customers/pierre/castle_0N.png), as his 1996
raytracer would: a first flat try, a second with shadows, and a full render that stops partway
down because the computer switched itself off. Pure Python; takes about a minute.

Usage: python3 tools/make_castle_renders.py
"""
import math
import os
import struct
import zlib

W, H = 320, 200
OUT = os.path.join(os.path.dirname(__file__), "..", "Godot", "customers", "pierre")


def sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def mul(a, s): return (a[0] * s, a[1] * s, a[2] * s)
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def norm(a):
    l = math.sqrt(dot(a, a))
    return (a[0] / l, a[1] / l, a[2] / l)


class Plane:
    def __init__(self, y, reflect):
        self.y, self.reflect = y, reflect

    def hit(self, o, d):
        if abs(d[1]) < 1e-9:
            return None
        t = (self.y - o[1]) / d[1]
        return t if t > 1e-4 else None

    def normal(self, p): return (0.0, 1.0, 0.0)

    def color(self, p):
        return (0.95, 0.85, 0.1) if (math.floor(p[0]) + math.floor(p[2])) % 2 == 0 else (0.15, 0.15, 0.6)


class Sphere:
    def __init__(self, c, r, col, reflect=0.0):
        self.c, self.r, self.col, self.reflect = c, r, col, reflect

    def hit(self, o, d):
        oc = sub(o, self.c)
        b = dot(oc, d)
        disc = b * b - (dot(oc, oc) - self.r * self.r)
        if disc < 0:
            return None
        s = math.sqrt(disc)
        for t in (-b - s, -b + s):
            if t > 1e-4:
                return t
        return None

    def normal(self, p): return norm(sub(p, self.c))
    def color(self, p): return self.col


class Box:
    def __init__(self, lo, hi, col):
        self.lo, self.hi, self.col, self.reflect = lo, hi, col, 0.0

    def hit(self, o, d):
        t0, t1 = -1e9, 1e9
        for i in range(3):
            if abs(d[i]) < 1e-9:
                if o[i] < self.lo[i] or o[i] > self.hi[i]:
                    return None
                continue
            a, b = (self.lo[i] - o[i]) / d[i], (self.hi[i] - o[i]) / d[i]
            if a > b:
                a, b = b, a
            t0, t1 = max(t0, a), min(t1, b)
            if t0 > t1:
                return None
        if t0 > 1e-4:
            return t0
        return t1 if t1 > 1e-4 else None

    def normal(self, p):
        best, n = 1e9, (0.0, 1.0, 0.0)
        for i in range(3):
            for v, s in ((self.lo[i], -1.0), (self.hi[i], 1.0)):
                if abs(p[i] - v) < best:
                    best = abs(p[i] - v)
                    n = tuple(s if j == i else 0.0 for j in range(3))
        return n

    def color(self, p):
        # Stone blocks: darker mortar lines every 0.25 up and every 0.5 along.
        row = math.floor(p[1] * 4)
        along = p[0] if abs(self.normal(p)[2]) > 0.5 else p[2]
        if (p[1] * 4) % 1 < 0.08 or ((along + 0.25 * (row % 2)) * 2) % 1 < 0.04:
            return mul(self.col, 0.6)
        return self.col


class Cylinder:
    """Vertical, capped."""

    def __init__(self, x, z, r, y0, y1, col):
        self.x, self.z, self.r, self.y0, self.y1, self.col, self.reflect = x, z, r, y0, y1, col, 0.0

    def hit(self, o, d):
        best = None
        ox, oz = o[0] - self.x, o[2] - self.z
        a = d[0] * d[0] + d[2] * d[2]
        if a > 1e-9:
            b = ox * d[0] + oz * d[2]
            disc = b * b - a * (ox * ox + oz * oz - self.r * self.r)
            if disc >= 0:
                s = math.sqrt(disc)
                for t in ((-b - s) / a, (-b + s) / a):
                    if t > 1e-4 and self.y0 <= o[1] + t * d[1] <= self.y1:
                        best = t
                        break
        if abs(d[1]) > 1e-9:
            t = (self.y1 - o[1]) / d[1]
            if t > 1e-4 and (best is None or t < best):
                px, pz = o[0] + t * d[0] - self.x, o[2] + t * d[2] - self.z
                if px * px + pz * pz <= self.r * self.r:
                    best = t
        return best

    def normal(self, p):
        if abs(p[1] - self.y1) < 1e-3:
            return (0.0, 1.0, 0.0)
        return norm((p[0] - self.x, 0.0, p[2] - self.z))

    def color(self, p): return Box.color(self, p)


class Cone:
    """Vertical, point up."""

    def __init__(self, x, z, r, y0, h, col):
        self.x, self.z, self.r, self.y0, self.h, self.col, self.reflect = x, z, r, y0, h, col, 0.0

    def hit(self, o, d):
        k = (self.r / self.h) ** 2
        ox, oz, oy = o[0] - self.x, o[2] - self.z, o[1] - (self.y0 + self.h)
        a = d[0] * d[0] + d[2] * d[2] - k * d[1] * d[1]
        b = ox * d[0] + oz * d[2] - k * oy * d[1]
        c = ox * ox + oz * oz - k * oy * oy
        if abs(a) < 1e-9:
            return None
        disc = b * b - a * c
        if disc < 0:
            return None
        s = math.sqrt(disc)
        for t in sorted(((-b - s) / a, (-b + s) / a)):
            y = o[1] + t * d[1]
            if t > 1e-4 and self.y0 <= y <= self.y0 + self.h:
                return t
        return None

    def normal(self, p):
        dx, dz = p[0] - self.x, p[2] - self.z
        l = math.sqrt(dx * dx + dz * dz) or 1.0
        return norm((dx / l, self.r / self.h, dz / l))

    def color(self, p): return self.col


STONE = (0.75, 0.72, 0.65)
ROOF = (0.8, 0.15, 0.1)


def castle(detail):
    objects = [Plane(0.0, 0.25 if detail >= 3 else 0.0)]
    objects.append(Box((-2.0, 0.0, 2.0), (2.0, 1.5, 2.6), STONE))
    objects.append(Box((-0.5, 0.0, 1.9), (0.5, 0.9, 2.0), (0.25, 0.15, 0.08)))  # the gate
    if detail >= 2:
        for i in range(8):
            x = -2.0 + i * 0.55
            objects.append(Box((x, 1.5, 2.0), (x + 0.28, 1.8, 2.6), STONE))
    for x in (-2.2, 2.2):
        objects.append(Cylinder(x, 2.3, 0.6, 0.0, 2.4, STONE))
        if detail >= 2:
            objects.append(Cone(x, 2.3, 0.75, 2.4, 1.2, ROOF))
    objects.append(Sphere((1.1, 0.6, 0.3), 0.6, (0.9, 0.9, 0.95), 0.7 if detail >= 3 else 0.0))
    return objects


LIGHT = (-4.0, 8.0, -5.0)
EYE = (0.6, 1.6, -5.0)
LOOK = (0.0, 1.2, 2.0)


def trace(objects, o, d, detail, depth):
    best_t, best = None, None
    for obj in objects:
        t = obj.hit(o, d)
        if t is not None and (best_t is None or t < best_t):
            best_t, best = t, obj
    if best is None:
        k = max(0.0, d[1])
        return (0.25 + 0.4 * k, 0.45 + 0.4 * k, 0.9)
    p = add(o, mul(d, best_t))
    n = best.normal(p)
    base = best.color(p)
    if detail == 1:
        return mul(base, 0.85 if n[1] > 0.5 else 0.65)  # flat: no light direction yet
    to_light = norm(sub(LIGHT, p))
    lit = max(0.0, dot(n, to_light))
    if lit > 0:
        dist = math.sqrt(dot(sub(LIGHT, p), sub(LIGHT, p)))
        for obj in objects:
            t = obj.hit(p, to_light)
            if t is not None and t < dist:
                lit = 0.0
                break
    col = mul(base, 0.25 + 0.75 * lit)
    if detail >= 3 and lit > 0:
        half = norm(sub(to_light, d))
        spec = max(0.0, dot(n, half)) ** 40
        col = add(col, (spec, spec, spec))
    if detail >= 3 and best.reflect > 0 and depth < 3:
        r = sub(d, mul(n, 2 * dot(d, n)))
        col = add(mul(col, 1 - best.reflect), mul(trace(objects, p, r, detail, depth + 1), best.reflect))
    return col


def render(detail, stop_row=H):
    objects = castle(detail)
    fwd = norm(sub(LOOK, EYE))
    right = norm((fwd[2], 0.0, -fwd[0]))
    up = (fwd[1] * right[2] - fwd[2] * right[1], fwd[2] * right[0] - fwd[0] * right[2], fwd[0] * right[1] - fwd[1] * right[0])
    rows = []
    for y in range(H):
        row = bytearray()
        for x in range(W):
            if y >= stop_row:
                row += b"\0\0\0"
                continue
            u = (x + 0.5 - W / 2) / H * 1.1
            v = (H / 2 - y - 0.5) / H * 1.1
            d = norm(add(fwd, add(mul(right, u), mul(up, v))))
            c = trace(objects, EYE, d, detail, 0)
            if detail == 1:
                c = tuple(round(min(1.0, k) * 3) / 3 for k in c)  # few colours, as a first test
            row += bytes(int(min(1.0, max(0.0, k)) * 255) for k in c)
        rows.append(bytes(row))
    return rows


def save_png(path, rows):
    raw = b"".join(b"\0" + r for r in rows)

    def chunk(t, data):
        return struct.pack(">I", len(data)) + t + data + struct.pack(">I", zlib.crc32(t + data) & 0xFFFFFFFF)

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", W, H, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for n, (detail, stop) in enumerate(((1, H), (2, H), (3, 146)), 1):
        path = os.path.join(OUT, "castle_%02d.png" % n)
        save_png(path, render(detail, stop))
        print("wrote", os.path.normpath(path))
