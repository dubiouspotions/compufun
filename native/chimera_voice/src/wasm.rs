//! The C ABI that Godot/voices/live/live_voice.js calls in its worker.

use crate::Speaker;
use std::cell::RefCell;

thread_local! {
    static SPEAKER: RefCell<Speaker> = RefCell::new(Speaker::default());
    static BUFFER: RefCell<Vec<f32>> = const { RefCell::new(Vec::new()) };
}

fn text_of(ptr: *const u8, len: usize) -> String {
    // SAFETY: the host passes a buffer from say_alloc, filled with UTF-8.
    String::from_utf8_lossy(unsafe { std::slice::from_raw_parts(ptr, len) }).into_owned()
}

/// A buffer of `n` bytes for the host to fill; it is never freed, the host reuses few of them.
#[unsafe(no_mangle)]
pub extern "C" fn say_alloc(n: usize) -> *mut u8 {
    Box::leak(vec![0u8; n].into_boxed_slice()).as_mut_ptr()
}

#[unsafe(no_mangle)]
pub extern "C" fn say_load_dict(ptr: *const u8, len: usize) {
    let dict = text_of(ptr, len);
    SPEAKER.with_borrow_mut(|s| s.load_dict(&dict));
}

/// Shapes every later line with a voice type in its text form; an empty one says lines plainly.
#[unsafe(no_mangle)]
pub extern "C" fn say_voice_type(ptr: *const u8, len: usize) {
    let text = if len == 0 { String::new() } else { text_of(ptr, len) };
    SPEAKER.with_borrow_mut(|s| s.set_voice_type((!text.trim().is_empty()).then(|| crate::voice_type::VoiceType::parse(&text))));
}

#[unsafe(no_mangle)]
pub extern "C" fn say_start(ptr: *const u8, len: usize, body: u32, fs: f64, rate: f64, pitch: f64, accent: f64) -> u32 {
    let text = text_of(ptr, len);
    SPEAKER.with_borrow_mut(|s| s.start(&text, body, fs, rate, pitch, accent)) as u32
}

/// Renders up to `n` samples into the buffer at say_buffer(); returns how many.
#[unsafe(no_mangle)]
pub extern "C" fn say_render(n: usize) -> u32 {
    BUFFER.with_borrow_mut(|b| {
        b.resize(b.len().max(n), 0.0);
        SPEAKER.with_borrow_mut(|s| s.render(&mut b[..n])) as u32
    })
}

#[unsafe(no_mangle)]
pub extern "C" fn say_buffer() -> *const f32 {
    BUFFER.with_borrow(|b| b.as_ptr())
}
