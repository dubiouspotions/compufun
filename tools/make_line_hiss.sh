#!/usr/bin/env bash
# Makes the hiss of the line under a phone call: pink noise in the telephone's band
# (Godot/voices/effects/telephone.tres), a mono loop. Noise has no seam to hide.
# Needs ffmpeg and oggenc (brew install ffmpeg vorbis-tools).
# Usage: make_line_hiss.sh Godot/sounds/line_hiss.ogg
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <out.ogg>" >&2; exit 2; }

seconds=4
low_cut=500     # Hz, as the telephone's low_cut_hz
high_cut=2600   # Hz, as the telephone's high_cut_hz
gain_db=-12     # about -30 dBFS RMS; the player's volume_db sets the level in the game

ffmpeg -hide_banner -loglevel error -f lavfi \
	-i "anoisesrc=color=pink:amplitude=1:seed=1996:sample_rate=22050:duration=$seconds" \
	-af "highpass=f=$low_cut,highpass=f=$low_cut,lowpass=f=$high_cut,lowpass=f=$high_cut,volume=${gain_db}dB" \
	-map_metadata -1 -fflags +bitexact -c:a pcm_s16le -f wav - | oggenc --quiet -q 3 -o "$1" -
