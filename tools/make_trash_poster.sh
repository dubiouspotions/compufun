#!/usr/bin/env bash
# Draws the "Is it broken? Throw it in the TRASH!" employee poster on the front of the shop counter,
# after the CompuFun logo (Godot/ui/logos/compufun_logo_red.png): white bold letters on its red and
# its speed stripes, around a pictogram of a broken RAM stick going into a trash can. Needs ImageMagick 7.
# Usage: make_trash_poster.sh Godot/materials/textures/trash_poster.png
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <out.png>" >&2; exit 2; }

font="$(cd "$(dirname "$0")/../Godot/win95/theme/fonts" && pwd)/liberation_sans_bold.ttf"
red='#e00000'

# 320 x 280 matches the poster's 0.38 x 0.3325 m quad in rooms/shop/shop.tscn.
magick -size 320x280 xc:white \
  -fill "$red" -draw 'rectangle 8,8 311,70' -draw 'rectangle 8,196 311,271' \
  -font "$font" -fill white \
  -gravity north -pointsize 40 -annotate +0+15 'Is it broken?' \
  -gravity northwest -pointsize 28 -annotate +16+198 'Throw it in the' \
  -pointsize 44 -annotate +130+226 'TRASH!' \
  -draw 'polygon 18,232 112,232 112,238 24,238' \
  -draw 'polygon 26,246 112,246 112,252 32,252' \
  -draw 'polygon 34,260 112,260 112,266 40,266' \
  -fill "$red" \
  -draw 'polygon 22,118 72,110 64,122 70,132 60,144 28,150' \
  -draw 'polygon 80,112 128,104 134,136 84,144 76,134 82,124' \
  -fill white \
  -draw 'rectangle 30,122 40,132' -draw 'rectangle 46,120 56,130' \
  -draw 'rectangle 90,116 100,126' -draw 'rectangle 106,114 116,124' \
  -fill "$red" -stroke "$red" -strokewidth 3 \
  -draw 'line 68,96 72,104' -draw 'line 58,98 64,106' -draw 'line 80,96 76,104' \
  -fill none -strokewidth 7 -draw 'path "M 104,98 Q 170,60 214,108"' \
  -stroke none -fill "$red" -draw 'polygon 202,104 226,98 222,124' \
  -draw 'polygon 208,132 290,132 282,188 216,188' \
  -draw 'polygon 202,118 292,108 294,120 204,130' \
  -draw 'rectangle 236,108 258,112' \
  -fill white -draw 'rectangle 230,140 236,180' -draw 'rectangle 246,140 252,180' -draw 'rectangle 262,140 268,180' \
  -strip -define png:color-type=2 "$1"
