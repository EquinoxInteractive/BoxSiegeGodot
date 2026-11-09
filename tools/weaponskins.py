"""Skin senjata: 5 per senjata (smith, kurval, flamer, scream, pistol, knife) = 30 skin.
Dibuat dari sprite p1 (aksen merah) dengan memetakan ulang warna badan & aksen + pola."""
import numpy as np, math, random, colorsys
from PIL import Image, ImageDraw
import cv2
from artlib import *

def accent_stops(c, light=0.55):
    c = np.array(c, np.float32)
    return [(0.0, tuple(c * 0.18)), (0.45, tuple(c * 0.85)), (0.7, tuple(c)), (1.0, tuple(np.clip(c + (1 - c) * light, 0, 1)))]

BODY = {
    "gold":     [(0, "2b1a00"), (0.3, "8a5a08"), (0.6, "e0a21c"), (0.85, "ffe27a"), (1, "fffbe6")],
    "obsidian": [(0, "030308"), (0.3, "1b1d2e"), (0.65, "4a4f6e"), (0.9, "b4bad6"), (1, "f2f4ff")],
    "frost":    [(0, "0c2447"), (0.35, "3f86c9"), (0.7, "b6e4ff"), (1, "ffffff")],
    "magma":    [(0, "070303"), (0.3, "2a1512"), (0.65, "6a3a28"), (0.9, "c0825a"), (1, "ffe0c0")],
    "toxic":    [(0, "050c04"), (0.3, "1f4a16"), (0.65, "5fa02c"), (0.9, "c4f07a"), (1, "f4ffd0")],
    "royal":    [(0, "10041f"), (0.3, "4a1f80"), (0.65, "9a62da"), (0.9, "e2ccff"), (1, "ffffff")],
    "sakura":   [(0, "3a1030"), (0.35, "c9578a"), (0.7, "ffb3cc"), (1, "fff7fa")],
    "camo":     [(0, "060a04"), (0.5, "808080"), (1, "ffffff")],
    "carbon":   [(0, "020202"), (0.4, "262830"), (0.75, "6c7080"), (1, "dde2f0")],
    "cosmic":   [(0, "04001a"), (0.3, "26105e"), (0.65, "6a2fb8"), (0.9, "7fe0ff"), (1, "ffffff")],
    "silver":   [(0, "0a0b10"), (0.35, "50566a"), (0.7, "c8cfe0"), (1, "ffffff")],
    "sand":     [(0, "0a0804"), (0.5, "808080"), (1, "ffffff")],
    "void":     [(0, "010005"), (0.3, "140a2a"), (0.65, "4a2a8a"), (0.9, "b88cff"), (1, "f4eaff")],
    "storm":    [(0, "04081a"), (0.3, "1a3470"), (0.65, "5a9aea"), (0.9, "d0f0ff"), (1, "ffffff")],
    "dragon":   [(0, "021a0e"), (0.3, "0e5a30"), (0.65, "2fb060"), (0.9, "b8f0a0"), (1, "f4ffe8")],
    "cyber":    [(0, "050510"), (0.3, "1a1840"), (0.65, "4a3a9a"), (0.9, "a8a0ff"), (1, "ffffff")],
    "crystal":  [(0, "0a1a3a"), (0.3, "3a70c0"), (0.65, "9ad8ff"), (0.9, "e8faff"), (1, "ffffff")],
    "holy":     [(0, "2a2208"), (0.3, "9a8a3a"), (0.65, "f4e8a8"), (0.9, "fffbe8"), (1, "ffffff")],
    "blossom":  [(0, "2a0a24"), (0.35, "b0487a"), (0.7, "ffc2dc"), (1, "ffffff")],
    "nova":     [(0, "02000e"), (0.3, "1a1060"), (0.6, "5a30c8"), (0.85, "60e0ff"), (1, "ffffff")],
    "venom":    [(0, "040a02"), (0.3, "20401a"), (0.65, "78c030"), (0.9, "d8ff70"), (1, "faffe0")],
    "jackpot":  [(0, "2a1400"), (0.3, "a0640a"), (0.6, "ffc018"), (0.85, "fff08a"), (1, "ffffff")],
    "prismw":   [(0, "0a0b10"), (0.35, "505a7a"), (0.7, "d0daf0"), (1, "ffffff")],
    # ---- palet untuk 30 skin finisher baru
    "basalt":   [(0, "030203"), (0.35, "15100f"), (0.7, "3a2e2c"), (0.92, "7a6660"), (1, "d8c0b0")],
    "tide":     [(0, "031030"), (0.3, "0c3a86"), (0.65, "2f86e0"), (0.9, "b4e4ff"), (1, "ffffff")],
    "abyss":    [(0, "00131a"), (0.3, "06424f"), (0.65, "1aa0a8"), (0.9, "8af4e8"), (1, "eafffb")],
    "aqua":     [(0, "002a30"), (0.3, "06788a"), (0.65, "3ae0e0"), (0.9, "c8fff8"), (1, "ffffff")],
    "reaper":   [(0, "04080a"), (0.3, "14281f"), (0.65, "3a6a56"), (0.9, "a8f0cc"), (1, "f0fff8")],
    "wraith":   [(0, "04040e"), (0.3, "1a1a48"), (0.65, "5a5ab8"), (0.9, "c0c8ff"), (1, "ffffff")],
    "bone":     [(0, "0a0806"), (0.3, "4a3e32"), (0.65, "c8b898"), (0.9, "f4ecd8"), (1, "ffffff")],
    "rift":     [(0, "060018"), (0.3, "240850"), (0.62, "5a22b0"), (0.88, "a070ff"), (1, "f4e8ff")],
    "pharaoh":  [(0, "1a1000"), (0.3, "6a4a10"), (0.6, "c09a38"), (0.85, "f0d880"), (1, "fff8d8")],
    "dune":     [(0, "1a0c02"), (0.3, "6a3a14"), (0.65, "d89a4a"), (0.9, "ffe0a0"), (1, "ffffff")],
    "festival": [(0, "05040f"), (0.3, "1c1850"), (0.65, "5a3aa0"), (0.9, "ffd0ff"), (1, "ffffff")],
    "steel":    [(0, "05070a"), (0.3, "232a34"), (0.65, "5a6a7c"), (0.9, "b8c8d8"), (1, "f4faff")],
    "occult":   [(0, "0a0010"), (0.3, "3a0a40"), (0.65, "8a2a90"), (0.9, "e8a0ff"), (1, "fff0ff")],
    "bubblegum": [(0, "3a0a2a"), (0.3, "d03a90"), (0.65, "ff8ad0"), (0.9, "ffd8f0"), (1, "ffffff")],
    "mint":     [(0, "002a20"), (0.3, "2aaa88"), (0.65, "8af0c8"), (0.9, "e0fff4"), (1, "ffffff")],
    "alien":    [(0, "020a06"), (0.3, "0c3a22"), (0.65, "26b060"), (0.9, "a8ffc8"), (1, "f0fff6")],
    "chrome":   [(0, "06080a"), (0.3, "3a4450"), (0.65, "b0bcc8"), (0.9, "f0f6ff"), (1, "ffffff")],
    "comet":    [(0, "06101c"), (0.3, "1a3a5a"), (0.65, "5a98c8"), (0.9, "d8f0ff"), (1, "ffffff")],
}

