"""5 tema skin karakter PREMIUM (berlevel: LV1 sprite, LV2 + partikel, LV3 + animasi). Dipakai untuk 24 karakter -> 120 skin (+ _die).
Efek partikel & animasi digambar saat game berjalan (scripts/fx_*.gd); di sini hanya sprite dasar (LV1)."""
import numpy as np, math, random, colorsys
from PIL import Image, ImageDraw, ImageFilter
import cv2
from artlib import *
from skins import SZ, S, base_l, overlay_img, newlayer, fin, star4, flames

def frame2(a, c1, c2, w=7):
    """bingkai premium: tepi tebal 2 warna + garis dalam + permata sudut"""
    h, wd = a.shape[:2]
    c1 = np.array(c1, np.float32); c2 = np.array(c2, np.float32)
    for i in range(w):
        t = i / max(w - 1, 1)
        k = c1 * (1 - t) + c2 * t
        a[i, :, :3] = k; a[h - 1 - i, :, :3] = k; a[:, i, :3] = k; a[:, wd - 1 - i, :3] = k
    a[w, w:wd - w, :3] *= 0.3; a[h - 1 - w, w:wd - w, :3] *= 0.3
    a[w:h - w, w, :3] *= 0.3; a[w:h - w, wd - 1 - w, :3] *= 0.3
    lay = newlayer(); d = ImageDraw.Draw(lay)
    for (cx, cy) in [(w + 6, w + 6), (SZ - w - 6, w + 6), (w + 6, SZ - w - 6), (SZ - w - 6, SZ - w - 6)]:
        r = 9 * S
        d.polygon([(cx * S, cy * S - r), (cx * S + r, cy * S), (cx * S, cy * S + r), (cx * S - r, cy * S)],
                  fill=tuple(int(x * 255) for x in c2) + (255,), outline=(12, 10, 18, 255), width=2 * S)
    return overlay_img(a, fin(lay))

def glowdots(a, rng, n, col, rmin=2, rmax=5, region=(8, 8, 172, 172), blur=3.0, strength=1.0):
    lay = np.zeros((SZ, SZ), np.float32)
    for _ in range(n):
        x = int(rng.uniform(region[0], region[2])); y = int(rng.uniform(region[1], region[3]))
        cv2.circle(lay, (x, y), int(rng.uniform(rmin, rmax)), 1.0, -1)
    g = glow_of(lay, blur, 2.2 * strength)
    a[..., :3] = np.clip(a[..., :3] + g[..., None] * np.array(col, np.float32), 0, 1)
    a[..., :3] = np.clip(a[..., :3] + lay[..., None] * 0.5, 0, 1)
    return a

def bolt_pts(rng, x0, y0, x1, y1, seg=9, jit=11):
    pts = [(x0, y0)]
    for i in range(1, seg):
        t = i / seg
        pts.append((x0 + (x1 - x0) * t + rng.uniform(-jit, jit), y0 + (y1 - y0) * t + rng.uniform(-jit * 0.6, jit * 0.6)))
    pts.append((x1, y1))
    return pts

