"""Prepares the Gemini source sheets for the game.

Input : assets/source/gemini/*.png (RGB, checkerboard baked in) + assets/gemini/hero.png
Output: assets/art/  (RGBA atlases, icons, UI textures) + assets/art/atlas.json

Run from the project root:  python tools/sprites/build_art.py
Requires Python 3 with numpy, scipy and Pillow.
"""
import colorsys
import json
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(__file__))
from keyout import key_out  # noqa: E402
from segment import segment  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "assets", "source", "gemini")
OUT = os.path.join(ROOT, "assets", "art")
MANIFEST = {"characters": {}, "relics": {}, "fx": {}, "ui": {}}


def load_rgb(name):
    return np.array(Image.open(os.path.join(SRC, name)).convert("RGB"))


def save(img, rel):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)
    return "res://assets/art/" + rel.replace(os.sep, "/")


def split_at_valley(alpha, box, lo, hi):
    """Split a merged segment at the emptiest column between lo and hi."""
    x0, y0, x1, y1 = box
    band = alpha[y0:y1]
    cols = band[:, lo:hi].sum(axis=0)
    cut = lo + int(np.argmin(cols))
    return [(x0, y0, cut, y1), (cut, y0, x1, y1)]


def tighten(alpha, box):
    x0, y0, x1, y1 = box
    sub = alpha[y0:y1, x0:x1]
    ys = np.where(sub.any(axis=1))[0]
    xs = np.where(sub.any(axis=0))[0]
    return (x0 + xs[0], y0 + ys[0], x0 + xs[-1] + 1, y0 + ys[-1] + 1)


def feet_x(alpha_crop):
    h = alpha_crop.shape[0]
    strip = max(3, int(h * 0.1))
    ys, xs = np.nonzero(alpha_crop[h - strip:])
    if xs.size == 0:
        return alpha_crop.shape[1] / 2
    return float(xs.mean())


def pack(frames, max_width=2048, pad=2):
    x = y = row_h = 0
    places = []
    for img in frames:
        w, h = img.size
        if x + w + pad > max_width:
            x = 0
            y += row_h + pad
            row_h = 0
        places.append((x, y))
        x += w + pad
        row_h = max(row_h, h)
    width = max(p[0] + f.size[0] for p, f in zip(places, frames))
    height = max(p[1] + f.size[1] for p, f in zip(places, frames))
    sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for (px, py), img in zip(places, frames):
        sheet.paste(img, (px, py))
    return sheet, places


def hue_shift(img, target_hue, sat_scale=1.0, min_sat=0.18):
    """Recolour saturated pixels to a new hue, keeping light and dark values."""
    arr = np.array(img).astype(np.float32) / 255.0
    rgb = arr[..., :3]
    out = rgb.copy()
    flat = rgb.reshape(-1, 3)
    res = out.reshape(-1, 3)
    for i, (r, g, b) in enumerate(flat):
        h, l, s = colorsys.rgb_to_hls(r, g, b)
        if s > min_sat and arr.reshape(-1, 4)[i, 3] > 0:
            res[i] = colorsys.hls_to_rgb(target_hue, l, min(1.0, s * sat_scale))
    arr[..., :3] = out
    return Image.fromarray((arr * 255).astype(np.uint8), "RGBA")


def build_character(key, rgba, alpha, rows, anims, flip, scale, fps):
    """rows: list of frame boxes per row; anims: name -> list of (row, index)."""
    frames, meta_frames = [], {}
    cache = {}
    baselines = [max(b[3] for b in row) for row in rows]
    for name, refs in anims.items():
        meta_frames[name] = []
        for row, index in refs:
            if (row, index) not in cache:
                box = tighten(alpha, rows[row][index])
                x0, y0, x1, y1 = box
                img = rgba.crop(box)
                a = alpha[y0:y1, x0:x1]
                px = feet_x(a)
                py = baselines[row] - y0
                if flip:
                    img = img.transpose(Image.FLIP_LEFT_RIGHT)
                    px = img.size[0] - px
                cache[(row, index)] = len(frames)
                frames.append((img, px, py))
            meta_frames[name].append(cache[(row, index)])
    sheet, places = pack([f[0] for f in frames])
    path = save(sheet, "characters/%s.png" % key)
    MANIFEST["characters"][key] = {
        "texture": path,
        "scale": scale,
        "frames": [[p[0], p[1], f[0].size[0], f[0].size[1], round(f[1], 1), round(f[2], 1)] for p, f in zip(places, frames)],
        "animations": {n: {"frames": idx, "fps": fps.get(n, 10), "loop": n in ("idle", "walk")} for n, idx in meta_frames.items()},
    }
    print("  %-9s %2d frames -> %s %s" % (key, len(frames), path, sheet.size))
    return sheet, frames


