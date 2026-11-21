#!/usr/bin/env python3
"""Synthesizes the ceiling mouse's squeak as a 22050 Hz mono WAV: three short chirps that rise and fall.
Usage: make_mouse_squeak.py Godot/sounds"""
import math
import os
import random
import struct
import sys
import wave

RATE = 22050
PEAK = 10 ** (-3 / 20)
random.seed(96)

# (start in seconds, length in seconds, lowest pitch, highest pitch) of each chirp.
CHIRPS = [(0.0, 0.075, 3100, 4700), (0.115, 0.06, 3400, 5000), (0.21, 0.11, 2900, 4500)]


def chirp(length, low, high):
    out, phase = [], 0.0
    count = int(length * RATE)
    for i in range(count):
        t = i / count
        pitch = low + (high - low) * math.sin(math.pi * t) + 180 * math.sin(2 * math.pi * 38 * i / RATE)
        phase += 2 * math.pi * pitch / RATE
        envelope = min(1.0, t / 0.08) * min(1.0, (1 - t) / 0.35)
        out.append(envelope * (math.sin(phase) + 0.25 * math.sin(2 * phase) + 0.04 * random.uniform(-1, 1)))
    return out


def main():
    if len(sys.argv) != 2 or not os.path.isdir(sys.argv[1]):
        sys.exit("usage: make_mouse_squeak.py <existing output folder>")
    end = max(start + length for start, length, _, _ in CHIRPS)
    sound = [0.0] * int((end + 0.03) * RATE)
    for start, length, low, high in CHIRPS:
        for i, s in enumerate(chirp(length, low, high)):
            sound[int(start * RATE) + i] += s
    loudest = max(abs(s) for s in sound)
    path = os.path.join(sys.argv[1], "mouse_squeak.wav")
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(s / loudest * PEAK * 32767)) for s in sound))
    print(f"{path}: {len(sound) / RATE:.2f} s")


main()
