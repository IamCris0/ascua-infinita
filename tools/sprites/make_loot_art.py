"""Pixel art for the map, chests and the Rueda del eclipse (0.7).

Run from the project root:  python tools/sprites/make_loot_art.py
Requires Pillow. Every sprite is drawn here pixel by pixel and outlined
automatically, then stored at 4x so the game can show it at any size.

Outputs:
  assets/art/loot/map_icons.png   ten 16 px icons in a row (see ICONS)
  assets/art/loot/chests.png      3 tiers x (closed, open), 40 x 34 px cells
  assets/art/loot/items.png       nine equipment pieces and the shard (see ITEMS)
"""
import math
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "art", "loot")
SCALE = 4

PALETTE = {
    "k": (18, 14, 20), "w": (244, 239, 230), "s": (185, 194, 204), "S": (111, 122, 136),
    "b": (150, 98, 52), "B": (92, 56, 26), "d": (61, 36, 18), "g": (242, 196, 124), "G": (184, 134, 47),
    "r": (224, 100, 90), "R": (140, 47, 47), "o": (255, 154, 74), "O": (196, 92, 34), "y": (255, 231, 168),
    "t": (127, 224, 191), "T": (47, 143, 116), "p": (177, 140, 240), "P": (91, 63, 143), "q": (46, 30, 74),
    "c": (217, 207, 192), "C": (154, 143, 128), "n": (58, 47, 42), "e": (111, 207, 126), "E": (47, 120, 70),
}


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [["." for _ in range(w)] for _ in range(h)]

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return "."

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            self.set(x0, y0, c)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    def disc(self, cx, cy, r, c):
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r + r * 0.6:
                    self.set(x, y, c)

    def ring(self, cx, cy, r, c):
        for y in range(cy - r - 1, cy + r + 2):
            for x in range(cx - r - 1, cx + r + 2):
                d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
                if abs(d - r) < 0.6:
                    self.set(x, y, c)

    def rows(self, x0, y0, art):
        for j, row in enumerate(art):
            for i, ch in enumerate(row):
                if ch != ".":
                    self.set(x0 + i, y0 + j, ch)

    def outline(self, c="k"):
        filled = [[self.px[y][x] != "." for x in range(self.w)] for y in range(self.h)]
        for y in range(self.h):
            for x in range(self.w):
                if filled[y][x]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and filled[ny][nx]:
                        self.px[y][x] = c
                        break

    def image(self):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                ch = self.px[y][x]
                if ch != ".":
                    img.putpixel((x, y), PALETTE[ch] + (255,))
        return img


# ---------------------------------------------------------------- map icons
def icon_fight():
    c = Canvas(16, 16)
    for t in range(9):  # blade, tip at the top right
        c.set(13 - t, 1 + t, "w")
        c.set(14 - t, 1 + t, "S")
    c.set(14, 1, "w")
    c.line(2, 8, 6, 12, "G")  # crossguard
    c.line(3, 8, 7, 12, "g")
    c.line(3, 11, 1, 13, "b")  # grip
    c.line(4, 11, 2, 13, "B")
    c.set(1, 14, "g")
    c.outline()
    return c


def icon_elite():
    c = Canvas(16, 16)
    c.rows(1, 1, [
        "r............r",
        "Rr..........rR",
        ".Rr........rR.",
        "..Rcccccccc R..".replace(" ", "c")[:14],
    ])
    c.rows(3, 3, [
        "cccccccccc",
        "cccccccccc",
        "cdddccdddc",
        "cdrdccdrdc",
        "cdddccdddc",
        "ccccdcccCc",
        ".cCcccccC.",
        ".cdcdcdcd.",
        "..CcCcCc..",
    ])
    c.outline()
    return c


def icon_rest():
    c = Canvas(16, 16)
    c.rows(4, 1, [
        "...y....",
        "...yo...",
        "..oyo...",
        "..oyyo..",
        ".ooyyoo.",
        ".oyyyyo.",
        "ooyyyyoo",
        ".ooyyoo.",
    ])
    c.line(2, 12, 13, 9, "b")
    c.line(2, 13, 13, 10, "B")
    c.line(2, 9, 13, 12, "b")
    c.line(2, 10, 13, 13, "B")
    c.outline()
    return c