# ------------------------------------------------------------------ SOLAR FLARE
def t_solar(a, rng, die):
    l = base_l(a[..., :3])
    g = gradient_map(np.clip(l * 0.9 + 0.1, 0, 1), [(0, hexc("1c0300")), (0.3, hexc("9c1a05")), (0.55, hexc("ff6a10")), (0.8, hexc("ffc830")), (1, hexc("fffbe0"))])
    a[..., :3] = g
    yy, xx = np.mgrid[0:SZ, 0:SZ].astype(np.float32)
    cx, cy = 140.0, 36.0
    dx, dy = xx - cx, yy - cy
    r = np.sqrt(dx * dx + dy * dy); ang = np.arctan2(dy, dx)
    rays = (np.sin(ang * 14.0) * 0.5 + 0.5) ** 3 * np.exp(-r / 85.0)
    corona = np.exp(-r / 38.0)
    sun = np.clip(1.0 - (r - 20.0) / 3.0, 0, 1)
    a[..., :3] = np.clip(a[..., :3] + rays[..., None] * np.array(hexc("ffb020")) * 0.55 + corona[..., None] * np.array(hexc("ff9a20")) * 0.5, 0, 1)
    a[..., :3] = a[..., :3] * (1 - sun[..., None]) + sun[..., None] * np.array(hexc("fff7c4"))
    lay = newlayer(); d = ImageDraw.Draw(lay)
    flames(d, rng, (255, 120, 20, 235), (255, 196, 50, 235), (255, 250, 190, 235))
    for k in range(6):   # filigran emas di sudut
        d.arc([(-30 + k * 6) * S, (-30 + k * 6) * S, (60 - k * 4) * S, (60 - k * 4) * S], 0, 90, fill=(255, 220, 110, 200), width=S)
    a = overlay_img(a, fin(lay))
    a = glowdots(a, rng, 22, hexc("ffb030"), 1, 3, (6, 40, 174, 150), 2.5)
    lay = newlayer(); d = ImageDraw.Draw(lay)
    for _ in range(6):
        star4(d, rng.uniform(14, 166) * S, rng.uniform(14, 120) * S, rng.uniform(5, 10) * S, (255, 252, 214, 255))
    a = overlay_img(a, fin(lay))
    return frame2(a, hexc("ffb21f"), hexc("fff0a0"))

# ------------------------------------------------------------------ VOID WALKER
def t_void(a, rng, die):
    l = base_l(a[..., :3])
    g = gradient_map(np.clip(l ** 1.3, 0, 1), [(0, hexc("000004")), (0.25, hexc("14052e")), (0.55, hexc("5a14a8")), (0.85, hexc("d060ff")), (1, hexc("ffe8ff"))])
    a[..., :3] = g
    yy, xx = np.mgrid[0:SZ, 0:SZ].astype(np.float32)
    cx, cy = 90.0, 96.0
    dx, dy = xx - cx, yy - cy
    r = np.sqrt(dx * dx + dy * dy) + 1e-3; ang = np.arctan2(dy, dx)
    n = fbm(SZ, SZ, rng.randint(0, 9999), 22, 3)
    spiral = np.sin(ang * 3.0 - np.log(r + 8.0) * 6.5 + n * 2.0) * 0.5 + 0.5
    vor = (spiral ** 2.2) * np.clip((r - 14.0) / 40.0, 0, 1) * np.exp(-r / 120.0)
    a[..., :3] = np.clip(a[..., :3] + vor[..., None] * np.array(hexc("a040ff")) * 0.7, 0, 1)
    ring = np.exp(-((r - 62.0) / 4.0) ** 2)
    a[..., :3] = np.clip(a[..., :3] + ring[..., None] * np.array(hexc("ff40d0")) * 0.5, 0, 1)
    core = np.clip(1.0 - (r - 6.0) / 18.0, 0, 1) ** 1.5 * 0.55
    a[..., :3] *= (1 - core[..., None])
    a = glowdots(a, rng, 26, hexc("c070ff"), 1, 2, (8, 8, 172, 172), 2.5, 0.8)
    v = np.clip(1.3 - np.sqrt(((xx - 90) / 105) ** 2 + ((yy - 90) / 105) ** 2) * 0.6, 0.45, 1)
    a[..., :3] *= v[..., None]
    return frame2(a, hexc("9a3dff"), hexc("ff5ae0"))

