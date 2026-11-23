#!/usr/bin/env python3
"""Synthesizes the heartbeat that sounds from a computer with a heart in it: one slow lub-dub,
muffled as through a computer case, as a 22050 Hz mono WAV that loops seamlessly.
Usage: make_heartbeat.py Godot/sounds"""
import math
import random
import struct
import sys
import wave

RATE = 22050
PEAK = 10 ** (-3 / 20)
BPM = 48
random.seed(1996)


def thump(freq, seconds, drop, decay):
    """A low sine that falls by [drop] of its pitch as it dies away, with a soft attack."""
    out = []
    phase = 0.0
    for i in range(int(seconds * RATE)):
        t = i / RATE
        f = freq * (1.0 - drop * min(t / seconds, 1.0))
        phase += 2 * math.pi * f / RATE
        attack = min(t / 0.012, 1.0)
        out.append(math.sin(phase) * attack * math.exp(-t / decay))
    return out


def thud(seconds, decay):
    """The wet, noisy part of a beat: low-passed noise."""
    out = []
    last = 0.0
    for i in range(int(seconds * RATE)):
        t = i / RATE
        last += 0.06 * (random.uniform(-1, 1) - last)
        out.append(last * min(t / 0.006, 1.0) * math.exp(-t / decay))
    return out


def mix(into, sound, at_seconds, gain):
    start = int(at_seconds * RATE)
    for i, s in enumerate(sound):
        into[(start + i) % len(into)] += s * gain


def lowpass(samples, alpha):
    """One-pole low-pass, run twice around the loop so that its start matches its end."""
    out = samples[:]
    last = 0.0
    for _ in range(2):
        for i, s in enumerate(samples):
            last += alpha * (s - last)
            out[i] = last
    return out


def main():
    beat = [0.0] * int(RATE * 60 / BPM)
    mix(beat, thump(58, 0.26, 0.35, 0.07), 0.0, 1.0)
    mix(beat, thud(0.12, 0.03), 0.0, 1.6)
    mix(beat, thump(74, 0.2, 0.3, 0.05), 0.3, 0.7)
    mix(beat, thud(0.08, 0.02), 0.3, 1.0)
    # The case rings faintly with each beat.
    mix(beat, thump(190, 0.15, 0.05, 0.04), 0.004, 0.05)
    beat = lowpass(beat, 0.18)
    peak = max(abs(s) for s in beat)
    path = sys.argv[1] + "/heartbeat.wav"
    with wave.open(path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(b"".join(struct.pack("<h", int(s / peak * PEAK * 32767)) for s in beat))
    print("wrote", path)


main()
