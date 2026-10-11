class_name MapVariantsLate
extends RefCounted
## Varian map untuk CHAPTER 4 (variant 3) dan CHAPTER 5 (variant 4). Dunia, sprite, dan palet sama dengan map asli,
## tetapi tata letak dan rintangan berbeda dari Chapter 1-3 supaya tiap chapter terasa baru.
##
## ATURAN KESEIMBANGAN (sama dengan map lain): semua layout SIMETRIS kiri-kanan, spawn pemain dipasangkan, semua platform
## terjangkau lompatan (naik <= 140 px, celah <= 200 px), platform bergerak memakai gerak cermin, dan tidak ada
## rintangan di titik spawn / respawn. Dipanggil lewat MapVariants.get_variant() (variant 3 / 4).
##
## v3 / v4 per dunia:
##   earth   WINDMILL HILL      (bukit + jamur pantul + duri)     / STORM FRONT      (pulau melayang di atas badai)
##   jungle  LIANA LOOP         (lift sulur + duri lantai)        / MOSS TEMPLE      (karpet duri + kayu runtuh)
##   snow    AVALANCHE PASS     (seluruh lantai es licin)         / AURORA LAKE      (danau es tipis + bongkahan hanyut)
##   desert  SCORPION DUNES     (piramida pasir + kaktus)         / PHARAOH'S VAULT  (jembatan runtuh + panah)
##   safari  BAOBAB PLAINS      (batang baobab + duri)            / VULTURE ROCK     (ladang duri + platform ayun)
##   hell    LAVA CASCADE       (pulau + feri di lautan lava)     / DEMON FORGE      (jembatan lava + panah)
##   temple  MOON SANCTUM       (pilar tameng + panah)            / SKULL THRONE     (singgasana di jurang)
##   ocean   COVE OF WRECKS     (geyser + meriam)                 / STORM HARBOR     (dermaga + feri + geyser)
##   space   ASTEROID DOCK      (lift + portal dek atas)          / WARP NEXUS       (portal lantai + lift tengah)
##   factory SCRAP FURNACE      (ban ke kolam lebur + gergaji)    / OMEGA ASSEMBLY   (ban lantai + gergaji kembar)

const W := 1280.0
const TITLES := {
	"earth": ["WINDMILL HILL", "STORM FRONT"],
	"jungle": ["LIANA LOOP", "MOSS TEMPLE"],
	"snow": ["AVALANCHE PASS", "AURORA LAKE"],
	"desert": ["SCORPION DUNES", "PHARAOH'S VAULT"],
	"safari": ["BAOBAB PLAINS", "VULTURE ROCK"],
	"hell": ["LAVA CASCADE", "DEMON FORGE"],
	"temple": ["MOON SANCTUM", "SKULL THRONE"],
	"ocean": ["COVE OF WRECKS", "STORM HARBOR"],
	"space": ["ASTEROID DOCK", "WARP NEXUS"],
	"factory": ["SCRAP FURNACE", "OMEGA ASSEMBLY"],
}


static func has_variant(id: String, variant: int) -> bool:
	return variant >= 3 and variant <= 4 and TITLES.has(id)


## variant 3 = Chapter 4, variant 4 = Chapter 5.
static func get_variant(id: String, variant: int) -> Dictionary:
	var v: int = clampi(variant, 3, 4)
	var m: Dictionary
	match id:
		"earth": m = _earth(v)
		"jungle": m = _jungle(v)
		"snow": m = _snow(v)
		"desert": m = _desert(v)
		"safari": m = _safari(v)
		"hell": m = _hell(v)
		"temple": m = _temple(v)
		"ocean": m = _ocean(v)
		"space": m = _space(v)
		"factory": m = _factory(v)
		_: m = MapData.get_map(id, 0)
	m["variant"] = v
	m["title"] = String((TITLES.get(id, [id.to_upper(), id.to_upper()]) as Array)[v - 3])
	return m


# ------------------------------------------------------------------ helper ringkas
static func _s(l: Array) -> Array:
	return MapData._sym(l)


