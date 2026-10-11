class_name MapData
extends RefCounted
## Layout tiap map. Dunia game = 1280x720 (background 320x180 di-scale 4x).
##
## KUNCI WAJIB
##   solids    : blok padat (lantai / dinding)
##   platforms : platform one-way (bisa dilompati dari bawah, tekan bawah untuk turun)
##   lava      : area bahaya jatuh (kena = -1 darah lalu respawn). Warna bisa diganti lewat "lava_colors"
##   respawn   : titik muncul lagi setelah kena lava / jatuh
##   spawns    : posisi spawn per jumlah pemain
##
## KUNCI OPSIONAL (rintangan baru, semuanya dibangun oleh scripts/hazards.gd)
##   moving    : platform bergerak  [{rect, move: Vector2 (jarak ayun +/-), period: detik, phase: radian}]
##   crumble   : platform rapuh (runtuh sebentar setelah diinjak, muncul lagi) [Rect2]
##   spikes    : duri / kaktus      [{rect, style: "safari" | "temple" | "cactus"}]  (kena = -1 darah + terpental)
##   bounce    : jamur pantul       [{rect, power}]
##   ice       : permukaan es licin [Rect2]  (tinggi bebas, bagian atas = permukaan)
##   traps     : jebakan panah dinding [{side: -1 kiri / 1 kanan, y, first, interval}]
##   ambient   : partikel suasana ("snow", "dust", "leaves", "motes")
##   powerup_spots : titik muncul power up (kalau tidak ada, dipilih acak dari platform)
##
## KUNCI OPSIONAL BARU (map Ocean / Space / Factory)
##   vents     : dorongan ke atas [{rect, kind: "geyser" | "antigrav", first, rest, warn, active, lift, rise}]
##               geyser = menyembur berkala (peringatan buih dulu), antigrav = lift cahaya selalu aktif
##   portals   : pasangan portal teleport [{a: Rect2, b: Rect2, color}]  (a <-> b, dibuat cermin kiri-kanan)
##   conveyors : ban berjalan [{rect (atas = permukaan), speed (px/detik, + kanan / - kiri)}]
##   saws      : gergaji bulat di rel [{pos, move: Vector2 (jarak ayun +/-), period, phase, radius}]
##   traps     : tambahan field "kind": "cannon" -> meriam kapal (default "dart" = panah batu)
##   ambient   : tambahan "bubbles", "stars", "sparks"
##
## ATURAN KESEIMBANGAN: semua map SIMETRIS kiri-kanan (dibuat otomatis lewat _sym / _sym_pts),
## platform bergerak memakai gerak cermin, dan semua titik spawn dipasangkan kiri-kanan.

const W := 1280.0


## variant: 0 = map asli (Chapter 1), 1..4 = varian Chapter 2..5 (lihat scripts/map_variants.gd & map_variants_late.gd).
static func get_map(id: String, variant: int = 0) -> Dictionary:
	if variant > 0 and MapVariants.has_variant(id, variant):
		return MapVariants.get_variant(id, variant)
	match id:
		"hell":
			return _hell()
		"snow":
			return _snow()
		"desert":
			return _desert()
		"jungle":
			return _jungle()
		"safari":
			return _safari()
		"temple":
			return _temple()
		"ocean":
			return _ocean()
		"space":
			return _space()
		"factory":
			return _factory()
		_:
			return _earth()


# ------------------------------------------------------------------ KEPADATAN OBJEK (setting OBJECTS di BATTLE SETTINGS)
## level 0 = FEWER  : rintangan asli lebih ringan (duri lebih pendek, jebakan & geyser lebih jarang, gergaji tinggal satu)
## level 1 = NORMAL : map apa adanya (bawaan)
## level 2 = MORE   : + objek tambahan yang sesuai tema map
## level 3 = EXTREME: MORE + objek tambahan lagi + jebakan sedikit lebih rapat
## SEMUA tambahan dibuat simetris kiri-kanan (_sym*), tidak menyentuh titik spawn / respawn, dan semua platform baru
## masih terjangkau lompatan (maks ~144 px naik, ~250 px jarak). Hanya dipakai di mode VERSUS (campaign tidak memanggil ini).
static func apply_density(m: Dictionary, level: int) -> Dictionary:
	var lv: int = clampi(level, 0, 3)
	if lv == 1:
		return m
	if lv == 0:
		return _lighten(m)
	_merge(m, _extras(String(m.get("id", "earth")), 1))
	if lv >= 3:
		_merge(m, _extras(String(m.get("id", "earth")), 2))
		_tighten(m)
	return m


## Gabungkan daftar objek tambahan ke map (semua kunci berupa Array, kecuali yang tidak ada dibuat baru).
static func _merge(m: Dictionary, extra: Dictionary) -> void:
	for k in extra:
		var cur: Array = m.get(k, [])
		cur = cur.duplicate()
		cur.append_array(extra[k])
		m[k] = cur


## Buang Rect2 tertentu (beserta bayangan cerminnya) dari daftar Rect2.
static func _without(list: Array, rects: Array) -> Array:
	var gone: Array = _sym(rects)
	var out: Array = []
	for r in list:
		var hit := false
		for g in gone:
			if (r as Rect2).is_equal_approx(g):
				hit = true
		if not hit:
			out.append(r)
	return out


