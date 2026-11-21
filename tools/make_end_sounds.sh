#!/usr/bin/env bash
# Makes the sounds of the end (rooms/shop/the_end.tscn) from noise and tones, so there is nothing
# to credit: end_rumble.wav, a low rumble that dies out, and end_pierce.wav, the pipe through the
# chest (a metal clonk, a thud and a wet tear).
# Needs ffmpeg.
# Usage: make_end_sounds.sh Godot/sounds
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <out folder>" >&2; exit 2; }
out=$1

wav() { ffmpeg -hide_banner -loglevel error "$@" -map_metadata -1 -fflags +bitexact -ac 1 -c:a pcm_s16le -y; }

# The rumble: brown noise and a low tone, shaking, fading out.
seconds=3.5   # the whole sound
shake=11      # how fast the rumble shakes, in Hz
cutoff=180    # the low-pass cutoff of the noise in Hz; lower is deeper
tone=38       # the low tone under the noise, in Hz
wav -f lavfi -i "anoisesrc=color=brown:duration=$seconds:amplitude=1:seed=95" \
	-f lavfi -i "sine=frequency=$tone:duration=$seconds" \
	-filter_complex "[0]lowpass=f=$cutoff,lowpass=f=$cutoff,volume=6[noise];[1]volume=0.7[tone];\
[noise][tone]amix=inputs=2:normalize=0,tremolo=f=$shake:d=0.6,afade=t=in:d=0.03,afade=t=out:st=1:d=2.5,alimiter=limit=0.9,aresample=22050" \
	"$out/end_rumble.wav"

# The pierce: an inharmonic metal clonk, a thud and a short wet tear, all over in under a second.
wav -f lavfi -i "sine=frequency=173:duration=0.9" \
	-f lavfi -i "sine=frequency=419:duration=0.9" \
	-f lavfi -i "sine=frequency=1063:duration=0.9" \
	-f lavfi -i "anoisesrc=color=brown:duration=0.9:amplitude=1:seed=7" \
	-f lavfi -i "anoisesrc=color=pink:duration=0.9:amplitude=1:seed=13" \
	-filter_complex "[0]volume=0.5[a];[1]volume=0.35[b];[2]volume=0.2[c];\
[a][b][c]amix=inputs=3:normalize=0,afade=t=out:st=0:d=0.6:curve=exp[clonk];\
[3]lowpass=f=300,volume=9,afade=t=out:st=0:d=0.18:curve=exp[thud];\
[4]bandpass=f=1800:w=1400,tremolo=f=45:d=0.9,volume=2.5,adelay=25,afade=t=in:d=0.02,afade=t=out:st=0.05:d=0.35:curve=exp[tear];\
[clonk][thud][tear]amix=inputs=3:normalize=0,alimiter=limit=0.95,aresample=22050" \
	"$out/end_pierce.wav"
