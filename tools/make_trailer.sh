#!/usr/bin/env bash
# Makes the CompuFun TV commercial (Godot/dev/trailer/trailer.tscn) an MP4 that looks and sounds as if
# taped off a 1995 TV: a little colour bleed and tape noise on the picture, and the sound of a small TV
# speaker, at the loudness that video sites expect.
#
# First record it with Godot's Movie Maker (close the Godot editor first: one Godot per checkout), from
# the repo root. The narrator needs the live voice: tools/build-voice.sh.
#   Godot --path Godot --always-on-top --position 0,0 --resolution 1920x1080 --fixed-fps 30 \
#     --write-movie /tmp/compufun_raw.avi res://dev/trailer/trailer.tscn
# --always-on-top: macOS draws no frames for a covered window, and Movie Maker then records none.
# Needs ffmpeg (brew install ffmpeg).
# Usage: make_trailer.sh <recorded.avi> <out.mp4>
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <recorded.avi> <out.mp4>" >&2; exit 2; }
recorded=$1
out=$2

bleed=3         # how far the colours bleed sideways, in pixels
noise=7         # the tape noise, 0 to 100; it changes every frame, so the bitrate below caps the file
loudness=-16    # the loudness to reach, in LUFS

ffmpeg -hide_banner -loglevel error -y -i "$recorded" \
	-vf "chromashift=cbh=$bleed:crh=-$bleed,noise=alls=$noise:allf=t,eq=saturation=1.08,format=yuv420p" \
	-af "highpass=f=120,lowpass=f=8000,acompressor=threshold=-18dB:ratio=3:attack=10:release=200,loudnorm=I=$loudness:TP=-1.5" \
	-c:v libx264 -preset slow -b:v 10M -maxrate 12M -bufsize 24M -r 30 -c:a aac -b:a 192k -ar 48000 -movflags +faststart "$out"
echo "$out: $(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$out") s"
