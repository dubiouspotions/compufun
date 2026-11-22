#!/usr/bin/env python3
"""Synthesizes the shop's door chime, door slam, phone, keyboard, mouse button, modem, printer, Open sign, paper handling, pencil and eraser sounds, the rain loops and the hums of the storage bulb, a PC and a CRT as 22050 Hz mono WAVs.
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
    """The receiver lifts off the cradle (a plastic knock and the hook switch), the number dials, the far phone rings once, and someone picks up."""
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
    line = []
    mix(line, ringback(1.0), 0.15, 0.25)
    mix(line, far_pickup(random.Random(131)), 1.4, 0.4)
    mix(out, phone_band(line), at)
    return out


def ringback(seconds):
    """The European ringback tone that the caller hears while the far phone rings: 425 Hz, with 5 ms edges."""
    n, edge = int(seconds * RATE), int(0.005 * RATE)
    return [math.sin(2 * math.pi * 425 * i / RATE) * min(1.0, i / edge, (n - i) / edge) for i in range(n)]


def far_pickup(rng):
    """The far end lifts the receiver: the hook switch clicks, then the open line hisses faintly."""
    out = [rng.uniform(-1, 1) * math.exp(-i / RATE / 0.0015) for i in range(int(0.01 * RATE))]
    mix(out, [math.sin(2 * math.pi * 520 * i / RATE) * math.exp(-i / RATE / 0.012) for i in range(int(0.06 * RATE))], 0.0, 0.6)
    mix(out, [rng.uniform(-1, 1) * 0.05 for _ in range(int(0.38 * RATE))], 0.015)
    return out


def ring(freq, seconds, decay, rng):
    """One damped mode of a struck part, at a random phase."""
    phase = rng.uniform(0, 2 * math.pi)
    return [math.sin(2 * math.pi * freq * i / RATE + phase) * math.exp(-i / RATE / decay) for i in range(int(seconds * RATE))]


def keystroke(seed, space_bar=False):
    """A buckling-spring key of an IBM Model M: the spring buckles and its hammer snaps against the
    switch barrel (a sharp click at 2 to 5 kHz with a short metallic ring), then the keycap bottoms
    out on the plate (a hollow plastic clack at 300 Hz to 1.5 kHz, with a short ring of the case).
    The space bar is longer and heavier: a lower clack, and its stabiliser wire ticks."""
    random.seed(seed)
    rng = random.Random(seed + 1000)
    out = silence(0.09)
    mix(out, highpass(noise(0.004, 0.0004), 2000), 0.0, 1.0)
    spring = random.uniform(3200, 4200)
    mix(out, biquad(noise(0.02, 0.0015), "band", spring, 6.0), 0.0, 3.5)
    for ratio, decay, gain in [(1.0, 0.003, 0.35), (1.37, 0.002, 0.2)]:
        mix(out, ring(spring * ratio, 0.02, decay, rng), 0.0, gain)
    low = 0.75 if space_bar else 1.0
    bottom = random.uniform(0.006, 0.009) + (0.004 if space_bar else 0.0)
    clack = lowpass(highpass(noise(0.01, 0.0012), 300), 1800)
    mix(out, clack, bottom, 1.1 if space_bar else 0.8)
    case = random.uniform(430, 520) * low
    for ratio, decay, gain in [(1.0, 0.014, 0.5), (1.62, 0.008, 0.35), (2.71, 0.005, 0.25)]:  # inharmonic: hollow, not a tone
        mix(out, ring(case * ratio, 0.06, decay * (1.4 if space_bar else 1.0), rng), bottom, gain * (1.3 if space_bar else 1.0))
    if space_bar:
        mix(out, highpass(noise(0.003, 0.0006), 2500), bottom + 0.003, 0.35)
    return highpass(lowpass(out, 8000), 150)


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


def pin_impact(gain):
    """One needle of the print head hitting the ribbon, the paper and the platen."""
    return [gain * (random.uniform(-1, 1) * 0.6 + math.sin(2 * math.pi * 4200 * i / RATE)) * math.exp(-i / RATE / 0.00025)
            for i in range(int(0.002 * RATE))]


def line_feed(gain):
    """The platen's stepper turning one line: a ratchet of four steps and the paper's tractor rustle."""
    out = silence(0.03)
    for step in range(4):
        click = [math.sin(2 * math.pi * 2300 * i / RATE) * math.exp(-i / RATE / 0.0012) for i in range(int(0.006 * RATE))]
        mix(out, click, step * 0.0035, gain * (0.8 if step else 1.0))
        mix(out, highpass(noise(0.002, 0.0005), 2500), step * 0.0035, gain * 0.5)
    thunk = [math.sin(2 * math.pi * 170 * i / RATE) * math.exp(-i / RATE / 0.008) for i in range(int(0.03 * RATE))]
    mix(out, thunk, 0.0, gain * 0.5)
    mix(out, lowpass(highpass(noise(0.03, 0.012), 900), 3000), 0.0, gain * 0.25)
    return out


def printer_line(seed, filled):
    """A 9-pin dot-matrix printer printing one line in 120 ms: the line feed, then the head runs
    across the share `filled` of the page. Each character is 9 columns at the column rate; each column
    fires some of the 9 pins, and a space fires none. The carriage stepper whines and rattles under
    the pins, speeding up and slowing down at the ends of its run."""
    random.seed(seed)
    seconds = 0.12
    out = silence(seconds)
    mix(out, line_feed(0.7), 0.0)
    start, run = 0.016, (seconds - 0.024) * filled
    column = 1.0 / 2900
    t, glyph = start, []
    pins = silence(seconds)
    while t < start + run:
        if not glyph:
            space = random.random() < 0.18
            glyph = [0] * 9 if space else [random.choice([0, 1, 2, 3, 3, 4, 5]) for _ in range(7)] + [0, 0]
        fired = glyph.pop(0)
        for _ in range(fired):
            mix(pins, pin_impact(random.uniform(0.15, 0.3)), t + random.uniform(0, 0.00008))
        t += column
    body = biquad(pins, "band", 1100, 1.5)  # the head and the plastic case ring under the pins
    mix(out, [p + 1.2 * b for p, b in zip(pins, body)], 0.0)
    motor = []
    for i in range(int((run + 0.012) * RATE)):
        u = i / RATE
        ramp = min(1.0, u / 0.006, (run + 0.012 - u) / 0.006)
        step = 520 + 380 * ramp  # the stepper's step rate, in Hz
        phase = 2 * math.pi * step * u
        rattle = 1.0 + 0.5 * random.uniform(-1, 1) * (1 if i % 220 < 30 else 0.2)
        motor.append(0.09 * ramp * rattle * (math.sin(phase) + 0.4 * math.sin(3 * phase) + 0.2 * math.sin(5 * phase)))
    mix(out, motor, start - 0.006)
    return highpass(lowpass(out[:int(seconds * RATE)], 7000), 120)


def printer_feed():
    """The form feed after the last line: the platen stepper turns fast for 0.4 s, a buzzing ratchet,
    and the fanfold paper rustles out of the tractors."""
    random.seed(40)
    seconds = 0.4
    out = silence(seconds)
    t = 0.0
    while t < seconds - 0.01:
        mix(out, [math.sin(2 * math.pi * 2300 * i / RATE) * math.exp(-i / RATE / 0.001) for i in range(int(0.005 * RATE))], t, 0.35)
        t += 1.0 / 240 if 0.03 < t < seconds - 0.04 else 1.0 / 140  # spins up and down
    hum = [0.15 * math.sin(2 * math.pi * 240 * i / RATE) * min(1.0, i / RATE / 0.03, (seconds - i / RATE) / 0.04) for i in range(int(seconds * RATE))]
    mix(out, hum, 0.0)
    rustle = lowpass(highpass(noise(seconds, 10.0), 700), 3500)
    mix(out, [r * 0.22 * (0.6 + 0.4 * math.sin(2 * math.pi * 7 * i / RATE)) for i, r in enumerate(rustle)], 0.0)
    return highpass(lowpass(out, 7000), 120)


def hook_tick(gain):
    """The sign's wire hook knocking in its eye: a dry tick with a short, inharmonic metal ring."""
    out = silence(0.04)
    mix(out, highpass(noise(0.003, 0.0006), 2500), 0.0, gain * 0.6)
    for freq, decay in [(2950, 0.009), (4630, 0.006), (6810, 0.004)]:
        mix(out, [math.sin(2 * math.pi * freq * i / RATE) * math.exp(-i / RATE / decay) for i in range(int(0.04 * RATE))], 0.0, gain * 0.3)
    return out


