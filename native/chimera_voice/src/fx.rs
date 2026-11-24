//! The effects of a voice type, applied to the line as it streams out: tape wobble, then the chunk
//! effects (stutter, reverse, dropout, static), then the effects per sample (ring mod, metal,
//! clip, distortion, phaser, chorus, echo, reverb, sample hold, bit depth, band-pass). Every setting can
//! change from one block to the next, as the voice type's curve moves.

use std::collections::VecDeque;
use std::f64::consts::TAU;

/// The settings at one moment. Each is neutral at its default.
#[derive(Clone, Copy)]
pub struct Params {
    pub wobble: f64,
    pub wobble_hz: f64,
    pub chunk_ms: f64,
    pub stutter: f64,
    pub stutter_ms: f64,
    pub stutter_repeats: f64,
    pub reverse: f64,
    pub dropout: f64,
    pub static_: f64,
    pub static_level: f64,
    pub ring_hz: f64,
    pub ring_mix: f64,
    pub metal_ms: f64,
    pub metal_fb: f64,
    pub drive: f64,
    pub distortion: f64,
    pub phaser: f64,
    pub chorus: f64,
    pub delay: f64,
    pub reverb: f64,
    pub hold: f64,
    pub bits: f64,
    /// A high-pass below this, in Hz; 0 or less is off.
    pub low_cut_hz: f64,
    /// A low-pass above this, in Hz; half the sample rate or more is off.
    pub high_cut_hz: f64,
}

impl Params {
    fn chunked(&self) -> bool {
        self.stutter > 0.0 || self.reverse > 0.0 || self.dropout > 0.0 || self.static_ > 0.0
    }

    /// How long the echo and reverb ring on after the voice ends, in seconds.
    pub fn tail(&self) -> f64 {
        let echo = if self.delay > 0.0 { 0.28 * (0.001f64.ln() / self.delay.max(0.01).ln()).min(12.0) } else { 0.0 };
        let reverb = if self.reverb > 0.0 { 1.2 } else { 0.0 };
        echo.max(reverb)
    }
}

const ECHO_S: f64 = 0.28;
const CHORUS_S: f64 = 0.025;
const COMBS_S: [f64; 4] = [0.0297, 0.0371, 0.0411, 0.0437];
const ALLPASS_S: [f64; 2] = [0.005, 0.0017];
/// The Q of the two sections of a fourth-order Butterworth filter.
const BUTTERWORTH_Q: [f64; 2] = [0.5412, 1.3066];

pub struct Fx {
    fs: f64,
    rng: u64,
    /// Samples out of the per-sample stage, and out of wobble: each its own clock.
    n: u64,
    wobble_n: u64,
    wobble_in: VecDeque<f32>,
    wobble_pos: f64,
    chunk: Vec<f32>,
    metal: Vec<f32>,
    held: f32,
    phase: [f32; 4],
    chorus: Line,
    echo: Line,
    combs: Vec<Line>,
    allpass: Vec<Line>,
    /// The band-pass: two high-pass sections, then two low-pass sections.
    band: [Biquad; 4],
}

/// One second-order filter section (the RBJ cookbook's), with its state.
#[derive(Clone, Copy, Default)]
struct Biquad {
    b: [f32; 3],
    a: [f32; 2],
    x: [f32; 2],
    y: [f32; 2],
}

impl Biquad {
    /// Makes it a high-pass (`high`) or low-pass at `hz`, keeping its state so a moving cutoff doesn't click.
    fn tune(&mut self, hz: f64, q: f64, fs: f64, high: bool) {
        let (sin, cos) = (TAU * hz / fs).sin_cos();
        let alpha = sin / (2.0 * q);
        let a0 = 1.0 + alpha;
        let (b0, b1) = if high { ((1.0 + cos) / 2.0, -(1.0 + cos)) } else { ((1.0 - cos) / 2.0, 1.0 - cos) };
        self.b = [(b0 / a0) as f32, (b1 / a0) as f32, (b0 / a0) as f32];
        self.a = [(-2.0 * cos / a0) as f32, ((1.0 - alpha) / a0) as f32];
    }

    fn run(&mut self, x: f32) -> f32 {
        let y = self.b[0] * x + self.b[1] * self.x[0] + self.b[2] * self.x[1] - self.a[0] * self.y[0] - self.a[1] * self.y[1];
        self.x = [x, self.x[0]];
        self.y = [y, self.y[0]];
        y
    }
}