static func _sd(l: Array) -> Array:
	return MapData._sym_dicts(l)


static func _sm(l: Array) -> Array:
	return MapData._sym_moving(l)


static func _sp_pts(l: Array) -> Array:
	return MapData._sym_pts(l)


static func _traps(y_low: float, y_high: float, first_a: float, first_b: float, interval: float, kind: String = "") -> Array:
	var out: Array = []
	for pair in [[y_low, first_a], [y_high, first_b]]:
		for side in [-1, 1]:
			var d := {"side": side, "y": float(pair[0]), "first": float(pair[1]), "interval": interval}
			if kind != "":
				d["kind"] = kind
			out.append(d)
	return out


# ------------------------------------------------------------------ EARTH
## v3 WINDMILL HILL: bukit piramida di tengah jadi tameng peluru, jamur pantul & duri di lantai.
## v4 STORM FRONT: dua tepi daratan, badai di tengah (jatuh = -1 darah), platform ayun menuju pulau tengah.
static func _earth(v: int) -> Dictionary:
	if v == 3:
		var m := MapVariants._base("earth", "7ad94a", Color(0.95, 0.72, 0.82), Color(1.0, 0.86, 0.9))
		m["solids"] = [Rect2(0, 640, 1280, 80), Rect2(540, 580, 200, 60), Rect2(590, 520, 100, 60)]
		m["platforms"] = _s([Rect2(60, 520, 180, 24), Rect2(290, 440, 170, 24)]) + [Rect2(500, 390, 280, 24)]
		m["bounce"] = _sd([{"rect": Rect2(300, 604, 100, 36), "power": -1000.0}])
		m["spikes"] = _sd([{"rect": Rect2(440, 604, 80, 36), "style": "safari"}])
		m["ambient"] = "leaves"
		m["powerup_spots"] = _sp_pts([Vector2(150, 486), Vector2(375, 406)]) + [Vector2(640, 356), Vector2(640, 486)]
		m["respawn"] = Vector2(640, 340)
		m["spawns"] = MapVariants._sp(Vector2(640, 489), Vector2(150, 489))
		return m
	var a := MapVariants._base("earth", "7ad94a", Color(0.72, 0.9, 0.86), Color(0.84, 0.95, 0.92))
	a["solids"] = _s([Rect2(0, 640, 330, 80)])
	a["platforms"] = _s([Rect2(60, 520, 180, 24), Rect2(300, 430, 160, 24)]) + [Rect2(540, 520, 200, 24), Rect2(520, 390, 240, 24)]
	a["moving"] = _sm([{"rect": Rect2(360, 580, 130, 24), "move": Vector2(40, 0), "period": 5.0, "phase": 0.0}])
	a["lava"] = [Rect2(330, 664, 620, 56)]
	a["lava_colors"] = [Color(0.18, 0.2, 0.36, 0.95), Color(0.55, 0.65, 1.0, 0.9)]
	a["ambient"] = "dust"
	a["powerup_spots"] = _sp_pts([Vector2(150, 486), Vector2(380, 396)]) + [Vector2(640, 356), Vector2(640, 486)]
	a["respawn"] = Vector2(640, 340)
	a["spawns"] = MapVariants._sp(Vector2(640, 359), Vector2(150, 489))
	return a