# (id, nama, rarity, body, accent_rgb|"rainbow", pola, sparkle, bullet_col, bullet_glow)
SKINS = {
 "smith": [
    ("golden_age", "GOLDEN AGE", "legendary", "gold", "d4142a", None, True),
    ("obsidian", "OBSIDIAN", "epic", "obsidian", "18e0ff", None, False),
    ("permafrost", "PERMAFROST", "rare", "frost", "5cc8ff", "frost", False),
    ("magma_core", "MAGMA CORE", "epic", "magma", "ff7a10", "lava", False),
    ("venomous", "VENOMOUS", "rare", "toxic", "b6ff1a", "bubbles", False),
 ],
 "kurval": [
    ("royal_guard", "ROYAL GUARD", "epic", "royal", "ffc828", "stars", False),
    ("jungle_camo", "JUNGLE CAMO", "common", "camo", "ff8a1a", "camo_green", False),
    ("carbon_red", "CARBON RED", "rare", "carbon", "ff1f2e", "carbon", False),
    ("sakura_blade", "SAKURA", "common", "sakura", "ff3d8f", "petals", False),
    ("prism", "PRISM", "legendary", "silver", "rainbow", None, True),
 ],
 "flamer": [
    ("dragon_fire", "DRAGON FIRE", "epic", "magma", "ffcf1f", "lava", False),
    ("cosmic_flare", "COSMIC FLARE", "legendary", "cosmic", "ff4fd8", "nebula", True),
    ("solar", "SOLAR", "epic", "gold", "ff6a00", None, True),
    ("toxic_waste", "TOXIC WASTE", "rare", "toxic", "ff9a1a", "bubbles", False),
    ("nightshade", "NIGHTSHADE", "common", "obsidian", "b04dff", None, False),
 ],
 "scream": [
    ("banshee", "BANSHEE", "epic", "royal", "ff3fd0", "stars", False),
    ("arctic_howl", "ARCTIC HOWL", "rare", "frost", "9be8ff", "frost", False),
    ("voltage", "VOLTAGE", "epic", "obsidian", "ffe91f", "carbon", False),
    ("sakura_scream", "SAKURA SCREAM", "common", "sakura", "ff2f7a", "petals", False),
    ("cosmic_echo", "COSMIC ECHO", "legendary", "cosmic", "4fe8ff", "nebula", True),
 ],
 "pistol": [
    ("golden_eagle", "GOLDEN EAGLE", "legendary", "gold", "1a1a1a", None, True),
    ("desert_camo", "DESERT CAMO", "common", "sand", "ff5a1a", "camo_sand", False),
    ("neon_punk", "NEON PUNK", "epic", "obsidian", "ff2fd0", None, False),
    ("candy", "CANDY POP", "rare", "sakura", "3fe0ff", "petals", False),
    ("storm", "STORM", "rare", "carbon", "3f8fff", "carbon", False),
 ],
 "knife": [
    ("golden_blade", "GOLDEN BLADE", "legendary", "gold", "d4142a", None, True),
    ("frozen_fang", "FROZEN FANG", "rare", "frost", "5cc8ff", "frost", False),
    ("magma_edge", "MAGMA EDGE", "epic", "magma", "ff7a10", "lava", False),
    ("toxic_shiv", "TOXIC SHIV", "rare", "toxic", "b6ff1a", "bubbles", False),
    ("prism_edge", "PRISM EDGE", "legendary", "silver", "rainbow", None, True),
 ],
}

