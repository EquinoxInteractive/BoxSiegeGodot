"""32 aksesoris (kanvas 260x260; kotak karakter 180x180 ada di tengah: (40,40)-(220,220)).
Slot: head (10), face (9), neck (7), back (6). Gambar vektor bergaris tepi hitam, gaya sama dengan sprite karakter."""
import math, random
from PIL import Image, ImageDraw, ImageFilter
import numpy as np
from artlib import *

C = 340
OFF = 40
S = 4
K = (12, 10, 18, 255)       # warna garis tepi
OW = 5 * S                  # tebal garis tepi

def col(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)

def sh(c, k):
    return (int(min(255, c[0] * k)), int(min(255, c[1] * k)), int(min(255, c[2] * k)), c[3])

class Cv:
    def __init__(self):
        self.im = Image.new("RGBA", (C * S, C * S), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)
    @staticmethod
    def q(pts):
        return [((x + OFF) * S, (y + OFF) * S) for x, y in pts]
    def P(self, pts, fill, ow=OW, outline=K):
        self.d.polygon(self.q(pts), fill=fill, outline=outline, width=ow)
    def E(self, x0, y0, x1, y1, fill, ow=OW, outline=K):
        self.d.ellipse([(x0 + OFF) * S, (y0 + OFF) * S, (x1 + OFF) * S, (y1 + OFF) * S], fill=fill, outline=outline, width=ow)
    def R(self, x0, y0, x1, y1, fill, r=0, ow=OW, outline=K):
        box = [(x0 + OFF) * S, (y0 + OFF) * S, (x1 + OFF) * S, (y1 + OFF) * S]
        if r > 0:
            self.d.rounded_rectangle(box, radius=r * S, fill=fill, outline=outline, width=ow)
        else:
            self.d.rectangle(box, fill=fill, outline=outline, width=ow)
    def L(self, pts, fill, w=4):
        self.d.line(self.q(pts), fill=fill, width=int(w * S), joint="curve")
    def A(self, x0, y0, x1, y1, a0, a1, fill, w=4):
        self.d.arc([(x0 + OFF) * S, (y0 + OFF) * S, (x1 + OFF) * S, (y1 + OFF) * S], a0, a1, fill=fill, width=int(w * S))
    def star(self, cx, cy, r, fill, ow=OW, outline=K, n=5, inner=0.45):
        pts = []
        for i in range(n * 2):
            rr = r if i % 2 == 0 else r * inner
            a = -math.pi / 2 + i * math.pi / n
            pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
        self.P(pts, fill, ow, outline)
    def out(self):
        return self.im.resize((C, C), Image.LANCZOS)

def glow(im, color, radius, strength=1.0):
    a = np.asarray(im, np.float32)[..., 3] / 255.0
    g = cv2.GaussianBlur(a, (0, 0), radius) * strength
    lay = np.zeros((im.size[1], im.size[0], 4), np.float32)
    lay[..., 0] = color[0] / 255.0; lay[..., 1] = color[1] / 255.0; lay[..., 2] = color[2] / 255.0
    lay[..., 3] = np.clip(g, 0, 1)
    base = Image.fromarray((lay * 255).astype(np.uint8), "RGBA")
    base.alpha_composite(im)
    return base

# =============================================================== HEAD (dasar kepala = y 40)
def a_crown():
    c = Cv(); G = col("ffcf2a"); Gd = col("c98a10")
    c.P([(62, 52), (62, 10), (88, 32), (110, 4), (130, 32), (152, 4), (172, 32), (198, 10), (198, 52)], G)
    c.R(60, 40, 200, 56, Gd, 3)
    c.E(120, 14, 140, 34, col("ff2d4a")); c.E(56, 6, 70, 20, col("4fd8ff"), 3); c.E(190, 6, 204, 20, col("4fd8ff"), 3)
    c.E(84, 41, 96, 53, col("4fd8ff"), 3); c.E(164, 41, 176, 53, col("4fd8ff"), 3)
    c.L([(70, 30), (84, 40)], col("fff3a0"), 3)
    return c.out()

def a_tophat():
    c = Cv()
    c.R(78, -2, 182, 36, col("23232e"), 4)
    c.R(78, 22, 182, 36, col("c82030"), 0, 4)
    c.R(58, 34, 202, 50, col("23232e"), 6)
    c.L([(90, 4), (90, 20)], col("55556a"), 4)
    return c.out()