# ------------------------------------------------------------------ JUNGLE
## v3 LIANA LOOP: lift sulur (platform naik-turun) di tengah menuju dahan puncak, duri di lantai.
## v4 MOSS TEMPLE: karpet duri sepanjang lantai tengah, jalan di atasnya dari kayu runtuh.
static func _jungle(v: int) -> Dictionary:
	if v == 3:
		var m := MapVariants._base("jungle", "8be04e", Color(0.95, 0.74, 0.84), Color(1.0, 0.88, 0.92))
		m["solids"] = [Rect2(0, 640, 1280, 80)]
		m["platforms"] = _s([Rect2(70, 520, 170, 24), Rect2(300, 430, 150, 24), Rect2(120, 330, 150, 24)]) + [Rect2(520, 330, 240, 24)]
		m["moving"] = [{"rect": Rect2(570, 500, 140, 24), "move": Vector2(0, -80), "period": 7.0, "phase": 0.0}]
		m["bounce"] = _sd([{"rect": Rect2(250, 604, 90, 36), "power": -1050.0}])
		m["spikes"] = _sd([{"rect": Rect2(430, 604, 110, 36), "style": "safari"}])
		m["ambient"] = "leaves"
		m["powerup_spots"] = _sp_pts([Vector2(155, 486), Vector2(375, 396), Vector2(195, 296)]) + [Vector2(640, 296)]
		m["respawn"] = Vector2(640, 290)
		m["spawns"] = MapVariants._sp(Vector2(640, 299), Vector2(155, 489))
		return m
	var a := MapVariants._base("jungle", "8be04e", Color(0.72, 0.9, 0.86), Color(0.84, 0.95, 0.9))
	a["solids"] = [Rect2(0, 640, 1280, 80)]
	a["platforms"] = _s([Rect2(60, 520, 180, 24), Rect2(270, 430, 150, 24)]) + [Rect2(510, 330, 260, 24), Rect2(580, 540, 120, 24)]
	a["crumble"] = _s([Rect2(430, 540, 110, 24)])
	a["spikes"] = [{"rect": Rect2(400, 604, 480, 36), "style": "safari"}]
	a["bounce"] = _sd([{"rect": Rect2(260, 604, 90, 36), "power": -1100.0}])
	a["ambient"] = "leaves"
	a["powerup_spots"] = _sp_pts([Vector2(150, 486), Vector2(345, 396)]) + [Vector2(640, 296), Vector2(640, 506)]
	a["respawn"] = Vector2(640, 290)
	a["spawns"] = MapVariants._sp(Vector2(640, 299), Vector2(150, 489))
	return a


# ------------------------------------------------------------------ SNOW
## v3 AVALANCHE PASS: SELURUH lantai es licin, dua bongkah batu es sebagai tameng.
## v4 AURORA LAKE: danau es lebar, lembaran es tipis (runtuh) & bongkahan es hanyut.
static func _snow(v: int) -> Dictionary:
	var cols: Array = [Color(0.12, 0.42, 0.85, 0.93), Color(0.78, 0.95, 1.0, 0.95)]
	if v == 3:
		var m := MapVariants._base("snow", "e8f6ff", Color(0.8, 0.82, 1.0), Color(0.86, 0.9, 1.0))
		m["solids"] = [Rect2(0, 640, 1280, 80)] + _s([Rect2(290, 540, 120, 100)])
		m["platforms"] = _s([Rect2(60, 520, 170, 24), Rect2(430, 430, 150, 24)]) + [Rect2(560, 330, 160, 24)]
		m["ice"] = [Rect2(0, 640, 1280, 8)] + _s([Rect2(430, 430, 150, 8), Rect2(290, 540, 120, 8)]) + [Rect2(560, 330, 160, 8)]
		m["ambient"] = "snow"
		m["powerup_spots"] = _sp_pts([Vector2(150, 486), Vector2(350, 506), Vector2(505, 396)]) + [Vector2(640, 296), Vector2(640, 606)]
		m["respawn"] = Vector2(640, 280)
		m["spawns"] = MapVariants._sp(Vector2(640, 299), Vector2(150, 489))
		return m
	var a := MapVariants._base("snow", "e8f6ff", Color(0.72, 0.9, 0.95), Color(0.84, 0.95, 0.98))
	a["solids"] = _s([Rect2(0, 640, 300, 80)])
	a["platforms"] = _s([Rect2(60, 520, 190, 24), Rect2(300, 430, 170, 24)]) + [Rect2(540, 340, 200, 24)]
	a["crumble"] = [Rect2(330, 596, 110, 24), Rect2(585, 596, 110, 24), Rect2(840, 596, 110, 24)]
	a["moving"] = _sm([{"rect": Rect2(460, 540, 100, 24), "move": Vector2(30, 0), "period": 5.5, "phase": 0.0}])
	a["ice"] = _s([Rect2(300, 430, 170, 8), Rect2(150, 640, 150, 8)]) + [Rect2(540, 340, 200, 8)]
	a["lava"] = [Rect2(300, 664, 680, 56)]
	a["lava_colors"] = cols
	a["ambient"] = "snow"
	a["powerup_spots"] = _sp_pts([Vector2(155, 486), Vector2(385, 396)]) + [Vector2(640, 306), Vector2(640, 562)]
	a["respawn"] = Vector2(640, 290)
	a["spawns"] = MapVariants._sp(Vector2(640, 309), Vector2(155, 489))
	return a


