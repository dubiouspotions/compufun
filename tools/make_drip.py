#!/usr/bin/env python3
"""Synthesizes three takes of a drop landing in a puddle: drip_1.wav to drip_3.wav, 22050 Hz mono.
Each is a rising bubble tone over a soft thump and a short splash of noise.
Usage: make_drip.py Godot/sounds"""
import math
import random
import struct
import sys
import wave

RATE = 22050
SECONDS = 0.3
PEAK = 10 ** (-3 / 20)
# Per take: the bubble's start and end pitch in Hz, how long it rises, its decay and the thump's pitch.
TAKES = [
    (520.0, 1250.0, 0.045, 0.030, 170.0),
    (600.0, 1450.0, 0.038, 0.024, 190.0),
    (470.0, 1100.0, 0.050, 0.034, 155.0),
]


def drip(start_hz, end_hz, rise, decay, thump_hz, rng):
    out, phase, thump_phase, noise = [], 0.0, 0.0, 0.0
    bubble_at = 0.006  # the bubble rings a moment after the impact
    for i in range(int(SECONDS * RATE)):
        t = i / RATE
        thump_phase += 2.0 * math.pi * thump_hz / RATE
        s = 0.5 * math.sin(thump_phase) * math.exp(-t / 0.012) * min(1.0, t / 0.001)
        noise += 0.35 * (rng.uniform(-1.0, 1.0) - noise)  # a little low-passed
        s += 0.25 * noise * math.exp(-t / 0.004)
        if t >= bubble_at:
            b = t - bubble_at
            hz = start_hz + (end_hz - start_hz) * min(1.0, b / rise)
            phase += 2.0 * math.pi * hz / RATE
            s += math.sin(phase) * math.exp(-b / decay) * min(1.0, b / 0.002)
        out.append(s)
    top = max(abs(s) for s in out)
    fade = int(0.02 * RATE)
    return [s / top * PEAK * min(1.0, (len(out) - i) / fade) for i, s in enumerate(out)]


def write(path, samples):
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    rng = random.Random(7)
    for n, take in enumerate(TAKES, 1):
        write("%s/drip_%d.wav" % (sys.argv[1], n), drip(*take, rng))
