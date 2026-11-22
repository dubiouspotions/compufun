#!/usr/bin/env bash
# Makes the CompuFun jingle that the loading screen plays (Godot/sounds/compufun_jingle.ogg) from
# the team's recording: a gentle low-pass softens its high notes, and a gain sets its loudness near
# the game's other sounds (the Win95 startup sound is -17.7 LUFS, the door chime -16.2 LUFS). The web
# build plays sounds as samples, which ignore bus effects, so the filter is in the file.
# Needs ffmpeg with libvorbis (brew install ffmpeg).
# Usage: make_compufun_jingle.sh <compufun.m4a> Godot/sounds/compufun_jingle.ogg
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <source audio> <out.ogg>" >&2; exit 2; }
source=$1
out=$2

cutoff=2500    # the low-pass cutoff in Hz; lower softens more of the high notes
loudness=-18   # the loudness to reach, in LUFS

measured=$(ffmpeg -hide_banner -nostats -i "$source" -af "lowpass=f=$cutoff,ebur128" -f null - 2>&1 \
	| awk '/^ *I:/ {print $2}' | tail -1)
[ -n "$measured" ] || { echo "$0: cannot measure the loudness of $source" >&2; exit 1; }
gain=$(awk -v target="$loudness" -v now="$measured" 'BEGIN {printf "%.2f", target - now}')

ffmpeg -hide_banner -loglevel error -y -i "$source" -af "lowpass=f=$cutoff,volume=${gain}dB" \
	-map_metadata -1 -c:a libvorbis -q:a 5 "$out"
echo "$out: low-pass at $cutoff Hz, then $gain dB to $loudness LUFS"
