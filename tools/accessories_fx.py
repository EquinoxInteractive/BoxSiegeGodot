"""10 aksesoris premium BERANIMASI (sprite dasar di sini; animasinya digambar saat game berjalan: scripts/fx_acc.gd).
Kanvas & koordinat sama dengan accessories.py (kotak karakter = (40,40)-(220,220), tengah x=130)."""
import math, random
from accessories import *

def a_starfall():
    c = Cv(); G = col("ffcf2a"); Gd = col("b87a10"); B = col("4fd8ff")
    c.P([(58, 54), (52, 14), (80, 34), (100, 0), (118, 30), (130, -14), (142, 30), (160, 0), (180, 34), (208, 14), (202, 54)], G)
    c.R(54, 42, 206, 60, Gd, 3)
    c.star(130, 10, 17, col("fff6b0"), 4, K, 5, 0.42)
    for x in (66, 98, 162, 194):
        c.E(x - 7, 44, x + 7, 58, B, 3)
    c.E(54, 4, 68, 18, B, 3); c.E(192, 4, 206, 18, B, 3)
    c.L([(66, 30), (84, 40)], col("fff3a0"), 3)
    return glow(c.out(), (255, 220, 90), 6, 1.0)

def a_stormcloud():
    c = Cv(); Cl = col("4a5578"); Cd = col("2e3552"); Cl2 = col("6a78a0")
    for (x0, y0, x1, y1) in [(70, 6, 130, 52), (104, -14, 170, 46), (140, 8, 200, 54), (56, 22, 112, 58), (122, 24, 190, 60)]:
        c.E(x0, y0, x1, y1, Cl, 5)
    for (x0, y0, x1, y1) in [(70, 6, 130, 52), (104, -14, 170, 46), (140, 8, 200, 54), (56, 22, 112, 58), (122, 24, 190, 60)]:
        c.E(x0 + 5, y0 + 5, x1 - 5, y1 - 8, Cl, 0, None)
    c.R(62, 40, 196, 56, Cd, 8, 0, None)
    c.L([(84, 14), (100, 10)], Cl2, 4); c.L([(150, -2), (166, 6)], Cl2, 4)
    bolt = [(132, 54), (120, 76), (136, 78), (124, 100)]
    c.L(bolt, K, 11); c.L(bolt, col("ffe84a"), 6); c.L(bolt, col("ffffff"), 2)
    return glow(c.out(), (140, 190, 255), 5, 0.6)

def a_hellhorns():
    c = Cv(); R = col("2a0a14"); Ro = col("d4202e"); Y = col("ffb21f")
    def horn(sx):
        def X(x): return 130 + sx * (x - 130)
        c.P([(X(76), 56), (X(54), 28), (X(40), -2), (X(30), -22), (X(62), -6), (X(86), 20), (X(100), 46)], R)
        c.L([(X(78), 46), (X(58), 22), (X(46), -8)], Ro, 4)
        c.L([(X(86), 52), (X(70), 34)], Y, 3)
        c.P([(X(30), -22), (X(26), -34), (X(38), -28)], Y, 3)
    horn(1); horn(-1)
    c.P([(112, 52), (118, 28), (130, 44), (142, 28), (148, 52)], col("ff6a1f"), 4)
    return glow(c.out(), (255, 110, 30), 6, 0.9)

def a_scanvisor():
    c = Cv(); Bk = col("10121c"); Cy = col("40f0ff")
    c.R(50, EY - 20, 210, EY + 18, Bk, 14)
    c.R(58, EY - 13, 202, EY + 11, col("0a3a4a"), 9, 0, None)
    c.R(58, EY - 13, 202, EY - 5, col("1a7a90"), 6, 0, None)
    c.L([(56, EY - 22), (204, EY - 22)], Cy, 3)
    c.L([(56, EY + 20), (204, EY + 20)], Cy, 3)
    c.E(44, EY - 6, 56, EY + 6, Cy, 3); c.E(204, EY - 6, 216, EY + 6, Cy, 3)
    c.L([(40, EY), (22, EY - 6)], K, 5); c.L([(220, EY), (238, EY - 6)], K, 5)
    return glow(c.out(), (64, 240, 255), 4, 0.7)

def _heart(c, cx, cy, s, fill, ow=4):
    pts = []
    for i in range(40):
        t = i / 40 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append((cx + x * s / 16.0, cy + y * s / 16.0))
    c.P(pts, fill, ow)

def a_lovestruck():
    c = Cv(); P = col("ff3d8f"); Pl = col("ffd0e4")
    _heart(c, 96, EY - 2, 44, col("c01a62"), 9)
    _heart(c, 164, EY - 2, 44, col("c01a62"), 9)
    _heart(c, 96, EY - 2, 36, P, 0); _heart(c, 164, EY - 2, 36, P, 0)
    _heart(c, 90, EY - 8, 14, Pl, 0); _heart(c, 158, EY - 8, 14, Pl, 0)
    c.L([(124, EY - 6), (136, EY - 6)], K, 6)
    c.L([(58, EY - 8), (46, EY - 10)], K, 5); c.L([(202, EY - 8), (214, EY - 10)], K, 5)
    return glow(c.out(), (255, 90, 160), 5, 0.8)

