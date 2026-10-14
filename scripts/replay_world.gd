class_name ReplayWorld
extends Node2D
## Dunia replay: menggambar ulang arena + pemain + peluru dari rekaman (lihat replay_recorder.gd).
## Tidak ada fisika / input / AI di sini - semua posisi dibaca dari snapshot dan diinterpolasi supaya halus.
## Pemain memakai class Player yang sama dengan game (sprite, skin, aksesoris, senjata, efek status) tapi proses fisikanya dimatikan.

const WeaponFx = preload("res://scripts/weapon_fx.gd")

var header: Dictionary = {}
var map: Dictionary = {}
var flat: PackedFloat32Array = PackedFloat32Array()
var starts: PackedInt32Array = PackedInt32Array()
var times: PackedFloat32Array = PackedFloat32Array()
var weapons: Array = []
var pu_types: Array = []
var duration: float = 0.0

var p_count: int = 0
var m_count: int = 0
var s_count: int = 0
var c_count: int = 0

var actors: Array[Player] = []
var moving: Array = []
var saws: Array = []
var crumbles: Array = []
var vents: Array = []

var bullets_root: Node2D
var powerups_root: Node2D
var players_root: Node2D
var fx_root: Node2D
var dummy_traps: Node2D

var bullet_nodes: Dictionary = {}      # id -> Bullet
var pu_nodes: Dictionary = {}          # id -> Powerup
var arrow_nodes: Dictionary = {}       # id -> Hazards.Arrow
var _bullet_last: Dictionary = {}      # id -> [pos, dir, weapon]

var _alive_vis: Array = []             # tampilan "hidup / mati" yang sedang dipasang di tiap pemain
var _last_hp: Array = []
var _last_weapon: Array = []
var _last_knife: Array = []
var _last_vanished: Array = []
var _sfx_gap: Dictionary = {}

var cur_i: int = 0                     # indeks snapshot yang sedang ditampilkan
var cur_t: float = 0.0
var _a: int = 0
var _b: int = 0
var _k: float = 0.0
var hit_flash: Array[float] = []       # per pemain: kilat darah di HUD
var sound_on: bool = true
var _rng := RandomNumberGenerator.new()


# ================================================================== membangun
## data = isi file .rpl yang sudah dimuat (ReplayStore.load_replay). Mengembalikan false kalau rusak.
func build(data: Dictionary) -> bool:
	if not (data.has("header") and data.has("flat") and data.has("starts")):
		return false
	_rng.randomize()
	header = data["header"]
	map = header["map"]
	flat = data["flat"]
	starts = data["starts"]
	weapons = data.get("weapons", [])
	pu_types = data.get("pu_types", [])
	var cnt: Array = header["counts"]
	p_count = int(cnt[0])
	m_count = int(cnt[1])
	s_count = int(cnt[2])
	c_count = int(cnt[3])
	if starts.is_empty():
		return false
	times.resize(starts.size())
	for i in starts.size():
		times[i] = flat[starts[i]]
	duration = times[times.size() - 1]

	_build_world()
	_build_actors()
	apply(0.0, false)
	return true


