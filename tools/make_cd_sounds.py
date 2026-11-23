#!/usr/bin/env python3
"""Synthesizes a CD-ROM drive's eject button, tray opening and tray closing as 22050 Hz mono WAVs.
The tray sounds assume Godot/props/cd_drive.gd's default timing: the motor starts MOTOR_DELAY
after the press and the tray travels SLIDE seconds. Usage: make_cd_sounds.py Godot/sounds"""
import math
import random
import struct
import sys
import wave

RATE = 22050
PEAK = 10 ** (-3 / 20)
MOTOR_DELAY = 0.25
SLIDE = 0.9
random.seed(96)


def mix(into, sound, at_seconds, gain=1.0):
    start = int(at_seconds * RATE)
    if len(into) < start + len(sound):
        into.extend([0.0] * (start + len(sound) - len(into)))
    for i, s in enumerate(sound):
        into[start + i] += s * gain


def norm(samples):
    peak = max(abs(s) for s in samples) or 1.0
    return [s / peak for s in samples]


def lowpass(samples, cutoff):
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for s in samples:
        y += a * (s - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    return [s - l for s, l in zip(samples, lowpass(samples, cutoff))]


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


def click(freqs, decay, gain=1.0):
    """A small plastic click: a burst of noise ringing a few resonances of the bezel."""
    burst = highpass(noise(0.004, 0.0015), 1500)
    out = [0.0] * int(0.12 * RATE)
    for f in freqs:
        mix(out, ring(burst + [0.0] * int(0.12 * RATE), f, decay), 0.0)
    return [s * gain for s in norm(out)]


def clunk(heavy):
    """The tray hitting its stop: a dull thump of the case and a rattle of the tray in its rails."""
    thump = lowpass(noise(0.03, 0.008), 900)
    out = norm(ring(thump + [0.0] * int(0.25 * RATE), 140 if heavy else 190, 0.035))
    mix(out, click([2300, 3900], 0.012, 0.7), 0.0)
    mix(out, click([3100], 0.008, 0.25), 0.045)
    return norm(out)


def motor(seconds):
    """The tray motor through its plastic gears: a buzzy whine, the gear teeth chattering, and
    grit in the rails. It spins up and runs down at the ends."""
    out = []
    phase, teeth = 0.0, 0.0
    grit = lowpass(highpass(noise(seconds, 99.0), 700), 3000)
    for i in range(int(seconds * RATE)):
        t = i / RATE
        up = min(1.0, t / 0.06) * min(1.0, (seconds - t) / 0.05)
        speed = 0.85 + 0.15 * min(1.0, t / 0.12) + 0.02 * math.sin(t * 23.0)
        phase += 2 * math.pi * 118.0 * speed / RATE
        teeth += 2 * math.pi * 1450.0 * speed / RATE
        buzz = (phase / math.pi % 2.0) - 1.0
        chatter = math.sin(teeth) * (0.6 + 0.4 * math.sin(phase * 0.5))
        out.append(up * (0.5 * buzz + 0.35 * chatter + 0.5 * grit[i]))
    return lowpass(highpass(out, 150), 5000)


def spin_up(seconds):
    """The disc spinning up after the tray closes: a soft rising whine with the laser's seek ticks."""
    out = []
    phase = 0.0
    for i in range(int(seconds * RATE)):
        t = i / RATE
        f = 180.0 + 900.0 * (t / seconds) ** 0.7
        phase += 2 * math.pi * f / RATE
        env = min(1.0, t / 0.2) * min(1.0, (seconds - t) / 0.3)
        out.append(env * 0.25 * math.sin(phase))
    for k in range(5):
        mix(out, click([4200, 6100], 0.004, 0.18), 0.25 + k * 0.17 + random.uniform(0, 0.05))
    return out


def button():
    return click([2900, 4400], 0.01)


def tray(opening):
    out = [0.0] * int((MOTOR_DELAY + SLIDE + 0.4) * RATE)
    mix(out, button(), 0.0, 0.6)
    mix(out, norm(motor(SLIDE)), MOTOR_DELAY, 0.55)
    mix(out, clunk(not opening), MOTOR_DELAY + SLIDE, 0.9)
    if not opening:
        mix(out, spin_up(1.4), MOTOR_DELAY + SLIDE + 0.15, 1.0)
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
        sys.exit("make_cd_sounds: cannot write %s: %s" % (path, e))
    print("wrote %s (%.2f s)" % (path, len(samples) / RATE))


if len(sys.argv) != 2:
    sys.exit(__doc__)
write(sys.argv[1] + "/cd_button.wav", button())
write(sys.argv[1] + "/cd_tray_open.wav", tray(True))
write(sys.argv[1] + "/cd_tray_close.wav", tray(False))
