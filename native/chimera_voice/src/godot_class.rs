//! ChimeraVoice for GDScript: load the dictionary, start a line, pull its samples each frame.

use crate::Speaker;
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
