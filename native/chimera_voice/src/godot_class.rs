//! ChimeraVoice for GDScript: load the dictionary, start a line, pull its samples each frame.

use crate::{Speaker, Tweaks};
use chimera::phonetics::Intonation;
use chimera::voice::human_voice::SourcePatch;
use godot::prelude::*;

struct ChimeraVoiceExtension;

#[gdextension]
unsafe impl ExtensionLibrary for ChimeraVoiceExtension {}

#[derive(GodotClass)]
#[class(init, base = RefCounted)]
struct ChimeraVoice {
    speaker: Speaker,
}

#[godot_api]
impl ChimeraVoice {
    /// `dict` is cmudict.txt, gunzipped.
    #[func]
    fn load_dict(&mut self, dict: GString) {
        self.speaker.load_dict(&dict.to_string());
    }

    #[func]
    fn is_ready(&self) -> bool {
        self.speaker.is_ready()
    }

    /// For a debug tool: overrides for every `start` until `clear_tweaks`. Keys, all optional:
    /// female, child (a body blend, 0..1); scale, pharynx, tongue, lips, folds (factors on the
    /// body); open_phase (added); glide, pressure, breathiness, tension, fry, roughness,
    /// vibrato_depth, vibrato_rate, drift, brightness (the voice source); voiced (bool);
    /// intonation ("statement", "question" or "flat").
    #[func]
    fn set_tweaks(&mut self, tweaks: VarDictionary) {
        let num = |key: &str| tweaks.get(key).and_then(|v| v.try_to::<f64>().ok());
        let mut t = Tweaks::default();
        if num("female").is_some() || num("child").is_some() {
            t.mix = Some((num("female").unwrap_or(0.0), num("child").unwrap_or(0.0)));
        }
        let shape = ["scale", "pharynx", "tongue", "lips", "folds"].map(|k| num(k));
        if shape.iter().any(|v| v.is_some()) {
            t.shape = Some(shape.map(|v| v.unwrap_or(1.0)));
        }
        t.open_phase = num("open_phase").unwrap_or(0.0);
        t.source = SourcePatch {
            glide: num("glide"),
            pressure: num("pressure"),
            breathiness: num("breathiness"),
            tension: num("tension"),
            fry: num("fry"),
            roughness: num("roughness"),
            vibrato_depth: num("vibrato_depth"),
            vibrato_rate: num("vibrato_rate"),
            drift: num("drift"),
            brightness: num("brightness"),
            voiced: tweaks.get("voiced").and_then(|v| v.try_to::<bool>().ok()),
            ..Default::default()
        };
        t.intonation = match tweaks.get("intonation").and_then(|v| v.try_to::<GString>().ok()).map(|s| s.to_string()).as_deref() {
            Some("statement") => Some(Intonation::Statement),
            Some("question") => Some(Intonation::Question),
            Some("flat") => Some(Intonation::Flat),
            _ => None,
        };
        self.speaker.set_tweaks(t);
    }

    #[func]
    fn clear_tweaks(&mut self) {
        self.speaker.set_tweaks(Tweaks::default());
    }

    /// Body 0 male, 1 female, 2 child; accent < 0 is the default. Returns samples, 0 on failure.
    #[func]
    fn start(&mut self, text: GString, body: i64, fs: f64, rate: f64, pitch: f64, accent: f64) -> i64 {
        self.speaker.start(&text.to_string(), body as u32, fs, rate, pitch, accent) as i64
    }

    /// Up to `n` more samples; empty when the line is over.
    #[func]
    fn render(&mut self, n: i64) -> PackedFloat32Array {
        let mut out = vec![0f32; n.max(0) as usize];
        let got = self.speaker.render(&mut out);
        out.truncate(got);
        PackedFloat32Array::from(out.as_slice())
    }

    #[func]
    fn stop(&mut self) {
        self.speaker.stop();
    }
}
