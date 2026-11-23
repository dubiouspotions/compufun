#!/usr/bin/env bash
# Draws the paper label of the CompuFun AntiVirus floppy (parts/antivirus_floppy.tres): a red
# CompuFun band over "AntiVirus 1.0" in the Win95 pixel font, unsmoothed. Needs ImageMagick 7.
# Usage: make_antivirus_label.sh Godot/materials/textures/antivirus_label.png
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <out.png>" >&2; exit 2; }

fonts="$(cd "$(dirname "$0")/../Godot/win95/theme/fonts" && pwd)"
bold="$fonts/w95fa_pixel_bold.ttf"
regular="$fonts/w95fa_pixel_regular.ttf"
red='#e00000'
ink='#141418'

# 136 x 48 matches the label's 0.068 x 0.024 m print on props/floppy_disk.tscn.
magick -size 136x48 xc:'#f4f1e6' +antialias \
  -fill "$red" -draw 'rectangle 0,0 135,21' \
  -font "$bold" -pointsize 24 -fill white -annotate +4+19 'CompuFun' \
  -font "$bold" -pointsize 12 -fill "$ink" -annotate +4+34 'AntiVirus 1.0' \
  -font "$regular" -pointsize 11 -fill "$ink" -annotate +4+45 'Disk 1 of 1' \
  -fill "$red" -draw 'rectangle 84,38 131,43' \
  -strip -define png:color-type=2 "$1"
