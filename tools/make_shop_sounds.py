#!/usr/bin/env python3
"""Synthesizes the shop's door bell and phone sounds as 22050 Hz mono WAVs.
Usage: make_shop_sounds.py Godot/sounds"""
import math
import random
import struct
import sys
import wave

RATE = 22050
random.seed(95)


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def mix(into, sound, at_seconds, gain=1.0):
    start = int(at_seconds * RATE)
    if len(into) < start + len(sound):
        into.extend([0.0] * (start + len(sound) - len(into)))
    for i, s in enumerate(sound):
        into[start + i] += s * gain


def lowpass(samples, cutoff):
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for s in samples:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [s - l for s, l in zip(samples, low)]


def noise(seconds, decay):
    return [random.uniform(-1, 1) * math.exp(-i / RATE / decay) for i in range(int(seconds * RATE))]


def bell_strike(seconds):
    """A small brass bell: inharmonic partials, each a slightly detuned pair that beats."""
    partials = [(2093.0, 1.0, 1.1), (4980.0, 0.45, 0.5), (8150.0, 0.2, 0.25)]
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        s = 0.0
        for freq, amp, decay in partials:
            env = amp * math.exp(-t / decay)
            s += env * (math.sin(2 * math.pi * freq * t) + 0.6 * math.sin(2 * math.pi * freq * 1.004 * t))
        out.append(s)
    mix(out, highpass(noise(0.01, 0.002), 3000), 0, 0.6)  # the clapper's tick
    return out


def door_bell():
    out = silence(1.6)
    for at, gain in [(0.0, 1.0), (0.13, 0.7), (0.29, 0.45), (0.5, 0.25)]:
        mix(out, bell_strike(1.6 - at), at, gain)
    return out


def dtmf(row, col, seconds):
    return [0.5 * (math.sin(2 * math.pi * row * i / RATE) + math.sin(2 * math.pi * col * i / RATE)) for i in range(int(seconds * RATE))]


def phone_receiver():
    """The receiver lifts off the cradle (a plastic knock and the hook switch), then the number dials."""
    out = silence(0.2)
    knock = [math.sin(2 * math.pi * 140 * i / RATE) * math.exp(-i / RATE / 0.025) for i in range(int(0.12 * RATE))]
    mix(out, knock, 0.0, 0.8)
    mix(out, lowpass(highpass(noise(0.08, 0.015), 400), 3500), 0.0, 0.9)
    mix(out, highpass(noise(0.006, 0.0015), 2000), 0.11, 0.7)
    keys = {"0": (941, 1336), "1": (697, 1209), "5": (770, 1336), "6": (770, 1477), "9": (852, 1477)}
    at = 0.45
    for digit in "5550196":
        mix(out, dtmf(*keys[digit], 0.085), at, 0.35)
        at += 0.14
    mix(out, silence(0.1), at)
    return out


def write(path, samples):
    peak = max(abs(s) for s in samples)
    gain = 0.7 / peak
    fade = int(0.01 * RATE)
    data = bytearray()
    for i, s in enumerate(samples):
        if i >= len(samples) - fade:
            s *= (len(samples) - i) / fade
        data += struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767))
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(data))


write(sys.argv[1] + "/door_bell.wav", door_bell())
write(sys.argv[1] + "/phone_receiver.wav", phone_receiver())
