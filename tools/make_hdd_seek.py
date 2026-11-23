#!/usr/bin/env python3
"""Synthesizes hdd_seek_<n>.wav, the work computer's hard drive seeking while CompuFunDB searches:
a burst of one to four dry ticks of the head actuator, each a short damped ring over a soft thump.
22050 Hz mono WAVs. Seeded, so a re-run makes the same takes.
Usage: make_hdd_seek.py Godot/sounds"""
import math
import random
import struct
import sys
import wave

RATE = 22050
TAKES = 5
PEAK = 10 ** (-12 / 20)


def tick(rng):
    out = []
    ring, ring2, thump = rng.uniform(1600, 2200), rng.uniform(3200, 4200), rng.uniform(160, 240)
    for i in range(int(0.03 * RATE)):
        t = i / RATE
        s = 0.6 * math.sin(2 * math.pi * ring * t) * math.exp(-t / 0.004)
        s += 0.3 * math.sin(2 * math.pi * ring2 * t) * math.exp(-t / 0.002)
        s += 0.5 * math.sin(2 * math.pi * thump * t) * math.exp(-t / 0.008)
        s += 0.15 * rng.uniform(-1, 1) * math.exp(-t / 0.001)
        out.append(s)
    return out


def take(rng):
    samples = [0.0] * int(0.2 * RATE)
    at = int(0.005 * RATE)
    for _ in range(rng.randint(1, 4)):
        gain = rng.uniform(0.6, 1.0)
        for i, s in enumerate(tick(rng)):
            if at + i < len(samples):
                samples[at + i] += s * gain
        at += int(rng.uniform(0.012, 0.045) * RATE)
    peak = max(abs(s) for s in samples)
    return [s / peak * PEAK for s in samples]


def write(path, samples):
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    rng = random.Random(386)
    for n in range(1, TAKES + 1):
        write(f"{sys.argv[1]}/hdd_seek_{n}.wav", take(rng))
