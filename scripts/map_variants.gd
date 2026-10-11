class_name MapVariants
extends RefCounted
## Varian map untuk CHAPTER 2 (variant 1) dan CHAPTER 3 (variant 2). Chapter 4 & 5 (variant 3 & 4): lihat map_variants_late.gd. Dunia, sprite, dan palet sama dengan map asli,
## tetapi tata letak, rintangan, dan warna (tint) berbeda supaya tiap chapter terasa baru.
##
## ATURAN KESEIMBANGAN (sama dengan map asli): semua layout SIMETRIS kiri-kanan (_sym*), spawn pemain dipasangkan,
## semua platform terjangkau lompatan (naik maks ~144 px, jarak maks ~250 px; di sini dipakai naik <= 140 & celah <= 200),
## platform bergerak memakai gerak cermin, dan tidak ada rintangan di titik spawn / respawn.
##
## Kunci tambahan khusus campaign: "tint" (warna latar), "floor_tint" (warna ubin).

const W := 1280.0
const CHAPTER_TITLES := {
	"earth": ["TWIN HILLS", "ACID FIELDS"],
	"jungle": ["VINE BRIDGE", "THORN CANOPY"],
	"snow": ["TWIN POOLS", "BLIZZARD RIDGE"],
	"desert": ["OASIS RUINS", "SANDSTORM CANYON"],
	"safari": ["ROCK KOPJE", "BONE VALLEY"],
	"hell": ["MAGMA ISLES", "MAGMA CAGE"],
	"temple": ["SUN COURT", "SERPENT PIT"],
	"ocean": ["SUNKEN DECK", "KRAKEN MAW"],
	"space": ["DOCKING BAY", "REACTOR CORE"],
	"factory": ["SMELTER", "SHREDDER"],
}


static func has_variant(id: String, variant: int) -> bool:
	if variant >= 3:
		return MapVariantsLate.has_variant(id, variant)
	return variant >= 1 and variant <= 2 and CHAPTER_TITLES.has(id)


static func get_variant(id: String, variant: int) -> Dictionary:
	if variant >= 3:
		return MapVariantsLate.get_variant(id, variant)   # Chapter 4 & 5 (scripts/map_variants_late.gd)
	var v: int = clampi(variant, 1, 2)
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
	m["title"] = String((CHAPTER_TITLES.get(id, [id.to_upper(), id.to_upper()]) as Array)[v - 1])
	return m


# ------------------------------------------------------------------ helper
static func _sp(mid: Vector2, side: Vector2) -> Dictionary:
	var l := Vector2(150, 609)
	var r := Vector2(1130, 609)
	return {
		2: [l, r],
		3: [l, r, mid],
		4: [l, r, side, Vector2(W - side.x, side.y)],
	}


static func _base(id: String, edge: String, tint: Color, floor_tint: Color = Color.WHITE) -> Dictionary:
	return {
		"id": id,
		"background": "res://assets/sprites/stages/%s.png" % id,
		"floor": "res://assets/sprites/stages/%s_floor.png" % id,
		"edge_color": Color(edge),
		"tint": tint,
		"floor_tint": floor_tint,
		"solids": [],
		"platforms": [],
		"lava": [],
	}


