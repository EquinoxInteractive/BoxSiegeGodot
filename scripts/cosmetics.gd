class_name Cosmetics
extends RefCounted
## Sistem KOIN, SHOP, INVENTORY & kosmetik (skin karakter, skin senjata, aksesoris).
## Data katalog ada di cosmetics_data.gd (dihasilkan tools/gen_all.py). Save terpisah: user://cosmetics.cfg.
##
## Konsep:
##   - Skin karakter  : tema yang sama (CosmeticsData.CHAR_SKINS) tersedia untuk tiap karakter, dibeli PER karakter.
##   - Skin senjata   : 5 per senjata (smith, kurval, flamer, scream, pistol, knife).
##   - Aksesoris      : 4 slot (head/face/neck/back), dibeli sekali, dipasang bebas PER (pemain P1-P4 + karakter + skin).
##   - Koin           : didapat dari menyelesaikan level CAMPAIGN (lihat award_level()).

const SAVE_PATH := "user://cosmetics.cfg"
const SLOTS := ["head", "face", "neck", "back"]
const SLOT_NAMES := {"head": "HEAD", "face": "FACE", "neck": "NECK", "back": "BACK"}
const WEAPON_IDS := ["smith", "kurval", "flamer", "scream", "pistol", "knife"]
const RARITY_COLORS := {
	"common": Color("c8cddc"), "rare": Color("46a0ff"), "epic": Color("be5aff"), "legendary": Color("ffcd3c"),
}
const RARITY_NAMES := {"common": "COMMON", "rare": "RARE", "epic": "EPIC", "legendary": "LEGENDARY"}
## Ukuran kanvas aksesoris (px) dan kotak karakter di dalamnya (karakter 180x180 di tengah).
const ACC_CANVAS := 340.0
const FACE_BOX := 180.0

static var _profile: Dictionary = {}
static var _loaded: bool = false
static var _tex_cache: Dictionary = {}
## --- cache performa (hanya menyimpan hasil hitung, tidak mengubah data/save) ---
static var _prefetched: Dictionary = {}        # path -> true (sudah diminta dimuat di thread latar)
static var _acc_idx: Dictionary = {}           # acc_id -> baris data aksesoris
static var _lo_cache: Dictionary = {}          # kunci loadout -> Dictionary (HANYA untuk UI, baca-saja)
static var _acc_tex_cache: Dictionary = {}     # acc_id -> Texture2D
static var _cskin_tex_cache: Dictionary = {}   # skin_id -> {char: Texture2D}
static var _wskin_tex_cache: Dictionary = {}   # weapon -> {skin_id: Texture2D}


# ------------------------------------------------------------------ save / load
static func _blank() -> Dictionary:
	return {
		"coins": 0,
		"skins": {},        # "char:skin_id" -> true
		"wskins": {},       # "weapon:skin_id" -> true
		"acc": {},          # acc_id -> true
		"loadouts": {},     # P1: "char:skin_id" | P2-P4: "p<n>:char:skin_id" -> {slot: acc_id}
		"last_cskin": {},   # "char" -> skin_id terakhir dipakai
		"last_wskin": {},   # "weapon" -> skin_id terakhir dipakai
		"pistol_skin": "",
		"knife_skin": "",
		"paid": {},         # level_n -> bintang terbaik yang sudah dibayar koin
	}


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_lo_cache.clear()
	_profile = _blank()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	var data: Variant = cfg.get_value("profile", "data", {})
	if data is Dictionary:
		var d: Dictionary = data
		for k in _profile.keys():
			if d.has(k) and typeof(d[k]) == typeof(_profile[k]):
				_profile[k] = d[k]


static func save() -> void:
	_ensure()
	_lo_cache.clear()
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "data", _profile)
	cfg.save(SAVE_PATH)


# ------------------------------------------------------------------ koin
static func coins() -> int:
	_ensure()
	return int(_profile["coins"])


static func add_coins(n: int) -> void:
	_ensure()
	_profile["coins"] = maxi(0, int(_profile["coins"]) + n)
	save()


static func can_afford(price: int) -> bool:
	return coins() >= price


## Rumus hadiah koin level campaign (nilai penuh = hadiah pertama kali selesai).
##   dasar 60 + 1.2 koin per nomor level, boss x1.5, pengali bintang 1* x1.0 / 2* x1.35 / 3* x1.8
static func level_value(level_n: int, stars: int, boss: bool) -> int:
	var base: float = 60.0 + 1.2 * float(level_n)
	if boss:
		base *= 1.5
	var mult: float = [1.0, 1.0, 1.35, 1.8][clampi(stars, 1, 3)]
	return int(round(base * mult))