/// A delay line.
struct Line {
    buf: Vec<f32>,
    at: usize,
}

impl Line {
    fn new(samples: usize) -> Line {
        Line { buf: vec![0.0; samples.max(1)], at: 0 }
    }
    fn read(&self, back: usize) -> f32 {
        let len = self.buf.len();
        self.buf[(self.at + len - back.min(len - 1) - 1) % len]
    }
    fn push(&mut self, v: f32) {
        self.buf[self.at] = v;
        self.at = (self.at + 1) % self.buf.len();
    }
}

impl Fx {
    pub fn new(fs: f64, seed: u64) -> Fx {
        let len = |s: f64| (s * fs).round() as usize;
        Fx {
            fs,
            rng: seed | 1,
            n: 0,
            wobble_n: 0,
            wobble_in: VecDeque::new(),
            wobble_pos: 0.0,
            chunk: Vec::new(),
            metal: Vec::new(),
            held: 0.0,
            phase: [0.0; 4],
            chorus: Line::new(len(CHORUS_S * 2.0)),
            echo: Line::new(len(ECHO_S)),
            combs: COMBS_S.iter().map(|s| Line::new(len(*s))).collect(),
            allpass: ALLPASS_S.iter().map(|s| Line::new(len(*s))).collect(),
            band: [Biquad::default(); 4],
        }
    }

    fn random(&mut self) -> f64 {
        self.rng ^= self.rng << 13;
        self.rng ^= self.rng >> 7;
        self.rng ^= self.rng << 17;
        (self.rng >> 11) as f64 / (1u64 << 53) as f64
    }

    /// Runs `input` through every effect and appends what comes out to `out`; wobble and the chunk
    /// effects hold some samples back until they have enough.
    pub fn push(&mut self, input: &[f32], p: &Params, out: &mut VecDeque<f32>) {
        let mut wobbled = Vec::with_capacity(input.len() + 8);
        self.wobble_in.extend(input.iter().copied());
        while self.wobble_pos + 1.0 < self.wobble_in.len() as f64 {
            let i = self.wobble_pos as usize;
            let f = (self.wobble_pos - i as f64) as f32;
            wobbled.push(self.wobble_in[i] + (self.wobble_in[i + 1] - self.wobble_in[i]) * f);
            let t = self.wobble_n as f64 / self.fs;
            self.wobble_pos += (1.0 + p.wobble * (TAU * p.wobble_hz * t).sin()).max(0.05);
            let used = self.wobble_pos as usize;
            self.wobble_in.drain(..used);
            self.wobble_pos -= used as f64;
            self.wobble_n += 1;
        }
        self.chunks(&wobbled, p, out, false);
    }

    /// Lets out what wobble and the chunk effects still hold, then the echo and reverb tail.
    pub fn finish(&mut self, p: &Params, out: &mut VecDeque<f32>) {
        let rest: Vec<f32> = self.wobble_in.drain(..).collect();
        self.chunks(&rest, p, out, true);
        let tail = (p.tail() * self.fs) as usize;
        let zeros = vec![0.0; tail];
        self.samples(&zeros, p, out);
    }

    fn chunks(&mut self, input: &[f32], p: &Params, out: &mut VecDeque<f32>, last: bool) {
        if !p.chunked() && self.chunk.is_empty() {
            self.samples(input, p, out);
            return;
        }
        let size = ((p.chunk_ms / 1000.0 * self.fs) as usize).max(16);
        for &s in input {
            self.chunk.push(s);
            if self.chunk.len() >= size {
                self.cut(p, out);
            }
        }
        if last && !self.chunk.is_empty() {
            self.cut(p, out);
        }
    }