# ------------------------------------------------------------------ EARTH
## v1 TWIN HILLS: dua bukit rendah jadi pelindung peluru, platform tengah bertingkat.
## v2 ACID FIELDS: kolam asam di tengah (jatuh = -1 darah) dengan jembatan bergerak.
static func _earth(v: int) -> Dictionary:
	if v == 1:
		var m := _base("earth", "5cc43a", Color(1.0, 0.88, 0.78), Color(1.0, 0.94, 0.88))
		m["solids"] = [Rect2(0, 640, 1280, 80)] + MapData._sym([Rect2(330, 584, 170, 56)])
		m["platforms"] = MapData._sym([
			Rect2(60, 520, 180, 24),
			Rect2(280, 460, 170, 24),
			Rect2(570, 500, 140, 24),
			Rect2(500, 370, 280, 24),
		])
		m["ambient"] = "dust"
		m["powerup_spots"] = MapData._sym_pts([Vector2(150, 486), Vector2(365, 426), Vector2(640, 336), Vector2(415, 550), Vector2(640, 466)])
		m["respawn"] = Vector2(640, 330)
		m["spawns"] = _sp(Vector2(640, 339), Vector2(150, 489))
		return m
	var a := _base("earth", "7ad94a", Color(0.7, 0.8, 0.92), Color(0.82, 0.9, 0.95))
	a["solids"] = MapData._sym([Rect2(0, 640, 440, 80)])
	a["platforms"] = MapData._sym([
		Rect2(60, 530, 200, 24),
		Rect2(340, 450, 190, 24),
		Rect2(110, 350, 170, 24),
		Rect2(540, 340, 200, 24),
	])
	a["moving"] = [{"rect": Rect2(560, 590, 160, 24), "move": Vector2(110, 0), "period": 6.4, "phase": 0.0}]
	a["lava"] = [Rect2(440, 664, 400, 56)]
	a["lava_colors"] = [Color(0.25, 0.62, 0.2, 0.93), Color(0.72, 1.0, 0.5, 0.95)]
	a["ambient"] = "bubbles"
	a["powerup_spots"] = MapData._sym_pts([Vector2(160, 496), Vector2(435, 416), Vector2(195, 316), Vector2(640, 306)])
	a["respawn"] = Vector2(640, 300)
	a["spawns"] = _sp(Vector2(640, 309), Vector2(160, 499))
	return a


# ------------------------------------------------------------------ JUNGLE
## v1 VINE BRIDGE: jamur pantul ke dahan tinggi, kayu ayun & lift tengah.
## v2 THORN CANOPY: duri tengah lantai, jamur lebih kuat, satu kayu menyeberangi duri.
static func _jungle(v: int) -> Dictionary:
	if v == 1:
		var m := _base("jungle", "8be04e", Color(1.0, 0.92, 0.78), Color(1.0, 0.96, 0.88))
		m["solids"] = [Rect2(0, 640, 1280, 80)]
		m["platforms"] = MapData._sym([
			Rect2(300, 510, 150, 24),
			Rect2(80, 360, 200, 24),
		]) + [Rect2(520, 290, 240, 24)]
		m["moving"] = MapData._sym_moving([
			{"rect": Rect2(330, 420, 140, 24), "move": Vector2(40, 0), "period": 6.0, "phase": 0.0},
		]) + [{"rect": Rect2(570, 470, 140, 24), "move": Vector2(0, -80), "period": 7.0, "phase": 0.0}]
		m["bounce"] = MapData._sym_dicts([{"rect": Rect2(120, 604, 100, 36), "power": -1050.0}])
		m["ambient"] = "leaves"
		m["powerup_spots"] = MapData._sym_pts([Vector2(375, 476), Vector2(180, 326), Vector2(640, 256), Vector2(250, 606)])
		m["respawn"] = Vector2(640, 250)
		m["spawns"] = _sp(Vector2(640, 259), Vector2(375, 479))
		return m
	var a := _base("jungle", "8be04e", Color(0.68, 0.8, 0.95), Color(0.8, 0.9, 0.95))
	a["solids"] = [Rect2(0, 640, 1280, 80)]
	a["platforms"] = MapData._sym([
		Rect2(60, 530, 150, 24),
		Rect2(250, 440, 160, 24),
		Rect2(70, 340, 160, 24),
	]) + [Rect2(500, 330, 280, 24)]
	a["moving"] = MapData._sym_moving([{"rect": Rect2(570, 560, 140, 24), "move": Vector2(90, 0), "period": 5.0, "phase": 0.0}])
	a["spikes"] = [{"rect": Rect2(540, 604, 200, 36), "style": "safari"}]
	a["bounce"] = MapData._sym_dicts([{"rect": Rect2(330, 604, 100, 36), "power": -1100.0}])
	a["ambient"] = "leaves"
	a["powerup_spots"] = MapData._sym_pts([Vector2(135, 496), Vector2(330, 406), Vector2(150, 306), Vector2(640, 296)])
	a["respawn"] = Vector2(640, 290)
	a["spawns"] = _sp(Vector2(640, 299), Vector2(135, 499))
	return a