# ------------------------------------------------------------------ DESERT
## v3 SCORPION DUNES: piramida pasir bertingkat di tengah, kaktus di lantai, batu runtuh menuju puncak.
## v4 PHARAOH'S VAULT: pasir hisap di tengah, jembatan batu (tepi runtuh), kaktus & panah dinding.
static func _desert(v: int) -> Dictionary:
	if v == 3:
		var m := MapVariants._base("desert", "f2c777", Color(0.95, 0.76, 0.7), Color(0.97, 0.86, 0.8))
		m["solids"] = [Rect2(0, 640, 1280, 80), Rect2(480, 590, 320, 50), Rect2(540, 540, 200, 50), Rect2(590, 490, 100, 50)]
		m["platforms"] = _s([Rect2(60, 510, 170, 24)]) + [Rect2(500, 380, 280, 24)]
		m["crumble"] = _s([Rect2(290, 440, 150, 24)])
		m["spikes"] = _sd([{"rect": Rect2(260, 586, 72, 54), "style": "cactus"}])
		m["ambient"] = "dust"
		m["powerup_spots"] = _sp_pts([Vector2(145, 476), Vector2(365, 406)]) + [Vector2(640, 346), Vector2(640, 456)]
		m["respawn"] = Vector2(640, 330)
		m["spawns"] = MapVariants._sp(Vector2(640, 459), Vector2(145, 479))
		return m
	var a := MapVariants._base("desert", "f2c777", Color(0.9, 0.84, 0.66), Color(0.95, 0.9, 0.78))
	a["solids"] = _s([Rect2(0, 640, 420, 80)])
	a["platforms"] = _s([Rect2(60, 510, 190, 24), Rect2(300, 440, 150, 24)]) + [Rect2(520, 340, 240, 24), Rect2(580, 590, 120, 24)]
	a["crumble"] = _s([Rect2(450, 590, 110, 24)])
	a["spikes"] = _sd([{"rect": Rect2(310, 586, 72, 54), "style": "cactus"}])
	a["traps"] = _traps(612.0, 612.0, 8.0, 8.0, 10.0).slice(0, 2)
	a["lava"] = [Rect2(420, 664, 440, 56)]
	a["lava_colors"] = [Color(0.85, 0.6, 0.25, 0.95), Color(1.0, 0.86, 0.5, 0.9)]
	a["ambient"] = "dust"
	a["powerup_spots"] = _sp_pts([Vector2(155, 476), Vector2(375, 406)]) + [Vector2(640, 306), Vector2(640, 556)]
	a["respawn"] = Vector2(640, 290)
	a["spawns"] = MapVariants._sp(Vector2(640, 309), Vector2(155, 479))
	return a


