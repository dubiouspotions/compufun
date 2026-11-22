#!/usr/bin/env python3
"""Synthesizes the shop's door chime, door slam, phone, keystroke, mouse button, modem and printer sounds as 22050 Hz mono WAVs.
Usage: make_shop_sounds.py Godot/sounds"""
import math
import random
import struct
import sys
import wave

RATE = 22050


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


def chime_tone(freq, seconds, decay):
    """One tone of a door sensor's chime: a sine with a little of its octave and twelfth, struck with a 4 ms attack."""
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        env = min(1.0, t / 0.004) * math.exp(-t / decay)
        phase = 2 * math.pi * freq * t
        out.append(env * (math.sin(phase) + 0.2 * math.sin(2 * phase) + 0.1 * math.sin(3 * phase)))
    return out


def door_bell():
    """The two-tone "bing bong" of a 90s shop's door sensor, E5 then C5, through its small speaker."""
    out = silence(1.0)
    mix(out, chime_tone(659.25, 0.6, 0.16), 0.0)
    mix(out, chime_tone(523.25, 0.68, 0.22), 0.32)
    out = lowpass(highpass(out, 350), 3500)
    peak = max(abs(s) for s in out)
    return [round(s / peak * 127) / 127 for s in out]  # 8-bit samples, for the cheap speaker's grit


def dtmf(row, col, seconds):
    return [0.5 * (math.sin(2 * math.pi * row * i / RATE) + math.sin(2 * math.pi * col * i / RATE)) for i in range(int(seconds * RATE))]


def phone_receiver():
    """The receiver lifts off the cradle (a plastic knock and the hook switch), then the number dials."""
    random.seed(95)
    for _ in range(880):  # the state that phone_receiver.wav was rendered from
        random.random()
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


def biquad(samples, kind, f0, q=0.7071):
    """An RBJ cookbook biquad: "low", "high" or "band" (0 dB at f0)."""
    w0 = 2 * math.pi * f0 / RATE
    alpha, c = math.sin(w0) / (2 * q), math.cos(w0)
    if kind == "low":
        b = [(1 - c) / 2, 1 - c, (1 - c) / 2]
    elif kind == "high":
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
    else:
        b = [alpha, 0.0, -alpha]
    a0, a1, a2 = 1 + alpha, -2 * c, 1 - alpha
    b0, b1, b2 = b[0] / a0, b[1] / a0, b[2] / a0
    a1, a2 = a1 / a0, a2 / a0
    out, x1, x2, y1, y2 = [], 0.0, 0.0, 0.0, 0.0
    for x in samples:
        y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, x, y1, y
        out.append(y)
    return out


def phone_band(samples):
    """A telephone line: 300 to 3400 Hz, 24 dB per octave on each side."""
    for _ in range(2):
        samples = biquad(biquad(samples, "high", 300), "low", 3400)
    return samples


def fsk(bits, baud, mark, space, gain):
    """Continuous-phase FSK: 1 is the mark frequency."""
    out, phase = [], 0.0
    per_bit = RATE / baud
    for i in range(int(len(bits) * per_bit)):
        phase += 2 * math.pi * (mark if bits[int(i / per_bit)] else space) / RATE
        out.append(gain * math.sin(phase))
    return out


def dpsk(bits, baud, carrier, gain):
    """Differential PSK: a 1 turns the carrier's phase half a turn."""
    out, flip = [], 0.0
    per_bit = RATE / baud
    for i in range(int(len(bits) * per_bit)):
        if i % int(per_bit) == 0 and bits[int(i / per_bit)]:
            flip += math.pi
        out.append(gain * math.sin(2 * math.pi * carrier * i / RATE + flip))
    return out


def v21_octets(count):
    """V.8 menu framing for V.21: ten ones, then octets with a start and a stop bit."""
    bits = [1] * 10
    for _ in range(count):
        bits += [0] + [random.getrandbits(1) for _ in range(8)] + [1]
    return bits