## Sama, untuk daftar Dictionary ber-"rect" (platform bergerak, duri, jamur).
static func _without_d(list: Array, rects: Array) -> Array:
	var gone: Array = _sym(rects)
	var out: Array = []
	for d in list:
		var hit := false
		for g in gone:
			if ((d as Dictionary)["rect"] as Rect2).is_equal_approx(g):
				hit = true
		if not hit:
			out.append(d)
	return out


## FEWER: objek bawaan map DIKURANGI (selalu simetris) di SEMUA map, supaya tidak pernah sama dengan NORMAL.
static func _remove_base(m: Dictionary) -> void:
	match String(m.get("id", "earth")):
		"hell":
			m["platforms"] = _without(m["platforms"], [Rect2(60, 340, 200, 24)])        # dua platform luar atas
		"snow":
			m["moving"] = []                                                             # bongkahan es hanyut
		"desert":
			m["spikes"] = _without_d(m["spikes"], [Rect2(270, 586, 72, 54)])             # kaktus luar (sisa kaktus tengah)
		"jungle":
			m["moving"] = _without_d(m["moving"], [Rect2(560, 478, 160, 24)])            # lift kayu tengah
		"safari":
			m["moving"] = _without_d(m["moving"], [Rect2(430, 580, 110, 24)])            # dua platform bergerak di atas duri
		"temple":
			m["moving"] = _without_d(m["moving"], [Rect2(300, 450, 130, 24)])            # dua platform ayun
		"ocean":
			m["crumble"] = _without(m["crumble"], [Rect2(372, 570, 110, 24)])            # papan lapuk di atas jurang
		"space":
			m["portals"] = []                                                            # portal dek (spawn 3 pemain di jembatan tengah tetap aman)
		"factory":
			pass                                                                         # gergaji dikurangi di _lighten
		_:
			m["platforms"] = _without(m["platforms"], [Rect2(200, 330, 240, 24)])        # earth: dua platform atas


## Jumlah seluruh objek arena (dipakai untuk memastikan tiap level OBJECTS benar-benar berbeda).
static func object_count(m: Dictionary) -> int:
	var n := 0
	for k in ["platforms", "crumble", "moving", "spikes", "bounce", "traps", "vents", "portals", "conveyors", "saws"]:
		n += (m.get(k, []) as Array).size()
	return n


## Pengaman: jumlah objek HARUS naik tegas FEWER < NORMAL < MORE < EXTREME di setiap map.
## Dipanggil otomatis saat game dijalankan dari editor (debug); kalau ada map yang melanggar, muncul error merah di Output.
static func verify_levels() -> bool:
	var ok := true
	for id in ["earth", "hell", "snow", "desert", "jungle", "safari", "temple", "ocean", "space", "factory"]:
		var prev := -1
		for lv in 4:
			var n: int = object_count(apply_density(get_map(id), lv))
			if n <= prev:
				push_error("MapData: map '%s' level %d (jumlah objek %d) tidak berbeda dari level sebelumnya (%d)" % [id, lv, n, prev])
				ok = false
			prev = n
	return ok


## FEWER: rintangan asli dibuat lebih ringan (tetap simetris).
static func _lighten(m: Dictionary) -> Dictionary:
	_remove_base(m)
	# duri / kaktus lebih pendek (dipersempit dari tengah, tetap cermin)
	var sp: Array = []
	for d in m.get("spikes", []):
		var c: Dictionary = (d as Dictionary).duplicate()
		var r: Rect2 = c["rect"]
		var nw: float = maxf(r.size.x * 0.7, 40.0)
		c["rect"] = Rect2(r.position.x + (r.size.x - nw) * 0.5, r.position.y, nw, r.size.y)
		sp.append(c)
	if not sp.is_empty():
		m["spikes"] = sp
	# jebakan panah / meriam lebih jarang
	var tr: Array = []
	for d in m.get("traps", []):
		var c2: Dictionary = (d as Dictionary).duplicate()
		c2["first"] = float(c2["first"]) * 1.2
		c2["interval"] = float(c2["interval"]) * 1.5
		tr.append(c2)
	if not tr.is_empty():
		m["traps"] = tr
	# geyser lebih jarang menyembur (lift anti-gravitasi tetap)
	var vt: Array = []
	for d in m.get("vents", []):
		var c3: Dictionary = (d as Dictionary).duplicate()
		if String(c3.get("kind", "")) == "geyser":
			c3["rest"] = float(c3["rest"]) * 1.5
		vt.append(c3)
	if not vt.is_empty():
		m["vents"] = vt
	# gergaji: tinggal satu (gergaji lantai tengah), sisanya dibuang
	var sw: Array = m.get("saws", [])
	if sw.size() > 1:
		m["saws"] = [sw[0]]
	return m


