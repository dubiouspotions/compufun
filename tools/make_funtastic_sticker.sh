#!/usr/bin/env bash
# Draws the "Have a FUNtastic day" sticker on the front of the shop counter, after the CompuFun
# logo (Godot/ui/logos/compufun_logo_red.png): white bold letters on its red, its three speed
# stripes and the tower at their end, inside a white edge. Needs ImageMagick 7.
# Usage: make_funtastic_sticker.sh Godot/materials/textures/funtastic_sticker.png
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <out.png>" >&2; exit 2; }

font="$(cd "$(dirname "$0")/../Godot/win95/theme/fonts" && pwd)/liberation_sans_bold.ttf"
red='#e00000'

# 360 x 96 matches the sticker's 0.63 x 0.168 m quad in rooms/shop/shop.tscn.
magick -size 360x96 xc:white \
  -fill "$red" -draw 'roundrectangle 5,5 354,90 10,10' \
  -font "$font" -fill white \
  -pointsize 30 -annotate +12+45 'Have a' \
  -pointsize 44 -annotate +115+47 'FUN' \
  -pointsize 30 -annotate +208+45 'tastic day' \
  -draw 'rectangle 16,60 300,64' -draw 'rectangle 30,68 300,72' -draw 'rectangle 44,76 300,80' \
  -draw 'rectangle 308,56 340,82' \
  -fill "$red" -draw 'rectangle 325,62 335,79' -draw 'point 311,59' -draw 'point 311,79' \
  -fill white -draw 'rectangle 327,74 333,76' \
  -strip -define png:color-type=2 "$1"