# ------------------------------------------------------------------ SNOW
## v1 TWIN POOLS: dua kolam air es di kiri-kanan pulau tengah, bongkahan es hanyut di tiap kolam.
## v2 BLIZZARD RIDGE: jurang air lebar, es rapuh di tengah, dua bongkahan es hanyut.
static func _snow(v: int) -> Dictionary:
	var cols: Array = [Color(0.12, 0.42, 0.85, 0.93), Color(0.78, 0.95, 1.0, 0.95)]
	if v == 1:
		var m := _base("snow", "e8f6ff", Color(1.0, 0.88, 0.9), Color(1.0, 0.94, 0.96))
		m["solids"] = MapData._sym([Rect2(0, 640, 300, 80)]) + [Rect2(540, 640, 200, 80)]
		m["platforms"] = MapData._sym([
			Rect2(60, 530, 190, 24),
			Rect2(330, 440, 170, 24),
			Rect2(100, 340, 170, 24),
		]) + [Rect2(520, 350, 240, 24)]
		m["moving"] = MapData._sym_moving([{"rect": Rect2(350, 596, 120, 24), "move": Vector2(30, 0), "period": 6.0, "phase": 0.0}])
		m["ice"] = MapData._sym([Rect2(210, 640, 90, 8), Rect2(330, 440, 170, 8)]) + [Rect2(540, 640, 200, 8), Rect2(520, 350, 240, 8)]
		m["lava"] = MapData._sym([Rect2(300, 664, 240, 56)])
		m["lava_colors"] = cols
		m["ambient"] = "snow"
		m["powerup_spots"] = MapData._sym_pts([Vector2(155, 496), Vector2(415, 406), Vector2(185, 306), Vector2(640, 316), Vector2(640, 606)])
		m["respawn"] = Vector2(640, 300)
		m["spawns"] = _sp(Vector2(640, 319), Vector2(155, 499))
		return m
	var a := _base("snow", "e8f6ff", Color(0.72, 0.8, 1.0), Color(0.82, 0.88, 1.0))
	a["solids"] = MapData._sym([Rect2(0, 640, 380, 80)])
	a["platforms"] = MapData._sym([
		Rect2(60, 530, 190, 24),
		Rect2(330, 430, 170, 24),
		Rect2(100, 330, 170, 24),
	]) + [Rect2(540, 320, 200, 24)]
	a["crumble"] = [Rect2(570, 590, 140, 24)]
	a["moving"] = MapData._sym_moving([{"rect": Rect2(420, 580, 110, 24), "move": Vector2(30, 0), "period": 5.5, "phase": 0.0}])
	a["ice"] = MapData._sym([Rect2(300, 640, 80, 8), Rect2(330, 430, 170, 8)]) + [Rect2(540, 320, 200, 8)]
	a["lava"] = [Rect2(380, 664, 520, 56)]
	a["lava_colors"] = cols
	a["ambient"] = "snow"
	a["powerup_spots"] = MapData._sym_pts([Vector2(155, 496), Vector2(415, 396), Vector2(185, 296), Vector2(640, 286)])
	a["respawn"] = Vector2(640, 270)
	a["spawns"] = _sp(Vector2(640, 289), Vector2(155, 499))
	return a


