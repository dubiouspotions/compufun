#!/usr/bin/env bash
# Cuts the buzz of a hung Win95 from its startup sound: a hung PC's sound card loops the last few
# hundredths of a second in its buffer until the reset. One slice; its import loops it, and the seam
# between the repeats is the buzz. Needs ffmpeg.
# Usage: make_hang_buzz.sh Godot/win95/sounds/boot_startup.ogg Godot/win95/sounds/hang_buzz.wav
set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 <boot_startup.ogg> <out.wav>" >&2; exit 2; }

at=1.8         # where in the startup sound Windows freezes, in seconds
slice=0.046    # the looped slice, in seconds; shorter buzzes higher

ffmpeg -loglevel error -y -ss "$at" -t "$slice" -i "$1" -ac 1 -ar 22050 -sample_fmt s16 "$2"
