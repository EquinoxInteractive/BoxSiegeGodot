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
