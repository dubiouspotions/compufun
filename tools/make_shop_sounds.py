#!/usr/bin/env python3
"""Synthesizes the shop's door bell, phone, keystroke, mouse button and modem sounds as 22050 Hz mono WAVs.
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


def keystroke(seed):
    """A 90s office keyboard key: the plastic click of the switch, then the key bottoming out."""
    random.seed(seed)
    out = silence(0.09)
    mix(out, highpass(noise(0.012, 0.002), 2500), 0.0, 0.8)
    thump_freq = random.uniform(180, 260)
    thump = [math.sin(2 * math.pi * thump_freq * i / RATE) * math.exp(-i / RATE / 0.012) for i in range(int(0.06 * RATE))]
    mix(out, thump, 0.008, 0.6)
    mix(out, lowpass(highpass(noise(0.03, 0.006), 700), 5000), 0.008, 0.5)
    return out


def mouse_button(seed, release):
    """A mouse button's microswitch: a dry snap of noise with no pitch, so it doesn't plink like a
    drop; the press has a little plastic body, the release is thinner."""
    random.seed(seed)
    out = silence(0.03)
    snap = lowpass(highpass(noise(0.004, 0.0006 if release else 0.0009), 1800 if release else 1200), 7000)
    mix(out, snap, 0.0, 1.0)
    if not release:
        body = lowpass(noise(0.012, 0.0025), 900)
        mix(out, body, 0.0005, 0.6)
    return out


def tone(freqs, seconds, gain=0.4):
    return [gain * sum(math.sin(2 * math.pi * f * i / RATE) for f in freqs) for i in range(int(seconds * RATE))]


def modem_dialup():
    """A 14400 modem dialling out through its little speaker: the dial tone, the number, one ring,
    the answer tone with its phase flips, the probing bongs, and the hiss of the handshake until
    the modem turns its speaker off."""
    random.seed(1996)
    out = []
    out += tone([350, 440], 0.7, 0.3)
    keys = {"0": (941, 1336), "1": (697, 1209), "5": (770, 1336), "6": (770, 1477), "9": (852, 1477)}
    for digit in "5550196":
        out += dtmf(*keys[digit], 0.08) + silence(0.06)
    out += silence(0.4) + tone([440, 480], 0.8, 0.3) + silence(0.25)
    answer = []
    for i in range(int(1.2 * RATE)):
        t = i / RATE
        flip = math.pi * int(t / 0.45)  # the answer tone reverses its phase every 450 ms
        answer.append(0.5 * math.sin(2 * math.pi * 2100 * t + flip))
    out += answer + silence(0.1)
    for f in [1200, 2400, 1200, 2400]:
        out += tone([f, f * 1.5], 0.07, 0.25) + silence(0.03)
    chirp = []
    for i in range(int(0.4 * RATE)):
        t = i / RATE
        chirp.append(0.3 * sum(math.sin(2 * math.pi * (300 + 600 * k + 900 * t) * t) for k in range(5)) / 3)
    out += chirp
    hiss_seconds = 1.8
    hiss = highpass(lowpass(noise(hiss_seconds, 10.0), 3400), 300)
    for i in range(len(hiss)):
        t = i / RATE
        hiss[i] = 0.8 * hiss[i] + 0.15 * math.sin(2 * math.pi * 1800 * t) * (1.0 if int(t * 8) % 2 else 0.4)
        hiss[i] *= min(1.0, (hiss_seconds - t) / 0.3)  # the speaker turns off as it connects
    out += hiss
    return highpass(lowpass(out, 3400), 300)


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
for take in range(1, 5):
    write(sys.argv[1] + "/keystroke_%d.wav" % take, keystroke(take))
for take in range(1, 4):
    write(sys.argv[1] + "/mouse_down_%d.wav" % take, mouse_button(10 + take, False))
    write(sys.argv[1] + "/mouse_up_%d.wav" % take, mouse_button(20 + take, True))
write(sys.argv[1] + "/modem_dialup.wav", modem_dialup())