## Dihitung & dibayarkan saat level selesai. Mengembalikan {"coins": n, "first": bool, "improved": bool}.
##   Pertama kali selesai : nilai penuh sesuai bintang.
##   Main ulang           : hanya 20% dari nilai bintang yang didapat (minimal 5 koin).
##   Bintang naik         : selisih nilai penuh ditambahkan (supaya mengejar bintang tetap berarti).
static func award_level(level_n: int, stars: int, boss: bool) -> Dictionary:
	_ensure()
	var paid: Dictionary = _profile["paid"]
	var prev: int = int(paid.get(level_n, 0))
	var gain: int = 0
	var first: bool = prev == 0
	var improved: bool = false
	if first:
		gain = level_value(level_n, stars, boss)
	else:
		gain = maxi(5, int(round(float(level_value(level_n, stars, boss)) * 0.2)))
		if stars > prev:
			improved = true
			gain += level_value(level_n, stars, boss) - level_value(level_n, prev, boss)
	paid[level_n] = maxi(prev, stars)
	_profile["paid"] = paid
	_profile["coins"] = int(_profile["coins"]) + gain
	save()
	return {"coins": gain, "first": first, "improved": improved}


# ------------------------------------------------------------------ katalog
static func char_skin_count() -> int:
	return CosmeticsData.CHAR_SKINS.size()


static func char_skin_info(sid: String) -> Array:
	for s in CosmeticsData.CHAR_SKINS:
		if String(s[0]) == sid:
			return s
	return []


static func weapon_skin_list(weapon: String) -> Array:
	return CosmeticsData.WEAPON_SKINS.get(weapon, [])


static func weapon_skin_info(weapon: String, sid: String) -> Array:
	for s in weapon_skin_list(weapon):
		if String(s[0]) == sid:
			return s
	return []


static func acc_info(aid: String) -> Array:
	if _acc_idx.is_empty():
		for a in CosmeticsData.ACCESSORIES:
			_acc_idx[String(a[0])] = a
	return _acc_idx.get(aid, [])


static func acc_list(slot: String = "") -> Array:
	if slot == "":
		return CosmeticsData.ACCESSORIES
	var out: Array = []
	for a in CosmeticsData.ACCESSORIES:
		if String(a[2]) == slot:
			out.append(a)
	return out


static func rarity_color(r: String) -> Color:
	return RARITY_COLORS.get(r, Color.WHITE)


# ------------------------------------------------------------------ kepemilikan & pembelian
static func owns_skin(ch: int, sid: String) -> bool:
	if sid == "":
		return true
	_ensure()
	return (_profile["skins"] as Dictionary).has("%d:%s" % [ch, sid])


static func owns_wskin(weapon: String, sid: String) -> bool:
	if sid == "":
		return true
	_ensure()
	return (_profile["wskins"] as Dictionary).has("%s:%s" % [weapon, sid])


static func owns_acc(aid: String) -> bool:
	if aid == "":
		return true
	_ensure()
	return (_profile["acc"] as Dictionary).has(aid)


static func owned_skin_ids(ch: int) -> Array:
	var out: Array = []
	for s in CosmeticsData.CHAR_SKINS:
		if owns_skin(ch, String(s[0])):
			out.append(String(s[0]))
	return out


static func owned_wskin_ids(weapon: String) -> Array:
	var out: Array = []
	for s in weapon_skin_list(weapon):
		if owns_wskin(weapon, String(s[0])):
			out.append(String(s[0]))
	return out


static func _spend(price: int) -> bool:
	if coins() < price:
		return false
	_profile["coins"] = int(_profile["coins"]) - price
	return true


static func buy_skin(ch: int, sid: String) -> bool:
	_ensure()
	var info: Array = char_skin_info(sid)
	if info.is_empty() or owns_skin(ch, sid) or not _spend(int(info[3])):
		return false
	(_profile["skins"] as Dictionary)["%d:%s" % [ch, sid]] = true
	save()
	return true


static func buy_wskin(weapon: String, sid: String) -> bool:
	_ensure()
	var info: Array = weapon_skin_info(weapon, sid)
	if info.is_empty() or owns_wskin(weapon, sid) or not _spend(int(info[3])):
		return false
	(_profile["wskins"] as Dictionary)["%s:%s" % [weapon, sid]] = true
	save()
	return true


static func buy_acc(aid: String) -> bool:
	_ensure()
	var info: Array = acc_info(aid)
	if info.is_empty() or owns_acc(aid) or not _spend(int(info[3])):
		return false
	(_profile["acc"] as Dictionary)[aid] = true
	save()
	return true


