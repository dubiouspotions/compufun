#!/usr/bin/env bash
# Cuts the city ambience heard through the shop windows from "Westfield.wav" by Islabonita
# (https://freesound.org/people/Islabonita/sounds/178532/, CC0): a mono loop, low-passed so it
# sounds muffled, with the seam cross-faded. The web build plays sounds as samples, which ignore
# bus effects, so the muffling is in the file.
# Needs ffmpeg and oggenc (brew install ffmpeg vorbis-tools).
# Usage: make_city_ambience.sh <westfield.mp3 or .wav> Godot/sounds/city_ambience.ogg
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <source audio> <out.ogg>" >&2; exit 2; }
source=$1
out=$2

start=80      # a steady stretch of the recording, in seconds
loop=36       # the loop's length, in seconds
fade=4        # the cross-fade at the seam, in seconds
cutoff=600    # the low-pass cutoff in Hz; lower sounds more muffled
gain_db=23    # the recording is quiet; the player's volume_db sets the level in the game

# The loop plays [fade, loop + fade) and ends in a cross-fade into [0, fade), so its last sample
# runs on into its first.
ffmpeg -hide_banner -loglevel error -ss "$start" -t $((loop + fade)) -i "$source" \
	-filter_complex "[0]pan=mono|c0=0.5*c0+0.5*c1,lowpass=f=$cutoff,lowpass=f=$cutoff,volume=${gain_db}dB,aresample=22050,asplit[a][b];\
[a]atrim=start=$fade,asetpts=PTS-STARTPTS[body];[b]atrim=end=$fade,asetpts=PTS-STARTPTS[head];\
[body][head]acrossfade=d=$fade:c1=qsin:c2=qsin" \
	-map_metadata -1 -fflags +bitexact -c:a pcm_s16le -f wav - | oggenc --quiet -q 3 -o "$out" -