func _build_world() -> void:
	var bg := Sprite2D.new()
	bg.texture = load(String(map["background"]))
	bg.centered = false
	bg.scale = Vector2(4, 4)
	bg.z_index = -100
	bg.modulate = map.get("tint", Color.WHITE)
	add_child(bg)

	var floor_tex: Texture2D = load(String(map["floor"]))
	var edge: Color = map["edge_color"]
	for r in map["solids"]:
		_add_block(r, floor_tex, edge, false)
	for r in map["platforms"]:
		_add_block(r, floor_tex, edge, true)
	for r in map["lava"]:
		_add_lava(r)

	dummy_traps = Node2D.new()
	add_child(dummy_traps)

	for d in map.get("moving", []):
		var mp := Hazards.MovingPlatform.new()
		mp.setup(d["rect"], floor_tex, edge, d["move"], float(d["period"]), float(d["phase"]))
		add_child(mp)
		_freeze_body(mp)
		moving.append(mp)
	for r in map.get("crumble", []):
		var cp := Hazards.CrumblePlatform.new()
		cp.setup(r, floor_tex, edge)
		add_child(cp)
		_freeze_body(cp)
		cp.sensor.monitoring = false
		crumbles.append(cp)
	for d in map.get("spikes", []):
		var strip := Hazards.SpikeStrip.new()
		strip.setup(d["rect"], String(d["style"]))
		add_child(strip)
	for d in map.get("bounce", []):
		var pad := Hazards.BouncePad.new()
		pad.setup(d["rect"], float(d["power"]))
		add_child(pad)
	for r in map.get("ice", []):
		add_child(Hazards.ice(r))
	for d in map.get("traps", []):
		var tr := Hazards.DartTrap.new()
		tr.setup(int(d["side"]), float(d["y"]), float(d["first"]), float(d["interval"]), dummy_traps, String(d.get("kind", "dart")))
		add_child(tr)
		tr.set_process(false)
		tr.set_physics_process(false)
	for d in map.get("vents", []):
		var vt := Hazards.UpdraftVent.new()
		vt.setup(d["rect"], String(d["kind"]), float(d.get("first", 3.0)), float(d.get("rest", 3.4)), float(d.get("warn", 1.0)),
			float(d.get("active", 1.5)), float(d.get("lift", 4600.0)), float(d.get("rise", 640.0)))
		add_child(vt)
		vents.append(vt)
	for d in map.get("portals", []):
		var pa := Hazards.Portal.new()
		var pb := Hazards.Portal.new()
		pa.setup(d["a"], d["color"], 0.0)
		pb.setup(d["b"], d["color"], 1.7)
		pa.partner = pb
		pb.partner = pa
		add_child(pa)
		add_child(pb)
	for d in map.get("conveyors", []):
		var cv := Hazards.Conveyor.new()
		cv.setup(d["rect"], float(d["speed"]))
		add_child(cv)
	for d in map.get("saws", []):
		var sw := Hazards.SawBlade.new()
		sw.setup(d["pos"], d["move"], float(d["period"]), float(d["phase"]), float(d["radius"]))
		add_child(sw)
		sw.set_physics_process(false)
		sw.area.monitoring = false
		saws.append(sw)
	var amb := Hazards.ambient(String(map.get("ambient", "")))
	if amb != null:
		add_child(amb)

	bullets_root = Node2D.new()
	add_child(bullets_root)
	powerups_root = Node2D.new()
	add_child(powerups_root)
	players_root = Node2D.new()
	add_child(players_root)
	fx_root = Node2D.new()
	add_child(fx_root)


func _freeze_body(b: CollisionObject2D) -> void:
	b.set_physics_process(false)
	b.collision_layer = 0
	b.collision_mask = 0


func _add_block(rect: Rect2, tex: Texture2D, edge: Color, one_way: bool) -> void:
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.centered = false
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, rect.size.x / 4.0, rect.size.y / 4.0)
	spr.scale = Vector2(4, 4)
	spr.position = rect.position
	spr.z_index = -10
	spr.modulate = map.get("floor_tint", Color.WHITE)
	add_child(spr)
	var strip := ColorRect.new()
	strip.color = edge
	strip.position = rect.position
	strip.size = Vector2(rect.size.x, 6)
	strip.z_index = -9
	add_child(strip)
	if one_way:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.35)
		shade.position = rect.position + Vector2(0, rect.size.y - 4)
		shade.size = Vector2(rect.size.x, 4)
		shade.z_index = -9
		add_child(shade)


func _add_lava(rect: Rect2) -> void:
	var cols: Array = map.get("lava_colors", [Color(1.0, 0.33, 0.05, 0.95), Color(1.0, 0.8, 0.2, 0.9)])
	var cr := ColorRect.new()
	cr.color = cols[0]
	cr.position = rect.position
	cr.size = rect.size
	cr.z_index = 1
	add_child(cr)
	var glow := ColorRect.new()
	glow.color = cols[1]
	glow.position = rect.position
	glow.size = Vector2(rect.size.x, 8)
	glow.z_index = 2
	add_child(glow)
	var tw := create_tween().set_loops()
	tw.tween_property(glow, "modulate:a", 0.4, 0.6)
	tw.tween_property(glow, "modulate:a", 1.0, 0.6)


