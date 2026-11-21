#!/usr/bin/env bash
# Makes the rumble of the end (rooms/shop/the_end.tscn) from noise: a thump and a low, shaking
# rumble that dies out. No source recording, so nothing to credit.
# Needs ffmpeg.
# Usage: make_end_rumble.sh Godot/sounds/end_rumble.wav
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <out.wav>" >&2; exit 2; }
out=$1

seconds=3.5   # the whole sound
shake=11      # how fast the rumble shakes, in Hz
cutoff=180    # the low-pass cutoff of the noise in Hz; lower is deeper
tone=38       # the low tone under the noise, in Hz

ffmpeg -hide_banner -loglevel error \
	-f lavfi -i "anoisesrc=color=brown:duration=$seconds:amplitude=1:seed=95" \
	-f lavfi -i "sine=frequency=$tone:duration=$seconds" \
	-filter_complex "[0]lowpass=f=$cutoff,lowpass=f=$cutoff,volume=6[noise];[1]volume=0.7[tone];\
[noise][tone]amix=inputs=2:normalize=0,tremolo=f=$shake:d=0.6,afade=t=in:d=0.03,afade=t=out:st=1:d=2.5,alimiter=limit=0.9,aresample=22050" \
	-map_metadata -1 -fflags +bitexact -ac 1 -c:a pcm_s16le -y "$out"