def a_party():
    c = Cv()
    c.P([(84, 48), (130, -22), (176, 48)], col("ff5fa8"))
    for i, cc in enumerate(["4fd8ff", "ffd23f", "4fd8ff"]):
        pass
    c.L([(100, 24), (150, 24)], col("ffd23f"), 6); c.L([(92, 38), (160, 38)], col("4fd8ff"), 6)
    c.E(114, -34, 146, -4, col("ffd23f"))
    c.E(120, -28, 130, -18, col("fff6c0"), 0, None)
    return c.out()

def a_halo():
    c = Cv()
    c.A(62, -18, 198, 30, 0, 360, K, 17)
    c.A(62, -18, 198, 30, 0, 360, col("ffe14a"), 9)
    c.A(66, -14, 194, 26, 200, 330, col("fffbd0"), 3)
    return glow(c.out(), (255, 230, 90), 6, 1.4)

def a_horns():
    c = Cv(); R = col("e0202c")
    c.P([(60, 52), (46, 22), (36, -4), (68, 12), (92, 40)], R)
    c.P([(200, 52), (214, 22), (224, -4), (192, 12), (168, 40)], R)
    c.L([(50, 22), (62, 40)], col("ff8a8a"), 3); c.L([(210, 22), (198, 40)], col("ff8a8a"), 3)
    return c.out()

def a_cowboy():
    c = Cv(); B = col("8a5a2c"); Bd = col("5e3a18")
    c.P([(76, 40), (82, 6), (100, 0), (130, 12), (160, 0), (178, 6), (184, 40)], B)
    c.P([(30, 28), (60, 46), (130, 52), (200, 46), (230, 28), (222, 56), (130, 62), (38, 56)], Bd)
    c.R(80, 28, 180, 42, col("2a1a0c"), 0, 3)
    c.R(120, 26, 140, 44, col("ffd23f"), 2, 3)
    return c.out()

def a_wizard():
    c = Cv(); P = col("5a2fc8")
    c.P([(64, 48), (118, -10), (150, -44), (162, -14), (196, 48)], P)
    c.P([(150, -44), (160, -52), (172, -40), (162, -14)], sh(P, 1.2))
    c.P([(30, 46), (130, 40), (230, 46), (210, 62), (130, 56), (50, 62)], sh(P, 0.8))
    c.star(130, 20, 14, col("ffe14a"), 3); c.star(104, 36, 8, col("ffe14a"), 2); c.star(158, 8, 7, col("ffe14a"), 2)
    c.E(168, -4, 178, 6, col("fff6c0"), 0, None)
    return c.out()

def a_viking():
    c = Cv(); M = col("9aa3b8")
    c.P([(60, 48), (64, 18), (88, 2), (130, -4), (172, 2), (196, 18), (200, 48)], M)
    c.R(58, 38, 202, 54, col("6a738a"), 3, 4)
    c.P([(66, 30), (30, 24), (16, -10), (44, -2), (62, 8), (78, 20)], col("f2ead2"))
    c.P([(194, 30), (230, 24), (244, -10), (216, -2), (198, 8), (182, 20)], col("f2ead2"))
    c.L([(100, 4), (100, 36)], col("c5cde0"), 3)
    c.E(124, 20, 136, 32, col("ffd23f"), 3)
    return c.out()

def a_catears():
    c = Cv(); P = col("ff6fb5")
    c.P([(56, 52), (52, 6), (98, 38)], col("23232e"))
    c.P([(204, 52), (208, 6), (162, 38)], col("23232e"))
    c.P([(64, 42), (62, 18), (86, 38)], P); c.P([(196, 42), (198, 18), (174, 38)], P)
    c.R(56, 40, 204, 54, P, 6, 4)
    c.L([(82, 46), (178, 46)], col("ffc0e0"), 3)
    return c.out()

