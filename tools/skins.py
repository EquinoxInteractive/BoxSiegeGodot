"""10 tema skin karakter. Dipakai untuk 24 karakter -> 240 skin (+ versi _die)."""
import numpy as np, math, random
from PIL import Image, ImageDraw, ImageFilter
import cv2
from artlib import *

SZ = 180
S = 4  # supersample

RARITY_COL = {"common": (200, 205, 220), "rare": (70, 160, 255), "epic": (190, 90, 255), "legendary": (255, 205, 60)}

def base_l(rgb):
    """kecerahan untuk gradient map: campuran luminance + value, supaya warna jenuh (merah/biru) tidak jadi gelap"""
    v = np.max(rgb, axis=-1)
    return np.clip(0.45 * lum(rgb) + 0.55 * v, 0, 1)

def frame(arr, col, width=5, inner=None):
    """bingkai warna di tepi sprite (gaya kartu koleksi)"""
    h, w = arr.shape[:2]
    c = np.array(col, np.float32)
    for i in range(width):
        t = i / max(width - 1, 1)
        k = c * (1.0 - 0.45 * t)
        arr[i, :, :3] = k; arr[h - 1 - i, :, :3] = k; arr[:, i, :3] = k; arr[:, w - 1 - i, :3] = k
    # garis hitam tipis di dalam bingkai
    arr[width, width:w - width, :3] *= 0.35; arr[h - 1 - width, width:w - width, :3] *= 0.35
    arr[width:h - width, width, :3] *= 0.35; arr[width:h - width, w - 1 - width, :3] *= 0.35
    return arr

def overlay_img(arr, im):
    base = to_img(arr)
    base.alpha_composite(im)
    return to_arr(base)

def newlayer():
    return Image.new("RGBA", (SZ * S, SZ * S), (0, 0, 0, 0))

def fin(layer):
    return layer.resize((SZ, SZ), Image.LANCZOS)

def star4(d, cx, cy, r, col):
    pts = [(cx, cy - r), (cx + r * 0.22, cy - r * 0.22), (cx + r, cy), (cx + r * 0.22, cy + r * 0.22),
           (cx, cy + r), (cx - r * 0.22, cy + r * 0.22), (cx - r, cy), (cx - r * 0.22, cy - r * 0.22)]
    d.polygon(pts, fill=col)

# ------------------------------------------------------------------ tema
def t_gold(a, rng, die):
    rgb = a[..., :3]; l = base_l(rgb)
    l = np.clip(l * 0.85 + 0.12, 0, 1)
    g = gradient_map(l, [(0, hexc("2a1700")), (0.35, hexc("a8680c")), (0.65, hexc("f2b522")), (0.88, hexc("ffe27a")), (1, hexc("fffbe0"))])
    # kilap diagonal
    yy, xx = np.mgrid[0:SZ, 0:SZ].astype(np.float32)
    band = np.exp(-(((xx + yy) - 190.0) / 22.0) ** 2) * 0.35
    g = np.clip(g + band[..., None] * np.array([1, 0.95, 0.7]), 0, 1)
    a[..., :3] = g
    lay = newlayer(); d = ImageDraw.Draw(lay)
    for _ in range(7):
        x, y = rng.uniform(14, 166) * S, rng.uniform(14, 166) * S
        star4(d, x, y, rng.uniform(5, 11) * S, (255, 252, 220, 255))
    a = overlay_img(a, fin(lay))
    return frame(a, hexc("ffd23f"), 6)

def t_neon(a, rng, die):
    rgb = a[..., :3]; l = base_l(rgb)
    l = np.clip(l ** 0.9, 0, 1)
    g = gradient_map(l, [(0, hexc("06001a")), (0.3, hexc("5a0a8a")), (0.55, hexc("ff2fb8")), (0.8, hexc("5ef0ff")), (1, hexc("f0ffff"))])
    a[..., :3] = g
    # tepi gelap asli -> garis neon bercahaya
    gx = cv2.Sobel(l, cv2.CV_32F, 1, 0); gy = cv2.Sobel(l, cv2.CV_32F, 0, 1)
    e = np.clip(np.sqrt(gx ** 2 + gy ** 2) * 1.6, 0, 1)
    glow = glow_of(e, 2.2, 1.6)
    a[..., :3] = np.clip(a[..., :3] + glow[..., None] * np.array(hexc("3ff6ff")) * 0.55, 0, 1)
    # scanline halus
    a[::4, :, :3] *= 0.88
    return frame(a, hexc("ff3fd0"), 5)