def icon_chest():
    c = Canvas(16, 16)
    c.rect(2, 4, 13, 7, "b")
    c.rect(3, 3, 12, 3, "b")
    c.rect(2, 8, 13, 13, "B")
    c.rect(2, 8, 13, 8, "d")
    for x in (4, 11):
        c.rect(x, 3, x, 13, "S")
    c.rect(7, 6, 8, 10, "g")
    c.set(7, 9, "d")
    c.set(8, 9, "d")
    c.rect(3, 4, 12, 4, "o")
    c.outline()
    return c


def icon_shrine():
    c = Canvas(16, 16)
    c.rows(5, 1, [
        "..y...",
        ".yoy..",
        ".oyo..",
        "oyyyo.",
        "ooyoo.",
    ])
    c.rect(3, 6, 12, 7, "s")
    c.rect(4, 8, 11, 12, "S")
    c.rect(6, 8, 9, 12, "s")
    c.rect(2, 13, 13, 14, "C")
    c.outline()
    return c


def icon_merchant():
    c = Canvas(16, 16)
    c.rows(2, 1, [
        "....BBBB....",
        ".....dd.....",
        "....bbbb....",
        "..bbbbbbbb..",
        ".bbbbBbbbbb.",
        "bbbbBgGbbbbB",
        "bbbBgggGbbbB",
        "bbbbBgGbbbBB",
        "bbbbbBbbbbBB",
        ".bbbbbbbbBB.",
        "..BBBBBBBB..",
    ])
    c.set(13, 2, "g")
    c.set(14, 3, "y")
    c.outline()
    return c


def icon_altar():
    c = Canvas(16, 16)
    c.rows(2, 2, [
        "....PPPP....",
        "..PPppppPP..",
        ".Ppp.yy.ppP.",
        "Ppp.yrry.ppP",
        "Ppp.yrry.ppP",
        ".Ppp.yy.ppP.",
        "..PPppppPP..",
        "....PPPP....",
    ])
    c.rect(3, 11, 12, 12, "C")
    c.rect(2, 13, 13, 14, "n")
    c.outline()
    return c


def icon_wheel():
    c = Canvas(16, 16)
    colors = ["g", "R"]
    for y in range(16):
        for x in range(16):
            dx, dy = x - 7.5, y - 7.5
            d = (dx * dx + dy * dy) ** 0.5
            if d <= 6.6:
                a = (math.atan2(dy, dx) + math.pi) / (2 * math.pi)
                c.set(x, y, colors[int(a * 8) % 2])
    c.ring(7, 7, 6, "B")
    c.disc(7, 7, 1, "y")
    c.rows(6, 0, ["yyy", ".y."])
    c.outline()
    return c


def icon_star():
    c = Canvas(16, 16)
    c.rows(1, 1, [
        "......g.......",
        "......g.......",
        ".....ggg......",
        ".....gyg......",
        "gggggyyygggggg"[:13],
        ".GgggyyyggggG.",
        "..GggyyyggG...",
        "...GgggggG....",
        "...GggGggG....",
        "..GgG...GgG...",
        "..GG.....GG...",
    ])
    c.outline()
    return c


def icon_crown():
    c = Canvas(16, 16)
    c.rows(1, 3, [
        "g.....g.....g.",
        "gg...ggg...gg.",
        "ggg.ggrgg.ggg.",
        "gggggggggggggG",
        "gGgggggggggGgG",
        "gggrgggtgggrgG",
        "GGGGGGGGGGGGGG",
    ])
    c.outline()
    return c


ICONS = [icon_fight, icon_elite, icon_rest, icon_chest, icon_shrine, icon_merchant, icon_altar, icon_wheel, icon_star, icon_crown]


# ---------------------------------------------------------------- equipment (0.8)
def item_ash_sword():
    c = Canvas(16, 16)
    for t in range(10):  # blade with a glowing ember edge
        c.set(13 - t, 1 + t, "c")
        c.set(14 - t, 1 + t, "o")
    c.set(14, 1, "y")
    c.line(1, 9, 5, 13, "n")
    c.line(2, 9, 6, 13, "C")
    c.line(2, 12, 1, 13, "B")
    c.set(0, 14, "o")
    c.outline()
    return c