def a_arccore():
    c = Cv(); S1 = col("a8b4c8")
    pts = [(50 + 160 * i / 20, 208 + 36 * math.sin(math.pi * i / 20)) for i in range(21)]
    c.L(pts, K, 11); c.L(pts, S1, 6)
    c.E(100, 226, 160, 286, col("2a3040"), 6)
    c.E(108, 234, 152, 278, col("0a1020"), 3)
    c.E(114, 240, 146, 272, col("40d8ff"), 0, None)
    c.E(121, 247, 139, 265, col("e8ffff"), 0, None)
    for k in range(6):
        a = k * math.pi / 3
        c.L([(130 + math.cos(a) * 20, 256 + math.sin(a) * 20), (130 + math.cos(a) * 26, 256 + math.sin(a) * 26)], col("e8ffff"), 3)
    return glow(c.out(), (64, 216, 255), 6, 1.0)

def a_cometscarf():
    c = Cv(); T = col("2fc4d8"); Tl = col("a8f0ff"); V = col("7a3ae0")
    c.P([(32, 204), (228, 204), (236, 240), (24, 240)], T)
    for x in range(50, 214, 26):
        c.L([(x, 208), (x - 6, 238)], Tl, 4)
    c.P([(172, 234), (214, 232), (240, 300), (212, 292), (204, 312), (170, 250)], V)
    for (x, y) in [(200, 262), (216, 282), (190, 250), (72, 222), (130, 226), (168, 220)]:
        c.star(x, y, 6, col("fff6b0"), 0, None, 4, 0.3)
    return glow(c.out(), (110, 240, 255), 4, 0.5)

def a_spiritwings():
    c = Cv()
    def wing(sx):
        def X(x): return 130 + sx * (x - 130)
        feathers = [((X(212), 104), (X(266), 4)), ((X(214), 132), (X(272), 52)), ((X(214), 160), (X(266), 104)), ((X(208), 188), (X(250), 150)), ((X(204), 210), (X(230), 186))]
        for k, (p0, p1) in enumerate(feathers):
            mx = (p0[0] + p1[0]) * 0.5; my = (p0[1] + p1[1]) * 0.5
            nx, ny = -(p1[1] - p0[1]), (p1[0] - p0[0]); ln = math.hypot(nx, ny) or 1
            colr = [col("7af0ff"), col("6ad0ff"), col("8ab4ff"), col("a89cff"), col("c490ff")][k]
            c.P([p0, (mx + nx / ln * 17, my + ny / ln * 17), p1, (mx - nx / ln * 17, my - ny / ln * 17)], colr, 4, col("1a2a5a"))
            c.L([p0, p1], col("f0ffff"), 3)
    wing(1); wing(-1)
    return glow(c.out(), (140, 220, 255), 8, 1.1)

def a_rocketpack():
    c = Cv(); Gy = col("6a7488"); Gd = col("3a4258"); R = col("e03a2a")
    c.R(60, 92, 200, 124, Gd, 8)          # tali dada
    for sx in (1, -1):
        def X(x): return 130 + sx * (x - 130)
        xa, xb = sorted((X(206), X(238)))
        c.R(xa, 70, xb, 196, Gy, 14)
        xa2, xb2 = sorted((X(211), X(233)))
        c.R(xa2, 84, xb2, 100, R, 4, 3)
        c.R(xa2, 110, xb2, 126, Gd, 4, 3)
        c.P([(X(211), 196), (X(233), 196), (X(240), 218), (X(204), 218)], Gd)
        xa3, xb3 = sorted((X(214), X(230)))
        c.E(xa3, 204, xb3, 222, col("ffb21f"), 0, None)
        c.L([(X(206), 110), (X(176), 106)], K, 5)
    return c.out()

def a_eventhorizon():
    c = Cv()
    cx, cy = 130, 130
    for k, (rr, colr) in enumerate([(124, col("3a0a6a")), (112, col("7a2ad0")), (100, col("ff5ad0")), (88, col("ff9a3a"))]):
        c.A(cx - rr, cy - rr, cx + rr, cy + rr, 0, 360, colr, 9)
    for k in range(8):
        a0 = k * 45
        c.A(cx - 106, cy - 106, cx + 106, cy + 106, a0, a0 + 24, col("ffe8ff"), 4)
    img = glow(c.out(), (180, 80, 255), 10, 1.4)
    return img

ACCESSORIES_FX = [
    ("starfall_crown", "STARFALL CROWN", "head", 2800, "mythic", "front", a_starfall),
    ("hellfire_horns", "HELLFIRE HORNS", "head", 2000, "legendary", "front", a_hellhorns),
    ("storm_cloud", "STORM CLOUD", "head", 1400, "epic", "front", a_stormcloud),
    ("scan_visor", "SCAN VISOR", "face", 1300, "epic", "front", a_scanvisor),
    ("love_struck", "LOVE STRUCK", "face", 1800, "legendary", "front", a_lovestruck),
    ("arc_core", "ARC REACTOR", "neck", 1500, "epic", "front", a_arccore),
    ("comet_scarf", "COMET SCARF", "neck", 1900, "legendary", "front", a_cometscarf),
    ("spirit_wings", "SPIRIT WINGS", "back", 3000, "mythic", "back", a_spiritwings),
    ("event_horizon", "EVENT HORIZON", "back", 2600, "mythic", "back", a_eventhorizon),
    ("rocket_pack", "ROCKET PACK", "back", 1200, "epic", "back", a_rocketpack),
]