def qam_hiss(seconds, baud, carrier, gain):
    """Scrambled V.34 data: random 16-QAM symbols at the baud rate, shaped to half the baud on each
    side of the carrier."""
    points = [-3, -1, 1, 3]
    per = RATE / baud
    i_in, q_in = [], []
    for n in range(int(seconds * RATE)):
        if n % max(1, int(per)) == 0 or not i_in:
            si, sq = random.choice(points), random.choice(points)
        i_in.append(si)
        q_in.append(sq)
    for _ in range(2):
        i_in, q_in = biquad(i_in, "low", baud / 2), biquad(q_in, "low", baud / 2)
    return [gain / 3 * (i_in[n] * math.cos(2 * math.pi * carrier * n / RATE) - q_in[n] * math.sin(2 * math.pi * carrier * n / RATE))
            for n in range(len(i_in))]


def relay_click(gain):
    """The hook relay or an exchange switch: a dry tick with a short metallic ring."""
    tick = highpass(noise(0.004, 0.0008), 1500)
    ring = [math.sin(2 * math.pi * 950 * i / RATE) * math.exp(-i / RATE / 0.006) for i in range(int(0.03 * RATE))]
    out = silence(0.03)
    mix(out, tick, 0.0, gain)
    mix(out, ring, 0.0, gain * 0.5)
    return out


def modem_dialup():
    """A 1996 V.34 modem dialling out through its little speaker, which it turns off once it has
    trained up. Each step's start is in seconds from the off-hook click."""
    random.seed(1996)
    out = silence(9.3)
    keys = {"0": (941, 1336), "1": (697, 1209), "5": (770, 1336), "6": (770, 1477), "9": (852, 1477)}
    mix(out, relay_click(0.9), 0.0)  # off-hook
    mix(out, tone([350, 440], 0.55, 0.22), 0.06)  # dial tone
    at = 0.7
    for digit in "5550196":  # ATDT at the default S11: 70 ms tones, 60 ms gaps
        mix(out, dtmf(*keys[digit], 0.07), at, 0.6)
        at += 0.13
    mix(out, relay_click(0.25), 1.75)  # the exchange switching through
    mix(out, relay_click(0.15), 1.92)
    mix(out, tone([440, 480], 1.0, 0.18), 2.1)  # ringback
    mix(out, relay_click(0.5), 3.35)  # the far modem answers
    answer = []  # ANSam: 2100 Hz, its phase reversed every 450 ms, amplitude-modulated 20 % at 15 Hz
    for i in range(int(1.6 * RATE)):
        t = i / RATE
        answer.append(0.45 * (1 + 0.2 * math.sin(2 * math.pi * 15 * t)) * math.sin(2 * math.pi * 2100 * t + math.pi * int(t / 0.45)))
    mix(out, answer, 3.55)
    mix(out, fsk(v21_octets(26), 300, 980, 1180, 0.4), 4.25)  # CM, the caller's V.8 menu on V.21 channel 1
    mix(out, fsk(v21_octets(12), 300, 1650, 1850, 0.4), 5.2)  # JM, the answer on channel 2
    mix(out, fsk([1] * 4 + [0] * 26, 300, 980, 1180, 0.35), 5.62)  # CJ
    mix(out, dpsk([1, 1, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0] * 4, 600, 1200, 0.35), 5.75)  # INFO0c
    mix(out, dpsk([1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1] * 4, 600, 2400, 0.35), 5.82)  # INFO0a
    for carrier, gain in [(1200, 0.3), (2400, 0.3)]:  # tones B and A, each with a phase reversal
        mix(out, [gain * math.sin(2 * math.pi * carrier * i / RATE + (math.pi if i > 0.15 * RATE else 0.0)) for i in range(int(0.3 * RATE))], 5.95)
    comb = [150 * k for k in range(1, 26) if 150 * k not in (900, 1200, 1800, 2400)]
    probe = [sum(math.cos(2 * math.pi * f * i / RATE + math.pi * k * k / len(comb)) for k, f in enumerate(comb)) / len(comb)
             for i in range(int(0.7 * RATE))]
    mix(out, [s * (1.6 if i < 0.16 * RATE else 0.9) for i, s in enumerate(probe)], 6.3)  # line probing, L1 then L2
    mix(out, dpsk([1, 0] * 30, 600, 2400, 0.3), 7.0)  # INFO1a
    mix(out, [0.3 * (math.sin(2 * math.pi * 320 * i / RATE) + math.sin(2 * math.pi * 3520 * i / RATE)) for i in range(int(0.08 * RATE))], 7.12)  # S: 3200 baud reversals
    mix(out, qam_hiss(0.55, 3200, 1920, 0.5), 7.2)  # the answerer trains alone
    mix(out, qam_hiss(1.55, 3200, 1920, 0.35), 7.75)  # then both ends: training and the rate exchange
    mix(out, qam_hiss(1.5, 3200, 1829, 0.35), 7.8)
    for i in range(int(9.3 * RATE)):  # line hiss and crackle while off-hook
        out[i] += random.gauss(0.0, 0.012) + (random.uniform(-0.3, 0.3) if random.random() < 0.00015 else 0.0)
    out = out[:int(9.3 * RATE)]
    speaker = phone_band(out)
    speaker = [a + 0.6 * b for a, b in zip(speaker, biquad(speaker, "band", 1600, 1.4))]  # the 2-inch cone's resonance
    driven = [math.tanh(1.2 * s) for s in biquad(speaker, "high", 450)]  # the cone breaks up when loud
    heard = biquad(biquad(driven, "low", 3800), "low", 3800)
    cut = int(0.002 * RATE)  # the speaker relay opens: the hiss stops dead, then the line is silent
    for i in range(cut):
        heard[-1 - i] *= i / cut
    return heard + silence(0.3)