def board_tap(gain):
    """The light board of the sign flapping against its strings: a papery slap with a little hollow body."""
    out = silence(0.05)
    mix(out, lowpass(highpass(noise(0.012, 0.0025), 1200), 6000), 0.0, gain)
    mix(out, [math.sin(2 * math.pi * 270 * i / RATE) * math.exp(-i / RATE / 0.012) for i in range(int(0.05 * RATE))], 0.0, gain * 0.5)
    return out


def sign_flip(seed):
    """The Open sign turned over by hand: a soft whoosh of air, the board slaps round and taps once
    more as it settles, and the hook ticks in its eye while the sign swings out."""
    random.seed(seed)
    out = silence(0.5)
    whoosh = [s * math.sin(math.pi * i / (0.07 * RATE)) for i, s in enumerate(noise(0.07, 10.0))]
    mix(out, biquad(whoosh, "band", random.uniform(900, 1300), 0.8), 0.0, 0.25)
    slap = random.uniform(0.06, 0.075)
    mix(out, board_tap(1.0), slap)
    mix(out, board_tap(0.35), slap + random.uniform(0.07, 0.09))
    at = slap + 0.01
    for gain in [0.5, 0.3, 0.18]:
        mix(out, hook_tick(gain), at)
        at += random.uniform(0.08, 0.12)
    return highpass(lowpass(out, 7000), 150)


