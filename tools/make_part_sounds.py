#!/usr/bin/env python3
"""Synthesizes the sounds of loose computer parts as 22050 Hz mono WAVs: three clunks of a part
landing in a case, and the rattle of loose parts in a tipping case.
Usage: make_part_sounds.py Godot/sounds"""
import math
import random
import struct
import sys
import wave

RATE = 22050
random.seed(1996)


def knock(gain, modes):
    """A part hitting metal or a board: a click of noise and a few damped ringing modes."""
    n = int(0.18 * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        click = random.uniform(-1.0, 1.0) * math.exp(-t / 0.004)
        ring = sum(a * math.sin(2.0 * math.pi * hz * t) * math.exp(-t / decay) for hz, a, decay in modes)
        out.append(gain * (0.6 * click + ring))
    return out


def random_modes():
    base = random.uniform(380.0, 700.0)
    return [(base, 0.5, 0.035), (base * random.uniform(2.2, 2.9), 0.3, 0.02), (base * random.uniform(4.8, 6.1), 0.15, 0.012)]


def mix(into, sound, at):
    start = int(at * RATE)
    if len(into) < start + len(sound):
        into.extend([0.0] * (start + len(sound) - len(into)))
    for i, s in enumerate(sound):
        into[start + i] += s


def normalised(samples, peak_db):
    peak = max(abs(s) for s in samples)
    gain = 10 ** (peak_db / 20) / peak
    return [s * gain for s in samples]


def write(path, samples):
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    folder = sys.argv[1]
    for take in range(1, 4):
        clunk = knock(1.0, random_modes())
        mix(clunk, knock(0.35, random_modes()), random.uniform(0.03, 0.06))  # it settles
        write("%s/part_clunk_%d.wav" % (folder, take), normalised(clunk, -3.0))
    rattle = []
    at = 0.0
    while at < 0.55:
        mix(rattle, knock(random.uniform(0.3, 1.0) * (1.0 - at), random_modes()), at)
        at += random.uniform(0.02, 0.09)
    write(folder + "/part_rattle.wav", normalised(rattle, -3.0))