def icicles(d, rng, w, col, col2):
    x = 6.0
    while x < SZ - 6:
        ww = rng.uniform(7, 15); hh = rng.uniform(14, 42)
        d.polygon([((x) * S, 4 * S), ((x + ww) * S, 4 * S), ((x + ww * 0.5) * S, (4 + hh) * S)], fill=col, outline=col2, width=2 * S // 2)
        x += ww * rng.uniform(0.8, 1.2)

def t_frost(a, rng, die):
    rgb = a[..., :3]; l = base_l(rgb)
    g = gradient_map(np.clip(l * 0.9 + 0.08, 0, 1), [(0, hexc("081a3a")), (0.4, hexc("2f78c8")), (0.75, hexc("9fdcff")), (1, hexc("f4fcff"))])
    a[..., :3] = g
    # salju menumpuk di bagian atas (noise)
    n = fbm(SZ, SZ, rng.randint(0, 9999), 14, 3)
    yy = np.linspace(0, 1, SZ)[:, None]
    snow = np.clip((n - 0.45) * 4.0 * (1.2 - yy * 2.2), 0, 1)
    a[..., :3] = a[..., :3] * (1 - snow[..., None] * 0.8) + snow[..., None] * 0.8
    lay = newlayer(); d = ImageDraw.Draw(lay)
    icicles(d, rng, SZ, (225, 247, 255, 255), (60, 130, 200, 255))
    for _ in range(9):
        x, y = rng.uniform(10, 170) * S, rng.uniform(20, 170) * S
        star4(d, x, y, rng.uniform(4, 9) * S, (255, 255, 255, 235))
    # kristal sudut
    for (cx, cy, sx, sy) in [(0, SZ, 1, -1), (SZ, SZ, -1, -1)]:
        for k in range(5):
            ang = math.radians(rng.uniform(20, 70))
            ln = rng.uniform(18, 40)
            x2 = cx + sx * math.cos(ang) * ln; y2 = cy + sy * math.sin(ang) * ln
            d.line([(cx * S, cy * S), (x2 * S, y2 * S)], fill=(235, 250, 255, 255), width=3 * S)
    a = overlay_img(a, fin(lay))
    return frame(a, hexc("7fd0ff"), 5)

def flames(d, rng, col_outer, col_mid, col_in):
    x = -4.0
    while x < SZ + 4:
        ww = rng.uniform(16, 30); hh = rng.uniform(26, 62)
        for (k, col) in ((1.0, col_outer), (0.7, col_mid), (0.4, col_in)):
            w2 = ww * k; h2 = hh * k
            cx = x + ww * 0.5 + rng.uniform(-3, 3)
            pts = [(cx - w2 * 0.5, SZ + 2), (cx - w2 * 0.35, SZ - h2 * 0.45), (cx - w2 * 0.1 + rng.uniform(-4, 4), SZ - h2 * 0.7),
                   (cx + rng.uniform(-3, 3), SZ - h2), (cx + w2 * 0.15, SZ - h2 * 0.65), (cx + w2 * 0.38, SZ - h2 * 0.4), (cx + w2 * 0.5, SZ + 2)]
            d.polygon([(px * S, py * S) for px, py in pts], fill=col)
        x += ww * rng.uniform(0.7, 1.0)

def t_inferno(a, rng, die):
    rgb = a[..., :3]; l = base_l(rgb)
    g = gradient_map(np.clip(l * 0.95, 0, 1), [(0, hexc("120000")), (0.3, hexc("7a0a05")), (0.6, hexc("e8420a")), (0.85, hexc("ffa51f")), (1, hexc("fff2a8"))])
    a[..., :3] = g
    lay = newlayer(); d = ImageDraw.Draw(lay)
    flames(d, rng, (210, 40, 10, 255), (255, 140, 20, 255), (255, 235, 120, 255))
    for _ in range(14):
        x, y = rng.uniform(5, 175) * S, rng.uniform(30, 150) * S
        r = rng.uniform(1.2, 3.2) * S
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 190, 60, 255))
    a = overlay_img(a, fin(lay))
    return frame(a, hexc("ff7a1f"), 5)