## EXTREME: jebakan sedikit lebih rapat (simetris, kedua sisi sama).
static func _tighten(m: Dictionary) -> void:
	var tr: Array = []
	for d in m.get("traps", []):
		var c: Dictionary = (d as Dictionary).duplicate()
		c["interval"] = maxf(float(c["interval"]) * 0.85, 5.0)
		tr.append(c)
	if not tr.is_empty():
		m["traps"] = tr
	var vt: Array = []
	for d in m.get("vents", []):
		var c2: Dictionary = (d as Dictionary).duplicate()
		if String(c2.get("kind", "")) == "geyser":
			c2["rest"] = maxf(float(c2["rest"]) * 0.85, 2.0)
		vt.append(c2)
	if not vt.is_empty():
		m["vents"] = vt


## Objek tambahan per map. tier 1 = MORE, tier 2 = tambahan untuk EXTREME (ditumpuk di atas tier 1).
## Kunci hasil sama dengan kunci map: platforms, crumble, moving, spikes, bounce, traps, vents, portals, conveyors, saws.
static func _extras(id: String, tier: int) -> Dictionary:
	match id:
		"hell":
			return _x_hell(tier)
		"snow":
			return _x_snow(tier)
		"desert":
			return _x_desert(tier)
		"jungle":
			return _x_jungle(tier)
		"safari":
			return _x_safari(tier)
		"temple":
			return _x_temple(tier)
		"ocean":
			return _x_ocean(tier)
		"space":
			return _x_space(tier)
		"factory":
			return _x_factory(tier)
	return _x_earth(tier)


## EARTH: padang rumput -> jamur pantul, kayu bergerak, semak berduri, batu rapuh di puncak.
static func _x_earth(tier: int) -> Dictionary:
	if tier == 1:
		return {
			"bounce": _sym_dicts([{"rect": Rect2(330, 604, 100, 36), "power": -1050.0}]),
			"moving": _sym_moving([{"rect": Rect2(40, 440, 110, 24), "move": Vector2(30, 0), "period": 5.5, "phase": 0.0}]),
		}
	return {
		"spikes": _sym_dicts([{"rect": Rect2(520, 604, 80, 36), "style": "safari"}]),
		"crumble": _sym([Rect2(560, 250, 160, 24)]),
	}


## HELL: lava -> lift batu api di atas lava, duri batu, batu hangus rapuh, jebakan panah iblis.
static func _x_hell(tier: int) -> Dictionary:
	if tier == 1:
		return {
			"moving": [{"rect": Rect2(570, 450, 140, 24), "move": Vector2(0, -45), "period": 6.0, "phase": 0.0}],
			"spikes": _sym_dicts([{"rect": Rect2(330, 604, 90, 36), "style": "temple"}]),
		}
	return {
		"crumble": _sym([Rect2(260, 250, 130, 24)]),
		"traps": [
			{"side": -1, "y": 500.0, "first": 8.0, "interval": 10.0},
			{"side": 1, "y": 500.0, "first": 8.0, "interval": 10.0},
		],
	}


## SNOW: es -> bongkahan es rapuh di atas air, platform es melayang, panah es dari dinding.
static func _x_snow(tier: int) -> Dictionary:
	if tier == 1:
		return {
			"crumble": _sym([Rect2(440, 520, 110, 24)]),
			"moving": _sym_moving([{"rect": Rect2(300, 270, 120, 24), "move": Vector2(40, 0), "period": 6.0, "phase": 0.0}]),
		}
	return {
		"traps": [
			{"side": -1, "y": 500.0, "first": 8.0, "interval": 10.0},
			{"side": 1, "y": 500.0, "first": 8.0, "interval": 10.0},
		],
	}


## DESERT: gurun -> kaktus tambahan, batu pasir rapuh, panah jebakan reruntuhan.
static func _x_desert(tier: int) -> Dictionary:
	if tier == 1:
		return {
			"spikes": _sym_dicts([{"rect": Rect2(450, 586, 60, 54), "style": "cactus"}]),
			"crumble": _sym([Rect2(330, 380, 130, 24)]),
		}
	return {
		"crumble": _sym([Rect2(80, 270, 130, 24)]),
		"traps": [
			{"side": -1, "y": 500.0, "first": 8.0, "interval": 10.0},
			{"side": 1, "y": 500.0, "first": 8.0, "interval": 10.0},
		],
	}


## JUNGLE: hutan -> semak duri, lift kayu, jamur pantul, cabang rapuh, panah sumpit.
static func _x_jungle(tier: int) -> Dictionary:
	if tier == 1:
		return {
			"spikes": _sym_dicts([{"rect": Rect2(470, 604, 90, 36), "style": "safari"}]),
			"moving": _sym_moving([{"rect": Rect2(400, 300, 110, 24), "move": Vector2(0, -50), "period": 6.5, "phase": 1.0}]),
		}
	return {
		"crumble": _sym([Rect2(40, 430, 100, 24)]),
		"traps": [
			{"side": -1, "y": 500.0, "first": 8.0, "interval": 10.0},
			{"side": 1, "y": 500.0, "first": 8.0, "interval": 10.0},
		],
	}


