"""Background removal for the Gemini sheets (checkerboard baked into RGB pixels).

The checkerboard is a pair of low-saturation gray tones. Every character has a dark
outline, so a flood fill from the sheet borders across checker-like pixels removes the
board without touching the gray armour inside the outline. Enclosed pockets of board
(e.g. between an arm and the body) are detected because they contain both checker tones.
"""
import numpy as np
from PIL import Image
from scipy import ndimage


def checker_tones(rgb):
    """Return the two dominant low-saturation tones of the sheet border."""
    border = np.concatenate([rgb[:12].reshape(-1, 3), rgb[-12:].reshape(-1, 3),
                             rgb[:, :12].reshape(-1, 3), rgb[:, -12:].reshape(-1, 3)])
    lum = border.mean(axis=1)
    sat = border.max(axis=1) - border.min(axis=1)
    lum = lum[sat < 24]
    hist, edges = np.histogram(lum, bins=64, range=(0, 256))
    peaks = np.argsort(-hist)
    first = peaks[0]
    second = next(p for p in peaks[1:] if abs(p - first) > 4)
    tones = sorted([(edges[first] + edges[first + 1]) / 2, (edges[second] + edges[second + 1]) / 2])
    return tones


def remove_white_pockets(background, lum, sat, hi_tone, margin, sat_max, max_size):
    """Drop small enclosed specks of the light tone that a lossy copy left behind.

    Only pockets ringed by the dark outline go; specks inside coloured glows or
    sparks keep their colour neighbours and stay.
    """
    bright = (sat <= sat_max) & (lum >= hi_tone - margin) & ~background
    pockets, count = ndimage.label(bright)
    for i, box in enumerate(ndimage.find_objects(pockets), start=1):
        if box is None:
            continue
        ys = slice(max(0, box[0].start - 3), box[0].stop + 3)
        xs = slice(max(0, box[1].start - 3), box[1].stop + 3)
        region = pockets[ys, xs] == i
        if region.sum() > max_size:
            continue
        ring = ndimage.binary_dilation(region, iterations=2) & ~region
        if sat[ys, xs][ring].mean() < 40:
            background[ys, xs] |= region
    return background


def key_out(rgb, sat_max=26, margin=24, grid_lines=False, fringe=2, min_blob=10,
            hole_min=40, keep_bright=False, tone_tol=9, near_min=0.85, white_pockets=0):
    rgb = rgb.astype(np.int16)
    lo_tone, hi_tone = checker_tones(rgb)
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    boardish = (sat <= sat_max) & (lum >= lo_tone - margin) & (lum <= hi_tone + margin)
    seeds = np.zeros_like(boardish)
    seeds[0, :] = seeds[-1, :] = True
    seeds[:, 0] = seeds[:, -1] = True
    passable = boardish.copy()
    if grid_lines:
        dark = (lum < lo_tone - margin) & (sat < 40)
        rows = dark.mean(axis=1) > 0.55
        cols = dark.mean(axis=0) > 0.55
        for y in np.where(rows)[0]:
            for d in (-2, -1, 0, 1, 2):
                if 0 <= y + d < rgb.shape[0]:
                    passable[y + d, :] |= (sat[y + d, :] < 40) & (lum[y + d, :] < hi_tone + margin)
        for x in np.where(cols)[0]:
            for d in (-2, -1, 0, 1, 2):
                if 0 <= x + d < rgb.shape[1]:
                    passable[:, x + d] |= (sat[:, x + d] < 40) & (lum[:, x + d] < hi_tone + margin)
    labels, n = ndimage.label(passable)
    touching = np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))
    background = np.isin(labels, touching[touching > 0])
    # Enclosed board pockets: both tones present in a sizeable component.
    pockets, count = ndimage.label(boardish & ~background)
    if count:
        idx = np.arange(1, count + 1)
        sizes = ndimage.sum(np.ones_like(lum), pockets, idx)
        mid = (lo_tone + hi_tone) / 2
        low_frac = ndimage.mean((lum < mid).astype(float), pockets, idx)
        near = (np.abs(lum - lo_tone) < tone_tol) | (np.abs(lum - hi_tone) < tone_tol)
        near_frac = ndimage.mean(near.astype(float), pockets, idx)
        for i, size, frac, nf in zip(idx, sizes, low_frac, near_frac):
            if size >= hole_min and 0.2 < frac < 0.8 and nf > near_min:
                background |= pockets == i
    # Fringe: blurred pixels between outline and board.
    for _ in range(fringe):
        edge = ndimage.binary_dilation(background) & ~background
        soft = (sat <= sat_max + 10) & (lum >= lo_tone - margin - 18)
        if keep_bright:
            soft &= lum <= hi_tone + margin
        background |= edge & soft
    if white_pockets:
        background = remove_white_pockets(background, lum, sat, hi_tone, margin, sat_max, white_pockets)
    alpha = ~background
    blobs, count = ndimage.label(alpha)
    if count:
        sizes = ndimage.sum(np.ones_like(lum), blobs, np.arange(1, count + 1))
        small = np.isin(blobs, np.where(sizes < min_blob)[0] + 1)
        alpha &= ~small
    return alpha


def rgba(rgb, alpha):
    out = np.dstack([rgb.astype(np.uint8), (alpha * 255).astype(np.uint8)])
    return Image.fromarray(out, "RGBA")


def preview(img, path, bg=(30, 36, 48)):
    base = Image.new("RGBA", img.size, bg + (255,))
    base.alpha_composite(img)
    base.convert("RGB").save(path)