# ------------------------------------------------------------------ DESERT
## v1 OASIS RUINS: kaktus kecil, platform runtuh bertingkat menuju puncak tengah.
## v2 SANDSTORM CANYON: pasir hisap di tengah, jembatan runtuh, pulau batu kecil.
static func _desert(v: int) -> Dictionary:
	if v == 1:
		var m := _base("desert", "f2c777", Color(1.0, 0.88, 0.78), Color(1.0, 0.94, 0.88))
		m["solids"] = [Rect2(0, 640, 1280, 80)]
		m["platforms"] = MapData._sym([Rect2(70, 520, 180, 24)]) + [Rect2(500, 360, 280, 24)]
		m["crumble"] = MapData._sym([Rect2(300, 450, 150, 24), Rect2(80, 390, 150, 24)])
		m["spikes"] = MapData._sym_dicts([{"rect": Rect2(310, 586, 72, 54), "style": "cactus"}]) + [{"rect": Rect2(604, 586, 72, 54), "style": "cactus"}]
		m["ambient"] = "dust"
		m["powerup_spots"] = MapData._sym_pts([Vector2(160, 486), Vector2(375, 416), Vector2(640, 326), Vector2(480, 606)])
		m["respawn"] = Vector2(640, 320)
		m["spawns"] = _sp(Vector2(640, 329), Vector2(160, 489))
		return m
	var a := _base("desert", "f2c777", Color(0.92, 0.78, 0.74), Color(0.95, 0.85, 0.82))
	a["solids"] = MapData._sym([Rect2(0, 640, 400, 80)]) + [Rect2(560, 640, 160, 80)]
	a["platforms"] = MapData._sym([
		Rect2(60, 530, 190, 24),
		Rect2(330, 440, 160, 24),
	]) + [Rect2(540, 350, 200, 24)]
	a["crumble"] = MapData._sym([Rect2(420, 585, 110, 24), Rect2(90, 350, 150, 24)])
	a["spikes"] = MapData._sym_dicts([{"rect": Rect2(250, 586, 72, 54), "style": "cactus"}])
	a["lava"] = [Rect2(400, 664, 480, 56)]
	a["lava_colors"] = [Color(0.85, 0.6, 0.25, 0.95), Color(1.0, 0.86, 0.5, 0.9)]
	a["ambient"] = "dust"
	a["powerup_spots"] = MapData._sym_pts([Vector2(155, 496), Vector2(410, 406), Vector2(640, 316), Vector2(640, 606)])
	a["respawn"] = Vector2(640, 300)
	a["spawns"] = _sp(Vector2(640, 319), Vector2(155, 499))
	return a


# ------------------------------------------------------------------ SAFARI
## v1 ROCK KOPJE: batu bertingkat, dua lajur duri dengan platform ayun, pijakan aman di tengah.
## v2 BONE VALLEY: lajur duri panjang, platform ayun lebih cepat, celah lantai sempit.
static func _safari(v: int) -> Dictionary:
	if v == 1:
		var m := _base("safari", "f0d078", Color(1.0, 0.88, 0.76), Color(1.0, 0.94, 0.86))
		m["solids"] = [Rect2(0, 640, 1280, 80)]
		m["platforms"] = MapData._sym([
			Rect2(60, 520, 170, 24),
			Rect2(250, 420, 170, 24),
		]) + [Rect2(480, 330, 320, 24), Rect2(580, 540, 120, 24)]
		m["moving"] = MapData._sym_moving([{"rect": Rect2(340, 560, 120, 24), "move": Vector2(30, 0), "period": 4.5, "phase": 0.0}])
		m["spikes"] = MapData._sym_dicts([{"rect": Rect2(330, 604, 140, 36), "style": "safari"}]) + [{"rect": Rect2(560, 604, 160, 36), "style": "safari"}]
		m["ambient"] = "dust"
		m["powerup_spots"] = MapData._sym_pts([Vector2(145, 486), Vector2(335, 386), Vector2(640, 296), Vector2(640, 506), Vector2(250, 606)])
		m["respawn"] = Vector2(640, 290)
		m["spawns"] = _sp(Vector2(640, 299), Vector2(145, 489))
		return m
	var a := _base("safari", "f0d078", Color(0.9, 0.76, 0.78), Color(0.93, 0.84, 0.84))
	a["solids"] = [Rect2(0, 640, 1280, 80)]
	a["platforms"] = MapData._sym([
		Rect2(60, 520, 140, 24),
		Rect2(330, 430, 170, 24),
		Rect2(80, 400, 150, 24),
	]) + [Rect2(520, 340, 240, 24)]
	a["moving"] = MapData._sym_moving([{"rect": Rect2(210, 560, 120, 24), "move": Vector2(50, 0), "period": 4.2, "phase": 0.0}])
	a["spikes"] = MapData._sym_dicts([{"rect": Rect2(200, 604, 200, 36), "style": "safari"}]) + [{"rect": Rect2(540, 604, 200, 36), "style": "safari"}]
	a["ambient"] = "dust"
	a["powerup_spots"] = MapData._sym_pts([Vector2(130, 486), Vector2(415, 396), Vector2(155, 366), Vector2(640, 306), Vector2(470, 606)])
	a["respawn"] = Vector2(640, 300)
	a["spawns"] = _sp(Vector2(640, 309), Vector2(130, 489))
	return a