## SAFARI: savana -> duri akasia tambahan, platform ayun, cabang rapuh, tombak dari dinding.
static func _x_safari(tier: int) -> Dictionary:
	if tier == 1:
		return {
			"spikes": _sym_dicts([{"rect": Rect2(240, 604, 60, 36), "style": "safari"}]),
			"moving": _sym_moving([{"rect": Rect2(70, 400, 120, 24), "move": Vector2(30, 0), "period": 5.5, "phase": 0.0}]),
		}
	return {
		"crumble": _sym([Rect2(290, 330, 120, 24)]),
		"traps": [
			{"side": -1, "y": 500.0, "first": 8.0, "interval": 10.0},
			{"side": 1, "y": 500.0, "first": 8.0, "interval": 10.0},
		],
	}


## TEMPLE: kuil -> platform ayun, panah tambahan setinggi platform, batu rapuh, jamur pantul batu.
static func _x_temple(tier: int) -> Dictionary:
	if tier == 1:
		return {
			"moving": _sym_moving([{"rect": Rect2(110, 410, 110, 24), "move": Vector2(40, 0), "period": 6.0, "phase": 0.0}]),
			"traps": [
				{"side": -1, "y": 470.0, "first": 11.0, "interval": 9.0},
				{"side": 1, "y": 470.0, "first": 11.0, "interval": 9.0},
			],
		}
	return {
		"crumble": _sym([Rect2(330, 350, 130, 24)]),
		"bounce": _sym_dicts([{"rect": Rect2(430, 604, 70, 36), "power": -1050.0}]),
	}


## OCEAN: teluk kapal -> papan lapuk tengah, tiang ayun, sarang gagak rapuh, meriam kapal tambahan.
static func _x_ocean(tier: int) -> Dictionary:
	if tier == 1:
		return {
			"crumble": _sym([Rect2(590, 580, 100, 24)]),
			"moving": _sym_moving([{"rect": Rect2(330, 300, 120, 24), "move": Vector2(30, 0), "period": 6.0, "phase": 0.0}]),
		}
	return {
		"crumble": _sym([Rect2(40, 250, 110, 24)]),
		"traps": [
			{"side": -1, "y": 400.0, "first": 9.0, "interval": 8.0, "kind": "cannon"},
			{"side": 1, "y": 400.0, "first": 9.0, "interval": 8.0, "kind": "cannon"},
		],
	}


## SPACE: stasiun -> platform melayang, portal lantai tambahan (jeda 1 detik tetap berlaku), dek rapuh.
static func _x_space(tier: int) -> Dictionary:
	if tier == 1:
		return {
			"moving": _sym_moving([{"rect": Rect2(560, 240, 160, 24), "move": Vector2(60, 0), "period": 6.0, "phase": 0.0}]),
		}
	var floor_portal := Rect2(250, 580, 56, 60)
	return {
		"moving": _sym_moving([{"rect": Rect2(60, 330, 120, 24), "move": Vector2(40, 0), "period": 5.5, "phase": 0.0}]),
		"portals": [{"a": floor_portal, "b": _m(floor_portal), "color": Color("ff5bd8")}],
	}


## FACTORY: pabrik -> ban berjalan tambahan, gergaji rel tambahan, piston panah dari dinding.
static func _x_factory(tier: int) -> Dictionary:
	if tier == 1:
		return {
			"conveyors": _sym_conv([{"rect": Rect2(380, 450, 170, 10), "speed": -80.0}]),
			"saws": _sym_saws([{"pos": Vector2(320, 360), "move": Vector2(50, 0), "period": 4.5, "phase": 0.0, "radius": 24.0}]),
		}
	return {
		"conveyors": _sym_conv([{"rect": Rect2(180, 640, 120, 10), "speed": -90.0}]),
		"traps": [
			{"side": -1, "y": 500.0, "first": 8.0, "interval": 10.0},
			{"side": 1, "y": 500.0, "first": 8.0, "interval": 10.0},
		],
	}


# ------------------------------------------------------------------ helper simetri
## Cermin horizontal sebuah Rect2 terhadap tengah layar.
static func _m(r: Rect2) -> Rect2:
	return Rect2(W - r.end.x, r.position.y, r.size.x, r.size.y)


## Daftar Rect2 + bayangan cerminnya (objek yang tepat di tengah tidak digandakan).
static func _sym(list: Array) -> Array:
	var out: Array = []
	for r in list:
		out.append(r)
	for r in list:
		var rect: Rect2 = r
		var mr := _m(rect)
		if not mr.is_equal_approx(rect):
			out.append(mr)
	return out


## Platform bergerak + cerminnya (gerak horizontal dibalik supaya gerakannya juga cermin).
static func _sym_moving(list: Array) -> Array:
	var out: Array = []
	for d in list:
		out.append(d)
	for d in list:
		var rect: Rect2 = d["rect"]
		var mr := _m(rect)
		if mr.is_equal_approx(rect):
			continue
		var mv: Vector2 = d["move"]
		out.append({"rect": mr, "move": Vector2(-mv.x, mv.y), "period": d["period"], "phase": d["phase"]})
	return out