def item_comet_blade():
    c = Canvas(16, 16)
    c.rows(2, 1, [
        "..........y.",
        ".........yty",
        "........tt.y",
        ".......tw...",
        "......tw....",
        ".....tw.....",
        "....tw......",
        "...Ttw......",
        "..TTt.......",
        ".gGT........",
        "gGg.........",
        ".b..........",
        "b...........",
    ])
    c.outline()
    return c


def item_rune_spear():
    c = Canvas(16, 16)
    c.rows(6, 0, [
        "..p.",
        ".ppP",
        ".pyP",
        "ppyP",
        ".pPP",
        "..P.",
    ])
    for y in range(6, 16):
        c.set(7, y, "b")
        c.set(8, y, "B")
    c.rect(6, 6, 9, 6, "g")
    c.set(7, 10, "p")
    c.set(8, 12, "p")
    c.outline()
    return c


def item_wisp_lantern():
    c = Canvas(16, 16)
    c.rows(3, 0, [
        "....SS....",
        "...S..S...",
        "..SSSSSS..",
        "..S.tt.S..",
        ".S.tTwt.S.",
        ".S.twwt.S.",
        ".S.tTTt.S.",
        ".S..tt..S.",
        "..SSSSSS..",
        "...SggS...",
        "...SSSS...",
    ])
    c.outline()
    return c


def item_black_hourglass():
    c = Canvas(16, 16)
    c.rows(3, 1, [
        "gggggggggg",
        ".GnnnnnnG.",
        ".Gn.yy.nG.",
        "..Gnyyn G.".replace(" ", "G")[:10],
        "...Gnn G..".replace(" ", "G")[:10],
        "....yy....",
        "...Gnn G..".replace(" ", "G")[:10],
        "..Gn.. nG.".replace(" ", "n")[:10],
        ".Gn.yy.nG.",
        ".GnyyyynG.",
        ".Gnyyyyng.",
        "gggggggggg",
    ])
    c.outline()
    return c


def item_silver_bell():
    c = Canvas(16, 16)
    c.rows(3, 1, [
        "....SS....",
        "...SwsS...",
        "..SwssS...",
        "..SwssSS..",
        ".SwsssSS..",
        ".SwsssSS..",
        ".SwssssS..",
        "SwsssssSS.",
        "SSSSSSSSS.",
        "....gg....",
        "....gG....",
    ])
    c.outline()
    return c


def item_moss_charm():
    c = Canvas(16, 16)
    c.line(3, 0, 7, 5, "C")
    c.line(12, 0, 8, 5, "C")
    c.disc(8, 10, 4, "E")
    c.disc(8, 10, 3, "e")
    c.disc(7, 9, 1, "y")
    c.rect(7, 5, 8, 6, "g")
    c.outline()
    return c


def item_split_coin():
    c = Canvas(16, 16)
    c.disc(7, 8, 6, "G")
    c.disc(7, 8, 5, "g")
    c.ring(7, 8, 3, "G")
    c.rect(6, 6, 8, 10, "y")
    # A jagged crack splits the coin in two.
    for x, y in ((8, 2), (7, 3), (8, 4), (9, 5), (8, 6), (7, 7), (8, 8), (9, 9), (8, 10), (7, 11), (8, 12), (9, 13), (8, 14)):
        c.set(x, y, "d")
    c.outline()
    return c


def item_forge_scale():
    c = Canvas(16, 16)
    c.rows(2, 1, [
        "....OOOO....",
        "..OOooooOO..",
        ".OooyyyyooO.",
        ".OoyyooyyoO.",
        "OooyoOOoyooO",
        "OooOOooOOooO",
        "OoOooooooOoO",
        ".OoooyyoooO.",
        ".OOooyyooOO.",
        "..OOooooOO..",
        "...OOooOO...",
        ".....OO.....",
    ])
    c.outline()
    return c


def item_scrap():
    c = Canvas(16, 16)
    c.rows(1, 1, [
        ".....w........",
        "....wsS.......",
        "....wsS.......",
        "...wssSS......",
        "...wssSS...w..",
        "..wsssSS..wsS.",
        "..wssSSS..wsS.",
        "..SSSSSS.wssSS",
        ".w.......wssSS",
        "wsS......SSSSS",
        "wssS..........",
        "SSSS..........",
    ])
    c.outline()
    return c