def sign_rattle(seed, seconds=0.6, swings=4):
    """The Open sign shaken on its hook: a tick at each end of each swing, dying out with the swing
    (OpenSign.shake: `seconds` long, `swings` back and forth), and the board knocking at the start."""
    random.seed(seed)
    out = silence(seconds + 0.05)
    mix(out, board_tap(0.4), 0.0)
    for k in range(2 * swings):
        progress = (2 * k + 1) / (4.0 * swings)
        mix(out, hook_tick(0.8 * (1.0 - progress) * random.uniform(0.8, 1.0)), progress * seconds + random.uniform(-0.004, 0.004))
    return highpass(lowpass(out, 7000), 150)


def paper_handle(seed):
    """A sheet of fanfold paper lifted or lowered by hand, 0.12 to 0.22 s: a soft swish of air as it
    moves, and the crackle of the sheet flexing, a run of tiny ticks that swells and dies away."""
    random.seed(seed)
    seconds = random.uniform(0.12, 0.22)
    n = int(seconds * RATE)
    out = silence(seconds + 0.02)
    swish = [s * math.sin(math.pi * i / n) ** 2 for i, s in enumerate(noise(seconds, 10.0))]
    mix(out, biquad(swish, "band", random.uniform(600, 1000), 0.7), 0.0, 0.4)
    swell = random.uniform(0.25, 0.5)  # where the crackle peaks, as a share of the length
    crackle = silence(seconds)
    for i in range(n):
        u = i / n
        env = u / swell if u < swell else (1.0 - u) / (1.0 - swell)
        if random.random() < 0.06 * env:
            mix(crackle, noise(0.002, random.uniform(0.0002, 0.0006)), i / RATE, random.uniform(0.2, 1.0) * env)
    mix(out, lowpass(highpass(crackle, 1800), 6500), 0.0, 0.7)
    return highpass(lowpass(out, 7000), 200)


def pencil_stroke(seconds, gain):
    """One pencil stroke on paper: graphite grains scratching over the fibres, a dense grainy hiss
    in 2 to 6 kHz that eases in and lifts off."""
    n = int(seconds * RATE)
    grains = [random.uniform(-1, 1) * (1.0 if random.random() < 0.25 else 0.2) for _ in range(n)]
    env = [min(1.0, i / (0.2 * n), (n - i) / (0.3 * n)) for i in range(n)]
    return [gain * g * e for g, e in zip(biquad(biquad(grains, "band", 3500, 0.6), "high", 1800), env)]


def pencil_tick(seed):
    """A pencil ticking a box, about 0.15 s: a short stroke down, the turn, and a longer, lighter
    stroke up and away."""
    random.seed(seed)
    down, up = random.uniform(0.035, 0.05), random.uniform(0.06, 0.085)
    out = silence(down + up + 0.03)
    mix(out, pencil_stroke(down, 1.0), 0.0)
    mix(out, pencil_stroke(up, random.uniform(0.6, 0.8)), down + random.uniform(0.005, 0.012))
    return highpass(lowpass(out, 8000), 400)