## Objek ber-"rect" (duri, jamur) + cerminnya.
static func _sym_dicts(list: Array) -> Array:
	var out: Array = []
	for d in list:
		out.append(d)
	for d in list:
		var rect: Rect2 = d["rect"]
		var mr := _m(rect)
		if mr.is_equal_approx(rect):
			continue
		var c: Dictionary = (d as Dictionary).duplicate()
		c["rect"] = mr
		out.append(c)
	return out


## Zona dorong (geyser / lift) + cerminnya.
static func _sym_vents(list: Array) -> Array:
	return _sym_dicts(list)


## Ban berjalan + cerminnya (arah ban dibalik supaya adil: kiri & kanan sama-sama menyeret ke arah yang sama relatif ke tengah).
static func _sym_conv(list: Array) -> Array:
	var out: Array = []
	for d in list:
		out.append(d)
	for d in list:
		var rect: Rect2 = d["rect"]
		var mr := _m(rect)
		if mr.is_equal_approx(rect):
			continue
		out.append({"rect": mr, "speed": -float(d["speed"])})
	return out


## Gergaji + cerminnya (gerak horizontal dibalik).
static func _sym_saws(list: Array) -> Array:
	var out: Array = []
	for d in list:
		out.append(d)
	for d in list:
		var pos: Vector2 = d["pos"]
		var mp := Vector2(W - pos.x, pos.y)
		if mp.is_equal_approx(pos):
			continue
		var mv: Vector2 = d["move"]
		var c: Dictionary = (d as Dictionary).duplicate()
		c["pos"] = mp
		c["move"] = Vector2(-mv.x, mv.y)
		out.append(c)
	return out


## Titik + cerminnya.
static func _sym_pts(list: Array) -> Array:
	var out: Array = []
	for p in list:
		out.append(p)
	for p in list:
		var v: Vector2 = p
		var mv := Vector2(W - v.x, v.y)
		if not mv.is_equal_approx(v):
			out.append(mv)
	return out


# ------------------------------------------------------------------ EARTH (asli)
static func _earth() -> Dictionary:
	return {
		"id": "earth",
		"background": "res://assets/sprites/stages/earth.png",
		"floor": "res://assets/sprites/stages/earth_floor.png",
		"edge_color": Color("5cc43a"),
		"solids": [Rect2(0, 640, 1280, 80)],
		"platforms": [
			Rect2(140, 530, 240, 24),
			Rect2(900, 530, 240, 24),
			Rect2(480, 430, 320, 24),
			Rect2(200, 330, 240, 24),
			Rect2(840, 330, 240, 24),
		],
		"lava": [],
		"respawn": Vector2(640, 390),
		"spawns": {
			2: [Vector2(150, 609), Vector2(1130, 609)],
			3: [Vector2(150, 609), Vector2(1130, 609), Vector2(640, 399)],
			4: [Vector2(150, 609), Vector2(1130, 609), Vector2(260, 499), Vector2(1020, 499)],
		},
	}


# ------------------------------------------------------------------ HELL (asli)
static func _hell() -> Dictionary:
	return {
		"id": "hell",
		"background": "res://assets/sprites/stages/hell.png",
		"floor": "res://assets/sprites/stages/hell_floor.png",
		"edge_color": Color("ff6a1a"),
		"solids": [
			Rect2(0, 640, 480, 80),
			Rect2(800, 640, 480, 80),
		],
		"platforms": [
			Rect2(540, 560, 200, 24),
			Rect2(60, 540, 200, 24),
			Rect2(1020, 540, 200, 24),
			Rect2(300, 440, 200, 24),
			Rect2(780, 440, 200, 24),
			Rect2(520, 340, 240, 24),
			Rect2(60, 340, 200, 24),
			Rect2(1020, 340, 200, 24),
		],
		"lava": [Rect2(480, 660, 320, 60)],
		"respawn": Vector2(640, 300),
		"spawns": {
			2: [Vector2(150, 609), Vector2(1130, 609)],
			3: [Vector2(150, 609), Vector2(1130, 609), Vector2(640, 309)],
			4: [Vector2(150, 609), Vector2(1130, 609), Vector2(400, 409), Vector2(880, 409)],
		},
	}


