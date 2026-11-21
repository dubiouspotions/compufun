#!/usr/bin/env python3
"""Extracts every icon from a copy of a Windows 95 install into named PNGs. See docs/win95-icons.md.

Usage: extract_win95_icons.py SRC_DIR OUT_DIR [--names NAMES.json] [--theme-icons DIR]
                               [--sheet SHEET.png [--sheet-names a,b,...] [--sheet-cols N]]

SRC_DIR is a copy of the guest's C: drive. The script reads every .ICO file and every NE (16-bit) or
PE (32-bit) .EXE/.DLL/.CPL/.SCR/.MOD/.DRV under it, decodes each icon group, and writes one PNG per
image to OUT_DIR, with transparency from the AND mask. Icon groups whose images are identical are
written once; manifest.json lists the copies under "duplicates".

Names: OUT_DIR/manifest.json is both output and input. Each icon's "name" is carried over from the
previous manifest by its key ("WINDOWS/SYSTEM/SHELL32.DLL#4"). --names adds or overrides names from
a {key: name} JSON file. An icon without a name is written as <file stem>_<group id>.

--theme-icons lists, on each image in the manifest, the PNGs in DIR with the same pixels
("theme_icons"); transparent pixels match whatever their colour.

Files per icon: <name>_<size>.png for the deepest colour depth at each size, and
<name>_<size>_<bpp>bit.png for every shallower depth at that size. <size> is "32" for 32x32 and
"48x32" for a non-square image. Only stdlib; Python 3.9 or newer.
"""
import argparse
import hashlib
import json
import os
import struct
import sys
import zlib

RT_ICON, RT_GROUP_ICON = 3, 14
SCANNED = {".ico", ".exe", ".dll", ".cpl", ".scr", ".mod", ".drv", ".icl", ".ocx"}
PNG_SIG = b"\x89PNG\r\n\x1a\n"


class BadFile(Exception):
    pass


def u16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def u32(b, o):
    return struct.unpack_from("<I", b, o)[0]


# ---------------------------------------------------------------- resource tables

def ne_resources(d, ne):
    """Yields (type, id, bytes) from a 16-bit NE resource table; ids are ints or str."""
    table = ne + u16(d, ne + 0x24)
    if table == ne + u16(d, ne + 0x26):
        return
    shift = u16(d, table)
    p = table + 2

    def ident(v):
        if v & 0x8000:
            return v & 0x7FFF
        n = d[table + v]
        return d[table + v + 1:table + v + 1 + n].decode("latin-1")

    while True:
        rtype = u16(d, p)
        if rtype == 0:
            return
        count = u16(d, p + 2)
        p += 8
        for _ in range(count):
            off, length, _flags, rid = struct.unpack_from("<HHHH", d, p)
            p += 12
            yield ident(rtype), ident(rid), d[off << shift:(off << shift) + (length << shift)]


def pe_resources(d, pe):
    """Yields (type, id, bytes) from a 32-bit PE resource directory; ids are ints or str."""
    nsect, opt_size = u16(d, pe + 6), u16(d, pe + 20)
    opt = pe + 24
    magic = u16(d, opt)
    dirs = opt + (96 if magic == 0x10B else 112)
    rsrc_rva = u32(d, dirs + 16)
    if not rsrc_rva:
        return
    sections = []
    for i in range(nsect):
        s = opt + opt_size + 40 * i
        vsize, va, rawsize, rawptr = struct.unpack_from("<IIII", d, s + 8)
        sections.append((va, max(vsize, rawsize), rawptr))

    def off(rva):
        for va, size, rawptr in sections:
            if va <= rva < va + size:
                return rva - va + rawptr
        raise BadFile(f"RVA {rva:#x} lies in no section")

    base = off(rsrc_rva)

    def entries(o):
        named, ids = u16(d, o + 12), u16(d, o + 14)
        for i in range(named + ids):
            name, target = struct.unpack_from("<II", d, o + 16 + 8 * i)
            if name & 0x80000000:
                s = base + (name & 0x7FFFFFFF)
                ident = d[s + 2:s + 2 + 2 * u16(d, s)].decode("utf-16-le")
            else:
                ident = name
            yield ident, target

    for rtype, t1 in entries(base):
        for rid, t2 in entries(base + (t1 & 0x7FFFFFFF)):
            for _lang, t3 in entries(base + (t2 & 0x7FFFFFFF)):
                rva, size = struct.unpack_from("<II", d, base + t3)
                start = off(rva)
                yield rtype, rid, d[start:start + size]
                break  # the first language is enough; Win95 ships one


