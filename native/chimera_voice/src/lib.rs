//! Says a line the way `chimera render text` does (CMU dictionary, phrase planner, the body's
//! speaking pitch), but chunk by chunk, so a game can play it while it renders. A voice type
//! (voice_type.rs) can shape it: blended live between its base and alternate voices along its
//! curve, and run through its effects (fx.rs).

use std::collections::VecDeque;

use chimera::anatomy::human::{BODY_CHILD, BODY_FEMALE, BODY_MALE, BodyMix, BodyName, HumanBody};
use chimera::control::score::{ControlKey, Gesture};
use chimera::phonetics::Intonation;
use chimera::phonetics::english::EnglishG2P;
use chimera::phonetics::planner::{PhraseInput, PlanOptions, plan_phrases};
use chimera::voice::human_voice::{HumanVoice, SourcePatch};

pub mod fx;
pub mod voice_type;

use fx::{Fx, Params};
use voice_type::{SOURCE_KEYS, VoiceType};

#[cfg(feature = "godot")]
mod godot_class;
#[cfg(target_arch = "wasm32")]
mod wasm;

const BLOCK: usize = 128;
/// The planner's pitch swing when a line gives none.
const DEFAULT_ACCENT: f64 = 0.14;

#[derive(Default)]
pub struct Speaker {
    g2p: Option<EnglishG2P>,
    voice: Option<HumanVoice>,
    left: usize,
    voice_type: Option<VoiceType>,
    /// With a voice type: the effects, what they have let out, and how far the voice has got.
    fx: Option<Fx>,
    queue: VecDeque<f32>,
    raw_total: usize,
    raw_done: usize,
    lines_said: u64,
}

impl Speaker {
    /// `dict` is cmudict.txt, gunzipped.
    pub fn load_dict(&mut self, dict: &str) {
        let mut g = EnglishG2P::new();
        g.load_dict(dict);
        self.g2p = Some(g);
    }

    pub fn is_ready(&self) -> bool {
        self.g2p.is_some()
    }

    /// Shapes every later line until replaced; `None` says lines plainly.
    pub fn set_voice_type(&mut self, voice_type: Option<VoiceType>) {
        self.voice_type = voice_type;
    }

    /// Plans `text` for body 0 male, 1 female, 2 child at `fs` Hz. `rate` and `pitch` are
    /// multipliers; `accent` < 0 keeps the planner's default. Returns about how many samples the
    /// line lasts (a voice type's stutters can make it longer), 0 without a dictionary.
    pub fn start(&mut self, text: &str, body: u32, fs: f64, rate: f64, pitch: f64, accent: f64) -> usize {
        let Some(g) = self.g2p.as_ref() else { return 0 };
        let (mut b, name, f0, neutral_mix) = match body {
            1 => (BODY_FEMALE, "female", 205.0, (1.0, 0.0)),
            2 => (BODY_CHILD, "child", 250.0, (0.0, 1.0)),
            _ => (BODY_MALE, "male", 112.0, (0.0, 0.0)),
        };
        let mut mix = BodyMix::from(name);
        let (mut f0, mut rate, mut pitch, mut accent, mut render_fs) = (f0, rate, pitch, accent, fs);
        let mut intonation = None;
        let mut tuned = 0.0;
        self.queue.clear();
        self.fx = None;
        if let Some(t) = self.voice_type.as_ref() {
            // What the voice plans once for the whole line takes the curve's average.
            let avg = t.average();
            rate *= t.get("rate", avg);
            pitch *= t.get("pitch", avg);
            if t.has("accent") {
                accent = t.get_from("accent", avg, if accent < 0.0 { DEFAULT_ACCENT } else { accent });
            }
            render_fs = t.get("fs", avg).clamp(2000.0, 96000.0);
            if t.has("female") || t.has("child") {
                mix = BodyMix::new(t.get_from("female", avg, neutral_mix.0), t.get_from("child", avg, neutral_mix.1));
                b = mix.body();
                f0 = mix.blend(|n| match n { BodyName::Male => 112.0, BodyName::Female => 205.0, BodyName::Child => 250.0 });
            }
            b = HumanBody {
                scale: b.scale * t.get("scale", avg),
                pharynx: b.pharynx * t.get("pharynx", avg),
                tongue_radius: b.tongue_radius * t.get("tongue", avg),
                lip_width: b.lip_width * t.get("lips", avg),
                fold_length: b.fold_length * t.get("folds", avg),
                open_phase: b.open_phase + t.get("open_phase", avg),
                ..b
            };
            intonation = match t.get("intonation", avg).round() as i64 {
                1 => Some(Intonation::Statement),
                2 => Some(Intonation::Question),
                3 => Some(Intonation::Flat),
                _ => None,
            };
            tuned = t.get("tune", avg).clamp(0.0, 1.0);
            self.lines_said += 1;
            let seed = text.bytes().fold(0xcbf29ce484222325u64 ^ self.lines_said, |h, c| (h ^ c as u64).wrapping_mul(0x100000001b3));
            self.fx = Some(Fx::new(fs, seed));
        }
        let f0 = f0 * pitch;
        let inputs: Vec<PhraseInput> = g
            .to_phrases(text)
            .iter()
            .map(|p| PhraseInput { segments: p.segments.clone(), intonation: Some(intonation.unwrap_or(p.intonation)), pause: Some(p.pause) })
            .collect();
        let mut plan = plan_phrases(
            &inputs,
            &PlanOptions {
                body: mix,
                t0: 0.05,
                f0: Some(f0),
                rate: Some(rate),
                accent: if accent < 0.0 { None } else { Some(accent) },
                ..Default::default()
            },
        );
        if tuned > 0.0 {
            tune(&mut plan.gestures, f0, tuned);
        }
        let mut voice = HumanVoice::new(render_fs, b, 2);
        voice.set_source(&self.source_at(0.0, f0));
        voice.schedule(&plan.gestures);
        self.voice = Some(voice);
        self.left = (render_fs * (plan.end + 0.3)).round() as usize;
        self.raw_total = self.left;
        self.raw_done = 0;
        match self.voice_type.as_ref() {
            Some(t) => self.left + (self.params_at(t.amount(1.0)).tail() * fs) as usize,
            None => self.left,
        }
    }