def a_chef():
    c = Cv(); W = col("fbfbff")
    c.R(78, 20, 182, 52, W, 3)
    for cx, cy, r in [(88, 4, 28), (130, -10, 34), (172, 4, 28), (110, 6, 26), (150, 6, 26)]:
        c.E(cx - r, cy - r + 14, cx + r, cy + r + 14, W, 4)
    c.R(78, 36, 182, 52, col("dfe3f0"), 3, 4)
    c.L([(100, 38), (100, 50)], col("b7bdd0"), 3); c.L([(130, 38), (130, 50)], col("b7bdd0"), 3); c.L([(160, 38), (160, 50)], col("b7bdd0"), 3)
    return c.out()

# =============================================================== FACE (pusat mata = y 110, tinggi 90 relatif; digeser per karakter)
EY = 100   # y garis mata di kanvas

def a_sunglasses():
    c = Cv(); Bk = col("14141c")
    c.R(60, EY - 18, 124, EY + 16, Bk, 10); c.R(136, EY - 18, 200, EY + 16, Bk, 10)
    c.R(122, EY - 10, 138, EY - 2, Bk, 0, 3)
    c.L([(66, EY - 10), (84, EY - 10)], col("6a6a8a"), 4); c.L([(142, EY - 10), (160, EY - 10)], col("6a6a8a"), 4)
    c.L([(46, EY - 8), (60, EY - 6)], K, 5); c.L([(200, EY - 6), (214, EY - 8)], K, 5)
    return c.out()

def a_nerd():
    c = Cv(); F = col("2a2a34")
    c.E(62, EY - 24, 122, EY + 28, col("cfeaff", 90), 6); c.E(138, EY - 24, 198, EY + 28, col("cfeaff", 90), 6)
    c.L([(122, EY), (138, EY)], K, 6)
    c.L([(70, EY - 12), (84, EY - 18)], col("ffffff", 200), 3); c.L([(146, EY - 12), (160, EY - 18)], col("ffffff", 200), 3)
    c.L([(48, EY - 4), (62, EY - 2)], K, 5); c.L([(198, EY - 2), (212, EY - 4)], K, 5)
    return c.out()

def a_monocle():
    c = Cv(); G = col("ffcf2a")
    c.E(138, EY - 30, 206, EY + 34, K, 0, None)
    c.E(143, EY - 25, 201, EY + 29, col("d8f4ff", 110), 9, G)
    c.L([(158, EY - 12), (176, EY - 18)], col("ffffff", 230), 3)
    c.L([(172, EY + 34), (178, EY + 58), (168, EY + 82), (176, EY + 106)], K, 7)
    c.L([(172, EY + 34), (178, EY + 58), (168, EY + 82), (176, EY + 106)], G, 3)
    return c.out()

def a_3d():
    c = Cv()
    c.R(54, EY - 20, 206, EY + 22, col("f2f2f6"), 8)
    c.R(66, EY - 12, 118, EY + 14, col("ff2d2d"), 4); c.R(142, EY - 12, 194, EY + 14, col("2dd8ff"), 4)
    c.L([(74, EY - 6), (96, EY - 6)], col("ffffff", 160), 3); c.L([(150, EY - 6), (172, EY - 6)], col("ffffff", 160), 3)
    return c.out()

def a_mustache():
    c = Cv(); B = col("3a2314")
    my = EY + 36
    c.P([(130, my - 6), (112, my - 14), (84, my - 10), (60, my - 24), (50, my - 12), (66, my + 8), (96, my + 10), (122, my + 6), (130, my + 4),
         (138, my + 6), (164, my + 10), (194, my + 8), (210, my - 12), (200, my - 24), (176, my - 10), (148, my - 14)], B)
    c.L([(100, my - 4), (80, my - 8)], col("7a5438"), 3); c.L([(160, my - 4), (180, my - 8)], col("7a5438"), 3)
    return c.out()

def a_heart():
    c = Cv(); P = col("ff4f9a")
    def heart(cx, cy, s):
        pts = []
        for i in range(40):
            t = i / 40 * 2 * math.pi
            x = 16 * math.sin(t) ** 3
            y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
            pts.append((cx + x * s, cy + y * s))
        c.P(pts, col("ff4f9a", 235))
        c.E(cx - 14 * s, cy - 12 * s, cx - 6 * s, cy - 6 * s, col("ffffff", 200), 0, None)
    heart(92, EY + 2, 2.1); heart(168, EY + 2, 2.1)
    c.L([(116, EY - 4), (144, EY - 4)], K, 6)
    return c.out()

