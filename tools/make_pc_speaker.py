#!/usr/bin/env python3
"""Synthesizes the PC speaker's tone, a 22050 Hz mono WAV that the beep patterns gate.
Usage: make_pc_speaker.py Godot/sounds"""
import math
import struct
import sys
import wave

RATE = 22050
HZ = 880.0
SECONDS = 3.0
PEAK = 10 ** (-12 / 20)


def tone():
    out, y = [], 0.0
    a = 1.0 - math.exp(-2.0 * math.pi * 6000.0 / RATE)  # the tiny cone rounds the square's edges
    for i in range(int(SECONDS * RATE)):
        square = 1.0 if math.sin(2.0 * math.pi * HZ * i / RATE) >= 0.0 else -1.0
        y += a * (square - y)
        out.append(y * PEAK)
    return out


def write(path, samples):
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    write(sys.argv[1] + "/pc_speaker.wav", tone())
