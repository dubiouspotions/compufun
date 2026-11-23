#!/usr/bin/env bash
# Cuts the sounds of the organs in Skater Bro's computer from Freesound recordings, all CC0, as
# mono WAVs; the README credits each. Download the previews named below into one folder first.
#   heartbeat.wav     one beat, looping at 60 bpm: "Human Heartbeat (60 BPM)" by FenrirFangs
#                     (https://freesound.org/people/FenrirFangs/sounds/213181/), 213181_3635427-hq.mp3
#   wheeze.wav        one breath, looping: "asthmatic_breathing.wav" by harleto
#                     (https://freesound.org/people/harleto/sounds/204469/), 204469_3183586-hq.mp3
#   squelch_1..3.wav  "Gore Impact - LOT OF HEART", "Meat Slap 2" and "Gushing Flesh" by magnuswaker
#                     (https://freesound.org/people/magnuswaker/sounds/641046/, /540076/, /563315/)
#   squelch_4..6.wav  three grabs from "Slimy flesh" by iampagan
#                     (https://freesound.org/people/iampagan/sounds/177017/), 177017_2484711-hq.mp3
# The loops' lengths are the organs' beat and breath in tools/make_organs.gd.
# Needs ffmpeg.
# Usage: cut_organ_sounds.sh <folder of the previews> Godot/sounds
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <previews folder> <sounds folder>" >&2; exit 2; }
from=$1
to=$2

# cut <source> <start s> <seconds> <out>: mono, 44.1 kHz, short fades, peak at -1.5 dB.
cut() {
	# The left channel, not a mix: the heartbeat's two channels nearly cancel each other.
	local fades="pan=mono|c0=c0,afade=t=in:d=0.005,afade=t=out:st=$(awk "BEGIN { print $3 - 0.03 }"):d=0.03"
	local peak
	peak=$(ffmpeg -hide_banner -ss "$2" -t "$3" -i "$from/$1" -af "$fades,volumedetect" -f null - 2>&1 | awk '/max_volume/ { print $5 }')
	ffmpeg -loglevel error -y -ss "$2" -t "$3" -i "$from/$1" -ar 44100 -af "$fades,volume=$(awk "BEGIN { print -1.5 - ($peak) }")dB" "$to/$4"
	echo "wrote $to/$4"
}

cut 213181_3635427-hq.mp3 3.07 1.0 heartbeat.wav
cut 204469_3183586-hq.mp3 8.25 3.5 wheeze.wav
cut 641046_11537497-hq.mp3 0 1.15 squelch_1.wav
cut 540076_11537497-hq.mp3 0 0.96 squelch_2.wav
cut 563315_11537497-hq.mp3 0 0.69 squelch_3.wav
cut 177017_2484711-hq.mp3 46.6 0.7 squelch_4.wav
cut 177017_2484711-hq.mp3 66.6 0.7 squelch_5.wav
cut 177017_2484711-hq.mp3 71.6 0.7 squelch_6.wav