ITEMS = [item_ash_sword, item_comet_blade, item_rune_spear, item_wisp_lantern, item_black_hourglass,
         item_silver_bell, item_moss_charm, item_split_coin, item_forge_scale, item_scrap]


# ---------------------------------------------------------------- chests
TIERS = [
    # body light, body dark, plank line, band light, band dark, lock, lock dark, inner glow
    {"body": "b", "dark": "B", "plank": "d", "band": "s", "band_dark": "S", "lock": "g", "lock_dark": "G", "glow": "y"},
    {"body": "s", "dark": "S", "plank": "C", "band": "g", "band_dark": "G", "lock": "y", "lock_dark": "G", "glow": "y"},
    {"body": "P", "dark": "q", "plank": "q", "band": "t", "band_dark": "T", "lock": "y", "lock_dark": "g", "glow": "t"},
]
CHEST_W, CHEST_H = 40, 34


def chest(tier, opened):
    p = TIERS[tier]
    c = Canvas(CHEST_W, CHEST_H)
    top = 15  # first row of the body
    # Body with planks and side shading.
    c.rect(3, top, 36, 32, p["body"])
    c.rect(30, top, 36, 32, p["dark"])
    for y in (top + 5, top + 10, top + 15):
        c.rect(3, y, 36, y, p["plank"])
    c.rect(3, 31, 36, 32, p["dark"])
    if not opened:
        # Rounded lid.
        c.rect(5, 4, 34, 4, p["body"])
        c.rect(4, 5, 35, 5, p["body"])
        c.rect(3, 6, 36, top - 1, p["body"])
        c.rect(30, 5, 35, top - 1, p["dark"])
        c.rect(5, 5, 28, 5, "w" if tier == 1 else p["lock"] if tier == 2 else "o")
        c.rect(3, top - 1, 36, top - 1, p["plank"])
        c.rect(3, 10, 36, 10, p["plank"])
    else:
        # Lid thrown back, seen from inside, and the glow of the loot.
        c.rect(5, 0, 34, 1, p["dark"])
        c.rect(4, 2, 35, 8, p["dark"])
        c.rect(6, 3, 33, 7, p["plank"])
        c.rect(4, 9, 35, 10, p["band_dark"])
        c.rect(5, 11, 34, top - 1, p["glow"])
        c.rect(9, 12, 30, top - 1, "w")
    # Metal bands and their rivets.
    for x0 in (8, 29):
        y0 = 9 if opened else 4
        c.rect(x0, y0, x0 + 2, 32, p["band"])
        c.rect(x0 + 2, y0, x0 + 2, 32, p["band_dark"])
        for y in (top + 2, top + 12):
            c.set(x0 + 1, y, "w")
    c.rect(3, top, 36, top, p["band"])
    # Lock plate with its keyhole.
    ly = top - 3
    c.rect(17, ly, 22, ly + 7, p["lock"])
    c.rect(22, ly, 22, ly + 7, p["lock_dark"])
    c.rect(19, ly + 2, 20, ly + 3, "k")
    c.rect(19, ly + 4, 19, ly + 5, "k")
    if tier == 2:
        # Eclipse runes glow on the body.
        for x, y in ((6, top + 7), (13, top + 3), (25, top + 8), (33, top + 3), (14, top + 12), (24, top + 13)):
            c.set(x, y, "t")
            c.set(x + 1, y, "p")
    c.outline()
    return c


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    img = img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)
    img.save(os.path.join(OUT, name))
    print("%s: %d x %d" % (name, img.width, img.height))


if __name__ == "__main__":
    sheet = Image.new("RGBA", (16 * len(ICONS), 16), (0, 0, 0, 0))
    for i, fn in enumerate(ICONS):
        sheet.paste(fn().image(), (16 * i, 0))
    save(sheet, "map_icons.png")
    sheet = Image.new("RGBA", (CHEST_W * 2, CHEST_H * 3), (0, 0, 0, 0))
    for tier in range(3):
        for opened in (0, 1):
            sheet.paste(chest(tier, opened).image(), (CHEST_W * opened, CHEST_H * tier))
    save(sheet, "chests.png")
    sheet = Image.new("RGBA", (16 * len(ITEMS), 16), (0, 0, 0, 0))
    for i, fn in enumerate(ITEMS):
        sheet.paste(fn().image(), (16 * i, 0))
    save(sheet, "items.png")
