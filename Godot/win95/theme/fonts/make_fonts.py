"""Builds w95fa_pixel_regular.ttf and w95fa_pixel_bold.ttf from W95FA, redrawn on a whole-pixel grid.

Usage: python3 make_fonts.py <path to W95FA.otf>
Needs: pip install fonttools
W95FA (SIL OFL 1.1) is at https://fontsarena.com/w95fa-by-alina-sava/
"""

import sys
from pathlib import Path

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.pointInsidePen import PointInsidePen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

HERE = Path(__file__).resolve().parent

SRC_PX = 80  # W95FA draws one pixel as 80 units at 1000 upem
SRC_X0 = 50  # and starts every glyph 50 units right of the origin
UPEM = 960   # 960 / 80 = 12, so font_size 12 maps one font pixel to one screen pixel


def rasterize(glyph_set, name):
    """Returns the set of lit (column, row) pixels, row 0 at the baseline, by sampling pixel centres."""
    glyph = glyph_set[name]
    lit = set()
    for row in range(-4, 14):
        for col in range(-2, 20):
            pen = PointInsidePen(glyph_set, (SRC_X0 + (col + 0.5) * SRC_PX, (row + 0.5) * SRC_PX))
            glyph.draw(pen)
            if pen.getResult():
                lit.add((col, row))
    return lit


def pixels_to_glyph(lit):
    pen = TTGlyphPen(None)
    for col, row in sorted(lit):
        x0, y0, x1, y1 = col * SRC_PX, row * SRC_PX, (col + 1) * SRC_PX, (row + 1) * SRC_PX
        pen.moveTo((x0, y0))
        pen.lineTo((x0, y1))
        pen.lineTo((x1, y1))
        pen.lineTo((x1, y0))
        pen.closePath()
    return pen.glyph()


def build_font(src_path, bold, out_path):
    src = TTFont(src_path)
    glyph_set = src.getGlyphSet()
    order = src.getGlyphOrder()
    glyphs, metrics = {}, {}
    for name in order:
        lit = rasterize(glyph_set, name)
        advance = round(src["hmtx"][name][0] / SRC_PX)
        if bold and lit:
            lit |= {(c + 1, r) for c, r in lit}  # double-strike, like Windows' synthesized bold
            advance += 1
        glyphs[name] = pixels_to_glyph(lit)
        left = min((c for c, _ in lit), default=0)
        metrics[name] = (advance * SRC_PX, left * SRC_PX)

    ascent = round(src["hhea"].ascent / SRC_PX) * SRC_PX
    descent = -round(-src["hhea"].descent / SRC_PX + 0.5) * SRC_PX
    style = "Bold" if bold else "Regular"
    fb = FontBuilder(UPEM, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap(src.getBestCmap())
    fb.setupGlyf(glyphs)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ascent, descent=descent)
    fb.setupOS2(sTypoAscender=ascent, sTypoDescender=descent, sTypoLineGap=0,
                usWinAscent=ascent, usWinDescent=-descent, usWeightClass=700 if bold else 400,
                fsSelection=0x20 if bold else 0x40)
    fb.setupNameTable({
        "familyName": "W95FA Pixel",
        "styleName": style,
        "uniqueFontIdentifier": f"W95FAPixel-{style}",
        "fullName": f"W95FA Pixel {style}",
        "psName": f"W95FAPixel-{style}",
        "version": "Version 1.0",
        "designer": "Alina Sava",
        "manufacturer": "FontsArena.com",
        "vendorURL": "https://fontsarena.com",
        "licenseDescription": "SIL Open Font License, Version 1.1",
        "licenseInfoURL": "https://openfontlicense.org",
        "description": "Pixel-grid version of W95FA for 12 px rendering.",
    })
    fb.setupPost()
    fb.updateHead(macStyle=1 if bold else 0)
    fb.save(out_path)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = Path(sys.argv[1])
    if not src.is_file():
        sys.exit(f"W95FA source font not found: {src}")
    build_font(src, False, HERE / "w95fa_pixel_regular.ttf")
    build_font(src, True, HERE / "w95fa_pixel_bold.ttf")


if __name__ == "__main__":
    main()
