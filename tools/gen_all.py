"""Hasilkan semua aset kosmetik + scripts/cosmetics_data.gd. Jalankan dari folder tools/: python3 gen_all.py"""
import os, sys, random
from PIL import Image, ImageDraw
from artlib import *
import skins, weaponskins, accessories

ROOT = os.path.abspath("..")
CHARS = [("p1","angry"),("p1","melow"),("p1","bandel"),("p1","ninja"),("p2","calm"),("p2","baik"),("p2","silat"),("p2","mime"),
         ("p3","spiderweaver"),("p3","blind"),("p3","joker"),("p3","drunk"),("p4","bald-man"),("p4","savior"),("p4","spiderblack"),("p4","deadswim"),
         ("p1","robot"),("p1","zombie"),("p2","pirate"),("p2","pocong"),("p3","vampire"),("p3","cyclops"),("p4","pumpkin"),("p4","alien")]
EYE_Y = [75,40,40,45,65,40,45,40, 55,45,60,50, 78,45,60,70, 65,60,70,85, 80,90,70,70]
PRICE = {"common":150,"rare":350,"epic":700,"legendary":1400}
WPRICE = {"common":250,"rare":600,"epic":1200,"legendary":2400}

def mk(p): os.makedirs(p, exist_ok=True)

# ---- skin karakter
for ci,(folder,name) in enumerate(CHARS):
    d = f"{ROOT}/assets/sprites/skins/{name}"; mk(d)
    for ti,(tid,tn,ra,fn) in enumerate(skins.THEMES):
        seed = 7000 + ci*101 + ti*13
        for suf in ("", "_die"):
            src = f"{ROOT}/assets/sprites/characters/{folder}/{name}{suf}.png"
            im = skins.make_skin(src, ti, seed)
            im.save(f"{d}/{tid}{suf}.png", optimize=True)
    print("skin", name, flush=True)

# ---- aksesoris
mk(f"{ROOT}/assets/sprites/accessories")
for (aid,nm,slot,pr,ra,layer,fn) in accessories.ACCESSORIES:
    fn().save(f"{ROOT}/assets/sprites/accessories/{aid}.png", optimize=True)

# ---- skin senjata
os.chdir(os.path.join(ROOT, "tools"))
wdata = {}
for wid, lst in weaponskins.SKINS.items():
    mk(f"{ROOT}/assets/sprites/weaponskins/{wid}")
    wdata[wid] = []
    for i, spec in enumerate(lst):
        im, acc = weaponskins.make_weapon_skin(wid, spec, 500 + i * 7 + len(wid))
        im.save(f"{ROOT}/assets/sprites/weaponskins/{wid}/{spec[0]}.png", optimize=True)
        hexacc = "%02x%02x%02x" % tuple(int(c*255) for c in acc)
        if (0.299*acc[0] + 0.587*acc[1] + 0.114*acc[2]) < 0.3:
            hexacc = "ffd23f"      # aksen gelap -> peluru tetap terang & terlihat
        wdata[wid].append((spec[0], spec[1], spec[2], hexacc))
    print("wskin", wid, flush=True)

# ---- koin
S = 4; im = Image.new("RGBA", (96*S, 96*S), (0,0,0,0)); d = ImageDraw.Draw(im)
d.ellipse([6*S,6*S,90*S,90*S], fill=(12,10,18,255))
d.ellipse([10*S,10*S,86*S,86*S], fill=(255,207,42,255))
d.ellipse([20*S,20*S,76*S,76*S], fill=(224,160,28,255), outline=(255,240,150,255), width=3*S)
import math
pts=[]
for i in range(10):
    r = 22 if i%2==0 else 10; a = -math.pi/2 + i*math.pi/5
    pts.append(((48+math.cos(a)*r)*S,(48+math.sin(a)*r)*S))
d.polygon(pts, fill=(255,244,170,255), outline=(150,90,10,255), width=2*S)
d.arc([14*S,14*S,82*S,82*S], 200, 260, fill=(255,255,255,200), width=3*S)
im.resize((96,96), Image.LANCZOS).save(f"{ROOT}/assets/sprites/ui/coin.png")

# ---- katalog GDScript
def q(s): return '"%s"' % s
L = []
L.append("class_name CosmeticsData\nextends RefCounted\n## DIHASILKAN oleh tools/gen_all.py - jangan edit tangan (ubah generatornya lalu jalankan ulang).\n")
L.append("const RARITY_ORDER := [\"common\", \"rare\", \"epic\", \"legendary\"]")
L.append("const EYE_Y := %s" % [e for e in EYE_Y])
L.append("## Tema skin karakter: [id, nama, rarity, harga]  (dipakai untuk SEMUA 24 karakter)")
L.append("const CHAR_SKINS := [")
for tid,tn,ra,fn in skins.THEMES:
    L.append("\t[%s, %s, %s, %d]," % (q(tid), q(tn), q(ra), PRICE[ra]))
L.append("]")
L.append("## Skin senjata per senjata: [id, nama, rarity, harga, warna_peluru_hex]")
L.append("const WEAPON_SKINS := {")
for wid, lst in wdata.items():
    L.append("\t%s: [" % q(wid))
    for sid,sn,ra,hx in lst:
        L.append("\t\t[%s, %s, %s, %d, %s]," % (q(sid), q(sn), q(ra), WPRICE[ra], q(hx)))
    L.append("\t],")
L.append("}")
L.append("## Aksesoris: [id, nama, slot, harga, rarity, layer]   slot: head/face/neck/back")
L.append("const ACCESSORIES := [")
for (aid,nm,slot,pr,ra,layer,fn) in accessories.ACCESSORIES:
    L.append("\t[%s, %s, %s, %d, %s, %s]," % (q(aid), q(nm), q(slot), pr, q(ra), q(layer)))
L.append("]")
open(f"{ROOT}/scripts/cosmetics_data.gd","w").write("\n".join(L)+"\n")
print("DONE")