CAMO = {
    "camo_green": [hexc("2f4a22"), hexc("56703a"), hexc("1d2a14"), hexc("8a8f4a")],
    "camo_sand": [hexc("b79a64"), hexc("8c7348"), hexc("d9c08a"), hexc("5e4c2c")],
}

def rainbow_map(w, h):
    x = np.linspace(0, 1, w)[None, :].repeat(h, 0)
    out = np.zeros((h, w, 3), np.float32)
    for i in range(3):
        pass
    r = np.zeros_like(x); g = np.zeros_like(x); b = np.zeros_like(x)
    for yi in range(1):
        pass
    cols = np.array([colorsys.hsv_to_rgb((k / 255.0) % 1.0, 0.85, 1.0) for k in range(256)], np.float32)
    idx = np.clip((x * 255).astype(int), 0, 255)
    return cols[idx]

def make_weapon_skin(wid, spec, seed):
    spec = tuple(spec[:7])
    sid, name, rarity, body, accent, pattern, sparkle = spec
    rng = random.Random(seed)
    src = to_arr(load("../assets/sprites/guns/p1/%s.png" % wid))
    h, w = src.shape[:2]
    alpha = src[..., 3]
    rgb = src[..., :3]
    hh, ss, vv = rgb_to_hsv(rgb)
    redhue = ((hh < 0.06) | (hh > 0.94)).astype(np.float32)
    acc = np.clip((ss - 0.22) / 0.35, 0, 1) * redhue
    l = lum(rgb)
    # ---- badan
    stops = [(p, hexc(c)) for p, c in BODY[body]]
    shade = np.clip(l * 1.05 + 0.02, 0, 1)
    if body in ("camo", "sand"):
        key = "camo_green" if body == "camo" else "camo_sand"
        cols = CAMO[key]
        n1 = fbm(h, w, seed, 70, 3); n2 = fbm(h, w, seed + 5, 45, 3)
        bodyc = np.zeros((h, w, 3), np.float32)
        bodyc[:] = cols[0]
        for i, (n, thr) in enumerate([(n1, 0.52), (n2, 0.58), (n1 * 0.5 + n2 * 0.5, 0.64)]):
            m = (n > thr)[..., None]
            bodyc = np.where(m, np.array(cols[i + 1], np.float32), bodyc)
        bodyc = bodyc * (0.25 + 0.95 * shade[..., None])
    else:
        bodyc = gradient_map(shade, stops)
    # ---- pola
    if pattern == "carbon":
        yy, xx = np.mgrid[0:h, 0:w]
        wv = (((xx // 6) + (yy // 6)) % 2).astype(np.float32)
        diag = (((xx + yy) % 12) < 3).astype(np.float32) * 0.5
        bodyc = bodyc * (0.7 + 0.35 * wv[..., None] + 0.1 * diag[..., None])
    if pattern == "frost":
        n = fbm(h, w, seed, 40, 4)
        bodyc = np.clip(bodyc + np.clip(n - 0.55, 0, 1)[..., None] * 1.3 * np.array([0.7, 0.9, 1.0]), 0, 1)
    if pattern == "stars":
        n = fbm(h, w, seed, 90, 3)
        bodyc = np.clip(bodyc + (np.clip(n - 0.45, 0, 1)[..., None] * np.array(hexc("ff9aff")) * 0.45), 0, 1)
    if pattern == "nebula":
        n = fbm(h, w, seed, 110, 4); n2 = fbm(h, w, seed + 9, 70, 3)
        neb = np.stack([np.clip(n * 1.5 - 0.3, 0, 1) * 0.8, np.clip(n2 * 0.4, 0, 1) * 0.3, np.clip(n2 * 1.3, 0, 1) * 0.8], -1)
        bodyc = np.clip(bodyc + neb * 0.6 * (1.0 - shade[..., None] * 0.6), 0, 1)
    if pattern == "bubbles":
        n = fbm(h, w, seed, 55, 3)
        bodyc = np.clip(bodyc + np.clip(n - 0.58, 0, 1)[..., None] * np.array(hexc("c8ff40")) * 1.2, 0, 1)
    if pattern == "scales":
        yy, xx = np.mgrid[0:h, 0:w]
        sz = 22
        row = (yy // (sz // 2)); off = (row % 2) * (sz // 2)
        fx = ((xx + off) % sz) / sz; fy = (yy % (sz // 2)) / (sz // 2)
        arc = np.clip(1.0 - np.abs(np.sqrt((fx - 0.5) ** 2 + (fy) ** 2) - 0.55) * 7.0, 0, 1)
        bodyc = bodyc * (0.82 + 0.3 * (1 - arc[..., None])) + arc[..., None] * np.array(hexc("d8ffc0")) * 0.22
    if pattern == "circuit":
        yy, xx = np.mgrid[0:h, 0:w]
        gx = ((xx % 28) < 2) | ((yy % 28) < 2)
        node = (((xx % 28) < 6) & ((yy % 28) < 6))
        mk = (n_ := fbm(h, w, seed + 2, 50, 2)) > 0.5
        line = (gx & mk).astype(np.float32); nd = (node & mk).astype(np.float32)
        bodyc = np.clip(bodyc + line[..., None] * np.array(hexc("40f0ff")) * 0.55 + nd[..., None] * np.array(hexc("ff40d0")) * 0.8, 0, 1)
    if pattern == "shards":
        n = fbm(h, w, seed, 36, 3)
        cell = np.floor(n * 9.0) / 9.0
        bodyc = np.clip(bodyc * (0.8 + 0.5 * cell[..., None]) + np.clip(n - 0.62, 0, 1)[..., None] * 1.4 * np.array([0.6, 0.9, 1.0]), 0, 1)
    if pattern == "runes":
        n = fbm(h, w, seed, 60, 3)
        yy, xx = np.mgrid[0:h, 0:w]
        stripe = ((xx // 18 + (n * 3).astype(int)) % 3 == 0).astype(np.float32) * 0.22
        bodyc = np.clip(bodyc + stripe[..., None] * np.array(hexc("b080ff")), 0, 1)
    if pattern == "holo":
        yy, xx = np.mgrid[0:h, 0:w]
        hue = ((xx + yy) / float(w + h) * 2.0 + shade * 0.5) % 1.0
        cols = np.array([colorsys.hsv_to_rgb(k / 255.0, 0.55, 1.0) for k in range(256)], np.float32)
        hc = cols[np.clip((hue * 255).astype(int), 0, 255)]
        bodyc = np.clip(bodyc * 0.65 + hc * shade[..., None] * 0.55, 0, 1)
    # ---- pola baru (skin finisher gelombang 2)
    if pattern == "waves":
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        nn = fbm(h, w, seed, 120, 3)
        ph_ = yy * 0.075 + np.sin(xx * 0.028 + nn * 5.0) * 2.4 + nn * 4.0
        band = np.clip(np.sin(ph_) * 0.5 + 0.5, 0, 1)
        crest = np.clip((band - 0.82) / 0.18, 0, 1)
        bodyc = np.clip(bodyc * (0.82 + 0.28 * band[..., None]) + crest[..., None] * 0.30 * np.array([0.8, 0.95, 1.0]), 0, 1)
    if pattern == "hiero":
        yy, xx = np.mgrid[0:h, 0:w]
        cw, ch = 30, 44
        cx, cy = xx // cw, yy // ch
        hs = np.sin(cx * 12.9898 + cy * 78.233) * 43758.5453
        hs = hs - np.floor(hs)
        lx, ly = (xx % cw) / cw, (yy % ch) / ch
        bar_h = (np.abs(ly - (0.25 + 0.5 * hs)) < 0.07) & (lx > 0.2) & (lx < 0.8)
        bar_v = (np.abs(lx - (0.3 + 0.4 * ((hs * 7.0) % 1.0))) < 0.08) & (ly > 0.15) & (ly < 0.85)
        dot_ = ((lx - 0.5) ** 2 + (ly - 0.8) ** 2) < 0.012
        eye = (np.abs(ly - 0.5) < 0.05) & (lx > 0.25) & (lx < 0.75) & (hs > 0.6)
        glyph = ((bar_h | bar_v | dot_ | eye) & (hs > 0.15)).astype(np.float32)
        glyph = cv2.GaussianBlur(glyph, (0, 0), 0.8)
        bodyc = np.clip(bodyc * (1.0 - 0.45 * glyph[..., None]) + glyph[..., None] * np.array(hexc("3af0e0")) * 0.18 * shade[..., None], 0, 1)
    if pattern == "confetti":
        d = Image.new("RGBA", (w, h), (0, 0, 0, 0)); dr = ImageDraw.Draw(d)
        cols_ = [(255, 90, 140), (255, 214, 64), (80, 220, 255), (150, 255, 110), (200, 110, 255), (255, 140, 40)]
        for _ in range(int(w * h / 1500)):
            x, y = rng.uniform(0, w), rng.uniform(0, h); r = rng.uniform(4, 9); ang = rng.uniform(0, 6.28)
            ca, sa = math.cos(ang), math.sin(ang); cc = rng.choice(cols_)
            if rng.random() < 0.5:
                pts = [(x + (-r * ca + -r * 0.45 * sa), y + (-r * sa + r * 0.45 * ca)), (x + (r * ca + -r * 0.45 * sa), y + (r * sa + r * 0.45 * ca)),
                       (x + (r * ca + r * 0.45 * sa), y + (r * sa - r * 0.45 * ca)), (x + (-r * ca + r * 0.45 * sa), y + (-r * sa - r * 0.45 * ca))]
                dr.polygon(pts, fill=cc + (255,))
            else:
                dr.ellipse([x - r * 0.6, y - r * 0.6, x + r * 0.6, y + r * 0.6], fill=cc + (255,))
        dd = to_arr(d)
        m = (dd[..., 3] * (1 - acc) * 0.95)[..., None]
        out0 = bodyc * (1 - m) + dd[..., :3] * m * (0.7 + 0.5 * shade[..., None])
        bodyc = np.clip(out0, 0, 1)
    if pattern == "hexgrid":
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        sz = 24.0
        px, py = xx / sz, yy / sz
        rx, ry = 1.0, 1.7320508
        ax = np.mod(px, rx) - rx * 0.5; ay = np.mod(py, ry) - ry * 0.5
        bx = np.mod(px - rx * 0.5, rx) - rx * 0.5; by = np.mod(py - ry * 0.5, ry) - ry * 0.5
        use_a = (ax * ax + ay * ay) < (bx * bx + by * by)
        gx = np.where(use_a, ax, bx); gy = np.where(use_a, ay, by)
        hd = np.maximum(np.abs(gx) * 0.5 + np.abs(gy) * 0.8660254, np.abs(gx))
        edge = np.clip((0.5 - hd) / 0.06, 0, 1)
        line = 1.0 - edge
        cellv = np.sin(np.floor(px - gx) * 12.9898 + np.floor(py - gy) * 78.233) * 43758.5453
        cellv = cellv - np.floor(cellv)
        bodyc = np.clip(bodyc * (0.78 + 0.38 * cellv[..., None]) * (1.0 - 0.45 * line[..., None]) + line[..., None] * 0.10, 0, 1)
    if pattern == "sigil":
        d = Image.new("RGBA", (w, h), (0, 0, 0, 0)); dr = ImageDraw.Draw(d)
        ncirc = max(2, int(w / 260))
        for k in range(ncirc):
            cx_ = w * (k + 0.5) / ncirc + rng.uniform(-20, 20); cy_ = h * rng.uniform(0.38, 0.6); R = min(h * 0.34, 78 + rng.uniform(-10, 14))
            dr.ellipse([cx_ - R, cy_ - R, cx_ + R, cy_ + R], outline=(255, 255, 255, 255), width=3)
            dr.ellipse([cx_ - R * 0.78, cy_ - R * 0.78, cx_ + R * 0.78, cy_ + R * 0.78], outline=(255, 255, 255, 255), width=2)
            pts = [(cx_ + math.cos(-math.pi / 2 + i * 4 * math.pi / 5) * R * 0.78, cy_ + math.sin(-math.pi / 2 + i * 4 * math.pi / 5) * R * 0.78) for i in range(5)]
            dr.polygon(pts, outline=(255, 255, 255, 255))
            for i in range(12):
                a_ = i * math.pi / 6
                dr.line([(cx_ + math.cos(a_) * R * 0.9, cy_ + math.sin(a_) * R * 0.9), (cx_ + math.cos(a_) * R * 1.0, cy_ + math.sin(a_) * R * 1.0)], fill=(255, 255, 255, 255), width=3)
        dd = to_arr(d)
        sg = (dd[..., 3] * (1 - acc))
        sg_c = hexc(accent) if accent != "rainbow" else hexc("ff5ad0")
        bodyc = np.clip(bodyc + sg[..., None] * np.array(sg_c) * 0.85 + glow_of(sg, 5.0, 1.4)[..., None] * np.array(sg_c) * 0.25, 0, 1)
    if pattern == "dots":
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        per = 46.0
        row = np.floor(yy / (per * 0.5)); off = np.mod(row, 2) * (per * 0.5)
        lx = np.mod(xx + off, per) - per * 0.5; ly = np.mod(yy, per * 0.5) - per * 0.25
        dm = np.clip((11.0 - np.sqrt(lx * lx + ly * ly * 1.0)) / 2.0, 0, 1)
        bodyc = np.clip(bodyc * (1 - dm[..., None] * 0.8) + dm[..., None] * np.array([1.0, 0.96, 0.98]) * (0.5 + 0.55 * shade[..., None]), 0, 1)
    if pattern == "rivets":
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        per = 56.0
        lx = np.mod(xx, per) - per * 0.5; ly = np.mod(yy, per) - per * 0.5
        rv = np.clip((6.0 - np.sqrt(lx * lx + ly * ly)) / 1.6, 0, 1)
        hl = np.clip((3.2 - np.sqrt((lx + 2.0) ** 2 + (ly + 2.0) ** 2)) / 1.2, 0, 1)
        seam = (np.abs(np.mod(yy, per * 2) - per) < 1.5).astype(np.float32)
        bodyc = np.clip(bodyc * (1 - 0.3 * rv[..., None]) * (1.0 - 0.35 * seam[..., None]) + hl[..., None] * 0.5, 0, 1)
    # ---- aksen
    if accent == "rainbow":
        rb = rainbow_map(w, h)
        accc = rb * (0.35 + 0.85 * np.clip(vv, 0, 1)[..., None])
        accent_rgb = hexc("ff5ad0")
    else:
        accent_rgb = hexc(accent)
        accc = gradient_map(np.clip(vv, 0, 1), accent_stops(accent_rgb))
    out = bodyc * (1 - acc[..., None]) + accc * acc[..., None]
    # retak lava / pola neon yang menyala
    glow_src = acc.copy()
    if pattern == "lava":
        n = fbm(h, w, seed + 3, 60, 4)
        crack = np.clip(1.0 - np.abs(n - 0.5) * 22.0, 0, 1) * (1 - acc) * (alpha > 0.5)
        lavac = gradient_map(crack, [(0, (0, 0, 0)), (0.4, accent_rgb), (1.0, (1, 0.95, 0.6))])
        out = out * (1 - crack[..., None]) + lavac * crack[..., None]
        glow_src = np.maximum(glow_src, crack)
    if pattern == "petals":
        d = Image.new("RGBA", (w, h), (0, 0, 0, 0)); dr = ImageDraw.Draw(d)
        for _ in range(int(w * h / 14000)):
            x, y = rng.uniform(0, w), rng.uniform(0, h); r = rng.uniform(9, 17); ang = rng.uniform(0, 6.28)
            pts = [(x + math.cos(t / 10 * 6.2832) * r * math.cos(ang) - math.sin(t / 10 * 6.2832) * r * 0.55 * math.sin(ang) * 0 - math.sin(t / 10 * 6.2832) * r * 0.55 * math.sin(ang) * 0, 0) for t in range(0)]
            ca, sa = math.cos(ang), math.sin(ang)
            pts = []
            for t in range(12):
                px = math.cos(t / 12 * 6.2832) * r; py = math.sin(t / 12 * 6.2832) * r * 0.55
                pts.append((x + px * ca - py * sa, y + px * sa + py * ca))
            dr.polygon(pts, fill=(255, 140, 185, 255), outline=(255, 235, 242, 255))
        dd = to_arr(d)
        m = (dd[..., 3] * (1 - acc) * 0.9)[..., None]
        out = out * (1 - m) + dd[..., :3] * m * (0.55 + 0.6 * shade[..., None])
    # ---- cahaya aksen (bloom) di dalam siluet
    gl = glow_of(glow_src, 6.0, 1.7)
    glc = np.array(accent_rgb, np.float32) if accent != "rainbow" else np.array(hexc("ffb0f0"), np.float32)
    out = np.clip(out + gl[..., None] * glc * 0.5 * alpha[..., None], 0, 1)
    # kilau
    img = to_img(np.dstack([out, alpha]))
    if sparkle:
        dl = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d2 = ImageDraw.Draw(dl)
        ys, xs = np.where(alpha > 0.9)
        if len(xs):
            for _ in range(max(5, int(w / 130))):
                k = rng.randrange(len(xs)); cx, cy = float(xs[k]), float(ys[k]); r = rng.uniform(10, 20)
                d2.polygon([(cx, cy - r), (cx + r * 0.2, cy - r * 0.2), (cx + r, cy), (cx + r * 0.2, cy + r * 0.2), (cx, cy + r),
                            (cx - r * 0.2, cy + r * 0.2), (cx - r, cy), (cx - r * 0.2, cy - r * 0.2)], fill=(255, 255, 240, 235))
        aa = np.asarray(dl, np.float32) / 255.0
        a0 = np.asarray(img, np.float32) / 255.0
        m = (aa[..., 3] * (alpha > 0.5))[..., None]
        a0[..., :3] = a0[..., :3] * (1 - m) + aa[..., :3] * m
        img = to_img(a0)
    # warna peluru (untuk game): aksen & cahaya
    return img, accent_rgb if accent != "rainbow" else hexc("ff5ad0")


# ====================================================================== SKIN PREMIUM (berlevel + finisher)
# (id, nama, rarity, body, accent, pola, sparkle) + (harga LV1, upgrade LV2, upgrade LV3, finisher)
PRICES_FX = {"epic": (2400, 1500, 2200), "legendary": (3200, 2000, 3000), "mythic": (4400, 2800, 4200)}
SKINS_FX = {
 "smith": [
    ("void_reaper", "VOID REAPER", "mythic", "void", "b04dff", "runes", True, "blackhole"),
    ("thunder_god", "THUNDER GOD", "legendary", "storm", "ffe84a", "carbon", True, "lightning"),
    ("solar_dragon", "SOLAR DRAGON", "legendary", "dragon", "ffb21f", "scales", True, "inferno"),
    ("cyber_ronin", "CYBER RONIN", "epic", "cyber", "ff2f8f", "circuit", False, "glitch"),
    ("crystal_king", "CRYSTAL KING", "epic", "crystal", "7ff0ff", "shards", False, "shatter"),
 ],
 "kurval": [
    ("nova_lance", "NOVA LANCE", "mythic", "nova", "ff4fd8", "nebula", True, "cosmic"),
    ("holy_judgment", "HOLY JUDGMENT", "legendary", "holy", "ffd23f", None, True, "ascend"),
    ("blood_moon", "BLOOD MOON", "legendary", "magma", "ff1f2e", "lava", True, "inferno"),
    ("matrix_code", "MATRIX CODE", "epic", "cyber", "40ff90", "circuit", False, "glitch"),
    ("glacier_fang", "GLACIER FANG", "epic", "crystal", "5cc8ff", "shards", False, "shatter"),
 ],
 "flamer": [
    ("phoenix_rebirth", "PHOENIX REBIRTH", "mythic", "magma", "ffcf1f", "lava", True, "inferno"),
    ("golden_jackpot", "GOLDEN JACKPOT", "legendary", "jackpot", "d4142a", None, True, "jackpot"),
    ("plague_doctor", "PLAGUE DOCTOR", "legendary", "venom", "b6ff1a", "bubbles", False, "toxic"),
    ("spirit_lantern", "SPIRIT LANTERN", "epic", "blossom", "ff3d8f", "petals", False, "petals"),
    ("void_furnace", "VOID FURNACE", "epic", "void", "ff7a10", "runes", False, "blackhole"),
 ],
 "scream": [
    ("cosmic_choir", "COSMIC CHOIR", "mythic", "nova", "4fe8ff", "nebula", True, "cosmic"),
    ("storm_siren", "STORM SIREN", "legendary", "storm", "9be8ff", "carbon", True, "lightning"),
    ("sakura_requiem", "SAKURA REQUIEM", "legendary", "blossom", "ff2f7a", "petals", True, "petals"),
    ("neon_static", "NEON STATIC", "epic", "cyber", "ffe91f", "circuit", False, "glitch"),
    ("frozen_aria", "FROZEN ARIA", "epic", "crystal", "9be8ff", "shards", False, "shatter"),
 ],
 "pistol": [
    ("jackpot_king", "JACKPOT KING", "mythic", "jackpot", "1a1a1a", None, True, "jackpot"),
    ("phantom_void", "PHANTOM VOID", "legendary", "void", "ff40d0", "runes", True, "blackhole"),
    ("dragon_breath", "DRAGON BREATH", "legendary", "dragon", "ff6a00", "scales", True, "inferno"),
    ("angel_judge", "ANGEL JUDGE", "epic", "holy", "4fd8ff", None, False, "ascend"),
    ("toxic_viper", "TOXIC VIPER", "epic", "venom", "ff9a1a", "scales", False, "toxic"),
 ],
 "knife": [
    ("prism_slicer", "PRISM SLICER", "mythic", "prismw", "rainbow", "holo", True, "slice"),
    ("shadow_fang", "SHADOW FANG", "legendary", "void", "9b3dff", None, True, "blackhole"),
    ("thunder_edge", "THUNDER EDGE", "legendary", "storm", "ffe84a", None, True, "lightning"),
    ("blossom_edge", "BLOSSOM EDGE", "epic", "blossom", "ff3d8f", "petals", False, "petals"),
    ("venom_shiv", "VENOM SHIV", "epic", "venom", "b6ff1a", "bubbles", False, "toxic"),
 ],
}

# ---- GELOMBANG 2: 30 skin premium baru, tiap skin punya finisher BARU (meteor, tsunami, reaper, portal, sands, firework, orbital, hex, balloon, ufo)
SKINS_FX["smith"] += [
    ("meteor_crash", "METEOR CRASH", "mythic", "basalt", "ff5a1a", "lava", True, "meteor"),
    ("tidal_wrath", "TIDAL WRATH", "legendary", "tide", "5ce8ff", "waves", True, "tsunami"),
    ("grim_harvest", "GRIM HARVEST", "legendary", "reaper", "5affb0", "runes", True, "reaper"),
    ("orbital_lance", "ORBITAL LANCE", "epic", "steel", "ff2a2a", "hexgrid", False, "orbital"),
    ("sands_of_ra", "SANDS OF RA", "epic", "pharaoh", "20e0d0", "hiero", False, "sands"),
]
SKINS_FX["kurval"] += [
    ("rift_breaker", "RIFT BREAKER", "mythic", "rift", "ff9a3a", "nebula", True, "portal"),
    ("first_contact", "FIRST CONTACT", "legendary", "alien", "9aff5a", "rivets", True, "ufo"),
    ("grand_finale", "GRAND FINALE", "legendary", "festival", "rainbow", "confetti", True, "firework"),
    ("hexed_sigil", "HEXED SIGIL", "epic", "occult", "d04aff", "sigil", False, "hex"),
    ("bubble_trouble", "BUBBLE TROUBLE", "epic", "bubblegum", "3fe0ff", "dots", False, "balloon"),
]
SKINS_FX["flamer"] += [
    ("doomsday_comet", "DOOMSDAY COMET", "mythic", "obsidian", "ffcf1f", "lava", True, "meteor"),
    ("soul_burner", "SOUL BURNER", "legendary", "wraith", "60e0ff", "runes", True, "reaper"),
    ("pyro_festival", "PYRO FESTIVAL", "legendary", "festival", "ff6a00", "confetti", True, "firework"),
    ("hellfire_sigil", "HELLFIRE SIGIL", "epic", "occult", "ff3a1a", "sigil", False, "hex"),
    ("desert_mirage", "DESERT MIRAGE", "epic", "dune", "ff5a1a", "hiero", False, "sands"),
]
SKINS_FX["scream"] += [
    ("echo_dimension", "ECHO DIMENSION", "mythic", "rift", "4fe8ff", "nebula", True, "portal"),
    ("siren_tide", "SIREN TIDE", "legendary", "abyss", "ff4fd8", "waves", True, "tsunami"),
    ("alien_anthem", "ALIEN ANTHEM", "legendary", "chrome", "5aff8a", "rivets", True, "ufo"),
    ("pop_diva", "POP DIVA", "epic", "bubblegum", "ffe91f", "dots", False, "balloon"),
    ("satellite_scream", "SATELLITE SCREAM", "epic", "steel", "40a0ff", "hexgrid", False, "orbital"),
]
SKINS_FX["pistol"] += [
    ("shooting_star", "SHOOTING STAR", "mythic", "comet", "ffe27a", "stars", True, "meteor"),
    ("rift_runner", "RIFT RUNNER", "legendary", "rift", "40ff90", None, True, "portal"),
    ("ufo_hunter", "UFO HUNTER", "legendary", "alien", "ff4fd8", "rivets", True, "ufo"),
    ("splash_blaster", "SPLASH BLASTER", "epic", "aqua", "ffd23f", "waves", False, "tsunami"),
    ("gumball_gun", "GUMBALL GUN", "epic", "mint", "ff4fa0", "dots", False, "balloon"),
]
SKINS_FX["knife"] += [
    ("death_scythe", "DEATH'S SCYTHE", "mythic", "bone", "ff1f2e", "runes", True, "reaper"),
    ("sandstorm", "SANDSTORM", "legendary", "dune", "20e0d0", "hiero", True, "sands"),
    ("sky_burst", "SKY BURST", "legendary", "festival", "ff3a6a", "confetti", True, "firework"),
    ("orbital_blade", "ORBITAL BLADE", "epic", "steel", "ffb21f", "hexgrid", False, "orbital"),
    ("cursed_talisman", "CURSED TALISMAN", "epic", "occult", "ff3a8a", "sigil", False, "hex"),
]
