#!/bin/bash
# Cuts the Office Assistant's poses, his lightbulb and the balloon's bullet out of screenshots of
# Office 97 in the win95ctl VM (docs/win95-reference.md, "Office Assistant").
# Usage: tools/crop_clippy.sh <shots dir> Godot/win95/office/assistant
#   <pose>.png, bulb_lit.png, bulb_unlit.png: his window, `win95ctl shot X.png --crop 524,324,102,95`
#   letter.png: the whole screen with the letter balloon open
set -euo pipefail
[ $# -eq 2 ] || { sed -n 2,7p "$0"; exit 1; }
shots=$1
out=$2
poses=(rest listen blink glance look point point_far stretch stretch_arm squash turn)

for pose in "${poses[@]}"; do
	magick "$shots/$pose.png" -crop 92x68+4+21 +repage "$out/clippy_$pose.png"  # the white stage under the title bar
done
for bulb in bulb_lit bulb_unlit; do
	magick "$shots/$bulb.png" -crop 18x26+71+26 +repage "$out/$bulb.png"
done
# The first choice's bullet, with the balloon's dithered yellow and white around it made clear.
magick "$shots/letter.png" -crop 16x16+508+202 +repage -alpha set -fill none \
	-opaque '#FFFF00' -opaque '#FFFFFF' -trim +repage "$out/bullet.png"