def t_toxic(a, rng, die):
    rgb = a[..., :3]; l = base_l(rgb)
    g = gradient_map(np.clip(l * 0.95, 0, 1), [(0, hexc("031006")), (0.35, hexc("1a6a1a")), (0.7, hexc("7ed321")), (1, hexc("e9ffa8"))])
    a[..., :3] = g
    lay = newlayer(); d = ImageDraw.Draw(lay)
    x = 4.0
    while x < SZ - 8:
        ww = rng.uniform(9, 20); hh = rng.uniform(16, 52)
        d.rounded_rectangle([x * S, -10 * S, (x + ww) * S, hh * S], radius=int(ww * 0.5 * S), fill=(120, 230, 30, 255), outline=(20, 90, 15, 255), width=2 * S)
        d.ellipse([(x - 2) * S, (hh - ww * 0.3) * S, (x + ww + 2) * S, (hh + ww * 0.9) * S], fill=(120, 230, 30, 255), outline=(20, 90, 15, 255), width=2 * S)
        d.ellipse([(x + ww * 0.25) * S, (hh) * S, (x + ww * 0.5) * S, (hh + ww * 0.3) * S], fill=(230, 255, 170, 255))
        x += ww + rng.uniform(4, 16)
    for _ in range(8):
        x, y = rng.uniform(10, 170) * S, rng.uniform(70, 170) * S
        r = rng.uniform(3, 8) * S
        d.ellipse([x - r, y - r, x + r, y + r], outline=(200, 255, 120, 255), width=2 * S)
        d.ellipse([x - r * 0.5, y - r * 0.6, x - r * 0.1, y - r * 0.2], fill=(255, 255, 255, 220))
    a = overlay_img(a, fin(lay))
    return frame(a, hexc("7ed321"), 5)

def t_shadow(a, rng, die):
    rgb = a[..., :3]; l = base_l(rgb)
    l = np.clip(l, 0, 1) ** 1.6
    g = gradient_map(l, [(0, hexc("020006")), (0.25, hexc("1a0f33")), (0.6, hexc("5a3a9a")), (0.9, hexc("d9c2ff")), (1, hexc("ffffff"))])
    a[..., :3] = g
    # kabut ungu di bawah
    n = fbm(SZ, SZ, rng.randint(0, 9999), 18, 3)
    yy = np.linspace(0, 1, SZ)[:, None]
    mist = np.clip((n - 0.35) * 2.4 * (yy * 1.6 - 0.3), 0, 1)
    a[..., :3] = a[..., :3] * (1 - mist[..., None] * 0.7) + mist[..., None] * 0.7 * np.array(hexc("7a4fe0"))
    # vignette
    yy2, xx2 = np.mgrid[0:SZ, 0:SZ].astype(np.float32)
    v = np.clip(1.25 - np.sqrt(((xx2 - 90) / 100) ** 2 + ((yy2 - 90) / 100) ** 2) * 0.55, 0.45, 1)
    a[..., :3] *= v[..., None]
    lay = newlayer(); d = ImageDraw.Draw(lay)
    for _ in range(10):
        x, y = rng.uniform(10, 170) * S, rng.uniform(10, 170) * S
        r = rng.uniform(1.5, 3.5) * S
        d.ellipse([x - r, y - r, x + r, y + r], fill=(190, 150, 255, 200))
    a = overlay_img(a, fin(lay))
    return frame(a, hexc("8a5cff"), 5)