def icon_groups(path):
    """Returns [(group id, [icon image bytes])] for one file; raises BadFile when unreadable."""
    d = open(path, "rb").read()
    if path.lower().endswith(".ico"):
        _, kind, count = struct.unpack_from("<HHH", d)
        if kind != 1:
            raise BadFile(f"{path}: ICONDIR type {kind} is not an icon")
        images = []
        for i in range(count):
            size, offset = struct.unpack_from("<II", d, 6 + 16 * i + 8)
            images.append(d[offset:offset + size])
        return [(0, images)]
    if len(d) < 0x40 or d[:2] != b"MZ":
        return []
    hdr = u32(d, 0x3C)
    sig = d[hdr:hdr + 4]
    if sig == b"PE\0\0":
        res = list(pe_resources(d, hdr))
    elif sig[:2] == b"NE":
        res = list(ne_resources(d, hdr))
    else:
        return []  # DOS, LE (VxD) and LX files carry no Windows icons
    icons = {rid: b for t, rid, b in res if t == RT_ICON}
    groups = []
    for t, gid, g in res:
        if t != RT_GROUP_ICON:
            continue
        _, kind, count = struct.unpack_from("<HHH", g)
        images = []
        for i in range(count):
            icon_id = u16(g, 6 + 14 * i + 12)
            if icon_id not in icons:
                raise BadFile(f"{path}: icon group {gid} names RT_ICON {icon_id}, which the file lacks")
            images.append(icons[icon_id])
        groups.append((gid, images))
    return groups


# ---------------------------------------------------------------- DIB decoding

