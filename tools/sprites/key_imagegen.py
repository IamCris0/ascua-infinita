"""Prepares the ImageGen art received on 7 October 2026 for the game.

Input : assets/source/imagegen/  copies exactly as received: four RGB sheets with
        a checkerboard baked into the pixels, the Campanera v2 with real alpha and
        the shrine/altar illustration (JPG with a dark background and grid lines).
Output: assets/art/imagegen/final/  RGBA sheets for the merchant, acolyte,
        guardian and Forjador, regions.json with one drawing region and pivot
        per pose, and events-v1.png with the eight shrine/altar states as
        framed 360 x 360 illustrations. The Campanera v2 copy is kept as a
        source only; the game uses bell-v1.png.

Run from the project root:  python tools/sprites/key_imagegen.py
Requires Python 3 with numpy, scipy and Pillow. Regions and pivots are then
registered by tools/import_imagegen.gd.
"""
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from keyout import key_out, rgba  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "source", "imagegen")
OUT = os.path.join(ROOT, "assets", "art", "imagegen", "final")
# Lossy copies blur the two board tones, so pockets are matched more loosely
# than in the Gemini sheets and enclosed white specks are dropped.
KEY = {"tone_tol": 16, "near_min": 0.55, "hole_min": 10, "white_pockets": 400}
SHEETS = ["forge-v1", "guardian-v1", "acolyte-v1", "merchant-v1"]
EVENT_CELL = 360


def key_sheets():
    for name in SHEETS:
        rgb = np.array(Image.open(os.path.join(SRC, name + ".webp")).convert("RGB"))
        alpha = key_out(rgb, **KEY)
        rgba(rgb, alpha).save(os.path.join(OUT, name + ".png"), optimize=True)
        print("%s: %.1f%% opaque" % (name, alpha.mean() * 100))