static func owned_counts() -> Dictionary:
	_ensure()
	var total_skins: int = Global.character_count() * char_skin_count()
	var total_w: int = 0
	for w in WEAPON_IDS:
		total_w += weapon_skin_list(w).size()
	return {
		"skins": (_profile["skins"] as Dictionary).size(), "skins_total": total_skins,
		"wskins": (_profile["wskins"] as Dictionary).size(), "wskins_total": total_w,
		"acc": (_profile["acc"] as Dictionary).size(), "acc_total": CosmeticsData.ACCESSORIES.size(),
	}


# ------------------------------------------------------------------ loadout aksesoris (per pemain + karakter + skin)
## Kunci simpanan. P1 (pl = 0) memakai format lama "char:skin" supaya data lama tetap terbaca;
## P2-P4 memakai "p<n>:char:skin". Jadi tiap pemain bisa punya set aksesoris sendiri di karakter + skin yang sama.
static func _lk(ch: int, sid: String, pl: int = 0) -> String:
	if pl <= 0:
		return "%d:%s" % [ch, sid]
	return "p%d:%d:%s" % [pl, ch, sid]


static func loadout(ch: int, sid: String, pl: int = 0) -> Dictionary:
	_ensure()
	var lo: Dictionary = (_profile["loadouts"] as Dictionary).get(_lk(ch, sid, pl), {})
	var out: Dictionary = {}
	for slot in SLOTS:
		var aid: String = String(lo.get(slot, ""))
		if aid != "" and owns_acc(aid):
			out[slot] = aid
	return out


## Sama seperti loadout(), tapi hasilnya disimpan sampai data berubah (dipanggil tiap frame oleh UI).
## JANGAN diubah isinya oleh pemanggil (pakai .duplicate() kalau perlu mengubah).
static func loadout_cached(ch: int, sid: String, pl: int = 0) -> Dictionary:
	_ensure()
	var k: String = _lk(ch, sid, pl)
	if _lo_cache.has(k):
		return _lo_cache[k]
	var d: Dictionary = loadout(ch, sid, pl)
	_lo_cache[k] = d
	return d


static func set_acc(ch: int, sid: String, slot: String, aid: String, pl: int = 0) -> void:
	_ensure()
	var all: Dictionary = _profile["loadouts"]
	var lo: Dictionary = all.get(_lk(ch, sid, pl), {})
	if aid == "":
		lo.erase(slot)
	else:
		lo[slot] = aid
	all[_lk(ch, sid, pl)] = lo
	_profile["loadouts"] = all
	save()


# ------------------------------------------------------------------ pilihan terakhir
static func last_cskin(ch: int) -> String:
	_ensure()
	var s: String = String((_profile["last_cskin"] as Dictionary).get(str(ch), ""))
	return s if owns_skin(ch, s) else ""


static func set_last_cskin(ch: int, sid: String) -> void:
	_ensure()
	(_profile["last_cskin"] as Dictionary)[str(ch)] = sid
	save()


static func last_wskin(weapon: String) -> String:
	_ensure()
	var s: String = String((_profile["last_wskin"] as Dictionary).get(weapon, ""))
	return s if owns_wskin(weapon, s) else ""


static func set_last_wskin(weapon: String, sid: String) -> void:
	_ensure()
	(_profile["last_wskin"] as Dictionary)[weapon] = sid
	save()


# ------------------------------------------------------------------ tekstur
## Minta Godot memuat tekstur di THREAD LATAR BELAKANG (tidak menghentikan game). Nanti load_tex() tinggal mengambilnya.
## Dulu tekstur baru dimuat saat pertama kali digambar -> patah-patah tepat ketika animasi buka tab / karakter berjalan.
static func prefetch(path: String) -> void:
	if _tex_cache.has(path) or _prefetched.has(path):
		return
	_prefetched[path] = true
	if ResourceLoader.exists(path):
		ResourceLoader.load_threaded_request(path)


## Antrian pemanasan: daftar file yang akan diminta dimuat di thread latar, sedikit demi sedikit per frame
## (supaya selesainya tidak menumpuk di satu frame). Dipanggil dari MENU, jadi Shop/Inventory sudah siap saat dibuka.
static var _warm_q: Array = []


