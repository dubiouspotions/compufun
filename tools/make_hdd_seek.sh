#!/usr/bin/env bash
# Cuts hdd_seek_<n>.wav, the work computer's hard drive seeking while CompuFunDB searches, from "hard
# disk drive IBM (1999)" by viertelnachvier on Freesound (sounds/321502, CC0, credited in the
# README): an IBM DJNA-371350 defragmenting, its heads rumbling. Its HQ preview works:
#   https://cdn.freesound.org/previews/321/321502_2633921-hq.mp3
# Needs ffmpeg.
# Usage: make_hdd_seek.sh <the recording> Godot/sounds
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <the recording> <Godot/sounds>" >&2; exit 2; }
source=$1 sounds=$2
[ -f "$source" ] || { echo "$0: missing $source" >&2; exit 1; }

# cut <start s> <end s> <output name>: mono, peak at -3 dB, short fades.
cut() {
	local start=$1 end=$2 name=$3
	local length gain
	length=$(awk "BEGIN{print $end - $start}")
	gain=$(ffmpeg -hide_banner -i "$source" -ss "$start" -to "$end" -ac 1 -af highpass=f=150,volumedetect -f null - 2>&1 \
		| awk '/max_volume/ {print -3 - $5}')
	ffmpeg -hide_banner -loglevel error -y -ss "$start" -to "$end" -i "$source" -ac 1 \
		-af "highpass=f=150,volume=${gain}dB,afade=t=in:d=0.01,afade=t=out:st=$(awk "BEGIN{print $length - 0.05}"):d=0.05" \
		-ar 22050 -map_metadata -1 -fflags +bitexact -c:a pcm_s16le "$sounds/$name.wav"
	# The fades and the filter's ringing move the peak: bring it to -3 dB again.
	gain=$(ffmpeg -hide_banner -i "$sounds/$name.wav" -af volumedetect -f null - 2>&1 | awk '/max_volume/ {print -3 - $5}')
	ffmpeg -hide_banner -loglevel error -y -i "$sounds/$name.wav" -af "volume=${gain}dB" \
		-map_metadata -1 -fflags +bitexact -c:a pcm_s16le "$sounds/$name.tmp.wav"
	mv "$sounds/$name.tmp.wav" "$sounds/$name.wav"
}

cut 7.50 7.85 hdd_seek_1
cut 16.40 16.75 hdd_seek_2
cut 53.65 54.00 hdd_seek_3
cut 69.80 70.15 hdd_seek_4
cut 118.50 118.85 hdd_seek_5