def door_slam():
    """A wooden shop door swung shut: the latch clacks, the heavy panel thumps into the frame, and
    the glass and frame rattle briefly."""
    random.seed(7)
    out = silence(0.6)
    mix(out, highpass(noise(0.015, 0.003), 2000), 0.0, 0.5)  # the latch
    body = [math.exp(-i / RATE / 0.07) * (math.sin(2 * math.pi * 85 * i / RATE) + 0.5 * math.sin(2 * math.pi * 140 * i / RATE))
            for i in range(int(0.4 * RATE))]
    mix(out, body, 0.008, 1.0)
    mix(out, lowpass(noise(0.25, 0.04), 900), 0.008, 0.9)  # the panel's wooden thud
    rattle = [random.uniform(-1, 1) * math.exp(-i / RATE / 0.05) * (0.6 + 0.4 * math.sin(2 * math.pi * 31 * i / RATE))
              for i in range(int(0.3 * RATE))]
    mix(out, highpass(lowpass(rattle, 4000), 1200), 0.02, 0.25)
    return out


def printer_line(seed):
    """A dot-matrix printer printing one line: the pins rasp through the characters as the head
    runs across the page, the carriage motor whines under it, and the platen clicks the paper on."""
    random.seed(seed)
    seconds = 0.12
    out = silence(seconds + 0.03)
    t = 0.0
    while t < seconds:
        char = 0.0025
        if random.random() > 0.2:  # a space fires no pins
            for k in range(4):
                click = highpass(noise(0.0006, 0.0002), 1500)
                mix(out, click, t + k * char / 4, random.uniform(0.5, 1.0))
        t += char
    motor = [0.08 * math.sin(2 * math.pi * 190 * i / RATE) * min(1.0, i / RATE / 0.01) for i in range(int(seconds * RATE))]
    mix(out, motor, 0.0)
    mix(out, lowpass(noise(0.02, 0.006), 700), seconds + 0.005, 0.5)  # the line feed
    return highpass(lowpass(out, 6000), 250)


def write(path, samples, level=0.7):
    """Writes `samples` as 16-bit PCM, normalised to the peak `level`."""
    peak = max(abs(s) for s in samples)
    gain = level / peak
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
write(sys.argv[1] + "/modem_dialup.wav", modem_dialup(), 0.58)  # a lower peak: the long hiss is loud on average
write(sys.argv[1] + "/door_slam.wav", door_slam())
for take in range(1, 4):
    write(sys.argv[1] + "/printer_line_%d.wav" % take, printer_line(30 + take))