# ------------------------------------------------------------------ SNOW  "Frozen Pass"
## Jurang air es di tengah + satu bongkahan es yang hanyut bolak-balik + permukaan es licin.
## Jangkauan lompat pemain: tinggi maks ~144 px, jarak maks ~250 px -> semua celah di bawah ini dihitung dari situ.
static func _snow() -> Dictionary:
	return {
		"id": "snow",
		"background": "res://assets/sprites/stages/snow.png",
		"floor": "res://assets/sprites/stages/snow_floor.png",
		"edge_color": Color("e8f6ff"),
		"solids": _sym([Rect2(0, 640, 420, 80)]),
		"platforms": _sym([
			Rect2(60, 530, 200, 24),    # A  (naik 110 dari lantai)
			Rect2(330, 440, 180, 24),   # B  (licin)
			Rect2(90, 340, 170, 24),    # D
			Rect2(540, 340, 200, 24),   # C  (licin, tengah atas)
		]),
		"moving": [
			# bongkahan es hanyut di atas air, bergerak pelan dari tepi ke tepi
			{"rect": Rect2(560, 596, 160, 24), "move": Vector2(110, 0), "period": 7.0, "phase": 0.0},
		],
		"ice": _sym([
			Rect2(300, 640, 120, 8),    # lantai dekat jurang
			Rect2(330, 440, 180, 8),    # B
			Rect2(540, 340, 200, 8),    # C
		]),
		"lava": [Rect2(420, 664, 440, 56)],
		"lava_colors": [Color(0.12, 0.42, 0.85, 0.93), Color(0.78, 0.95, 1.0, 0.95)],
		"ambient": "snow",
		"powerup_spots": _sym_pts([
			Vector2(160, 496), Vector2(420, 406), Vector2(175, 306),
			Vector2(640, 306),
		]),
		"respawn": Vector2(640, 290),
		"spawns": {
			2: [Vector2(150, 609), Vector2(1130, 609)],
			3: [Vector2(150, 609), Vector2(1130, 609), Vector2(640, 309)],
			4: [Vector2(150, 609), Vector2(1130, 609), Vector2(160, 499), Vector2(1120, 499)],
		},
	}


# ------------------------------------------------------------------ DESERT  "Dune Ruins"
## Platform batu pasir yang runtuh kalau diinjak + kaktus berduri di lantai.
static func _desert() -> Dictionary:
	return {
		"id": "desert",
		"background": "res://assets/sprites/stages/desert.png",
		"floor": "res://assets/sprites/stages/desert_floor.png",
		"edge_color": Color("f2c777"),
		"solids": [Rect2(0, 640, 1280, 80)],
		"platforms": _sym([
			Rect2(60, 540, 180, 24),    # S1 (kokoh, dekat spawn)
			Rect2(520, 380, 240, 24),   # E  (kokoh, tengah)
		]),
		"crumble": _sym([
			Rect2(340, 470, 160, 24),   # M1 runtuh
			Rect2(100, 380, 160, 24),   # U1 runtuh
			Rect2(560, 290, 160, 24),   # T  runtuh, "puncak bukit"
		]),
		"spikes": _sym_dicts([
			{"rect": Rect2(270, 586, 72, 54), "style": "cactus"},
			{"rect": Rect2(604, 586, 72, 54), "style": "cactus"},
		]),
		"lava": [],
		"ambient": "dust",
		"powerup_spots": _sym_pts([
			Vector2(150, 506), Vector2(590, 346), Vector2(470, 606),
		]),
		"respawn": Vector2(640, 330),
		"spawns": {
			2: [Vector2(150, 609), Vector2(1130, 609)],
			3: [Vector2(150, 609), Vector2(1130, 609), Vector2(640, 349)],
			4: [Vector2(150, 609), Vector2(1130, 609), Vector2(150, 509), Vector2(1130, 509)],
		},
	}


# ------------------------------------------------------------------ JUNGLE  "Canopy"
## Kayu bergerak (lift tengah + dua kayu ayun) dan jamur pantul yang melontarkan ke tepi atas.
static func _jungle() -> Dictionary:
	return {
		"id": "jungle",
		"background": "res://assets/sprites/stages/jungle.png",
		"floor": "res://assets/sprites/stages/jungle_floor.png",
		"edge_color": Color("8be04e"),
		"solids": [Rect2(0, 640, 1280, 80)],
		"platforms": _sym([
			Rect2(60, 530, 150, 24),    # L1
			Rect2(180, 350, 160, 24),   # P  (dicapai lewat jamur / kayu ayun)
			Rect2(540, 330, 200, 24),   # K  kanopi tengah
		]),
		"moving": _sym_moving([
			{"rect": Rect2(300, 440, 140, 24), "move": Vector2(60, 0), "period": 6.0, "phase": 0.0},
			# lift tengah: naik-turun, titik terendah masih di atas kepala pemain di lantai
			{"rect": Rect2(560, 478, 160, 24), "move": Vector2(0, -78), "period": 7.0, "phase": 0.0},
		]),
		"bounce": _sym_dicts([
			{"rect": Rect2(250, 604, 100, 36), "power": -1050.0},
		]),
		"lava": [],
		"ambient": "leaves",
		"powerup_spots": _sym_pts([
			Vector2(135, 496), Vector2(260, 316), Vector2(470, 606),
			Vector2(640, 296),
		]),
		"respawn": Vector2(640, 280),
		"spawns": {
			2: [Vector2(150, 609), Vector2(1130, 609)],
			3: [Vector2(150, 609), Vector2(1130, 609), Vector2(640, 299)],
			4: [Vector2(150, 609), Vector2(1130, 609), Vector2(135, 499), Vector2(1145, 499)],
		},
	}