# ------------------------------------------------------------------ HELL
## v1 MAGMA ISLES: dua kolam lava, batu pijakan rapuh, pulau tengah.
## v2 MAGMA CAGE: lautan lava dengan pilar tengah dan menara platform bertingkat.
static func _hell(v: int) -> Dictionary:
	if v == 1:
		var m := _base("hell", "ff6a1a", Color(1.0, 0.82, 0.76), Color(1.0, 0.9, 0.86))
		m["solids"] = MapData._sym([Rect2(0, 640, 320, 80)]) + [Rect2(520, 640, 240, 80)]
		m["platforms"] = MapData._sym([
			Rect2(60, 530, 190, 24),
			Rect2(300, 440, 170, 24),
			Rect2(100, 340, 170, 24),
		]) + [Rect2(520, 350, 240, 24)]
		m["crumble"] = MapData._sym([Rect2(355, 590, 110, 24)])
		m["lava"] = MapData._sym([Rect2(320, 664, 200, 56)])
		m["ambient"] = "sparks"
		m["powerup_spots"] = MapData._sym_pts([Vector2(155, 496), Vector2(385, 406), Vector2(185, 306), Vector2(640, 316), Vector2(640, 606)])
		m["respawn"] = Vector2(640, 300)
		m["spawns"] = _sp(Vector2(640, 319), Vector2(155, 499))
		return m
	var a := _base("hell", "ff6a1a", Color(1.0, 0.72, 0.72), Color(1.0, 0.82, 0.82))
	a["solids"] = MapData._sym([Rect2(0, 640, 340, 80)]) + [Rect2(590, 500, 100, 220)]
	a["platforms"] = MapData._sym([
		Rect2(360, 560, 150, 24),
		Rect2(80, 520, 170, 24),
		Rect2(330, 420, 170, 24),
		Rect2(80, 330, 150, 24),
	]) + [Rect2(540, 330, 200, 24)]
	a["lava"] = [Rect2(340, 664, 600, 56)]
	a["ambient"] = "sparks"
	a["powerup_spots"] = MapData._sym_pts([Vector2(165, 486), Vector2(415, 386), Vector2(155, 296), Vector2(640, 296), Vector2(640, 466)])
	a["respawn"] = Vector2(640, 290)
	a["spawns"] = _sp(Vector2(640, 299), Vector2(165, 489))
	return a


