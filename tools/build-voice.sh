#!/bin/bash
# Builds the live voice (native/chimera_voice) into Godot/voices/live/: chimera_voice.wasm for the
# web, the ChimeraVoice extension for desktop, and the .gdextension that lists the libraries that
# are there. Without them the game plays the rendered WAVs. Needs Rust (https://rustup.rs).
#   tools/build-voice.sh                 wasm and this machine's library
#   tools/build-voice.sh wasm macos linux windows   any of those (CI builds each on its own OS)
#   tools/build-voice.sh list            only rewrite the .gdextension from what is in bin/
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
crate="$root/native/chimera_voice"
live="$root/Godot/voices/live"
bin="$live/bin"
cargo="${CARGO:-cargo}"
command -v "$cargo" >/dev/null || cargo="$HOME/.cargo/bin/cargo"
rustup="$(dirname "$cargo")/rustup"
command -v rustup >/dev/null && rustup=rustup
mkdir -p "$bin"

build() {  # build <rust target> [cargo args...]; prints the target dir
	"$rustup" target add "$1" >/dev/null
	"$cargo" build --manifest-path "$crate/Cargo.toml" --release --target "$@" >&2
	echo "$crate/target/$1/release"
}

targets=("$@")
if [ ${#targets[@]} -eq 0 ]; then
	case "$(uname -s)" in
		Darwin) targets=(wasm macos) ;;
		Linux) targets=(wasm linux) ;;
		*) targets=(wasm windows) ;;
	esac
fi

for t in "${targets[@]}"; do
	case "$t" in
		wasm) cp "$(build wasm32-unknown-unknown)/chimera_voice.wasm" "$live/chimera_voice.wasm" ;;
		macos)
			arm="$(build aarch64-apple-darwin --features godot)/libchimera_voice.dylib"
			x86="$(build x86_64-apple-darwin --features godot)/libchimera_voice.dylib"
			lipo -create "$arm" "$x86" -output "$bin/libchimera_voice.macos.dylib" ;;
		linux) cp "$(build x86_64-unknown-linux-gnu --features godot)/libchimera_voice.so" "$bin/libchimera_voice.linux.x86_64.so" ;;
		windows) cp "$(build x86_64-pc-windows-gnu --features godot)/chimera_voice.dll" "$bin/chimera_voice.windows.x86_64.dll" ;;
		list) ;;
		*) echo "Error: unknown target $t (wasm, macos, linux, windows, list)" >&2; exit 1 ;;
	esac
done

# List only the libraries that exist: Godot reports a listed library that is missing as an error,
# and so does a .gdextension that lists none.
libraries="$(
	[ -f "$bin/libchimera_voice.macos.dylib" ] && printf 'macos = "res://voices/live/bin/libchimera_voice.macos.dylib"\n'
	[ -f "$bin/libchimera_voice.linux.x86_64.so" ] && printf 'linux.x86_64 = "res://voices/live/bin/libchimera_voice.linux.x86_64.so"\n'
	[ -f "$bin/chimera_voice.windows.x86_64.dll" ] && printf 'windows.x86_64 = "res://voices/live/bin/chimera_voice.windows.x86_64.dll"\n'
	true
)"
ls -la "$live/chimera_voice.wasm" "$bin" 2>/dev/null | grep -E "chimera_voice" >&2 || true
if [ -z "$libraries" ]; then
	rm -f "$live/chimera_voice.gdextension"
	echo "No libraries in $bin, so no $live/chimera_voice.gdextension" >&2
	exit 0
fi
printf '[configuration]\n\nentry_symbol = "gdext_rust_init"\ncompatibility_minimum = 4.7\nreloadable = false\n\n[libraries]\n\n%s\n' "$libraries" > "$live/chimera_voice.gdextension"
echo "Wrote $live/chimera_voice.gdextension" >&2
