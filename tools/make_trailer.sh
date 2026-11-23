#!/usr/bin/env bash
# Makes one cut of the CompuFun TV commercial (docs/trailers.md) an MP4: records it with Godot's Movie
# Maker, then makes it look and sound as if taped off a 1995 TV: a little colour bleed and tape noise on
# the picture, the sound of a small TV speaker, at the loudness that video sites expect.
#
# The cuts are the scenes in Godot/dev/trailer/: trailer (cheerful), trailer_win95 (more Windows 95) and
# trailer_bleak (deadpan). The narrator needs the live voice (tools/build-voice.sh); the recording runs
# through tools/run.sh, which finds Godot ($GODOT) and refuses while the editor has the project open.
# Keep the game window uncovered until it closes: macOS draws no frames for a covered window, and Movie
# Maker then records none. Needs ffmpeg (brew install ffmpeg).
# Usage: tools/make_trailer.sh <cut> <out.mp4>, for example: tools/make_trailer.sh trailer_bleak ~/Movies/bleak.mp4
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <trailer|trailer_win95|trailer_bleak> <out.mp4>" >&2; exit 2; }
cut=$1
out=$2
repo="$(cd "$(dirname "$0")/.." && pwd)"
[ -f "$repo/Godot/dev/trailer/$cut.tscn" ] || { echo "Error: no cut $cut: Godot/dev/trailer/$cut.tscn is missing" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "Error: no ffmpeg; brew install ffmpeg" >&2; exit 1; }

bleed=3         # how far the colours bleed sideways, in pixels
noise=7         # the tape noise, 0 to 100; it changes every frame, so the bitrate below caps the file
loudness=-16    # the loudness to reach, in LUFS

tmp="$(mktemp -d)"
trap 'rm -f "${tmp:?}/raw.avi"; rmdir "${tmp:?}"' EXIT
"$repo/tools/run.sh" --always-on-top --position 0,0 --resolution 1920x1080 --fixed-fps 30 \
	--write-movie "$tmp/raw.avi" "res://dev/trailer/$cut.tscn"
[ -s "$tmp/raw.avi" ] || { echo "Error: Movie Maker recorded nothing for $cut" >&2; exit 1; }

ffmpeg -hide_banner -loglevel error -y -i "$tmp/raw.avi" \
	-vf "chromashift=cbh=$bleed:crh=-$bleed,noise=alls=$noise:allf=t,eq=saturation=1.08,format=yuv420p" \
	-af "highpass=f=120,lowpass=f=8000,acompressor=threshold=-18dB:ratio=3:attack=10:release=200,loudnorm=I=$loudness:TP=-1.5" \
	-c:v libx264 -preset slow -b:v 10M -maxrate 12M -bufsize 24M -r 30 -c:a aac -b:a 192k -ar 48000 -movflags +faststart "$out"
echo "$out: $(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$out") s"