# ------------------------------------------------------------------ TEMPLE
## v1 SUN COURT: dua pilar batu jadi tameng, duri kecil, panah dari dinding di dua ketinggian.
## v2 SERPENT PIT: jurang gelap dengan pulau tangga di tengah, duri & panah.
static func _temple(v: int) -> Dictionary:
	if v == 1:
		var m := _base("temple", "f2e6b0", Color(1.0, 0.9, 0.78), Color(1.0, 0.95, 0.86))
		m["solids"] = [Rect2(0, 640, 1280, 80)] + MapData._sym([Rect2(250, 520, 90, 120)])
		m["platforms"] = MapData._sym([
			Rect2(60, 530, 170, 24),
			Rect2(430, 430, 160, 24),
		]) + [Rect2(540, 340, 200, 24)]
		m["spikes"] = MapData._sym_dicts([{"rect": Rect2(440, 604, 100, 36), "style": "temple"}])
		m["traps"] = [
			{"side": -1, "y": 612.0, "first": 8.0, "interval": 10.0},
			{"side": 1, "y": 612.0, "first": 8.0, "interval": 10.0},
			{"side": -1, "y": 470.0, "first": 12.0, "interval": 10.0},
			{"side": 1, "y": 470.0, "first": 12.0, "interval": 10.0},
		]
		m["ambient"] = "motes"
		m["powerup_spots"] = MapData._sym_pts([Vector2(145, 496), Vector2(510, 396), Vector2(640, 306), Vector2(295, 486)])
		m["respawn"] = Vector2(640, 300)
		m["spawns"] = _sp(Vector2(640, 309), Vector2(145, 499))
		return m
	var a := _base("temple", "f2e6b0", Color(0.8, 0.72, 0.96), Color(0.86, 0.82, 0.96))
	a["solids"] = MapData._sym([Rect2(0, 640, 400, 80)]) + [Rect2(540, 560, 200, 160), Rect2(590, 500, 100, 60)]
	a["platforms"] = MapData._sym([
		Rect2(60, 530, 170, 24),
		Rect2(300, 440, 150, 24),
	]) + [Rect2(540, 330, 200, 24)]
	a["spikes"] = MapData._sym_dicts([{"rect": Rect2(250, 604, 100, 36), "style": "temple"}])
	a["traps"] = [
		{"side": -1, "y": 612.0, "first": 7.0, "interval": 9.0},
		{"side": 1, "y": 612.0, "first": 7.0, "interval": 9.0},
	]
	a["lava"] = [Rect2(400, 664, 480, 56)]
	a["lava_colors"] = [Color(0.25, 0.1, 0.38, 0.95), Color(0.62, 0.3, 0.92, 0.9)]
	a["ambient"] = "motes"
	a["powerup_spots"] = MapData._sym_pts([Vector2(145, 496), Vector2(375, 406), Vector2(640, 296), Vector2(640, 466)])
	a["respawn"] = Vector2(640, 290)
	a["spawns"] = _sp(Vector2(640, 469), Vector2(145, 499))
	return a