# ------------------------------------------------------------------ SAFARI  "Thorn Savanna"
## Dua lajur duri di lantai; pulau tengah aman hanya bisa dicapai dengan melompat / lewat platform
## (termasuk dua platform yang bergerak di atas duri).
static func _safari() -> Dictionary:
	return {
		"id": "safari",
		"background": "res://assets/sprites/stages/safari.png",
		"floor": "res://assets/sprites/stages/safari_floor.png",
		"edge_color": Color("f0d078"),
		"solids": [Rect2(0, 640, 1280, 80)],
		"platforms": _sym([
			Rect2(60, 530, 180, 24),    # R1 batu
			Rect2(300, 440, 200, 24),   # A1 cabang akasia
			Rect2(540, 350, 200, 24),   # T  puncak
		]),
		"moving": _sym_moving([
			{"rect": Rect2(430, 580, 110, 24), "move": Vector2(40, 0), "period": 5.0, "phase": 0.0},
		]),
		"spikes": _sym_dicts([
			{"rect": Rect2(380, 604, 160, 36), "style": "safari"},
		]),
		"lava": [],
		"ambient": "dust",
		"powerup_spots": _sym_pts([
			Vector2(150, 496), Vector2(400, 406), Vector2(300, 606),
			Vector2(640, 316), Vector2(640, 606),
		]),
		"respawn": Vector2(640, 300),
		"spawns": {
			2: [Vector2(150, 609), Vector2(1130, 609)],
			3: [Vector2(150, 609), Vector2(1130, 609), Vector2(640, 319)],
			4: [Vector2(150, 609), Vector2(1130, 609), Vector2(150, 499), Vector2(1130, 499)],
		},
	}


# ------------------------------------------------------------------ TEMPLE  "Trial of the Ziggurat"
## Map paling berat: piramida batu (jadi tameng peluru), duri di kiri-kanan piramida,
## dua platform ayun, dan jebakan panah dari dinding yang menembak bersamaan dari kedua sisi.
static func _temple() -> Dictionary:
	return {
		"id": "temple",
		"background": "res://assets/sprites/stages/temple.png",
		"floor": "res://assets/sprites/stages/temple_floor.png",
		"edge_color": Color("f2e6b0"),
		"solids": [
			Rect2(0, 640, 1280, 80),
			Rect2(500, 584, 280, 56),   # anak tangga bawah piramida
			Rect2(570, 528, 140, 56),   # anak tangga atas piramida
		],
		"platforms": _sym([
			Rect2(60, 530, 180, 24),    # T1
			Rect2(540, 360, 200, 24),   # Tp  puncak tengah
		]),
		"moving": _sym_moving([
			{"rect": Rect2(300, 450, 130, 24), "move": Vector2(50, 0), "period": 6.0, "phase": 0.0},
		]),
		"spikes": _sym_dicts([
			{"rect": Rect2(300, 604, 120, 36), "style": "temple"},
		]),
		"traps": [
			{"side": -1, "y": 612.0, "first": 7.0, "interval": 9.0},
			{"side": 1, "y": 612.0, "first": 7.0, "interval": 9.0},
		],
		"lava": [],
		"ambient": "motes",
		"powerup_spots": _sym_pts([
			Vector2(150, 496), Vector2(590, 326), Vector2(230, 606),
			Vector2(640, 494),
		]),
		"respawn": Vector2(640, 300),
		"spawns": {
			2: [Vector2(150, 609), Vector2(1130, 609)],
			3: [Vector2(150, 609), Vector2(1130, 609), Vector2(640, 497)],
			4: [Vector2(150, 609), Vector2(1130, 609), Vector2(150, 499), Vector2(1130, 499)],
		},
	}


# ------------------------------------------------------------------ OCEAN  "Shipwreck Bay"
## Teluk bangkai kapal: jurang air di tengah, papan lapuk, dua GEYSER LAUT yang melontarkan ke atas
## (peringatan buih + garis merah dulu) dan MERIAM KAPAL di kedua dinding yang menembak sejajar dek.
## Geyser sekaligus penyelamat: kalau jatuh ke jurang tepat saat menyembur, kamu terdorong naik lagi.
static func _ocean() -> Dictionary:
	return {
		"id": "ocean",
		"background": "res://assets/sprites/stages/ocean.png",
		"floor": "res://assets/sprites/stages/ocean_floor.png",
		"edge_color": Color("f2c27a"),
		"solids": _sym([Rect2(0, 640, 360, 80)]),
		"platforms": _sym([
			Rect2(60, 530, 200, 24),    # A  dek buritan (naik 110 dari lantai)
			Rect2(300, 450, 170, 24),   # B  tiang layar
			Rect2(110, 350, 170, 24),   # C  sarang gagak
			Rect2(540, 330, 200, 24),   # D  bendera tengah
		]),
		"crumble": _sym([
			Rect2(372, 570, 110, 24),   # papan lapuk di atas jurang
		]),
		"vents": _sym_vents([
			{"rect": Rect2(500, 380, 80, 284), "kind": "geyser", "first": 3.0, "rest": 3.4, "warn": 1.0, "active": 1.5,
				"lift": 4600.0, "rise": 640.0},
		]),
		"traps": [
			{"side": -1, "y": 500.0, "first": 6.0, "interval": 8.0, "kind": "cannon"},
			{"side": 1, "y": 500.0, "first": 6.0, "interval": 8.0, "kind": "cannon"},
		],
		"lava": [Rect2(360, 664, 560, 56)],
		"lava_colors": [Color(0.05, 0.38, 0.62, 0.93), Color(0.7, 0.95, 1.0, 0.95)],
		"ambient": "bubbles",
		"powerup_spots": _sym_pts([
			Vector2(160, 496), Vector2(385, 416), Vector2(195, 316),
			Vector2(640, 296), Vector2(260, 606),
		]),
		"respawn": Vector2(640, 280),
		"spawns": {
			2: [Vector2(150, 609), Vector2(1130, 609)],
			3: [Vector2(150, 609), Vector2(1130, 609), Vector2(640, 299)],
			4: [Vector2(150, 609), Vector2(1130, 609), Vector2(160, 499), Vector2(1120, 499)],
		},
	}