static func warm_build(ch: int, weapon: String) -> void:
	_warm_q.clear()
	_warm_q.append("res://scenes/shop.tscn")
	_warm_q.append("res://scenes/inventory.tscn")
	for i in Global.character_count():
		var info: Array = Global.CHARACTERS[i]
		_warm_q.append("res://assets/sprites/characters/%s/%s.png" % [info[0], info[1]])
	for w in WEAPON_IDS:
		_warm_q.append("res://assets/sprites/guns/p1/%s.png" % String(w))
	if ch >= 0 and ch < Global.character_count():
		for s in CosmeticsData.CHAR_SKINS:
			_warm_q.append("res://assets/sprites/skins/%s/%s.png" % [char_name(ch), String(s[0])])
	for s in weapon_skin_list(weapon):
		_warm_q.append("res://assets/sprites/weaponskins/%s/%s.png" % [weapon, String(s[0])])
	for a in CosmeticsData.ACCESSORIES:
		_warm_q.append("res://assets/sprites/accessories/%s.png" % String(a[0]))


## Minta n file dari antrian. Return true kalau antrian sudah habis.
static func warm_step(n: int) -> bool:
	var k: int = 0
	while k < n and not _warm_q.is_empty():
		prefetch(String(_warm_q.pop_front()))
		k += 1
	return _warm_q.is_empty()


static func prefetch_accessories() -> void:
	for a in CosmeticsData.ACCESSORIES:
		prefetch("res://assets/sprites/accessories/%s.png" % String(a[0]))


static func prefetch_char_skins(ch: int) -> void:
	if ch < 0 or ch >= Global.character_count():
		return
	for s in CosmeticsData.CHAR_SKINS:
		prefetch("res://assets/sprites/skins/%s/%s.png" % [char_name(ch), String(s[0])])


static func prefetch_weapon_skins(weapon: String) -> void:
	for s in weapon_skin_list(weapon):
		prefetch("res://assets/sprites/weaponskins/%s/%s.png" % [weapon, String(s[0])])


static func prefetch_base_chars() -> void:
	for i in Global.character_count():
		var info: Array = Global.CHARACTERS[i]
		prefetch("res://assets/sprites/characters/%s/%s.png" % [info[0], info[1]])


static func prefetch_base_weapons() -> void:
	for w in WEAPON_IDS:
		prefetch("res://assets/sprites/guns/p1/%s.png" % String(w))


static func load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null:
		# cadangan kalau PNG belum sempat di-import editor (mis. saat dites langsung)
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null:
			tex = ImageTexture.create_from_image(img)
	_tex_cache[path] = tex
	return tex


static func char_name(ch: int) -> String:
	return String(Global.CHARACTERS[ch][1])


## Tekstur karakter dengan skin. sid "" = sprite asli (pakai Global.character_texture).
static func char_tex(ch: int, sid: String, dead: bool = false, base_slot: int = 0) -> Texture2D:
	if dead or base_slot != 0:
		return _char_tex_raw(ch, sid, dead, base_slot)
	var per: Dictionary = _cskin_tex_cache.get(sid, {})
	if per.has(ch):
		return per[ch]
	var tx: Texture2D = _char_tex_raw(ch, sid, dead, base_slot)
	if tx != null:
		per[ch] = tx
		_cskin_tex_cache[sid] = per
	return tx


static func _char_tex_raw(ch: int, sid: String, dead: bool, base_slot: int) -> Texture2D:
	if sid == "":
		return Global.character_texture(base_slot, ch, dead)
	var path: String = "res://assets/sprites/skins/%s/%s%s.png" % [char_name(ch), sid, "_die" if dead else ""]
	var t: Texture2D = load_tex(path)
	return t if t != null else Global.character_texture(base_slot, ch, dead)


static func weapon_tex(weapon: String, sid: String, base_player: int = 0) -> Texture2D:
	if base_player != 0:
		return _weapon_tex_raw(weapon, sid, base_player)
	var per: Dictionary = _wskin_tex_cache.get(weapon, {})
	if per.has(sid):
		return per[sid]
	var tx: Texture2D = _weapon_tex_raw(weapon, sid, base_player)
	if tx != null:
		per[sid] = tx
		_wskin_tex_cache[weapon] = per
	return tx


static func _weapon_tex_raw(weapon: String, sid: String, base_player: int) -> Texture2D:
	if sid == "":
		return Global.weapon_texture(base_player, weapon)
	var t: Texture2D = load_tex("res://assets/sprites/weaponskins/%s/%s.png" % [weapon, sid])
	return t if t != null else Global.weapon_texture(base_player, weapon)


static func acc_tex(aid: String) -> Texture2D:
	if _acc_tex_cache.has(aid):
		return _acc_tex_cache[aid]
	var tx: Texture2D = load_tex("res://assets/sprites/accessories/%s.png" % aid)
	if tx != null:
		_acc_tex_cache[aid] = tx
	return tx