# ------------------------------------------------------------------ OCEAN
## v1 SUNKEN DECK: dek penuh dengan geyser di tengah lantai dan meriam di dua ketinggian.
## v2 KRAKEN MAW: jurang lebar, geyser dekat tengah, papan runtuh, meriam bertingkat.
static func _ocean(v: int) -> Dictionary:
	var wcols: Array = [Color(0.05, 0.38, 0.62, 0.93), Color(0.7, 0.95, 1.0, 0.95)]
	if v == 1:
		var m := _base("ocean", "f2c27a", Color(1.0, 0.9, 0.82), Color(1.0, 0.95, 0.9))
		m["solids"] = [Rect2(0, 640, 1280, 80)]
		m["platforms"] = MapData._sym([
			Rect2(60, 530, 200, 24),
			Rect2(300, 450, 170, 24),
			Rect2(110, 350, 170, 24),
		]) + [Rect2(540, 320, 200, 24)]
		m["vents"] = [{"rect": Rect2(590, 380, 100, 260), "kind": "geyser", "first": 3.0, "rest": 3.6, "warn": 1.0, "active": 1.5, "lift": 4600.0, "rise": 560.0}]
		m["traps"] = [
			{"side": -1, "y": 600.0, "first": 6.0, "interval": 9.0, "kind": "cannon"},
			{"side": 1, "y": 600.0, "first": 6.0, "interval": 9.0, "kind": "cannon"},
			{"side": -1, "y": 470.0, "first": 10.0, "interval": 9.0, "kind": "cannon"},
			{"side": 1, "y": 470.0, "first": 10.0, "interval": 9.0, "kind": "cannon"},
		]
		m["ambient"] = "bubbles"
		m["powerup_spots"] = MapData._sym_pts([Vector2(160, 496), Vector2(385, 416), Vector2(195, 316), Vector2(640, 286), Vector2(300, 606)])
		m["respawn"] = Vector2(640, 260)
		m["spawns"] = _sp(Vector2(640, 289), Vector2(160, 499))
		return m
	var a := _base("ocean", "f2c27a", Color(0.76, 0.86, 1.0), Color(0.85, 0.92, 1.0))
	a["solids"] = MapData._sym([Rect2(0, 640, 330, 80)])
	a["platforms"] = MapData._sym([
		Rect2(60, 530, 200, 24),
		Rect2(290, 450, 170, 24),
		Rect2(100, 350, 170, 24),
	]) + [Rect2(540, 330, 200, 24)]
	a["crumble"] = MapData._sym([Rect2(350, 590, 110, 24)]) + [Rect2(570, 590, 140, 24)]
	a["vents"] = MapData._sym_vents([{"rect": Rect2(440, 420, 80, 244), "kind": "geyser", "first": 3.0, "rest": 3.2, "warn": 1.0, "active": 1.5, "lift": 4600.0, "rise": 600.0}])
	a["traps"] = [
		{"side": -1, "y": 500.0, "first": 6.0, "interval": 8.0, "kind": "cannon"},
		{"side": 1, "y": 500.0, "first": 6.0, "interval": 8.0, "kind": "cannon"},
		{"side": -1, "y": 380.0, "first": 11.0, "interval": 9.0, "kind": "cannon"},
		{"side": 1, "y": 380.0, "first": 11.0, "interval": 9.0, "kind": "cannon"},
	]
	a["lava"] = [Rect2(330, 664, 620, 56)]
	a["lava_colors"] = wcols
	a["ambient"] = "bubbles"
	a["powerup_spots"] = MapData._sym_pts([Vector2(160, 496), Vector2(375, 416), Vector2(185, 316), Vector2(640, 296), Vector2(250, 606)])
	a["respawn"] = Vector2(640, 280)
	a["spawns"] = _sp(Vector2(640, 299), Vector2(160, 499))
	return a


# ------------------------------------------------------------------ SPACE
## v1 DOCKING BAY: portal di lantai (menghubungkan dua sisi) + lift anti-gravitasi tengah ke dek puncak.
## v2 REACTOR CORE: dua lift ke dek atas dengan portal, lift tengah ke jembatan.
static func _space(v: int) -> Dictionary:
	if v == 1:
		var m := _base("space", "5bf0ff", Color(1.0, 0.86, 1.0), Color(1.0, 0.92, 1.0))
		m["solids"] = [Rect2(0, 640, 1280, 80)]
		m["platforms"] = MapData._sym([
			Rect2(60, 520, 150, 24),
			Rect2(260, 430, 160, 24),
			Rect2(80, 330, 150, 24),
		]) + [Rect2(520, 350, 240, 24)]
		m["vents"] = [{"rect": Rect2(590, 360, 100, 280), "kind": "antigrav", "first": 0.0, "rest": 0.0, "warn": 0.0, "active": 0.0, "lift": 3400.0, "rise": 400.0}]
		var pa := Rect2(350, 580, 56, 60)
		m["portals"] = [{"a": pa, "b": MapData._m(pa), "color": Color("ff7bff")}]
		m["ambient"] = "stars"
		m["powerup_spots"] = MapData._sym_pts([Vector2(135, 486), Vector2(340, 396), Vector2(155, 296), Vector2(640, 316), Vector2(500, 606)])
		m["respawn"] = Vector2(640, 300)
		m["spawns"] = _sp(Vector2(640, 319), Vector2(135, 489))
		return m
	var a := _base("space", "5bf0ff", Color(0.8, 0.92, 1.0), Color(0.88, 0.95, 1.0))
	a["solids"] = [Rect2(0, 640, 1280, 80)]
	a["platforms"] = MapData._sym([
		Rect2(60, 510, 150, 24),
		Rect2(240, 300, 200, 24),
	]) + [Rect2(540, 420, 200, 24)]
	a["vents"] = MapData._sym_vents([{"rect": Rect2(330, 300, 80, 340), "kind": "antigrav", "first": 0.0, "rest": 0.0, "warn": 0.0, "active": 0.0, "lift": 3400.0, "rise": 400.0}]) + [{"rect": Rect2(590, 430, 100, 210), "kind": "antigrav", "first": 0.0, "rest": 0.0, "warn": 0.0, "active": 0.0, "lift": 3400.0, "rise": 300.0}]
	var pb := Rect2(250, 240, 56, 60)
	a["portals"] = [{"a": pb, "b": MapData._m(pb), "color": Color("5bf0ff")}]
	a["ambient"] = "stars"
	a["powerup_spots"] = MapData._sym_pts([Vector2(135, 476), Vector2(340, 266), Vector2(640, 386), Vector2(480, 606)])
	a["respawn"] = Vector2(640, 380)
	a["spawns"] = _sp(Vector2(640, 389), Vector2(135, 479))
	return a


