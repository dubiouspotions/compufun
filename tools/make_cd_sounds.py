#!/usr/bin/env python3
"""Cuts the CD-ROM drive's sounds from recordings of a real drive: the eject button's click, the
tray opening and the tray closing, as mono 16-bit WAVs with the silence before them trimmed.
Godot/props/cd_drive.gd's default timing follows these cuts: the opening's latch clicks at once
and the tray slides 0.12 to 0.52 s in; the closing tray slides 0.03 to 0.51 s in and hits its stop.
Usage: make_cd_sounds.py OPEN.wav CLOSE.wav Godot/sounds"""
import array
import struct
import sys
import wave

PEAK = 10 ** (-3 / 20)
OPEN_FROM, OPEN_TO = 0.66, 1.30
CLOSE_FROM, CLOSE_TO = 0.92, 1.65
BUTTON_SECONDS = 0.1


def read(path):
    try:
        with wave.open(path) as w:
            if w.getsampwidth() != 2:
                sys.exit("make_cd_sounds: %s is not 16-bit" % path)
            rate, channels = w.getframerate(), w.getnchannels()
            samples = array.array("h", w.readframes(w.getnframes()))
    except (OSError, wave.Error) as e:
        sys.exit("make_cd_sounds: cannot read %s: %s" % (path, e))
    mono = [sum(samples[i:i + channels]) / channels / 32768 for i in range(0, len(samples), channels)]
    return rate, mono


def cut(rate, samples, start, end):
    return samples[int(start * rate):int(end * rate)]


def write(path, rate, samples, gain):
    fade = int(0.02 * rate)
    data = bytearray()
    for i, s in enumerate(samples):
        if i >= len(samples) - fade:
            s *= (len(samples) - 1 - i) / fade
        data += struct.pack("<h", int(max(-1.0, min(1.0, s * gain)) * 32767))
    try:
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(bytes(data))
    except OSError as e:
        sys.exit("make_cd_sounds: cannot write %s: %s" % (path, e))
    print("wrote %s (%.2f s)" % (path, len(samples) / rate))


if len(sys.argv) != 4:
    sys.exit(__doc__)
open_rate, opening = read(sys.argv[1])
close_rate, closing = read(sys.argv[2])
opening = cut(open_rate, opening, OPEN_FROM, OPEN_TO)
closing = cut(close_rate, closing, CLOSE_FROM, CLOSE_TO)
gain = PEAK / max(abs(s) for s in opening + closing)  # one gain, so the clunk stays louder than the latch
write(sys.argv[3] + "/cd_button.wav", open_rate, opening[:int(BUTTON_SECONDS * open_rate)], gain)
write(sys.argv[3] + "/cd_tray_open.wav", open_rate, opening, gain)
write(sys.argv[3] + "/cd_tray_close.wav", close_rate, closing, gain)
