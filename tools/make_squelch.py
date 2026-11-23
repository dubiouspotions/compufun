#!/usr/bin/env python3
"""Synthesizes four wet squelches (an organ in a hand, blood shifting in a computer) as 22050 Hz mono
WAVs: noise through a resonant band that sweeps, in a few sticky bursts.
Usage: make_squelch.py Godot/sounds"""
import math
import random
import struct
import sys
import wave

RATE = 22050
PEAK = 10 ** (-3 / 20)
random.seed(666)


def bandpass(samples, freqs, q):
    """A resonant band-pass (RBJ biquad) whose centre follows freqs, one per sample."""
    out = []
    x1 = x2 = y1 = y2 = 0.0
    for x, f in zip(samples, freqs):
        w = 2 * math.pi * f / RATE
        alpha = math.sin(w) / (2 * q)
        a0 = 1 + alpha
        b0, b2 = alpha / a0, -alpha / a0
        a1, a2 = -2 * math.cos(w) / a0, (1 - alpha) / a0
        y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def squelch(seconds, bursts, start_hz, end_hz):
    n = int(seconds * RATE)
    noise = [random.uniform(-1, 1) for _ in range(n)]
    freqs = []
    for i in range(n):
        t = i / n
        wobble = 1 + 0.25 * math.sin(t * math.pi * random.uniform(6, 10))
        freqs.append((start_hz + (end_hz - start_hz) * t) * wobble)
    wet = bandpass(noise, freqs, 6.0)
    starts = sorted(random.uniform(0, seconds * 0.7) for _ in range(bursts))
    env = [0.0] * n
    for s in starts:
        length = random.uniform(0.04, 0.14)
        for i in range(int(s * RATE), min(n, int((s + length) * RATE))):
            t = (i / RATE - s) / length
            env[i] = max(env[i], max(0.0, math.sin(math.pi * t)) ** 0.5 * random.uniform(0.85, 1.0))
    out = [w * e for w, e in zip(wet, env)]
    # A soft low thump under the first burst: something heavy and wet settling.
    for i in range(int(0.12 * RATE)):
        t = i / RATE
        j = int(starts[0] * RATE) + i
        if j < n:
            out[j] += 0.15 * math.sin(2 * math.pi * 90 * t) * math.exp(-t / 0.04)
    peak = max(abs(s) for s in out)
    return [s / peak * PEAK for s in out]


def main():
    takes = [(0.45, 4, 250, 900), (0.35, 3, 700, 300), (0.55, 5, 300, 1300), (0.3, 2, 900, 400)]
    for i, take in enumerate(takes, 1):
        path = "%s/squelch_%d.wav" % (sys.argv[1], i)
        with wave.open(path, "wb") as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes(b"".join(struct.pack("<h", int(s * 32767)) for s in squelch(*take)))
        print("wrote", path)


main()