    // One chunk: maybe reversed, dropped or buried in static, maybe stuttered first.
    fn cut(&mut self, p: &Params, out: &mut VecDeque<f32>) {
        let mut piece = std::mem::take(&mut self.chunk);
        if self.random() < p.reverse {
            piece.reverse();
        }
        if self.random() < p.dropout {
            piece.fill(0.0);
        }
        if self.random() < p.static_ {
            for s in piece.iter_mut() {
                let noise = (self.random() * 2.0 - 1.0) as f32 * p.static_level as f32;
                *s += (noise - *s) * 0.85;
            }
        }
        let mut cut = Vec::new();
        if self.random() < p.stutter {
            let grain = ((p.stutter_ms / 1000.0 * self.fs) as usize).clamp(1, piece.len().max(1)).min(piece.len());
            for _ in 0..(p.stutter_repeats.round() as usize).max(1) {
                cut.extend_from_slice(&piece[..grain]);
            }
        }
        cut.extend_from_slice(&piece);
        self.samples(&cut, p, out);
    }

    fn samples(&mut self, input: &[f32], p: &Params, out: &mut VecDeque<f32>) {
        let metal_len = (p.metal_ms / 1000.0 * self.fs) as usize;
        if metal_len != self.metal.len() {
            self.metal = vec![0.0; metal_len];
        }
        let hold = (p.hold.round() as u64).max(1);
        let levels = 2f64.powf(p.bits.clamp(1.0, 16.0) - 1.0) as f32;
        let fs = self.fs;
        let low_cut = p.low_cut_hz > 0.0;
        let high_cut = p.high_cut_hz < fs / 2.0;
        for (i, q) in BUTTERWORTH_Q.iter().enumerate() {
            if low_cut {
                self.band[i].tune(p.low_cut_hz.min(0.45 * fs), *q, fs, true);
            }
            if high_cut {
                self.band[2 + i].tune(p.high_cut_hz.max(20.0), *q, fs, false);
            }
        }
        for (i, &x) in input.iter().enumerate() {
            let k = self.n + i as u64;
            let t = k as f64 / fs;
            let mut s = x;
            if p.ring_mix > 0.0 {
                let ring = s * (TAU * p.ring_hz * t).sin() as f32;
                s += (ring - s) * p.ring_mix as f32;
            }
            if !self.metal.is_empty() {
                let slot = (k as usize) % self.metal.len();
                s += p.metal_fb as f32 * self.metal[slot];
                self.metal[slot] = s;
            }
            s = (s * p.drive as f32).clamp(-1.0, 1.0);
            if p.distortion > 0.0 {
                let g = 1.0 + 19.0 * p.distortion as f32;
                s = (s * g).tanh() / g.tanh();
            }
            if p.phaser > 0.0 {
                // Four allpass stages swept by a slow LFO, mixed back in.
                let a = (0.6 + 0.35 * (TAU * 0.5 * t).sin()) as f32;
                let mut y = s;
                for z in self.phase.iter_mut() {
                    let v = -a * y + *z;
                    *z = y + a * v;
                    y = v;
                }
                s += y * (p.phaser / 4.0).min(1.0) as f32;
                s *= 0.7;
            }
            if p.chorus > 0.0 {
                let back = (CHORUS_S * fs * (1.0 + 0.3 * (TAU * 0.8 * t).sin())) as usize;
                let wet = self.chorus.read(back);
                self.chorus.push(s);
                s = (s + wet * p.chorus as f32) / (1.0 + p.chorus as f32 * 0.5);
            } else {
                self.chorus.push(s);
            }
            if p.delay > 0.0 {
                let wet = self.echo.read(self.echo.buf.len() - 1);
                let y = s + wet * p.delay as f32;
                self.echo.push(y);
                s = y;
            } else {
                self.echo.push(s);
            }
            if p.reverb > 0.0 {
                let mut wet = 0.0;
                for c in self.combs.iter_mut() {
                    let y = s + c.read(c.buf.len() - 1) * 0.8;
                    c.push(y);
                    wet += y;
                }
                wet *= 0.25;
                for a in self.allpass.iter_mut() {
                    let d = a.read(a.buf.len() - 1);
                    let y = -0.5 * wet + d;
                    a.push(wet + 0.5 * y);
                    wet = y;
                }
                s += (wet - s) * p.reverb as f32 * 0.5;
            }
            if k % hold == 0 {
                self.held = s;
            }
            s = self.held;
            if levels < 32768.0 {
                s = (s * levels).round() / levels;
            }
            for (section, on) in self.band.iter_mut().zip([low_cut, low_cut, high_cut, high_cut]) {
                if on {
                    s = section.run(s);
                }
            }
            out.push_back(s.clamp(-1.0, 1.0));
        }
        self.n += input.len() as u64;
    }
}