func _build_actors() -> void:
	var plist: Array = header["players"]
	var team_mode: bool = bool(header.get("team_mode", false))
	for i in p_count:
		var pd: Dictionary = plist[i]
		var p := Player.new()
		players_root.add_child(p)
		p.setup(int(pd["index"]), int(pd["char"]), String(pd["weapon"]), self)
		p.apply_cosmetics(String(pd.get("skin", "")), pd.get("wskins", {}), pd.get("loadout", {}))
		if team_mode:
			p.apply_team_balance(int(pd["team"]), pd["team_color"], int(pd.get("team_level", 0)), {})
		p.set_physics_process(false)
		p.set_process(false)
		p.collision_layer = 0
		p.collision_mask = 0
		p.controls_enabled = false
		actors.append(p)
		_alive_vis.append(true)
		_last_hp.append(-1.0)
		_last_weapon.append(-1)
		_last_knife.append(-1.0)
		_last_vanished.append(false)
		hit_flash.append(0.0)


# ================================================================== membaca snapshot
func _find_frame(t: float) -> int:
	var lo: int = 0
	var hi: int = times.size() - 1
	while lo < hi:
		var mid: int = (lo + hi + 1) / 2
		if times[mid] <= t:
			lo = mid
		else:
			hi = mid - 1
	return lo


## Nilai header snapshot saat ini (state, time_left, sudden death, round).
func head(idx: int) -> float:
	return flat[_a + idx]


func pl(i: int, idx: int) -> float:
	return flat[_a + ReplayRecorder.H + i * ReplayRecorder.PS + idx]


func frame_time(i: int) -> float:
	return times[clampi(i, 0, times.size() - 1)]


## Tampilkan keadaan pada waktu t. fx_ok = true kalau waktu berjalan maju normal (efek & suara boleh muncul);
## false kalau loncat / seek (tanpa efek supaya tidak berisik).
func apply(t: float, fx_ok: bool) -> void:
	if times.is_empty():
		return
	t = clampf(t, 0.0, duration)
	var i: int = _find_frame(t)
	var j: int = mini(i + 1, times.size() - 1)
	var ta: float = times[i]
	var tb: float = times[j]
	var k: float = 0.0
	if tb > ta + 0.00001:
		k = clampf((t - ta) / (tb - ta), 0.0, 1.0)
	cur_i = i
	cur_t = t
	_a = starts[i]
	_b = starts[j]
	_k = k

	var P: int = ReplayRecorder.PS
	for n in p_count:
		_apply_player(n, fx_ok)
	var off: int = ReplayRecorder.H + p_count * P
	# platform bergerak, gergaji, platform rapuh
	for m in m_count:
		var mp: Node2D = moving[m]
		mp.position = _lerp_v2(off + m * 2)
	off += m_count * 2
	for s in s_count:
		var sw: Node2D = saws[s]
		sw.position = _lerp_v2(off + s * 2)
	off += s_count * 2
	for c in c_count:
		var cp: Hazards.CrumblePlatform = crumbles[c]
		var mode: int = int(flat[_a + off + c * 2])
		var alpha: float = flat[_a + off + c * 2 + 1]
		if mode == 1:
			cp.art.position = Vector2(_rng.randf_range(-2.5, 2.5), _rng.randf_range(-1.5, 1.5))
			cp.art.modulate = Color(1.0, 0.75 + 0.2 * sin(t * 40.0), 0.6, alpha)
		else:
			cp.art.position = Vector2.ZERO
			cp.art.modulate = Color(1.0, 0.93, 0.82, alpha)
	off += c_count * 2
	_apply_objects(off, fx_ok)


func _lerp_v2(rel: int) -> Vector2:
	var va := Vector2(flat[_a + rel], flat[_a + rel + 1])
	var vb := Vector2(flat[_b + rel], flat[_b + rel + 1])
	return va.lerp(vb, _k)


