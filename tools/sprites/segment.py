import numpy as np
from scipy import ndimage

def runs(profile, min_gap):
    """Return [start, end) runs of truthy values separated by gaps >= min_gap."""
    idx = np.where(profile)[0]
    if idx.size == 0:
        return []
    out = []
    start = prev = idx[0]
    for i in idx[1:]:
        if i - prev > min_gap:
            out.append([start, prev + 1])
            start = i
        prev = i
    out.append([start, prev + 1])
    return out

def segment(alpha, row_gap=6, col_gap=8, min_width=28):
    rows = runs(alpha.sum(axis=1) > 0, row_gap)
    result = []
    for y0, y1 in rows:
        band = alpha[y0:y1]
        segs = runs(band.sum(axis=0) > 0, col_gap)
        # merge slivers (particles) into nearest neighbour
        merged = []
        for s in segs:
            if s[1] - s[0] < min_width and merged:
                merged[-1][1] = s[1]
            else:
                merged.append(list(s))
        # leading sliver merges forward
        if len(merged) > 1 and merged[0][1] - merged[0][0] < min_width:
            merged[1][0] = merged[0][0]
            merged.pop(0)
        frames = []
        for x0, x1 in merged:
            sub = band[:, x0:x1]
            ys = np.where(sub.any(axis=1))[0]
            frames.append((x0, y0 + ys[0], x1, y0 + ys[-1] + 1))
        result.append(frames)
    return result
