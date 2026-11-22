#!/usr/bin/env python3
"""Asks an image model (codex image_gen on the ChatGPT plan, or Gemini) to draw each person from
behind, from their neutral portrait, for the back of the photo relief body. It writes Godot/people/<name>/back.png: the drawing, at the portrait's size, cut to the
portrait's outline mirrored (seen from behind, the outline is the front's mirror image), so the back
always fits the front. The raw answers go to the folder given by --raw, for review.

Usage: make_portrait_backs.py --raw <folder> [--backend codex|gemini] [--only name,name] [--force]
codex: the logged-in codex CLI makes the image (about a minute each, on the ChatGPT plan).
gemini: the key comes from GEMINI_API_KEY, or else from ~/.config/humanerror/gemini_api_key.
Needs Pillow and numpy. Sends each portrait to OpenAI (codex) or Google (Gemini)."""
import argparse
import base64
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.error
import urllib.request

import numpy as np
from PIL import Image, ImageChops

PEOPLE = os.path.join(os.path.dirname(__file__), "..", "Godot", "people")
API = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent"
BACKGROUND = (128, 128, 128)
UPSCALE = 4
PROMPT = (
    "This is a cut-out photo of a person, from the front, on a flat grey background. Draw the same "
    "person seen from directly behind: the back of their head, their hair or hat, the back of their "
    "clothes and arms. Keep the same pose, the same size and the same place in the frame, mirrored "
    "left to right as a view from behind is. Keep the photo's style, colours and lighting. Keep the "
    "flat grey background. No face, no text."
)


def ask_gemini(key, model, image):
    buffer = io.BytesIO()
    image.save(buffer, "PNG")
    body = {
        "contents": [{"parts": [
            {"text": PROMPT},
            {"inline_data": {"mime_type": "image/png", "data": base64.b64encode(buffer.getvalue()).decode()}},
        ]}],
        "generationConfig": {"responseModalities": ["TEXT", "IMAGE"]},
    }
    request = urllib.request.Request(API % model, data=json.dumps(body).encode(), method="POST",
                                     headers={"Content-Type": "application/json", "x-goog-api-key": key})
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            answer = json.load(response)
    except urllib.error.HTTPError as error:
        raise RuntimeError("Gemini refused (HTTP %d): %s" % (error.code, error.read().decode()[:400]))
    for candidate in answer.get("candidates", []):
        for part in candidate.get("content", {}).get("parts", []):
            data = part.get("inlineData") or part.get("inline_data")
            if data:
                return Image.open(io.BytesIO(base64.b64decode(data["data"]))).convert("RGB")
    raise RuntimeError("Gemini sent no image: %s" % json.dumps(answer)[:400])


def ask_codex(image, raw_dir, name):
    """Runs codex exec with its built-in image_gen tool, the portrait as -i, in an empty work folder,
    and takes the image that its session made (by the session id, never the newest file)."""
    work = tempfile.mkdtemp(prefix="portrait_back_")
    reference = os.path.join(work, "front.png")
    image.save(reference)
    prompt = ("Use the built-in image generation tool (image_gen). Make exactly ONE image. Do not write "
              "code to draw it. Do not copy or move files. The attached image is the reference. " + PROMPT)
    command = [shutil.which("codex") or "codex", "exec", "--skip-git-repo-check", "--ephemeral",
               "-s", "workspace-write", "-c", 'approval_policy="never"', "-c", 'model_reasoning_effort="low"',
               "-C", work, "-o", os.path.join(raw_dir, "%s.last.txt" % name), "--image=" + reference, "-"]
    run = subprocess.run(command, input=prompt, capture_output=True, text=True, timeout=600)
    output = run.stdout + run.stderr
    with open(os.path.join(raw_dir, "%s.codex.log" % name), "w") as log:
        log.write(output)
    found = re.search(r"session id:\s*([0-9a-f-]+)", output)
    if run.returncode != 0 or found is None:
        raise RuntimeError("codex exited %d without a session id; see %s.codex.log" % (run.returncode, name))
    folder = os.path.expanduser("~/.codex/generated_images/%s" % found.group(1))
    pictures = sorted(f for f in os.listdir(folder) if f.endswith(".png")) if os.path.isdir(folder) else []
    if not pictures:
        raise RuntimeError("codex session %s made no image in %s" % (found.group(1), folder))
    return Image.open(os.path.join(folder, pictures[-1])).convert("RGB")


def fit(image, size):
    """Scales and centre-crops image to exactly size, keeping its aspect."""
    scale = max(size[0] / image.width, size[1] / image.height)
    scaled = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    left = (scaled.width - size[0]) // 2
    top = (scaled.height - size[1]) // 2
    return scaled.crop((left, top, left + size[0], top + size[1]))


def figure_box(drawn):
    """The box around the drawn person: the pixels that are not the flat grey background."""
    rgb = drawn.convert("RGB")
    grey = Image.new("RGB", rgb.size, BACKGROUND)
    differs = ImageChops.difference(rgb, grey).convert("L").point(lambda v: 255 if v > 24 else 0)
    return differs.getbbox() or (0, 0, rgb.width, rgb.height), differs


