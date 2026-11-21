#!/usr/bin/env python3
"""Synthesizes the CRT monitor's power on, power off, degauss and relay sounds as 22050 Hz mono WAVs.
Usage: make_crt_sounds.py Godot/sounds"""
import math
import random
import struct
import sys
import wave

RATE = 22050
PEAK = 10 ** (-3 / 20)
random.seed(95)


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def mix(into, sound, at_seconds, gain=1.0):
    start = int(at_seconds * RATE)
    if len(into) < start + len(sound):
        into.extend([0.0] * (start + len(sound) - len(into)))
    for i, s in enumerate(sound):
        into[start + i] += s * gain


def norm(samples):
    peak = max(abs(s) for s in samples)
    return [s / peak for s in samples]


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


def ring(samples, freq, decay):
    """A two-pole resonator: each input transient rings at freq and dies away over decay seconds."""
    r = math.exp(-1.0 / (decay * RATE))
    a1, a2 = 2 * r * math.cos(2 * math.pi * freq / RATE), -r * r
    out, y1, y2 = [], 0.0, 0.0
    for s in samples:
        y = s + a1 * y1 + a2 * y2
        out.append(y)
        y1, y2 = y, y1
    return out


def noise(seconds, decay):
    return [random.uniform(-1, 1) * math.exp(-i / RATE / decay) for i in range(int(seconds * RATE))]


def ping(freq, seconds, decay):
    return [math.sin(2 * math.pi * freq * i / RATE) * math.exp(-i / RATE / decay) for i in range(int(seconds * RATE))]


def rocker_clunk():
    """The rocker switch: two contact clicks over a low, damped thump of the plastic case."""
    out = []
    phase = 0.0
    for i in range(int(0.3 * RATE)):
        t = i / RATE
        phase += 2 * math.pi * (55 + 70 * math.exp(-t / 0.02)) / RATE
        out.append((math.sin(phase) + 0.4 * math.sin(2 * phase)) * math.exp(-t / 0.06))
    mix(out, ping(230, 0.12, 0.02), 0, 0.6)
    mix(out, lowpass(noise(0.08, 0.015), 600), 0, 1.2)
    mix(out, highpass(noise(0.005, 0.0008), 2500), 0, 0.9)
    mix(out, highpass(noise(0.004, 0.0006), 3000), 0.007, 0.5)
    return out


def crackles(seconds, rate, decay):
    """Sparse static discharges: a Poisson stream whose rate and loudness die away over decay seconds."""
    out = silence(seconds)
    t = 0.0
    while True:
        t += random.expovariate(rate * math.exp(-t / decay))
        if t >= seconds:
            break
        length = random.uniform(0.0005, 0.003)
        mix(out, noise(length, length / 3), t, random.random() ** 2 * math.exp(-t / decay))
    return highpass(out, 1500)


def power_on():
    out = silence(1.5)
    mix(out, norm(rocker_clunk()), 0, 1.0)
    fsss = lowpass(highpass(noise(1.4, 10), 2500), 7000)
    fsss = [s * (1 - math.exp(-i / RATE / 0.06)) * math.exp(-i / RATE / 0.3) for i, s in enumerate(fsss)]
    mix(out, norm(fsss), 0.06, 0.2)
    mix(out, norm(crackles(1.35, 45, 0.35)), 0.08, 0.45)
    for at, gain in [(0.11, 0.7), (0.19, 0.5), (0.34, 0.35)]:
        mix(out, highpass(noise(0.004, 0.0012), 1200), at, gain)  # a few big snaps make it chunky
    return out


def button_click():
    out = highpass(noise(0.004, 0.0007), 2500)
    mix(out, ping(1800, 0.03, 0.004), 0, 0.5)
    mix(out, ping(600, 0.04, 0.008), 0, 0.4)
    return out


def degauss_hum(seconds):
    """Mains hum through the coil: near-square at full current, softening to a sine as the thermistor chokes it."""
    out = []
    w = 2 * math.pi * 50 / RATE
    for i in range(int(seconds * RATE)):
        env = (1 - math.exp(-i / RATE / 0.004)) * math.exp(-i / RATE / 0.5)
        drive = 1 + 6 * env
        base = math.sin(w * i) + 0.25 * math.sin(3 * w * i + 0.3)
        out.append(env * math.tanh(drive * base) / math.tanh(drive))
    return lowpass(lowpass(out, 2000), 2000)


def degauss_rattle(seconds):
    """The coil and shield buzz at twice mains, irregularly, and only while the current is high."""
    cycles = [random.uniform(0.5, 1.0) for _ in range(int(seconds * 100) + 1)]
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        env = max(0.0, math.exp(-t / 0.35) - 0.08) / 0.92
        pulse = max(0.0, math.sin(2 * math.pi * 100 * t)) ** 6 * cycles[int(t * 100)]
        out.append(random.uniform(-1, 1) * pulse * env)
    buzz = highpass(out, 300)
    mix(buzz, norm(ring(out, 820, 0.015)), 0, 0.6)
    mix(buzz, norm(ring(out, 2300, 0.006)), 0, 0.4)
    return buzz


def degauss():
    out = silence(2.2)
    mix(out, norm(button_click()), 0, 0.5)
    mix(out, norm(degauss_hum(2.15)), 0.04, 1.0)
    mix(out, norm(degauss_rattle(2.15)), 0.04, 0.5)
    return out


def zip_down(seconds, start, end):
    out = []
    phase = 0.0
    for i in range(int(seconds * RATE)):
        t = i / RATE
        phase += 2 * math.pi * start * (end / start) ** (t / seconds) / RATE
        env = (1 - math.exp(-t / 0.003)) * (1 - t / seconds) ** 1.5
        out.append(env * (math.sin(phase) + 0.3 * math.sin(2 * phase)))
    return lowpass(out, 5000)


def power_off():
    out = silence(1.2)
    mix(out, norm(rocker_clunk()), 0, 1.0)
    mix(out, norm(zip_down(0.2, 3000, 200)), 0.03, 0.35)
    mix(out, norm(crackles(0.9, 20, 0.4)), 0.25, 0.25)
    return out


def relay_clack(freqs):
    out = highpass(noise(0.003, 0.0006), 3000)
    mix(out, ping(freqs[0], 0.04, 0.006), 0, 0.5)
    mix(out, ping(freqs[1], 0.03, 0.003), 0, 0.3)
    mix(out, ping(450, 0.03, 0.004), 0, 0.4)
    return out


def relay():
    out = silence(0.2)
    mix(out, norm(relay_clack((3150, 5400))), 0.004, 1.0)
    mix(out, norm(relay_clack((3700, 6100))), 0.054, 0.5)
    return out


def write(path, samples):
    gain = PEAK / max(abs(s) for s in samples)
    fade = int(0.02 * RATE)
    data = bytearray()
    for i, s in enumerate(samples):
        if i >= len(samples) - fade:
            s *= (len(samples) - 1 - i) / fade
        data += struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767))
    try:
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(bytes(data))
    except OSError as e:
        sys.exit(f"make_crt_sounds.py: cannot write {path}: {e}")


write(sys.argv[1] + "/crt_power_on.wav", power_on())
write(sys.argv[1] + "/crt_degauss.wav", degauss())
write(sys.argv[1] + "/crt_power_off.wav", power_off())
write(sys.argv[1] + "/crt_relay.wav", relay())