# ------------------------------------------------------------------ FACTORY
## v1 SMELTER: ban berjalan menuju gergaji tengah + gergaji vertikal di bawah catwalk.
## v2 SHREDDER: ban lebih cepat, gergaji lantai lebih lebar, gergaji terbang di tengah.
static func _factory(v: int) -> Dictionary:
	if v == 1:
		var m := _base("factory", "ffc933", Color(1.0, 0.9, 0.8), Color(1.0, 0.95, 0.88))
		m["solids"] = [Rect2(0, 640, 1280, 80)]
		m["platforms"] = MapData._sym([
			Rect2(80, 530, 220, 24),
			Rect2(380, 440, 190, 24),
			Rect2(90, 370, 170, 24),
		]) + [Rect2(540, 340, 200, 24)]
		m["conveyors"] = MapData._sym_conv([
			{"rect": Rect2(300, 640, 260, 10), "speed": 130.0},
			{"rect": Rect2(80, 530, 220, 10), "speed": -90.0},
		])
		m["saws"] = [
			{"pos": Vector2(640, 612), "move": Vector2(120, 0), "period": 4.5, "phase": 0.0, "radius": 28.0},
			{"pos": Vector2(640, 450), "move": Vector2(0, 40), "period": 4.0, "phase": 0.0, "radius": 24.0},
		]
		m["ambient"] = "sparks"
		m["powerup_spots"] = MapData._sym_pts([Vector2(190, 496), Vector2(475, 406), Vector2(175, 336), Vector2(640, 306), Vector2(250, 606)])
		m["respawn"] = Vector2(640, 290)
		m["spawns"] = _sp(Vector2(640, 309), Vector2(190, 499))
		return m
	var a := _base("factory", "ffc933", Color(0.78, 0.82, 1.0), Color(0.86, 0.88, 1.0))
	a["solids"] = [Rect2(0, 640, 1280, 80)]
	a["platforms"] = MapData._sym([
		Rect2(60, 520, 200, 24),
		Rect2(330, 430, 170, 24),
		Rect2(90, 340, 170, 24),
	]) + [Rect2(540, 330, 200, 24)]
	a["conveyors"] = MapData._sym_conv([
		{"rect": Rect2(260, 640, 220, 10), "speed": 150.0},
		{"rect": Rect2(60, 520, 200, 10), "speed": -110.0},
	])
	a["saws"] = [
		{"pos": Vector2(640, 612), "move": Vector2(160, 0), "period": 5.0, "phase": 0.0, "radius": 30.0},
		{"pos": Vector2(640, 420), "move": Vector2(100, 0), "period": 4.0, "phase": 0.0, "radius": 24.0},
	]
	a["ambient"] = "sparks"
	a["powerup_spots"] = MapData._sym_pts([Vector2(160, 486), Vector2(415, 396), Vector2(175, 306), Vector2(640, 296), Vector2(220, 606)])
	a["respawn"] = Vector2(640, 280)
	a["spawns"] = _sp(Vector2(640, 299), Vector2(160, 489))
	return a