def decode_icon(b, where):
    """Returns (width, height, bpp, RGBA bytes) for one icon image (a DIB with an AND mask)."""
    if b[:8] == PNG_SIG:
        raise BadFile(f"{where}: PNG icon images are Vista-era; this script decodes DIBs only")
    hsize = u32(b, 0)
    if hsize == 40:
        _, w, h2, _, bpp, comp, _, _, _, used, _ = struct.unpack_from("<IiiHHIIiiII", b)
        pal_entry = 4
    elif hsize == 12:
        w, h2, _, bpp = struct.unpack_from("<HHHH", b, 4)
        comp, used, pal_entry = 0, 0, 3
    else:
        raise BadFile(f"{where}: unknown bitmap header size {hsize}")
    if comp != 0:
        raise BadFile(f"{where}: compressed icon bitmap (compression {comp})")
    h = h2 // 2
    ncolors = (used or 1 << bpp) if bpp <= 8 else 0
    pal = [tuple(b[hsize + pal_entry * i + j] for j in (2, 1, 0)) for i in range(ncolors)]
    xor = hsize + pal_entry * ncolors
    xstride = (w * bpp + 31) // 32 * 4
    and_ = xor + xstride * h
    astride = (w + 31) // 32 * 4
    if and_ + astride * h > len(b):
        raise BadFile(f"{where}: {len(b)} bytes is too short for a {w}x{h} {bpp}-bit icon")
    has_alpha = bpp == 32 and any(b[xor + 3 + 4 * i] for i in range(w * h))
    out = bytearray()
    for y in range(h):
        row = xor + xstride * (h - 1 - y)
        mrow = and_ + astride * (h - 1 - y)
        for x in range(w):
            if bpp <= 8:
                bit = x * bpp
                idx = (b[row + bit // 8] >> (8 - bpp - bit % 8)) & ((1 << bpp) - 1)
                r, g, bl = pal[idx]
                a = 255
            elif bpp == 24:
                bl, g, r = b[row + 3 * x:row + 3 * x + 3]
                a = 255
            elif bpp == 32:
                bl, g, r, a = b[row + 4 * x:row + 4 * x + 4]
                if not has_alpha:
                    a = 255
            else:
                raise BadFile(f"{where}: {bpp}-bit icons are not supported")
            if not has_alpha and b[mrow + x // 8] >> (7 - x % 8) & 1:
                r = g = bl = a = 0  # AND bit set: the screen shows through (or is inverted, which a PNG can't)
            out += bytes((r, g, bl, a))
    return w, h, bpp, bytes(out)


# ---------------------------------------------------------------- PNG

def png(w, h, pixels, channels=4):
    """Encodes 8-bit RGBA (channels=4) or RGB (channels=3) pixels as PNG bytes."""
    stride = w * channels
    raw = b"".join(b"\0" + pixels[y * stride:(y + 1) * stride] for y in range(h))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    color_type = {4: 6, 3: 2}[channels]
    return (PNG_SIG + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, color_type, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def read_png(path):
    """Returns (width, height, RGBA bytes) of an 8-bit RGBA, non-interlaced PNG."""
    d = open(path, "rb").read()
    if d[:8] != PNG_SIG:
        raise BadFile(f"{path}: not a PNG")
    w, h, depth, color_type, _, _, interlace = struct.unpack(">IIBBBBB", d[16:29])
    if (depth, color_type, interlace) != (8, 6, 0):
        raise BadFile(f"{path}: only 8-bit RGBA non-interlaced PNGs are compared "
                      f"(depth {depth}, colour type {color_type}, interlace {interlace})")
    o, idat = 8, b""
    while o < len(d):
        n, tag = struct.unpack(">I4s", d[o:o + 8])
        if tag == b"IDAT":
            idat += d[o + 8:o + 8 + n]
        o += 12 + n
    raw, s, out, prev = zlib.decompress(idat), w * 4, bytearray(), bytearray(w * 4)
    for y in range(h):
        f, line = raw[y * (s + 1)], bytearray(raw[y * (s + 1) + 1:(y + 1) * (s + 1)])
        for i in range(s):
            a, b = line[i - 4] if i >= 4 else 0, prev[i]
            c = prev[i - 4] if i >= 4 else 0
            if f == 1:
                line[i] = (line[i] + a) & 255
            elif f == 2:
                line[i] = (line[i] + b) & 255
            elif f == 3:
                line[i] = (line[i] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        out += line
        prev = line
    return w, h, bytes(out)


def opaque_pixels(rgba):
    """Clears the colour of transparent pixels, so that images compare by what they show."""
    out = bytearray(rgba)
    for i in range(3, len(out), 4):
        if out[i] == 0:
            out[i - 3:i] = b"\0\0\0"
    return bytes(out)


# ---------------------------------------------------------------- contact sheet

FONT = {  # 3 x 5 glyphs
    "0": "###,#.#,#.#,#.#,###", "1": ".#.,##.,.#.,.#.,###", "2": "###,..#,###,#..,###",
    "3": "###,..#,.##,..#,###", "4": "#.#,#.#,###,..#,..#", "5": "###,#..,###,..#,###",
    "6": "###,#..,###,#.#,###", "7": "###,..#,..#,.#.,.#.", "8": "###,#.#,###,#.#,###",
    "9": "###,#.#,###,..#,###", "a": ".#.,#.#,###,#.#,#.#", "b": "##.,#.#,##.,#.#,##.",
    "c": ".##,#..,#..,#..,.##", "d": "##.,#.#,#.#,#.#,##.", "e": "###,#..,##.,#..,###",
    "f": "###,#..,##.,#..,#..", "g": ".##,#..,#.#,#.#,.##", "h": "#.#,#.#,###,#.#,#.#",
    "i": "###,.#.,.#.,.#.,###", "j": "..#,..#,..#,#.#,.#.", "k": "#.#,#.#,##.,#.#,#.#",
    "l": "#..,#..,#..,#..,###", "m": "#.#,###,###,#.#,#.#", "n": "##.,#.#,#.#,#.#,#.#",
    "o": ".#.,#.#,#.#,#.#,.#.", "p": "##.,#.#,##.,#..,#..", "q": ".#.,#.#,#.#,##.,.##",
    "r": "##.,#.#,##.,#.#,#.#", "s": ".##,#..,.#.,..#,##.", "t": "###,.#.,.#.,.#.,.#.",
    "u": "#.#,#.#,#.#,#.#,###", "v": "#.#,#.#,#.#,#.#,.#.", "w": "#.#,#.#,###,###,#.#",
    "x": "#.#,#.#,.#.,#.#,#.#", "y": "#.#,#.#,.#.,.#.,.#.", "z": "###,..#,.#.,#..,###",
    "_": "...,...,...,...,###", "-": "...,...,###,...,...", " ": "...,...,...,...,...",
}
TEAL, WHITE = (0, 128, 128), (255, 255, 255)


def contact_sheet(icons, cols, scale=2):
    """Draws each icon's largest and smallest image at `scale` over its name; returns PNG bytes."""
    label_px = 2 * scale - 2
    longest = max(len(i["name"]) for i in icons)
    cell_w = max(64 * scale, longest * 4 * label_px + 8)
    cell_h = 32 * scale + 6 * label_px + 12
    rows = (len(icons) + cols - 1) // cols
    W, H = cols * cell_w, rows * cell_h
    px = bytearray(bytes(TEAL) * W * H)

    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            px[3 * (y * W + x):3 * (y * W + x) + 3] = bytes(c)

    for n, icon in enumerate(icons):
        cx, cy = n % cols * cell_w, n // cols * cell_h
        imgs = sorted((i for i in icon["pixels"] if i[0] <= 32 and i[1] <= 32), key=lambda i: -i[0] * i[1])
        imgs = imgs or icon["pixels"][:1]
        shown = [imgs[0]] + ([imgs[-1]] if imgs[-1][:2] != imgs[0][:2] else [])
        x0 = cx + (cell_w - sum(min(i[0], 32) * scale + 4 for i in shown)) // 2
        for w, h, rgba in shown:
            for y in range(min(h, 32)):
                for x in range(min(w, 32)):
                    r, g, b, a = rgba[4 * (y * w + x):4 * (y * w + x) + 4]
                    if a:
                        for sy in range(scale):
                            for sx in range(scale):
                                put(x0 + x * scale + sx, cy + 4 + y * scale + sy, (r, g, b))
            x0 += min(w, 32) * scale + 4
        lx = cx + (cell_w - len(icon["name"]) * 4 * label_px) // 2
        ly = cy + 32 * scale + 8
        for ch in icon["name"].lower():
            glyph = FONT.get(ch, FONT["-"]).split(",")
            for gy, line in enumerate(glyph):
                for gx, on in enumerate(line):
                    if on == "#":
                        for sy in range(label_px):
                            for sx in range(label_px):
                                put(lx + gx * label_px + sx, ly + gy * label_px + sy, WHITE)
            lx += 4 * label_px
    return png(W, H, bytes(px), channels=3)


# ---------------------------------------------------------------- main

def source_order(rel):
    """Sorts the live copy of a file before its SYSBCKUP backup, so the live one is kept."""
    return ("SYSBCKUP" in rel.upper(), rel.upper())


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--names", help="JSON file of {key: name} that adds to or overrides the manifest's names")
    ap.add_argument("--theme-icons", help="directory of PNGs to match against the extracted images")
    ap.add_argument("--sheet", help="write a contact sheet to this PNG")
    ap.add_argument("--sheet-names", help="comma-separated icon names for the sheet; default all")
    ap.add_argument("--sheet-cols", type=int, default=12)
    a = ap.parse_args()

    manifest_path = os.path.join(a.out, "manifest.json")
    carried = {}
    if os.path.exists(manifest_path):
        with open(manifest_path) as f:
            for icon in json.load(f)["icons"]:
                for key in [icon["key"]] + icon.get("duplicates", []):
                    carried[key] = icon["name"]
    if a.names:
        with open(a.names) as f:
            carried.update(json.load(f))

    theme = {}
    if a.theme_icons:
        for n in sorted(os.listdir(a.theme_icons)):
            if n.lower().endswith(".png"):
                try:
                    w, h, rgba = read_png(os.path.join(a.theme_icons, n))
                except (BadFile, zlib.error, struct.error) as e:
                    sys.exit(f"--theme-icons: {e}")
                theme.setdefault((w, h, opaque_pixels(rgba)), []).append(n)

    files = []
    for root, _, names in os.walk(a.src):
        for n in names:
            if os.path.splitext(n)[1].lower() in SCANNED:
                files.append(os.path.relpath(os.path.join(root, n), a.src).replace(os.sep, "/"))
    files.sort(key=source_order)

    icons, by_content = [], {}
    for rel in files:
        try:
            groups = [(gid, [decode_icon(b, f"{rel}#{gid} image {i}") for i, b in enumerate(images)])
                      for gid, images in icon_groups(os.path.join(a.src, rel))]
        except (BadFile, struct.error, IndexError) as e:
            sys.exit(f"{rel}: cannot read its icons: {e}")
        for gid, decoded in groups:
            key = f"{rel}#{gid}"
            content = hashlib.sha1(b"".join(
                struct.pack("<HHH", w, h, bpp) + rgba for w, h, bpp, rgba in sorted(decoded))).hexdigest()
            if content in by_content:
                by_content[content]["duplicates"].append(key)
                continue
            stem = os.path.splitext(os.path.basename(rel))[0].lower()
            icon = {"key": key, "name": carried.get(key) or f"{stem}_{gid}".lower().replace(" ", "_"),
                    "source": rel, "group": gid, "images": [], "duplicates": [], "decoded": decoded}
            by_content[content] = icon
            icons.append(icon)

    taken = {}
    for icon in icons:
        if icon["name"] in taken:
            sys.exit(f"name {icon['name']!r} is given to both {taken[icon['name']]} and {icon['key']}")
        taken[icon["name"]] = icon["key"]

    os.makedirs(a.out, exist_ok=True)
    for icon in icons:
        decoded = sorted(icon.pop("decoded"), key=lambda i: (-i[0] * i[1], -i[2]))
        seen_sizes = set()
        for w, h, bpp, rgba in decoded:
            size = str(w) if w == h else f"{w}x{h}"
            fname = f"{icon['name']}_{size}" + (f"_{bpp}bit" if size in seen_sizes else "") + ".png"
            if any(i["file"] == fname for i in icon["images"]):
                continue  # the group lists the same size and depth twice
            seen_sizes.add(size)
            with open(os.path.join(a.out, fname), "wb") as f:
                f.write(png(w, h, rgba))
            image = {"file": fname, "width": w, "height": h, "bpp": bpp}
            if a.theme_icons:
                image["theme_icons"] = theme.get((w, h, opaque_pixels(rgba)), [])
            icon["images"].append(image)
            icon.setdefault("pixels", []).append((w, h, rgba))

    if a.sheet:
        shown = icons
        if a.sheet_names:
            by_name = {i["name"]: i for i in icons}
            unknown = [n for n in a.sheet_names.split(",") if n not in by_name]
            if unknown:
                sys.exit(f"--sheet-names: no icon is named {', '.join(unknown)}")
            shown = [by_name[n] for n in a.sheet_names.split(",")]
        with open(a.sheet, "wb") as f:
            f.write(contact_sheet(shown, a.sheet_cols))
    for icon in icons:
        icon.pop("pixels")
    with open(manifest_path, "w") as f:
        json.dump({"source": "C:\\ of a Windows 95 install; see docs/win95-icons.md", "icons": icons}, f, indent=1)
        f.write("\n")
    images = sum(len(i["images"]) for i in icons)
    dups = sum(len(i["duplicates"]) for i in icons)
    print(f"{len(icons)} icons, {images} images, {dups} duplicate groups, from {len(files)} files -> {a.out}")
    written = {im["file"] for i in icons for im in i["images"]}
    stale = sorted(n for n in os.listdir(a.out) if n.endswith(".png") and n not in written)
    if stale:
        print(f"{len(stale)} PNGs in {a.out} are not in the manifest (renamed?): {', '.join(stale)}", file=sys.stderr)


if __name__ == "__main__":
    main()