# ------------------------------------------------------------------ STORMCALLER
def t_storm(a, rng, die):
    l = base_l(a[..., :3])
    g = gradient_map(np.clip(l * 0.95 + 0.05, 0, 1), [(0, hexc("020616")), (0.3, hexc("0f2a6a")), (0.6, hexc("2a78e8")), (0.85, hexc("8fe4ff")), (1, hexc("ffffff"))])
    a[..., :3] = g
    n = fbm(SZ, SZ, rng.randint(0, 9999), 26, 4)
    yy = np.linspace(0, 1, SZ)[:, None]
    cloud = np.clip((n - 0.42) * 3.0, 0, 1) * np.clip(1.0 - yy * 2.6, 0, 1)
    a[..., :3] = a[..., :3] * (1 - cloud[..., None] * 0.75) + cloud[..., None] * 0.75 * np.array(hexc("3a4a78"))
    yy2, xx2 = np.mgrid[0:SZ, 0:SZ].astype(np.float32)
    rain = (((xx2 * 0.5 + yy2) % 11) < 1.1).astype(np.float32) * 0.18 * np.clip(yy2 / 90, 0, 1)
    a[..., :3] = np.clip(a[..., :3] + rain[..., None] * np.array(hexc("a0d8ff")), 0, 1)
    lay = np.zeros((SZ * 2, SZ * 2, 4), np.float32)
    img = Image.new("RGBA", (SZ * S, SZ * S), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    for (x0, x1) in [(rng.uniform(20, 70), rng.uniform(10, 80)), (rng.uniform(110, 160), rng.uniform(100, 170))]:
        pts = bolt_pts(rng, x0, 0, x1, rng.uniform(110, 160))
        P = [(x * S, y * S) for x, y in pts]
        d.line(P, fill=(120, 190, 255, 255), width=9 * S, joint="curve")
        d.line(P, fill=(255, 255, 255, 255), width=3 * S, joint="curve")
        for _ in range(2):
            k = rng.randint(2, 6); bx, by = pts[k]
            br = bolt_pts(rng, bx, by, bx + rng.uniform(-30, 30), by + rng.uniform(15, 40), 4, 5)
            d.line([(x * S, y * S) for x, y in br], fill=(180, 225, 255, 255), width=2 * S)
    lyr = fin(img)
    arr = to_arr(lyr)
    gl = glow_of(arr[..., 3], 5.0, 1.8)
    a[..., :3] = np.clip(a[..., :3] + gl[..., None] * np.array(hexc("4fa8ff")) * 0.7, 0, 1)
    a = overlay_img(a, lyr)
    a = glowdots(a, rng, 12, hexc("ffe84a"), 1, 2, (8, 40, 172, 170), 2.0, 0.7)
    return frame2(a, hexc("3fa0ff"), hexc("ffe84a"))

# ------------------------------------------------------------------ PRISMATIC
def t_prism(a, rng, die):
    l = base_l(a[..., :3])
    yy, xx = np.mgrid[0:SZ, 0:SZ].astype(np.float32)
    hue = (l * 0.9 + (xx + yy) / 360.0) % 1.0
    out = np.zeros(a.shape[:2] + (3,), np.float32)
    # hsv -> rgb vectorized
    h6 = hue * 6.0; i = np.floor(h6).astype(int) % 6; f = h6 - np.floor(h6)
    s = 0.62; v = np.clip(0.22 + 0.85 * l, 0, 1)
    p = v * (1 - s); q = v * (1 - s * f); t = v * (1 - s * (1 - f))
    for k, (r_, g_, b_) in enumerate([(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)]):
        m = (i == k)
        out[..., 0] = np.where(m, r_, out[..., 0]); out[..., 1] = np.where(m, g_, out[..., 1]); out[..., 2] = np.where(m, b_, out[..., 2])
    a[..., :3] = out
    # faset kristal
    lay = newlayer(); d = ImageDraw.Draw(lay)
    pts = [(rng.uniform(0, SZ), rng.uniform(0, SZ)) for _ in range(14)] + [(0, 0), (SZ, 0), (0, SZ), (SZ, SZ)]
    for _ in range(26):
        p0 = rng.choice(pts); p1 = rng.choice(pts)
        d.line([(p0[0] * S, p0[1] * S), (p1[0] * S, p1[1] * S)], fill=(255, 255, 255, 70), width=S)
    for _ in range(7):
        p0, p1, p2 = rng.sample(pts, 3)
        d.polygon([(x * S, y * S) for x, y in (p0, p1, p2)], fill=(255, 255, 255, rng.randint(16, 46)))
    a = overlay_img(a, fin(lay))
    band = np.exp(-(((xx - yy * 0.6) - 70.0) / 18.0) ** 2) * 0.35
    a[..., :3] = np.clip(a[..., :3] + band[..., None], 0, 1)
    lay = newlayer(); d = ImageDraw.Draw(lay)
    for _ in range(9):
        star4(d, rng.uniform(12, 168) * S, rng.uniform(12, 168) * S, rng.uniform(5, 12) * S, (255, 255, 255, 255))
    a = overlay_img(a, fin(lay))
    # bingkai pelangi premium
    h, w = a.shape[:2]
    for i2 in range(7):
        for k in range(w):
            c = np.array(colorsys.hsv_to_rgb((k / w + i2 * 0.04) % 1.0, 0.5, 1.0), np.float32) * (1 - 0.1 * i2)
            a[i2, k, :3] = c; a[h - 1 - i2, k, :3] = c; a[k, i2, :3] = c; a[k, w - 1 - i2, :3] = c
    return frame2(a, hexc("ffffff"), hexc("ffffff"), 7) if False else a

# ------------------------------------------------------------------ SPIRIT BLOOM
def t_spirit(a, rng, die):
    l = base_l(a[..., :3])
    g = gradient_map(np.clip(l * 0.92 + 0.06, 0, 1), [(0, hexc("021612")), (0.3, hexc("0b5a4c")), (0.6, hexc("2fc4a0")), (0.85, hexc("bff6e0")), (1, hexc("ffffff"))])
    a[..., :3] = g
    n = fbm(SZ, SZ, rng.randint(0, 9999), 20, 3)
    yy = np.linspace(0, 1, SZ)[:, None]
    mist = np.clip((n - 0.4) * 2.6 * (yy * 1.7 - 0.4), 0, 1)
    a[..., :3] = a[..., :3] * (1 - mist[..., None] * 0.6) + mist[..., None] * 0.6 * np.array(hexc("8affd8"))
    # orb roh bercahaya
    orbs = np.zeros((SZ, SZ), np.float32)
    for _ in range(9):
        cv2.circle(orbs, (int(rng.uniform(14, 166)), int(rng.uniform(14, 166))), int(rng.uniform(3, 7)), 1.0, -1)
    gl = glow_of(orbs, 5.0, 2.2)
    a[..., :3] = np.clip(a[..., :3] + gl[..., None] * np.array(hexc("ffa0d0")) * 0.8 + orbs[..., None] * 0.6, 0, 1)
    lay = newlayer(); d = ImageDraw.Draw(lay)
    from skins import petal
    for _ in range(20):
        petal(d, rng.uniform(8, 172) * S, rng.uniform(8, 172) * S, rng.uniform(5, 10) * S, rng.uniform(0, 6.28), (255, 176, 208, 245), (214, 80, 140, 255))
    # ranting sakura sudut kanan atas
    d.line([(184 * S, 26 * S), (150 * S, 20 * S), (118 * S, 2 * S)], fill=(70, 46, 40, 255), width=5 * S)
    for (x, y) in [(150, 20), (134, 12), (166, 24)]:
        for k in range(5):
            ang = k * 2 * math.pi / 5
            petal(d, (x + math.cos(ang) * 7) * S, (y + math.sin(ang) * 7) * S, 7 * S, ang, (255, 150, 190, 255), (200, 70, 120, 255))
        d.ellipse([(x - 3) * S, (y - 3) * S, (x + 3) * S, (y + 3) * S], fill=(255, 232, 110, 255))
    a = overlay_img(a, fin(lay))
    return frame2(a, hexc("3fe0b0"), hexc("ff9ac8"))

# id, nama, rarity, fungsi, harga LV1, upgrade LV2, upgrade LV3
THEMES_FX = [
    ("storm_caller",  "STORMCALLER",   "legendary", t_storm,  1800, 1200, 1800),
    ("spirit_bloom",  "SPIRIT BLOOM",  "legendary", t_spirit, 2000, 1400, 2000),
    ("prismatic",     "PRISMATIC",     "legendary", t_prism,  2200, 1500, 2200),
    ("solar_flare",   "SOLAR FLARE",   "mythic",    t_solar,  2800, 1900, 2800),
    ("void_walker",   "VOID WALKER",   "mythic",    t_void,   3200, 2200, 3200),
]

def make_skin_fx(src_path, theme_idx, seed):
    a = to_arr(load(src_path))
    rng = random.Random(seed)
    out = THEMES_FX[theme_idx][3](a, rng, False)
    return to_img(out)
