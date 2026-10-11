"""Pustaka kecil untuk membuat aset kosmetik BoxSiege (skin karakter, skin senjata, aksesoris).
Semua dihasilkan dari sprite asli lewat recolor + hiasan, supaya gaya tetap sama dengan game."""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import cv2, math, random

def load(path):
    return Image.open(path).convert("RGBA")

def to_arr(im):
    return np.asarray(im, dtype=np.float32) / 255.0

def to_img(a):
    return Image.fromarray((np.clip(a, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGBA")

def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

def lum(rgb):
    return rgb[..., 0] * 0.299 + rgb[..., 1] * 0.587 + rgb[..., 2] * 0.114

def gradient_map(l, stops):
    """l: HxW 0..1 ; stops: [(pos, (r,g,b)), ...] -> HxWx3"""
    pos = np.array([s[0] for s in stops], dtype=np.float32)
    cols = np.array([s[1] for s in stops], dtype=np.float32)
    out = np.zeros(l.shape + (3,), dtype=np.float32)
    for c in range(3):
        out[..., c] = np.interp(l, pos, cols[:, c])
    return out

def rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx = np.max(rgb, axis=-1); mn = np.min(rgb, axis=-1); d = mx - mn
    h = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m & (mx == r), ((g - b) / np.maximum(d, 1e-6)) % 6.0, 0.0)
    gc = np.where(m & (mx == g), (b - r) / np.maximum(d, 1e-6) + 2.0, 0.0)
    bc = np.where(m & (mx == b), (r - g) / np.maximum(d, 1e-6) + 4.0, 0.0)
    h = np.where(mx == r, rc, np.where(mx == g, gc, bc)) / 6.0
    h = np.where(m, h % 1.0, 0.0)
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0.0)
    return h, s, mx

def blend_over(base, over):
    """alpha composite PIL images"""
    out = base.copy()
    out.alpha_composite(over)
    return out

def glow_of(mask, radius, strength=1.0):
    m = cv2.GaussianBlur(mask.astype(np.float32), (0, 0), radius)
    return np.clip(m * strength, 0, 1)

def dilate(mask, r):
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
    return cv2.dilate(mask.astype(np.float32), k)

def erode(mask, r):
    k = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (2 * r + 1, 2 * r + 1))
    return cv2.erode(mask.astype(np.float32), k)

def value_noise(h, w, scale, seed):
    rng = np.random.RandomState(seed)
    gh, gw = max(2, int(h / scale) + 2), max(2, int(w / scale) + 2)
    g = rng.rand(gh, gw).astype(np.float32)
    return cv2.resize(g, (w, h), interpolation=cv2.INTER_CUBIC)

def fbm(h, w, seed, base=24.0, octaves=3):
    out = np.zeros((h, w), np.float32); amp = 1.0; tot = 0.0
    for o in range(octaves):
        out += value_noise(h, w, base / (2 ** o), seed + o * 17) * amp
        tot += amp; amp *= 0.5
    return out / tot

def supersample(size, S=4):
    return Image.new("RGBA", (size[0] * S, size[1] * S), (0, 0, 0, 0))

def down(im, size):
    return im.resize(size, Image.LANCZOS)