func _apply_player(n: int, fx_ok: bool) -> void:
	var p: Player = actors[n]
	var base: int = ReplayRecorder.H + n * ReplayRecorder.PS
	var pa: int = _a + base
	var pb: int = _b + base
	var alive: bool = flat[pa + ReplayRecorder.PL_ALIVE] > 0.5
	var vanished: bool = flat[pa + ReplayRecorder.PL_VANISHED] > 0.5

	# posisi: interpolasi, kecuali lompatan jauh (respawn / portal / swap) langsung pindah
	var pos_a := Vector2(flat[pa + ReplayRecorder.PL_X], flat[pa + ReplayRecorder.PL_Y])
	var pos_b := Vector2(flat[pb + ReplayRecorder.PL_X], flat[pb + ReplayRecorder.PL_Y])
	var same_state: bool = (flat[pb + ReplayRecorder.PL_ALIVE] > 0.5) == alive
	if same_state and pos_a.distance_to(pos_b) < 240.0:
		p.position = pos_a.lerp(pos_b, _k)
	else:
		p.position = pos_a
	p.facing = int(flat[pa + ReplayRecorder.PL_FACE])

	# hidup / mati
	if alive != bool(_alive_vis[n]):
		_alive_vis[n] = alive
		_set_alive_visual(p, alive)
		if not alive and fx_ok:
			UIKit.burst(fx_root, p.position, Global.PLAYER_COLORS[p.index], 36, 520.0, 9.0, 0.9)
			UIKit.burst(fx_root, p.position, Color.WHITE, 14, 380.0, 6.0, 0.5)
			UIKit.ring(fx_root, p.position, Global.PLAYER_COLORS[p.index], 160.0, 0.55)
			_sfx("dead", 0.0)
	var hp: float = flat[pa + ReplayRecorder.PL_HP]
	if fx_ok and float(_last_hp[n]) >= 0.0 and hp < float(_last_hp[n]) - 0.001 and alive:
		hit_flash[n] = 1.0
		UIKit.burst(fx_root, p.position, Global.PLAYER_COLORS[p.index].lightened(0.2), 8, 220.0, 6.0, 0.45)
		_sfx("hit", -4.0)
	_last_hp[n] = hp
	p.hp = hp
	p.alive = alive          # dibaca HUD asli (potret K.O., kartu redup)
	p.visible = not vanished

	# senjata yang dipegang
	var wi: int = int(flat[pa + ReplayRecorder.PL_WEAPON])
	if wi != int(_last_weapon[n]):
		_last_weapon[n] = wi
		var wid: String = String(weapons[wi]) if wi >= 0 and wi < weapons.size() else p.weapon_id
		# HUD asli (PlayerHud) membaca current_weapon(): pisau dipegang = knife_out, senjata cadangan lewat jumlah peluru
		p.knife_out = wid == Global.MELEE_WEAPON
		_set_weapon(p, wid)

	# animasi senjata (pegas / tebasan dipakai langsung dari rekaman)
	p.kick = lerpf(flat[pa + ReplayRecorder.PL_KICK], flat[pb + ReplayRecorder.PL_KICK], _k)
	var kn: float = flat[pa + ReplayRecorder.PL_KNIFE_T]
	p.knife_t = kn
	p.swap_anim = flat[pa + ReplayRecorder.PL_SWAP_ANIM]
	if fx_ok and kn >= 0.0 and float(_last_knife[n]) < 0.0 and alive:
		WeaponFx.slash(fx_root, p.position + Vector2(p.facing * 10.0, 6.0), p.facing)
		if sound_on:
			Global.play_slash(-6.0)
	_last_knife[n] = kn
	p._animate_gun(0.0)

	# status power up (dibaca oleh StatusFx milik pemain)
	p.ammo = int(flat[pa + ReplayRecorder.PL_AMMO])
	p.invis_time = flat[pa + ReplayRecorder.PL_INVIS]
	p.shield_hits = int(flat[pa + ReplayRecorder.PL_SHIELD_HITS])
	p.shield_time = flat[pa + ReplayRecorder.PL_SHIELD_TIME]
	p.swap_time = flat[pa + ReplayRecorder.PL_SWAP_TIME]
	p.speed_time = flat[pa + ReplayRecorder.PL_SPEED]
	p.jump_time = flat[pa + ReplayRecorder.PL_JUMP]
	p.invuln = flat[pa + ReplayRecorder.PL_INVULN]

	# penampilan badan
	var bs: float = p.base_scale
	p.body_sprite.scale = Vector2(flat[pa + ReplayRecorder.PL_SQ_X], flat[pa + ReplayRecorder.PL_SQ_Y]) * bs
	var fl: float = flat[pa + ReplayRecorder.PL_FLASH]
	p.body_sprite.modulate = Color(fl, fl, fl, 1.0)
	var a: float = flat[pa + ReplayRecorder.PL_ALPHA]
	if alive:
		var shown: bool = flat[pa + ReplayRecorder.PL_BODY_SHOWN] > 0.5
		p.tag.visible = shown
		p.fx.visible = shown
		if p.team_mark != null:
			p.team_mark.visible = shown
		# Invisible: di game asli tubuhnya hilang total. Di replay ditampilkan samar supaya penonton tetap bisa mengikutinya.
		p.modulate.a = a if shown else minf(a, 0.3)
	else:
		p.modulate.a = a


