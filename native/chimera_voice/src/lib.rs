//! Says a line the way `chimera render text` does (CMU dictionary, phrase planner, the body's
//! speaking pitch), but chunk by chunk, so a game can play it while it renders.

use chimera::anatomy::human::{BODY_CHILD, BODY_FEMALE, BODY_MALE};
use chimera::phonetics::english::EnglishG2P;
use chimera::phonetics::planner::{PhraseInput, PlanOptions, plan_phrases};
use chimera::voice::human_voice::{HumanVoice, SourcePatch};

#[cfg(feature = "godot")]
mod godot_class;
#[cfg(target_arch = "wasm32")]
mod wasm;

const BLOCK: usize = 128;

#[derive(Default)]
pub struct Speaker {
    g2p: Option<EnglishG2P>,
    voice: Option<HumanVoice>,
    left: usize,
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

    /// Plans `text` for body 0 male, 1 female, 2 child at `fs` Hz. `rate` and `pitch` are
    /// multipliers; `accent` < 0 keeps the planner's default. Returns the length in samples, 0
    /// without a dictionary.
    pub fn start(&mut self, text: &str, body: u32, fs: f64, rate: f64, pitch: f64, accent: f64) -> usize {
        let Some(g) = self.g2p.as_ref() else { return 0 };
        let (b, name, f0) = match body {
            1 => (BODY_FEMALE, "female", 205.0),
            2 => (BODY_CHILD, "child", 250.0),
            _ => (BODY_MALE, "male", 112.0),
        };
        let f0 = f0 * pitch;
        let inputs: Vec<PhraseInput> = g
            .to_phrases(text)
            .iter()
            .map(|p| PhraseInput { segments: p.segments.clone(), intonation: Some(p.intonation), pause: Some(p.pause) })
            .collect();
        let plan = plan_phrases(
            &inputs,
            &PlanOptions {
                body: name.into(),
                t0: 0.05,
                f0: Some(f0),
                rate: Some(rate),
                accent: if accent < 0.0 { None } else { Some(accent) },
                ..Default::default()
            },
        );
        let mut voice = HumanVoice::new(fs, b, 2);
        voice.set_source(&SourcePatch::f0(f0));
        voice.schedule(&plan.gestures);
        self.voice = Some(voice);
        self.left = (fs * (plan.end + 0.3)).round() as usize;
        self.left
    }

    /// Renders the next samples of the line into `out`; returns how many, 0 when it is over.
    pub fn render(&mut self, out: &mut [f32]) -> usize {
        let Some(voice) = self.voice.as_mut() else { return 0 };
        let n = out.len().min(self.left);
        for block in out[..n].chunks_mut(BLOCK) {
            voice.render(block);
        }
        self.left -= n;
        if self.left == 0 {
            self.voice = None;
        }
        n
    }

    pub fn stop(&mut self) {
        self.voice = None;
        self.left = 0;
    }
}