def a_visor():
    c = Cv()
    c.R(52, EY - 18, 208, EY + 18, col("1a2a3a"), 12)
    c.R(62, EY - 9, 198, EY + 9, col("3ff0ff"), 6, 0)
    c.L([(70, EY), (190, EY)], col("e8ffff"), 3)
    c.R(40, EY - 8, 54, EY + 8, col("3a4a5a"), 3, 4); c.R(206, EY - 8, 220, EY + 8, col("3a4a5a"), 3, 4)
    return glow(c.out(), (63, 240, 255), 5, 1.2)

def a_clownnose():
    c = Cv()
    c.E(106, EY + 14, 154, EY + 62, col("ff2d3a"), 5)
    c.E(116, EY + 22, 130, EY + 34, col("ffb0b0", 230), 0, None)
    return c.out()

def a_bandage():
    c = Cv(); B = col("f2c9a0")
    c.P([(150, EY + 22), (176, EY + 6), (204, EY + 24), (178, EY + 40)], B, 4)
    c.L([(160, EY + 20), (192, EY + 28)], col("d9a878"), 3); c.L([(162, EY + 30), (186, EY + 16)], col("d9a878"), 3)
    c.E(172, EY + 17, 180, EY + 25, col("f6dcc0"), 0, None)
    return c.out()

# =============================================================== NECK (di tepi bawah kotak, y 220)
def a_scarf():
    c = Cv(); R = col("e02a3a")
    c.P([(34, 206), (226, 206), (232, 238), (28, 238)], R)
    for x in range(52, 214, 28):
        c.L([(x, 208), (x - 6, 236)], col("ffb0b6"), 4)
    c.P([(176, 232), (214, 232), (222, 292), (192, 284), (186, 296), (166, 238)], sh(R, 0.9))
    c.L([(184, 252), (210, 256)], col("ffb0b6"), 3); c.L([(186, 270), (212, 274)], col("ffb0b6"), 3)
    return c.out()

def a_bowtie():
    c = Cv(); R = col("d0202e")
    c.P([(130, 226), (84, 204), (84, 248)], R); c.P([(130, 226), (176, 204), (176, 248)], R)
    c.R(120, 214, 140, 238, sh(R, 0.8), 5, 4)
    c.L([(92, 218), (112, 224)], col("ff8a92"), 3); c.L([(168, 218), (148, 224)], col("ff8a92"), 3)
    return c.out()

def a_chain():
    c = Cv(); G = col("ffcf2a")
    pts = []
    for i in range(21):
        t = i / 20
        x = 50 + 160 * t; y = 210 + 40 * math.sin(math.pi * t)
        pts.append((x, y))
    c.L(pts, K, 11); c.L(pts, G, 6)
    for (x, y) in pts[2:-2:3]:
        c.E(x - 4, y - 4, x + 4, y + 4, col("fff0a0"), 2)
    c.E(110, 238, 150, 278, G, 5); c.E(118, 246, 142, 270, col("c98a10"), 3)
    c.star(130, 258, 9, col("fff3a0"), 2)
    return c.out()

def a_medal():
    c = Cv()
    c.P([(96, 206), (126, 206), (140, 250), (112, 250)], col("2d6cff")); c.P([(164, 206), (134, 206), (120, 250), (148, 250)], col("e02a3a"))
    c.E(100, 240, 160, 300, col("ffcf2a"), 5)
    c.E(110, 250, 150, 290, col("e0a41c"), 3)
    c.star(130, 270, 16, col("fff3a0"), 3)
    return c.out()

def a_bell():
    c = Cv()
    c.R(34, 206, 226, 224, col("ff4f6a"), 8, 4)
    c.L([(54, 215), (206, 215)], col("ffb0c0"), 3)
    c.E(106, 220, 154, 268, col("ffcf2a"), 5)
    c.L([(112, 244), (148, 244)], col("c98a10"), 3); c.E(124, 250, 136, 262, col("5e3a08"), 0, None)
    c.E(116, 228, 128, 240, col("fff6c0", 220), 0, None)
    return c.out()