func _set_alive_visual(p: Player, alive: bool) -> void:
	if alive:
		p.body_sprite.texture = p.portrait_tex(false)
		p.modulate = Color.WHITE
		p.z_index = 0
		p._show_accessories(true)
		p.body_sprite.visible = true
		p.gun_sprite.visible = true
		p.tag.visible = true
		p.fx.visible = true
		p.fx.reset()
		if p.team_mark != null:
			p.team_mark.visible = true
	else:
		p.body_sprite.visible = true
		p.fx.visible = false
		p.modulate = Color(1, 1, 1, 0.85)
		p.z_index = -1
		p.body_sprite.texture = p.portrait_tex(true)
		p._show_accessories(false)
		p.gun_sprite.visible = false
		p.tag.visible = false
		if p.team_mark != null:
			p.team_mark.visible = false


func _set_weapon(p: Player, id: String) -> void:
	if not Global.WEAPONS.has(id):
		return
	p.shown_weapon = id
	var tex: Texture2D = p.weapon_tex_for(id)
	p.gun_sprite.texture = tex
	p.gun_tex_w = float(tex.get_width())
	p.gun_len = float(Global.WEAPONS[id].get("hold_len", 56.0))
	p.gun_base_scale = p.gun_len / p.gun_tex_w
	p.gun_sprite.scale = Vector2.ONE * p.gun_base_scale


# ------------------------------------------------------------------ peluru, power up, panah
func _apply_objects(off: int, fx_ok: bool) -> void:
	var nb: int = int(flat[_a + 5])
	var npu: int = int(flat[_a + 6])
	var nar: int = int(flat[_a + 7])
	var nb_b: int = int(flat[_b + 5])
	var npu_b: int = int(flat[_b + 6])
	var nar_b: int = int(flat[_b + 7])
	var off_b: int = ReplayRecorder.H + p_count * ReplayRecorder.PS + (m_count + s_count + c_count) * 2

	# ---- peluru
	var seen: Dictionary = {}
	for n in nb:
		var o: int = _a + off + n * ReplayRecorder.BUL
		var id: int = int(flat[o])
		var pos := Vector2(flat[o + 1], flat[o + 2])
		# cari peluru yang sama di snapshot berikutnya untuk interpolasi
		if _b != _a:
			for m in nb_b:
				var ob: int = _b + off_b + m * ReplayRecorder.BUL
				if int(flat[ob]) == id:
					pos = pos.lerp(Vector2(flat[ob + 1], flat[ob + 2]), _k)
					break
		var dir: int = int(flat[o + 3])
		var wid: String = String(weapons[int(flat[o + 4])])
		var shooter: int = int(flat[o + 5])
		var bu = bullet_nodes.get(id, null)
		if bu == null or not is_instance_valid(bu):
			bu = _make_bullet(dir, wid, shooter)
			bullet_nodes[id] = bu
			if fx_ok:
				WeaponFx.muzzle(fx_root, pos, dir, wid)
				_gun_sfx(wid)
		bu.position = pos
		_bullet_last[id] = [pos, dir, wid]
		seen[id] = true
	for id in bullet_nodes.keys():
		if seen.has(id):
			continue
		var gone = bullet_nodes[id]
		if is_instance_valid(gone):
			gone.queue_free()
		bullet_nodes.erase(id)
		if fx_ok and _bullet_last.has(id):
			var lst: Array = _bullet_last[id]
			WeaponFx.impact(fx_root, lst[0], String(lst[2]), int(lst[1]), false)
		_bullet_last.erase(id)
	off += nb * ReplayRecorder.BUL
	off_b += nb_b * ReplayRecorder.BUL

	# ---- power up
	var seen_pu: Dictionary = {}
	for n in npu:
		var o2: int = _a + off + n * ReplayRecorder.PUP
		var id2: int = int(flat[o2])
		var ptype: String = String(pu_types[int(flat[o2 + 3])])
		var pu = pu_nodes.get(id2, null)
		if pu == null or not is_instance_valid(pu):
			pu = Powerup.new()
			pu.setup(ptype)
			powerups_root.add_child(pu)
			pu.collision_mask = 0
			pu.monitoring = false
			pu_nodes[id2] = pu
		pu.life = flat[o2 + 4] + 0.2      # selisih kecil supaya Powerup tidak menghapus dirinya sendiri
		pu.global_position = Vector2(flat[o2 + 1], flat[o2 + 2])
		seen_pu[id2] = true
	for id2 in pu_nodes.keys():
		if seen_pu.has(id2):
			continue
		var gp = pu_nodes[id2]
		if is_instance_valid(gp):
			gp.queue_free()
		pu_nodes.erase(id2)
	off += npu * ReplayRecorder.PUP
	off_b += npu_b * ReplayRecorder.PUP

	# ---- panah / bola meriam jebakan
	var seen_ar: Dictionary = {}
	for n in nar:
		var o3: int = _a + off + n * ReplayRecorder.ARW
		var id3: int = int(flat[o3])
		var apos := Vector2(flat[o3 + 1], flat[o3 + 2])
		if _b != _a:
			for m in nar_b:
				var ob3: int = _b + off_b + m * ReplayRecorder.ARW
				if int(flat[ob3]) == id3:
					apos = apos.lerp(Vector2(flat[ob3 + 1], flat[ob3 + 2]), _k)
					break
		var ar = arrow_nodes.get(id3, null)
		if ar == null or not is_instance_valid(ar):
			ar = Hazards.Arrow.new()
			ar.setup(int(flat[o3 + 3]), 0.0, "cannon" if flat[o3 + 4] > 0.5 else "dart")
			add_child(ar)
			ar.set_physics_process(false)
			ar.collision_mask = 0
			ar.monitoring = false
			arrow_nodes[id3] = ar
		ar.global_position = apos
		seen_ar[id3] = true
	for id3 in arrow_nodes.keys():
		if seen_ar.has(id3):
			continue
		var ga = arrow_nodes[id3]
		if is_instance_valid(ga):
			ga.queue_free()
		arrow_nodes.erase(id3)


