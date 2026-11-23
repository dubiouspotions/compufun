#!/usr/bin/env bash
# Cuts hdd_seek_<n>.wav, the work computer's hard drive seeking while CompuFunDB searches, from the
# recording of a 1990s Compaq hard drive by jaegrover on Freesound (sounds/262872, CC0, credited in
# the README), as cut to boot_drive.ogg before 8fd51dc removed it:
#   git show 02f00a6:Godot/win95/sounds/boot_drive.ogg | git lfs smudge > boot_drive.ogg
# Needs ffmpeg.
# Usage: make_hdd_seek.sh <boot_drive.ogg> Godot/sounds
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <boot_drive.ogg> <Godot/sounds>" >&2; exit 2; }
source=$1 sounds=$2
[ -f "$source" ] || { echo "$0: missing $source" >&2; exit 1; }

# cut <start s> <end s> <output name>: mono, peak at -3 dB, short fades.
cut() {
	local start=$1 end=$2 name=$3
	local length gain
	length=$(awk "BEGIN{print $end - $start}")
	gain=$(ffmpeg -hide_banner -i "$source" -ss "$start" -to "$end" -ac 1 -af volumedetect -f null - 2>&1 \
		| awk '/max_volume/ {print -3 - $5}')
	ffmpeg -hide_banner -loglevel error -y -ss "$start" -to "$end" -i "$source" -ac 1 \
		-af "highpass=f=120,volume=${gain}dB,afade=t=in:d=0.01,afade=t=out:st=$(awk "BEGIN{print $length - 0.08}"):d=0.08" \
		-ar 22050 -map_metadata -1 -fflags +bitexact -c:a pcm_s16le "$sounds/$name.wav"
}

cut 0.40 0.75 hdd_seek_1
cut 0.80 1.10 hdd_seek_2
cut 1.30 1.60 hdd_seek_3
cut 2.10 2.45 hdd_seek_4
cut 2.95 3.30 hdd_seek_5