def keyed(name, **kw):
    rgb = load_rgb(name)
    alpha = key_out(rgb, **kw)
    rgba = Image.fromarray(np.dstack([rgb, alpha.astype(np.uint8) * 255]), "RGBA")
    return rgba, alpha


def characters():
    print("characters")
    # Hero: the user supplied a transparent high-resolution sheet.
    hero = Image.open(os.path.join(ROOT, "assets", "gemini", "hero.png")).convert("RGBA")
    harr = np.array(hero)
    halpha = harr[..., 3] > 40
    harr[..., 3] = np.where(halpha, harr[..., 3], 0)
    hero = Image.fromarray(harr, "RGBA")
    rows = segment(halpha)
    build_character("hero", hero, halpha, rows, {
        "idle": [(0, i) for i in range(8)],
        "walk": [(1, i) for i in range(8)],
        "attack": [(2, i) for i in range(7)],
        "hurt": [(3, 0), (3, 1), (3, 2)],
        "death": [(3, 3), (3, 4)],
    }, False, 0.78, {"idle": 7, "walk": 12, "attack": 22, "hurt": 10, "death": 4})

    slime, salpha = keyed("03_gelatina.png", grid_lines=True)
    srgb = load_rgb("03_gelatina.png").astype(np.int16)
    slum = srgb.mean(axis=2)
    grid_rows = [y for y in range(slum.shape[0]) if (slum[y] < 110).mean() > 0.85]
    grid_cols = [x for x in range(slum.shape[1]) if (slum[:, x] < 110).mean() > 0.85]
    # Grid lines: inpaint where the sprite continues on both sides, else clear.
    for y in grid_rows:
        for x in range(slum.shape[1]):
            up, down = max(0, y - 3), min(slum.shape[0] - 1, y + 3)
            if salpha[up, x] and salpha[down, x]:
                salpha[y, x] = True
                srgb[y, x] = (srgb[up, x] + srgb[down, x]) // 2
            else:
                salpha[y, x] = False
    for x in grid_cols:
        for y in range(slum.shape[0]):
            left, right = max(0, x - 3), min(slum.shape[1] - 1, x + 3)
            if salpha[y, left] and salpha[y, right]:
                salpha[y, x] = True
                srgb[y, x] = (srgb[y, left] + srgb[y, right]) // 2
            else:
                salpha[y, x] = False
    slime = Image.fromarray(np.dstack([srgb.astype(np.uint8), salpha.astype(np.uint8) * 255]), "RGBA")
    rows = segment(salpha)
    rows[3] = rows[3][:3] + split_at_valley(salpha, rows[3][3], 690, 760)
    build_character("slime", slime, salpha, rows, {
        "idle": [(0, i) for i in range(8)],
        "walk": [(1, i) for i in range(5)],
        "attack": [(2, i) for i in range(5)],
        "hurt": [(3, 2), (3, 0)],
        "death": [(3, 0), (3, 1), (3, 3), (3, 4)],
    }, True, 1.3, {"idle": 8, "walk": 10, "attack": 12, "hurt": 10, "death": 8})

    wisp, walpha = keyed("04_lucero.png")
    rows = segment(walpha)
    rows[2] = rows[2][:6] + split_at_valley(walpha, rows[2][6], 870, 905)
    build_character("wisp", wisp, walpha, rows, {
        "idle": [(0, i) for i in range(4)],
        "walk": [(0, i) for i in range(4, 8)],
        "attack": [(1, i) for i in range(8)],
        "hurt": [(2, 3), (2, 4)],
        "death": [(2, 5), (2, 6), (2, 7)],
    }, True, 1.25, {"idle": 7, "walk": 10, "attack": 14, "hurt": 10, "death": 7})
    # Companion: same spirit, recoloured to the mint of the bearer's core.
    idle = [wisp.crop(tighten(walpha, rows[0][i])) for i in range(4)]
    companion = [hue_shift(f, 0.44, 1.05) for f in idle]
    sheet, places = pack(companion)
    MANIFEST["characters"]["companion"] = {
        "texture": save(sheet, "characters/companion.png"),
        "scale": 0.42,
        "frames": [[p[0], p[1], f.size[0], f.size[1], f.size[0] / 2, f.size[1] / 2] for p, f in zip(places, companion)],
        "animations": {"idle": {"frames": [0, 1, 2, 3], "fps": 8, "loop": True}},
    }

    sentinel, centalpha = keyed("05_centinela.png", near_min=0.6, tone_tol=12)
    rows = segment(centalpha)
    build_character("sentinel", sentinel, centalpha, rows, {
        "idle": [(0, i) for i in range(4)],
        "walk": [(0, i) for i in range(4, 8)],
        "attack": [(1, i) for i in range(4)],
        "hurt": [(2, 0), (2, 1), (2, 2)],
        "death": [(2, 3), (2, 4)],
    }, True, 1.3, {"idle": 6, "walk": 9, "attack": 9, "hurt": 10, "death": 5})

    boss, balpha = keyed("06_rey_sin_brasa.png")
    rows = segment(balpha)
    a, b = split_at_valley(balpha, rows[1][1], 320, 370)
    c, d = split_at_valley(balpha, rows[1][2], 735, 790)
    rows[1] = [rows[1][0], a, b, c, d]
    build_character("boss", boss, balpha, rows, {
        "idle": [(0, i) for i in range(4)],
        "walk": [(0, i) for i in range(4, 8)],
        "attack": [(1, i) for i in range(5)],
        "hurt": [(2, 0), (2, 1), (2, 2)],
        "death": [(2, 3), (2, 4), (2, 5)],
    }, True, 1.45, {"idle": 6, "walk": 8, "attack": 8, "hurt": 9, "death": 5})