def pose_regions(alpha, rows, cols, cell_w, cell_h):
    """One drawing region per pose, ordered row by row.

    Each cell's largest component is its pose; every other spark, droplet or
    ring joins the nearest pose of its own row. Where two neighbouring regions
    still overlap they are split at the middle of the overlap, so no region
    draws pixels of another pose.
    """
    labels, count = ndimage.label(alpha, structure=np.ones((3, 3)))
    index = range(1, count + 1)
    boxes = ndimage.find_objects(labels)
    sizes = ndimage.sum(alpha, labels, index)
    centres = ndimage.center_of_mass(alpha, labels, index)
    best = {}
    for i in range(count):
        cell = (int(centres[i][0] // cell_h), int(centres[i][1] // cell_w))
        if cell not in best or sizes[i] > sizes[best[cell]]:
            best[cell] = i
    missing = [(r, c) for r in range(rows) for c in range(cols) if (r, c) not in best]
    if missing:
        raise ValueError("cells without a pose: %s" % missing)
    ordered = [best[(r, c)] for r in range(rows) for c in range(cols)]
    rects = [[boxes[i][1].start, boxes[i][0].start, boxes[i][1].stop, boxes[i][0].stop] for i in ordered]
    # Rows of poses rarely sit exactly on the grid: a mote belongs to the row
    # whose bodies span its height, or the nearest one.
    bands = [(min(r[1] for r in rects[k * cols:(k + 1) * cols]), max(r[3] for r in rects[k * cols:(k + 1) * cols])) for k in range(rows)]
    for i in range(count):
        if i in ordered:
            continue
        cy, cx = centres[i]
        row = min(range(rows), key=lambda k: max(bands[k][0] - cy, 0, cy - bands[k][1]))
        k = min(range(row * cols, (row + 1) * cols), key=lambda k: (centres[ordered[k]][0] - cy) ** 2 + (centres[ordered[k]][1] - cx) ** 2)
        r = rects[k]
        r[0], r[1] = min(r[0], boxes[i][1].start), min(r[1], boxes[i][0].start)
        r[2], r[3] = max(r[2], boxes[i][1].stop), max(r[3], boxes[i][0].stop)
    for a in range(len(rects)):
        for b in range(a + 1, len(rects)):
            ra, rb = rects[a], rects[b]
            if ra[0] < rb[2] and rb[0] < ra[2] and ra[1] < rb[3] and rb[1] < ra[3]:
                if a // cols == b // cols:
                    cut = (max(ra[0], rb[0]) + min(ra[2], rb[2])) // 2
                    left, right = (ra, rb) if ra[0] < rb[0] else (rb, ra)
                    left[2], right[0] = cut, cut
                else:
                    cut = (max(ra[1], rb[1]) + min(ra[3], rb[3])) // 2
                    top, bottom = (ra, rb) if ra[1] < rb[1] else (rb, ra)
                    top[3], bottom[1] = cut, cut
    return rects


# Poses that share a ground line: each row, except the last, whose first three
# poses are the hurt reaction and the last three the death.
GROUPS = [range(0, 6), range(6, 12), range(12, 18), range(18, 21), range(21, 24)]


def sheet_layout(name, cell=256):
    """Regions with the cell anchor as pivot: x centre of the cell, y at the
    median lowest pixel of its group (the ground line shared by those poses)."""
    alpha = np.array(Image.open(os.path.join(OUT, name + ".png")))[:, :, 3] > 0
    rects = pose_regions(alpha, 4, 6, cell, cell)
    frames = [None] * len(rects)
    for group in GROUPS:
        foot = int(np.median([rects[i][3] for i in group])) - 1
        for i in group:
            x0, y0, x1, y1 = rects[i]
            frames[i] = [x0, y0, x1 - x0, y1 - y0, (i % 6) * cell + cell // 2 - x0, foot - y0]
    return frames


def merchant_layout():
    """Four idle poses on the first row and the bust portrait below."""
    alpha = np.array(Image.open(os.path.join(OUT, "merchant-v1.png")))[:, :, 3] > 0
    rects = pose_regions(alpha[:480], 1, 4, alpha.shape[1] // 4, 480)
    frames = []
    for r in rects:
        x0, y0, x1, y1 = r
        feet = alpha[y1 - 12:y1, x0:x1]
        centre = x0 + int(np.mean(np.where(feet)[1]))
        frames.append([x0, y0, x1 - x0, y1 - y0, centre - x0, y1 - 1 - y0])
    ys, xs = np.where(alpha[480:])
    return frames, [int(xs.min()), int(ys.min()) + 480, int(xs.max() - xs.min()) + 1, int(ys.max() - ys.min()) + 1]


def regions():
    data = {}
    heights = {"forge": 215.0, "guardian": 175.0, "acolyte": 135.0}
    for key, height in heights.items():
        data[key] = {"texture": "res://assets/art/imagegen/final/%s-v1.png" % key, "height": height, "frames": sheet_layout(key + "-v1")}
    frames, portrait = merchant_layout()
    data["merchant"] = {"texture": "res://assets/art/imagegen/final/merchant-v1.png", "height": 150.0, "frames": frames, "portrait": portrait}
    with open(os.path.join(OUT, "regions.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent="\t")
        f.write("\n")


def erase_grid(rgb):
    """Paint the thin grid and floor lines with the background around them.

    Line pixels are greyish, lighter than the dark board and have dark board on
    both sides across the line; sparks are saturated and objects are not thin.
    """
    a = rgb.astype(np.int16)
    lum = a.mean(axis=2)
    sat = a.max(axis=2) - a.min(axis=2)
    dark = lum < 36
    out = a.copy()
    for axis in (0, 1):
        before = np.roll(dark, 4, axis)
        after = np.roll(dark, -4, axis)
        thin = (lum >= 36) & (sat < 30) & before & after
        # Only whole lines, not isolated grey pixels.
        share = thin.mean(axis=1 - axis)
        lines = share > 0.3
        mask = thin & (lines[:, None] if axis == 0 else lines[None, :])
        fill = (np.roll(a, 4, axis) + np.roll(a, -4, axis)) // 2
        out[mask] = fill[mask]
    return out.astype(np.uint8), lines


def cell_bounds(lum, axis, count):
    """Cells between the bright separator lines along one axis."""
    profile = (lum > 50).mean(axis=1 - axis)
    lines = np.where(profile > 0.6)[0]
    size = lum.shape[axis]
    cuts = [0]
    for i in lines:
        if i - cuts[-1] > 8:
            cuts.append(int(i))
    if size - cuts[-1] > 8:
        cuts.append(size)
    if len(cuts) != count + 1:
        cuts = [round(i * size / count) for i in range(count + 1)]
    return cuts


def events():
    rgb = np.array(Image.open(os.path.join(SRC, "shrine-altar-v1.jpg")).convert("RGB"))
    lum = rgb.astype(np.int16).mean(axis=2)
    xs = cell_bounds(lum, 1, 4)
    ys = cell_bounds(lum, 0, 2)
    clean, _ = erase_grid(rgb)
    sheet = Image.new("RGB", (EVENT_CELL * 4, EVENT_CELL * 2))
    for row in range(2):
        for col in range(4):
            box = (xs[col] + 8, ys[row] + 8, xs[col + 1] - 8, ys[row + 1] - 8)
            cell = Image.fromarray(clean).crop(box).resize((EVENT_CELL, EVENT_CELL), Image.LANCZOS)
            sheet.paste(cell, (col * EVENT_CELL, row * EVENT_CELL))
    sheet.save(os.path.join(OUT, "events-v1.png"), optimize=True)
    print("events: columns %s rows %s" % (xs, ys))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    key_sheets()
    regions()
    events()
