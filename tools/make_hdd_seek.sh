#!/usr/bin/env bash
# Cuts hdd_seek_<n>.wav, the work computer's hard drive seeking while CompuFunDB searches, from the
# drive chatter in the boot recording Godot/win95/sounds/boot_power_on.ogg (its credit is in the
# README), with the fan hum filtered out.
# Needs ffmpeg.
# Usage: make_hdd_seek.sh Godot/win95/sounds/boot_power_on.ogg Godot/sounds
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <boot_power_on.ogg> <Godot/sounds>" >&2; exit 2; }
source=$1 sounds=$2
[ -f "$source" ] || { echo "$0: missing $source" >&2; exit 1; }

# cut <start s> <end s> <output name>: mono, peak at -3 dB, short fades.
cut() {
	local start=$1 end=$2 name=$3
	local length gain
	length=$(awk "BEGIN{print $end - $start}")
	gain=$(ffmpeg -hide_banner -i "$source" -ss "$start" -to "$end" -ac 1 -af highpass=f=600,volumedetect -f null - 2>&1 \
		| awk '/max_volume/ {print -3 - $5}')
	ffmpeg -hide_banner -loglevel error -y -ss "$start" -to "$end" -i "$source" -ac 1 \
		-af "highpass=f=600,volume=${gain}dB,afade=t=in:d=0.01,afade=t=out:st=$(awk "BEGIN{print $length - 0.05}"):d=0.05" \
		-ar 22050 -map_metadata -1 -fflags +bitexact -c:a pcm_s16le "$sounds/$name.wav"
	# The fades and the filter's ringing move the peak: bring it to -3 dB again.
	gain=$(ffmpeg -hide_banner -i "$sounds/$name.wav" -af volumedetect -f null - 2>&1 | awk '/max_volume/ {print -3 - $5}')
	ffmpeg -hide_banner -loglevel error -y -i "$sounds/$name.wav" -af "volume=${gain}dB" \
		-map_metadata -1 -fflags +bitexact -c:a pcm_s16le "$sounds/$name.tmp.wav"
	mv "$sounds/$name.tmp.wav" "$sounds/$name.wav"
}

cut 5.95 6.30 hdd_seek_1
cut 6.30 6.62 hdd_seek_2
cut 6.40 6.75 hdd_seek_3
cut 6.60 6.95 hdd_seek_4
cut 8.35 8.70 hdd_seek_5
