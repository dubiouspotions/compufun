#!/usr/bin/env python3
"""Synthesizes case_stab.wav, the stab as the case of Skater Bro's computer opens on his organs, as a
22050 Hz mono WAV: a dissonant cluster, a screech over it, a boom and a wet squelch under it.
Usage: make_case_stab.py Godot/sounds"""
import math
import random
import struct
import sys
import wave

RATE = 22050
PEAK = 10 ** (-3 / 20)


def save(name, samples):
    peak = max(abs(s) for s in samples)
    path = "%s/%s" % (sys.argv[1], name)
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(s / peak * PEAK * 32767)) for s in samples))
    print("wrote", path)

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
    return out


def stab():
    """A dissonant cluster with a hard attack, a screech over it and a boom under it, dying out."""
    seconds = 1.8
    n = int(seconds * RATE)
    out = [0.0] * n
    for freq in [110.0, 116.5, 164.8, 174.6, 233.1, 246.9]:
        phase = random.uniform(0, 1)
        for i in range(n):
            t = i / RATE
            saw = 2 * ((freq * t * (1 + 0.004 * math.sin(2 * math.pi * 5.5 * t)) + phase) % 1.0) - 1
            out[i] += saw * math.exp(-t / 0.55) * min(t / 0.004, 1.0) * 0.25
    screech = bandpass([random.uniform(-1, 1) for _ in range(n)], [2600 - 900 * i / n for i in range(n)], 9.0)
    for i in range(n):
        t = i / RATE
        out[i] += screech[i] * 2.2 * math.exp(-t / 0.35) * min(t / 0.01, 1.0)
        out[i] += 0.9 * math.sin(2 * math.pi * (55 - 20 * min(t / 0.6, 1.0)) * t) * math.exp(-t / 0.4)
    wet = squelch(0.5, 4, 300, 1100)
    peak = max(abs(s) for s in wet)
    for i, s in enumerate(wet):
        out[i + int(0.05 * RATE)] += s / peak * 0.5
    return out


def main():
    random.seed(13)
    save("case_stab.wav", stab())


main()