# ------------------------------------------------------------------ SAFARI
## v3 BAOBAB PLAINS: batang baobab bertangga di tengah, lajur duri dengan platform ayun di kedua sisi.
## v4 VULTURE ROCK: seluruh lantai tengah adalah ladang duri; seberangi lewat platform ayun & batu tinggi.
static func _safari(v: int) -> Dictionary:
	if v == 3:
		var m := MapVariants._base("safari", "f0d078", Color(0.95, 0.78, 0.72), Color(0.97, 0.88, 0.82))
		m["solids"] = [Rect2(0, 640, 1280, 80), Rect2(560, 560, 160, 80), Rect2(600, 480, 80, 80)]
		m["platforms"] = _s([Rect2(60, 530, 160, 24), Rect2(270, 440, 160, 24)]) + [Rect2(500, 380, 280, 24)]
		m["moving"] = _sm([{"rect": Rect2(410, 550, 100, 24), "move": Vector2(40, 0), "period": 4.6, "phase": 0.0}])
		m["spikes"] = _sd([{"rect": Rect2(390, 604, 140, 36), "style": "safari"}])
		m["ambient"] = "dust"
		m["powerup_spots"] = _sp_pts([Vector2(140, 496), Vector2(350, 406)]) + [Vector2(640, 346), Vector2(640, 446)]
		m["respawn"] = Vector2(640, 330)
		m["spawns"] = MapVariants._sp(Vector2(640, 449), Vector2(140, 499))
		return m
	var a := MapVariants._base("safari", "f0d078", Color(0.85, 0.78, 0.7), Color(0.9, 0.86, 0.8))
	a["solids"] = [Rect2(0, 640, 1280, 80)]
	a["platforms"] = _s([Rect2(60, 520, 150, 24), Rect2(290, 420, 150, 24)]) + [Rect2(540, 500, 200, 24), Rect2(520, 320, 240, 24)]
	a["moving"] = _sm([{"rect": Rect2(350, 540, 110, 24), "move": Vector2(20, 0), "period": 4.0, "phase": 0.0}])
	a["spikes"] = [{"rect": Rect2(330, 604, 620, 36), "style": "safari"}]
	a["ambient"] = "dust"
	a["powerup_spots"] = _sp_pts([Vector2(135, 486), Vector2(365, 386)]) + [Vector2(640, 286), Vector2(640, 466)]
	a["respawn"] = Vector2(640, 270)
	a["spawns"] = MapVariants._sp(Vector2(640, 289), Vector2(135, 489))
	return a


# ------------------------------------------------------------------ HELL
## v3 LAVA CASCADE: lautan lava penuh; dua pulau kecil di sisi + pulau tengah, dihubungkan platform feri.
## v4 DEMON FORGE: jurang lava di tengah dengan jembatan (tepi runtuh) dan panah dinding di dua ketinggian.
static func _hell(v: int) -> Dictionary:
	if v == 3:
		var m := MapVariants._base("hell", "ff6a1a", Color(1.0, 0.7, 0.7), Color(1.0, 0.82, 0.82))
		m["solids"] = _s([Rect2(80, 640, 200, 80)]) + [Rect2(520, 640, 240, 80)]
		m["lava"] = _s([Rect2(0, 664, 80, 56), Rect2(280, 664, 240, 56)])
		m["platforms"] = _s([Rect2(80, 520, 170, 24), Rect2(300, 430, 150, 24)]) + [Rect2(540, 420, 200, 24), Rect2(580, 540, 120, 24)]
		m["moving"] = _sm([{"rect": Rect2(330, 600, 110, 24), "move": Vector2(40, 0), "period": 5.0, "phase": 0.0}])
		m["ambient"] = "sparks"
		m["powerup_spots"] = _sp_pts([Vector2(165, 486), Vector2(375, 396)]) + [Vector2(640, 386), Vector2(640, 506)]
		m["respawn"] = Vector2(640, 380)
		m["spawns"] = MapVariants._sp(Vector2(640, 609), Vector2(165, 489))
		return m
	var a := MapVariants._base("hell", "ff6a1a", Color(1.0, 0.76, 0.66), Color(1.0, 0.86, 0.78))
	a["solids"] = _s([Rect2(0, 640, 480, 80)])
	a["platforms"] = _s([Rect2(60, 520, 180, 24), Rect2(290, 430, 150, 24)]) + [Rect2(540, 330, 200, 24), Rect2(600, 596, 80, 24)]
	a["crumble"] = _s([Rect2(500, 596, 100, 24)])
	a["lava"] = [Rect2(480, 664, 320, 56)]
	a["traps"] = _traps(612.0, 470.0, 8.0, 12.0, 10.0)
	a["ambient"] = "sparks"
	a["powerup_spots"] = _sp_pts([Vector2(150, 486), Vector2(365, 396)]) + [Vector2(640, 296), Vector2(640, 562)]
	a["respawn"] = Vector2(640, 290)
	a["spawns"] = MapVariants._sp(Vector2(640, 299), Vector2(150, 489))
	return a


