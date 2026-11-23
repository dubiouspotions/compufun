#!/usr/bin/env bash
# Cuts hdd_seek_<n>.wav, the work computer's hard drive seeking while CompuFunDB searches, from "hard
# disk drive IBM (1999)" by viertelnachvier on Freesound (sounds/321502, CC0, credited in the
# README): an IBM DJNA-371350 defragmenting. Only its heads' ticks: the rumble between them is
# filtered and cut away. Its HQ preview works:
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
	gain=$(ffmpeg -hide_banner -i "$source" -ss "$start" -to "$end" -ac 1 -af highpass=f=400,volumedetect -f null - 2>&1 \
		| awk '/max_volume/ {print -3 - $5}')
	ffmpeg -hide_banner -loglevel error -y -ss "$start" -to "$end" -i "$source" -ac 1 \
		-af "highpass=f=400,volume=${gain}dB,afade=t=in:d=0.003,afade=t=out:st=$(awk "BEGIN{print $length - 0.03}"):d=0.03" \
		-ar 22050 -map_metadata -1 -fflags +bitexact -c:a pcm_s16le "$sounds/$name.wav"
	# The fades and the filter's ringing move the peak: bring it to -3 dB again.
	gain=$(ffmpeg -hide_banner -i "$sounds/$name.wav" -af volumedetect -f null - 2>&1 | awk '/max_volume/ {print -3 - $5}')
	ffmpeg -hide_banner -loglevel error -y -i "$sounds/$name.wav" -af "volume=${gain}dB" \
		-map_metadata -1 -fflags +bitexact -c:a pcm_s16le "$sounds/$name.tmp.wav"
	mv "$sounds/$name.tmp.wav" "$sounds/$name.wav"
}

# 70 ms around each of the sharpest ticks.
n=0
for at in 7.845 8.380 10.320 17.440 58.360 107.535 109.045 149.420; do
	n=$((n + 1))
	cut "$(awk "BEGIN{print $at - 0.01}")" "$(awk "BEGIN{print $at + 0.06}")" "hdd_seek_$n"
done