def petal(d, x, y, r, ang, col, col2):
    pts = []
    for k in range(12):
        t = k / 12 * 2 * math.pi
        px = math.cos(t) * r; py = math.sin(t) * r * 0.55
        pts.append((px, py))
    ca, sa = math.cos(ang), math.sin(ang)
    pts = [((x + px * ca - py * sa), (y + px * sa + py * ca)) for px, py in pts]
    d.polygon(pts, fill=col, outline=col2, width=S // 2)

def t_sakura(a, rng, die):
    rgb = a[..., :3]; l = base_l(rgb)
    g = gradient_map(np.clip(l * 0.92 + 0.04, 0, 1), [(0, hexc("3a1030")), (0.4, hexc("d9608f")), (0.75, hexc("ffb7cf")), (1, hexc("fff6f9"))])
    a[..., :3] = g
    lay = newlayer(); d = ImageDraw.Draw(lay)
    for _ in range(16):
        x, y = rng.uniform(8, 172) * S, rng.uniform(8, 172) * S
        petal(d, x, y, rng.uniform(5, 9) * S, rng.uniform(0, 6.28), (255, 183, 207, 255), (220, 90, 140, 255))
    # cabang di pojok kiri atas
    d.line([(-4 * S, 30 * S), (30 * S, 22 * S), (62 * S, 4 * S)], fill=(90, 50, 40, 255), width=5 * S)
    for (x, y) in [(30, 22), (46, 14), (14, 28), (58, 6)]:
        for k in range(5):
            ang = k * 2 * math.pi / 5
            petal(d, (x + math.cos(ang) * 7) * S, (y + math.sin(ang) * 7) * S, 7 * S, ang, (255, 150, 190, 255), (200, 70, 120, 255))
        d.ellipse([(x - 3) * S, (y - 3) * S, (x + 3) * S, (y + 3) * S], fill=(255, 225, 90, 255))
    a = overlay_img(a, fin(lay))
    return frame(a, hexc("ff8fb8"), 4)

def t_glitch(a, rng, die):
    h, w = a.shape[:2]
    out = a.copy()
    # pisah kanal RGB
    out[..., 0] = np.roll(a[..., 0], 4, axis=1)
    out[..., 2] = np.roll(a[..., 2], -4, axis=1)
    # irisan horizontal bergeser
    for _ in range(9):
        y0 = rng.randint(6, h - 24); hh = rng.randint(4, 16); sh = rng.choice([-1, 1]) * rng.randint(6, 26)
        out[y0:y0 + hh] = np.roll(out[y0:y0 + hh], sh, axis=1)
        if rng.random() < 0.5:
            tint = np.array(rng.choice([hexc("ff2fd0"), hexc("2ff0ff")]))
            out[y0:y0 + hh, :, :3] = out[y0:y0 + hh, :, :3] * 0.65 + tint * 0.35
    out[::3, :, :3] *= 0.9
    lay = newlayer(); d = ImageDraw.Draw(lay)
    for _ in range(12):
        x, y = rng.randint(0, 170), rng.randint(0, 170)
        bw, bh = rng.randint(4, 18), rng.randint(3, 9)
        col = rng.choice([(255, 47, 208, 255), (47, 240, 255, 255), (255, 255, 255, 255), (20, 20, 30, 255)])
        d.rectangle([x * S, y * S, (x + bw) * S, (y + bh) * S], fill=col)
    out = overlay_img(out, fin(lay))
    # sirkuit di sudut
    lay2 = newlayer(); d2 = ImageDraw.Draw(lay2)
    for (cx, cy, sx, sy) in [(8, 8, 1, 1), (172, 172, -1, -1)]:
        pts = [(cx, cy + sy * 40), (cx, cy + sy * 14), (cx + sx * 14, cy), (cx + sx * 50, cy)]
        d2.line([(px * S, py * S) for px, py in pts], fill=(47, 240, 255, 255), width=3 * S)
        d2.ellipse([(pts[-1][0] - 4) * S, (pts[-1][1] - 4) * S, (pts[-1][0] + 4) * S, (pts[-1][1] + 4) * S], fill=(255, 47, 208, 255))
    out = overlay_img(out, fin(lay2))
    return frame(out, hexc("2ff0ff"), 4)

def t_cosmic(a, rng, die):
    rgb = a[..., :3]; l = base_l(rgb)
    g = gradient_map(np.clip(l, 0, 1), [(0, hexc("05001a")), (0.3, hexc("2a0e6a")), (0.6, hexc("8a2fd0")), (0.85, hexc("4fd8ff")), (1, hexc("ffffff"))])
    n = fbm(SZ, SZ, rng.randint(0, 9999), 30, 4)
    neb = np.stack([np.clip(n * 1.4 - 0.2, 0, 1) * 0.55, np.clip(n * 0.5, 0, 1) * 0.1, np.clip(n * 1.2, 0, 1) * 0.6], -1)
    a[..., :3] = np.clip(g + neb * (1.0 - l[..., None]) * 0.9, 0, 1)
    lay = newlayer(); d = ImageDraw.Draw(lay)
    for _ in range(60):
        x, y = rng.uniform(3, 177) * S, rng.uniform(3, 177) * S
        r = rng.uniform(0.6, 1.8) * S
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255, int(rng.uniform(150, 255))))
    for _ in range(5):
        x, y = rng.uniform(12, 168) * S, rng.uniform(12, 168) * S
        star4(d, x, y, rng.uniform(6, 12) * S, (255, 255, 255, 255))
    # bintang jatuh
    d.line([(150 * S, 14 * S), (108 * S, 50 * S)], fill=(170, 230, 255, 200), width=2 * S)
    d.ellipse([146 * S, 10 * S, 156 * S, 20 * S], fill=(255, 255, 255, 255))
    a = overlay_img(a, fin(lay))
    # bingkai pelangi
    h, w = a.shape[:2]
    for i in range(6):
        for k in range(w):
            hue = (k / w + i * 0.03) % 1.0
            c = np.array(hsv(hue, 0.55, 1.0), np.float32) * (1 - 0.12 * i)
            a[i, k, :3] = c; a[h - 1 - i, k, :3] = c; a[k, i, :3] = c; a[k, w - 1 - i, :3] = c
    return a