# ------------------------------------------------------------------ TEMPLE
## v3 MOON SANCTUM: dua pilar batu tinggi jadi tameng peluru, duri di tengah lantai, panah di dua ketinggian.
## v4 SKULL THRONE: singgasana bertangga di pulau tengah, jurang gelap di kedua sisi, duri & panah.
static func _temple(v: int) -> Dictionary:
	if v == 3:
		var m := MapVariants._base("temple", "f2e6b0", Color(0.82, 0.74, 0.95), Color(0.88, 0.84, 0.97))
		m["solids"] = [Rect2(0, 640, 1280, 80)] + _s([Rect2(330, 480, 80, 160)])
		m["platforms"] = _s([Rect2(60, 530, 170, 24)]) + [Rect2(520, 420, 240, 24)]
		m["spikes"] = [{"rect": Rect2(560, 604, 160, 36), "style": "temple"}]
		m["traps"] = _traps(612.0, 450.0, 8.0, 12.0, 10.0)
		m["ambient"] = "motes"
		m["powerup_spots"] = _sp_pts([Vector2(145, 496), Vector2(370, 446)]) + [Vector2(640, 386)]
		m["respawn"] = Vector2(640, 350)
		m["spawns"] = MapVariants._sp(Vector2(640, 389), Vector2(145, 499))
		return m
	var a := MapVariants._base("temple", "f2e6b0", Color(0.74, 0.7, 0.9), Color(0.82, 0.8, 0.94))
	a["solids"] = _s([Rect2(0, 640, 360, 80)]) + [Rect2(520, 640, 240, 80), Rect2(560, 580, 160, 60), Rect2(600, 520, 80, 60)]
	a["platforms"] = _s([Rect2(60, 530, 170, 24), Rect2(260, 440, 150, 24)]) + [Rect2(500, 400, 280, 24)]
	a["spikes"] = _sd([{"rect": Rect2(250, 604, 80, 36), "style": "temple"}])
	a["traps"] = _traps(612.0, 470.0, 7.0, 11.0, 9.0)
	a["lava"] = _s([Rect2(360, 664, 160, 56)])
	a["lava_colors"] = [Color(0.25, 0.1, 0.38, 0.95), Color(0.62, 0.3, 0.92, 0.9)]
	a["ambient"] = "motes"
	a["powerup_spots"] = _sp_pts([Vector2(145, 496), Vector2(335, 406)]) + [Vector2(640, 366), Vector2(640, 486)]
	a["respawn"] = Vector2(640, 360)
	a["spawns"] = MapVariants._sp(Vector2(640, 489), Vector2(145, 499))
	return a