# ------------------------------------------------------------------ SPACE  "Orbital Station"
## Stasiun luar angkasa: dua LIFT ANTI-GRAVITASI (kolom cahaya biru, selalu aktif) mengantar ke dek atas,
## dan sepasang PORTAL (kiri <-> kanan) di dek luar memindahkan pemain ke sisi seberang.
## Lantai penuh, tanpa jurang, jadi map ini cepat dan penuh manuver.
static func _space() -> Dictionary:
	var portal_a := Rect2(72, 380, 56, 60)
	return {
		"id": "space",
		"background": "res://assets/sprites/stages/space.png",
		"floor": "res://assets/sprites/stages/space_floor.png",
		"edge_color": Color("5bf0ff"),
		"solids": [Rect2(0, 640, 1280, 80)],
		"platforms": _sym([
			Rect2(230, 540, 130, 24),   # pad rendah (naik 100 dari lantai)
			Rect2(60, 440, 160, 24),    # dek portal
			Rect2(330, 330, 180, 24),   # dek atas (di atas lift)
			Rect2(540, 430, 200, 24),   # jembatan tengah
		]),
		"vents": _sym_vents([
			{"rect": Rect2(390, 340, 90, 300), "kind": "antigrav", "first": 0.0, "rest": 0.0, "warn": 0.0, "active": 0.0,
				"lift": 3400.0, "rise": 400.0},
		]),
		"portals": [
			{"a": portal_a, "b": _m(portal_a), "color": Color("5bf0ff")},
		],
		"lava": [],
		"ambient": "stars",
		"powerup_spots": _sym_pts([
			Vector2(295, 506), Vector2(175, 406), Vector2(420, 296),
			Vector2(640, 396), Vector2(560, 606),
		]),
		"respawn": Vector2(640, 380),
		"spawns": {
			2: [Vector2(150, 609), Vector2(1130, 609)],
			3: [Vector2(150, 609), Vector2(1130, 609), Vector2(640, 399)],
			4: [Vector2(150, 609), Vector2(1130, 609), Vector2(185, 409), Vector2(1095, 409)],
		},
	}


# ------------------------------------------------------------------ FACTORY  "Iron Foundry"
## Pabrik baja: BAN BERJALAN (lantai menyeret ke tengah, dek atas menyeret ke luar) dan GERGAJI BULAT di rel:
## satu menyapu lantai tengah (tepat di ujung ban lantai), satu naik-turun di celah antar dek.
## Semua simetris; ban dan gergaji hanya mendorong / melukai, tidak pernah mengunci pemain.
static func _factory() -> Dictionary:
	return {
		"id": "factory",
		"background": "res://assets/sprites/stages/factory.png",
		"floor": "res://assets/sprites/stages/factory_floor.png",
		"edge_color": Color("ffc933"),
		"solids": [Rect2(0, 640, 1280, 80)],
		"platforms": _sym([
			Rect2(110, 530, 220, 24),   # L1  dek ban (naik 110)
			Rect2(380, 450, 170, 24),   # M1  dek tengah
			Rect2(80, 400, 170, 24),    # U1  dek luar atas
			Rect2(540, 340, 200, 24),   # T   catwalk puncak
		]),
		"conveyors": _sym_conv([
			{"rect": Rect2(330, 640, 200, 10), "speed": 120.0},     # lantai: menyeret ke tengah (ke arah gergaji)
			{"rect": Rect2(110, 530, 220, 10), "speed": -100.0},    # dek ban: menyeret ke luar
		]),
		"saws": [
			{"pos": Vector2(640, 612), "move": Vector2(150, 0), "period": 5.0, "phase": 0.0, "radius": 28.0},
			{"pos": Vector2(640, 470), "move": Vector2(0, 35), "period": 4.0, "phase": 0.0, "radius": 26.0},
		],
		"lava": [],
		"ambient": "sparks",
		"powerup_spots": _sym_pts([
			Vector2(220, 496), Vector2(465, 416), Vector2(165, 366),
			Vector2(640, 306), Vector2(260, 606),
		]),
		"respawn": Vector2(640, 290),
		"spawns": {
			2: [Vector2(150, 609), Vector2(1130, 609)],
			3: [Vector2(150, 609), Vector2(1130, 609), Vector2(640, 309)],
			4: [Vector2(150, 609), Vector2(1130, 609), Vector2(200, 499), Vector2(1080, 499)],
		},
	}