def hsv(h, s, v):
    import colorsys
    return colorsys.hsv_to_rgb(h, s, v)

def t_8bit(a, rng, die):
    img = to_img(a).convert("RGB")
    small = img.resize((36, 36), Image.BOX)
    pal = small.quantize(colors=10, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    big = pal.resize((SZ, SZ), Image.NEAREST)
    arr = np.asarray(big, np.float32) / 255.0
    a[..., :3] = np.clip(arr * 1.08, 0, 1)
    # bingkai pixel tebal bergaya checker
    h, w = a.shape[:2]
    for i in range(6):
        for k in range(w):
            c = 0.95 if ((k // 5) + (i // 5)) % 2 == 0 else 0.25
            a[i, k, :3] = c; a[h - 1 - i, k, :3] = c; a[k, i, :3] = c; a[k, w - 1 - i, :3] = c
    return a

# id, nama, rarity, fungsi
THEMES = [
    ("gold_rush",  "GOLD RUSH",   "legendary", t_gold),
    ("cosmic",     "COSMIC",      "legendary", t_cosmic),
    ("neon_pulse", "NEON PULSE",  "epic",      t_neon),
    ("inferno",    "INFERNO",     "epic",      t_inferno),
    ("glitch",     "GLITCH",      "epic",      t_glitch),
    ("frostbite",  "FROSTBITE",   "rare",      t_frost),
    ("toxic",      "TOXIC",       "rare",      t_toxic),
    ("shadow",     "SHADOW",      "rare",      t_shadow),
    ("sakura",     "SAKURA",      "common",    t_sakura),
    ("pixel8",     "8-BIT",       "common",    t_8bit),
]

def make_skin(src_path, theme_idx, seed):
    im = load(src_path)
    a = to_arr(im)
    rng = random.Random(seed)
    fn = THEMES[theme_idx][3]
    out = fn(a, rng, False)
    return to_img(out)