def a_dogtag():
    c = Cv()
    pts = [(56 + 148 * i / 20, 210 + 34 * math.sin(math.pi * i / 20)) for i in range(21)]
    c.L(pts, K, 9); c.L(pts, col("b8c0d0"), 5)
    c.R(106, 244, 154, 288, col("aab4c8"), 9, 5)
    c.L([(116, 258), (144, 258)], col("4a5468"), 4); c.L([(116, 270), (140, 270)], col("4a5468"), 4)
    c.L([(112, 250), (130, 250)], col("e8eefc"), 3)
    return c.out()

# =============================================================== BACK (di belakang sprite)
def a_cape():
    c = Cv(); R = col("d4202e")
    c.P([(52, 52), (208, 52), (248, 240), (226, 256), (196, 244), (166, 258), (130, 244), (94, 258), (64, 244), (34, 256), (12, 240)], R)
    c.P([(88, 70), (172, 70), (190, 200), (130, 190), (70, 200)], sh(R, 0.82), 0)
    c.L([(30, 220), (50, 100)], col("ff8a92"), 3); c.L([(230, 220), (210, 100)], col("ff8a92"), 3)
    return c.out()

def a_angel():
    c = Cv(); W = col("fbfbff")
    def wing(sx):
        def X(x): return 130 + sx * (x - 130)
        feathers = [((X(212), 110), (X(258), 20)), ((X(214), 140), (X(256), 66)), ((X(214), 170), (X(250), 110)), ((X(206), 198), (X(238), 150))]
        for (p0, p1) in feathers:
            mx = (p0[0] + p1[0]) * 0.5; my = (p0[1] + p1[1]) * 0.5
            nx, ny = -(p1[1] - p0[1]), (p1[0] - p0[0]); ln = math.hypot(nx, ny) or 1
            c.P([p0, (mx + nx / ln * 14, my + ny / ln * 14), p1, (mx - nx / ln * 14, my - ny / ln * 14)], W, 4)
    wing(1); wing(-1)
    return glow(c.out(), (255, 245, 180), 5, 0.9)

def a_bat():
    c = Cv(); D = col("3a2a5a")
    def wing(sx):
        def X(x): return 130 + sx * (x - 130)
        pts = [(X(210), 92), (X(240), 52), (X(258), 10), (X(246), 70), (X(256), 112), (X(238), 100), (X(236), 150), (X(222), 134), (X(214), 178), (X(200), 150)]
        c.P(pts, D)
        c.L([(X(214), 100), (X(250), 22)], col("7a5ab8"), 3); c.L([(X(214), 120), (X(248), 112)], col("7a5ab8"), 3); c.L([(X(210), 140), (X(228), 160)], col("7a5ab8"), 3)
    wing(1); wing(-1)
    return c.out()

def a_flame():
    c = Cv(); rng = random.Random(5)
    for layer, (cc, k) in enumerate([(col("e03a10"), 1.0), (col("ff9a1f"), 0.72), (col("ffe27a"), 0.44)]):
        x = 8
        while x < 252:
            w = rng.uniform(26, 44) * k + 10; h = rng.uniform(50, 96) * k + 14
            side = 40 if (x < 40 or x > 220) else 0
            top = 8 + (0 if side else 20)
            base_y = 200 if not side else 226
            cx = x + w * 0.5
            pts = [(x, base_y), (x + w * 0.2, base_y - h * 0.7), (cx - 4, base_y - h * 1.15 - side * 1.5), (cx + 6, base_y - h * 0.85), (x + w * 0.85, base_y - h * 0.5), (x + w, base_y)]
            if layer == 0:
                c.P(pts, cc, 4)
            else:
                c.P(pts, cc, 0, None)
            x += w * 0.7
    return glow(c.out(), (255, 160, 40), 8, 1.1)