def eraser_rub(seed):
    """A rubber eraser rubbed over a tick, about 0.2 s: three quick strokes back and forth, a soft,
    dull squeak of rubber dragging on paper."""
    random.seed(seed)
    seconds = random.uniform(0.18, 0.22)
    n = int(seconds * RATE)
    strokes = 3
    drag = biquad(biquad([random.gauss(0.0, 1.0) for _ in range(n)], "band", random.uniform(900, 1300), 1.2), "low", 2500)
    out = []
    for i in range(n):
        u = i / n
        stroke = abs(math.sin(math.pi * strokes * u))  # each stroke swells and stops at the turn
        out.append(drag[i] * stroke ** 0.7 * min(1.0, (1.0 - u) / 0.15))
    mix(out, silence(0.02), seconds)
    return highpass(out, 300)


def looped(samples, filters):
    """Runs `samples` through `filters` as a loop: the filters settle on a first pass, so the
    second pass, which is kept, runs on from its own end into its start."""
    out = samples + samples
    for f in filters:
        out = f(out)
    return out[len(samples):]


def rain(seconds):
    """Steady rain on the alley as a seamless loop of `seconds`: a hiss of fine drops on the asphalt,
    bubbly plinks in the puddles, and a drip from the gutter now and then. Returns the rain as heard
    in the open doorway and through the shut door and windows."""
    random.seed(130)
    n = int(seconds * RATE)
    out = [random.gauss(0.0, 0.05) for _ in range(n)]

    def add(sound, at, gain):  # wraps round the end, so the loop has no seam
        for i, v in enumerate(sound):
            out[(at + i) % n] += v * gain

    for _ in range(int(seconds * 900)):  # fine drops on the asphalt
        decay = random.uniform(0.0002, 0.0008)
        add(noise(decay * 5, decay), random.randrange(n), random.uniform(0.05, 0.35) ** 2 * 3)
    for _ in range(int(seconds * 7)):  # plinks: a bubble's ring rises as it closes
        f0, decay = random.uniform(1400, 3200), random.uniform(0.004, 0.012)
        plink = [math.sin(2 * math.pi * f0 * (1 + 15 * i / RATE) * i / RATE) * math.exp(-i / RATE / decay) for i in range(int(decay * 5 * RATE))]
        add(plink, random.randrange(n), random.uniform(0.08, 0.2))
    at = 0.0
    while at < seconds - 0.05:  # the gutter drips, not quite steadily
        f0 = random.uniform(700, 950)
        drip = [math.sin(2 * math.pi * f0 * (1 + 6 * i / RATE) * i / RATE) * math.exp(-i / RATE / 0.02) for i in range(int(0.1 * RATE))]
        add(drip, int(at * RATE), random.uniform(0.3, 0.45))
        at += random.uniform(0.45, 1.1)
    heard = looped(out, [lambda x: biquad(x, "high", 180), lambda x: biquad(x, "low", 7000)])
    muffled = looped(heard, [lambda x: biquad(x, "low", 800)])  # through the glass: dull, but the patter still shows
    return heard, muffled


def light_hum(seconds):
    """The storage room's bare bulb buzzing on the 50 Hz mains, as a seamless loop of `seconds` (a
    multiple of 0.25 s): a soft 100 Hz buzz whose harmonics ring up a little around 1 kHz in the
    filament, swelling a little now and then."""
    random.seed(150)
    n = int(seconds * RATE)
    out = [random.gauss(0.0, 0.004) for _ in range(n)]
    for k in range(1, 31):
        f = 100.0 * k
        gain = (0.6 if k == 1 else 1.0 / k ** 1.5) * (1.0 + 0.8 * math.exp(-((f - 1000.0) / 400.0) ** 2))
        phase = random.uniform(0, 2 * math.pi)
        for i in range(n):
            out[i] += gain * math.sin(2 * math.pi * f * i / RATE + phase)
    for i in range(n):
        t = i / RATE
        out[i] *= 1.0 + 0.12 * math.sin(2 * math.pi * 0.25 * t) + 0.06 * math.sin(2 * math.pi * 1.75 * t)
    return looped(out, [lambda x: biquad(x, "high", 70), lambda x: biquad(x, "low", 2500)])