# ------------------------------------------------------------------ OCEAN
## v3 COVE OF WRECKS: dek penuh, geyser di sisi tengah mengangkat ke dek atas, meriam di dua ketinggian.
## v4 STORM HARBOR: dua dermaga, laut di tengah, feri menuju dek tengah dengan geyser ke dek puncak.
static func _ocean(v: int) -> Dictionary:
	var wcols: Array = [Color(0.05, 0.38, 0.62, 0.93), Color(0.7, 0.95, 1.0, 0.95)]
	var gey := {"kind": "geyser", "first": 3.0, "rest": 3.4, "warn": 1.0, "active": 1.5, "lift": 4600.0}
	if v == 3:
		var m := MapVariants._base("ocean", "f2c27a", Color(0.8, 0.82, 1.0), Color(0.88, 0.9, 1.0))
		m["solids"] = [Rect2(0, 640, 1280, 80)]
		m["platforms"] = _s([Rect2(60, 520, 170, 24), Rect2(300, 440, 150, 24)]) + [Rect2(500, 350, 280, 24)]
		var g1: Dictionary = gey.duplicate()
		g1["rect"] = Rect2(450, 380, 80, 260)
		g1["rise"] = 560.0
		m["vents"] = MapData._sym_vents([g1])
		m["traps"] = _traps(590.0, 420.0, 6.0, 10.0, 9.0, "cannon")
		m["ambient"] = "bubbles"
		m["powerup_spots"] = _sp_pts([Vector2(145, 486), Vector2(375, 406)]) + [Vector2(640, 316), Vector2(640, 606)]
		m["respawn"] = Vector2(640, 300)
		m["spawns"] = MapVariants._sp(Vector2(640, 319), Vector2(145, 489))
		return m
	var a := MapVariants._base("ocean", "f2c27a", Color(0.72, 0.88, 0.95), Color(0.84, 0.94, 0.98))
	a["solids"] = _s([Rect2(0, 640, 280, 80)])
	a["platforms"] = _s([Rect2(60, 520, 170, 24), Rect2(290, 430, 150, 24)]) + [Rect2(540, 560, 200, 24), Rect2(520, 350, 240, 24)]
	a["moving"] = _sm([{"rect": Rect2(310, 590, 110, 24), "move": Vector2(30, 0), "period": 5.0, "phase": 0.0}])
	var g2: Dictionary = gey.duplicate()
	g2["rect"] = Rect2(590, 360, 100, 200)
	g2["rise"] = 520.0
	a["vents"] = [g2]
	a["traps"] = _traps(590.0, 400.0, 6.0, 10.0, 9.0, "cannon")
	a["lava"] = [Rect2(280, 664, 720, 56)]
	a["lava_colors"] = wcols
	a["ambient"] = "bubbles"
	a["powerup_spots"] = _sp_pts([Vector2(145, 486), Vector2(365, 396)]) + [Vector2(640, 316), Vector2(640, 526)]
	a["respawn"] = Vector2(640, 300)
	a["spawns"] = MapVariants._sp(Vector2(640, 529), Vector2(145, 489))
	return a


# ------------------------------------------------------------------ SPACE
## v3 ASTEROID DOCK: lift anti-gravitasi di sisi menuju dek atas, portal di dek kiri-kanan, dek puncak tengah.
## v4 WARP NEXUS: dua pasang portal (lantai & dek) menghubungkan kedua sisi, lift tengah ke dek puncak.
static func _space(v: int) -> Dictionary:
	if v == 3:
		var m := MapVariants._base("space", "5bf0ff", Color(0.9, 0.85, 1.0), Color(0.94, 0.9, 1.0))
		m["solids"] = [Rect2(0, 640, 1280, 80)]
		m["platforms"] = _s([Rect2(60, 520, 150, 24), Rect2(300, 400, 160, 24)]) + [Rect2(520, 290, 240, 24)]
		m["vents"] = MapData._sym_vents([{"rect": Rect2(220, 320, 70, 320), "kind": "antigrav", "first": 0.0, "rest": 0.0, "warn": 0.0, "active": 0.0, "lift": 3400.0, "rise": 400.0}])
		var pa := Rect2(150, 464, 56, 56)
		m["portals"] = [{"a": pa, "b": MapData._m(pa), "color": Color("ff7bff")}]
		m["ambient"] = "stars"
		m["powerup_spots"] = _sp_pts([Vector2(100, 486), Vector2(380, 366), Vector2(500, 606)]) + [Vector2(640, 256)]
		m["respawn"] = Vector2(640, 230)
		m["spawns"] = MapVariants._sp(Vector2(640, 259), Vector2(100, 489))
		return m
	var a := MapVariants._base("space", "5bf0ff", Color(0.78, 0.9, 0.95), Color(0.88, 0.94, 0.98))
	a["solids"] = [Rect2(0, 640, 1280, 80)]
	a["platforms"] = _s([Rect2(60, 520, 150, 24), Rect2(300, 420, 140, 24)]) + [Rect2(540, 300, 200, 24)]
	a["vents"] = [{"rect": Rect2(590, 310, 100, 330), "kind": "antigrav", "first": 0.0, "rest": 0.0, "warn": 0.0, "active": 0.0, "lift": 3400.0, "rise": 400.0}]
	var pf := Rect2(260, 580, 56, 60)
	var pd := Rect2(380, 364, 56, 56)
	a["portals"] = [
		{"a": pf, "b": MapData._m(pf), "color": Color("ff7bff")},
		{"a": pd, "b": MapData._m(pd), "color": Color("5bf0ff")},
	]
	a["ambient"] = "stars"
	a["powerup_spots"] = _sp_pts([Vector2(135, 486), Vector2(370, 386), Vector2(480, 606)]) + [Vector2(640, 266)]
	a["respawn"] = Vector2(640, 250)
	a["spawns"] = MapVariants._sp(Vector2(640, 269), Vector2(135, 489))
	return a


