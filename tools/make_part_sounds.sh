#!/usr/bin/env bash
# Cuts the sounds of misplaced parts from two Freesound recordings (CC0, credited in the README):
# part_rattle.ogg, the box of screws flipping over, from "boxofscrews.wav" by j1987 (sounds/79382);
# part_clunk_<n>.ogg, single parts dropping into a tray, from "R29-08-Small Metal Objects on Metal
# Tray.wav" by craigsmith (sounds/481935). Their HQ previews on cdn.freesound.org work too.
# Needs ffmpeg and oggenc (brew install ffmpeg vorbis-tools).
# Usage: make_part_sounds.sh <boxofscrews> <metal tray> Godot/sounds
set -euo pipefail

[ $# -eq 3 ] || { echo "usage: $0 <boxofscrews> <metal tray> <Godot/sounds>" >&2; exit 2; }
screws=$1 tray=$2 sounds=$3
for source in "$screws" "$tray"; do
	[ -f "$source" ] || { echo "$0: missing $source" >&2; exit 1; }
done

# cut <source> <start s> <end s> <fade-out s> <output name>: mono, peak at -3 dB, a short fade in.
cut() {
	local source=$1 start=$2 end=$3 fade=$4 name=$5
	local length gain
	length=$(awk "BEGIN{print $end - $start}")
	gain=$(ffmpeg -hide_banner -i "$source" -ss "$start" -to "$end" -ac 1 -af volumedetect -f null - 2>&1 \
		| awk '/max_volume/ {print -3 - $5}')
	ffmpeg -hide_banner -loglevel error -ss "$start" -to "$end" -i "$source" -ac 1 \
		-af "highpass=f=80,volume=${gain}dB,afade=t=in:d=0.005,afade=t=out:st=$(awk "BEGIN{print $length - $fade}"):d=$fade" \
		-map_metadata -1 -fflags +bitexact -c:a pcm_s16le -f wav - \
		| oggenc --quiet -q 4 -o "$sounds/$name.ogg" -
}

cut "$screws" 0.50 1.65 0.25 part_rattle
cut "$tray" 6.10 6.45 0.12 part_clunk_1
cut "$tray" 8.66 9.10 0.15 part_clunk_2
cut "$tray" 13.30 13.56 0.10 part_clunk_3