func _make_bullet(dir: int, wid: String, shooter: int) -> Bullet:
	var bu := Bullet.new()
	bu.setup(dir, 0.0, 0.0, shooter, wid, 0.0)
	var plist: Array = header["players"]
	if shooter >= 0 and shooter < plist.size():
		var ws: Dictionary = (plist[shooter] as Dictionary).get("wskins", {})
		bu.skin_color = Cosmetics.bullet_color(wid, String(ws.get(wid, "")))
	bullets_root.add_child(bu)
	bu.set_physics_process(false)
	bu.collision_mask = 0
	bu.monitoring = false
	return bu


# ------------------------------------------------------------------ suara
func _sfx(sfx_name: String, vol: float) -> void:
	if not sound_on:
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now < float(_sfx_gap.get(sfx_name, 0.0)):
		return
	_sfx_gap[sfx_name] = now + 0.05
	Global.play_sfx(sfx_name, vol)


func _gun_sfx(wid: String) -> void:
	if not sound_on or not Global.WEAPONS.has(wid):
		return
	var w: Dictionary = Global.WEAPONS[wid]
	var key: String = "gun_" + wid
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now < float(_sfx_gap.get(key, 0.0)):
		return
	_sfx_gap[key] = now + maxf(float(w.get("sfx_gap", 0.0)), 0.06)
	Global.play_sfx(String(w["sfx"]), float(w.get("sfx_vol", -4.0)) - 4.0, _rng.randf_range(0.95, 1.06))


## Hapus semua efek partikel yang sedang berjalan (dipanggil setelah loncat waktu).
func clear_fx() -> void:
	for c in fx_root.get_children():
		c.queue_free()


## Animasi visual rintangan yang tidak direkam (geyser dll) ikut berjalan selama replay diputar.
func tick_visuals(delta: float) -> void:
	for vt in vents:
		vt.tick(delta)
	for n in hit_flash.size():
		hit_flash[n] = maxf(hit_flash[n] - delta * 3.0, 0.0)