# ------------------------------------------------------------------ FACTORY
## v3 SCRAP FURNACE: ban berjalan menyeret ke kolam lebur di tengah, jembatan pendek dengan gergaji naik-turun.
## v4 OMEGA ASSEMBLY: ban lantai panjang menuju gergaji kembar di tengah, ban juga di platform tengah.
static func _factory(v: int) -> Dictionary:
	if v == 3:
		var m := MapVariants._base("factory", "ffc933", Color(0.95, 0.78, 0.78), Color(0.97, 0.86, 0.86))
		m["solids"] = _s([Rect2(0, 640, 540, 80)])
		m["lava"] = [Rect2(540, 664, 200, 56)]
		m["lava_colors"] = [Color(1.0, 0.45, 0.1, 0.95), Color(1.0, 0.85, 0.3, 0.9)]
		m["platforms"] = _s([Rect2(60, 520, 200, 24), Rect2(330, 430, 170, 24)]) + [Rect2(540, 520, 200, 24), Rect2(540, 340, 200, 24)]
		m["conveyors"] = MapData._sym_conv([
			{"rect": Rect2(300, 640, 240, 10), "speed": 130.0},
			{"rect": Rect2(60, 520, 200, 10), "speed": -90.0},
		])
		m["saws"] = [{"pos": Vector2(640, 450), "move": Vector2(0, 40), "period": 4.0, "phase": 0.0, "radius": 24.0}]
		m["ambient"] = "sparks"
		m["powerup_spots"] = _sp_pts([Vector2(160, 486), Vector2(415, 396)]) + [Vector2(640, 306)]
		m["respawn"] = Vector2(640, 290)
		m["spawns"] = MapVariants._sp(Vector2(640, 309), Vector2(160, 489))
		return m
	var a := MapVariants._base("factory", "ffc933", Color(0.72, 0.82, 0.9), Color(0.84, 0.9, 0.95))
	a["solids"] = [Rect2(0, 640, 1280, 80)]
	a["platforms"] = _s([Rect2(60, 520, 180, 24), Rect2(300, 430, 170, 24)]) + [Rect2(540, 330, 200, 24)]
	a["conveyors"] = MapData._sym_conv([
		{"rect": Rect2(100, 640, 400, 10), "speed": 150.0},
		{"rect": Rect2(300, 430, 170, 10), "speed": 100.0},
	])
	a["saws"] = MapData._sym_saws([{"pos": Vector2(560, 612), "move": Vector2(30, 0), "period": 4.5, "phase": 0.0, "radius": 26.0}])
	a["ambient"] = "sparks"
	a["powerup_spots"] = _sp_pts([Vector2(150, 486), Vector2(385, 396)]) + [Vector2(640, 296), Vector2(640, 606)]
	a["respawn"] = Vector2(640, 280)
	a["spawns"] = MapVariants._sp(Vector2(640, 299), Vector2(150, 489))
	return a