def relics():
    print("relics")
    rgb = load_rgb("10_reliquias.png")
    cells = [(5, 142), (153, 286), (294, 436), (444, 581), (591, 726), (738, 876), (882, 1020)]
    ids = ["fang", "clock", "eye", "heart", "coin", "ash", "storm"]
    for rid, (x0, x1) in zip(ids, cells):
        crop = rgb[6:118, x0 + 3:x1 - 3]
        # Pad with the board colour so the flood fill can enter from every side.
        alpha = key_out(crop, sat_max=22, margin=20, fringe=2, min_blob=30, near_min=0.7, tone_tol=12)
        labels, n = ndimage.label(alpha)
        if n > 1:
            sizes = ndimage.sum(alpha, labels, range(1, n + 1))
            keep = np.argmax(sizes) + 1
            near = ndimage.binary_dilation(labels == keep, iterations=10)
            alpha = alpha & np.isin(labels, [i for i in range(1, n + 1) if (near & (labels == i)).any()])
        img = Image.fromarray(np.dstack([crop, alpha.astype(np.uint8) * 255]), "RGBA")
        box = img.getbbox()
        img = img.crop(box)
        side = max(img.size) + 8
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(img, ((side - img.size[0]) // 2, (side - img.size[1]) // 2))
        MANIFEST["relics"][rid] = save(square, "relics/%s.png" % rid)
    print("  7 icons")


def effects():
    print("effects")
    rgb = load_rgb("11_efectos.png").astype(np.int16)
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    alpha = (sat > 48) | (lum > 190)
    alpha = ndimage.binary_opening(alpha, iterations=1) | ((sat > 90) & alpha)
    # soft alpha from saturation keeps pixel edges clean on dark stages
    names = ["slash", "critical", "magic", "embers"]
    bands = [(0, 256), (256, 512), (512, 768), (768, 1024)]
    for name, (y0, y1) in zip(names, bands):
        frames = []
        count = 3 if name == "slash" else 4
        width = 1024 / (3 if name == "slash" else 4)
        if name == "slash":
            cols = [(60, 200), (300, 470), (520, 760)]
        else:
            cols = [(int(i * width), int((i + 1) * width)) for i in range(count)]
        for x0, x1 in cols:
            a = alpha[y0:y1, x0:x1]
            img = Image.fromarray(np.dstack([rgb[y0:y1, x0:x1].astype(np.uint8), a.astype(np.uint8) * 255]), "RGBA")
            frames.append(img)
        # Centre every frame on a common canvas so animation stays anchored.
        side = max(max(f.size) for f in frames)
        canvas = []
        for f in frames:
            c = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            c.paste(f, ((side - f.size[0]) // 2, (side - f.size[1]) // 2))
            canvas.append(c)
        sheet = Image.new("RGBA", (side * len(canvas), side), (0, 0, 0, 0))
        for i, c in enumerate(canvas):
            sheet.paste(c, (i * side, 0))
        MANIFEST["fx"][name] = {"texture": save(sheet, "fx/%s.png" % name), "frames": len(canvas), "size": side}
    print("  4 effects")


def ui():
    """Panel and button textures cut from the interface reference."""
    print("ui")
    ref = load_rgb("01_referencia_interfaz.png").astype(np.int16)
    lum = ref.mean(axis=2)

    def outline_cut(x0, y0, x1, y1, thresh=40):
        """Keep the outlined object; drop surroundings outside its black outline."""
        crop = ref[y0:y1, x0:x1]
        l = lum[y0:y1, x0:x1]
        outline = l < thresh
        open_space = ~outline
        labels, _ = ndimage.label(open_space)
        border = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
        outside = np.isin(labels, border[border > 0])
        alpha = ~outside
        alpha = ndimage.binary_opening(alpha, iterations=1)
        labels, n = ndimage.label(alpha)
        sizes = ndimage.sum(alpha, labels, range(1, n + 1))
        alpha = labels == (np.argmax(sizes) + 1)
        return Image.fromarray(np.dstack([crop.astype(np.uint8), alpha.astype(np.uint8) * 255]), "RGBA")

    # Stone button: remove the word by joining the plain left and right thirds.
    # Stone button: keep both cracked ends and stretch one clean column between
    # the letters "L" and "I" so the word disappears.
    button = outline_cut(364, 379, 660, 497, thresh=28)
    w, h = button.size
    left = button.crop((0, 0, 68, h))
    right = button.crop((244, 0, w, h))
    arr = np.array(button)
    # Per-row median across the lettered span recovers the bare stone colour.
    span = arr[:, 70:228].astype(np.int16)
    median = np.zeros((h, 4), np.uint8)
    for y in range(h):
        row = span[y]
        plain = row[(row[:, 0] - row[:, 2] < 45) & (row[:, 3] > 0)]
        median[y] = np.median(plain if len(plain) else row, axis=0).astype(np.uint8)
    copper_rows = [y for y in range(h) if (arr[y, 40:60, 0].astype(int) - arr[y, 40:60, 2] > 45).mean() > 0.6]
    if copper_rows:
        top, bottom = copper_rows[0] + 3, copper_rows[-1] - 3
        lum = median[top:bottom, :3].astype(float).mean(axis=1)
        # Letters leave dark rims: rebuild the stone interior as a smooth ramp.
        smooth = ndimage.median_filter(median[top:bottom].astype(np.int16), size=(15, 1))
        median[top:bottom] = smooth.astype(np.uint8)
    # Keep the copper inner border, which the letters never cover.
    for y in range(h):
        edge = arr[y, 40:60].astype(np.int16)
        if (edge[:, 0] - edge[:, 2] > 45).mean() > 0.6:
            median[y] = np.median(edge, axis=0).astype(np.uint8)
    middle = Image.fromarray(np.repeat(median[:, None, :], 6, axis=1), "RGBA")
    joined = Image.new("RGBA", (68 + 6 + right.width, h), (0, 0, 0, 0))
    joined.paste(left, (0, 0))
    joined.paste(middle, (68, 0))
    joined.paste(right, (74, 0))
    half = joined.resize((joined.width // 2, joined.height // 2), Image.LANCZOS)
    MANIFEST["ui"]["button"] = {"texture": save(half, "ui/button.png"), "margin": [35, 18, half.width - 37, 19]}

    # Portrait of the wanderer and the inventory icons (opaque slots).
    portrait = Image.fromarray(ref[86:246, 276:432].astype(np.uint8), "RGB")
    MANIFEST["ui"]["keeper"] = save(portrait, "ui/keeper.png")
    slots = {"staff": (523, 97, 597, 171), "key": (607, 97, 681, 171), "lantern": (690, 97, 764, 171),
             "lantern_lit": (523, 183, 597, 257), "lantern_star": (607, 183, 681, 257)}
    for name, box in slots.items():
        MANIFEST["ui"][name] = save(Image.fromarray(ref[box[1]:box[3], box[0]:box[2]].astype(np.uint8), "RGB"), "ui/%s.png" % name)

    # Green shard for the ascuas currency.
    crop = ref[262:356, 228:480]
    l = crop.mean(axis=2)
    s = crop.max(axis=2) - crop.min(axis=2)
    alpha = ((s > 55) & (crop[..., 1] > crop[..., 0] + 30)) | (l < 34)
    green = (s > 55) & (crop[..., 1] > crop[..., 0] + 30)
    labels, n = ndimage.label(green)
    sizes = ndimage.sum(np.ones_like(l), labels, range(1, n + 1))
    biggest = int(np.argmax(sizes)) + 1
    shard = ndimage.binary_dilation(labels == biggest, iterations=3) & alpha
    img = Image.fromarray(np.dstack([crop.astype(np.uint8), shard.astype(np.uint8) * 255]), "RGBA")
    img = img.crop(img.getbbox())
    MANIFEST["ui"]["shard"] = save(img, "ui/shard.png")
    print("  button, keeper portrait, 5 item icons, shard")


if __name__ == "__main__":
    characters()
    relics()
    effects()
    ui()
    with open(os.path.join(OUT, "atlas.json"), "w", encoding="utf-8") as f:
        json.dump(MANIFEST, f, indent=1, default=lambda o: o.item() if hasattr(o, "item") else str(o))
    print("manifest written")