def fit_to_outline(drawn, mask):
    """Scales the drawn person's box onto the outline's box, then fills what is still background
    inside the outline from the nearest drawn pixels, so no grey shows at the edge."""
    box, _ = figure_box(drawn)
    target = mask.getbbox()
    person = drawn.convert("RGB").crop(box).resize((target[2] - target[0], target[3] - target[1]), Image.LANCZOS)
    canvas = Image.new("RGB", mask.size, BACKGROUND)
    canvas.paste(person, target[:2])
    _, solid = figure_box(canvas)
    canvas = fill_from_neighbours(canvas, mask, solid)
    out = canvas.convert("RGBA")
    out.putalpha(mask)
    return out


def fill_from_neighbours(canvas, mask, solid, rounds=16):
    """Fills each pixel inside mask that solid does not cover with the average of its covered
    neighbours, one ring per round, so the drawn colours grow out to the outline."""
    colour = np.asarray(canvas, dtype=np.float32).copy()
    inside = np.asarray(mask) > 127
    known = np.asarray(solid) > 127
    for _ in range(rounds):
        holes = inside & ~known
        if not holes.any():
            break
        weight = known.astype(np.float32)
        total = np.zeros_like(colour)
        count = np.zeros_like(weight)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dy or dx:
                    total += np.roll(colour * weight[..., None], (dy, dx), axis=(0, 1))
                    count += np.roll(weight, (dy, dx), axis=(0, 1))
        edge = holes & (count > 0)
        colour[edge] = total[edge] / count[edge][:, None]
        known |= edge
    return Image.fromarray(colour.clip(0, 255).astype(np.uint8))


def mirrored_mask(alpha):
    """The front's outline mirrored about the middle of its opaque part, as the back sees it."""
    box = alpha.getbbox()
    centre = (box[0] + box[2] - 1) / 2.0
    out = Image.new("L", alpha.size, 0)
    pixels, src = out.load(), alpha.load()
    for y in range(alpha.height):
        for x in range(alpha.width):
            mx = round(2 * centre - x)
            if 0 <= mx < alpha.width:
                pixels[x, y] = src[mx, y]
    return out, centre


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw", required=True, help="folder for Gemini's raw answers")
    parser.add_argument("--backend", choices=["codex", "gemini"], default="codex")
    parser.add_argument("--model", default="gemini-2.5-flash-image", help="the Gemini model")
    parser.add_argument("--only", default="", help="comma-separated people to do")
    parser.add_argument("--force", action="store_true", help="ask again for people who have a back.png")
    parser.add_argument("--reuse-raw", action="store_true", help="cut the raw image in --raw again; ask for none")
    args = parser.parse_args()
    key = ""
    if args.backend == "gemini":
        key = os.environ.get("GEMINI_API_KEY", "")
        key_file = os.path.expanduser("~/.config/humanerror/gemini_api_key")
        if not key and os.path.isfile(key_file):
            with open(key_file) as f:
                key = f.read().strip()
        if not key:
            sys.exit("No Gemini key: set GEMINI_API_KEY or put the key in %s" % key_file)
    elif shutil.which("codex") is None:
        sys.exit("codex is not on the PATH; install and log in to the codex CLI, or use --backend gemini")
    os.makedirs(args.raw, exist_ok=True)
    names = sorted(n for n in os.listdir(PEOPLE) if os.path.isfile(os.path.join(PEOPLE, n, "portrait_neutral.png")))
    if args.only:
        names = [n for n in names if n in args.only.split(",")]
    failed = []
    for name in names:
        target = os.path.join(PEOPLE, name, "back.png")
        raw_path = os.path.join(args.raw, "%s_raw.png" % name)
        if os.path.exists(target) and not args.force and not args.reuse_raw:
            print("%s: has a back.png, skipped" % name)
            continue
        front = Image.open(os.path.join(PEOPLE, name, "portrait_neutral.png")).convert("RGBA")
        big = front.resize((front.width * UPSCALE, front.height * UPSCALE), Image.LANCZOS)
        flat = Image.new("RGB", big.size, BACKGROUND)
        flat.paste(big, mask=big.split()[3])
        if args.reuse_raw:
            if not os.path.exists(raw_path):
                print("%s: FAILED: no raw image %s to reuse" % (name, raw_path))
                failed.append(name)
                continue
            drawn = Image.open(raw_path).convert("RGB")
        else:
            try:
                drawn = ask_codex(flat, args.raw, name) if args.backend == "codex" else ask_gemini(key, args.model, flat)
            except (RuntimeError, urllib.error.URLError, subprocess.TimeoutExpired, OSError) as error:
                print("%s: FAILED: %s" % (name, error))
                failed.append(name)
                continue
            drawn.save(raw_path)
        mask, _ = mirrored_mask(front.split()[3].point(lambda v: 255 if v > 127 else 0))
        big_mask = mask.resize(big.size, Image.NEAREST)
        back = fit_to_outline(fit(drawn, big.size), big_mask).resize(front.size, Image.LANCZOS)
        back.putalpha(mask)
        back.save(target)
        print("%s: wrote %s" % (name, os.path.relpath(target)))
    if failed:
        sys.exit("failed: %s" % ", ".join(failed))


main()