def pc_fan(seconds):
    """A 90s PC running, as a seamless loop of `seconds` (a multiple of 0.25 s): the soft, dull whoosh
    of its CPU and power-supply fans, a faint drone of their blades (two 7-blade fans at about
    2000 rpm, 233.25 and 236.5 Hz, beating 3.25 times a second) and the 100 Hz hum of the supply."""
    random.seed(151)
    n = int(seconds * RATE)
    air = looped([random.gauss(0.0, 1.0) for _ in range(n)],
                 [lambda x: biquad(x, "high", 90), lambda x: biquad(x, "low", 700), lambda x: biquad(x, "low", 1400)])
    air = [a + 0.5 * b for a, b in zip(air, looped(air, [lambda x: biquad(x, "band", 300, 1.0)]))]
    rms = math.sqrt(sum(a * a for a in air) / n)
    out = [a / rms for a in air]
    for f, gain in [(233.25, 0.1), (236.5, 0.07), (100.0, 0.12), (200.0, 0.04)]:
        for i in range(n):
            out[i] += gain * math.sin(2 * math.pi * f * i / RATE)
    return out


def crt_hum(seconds):
    """A CRT monitor switched on, as a seamless loop of `seconds` (a multiple of 0.25 s): the low hum
    of its power supply and deflection coils at 100 Hz and its harmonics, and a faint fizz of high
    voltage, all under 2 kHz; the line transformer's whine is left out, as it is a piercing tone."""
    random.seed(152)
    n = int(seconds * RATE)
    out = []
    for i in range(n):
        t = i / RATE
        out.append(sum(math.sin(2 * math.pi * 100.0 * k * t + k) / k ** 1.5 for k in range(1, 9)) + random.gauss(0.0, 0.08))
    return looped(out, [lambda x: biquad(x, "high", 70), lambda x: biquad(x, "low", 1800)])


def write(path, samples, level=0.7, fade_out=True):
    """Writes `samples` as 16-bit PCM, normalised to the peak `level`, and fades out the last 10 ms
    unless the sound is a loop."""
    peak = max(abs(s) for s in samples)
    gain = level / peak
    fade = int(0.01 * RATE) if fade_out else 0
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
for take, level in enumerate([0.7, 0.6, 0.66, 0.56], 1):
    write(sys.argv[1] + "/keystroke_%d.wav" % take, keystroke(take), level)
write(sys.argv[1] + "/keystroke_space.wav", keystroke(5, space_bar=True))
for take in range(1, 4):
    write(sys.argv[1] + "/mouse_down_%d.wav" % take, mouse_button(10 + take, False))
    write(sys.argv[1] + "/mouse_up_%d.wav" % take, mouse_button(20 + take, True))
write(sys.argv[1] + "/modem_dialup.wav", modem_dialup(), 0.58)  # a lower peak: the long hiss is loud on average
write(sys.argv[1] + "/door_slam.wav", door_slam())
for take, filled in enumerate([1.0, 0.75, 0.5, 0.3], 1):
    write(sys.argv[1] + "/printer_line_%d.wav" % take, printer_line(30 + take, filled))
write(sys.argv[1] + "/printer_feed.wav", printer_feed())
for take in range(1, 4):
    write(sys.argv[1] + "/sign_flip_%d.wav" % take, sign_flip(50 + take))
for take in range(1, 3):
    write(sys.argv[1] + "/sign_rattle_%d.wav" % take, sign_rattle(60 + take))
for take in range(1, 5):
    write(sys.argv[1] + "/paper_handle_%d.wav" % take, paper_handle(70 + take))
for take in range(1, 4):
    write(sys.argv[1] + "/pencil_tick_%d.wav" % take, pencil_tick(80 + take))
for take in range(1, 3):
    write(sys.argv[1] + "/eraser_rub_%d.wav" % take, eraser_rub(90 + take))
rain_open, rain_shut = rain(12.0)
write(sys.argv[1] + "/rain_open.wav", rain_open, fade_out=False)
write(sys.argv[1] + "/rain_shut.wav", rain_shut, fade_out=False)
write(sys.argv[1] + "/light_hum.wav", light_hum(4.0), fade_out=False)
write(sys.argv[1] + "/pc_fan.wav", pc_fan(4.0), fade_out=False)
write(sys.argv[1] + "/crt_hum.wav", crt_hum(4.0), fade_out=False)
