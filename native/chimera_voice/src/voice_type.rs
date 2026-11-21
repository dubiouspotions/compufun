//! A voice type: a base voice, an alternate voice, and a curve over the line that says how much of
//! the alternate plays at each moment (0 the base, 1 the alternate). Each voice is a set of
//! settings by key; a key that a voice leaves out takes its neutral value, so it changes nothing.
//!
//! The text form, shared by GDScript and the web worker:
//! `base:fry=0.8,bits=8|alt:fry=0,ring_mix=0.5|curve:0:0,0.5:1,1:0`

/// Every setting a voice type can hold, with the value that changes nothing.
pub const NEUTRAL: &[(&str, f64)] = &[
    // Planned once per line, from the curve's average: speed, pitch, melody, body, intonation and
    // tune (how far the pitch snaps to notes).
    ("rate", 1.0), ("pitch", 1.0), ("accent", -1.0), ("fs", 22050.0),
    ("female", -1.0), ("child", -1.0), ("scale", 1.0), ("pharynx", 1.0), ("tongue", 1.0), ("lips", 1.0),
    ("folds", 1.0), ("open_phase", 0.0), ("intonation", 0.0), ("tune", 0.0),
    // The voice source: blended live along the curve as the line plays. Chimera's defaults.
    ("glide", 0.06), ("pressure", 7.2), ("breathiness", 0.15), ("tension", 0.5), ("fry", 0.0),
    ("roughness", 0.1), ("vibrato_depth", 0.0), ("vibrato_rate", 6.0), ("drift", 5.0),
    ("brightness", 0.25), ("voiced", 1.0),
    // Effects on the samples: blended live along the curve.
    ("wobble", 0.0), ("wobble_hz", 3.0), ("chunk_ms", 120.0), ("stutter", 0.0), ("stutter_ms", 80.0),
    ("stutter_repeats", 3.0), ("reverse", 0.0), ("dropout", 0.0), ("static", 0.0), ("static_level", 0.4),
    ("ring_hz", 0.0), ("ring_mix", 0.0), ("metal_ms", 0.0), ("metal_fb", 0.6), ("drive", 1.0),
    ("distortion", 0.0), ("phaser", 0.0), ("chorus", 0.0), ("delay", 0.0), ("reverb", 0.0),
    ("hold", 1.0), ("bits", 16.0),
];

/// The voice-source keys; one that neither voice sets is left to Chimera.
pub const SOURCE_KEYS: &[&str] = &["glide", "pressure", "breathiness", "tension", "fry", "roughness", "vibrato_depth", "vibrato_rate", "drift", "brightness"];

#[derive(Clone, Default)]
pub struct VoiceType {
    base: Vec<(String, f64)>,
    alt: Vec<(String, f64)>,
    /// (x, y) points, x from 0 to 1 across the line, sorted by x. Empty plays the base alone.
    curve: Vec<(f64, f64)>,
}

impl VoiceType {
    /// Parses the text form; unknown keys and bad numbers are skipped.
    pub fn parse(text: &str) -> VoiceType {
        let mut t = VoiceType::default();
        for part in text.split('|') {
            let Some((name, body)) = part.split_once(':') else { continue };
            match name.trim() {
                "base" | "alt" => {
                    let values = settings(body);
                    if name.trim() == "base" { t.base = values } else { t.alt = values }
                }
                "curve" => {
                    t.curve = body
                        .split(',')
                        .filter_map(|p| {
                            let (x, y) = p.split_once(':')?;
                            Some((x.trim().parse::<f64>().ok()?.clamp(0.0, 1.0), y.trim().parse::<f64>().ok()?.clamp(0.0, 1.0)))
                        })
                        .collect();
                    t.curve.sort_by(|a, b| a.0.total_cmp(&b.0));
                }
                _ => {}
            }
        }
        t
    }

    /// How much of the alternate plays at `x`, 0 to 1 across the line: the curve, straight
    /// between its points and flat beyond its ends.
    pub fn amount(&self, x: f64) -> f64 {
        let c = &self.curve;
        match c.len() {
            0 => 0.0,
            1 => c[0].1,
            _ => {
                if x <= c[0].0 {
                    return c[0].1;
                }
                for w in c.windows(2) {
                    if x <= w[1].0 {
                        let span = (w[1].0 - w[0].0).max(1e-9);
                        return w[0].1 + (w[1].1 - w[0].1) * (x - w[0].0) / span;
                    }
                }
                c[c.len() - 1].1
            }
        }
    }

    /// The curve's average over the whole line, for what is planned once per line.
    pub fn average(&self) -> f64 {
        (0..=32).map(|i| self.amount(i as f64 / 32.0)).sum::<f64>() / 33.0
    }

    /// `key` at the moment where `amount` of the alternate plays. A voice that leaves the key out
    /// holds its neutral value, so a key only one voice sets fades in and out along the curve.
    pub fn get(&self, key: &str, amount: f64) -> f64 {
        let neutral = NEUTRAL.iter().find(|(k, _)| *k == key).map_or(0.0, |(_, v)| *v);
        self.get_from(key, amount, neutral)
    }

    /// [`get`](Self::get) with the neutral value given, for keys whose neutral depends on the line
    /// (the body blend comes from the customer's voice, the melody from the line's mood).
    pub fn get_from(&self, key: &str, amount: f64, neutral: f64) -> f64 {
        let of = |v: &Vec<(String, f64)>| v.iter().find(|(k, _)| k == key).map(|(_, x)| *x);
        let b = of(&self.base).unwrap_or(neutral);
        let a = of(&self.alt).unwrap_or(neutral);
        b + (a - b) * amount
    }

    /// Whether either voice sets `key`.
    pub fn has(&self, key: &str) -> bool {
        self.base.iter().chain(self.alt.iter()).any(|(k, _)| k == key)
    }
}

fn settings(text: &str) -> Vec<(String, f64)> {
    text.split(',')
        .filter_map(|kv| {
            let (k, v) = kv.split_once('=')?;
            let k = k.trim();
            NEUTRAL.iter().any(|(n, _)| *n == k).then_some(())?;
            Some((k.to_string(), v.trim().parse::<f64>().ok()?))
        })
        .collect()
}