def a_frost():
    c = Cv(); rng = random.Random(9)
    for (cx, cy, ln, ang) in [(30, 150, 74, 200), (230, 150, 74, -20), (40, 90, 62, 235), (220, 90, 62, -55), (34, 205, 60, 170), (226, 205, 60, 10), (130, 8, 56, 270)]:
        a = math.radians(ang); nx, ny = -math.sin(a), math.cos(a)
        tipx, tipy = cx + math.cos(a) * ln, cy + math.sin(a) * ln
        c.P([(cx + nx * 11, cy + ny * 11), (tipx, tipy), (cx - nx * 11, cy - ny * 11), (cx - math.cos(a) * 8, cy - math.sin(a) * 8)], col("a8e6ff"), 4)
        c.L([(cx, cy), (tipx - math.cos(a) * 12, tipy - math.sin(a) * 12)], col("f2fcff"), 3)
    for _ in range(10):
        x, y = rng.choice([rng.uniform(4, 36), rng.uniform(224, 256)]), rng.uniform(30, 230)
        c.star(x, y, rng.uniform(4, 8), col("ffffff"), 0, None, 4, 0.25)
    return glow(c.out(), (120, 210, 255), 6, 1.0)

def a_lightning():
    c = Cv(); Y = col("ffe84a")
    def bolt(pts):
        c.L(pts, K, 11); c.L(pts, Y, 6); c.L(pts, col("ffffff"), 2)
    bolt([(36, 30), (22, 70), (46, 82), (26, 128), (50, 138), (30, 190)])
    bolt([(224, 30), (238, 74), (214, 84), (234, 130), (210, 142), (230, 196)])
    bolt([(130, 4), (116, 28), (136, 34), (122, 54)])
    return glow(c.out(), (255, 230, 70), 7, 1.2)

# id, nombre, slot, harga, rarity, layer, fungsi
ACCESSORIES = [
    ("crown", "ROYAL CROWN", "head", 900, "legendary", "front", a_crown),
    ("tophat", "TOP HAT", "head", 300, "common", "front", a_tophat),
    ("party_hat", "PARTY HAT", "head", 150, "common", "front", a_party),
    ("halo", "HOLY HALO", "head", 700, "epic", "front", a_halo),
    ("devil_horns", "DEVIL HORNS", "head", 450, "rare", "front", a_horns),
    ("cowboy_hat", "COWBOY HAT", "head", 300, "common", "front", a_cowboy),
    ("wizard_hat", "WIZARD HAT", "head", 600, "rare", "front", a_wizard),
    ("viking_helm", "VIKING HELM", "head", 550, "rare", "front", a_viking),
    ("cat_ears", "CAT EARS", "head", 350, "common", "front", a_catears),
    ("chef_hat", "CHEF HAT", "head", 250, "common", "front", a_chef),
    ("sunglasses", "COOL SHADES", "face", 250, "common", "front", a_sunglasses),
    ("nerd_glasses", "NERD GLASSES", "face", 200, "common", "front", a_nerd),
    ("monocle", "GENTLE MONOCLE", "face", 400, "rare", "front", a_monocle),
    ("glasses_3d", "3D GLASSES", "face", 300, "common", "front", a_3d),
    ("mustache", "BIG MUSTACHE", "face", 250, "common", "front", a_mustache),
    ("heart_glasses", "HEART SHADES", "face", 450, "rare", "front", a_heart),
    ("cyber_visor", "CYBER VISOR", "face", 800, "epic", "front", a_visor),
    ("clown_nose", "CLOWN NOSE", "face", 150, "common", "front", a_clownnose),
    ("bandage", "BATTLE PATCH", "face", 150, "common", "front", a_bandage),
    ("scarf", "RED SCARF", "neck", 300, "common", "front", a_scarf),
    ("bowtie", "BOW TIE", "neck", 250, "common", "front", a_bowtie),
    ("gold_chain", "GOLD CHAIN", "neck", 750, "epic", "front", a_chain),
    ("hero_medal", "HERO MEDAL", "neck", 500, "rare", "front", a_medal),
    ("bell_collar", "BELL COLLAR", "neck", 200, "common", "front", a_bell),
    ("dog_tag", "DOG TAG", "neck", 350, "rare", "front", a_dogtag),
    ("hero_cape", "HERO CAPE", "back", 650, "epic", "back", a_cape),
    ("angel_wings", "ANGEL WINGS", "back", 1200, "legendary", "back", a_angel),
    ("bat_wings", "BAT WINGS", "back", 900, "epic", "back", a_bat),
    ("flame_aura", "FLAME AURA", "back", 1000, "legendary", "back", a_flame),
    ("frost_aura", "FROST SPIKES", "back", 800, "epic", "back", a_frost),
    ("thunder_aura", "THUNDER AURA", "back", 850, "epic", "back", a_lightning),
]