    /// Renders the next samples of the line into `out`; returns how many, 0 when it is over.
    pub fn render(&mut self, out: &mut [f32]) -> usize {
        if self.fx.is_none() {
            let Some(voice) = self.voice.as_mut() else { return 0 };
            let n = out.len().min(self.left);
            for block in out[..n].chunks_mut(BLOCK) {
                voice.render(block);
            }
            self.left -= n;
            if self.left == 0 {
                self.voice = None;
            }
            return n;
        }
        let mut raw = [0f32; BLOCK];
        while self.queue.len() < out.len() && self.voice.is_some() {
            let n = BLOCK.min(self.left);
            let amount = self.voice_type.as_ref().map_or(0.0, |t| t.amount(self.raw_done as f64 / self.raw_total.max(1) as f64));
            let source = self.source_at(amount, 0.0);
            let params = self.params_at(amount);
            let voice = self.voice.as_mut().unwrap();
            voice.set_source(&source);
            voice.render(&mut raw[..n]);
            self.left -= n;
            self.raw_done += n;
            let fx = self.fx.as_mut().unwrap();
            fx.push(&raw[..n], &params, &mut self.queue);
            if self.left == 0 {
                self.voice = None;
                fx.finish(&params, &mut self.queue);
            }
        }
        let n = out.len().min(self.queue.len());
        for (o, s) in out[..n].iter_mut().zip(self.queue.drain(..n)) {
            *o = s;
        }
        n
    }

    pub fn stop(&mut self) {
        self.voice = None;
        self.left = 0;
        self.queue.clear();
        self.fx = None;
    }

    // The voice source where `amount` of the alternate plays: only the keys the type sets, so the
    // rest stay Chimera's. `f0` > 0 sets the pitch too, as at the start of a line.
    fn source_at(&self, amount: f64, f0: f64) -> SourcePatch {
        let mut patch = SourcePatch { f0: (f0 > 0.0).then_some(f0), ..Default::default() };
        let Some(t) = self.voice_type.as_ref() else { return patch };
        let get = |k: &str| t.has(k).then(|| t.get(k, amount));
        for (key, value) in SOURCE_KEYS.iter().map(|k| (*k, get(k))) {
            let slot = match key {
                "glide" => &mut patch.glide,
                "pressure" => &mut patch.pressure,
                "breathiness" => &mut patch.breathiness,
                "tension" => &mut patch.tension,
                "fry" => &mut patch.fry,
                "roughness" => &mut patch.roughness,
                "vibrato_depth" => &mut patch.vibrato_depth,
                "vibrato_rate" => &mut patch.vibrato_rate,
                "drift" => &mut patch.drift,
                _ => &mut patch.brightness,
            };
            *slot = value;
        }
        if t.has("voiced") {
            patch.voiced = Some(t.get("voiced", amount) >= 0.5);
        }
        patch
    }

    fn params_at(&self, amount: f64) -> Params {
        let t = self.voice_type.as_ref();
        let g = |k: &str| t.map_or_else(|| VoiceType::default().get(k, 0.0), |t| t.get(k, amount));
        Params {
            wobble: g("wobble"),
            wobble_hz: g("wobble_hz"),
            chunk_ms: g("chunk_ms"),
            stutter: g("stutter"),
            stutter_ms: g("stutter_ms"),
            stutter_repeats: g("stutter_repeats"),
            reverse: g("reverse"),
            dropout: g("dropout"),
            static_: g("static"),
            static_level: g("static_level"),
            ring_hz: g("ring_hz"),
            ring_mix: g("ring_mix"),
            metal_ms: g("metal_ms"),
            metal_fb: g("metal_fb"),
            drive: g("drive"),
            distortion: g("distortion"),
            phaser: g("phaser"),
            chorus: g("chorus"),
            delay: g("delay"),
            reverb: g("reverb"),
            hold: g("hold"),
            bits: g("bits"),
        }
    }
}

/// Pulls the pitch of every planned gesture toward the nearest note of a major pentatonic scale on
/// the line's own pitch `root` (Hz), by `amount` from 0 (speech) to 1 (on the notes), and shortens
/// the glide between pitch targets, so the line sounds sung; at 1 it steps between notes.
fn tune(gestures: &mut [Gesture], root: f64, amount: f64) {
    const NOTES: [f64; 6] = [0.0, 2.0, 4.0, 7.0, 9.0, 12.0];
    for g in gestures.iter_mut() {
        let Some(f) = g.targets.get(ControlKey::F0) else { continue };
        if f <= 0.0 || root <= 0.0 {
            continue;
        }
        let semitones = 12.0 * (f / root).log2();
        let octave = (semitones / 12.0).floor() * 12.0;
        let within = semitones - octave;
        let note = NOTES.iter().copied().min_by(|a, b| (a - within).abs().total_cmp(&(b - within).abs())).unwrap_or(0.0);
        let snapped = root * 2f64.powf((octave + note) / 12.0);
        g.targets.set(ControlKey::F0, f + (snapped - f) * amount);
        if g.targets.iter().count() == 1 {
            // At 1 the pitch steps from note to note, as hard autotune does.
            g.ramp_in *= 1.0 - 0.97 * amount;
            g.ramp_out *= 1.0 - 0.97 * amount;
        }
    }
}