static func coin_tex() -> Texture2D:
	return load_tex("res://assets/sprites/ui/coin.png")


## Warna peluru dari skin senjata (Color dengan alpha 0 = tidak ada override).
static func bullet_color(weapon: String, sid: String) -> Color:
	if sid == "":
		return Color(0, 0, 0, 0)
	var info: Array = weapon_skin_info(weapon, sid)
	return Color(String(info[4])) if not info.is_empty() else Color(0, 0, 0, 0)


# ------------------------------------------------------------------ pasang aksesoris di sprite
## Menambah Sprite2D aksesoris sebagai anak `holder` (biasanya sprite badan). Posisi wajah menyesuaikan karakter.
## `holder_tex_size` = ukuran tekstur karakter (180) supaya skala aksesoris ikut.
static func attach_accessories(holder: Node2D, ch: int, lo: Dictionary) -> Array:
	var made: Array = []
	for slot in SLOTS:
		if not lo.has(slot):
			continue
		var info: Array = acc_info(String(lo[slot]))
		if info.is_empty():
			continue
		var tex: Texture2D = acc_tex(String(lo[slot]))
		if tex == null:
			continue
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.name = "Acc_" + slot
		if String(info[5]) == "back":
			sp.show_behind_parent = true
		if slot == "face":
			var ey: float = float(CosmeticsData.EYE_Y[ch]) if ch >= 0 and ch < CosmeticsData.EYE_Y.size() else 60.0
			sp.position.y = ey - 60.0     # aksesoris wajah digambar dengan garis mata 60px dari atas kotak
		holder.add_child(sp)
		made.append(sp)
	return made


# ------------------------------------------------------------------ gabungan: pasang semua kosmetik ke Player
## `sel` = entri Global.selections / fighter campaign: {"character", "weapon", "skin", "wskin", "pskin", "kskin"}.
## Semua skin senjata (utama, pistol, pisau) dipilih di layar pilih fighter. Aksesoris diambil dari loadout
## milik pemain ini (p.index) untuk karakter + skin yang dipakai.
static func apply_to_player(p: Player, sel: Dictionary) -> void:
	var ch: int = int(sel["character"])
	var skin: String = String(sel.get("skin", last_cskin(ch)))
	if not owns_skin(ch, skin):
		skin = ""
	var ws: Dictionary = {}
	var main_w: String = String(sel["weapon"])
	var wsk: String = String(sel.get("wskin", ""))
	if owns_wskin(main_w, wsk):
		ws[main_w] = wsk
	for extra in ["pistol", "knife"]:
		var e: String = String(sel.get("pskin" if extra == "pistol" else "kskin", ""))
		if e != "" and owns_wskin(extra, e):
			ws[extra] = e
	p.apply_cosmetics(skin, ws, loadout(ch, skin, int(p.index)))


# ------------------------------------------------------------------ gambar aksesoris di UI (preview)
## Menggambar aksesoris sebuah loadout di sekitar kotak karakter `face` (rect piksel layar).
## pass_id: 0 = lapisan belakang (sayap, jubah, aura), 1 = lapisan depan (topi, kacamata, kalung).
static func draw_accessories(ci: CanvasItem, ch: int, lo: Dictionary, face: Rect2, tint: Color, pass_id: int) -> void:
	if lo.is_empty():
		return
	var k: float = face.size.x / FACE_BOX
	for slot in SLOTS:
		if not lo.has(slot):
			continue
		var info: Array = acc_info(String(lo[slot]))
		if info.is_empty():
			continue
		var is_back: bool = String(info[5]) == "back"
		if (pass_id == 0) != is_back:
			continue
		var tex: Texture2D = acc_tex(String(lo[slot]))
		if tex == null:
			continue
		var dy: float = 0.0
		if slot == "face":
			dy = (float(CosmeticsData.EYE_Y[ch]) - 60.0) * k
		var side: float = ACC_CANVAS * k
		var origin: Vector2 = face.position - Vector2(80.0, 80.0) * k + Vector2(0.0, dy)
		ci.draw_texture_rect(tex, Rect2(origin, Vector2(side, side)), false, tint)


## Preview lengkap (belakang -> karakter -> depan) untuk Shop/Inventory.
static func draw_preview(ci: CanvasItem, ch: int, sid: String, lo: Dictionary, face: Rect2, tint: Color = Color.WHITE) -> void:
	draw_accessories(ci, ch, lo, face, tint, 0)
	var tex: Texture2D = char_tex(ch, sid)
	if tex != null:
		ci.draw_texture_rect(tex, face, false, tint)
	draw_accessories(ci, ch, lo, face, tint, 1)
