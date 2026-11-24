#!/usr/bin/env bash
# Draws the "Is it broken? Throw it in the TRASH!" employee poster on the front of the shop counter,
# after the CompuFun logo (Godot/ui/logos/compufun_logo_red.png): white bold letters on green bands,
# above and below a pictogram of a broken RAM stick going into a trash can. Needs ImageMagick 7.
# The Main view shows the poster about 65 x 53 pixels of the 480 x 270 world buffer, a fifth of this
# texture, so each line (label: with -size) takes the largest type that fits its band, and a white
# stroke fattens the letters so that the nearest-texel sampling keeps them whole.
# Usage: make_trash_poster.sh Godot/materials/textures/trash_poster.png
set -euo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <out.png>" >&2; exit 2; }

font="$(cd "$(dirname "$0")/../Godot/win95/theme/fonts" && pwd)/liberation_sans_bold.ttf"
green='#008f48'

# 320 x 280 matches the poster's 0.38 x 0.3325 m quad in rooms/shop/shop.tscn.
magick -size 320x280 xc:white \
  -fill "$green" -draw 'rectangle 6,6 313,68' -draw 'rectangle 6,150 313,273' \
  \( -background none -fill white -stroke white -strokewidth 3 -font "$font" -size 300x52 -gravity center label:'Is it broken?' \) -gravity north -geometry +0+11 -composite \
  \( -size 320x280 xc:none -fill "$green" \
    -draw 'polygon 22,118 72,110 64,122 70,132 60,144 28,150' \
    -draw 'polygon 80,112 128,104 134,136 84,144 76,134 82,124' \
    -fill white \
    -draw 'rectangle 30,122 40,132' -draw 'rectangle 46,120 56,130' \
    -draw 'rectangle 90,116 100,126' -draw 'rectangle 106,114 116,124' \
    -fill "$green" -stroke "$green" -strokewidth 3 \
    -draw 'line 68,96 72,104' -draw 'line 58,98 64,106' -draw 'line 80,96 76,104' \
    -fill none -strokewidth 7 -draw 'path "M 104,98 Q 170,60 214,108"' \
    -stroke none -fill "$green" -draw 'polygon 202,104 226,98 222,124' \
    -draw 'polygon 208,132 290,132 282,188 216,188' \
    -draw 'polygon 202,118 292,108 294,120 204,130' \
    -draw 'rectangle 236,108 258,112' \
    -fill white -draw 'rectangle 230,140 236,180' -draw 'rectangle 246,140 252,180' -draw 'rectangle 262,140 268,180' \
    -crop 284x118+14+74 +repage -resize x74 \) -gravity north -geometry +0+73 -composite \
  \( -background none -fill white -stroke white -strokewidth 3 -font "$font" -size 296x54 -gravity center label:'Throw it in' \) -gravity north -geometry +0+156 -composite \
  \( -background none -fill white -stroke white -strokewidth 3 -font "$font" -size 300x58 -gravity center label:'the TRASH!' \) -gravity north -geometry +0+210 -composite \
  -strip -define png:color-type=2 "$1"
