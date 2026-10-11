extends Node2D
## Scene permainan: membangun map, pemain, HUD; mengatur alur round & match.

enum State { INTRO, PLAYING, ROUND_END, MATCH_END }

## Nama = nama file ikon di assets/sprites/powerups/<nama>.png

var map: Dictionary
var state: int = State.INTRO
var state_timer: float = 0.0
var intro_stage: int = 0
var round_num: int = 0
var time_left: float = 0.0
var sudden_death: bool = false
var powerup_timer: float = 5.0
var msg_clear: float = 0.0

var players: Array[Player] = []
var wins: Array[int] = []
var team_mode: bool = false          # versus 3-4 pemain dengan tim (lihat layar TEAM / Global.team_of)
var team_ids: Array[int] = []        # nomor tim tiap pemain. Tanpa mode tim = nomor pemain sendiri (FFA, perilaku lama)
var winner_team: int = -1            # tim pemenang match
var kills: Array[int] = []           # jumlah kill tiap pemain selama match (dipakai untuk urutan kartu tim pemenang)

var bullets_root: Node2D
var powerups_root: Node2D
var players_root: Node2D

var panel_boxes: Array[VBoxContainer] = []

var pause_root: Control
var _overlay_ready_ms: int = 0
var overlay_title: UIKit.Banner
var overlay_btns := {}          # id -> FancyButton
var overlay_list: Array = []    # id yang tampil sekarang
var overlay_idx: int = 0
var overlay_mode: String = "pause"
var overlay_prompt: UIKit.PromptBar
var overlay_poster: UIKit.Poster
var overlay_team_poster: TeamPoster     # kartu kemenangan TIM: semua anggota, urut kill terbanyak di atas
var overlay_open := false

var rng := RandomNumberGenerator.new()

# --- efek kamera & HUD baru
var cam: Camera2D
var shake_amt: float = 0.0
var hit_stop_t: float = 0.0
var hud_root: Control
var huds: Array[PlayerHud] = []
var banner: BannerFx
var winner_idx: int = -1
var victory_show: VictoryShow = null   # animasi kemenangan match (lihat class VictoryShow di bawah)
var low_time_tick: int = -1

# --- rintangan arena (dibangun dari data map, lihat scripts/hazards.gd)
var moving_platforms: Array[Hazards.MovingPlatform] = []
var crumbles: Array[Hazards.CrumblePlatform] = []
var spike_strips: Array[Hazards.SpikeStrip] = []
var pads: Array[Hazards.BouncePad] = []
var traps: Array[Hazards.DartTrap] = []
var vents: Array[Hazards.UpdraftVent] = []        # geyser laut & lift anti-gravitasi
var portals: Array[Hazards.Portal] = []           # portal teleport (berpasangan)
var conveyors: Array[Hazards.Conveyor] = []       # ban berjalan
var saws: Array[Hazards.SawBlade] = []            # gergaji bulat di rel
var portal_cd: Dictionary = {}                    # instance id pemain -> sisa jeda portal (detik)
var ice_rects: Array[Rect2] = []
var traps_root: Node2D          # tempat panah jebakan (dibersihkan tiap ronde)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # supaya ESC bisa un-pause; isi dunia di-set PAUSABLE
	rng.randomize()
	map = MapData.get_map(Global.resolve_map_id(Global.map_id))   # pilihan RANDOM diacak di sini, tiap pertandingan baru
	map = MapData.apply_density(map, Global.object_density)       # setting OBJECTS (FEWER / NORMAL / MORE / EXTREME)
	Global.play_music("game")
	Global.prewarm_synth()   # suara animasi kemenangan dibangun di latar belakang

	cam = Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(cam)
	cam.make_current()

	_build_world()
	_build_players()
	_build_hud()
	_build_overlay()
	_start_round()


# ------------------------------------------------------------------ world
func _build_world() -> void:
	var bg := Sprite2D.new()
	bg.texture = load(map["background"])
	bg.centered = false
	bg.scale = Vector2(4, 4)
	bg.z_index = -100
	bg.modulate = map.get("tint", Color.WHITE)      # campaign Chapter 2 / 3: warna latar berbeda per chapter
	add_child(bg)

	var floor_tex: Texture2D = load(map["floor"])
	var edge: Color = map["edge_color"]
	for r in map["solids"]:
		var rect: Rect2 = r
		_add_block(rect, floor_tex, edge, false)
	for r in map["platforms"]:
		var rect: Rect2 = r
		_add_block(rect, floor_tex, edge, true)

	# dinding tak terlihat di kiri-kanan layar
	_add_collider(Rect2(-40, -600, 40, 2000), false)
	_add_collider(Rect2(1280, -600, 40, 2000), false)

	for r in map["lava"]:
		var rect: Rect2 = r
		_add_lava(rect)

	_build_hazards()

	bullets_root = Node2D.new()
	bullets_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(bullets_root)
	powerups_root = Node2D.new()
	powerups_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(powerups_root)
	players_root = Node2D.new()
	players_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(players_root)


func _add_collider(rect: Rect2, one_way: bool) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 2 if one_way else 1
	body.collision_mask = 0
	body.position = rect.position + rect.size / 2.0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	if one_way:
		cs.one_way_collision = true
		cs.one_way_collision_margin = 8.0
	body.add_child(cs)
	add_child(body)
	return body


func _add_block(rect: Rect2, tex: Texture2D, edge: Color, one_way: bool) -> void:
	_add_collider(rect, one_way)

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
	# warna bisa diganti per map (mis. air es di map Snow) lewat map["lava_colors"] = [warna isi, warna kilau]
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

	var area := Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 4
	area.position = rect.position + rect.size / 2.0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	cs.shape = shape
	area.add_child(cs)
	area.body_entered.connect(_on_lava_entered.bind(rect))
	add_child(area)


func _on_lava_entered(body: Node, lava_rect: Rect2) -> void:
	if not (body is Player):
		return
	var p: Player = body
	# Pemain yang sudah mati / hilang tidak boleh kena lava lagi.
	if not p.alive or p.vanished:
		return
	# Pengaman event basi: body_entered bisa terkirim terlambat (mis. pemain baru saja di-teleport ke
	# spawn saat ronde baru). Hanya proses kalau pemain MEMANG sedang berada di area lava.
	if not lava_rect.grow(40.0).has_point(p.global_position):
		return
	p.hazard_hit(map["respawn"])


# ------------------------------------------------------------------ rintangan arena
func _build_hazards() -> void:
	var floor_tex: Texture2D = load(map["floor"])
	var edge: Color = map["edge_color"]

	traps_root = Node2D.new()
	traps_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(traps_root)

	for d in map.get("moving", []):
		var mp := Hazards.MovingPlatform.new()
		mp.setup(d["rect"], floor_tex, edge, d["move"], float(d["period"]), float(d["phase"]))
		add_child(mp)
		moving_platforms.append(mp)

	for r in map.get("crumble", []):
		var cp := Hazards.CrumblePlatform.new()
		cp.setup(r, floor_tex, edge)
		add_child(cp)
		crumbles.append(cp)

	for d in map.get("spikes", []):
		var strip := Hazards.SpikeStrip.new()
		strip.setup(d["rect"], String(d["style"]))
		add_child(strip)
		spike_strips.append(strip)

	for d in map.get("bounce", []):
		var pad := Hazards.BouncePad.new()
		pad.setup(d["rect"], float(d["power"]))
		add_child(pad)
		pads.append(pad)

	for r in map.get("ice", []):
		var rect: Rect2 = r
		ice_rects.append(rect)
		add_child(Hazards.ice(rect))

	for d in map.get("traps", []):
		var tr := Hazards.DartTrap.new()
		tr.setup(int(d["side"]), float(d["y"]), float(d["first"]), float(d["interval"]), traps_root, String(d.get("kind", "dart")))
		add_child(tr)
		traps.append(tr)

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
		portals.append(pa)
		portals.append(pb)

	for d in map.get("conveyors", []):
		var cv := Hazards.Conveyor.new()
		cv.setup(d["rect"], float(d["speed"]))
		add_child(cv)
		conveyors.append(cv)

	for d in map.get("saws", []):
		var sw := Hazards.SawBlade.new()
		sw.setup(d["pos"], d["move"], float(d["period"]), float(d["phase"]), float(d["radius"]))
		add_child(sw)
		saws.append(sw)

	var amb := Hazards.ambient(String(map.get("ambient", "")))
	if amb != null:
		add_child(amb)


## Dipanggil Player: pengali tarikan lantai di bawah kaki pemain (1.0 = normal, kecil = licin).
func surface_grip(p: Player) -> float:
	if ice_rects.is_empty():
		return 1.0
	var feet := p.global_position + Vector2(0.0, 30.0)
	for r in ice_rects:
		if feet.x >= r.position.x and feet.x <= r.end.x and absf(feet.y - r.position.y) <= 6.0:
			return 0.18
	return 1.0


## Dijalankan tiap frame fisika saat ronde berjalan.
func _update_hazards(delta: float) -> void:
	for tr in traps:
		tr.tick(delta)

	for strip in spike_strips:
		for b in strip.area.get_overlapping_bodies():
			if b is Player:
				var p: Player = b
				if p.alive and not p.vanished and p.invuln <= 0.0:
					var cx: float = strip.global_position.x + strip.rect.size.x * 0.5
					p.spike_hit(1 if p.global_position.x >= cx else -1)

	for pad in pads:
		for b in pad.area.get_overlapping_bodies():
			if b is Player:
				var p2: Player = b
				if p2.alive and not p2.vanished and p2.velocity.y > -40.0:
					if p2.launch(pad.power):
						pad.pulse()

	# --- rintangan baru: geyser / lift anti-gravitasi, portal, ban berjalan, gergaji
	for vt in vents:
		vt.tick(delta)
		for pv in players:
			vt.push(pv, delta)

	_update_portals(delta)

	for cv in conveyors:
		for pc in players:
			if not pc.alive or pc.vanished or not pc.is_on_floor():
				continue
			var feet: Vector2 = pc.global_position + Vector2(0.0, 30.0)
			if feet.x >= cv.rect.position.x and feet.x <= cv.rect.end.x and absf(feet.y - cv.rect.position.y) <= 6.0:
				pc.move_and_collide(Vector2(cv.speed * delta, 0.0))

	for sw in saws:
		for b in sw.area.get_overlapping_bodies():
			if b is Player:
				var ps: Player = b
				if ps.alive and not ps.vanished and ps.invuln <= 0.0:
					ps.spike_hit(1 if ps.global_position.x >= sw.global_position.x else -1)


## Teleport lewat portal: masuk satu -> muncul di pasangannya (kecepatan dipertahankan). Ada jeda 1 detik per pemain.
func _update_portals(delta: float) -> void:
	if portals.is_empty():
		return
	for k in portal_cd.keys():
		portal_cd[k] = float(portal_cd[k]) - delta
		if float(portal_cd[k]) <= 0.0:
			portal_cd.erase(k)
	for pt in portals:
		for pl in players:
			if not pl.alive or pl.vanished:
				continue
			var id: int = pl.get_instance_id()
			if portal_cd.has(id):
				continue
			if not pt.rect.has_point(pl.global_position):
				continue
			pl.global_position = pt.partner.exit_point()
			portal_cd[id] = 1.0
			pt.pulse()
			pt.partner.pulse()
			Global.play_sfx("pu_swap_position", -10.0, randf_range(1.15, 1.3))
			var scene := get_tree().current_scene
			if scene != null:
				UIKit.burst(scene, pt.global_position + pt.rect.size * 0.5, pt.color, 14, 220.0, 5.0, 0.45, 100.0)
				UIKit.burst(scene, pt.partner.global_position + pt.partner.rect.size * 0.5, pt.color, 14, 220.0, 5.0, 0.45, 100.0)


## Kembalikan semua rintangan ke keadaan awal setiap ronde baru (adil untuk semua pemain).
func _reset_hazards() -> void:
	for mp in moving_platforms:
		mp.reset_motion()
	for cp in crumbles:
		cp.reset_state()
	for tr in traps:
		tr.reset()
	for vt in vents:
		vt.reset()
	for sw in saws:
		sw.reset_motion()
	portal_cd.clear()
	if traps_root != null:
		for c in traps_root.get_children():
			c.queue_free()


func _build_players() -> void:
	Global.sanitize_teams()
	team_mode = Global.teams_active()
	team_ids.clear()
	for i in Global.player_count:
		team_ids.append(int(Global.team_of[i]) if team_mode else i)
	for i in Global.player_count:
		var sel: Dictionary = Global.selections[i]
		var p := Player.new()
		players_root.add_child(p)
		p.setup(i, sel["character"], sel["weapon"], self)
		Cosmetics.apply_to_player(p, sel)
		if team_mode:
			# tim: peluru & pisau tidak melukai rekan; tim yang lebih banyak anggotanya kena nerf ringan
			var tid: int = team_ids[i]
			p.apply_team_balance(tid, Global.team_color(tid), Global.team_nerf_level(tid), Global.team_nerf(tid))
		p.died.connect(_on_player_died)
		p.status_changed.connect(_on_player_status)
		players.append(p)
		wins.append(0)
		kills.append(0)


func spawn_bullet(p: Player, weapon: String = "") -> void:
	var id: String = weapon if weapon != "" else p.current_weapon()
	var w: Dictionary = Global.WEAPONS[id]
	var b := Bullet.new()
	b.setup(p.facing, float(w["bullet_speed"]), float(w["damage"]) * p.dmg_out * p.nerf_mult(float(w["damage"])), p.index, id, float(w.get("range", 0.0)))
	b.team = p.team
	b.skin_color = Cosmetics.bullet_color(id, String(p.wskins.get(id, "")))
	var spread: float = float(w.get("spread", 0.0))
	var jitter: float = rng.randf_range(-spread, spread) if spread > 0.0 else 0.0
	b.position = p.global_position + Vector2(p.facing * (p.muzzle_x() - 6.0), 6.0 * p.size_mult + jitter)
	bullets_root.add_child(b)


# ------------------------------------------------------------------ HUD
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud_root = Control.new()
	hud_root.theme = Global.ui_theme
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_root)

	var tm := TimerHud.new()
	tm.name = "TimerHud"
	hud_root.add_child(tm)

	for i in Global.player_count:
		var h := PlayerHud.new(i, players[i])
		if team_mode:
			h.team_id = team_ids[i]
			h.team_level = Global.team_nerf_level(team_ids[i])
		match i:
			0, 2:
				h.position = Vector2(14, 12 + (i / 2) * 140)
			_:
				h.position = Vector2(1280 - 14 - h.size.x, 12 + (i / 2) * 140)
		hud_root.add_child(h)
		huds.append(h)

	banner = BannerFx.new()
	hud_root.add_child(banner)


func _timer_hud() -> TimerHud:
	return hud_root.get_node("TimerHud") as TimerHud


func _refresh_panel(i: int) -> void:
	if i < huds.size():
		huds[i].refresh(wins[i])


func _refresh_all_panels() -> void:
	for i in players.size():
		_refresh_panel(i)


func _on_player_status(p: Player) -> void:
	_refresh_panel(p.index)


func _update_timer_label() -> void:
	var th := _timer_hud()
	if sudden_death:
		th.set_state("SD", true, true)
		return
	if Global.match_time == Global.TIME_INFINITE:
		th.set_state("INF", false, false)
		return
	var secs := int(ceil(time_left))
	th.set_state(Global.format_time(secs), secs <= 10, false)
	if secs <= 10 and secs != low_time_tick and state == State.PLAYING:
		low_time_tick = secs
		th.pulse()
		if secs <= 3:
			Global.play_sfx("timer_urgent", -5.0)
		else:
			Global.play_sfx("timer_tick", -8.0)


func _show_message(text: String, color: Color = Color.WHITE, font_size: int = 110) -> void:
	banner.show_text(text, color, font_size)


func _clear_message() -> void:
	banner.clear()


# ------------------------------------------------------------------ efek kamera
func shake(amount: float) -> void:
	if not Global.screen_shake:
		return
	shake_amt = maxf(shake_amt, amount)


## Jeda singkat (hit-stop) berbasis waktu nyata supaya tidak ikut melambat.
func hit_stop(duration: float) -> void:
	hit_stop_t = maxf(hit_stop_t, float(Time.get_ticks_msec()) + duration * 1000.0)
	Engine.time_scale = 0.08


func _process(delta: float) -> void:
	if hit_stop_t > 0.0 and float(Time.get_ticks_msec()) >= hit_stop_t:
		hit_stop_t = 0.0
		Engine.time_scale = 1.0
	if get_tree().paused:
		cam.offset = Vector2.ZERO
		return
	if shake_amt > 0.05:
		cam.offset = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake_amt
		shake_amt = lerpf(shake_amt, 0.0, minf(delta * 12.0, 1.0))
	else:
		shake_amt = 0.0
		cam.offset = Vector2.ZERO


func _exit_tree() -> void:
	Engine.time_scale = 1.0


# ================================================================== kartu kemenangan TIM
## Kipas kartu seperti kartu remi: tiap anggota tim pemenang punya kartunya sendiri. Kartu dengan kill terbanyak
## berada paling depan (paling atas tumpukan, di sisi kanan), sisanya terkipas ke kiri di belakangnya.
class TeamPoster extends Control:
	var members: Array = []              # [{tex, col, kills, name}] sudah terurut (kill terbanyak dulu)
	var color: Color = Color.WHITE
	var tag: String = ""
	var spread: float = 1.0:             # 0 = kartu masih menumpuk, 1 = kipas terbuka penuh (dianimasikan saat muncul)
		set(v):
			spread = v
			queue_redraw()
	var _cw: float = 150.0
	var _ch: float = 210.0
	var _pivot: Vector2 = Vector2(150, 232)
	var _angles: Array = []
	var _xoffs: Array = []               # geser horizontal tiap kartu (kiri -> kanan) supaya kartu belakang tetap terlihat

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func setup(list: Array, c: Color, label_text: String) -> void:
		members = list
		color = c
		tag = label_text
		if members.size() <= 2:
			size = Vector2(340.0, 334.0)
			_cw = 156.0
			_ch = 220.0
			_pivot = Vector2(170.0, 236.0)
			_angles = [-14.0, 10.0]
			_xoffs = [-46.0, 46.0]
		else:
			size = Vector2(400.0, 334.0)
			_cw = 136.0
			_ch = 192.0
			_pivot = Vector2(200.0, 216.0)
			_angles = [-22.0, -1.0, 20.0]
			_xoffs = [-84.0, 0.0, 82.0]
		custom_minimum_size = size
		pivot_offset = size * 0.5
		queue_redraw()

	## Sudut kartu ke-k (k = 0 kartu terdepan = paling kanan).
	func _angle_of(k: int) -> float:
		var cnt: int = members.size()
		var idx: int = cnt - 1 - k                        # urutan dari kiri
		if cnt <= 1 or idx >= _angles.size():
			return 0.0
		return float(_angles[idx]) * spread

	func _xoff_of(k: int) -> float:
		var idx: int = members.size() - 1 - k
		if idx >= _xoffs.size():
			return 0.0
		return float(_xoffs[idx]) * spread

	func _draw_card(m: Dictionary, k: int, front: bool, unique_mvp: bool) -> void:
		var cw: float = _cw
		var ch: float = _ch
		var gold := Color("f2c14e")
		var gold_d := Color("9a6b12")
		var pcol: Color = m["col"]
		var xf := Transform2D(deg_to_rad(_angle_of(k)), _pivot + Vector2(_xoff_of(k), 0.0))
		draw_set_transform_matrix(xf)
		var r := Rect2(-cw * 0.5, -ch + 22.0, cw, ch)
		# bayangan + bingkai emas (seperti tepi kartu remi)
		draw_rect(Rect2(r.position + Vector2(6, 7), r.size + Vector2(6, 6)), Color(0, 0, 0, 0.38))
		draw_rect(r.grow(5.0), gold_d)
		draw_rect(r.grow(3.5), gold)
		draw_rect(r.grow(1.0), gold_d)
		# muka kartu: gradasi warna pemain
		var cl: Color = pcol.lightened(0.25)
		var cd: Color = pcol.darkened(0.5)
		draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
			PackedColorArray([cl, cl, cd, cd]))
		draw_colored_polygon(PackedVector2Array([
			Vector2(r.position.x + cw * 0.5, r.position.y), Vector2(r.position.x + cw * 0.78, r.position.y),
			Vector2(r.position.x + cw * 0.42, r.end.y), Vector2(r.position.x + cw * 0.14, r.end.y),
		]), Color(1, 1, 1, 0.08))
		# potret karakter
		var ps: float = cw - 38.0
		var pr := Rect2(r.position.x + 19.0, r.position.y + 36.0, ps, ps)
		draw_rect(pr.grow(3.0), Color(1, 1, 1, 0.9))
		draw_rect(pr.grow(1.0), Color(0, 0, 0, 0.8))
		draw_texture_rect(m["tex"], pr, false)
		# nama & kill
		var kc: int = int(m["kills"])
		UIKit.text_in(self, str(m["name"]), Rect2(r.position.x, pr.end.y + 4.0, cw, 26.0), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5)
		UIKit.text_in(self, "%d KILL%s" % [kc, "" if kc == 1 else "S"], Rect2(r.position.x, pr.end.y + 28.0, cw, 22.0), 17, gold if front else Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 4)
		# nomor urutan di kiri atas (1 = kill terbanyak, dst.)
		UIKit.text_in(self, str(k + 1), Rect2(r.position.x + 6.0, r.position.y + 4.0, 30.0, 30.0), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5)
		# lencana MVP di kartu terdepan
		if front and unique_mvp:
			var mr := Rect2(r.end.x - 56.0, r.position.y - 14.0, 66.0, 28.0)
			var mp := UIKit.slanted(mr.size.x, mr.size.y, 8.0, mr.position.x, mr.position.y)
			draw_colored_polygon(mp, gold)
			draw_polyline(UIKit.closed(mp), Color(0.2, 0.12, 0.0), 2.0, true)
			UIKit.text_in(self, "MVP", mr, 20, Color(0.18, 0.09, 0.0), HORIZONTAL_ALIGNMENT_CENTER, 0)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	func _draw() -> void:
		var cnt: int = members.size()
		if cnt == 0:
			return
		var unique_mvp: bool = cnt > 1 and int(members[0]["kills"]) > int(members[1]["kills"])
		# kartu paling belakang (kill tersedikit) digambar dulu, kartu kill terbanyak paling akhir (paling depan)
		for k in range(cnt - 1, -1, -1):
			_draw_card(members[k], k, k == 0, unique_mvp)
		# pita nama tim di dasar kipas
		var pw := 210.0
		var ph := 40.0
		var pp := UIKit.slanted(pw, ph, 14.0, (size.x - pw) * 0.5, size.y - ph - 4.0)
		draw_colored_polygon(UIKit.slanted(pw, ph, 14.0, (size.x - pw) * 0.5 + 4.0, size.y - ph + 1.0), Color(0, 0, 0, 0.5))
		var c0: Color = color.lightened(0.1)
		var c1: Color = color.darkened(0.4)
		draw_polygon(pp, PackedColorArray([c0, c0, c1, c1]))
		draw_polyline(UIKit.closed(pp), Color(1, 1, 1, 0.9), 3.0, true)
		UIKit.text_in(self, tag, Rect2((size.x - pw) * 0.5, size.y - ph - 4.0, pw, ph), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6)


# ================================================================== komponen HUD
class TimerHud extends Control:
	var text: String = ""
	var low: bool = false
	var sd: bool = false
	var pop: float = 1.0
	var t: float = 0.0

	func _init() -> void:
		size = Vector2(230, 96)
		position = Vector2(525, 4)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(s: String, is_low: bool, is_sd: bool) -> void:
		if s != text:
			text = s
			queue_redraw()
		low = is_low
		sd = is_sd

	func pulse() -> void:
		pop = 1.35
		UIKit.tw(self).tween_property(self, "pop", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var pts := UIKit.slanted(w, 70, 22, 0, 0)
		draw_colored_polygon(UIKit.slanted(w, 70, 22, 5, 6), Color(0, 0, 0, 0.45))
		var base := Color(0.05, 0.05, 0.12, 0.88)
		if low:
			base = base.lerp(Color(0.5, 0.05, 0.05, 0.9), 0.5 + 0.5 * sin(t * 9.0))
		draw_colored_polygon(pts, base)
		draw_polyline(UIKit.closed(pts), Color(UIKit.RED, 0.95) if low else Color(1, 1, 1, 0.35), 3.0, true)
		draw_set_transform(Vector2(w * 0.5, 35), 0.0, Vector2.ONE * pop)
		var col := UIKit.RED if low else Color.WHITE
		if text == "INF":
			var itex: Texture2D = Global.cached_tex("res://assets/sprites/ui/infinite.png")
			var bob: float = 1.0 + sin(t * 2.2) * 0.04
			draw_texture_rect_region(itex, Rect2(Vector2(-52, -26) * bob, Vector2(104, 52) * bob), Rect2(300, 360, 800, 400), Color(1, 1, 1, 0.95))
		else:
			UIKit.text_in(self, text, Rect2(-100, -35, 200, 70), 64, col, HORIZONTAL_ALIGNMENT_CENTER, 8, Color.BLACK, Global.font_digital)
		draw_set_transform(Vector2.ZERO)
		var rl: String = "SUDDEN DEATH" if sd else "FIRST TO %d WINS" % Global.WINS_TO_MATCH
		UIKit.text_in(self, rl, Rect2(0, 72, w, 24), 18, Color(UIKit.RED if sd else Color(1, 1, 1, 0.75)), HORIZONTAL_ALIGNMENT_CENTER, 5)


class PlayerHud extends Control:
	var idx: int = 0
	var player: Player
	var wins: int = 0
	var hp_shown: float = 3.0
	var hurt: float = 0.0
	var shake_x: float = 0.0
	var win_pop: float = 0.0
	var t: float = 0.0
	var last_hp: float = 3.0
	var last_wins: int = 0
	var last_ammo: int = -2
	var last_weapon: String = ""
	var ammo_pop: float = 0.0
	var ammo_shown: float = 1.0
	var weapon_pop: float = 0.0
	var heart_tex: Texture2D
	var inf_tex: Texture2D
	var pu_items: Array = []         # kartu power up yang tampil (diisi _collect_powerups)
	var pu_last: Dictionary = {}     # id -> sisa waktu terakhir (untuk mendeteksi power up baru diambil)
	var pu_pop: Dictionary = {}      # id -> denyut kartu 1..0
	var max_hearts: int = Global.MAX_HP     # campaign: bisa lebih dari 3 (perk EXTRA HEART)
	var show_wins: bool = true              # campaign: pip kemenangan disembunyikan
	var name_text: String = ""              # campaign: kosong = nama karakter
	var sub_text: String = ""               # campaign: teks kecil di bawah hati (mis. SCORE)
	var team_id: int = -1                   # versus tim: nomor tim (-1 = tanpa tim)
	var team_level: int = 0                 # versus tim: level nerf (0 = seimbang)

	func _init(i: int = 0, p: Player = null) -> void:
		idx = i
		player = p
		size = Vector2(250, 128)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		heart_tex = Global.cached_tex("res://assets/sprites/ui/heart.png")
		inf_tex = Global.cached_tex("res://assets/sprites/ui/infinite.png")
		last_hp = float(Global.MAX_HP)

	func refresh(w: int) -> void:
		wins = w
		if player.hp < last_hp:
			hurt = 1.0
			var tw := UIKit.tw(self)
			tw.tween_property(self, "hurt", 0.0, 0.5)
			var s := UIKit.tw(self)
			for v in [8.0, -7.0, 5.0, -3.0, 0.0]:
				s.tween_property(self, "shake_x", v, 0.045)
		last_hp = player.hp
		if w > last_wins:
			win_pop = 1.0
			Global.play_sfx("win_pip", -4.0)
			UIKit.tw(self).tween_property(self, "win_pop", 0.0, 0.7).set_trans(Tween.TRANS_BACK)
		last_wins = w
		queue_redraw()

	func _process(d: float) -> void:
		t += d
		hp_shown = lerpf(hp_shown, player.hp, minf(d * 10.0, 1.0))
		if absf(hp_shown - player.hp) < 0.004:
			hp_shown = player.hp
		# animasi indikator peluru: berdenyut tiap berubah, bar mengalir halus
		var cw: String = player.current_weapon()
		if cw != last_weapon:
			last_weapon = cw
			weapon_pop = 1.0
			ammo_pop = 0.0
		if player.ammo != last_ammo:
			if last_ammo != -2:
				ammo_pop = 1.0
			last_ammo = player.ammo
		ammo_pop = maxf(ammo_pop - d * 5.0, 0.0)
		weapon_pop = maxf(weapon_pop - d * 3.5, 0.0)
		var frac: float = _ammo_frac()
		ammo_shown = lerpf(ammo_shown, frac, minf(d * 14.0, 1.0))
		_collect_powerups(d)
		queue_redraw()

	## Sisa peluru senjata yang sedang dipegang, 0..1 (tak terbatas = 1).
	func _ammo_frac() -> float:
		var cw: String = player.current_weapon()
		if cw == Global.MELEE_WEAPON or cw == "pistol":
			return 1.0
		var mx: int = player.max_ammo()
		if mx <= 0:
			return 1.0
		return clampf(float(player.ammo) / float(mx), 0.0, 1.0)

	func _draw() -> void:
		var col: Color = Global.PLAYER_COLORS[idx]
		var w: float = size.x
		var h: float = size.y
		var alive: bool = player.alive
		draw_set_transform(Vector2(shake_x, 0))
		var pts := UIKit.slanted(w, h, 20, 0, 0)
		draw_colored_polygon(UIKit.slanted(w, h, 20, 5, 6), Color(0, 0, 0, 0.45))
		var bg := Color(0.04, 0.04, 0.1, 0.84).lerp(Color(0.5, 0.05, 0.05, 0.9), hurt * 0.7)
		draw_colored_polygon(pts, bg)
		draw_polyline(UIKit.closed(pts), col if alive else Color(0.4, 0.4, 0.45), 3.0, true)
		# potret
		var pr := Rect2(22, 14, 66, 66)
		draw_rect(Rect2(pr.position - Vector2(3, 3), pr.size + Vector2(6, 6)), col)
		var tex: Texture2D = player.portrait_tex(not alive)
		draw_texture_rect(tex, pr, false, Color.WHITE if alive else Color(0.55, 0.55, 0.6))
		if not alive:
			UIKit.text_in(self, "K.O.", Rect2(pr.position.x - 10, pr.position.y + 16, pr.size.x + 20, 34), 34, UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER, 8)
		# lencana TIM (di bawah potret): warna tim + nomor
		if team_id >= 0:
			var tcol: Color = Global.team_color(team_id)
			var ta: float = 1.0 if alive else 0.45
			var br := Rect2(18.0, 92.0, 58.0, 26.0)
			var bp := UIKit.slanted(br.size.x, br.size.y, 8.0, br.position.x, br.position.y)
			draw_colored_polygon(bp, Color(tcol.darkened(0.55), 0.95 * ta))
			draw_polyline(UIKit.closed(bp), Color(tcol, ta), 2.0, true)
			UIKit.text_in(self, "T%d" % (team_id + 1), br, 19, Color(1, 1, 1, ta), HORIZONTAL_ALIGNMENT_CENTER, 4)
		# nama
		var tx: float = 104.0
		# nama karakter yang dipakai pemain ini (bukan "PLAYER N"); font mengecil otomatis kalau namanya panjang
		var hud_name: String = name_text if name_text != "" else Global.character_name(idx, player.char_idx)
		var name_w: float = w - tx - 20.0
		var name_fs: int = 24
		while name_fs > 14 and UIKit.text_w(hud_name, name_fs) > name_w:
			name_fs -= 1
		UIKit.text_in(self, hud_name, Rect2(tx, 8, name_w, 28), name_fs, col.lightened(0.15), HORIZONTAL_ALIGNMENT_LEFT, 6)
		# hati (bisa terisi sebagian: damage 0.25 / 0.5 / 1.5)
		var heart_step: float = minf(31.0, (w - tx - 14.0) / float(max_hearts))
		var heart_half: float = minf(14.0, heart_step * 0.46)
		for k in max_hearts:
			var fill: float = clampf(hp_shown - float(k), 0.0, 1.0)
			var pulse: float = 1.0
			if alive and player.hp <= 1.0 and fill > 0.0:
				pulse = 1.0 + 0.14 * sin(t * 10.0)
			var cxk: float = tx + k * heart_step + heart_half
			draw_set_transform(Vector2(shake_x, 0) + Vector2(cxk, 52), 0.0, Vector2.ONE * pulse)
			draw_texture_rect(heart_tex, Rect2(-heart_half, -heart_half, heart_half * 2.0, heart_half * 2.0), false, Color(0.12, 0.12, 0.14, 0.75))
			if fill > 0.01:
				var tw_px: float = float(heart_tex.get_width())
				var th_px: float = float(heart_tex.get_height())
				draw_texture_rect_region(heart_tex, Rect2(-heart_half, -heart_half, heart_half * 2.0 * fill, heart_half * 2.0), Rect2(0, 0, tw_px * fill, th_px), Color.WHITE)
		draw_set_transform(Vector2(shake_x, 0))
		# kemenangan
		# jarak kotak kemenangan menyesuaikan jumlah round (sampai 5) supaya tidak keluar dari panel
		var n_win: int = Global.WINS_TO_MATCH if show_wins else 0
		var win_step: float = minf(32.0, (w - tx - 22.0 + 8.0) / float(maxi(n_win, 1)))
		var win_w: float = minf(24.0, win_step - 8.0)
		if sub_text != "":
			UIKit.text_in(self, sub_text, Rect2(tx, 72.0, w - tx - 16.0, 22.0), 18, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_LEFT, 5)
		for k in n_win:
			var filled: bool = k < wins
			var r := Rect2(tx + k * win_step, 76, win_w, 14)
			var sc: float = 1.0
			if filled and k == wins - 1:
				sc = 1.0 + win_pop * 0.9
			var cc := Rect2(r.get_center() - r.size * 0.5 * sc, r.size * sc)
			var sp := UIKit.slanted(cc.size.x, cc.size.y, 5, cc.position.x, cc.position.y)
			draw_colored_polygon(sp, col if filled else Color(1, 1, 1, 0.16))
			draw_polyline(UIKit.closed(sp), Color(0, 0, 0, 0.8), 1.5, true)
		# senjata + indikator peluru
		if alive:
			_draw_ammo(tx, 100.0, w - tx - 22.0, col)
		# power-up aktif (strip kecil di samping panel)
		if alive:
			_draw_powerups(col)
		draw_set_transform(Vector2.ZERO)

	func _draw_ammo(x: float, y: float, width: float, col: Color) -> void:
		var cw: String = player.current_weapon()
		var wd: Dictionary = Global.WEAPONS[cw]
		var unlimited: bool = cw == Global.MELEE_WEAPON or int(wd["ammo"]) < 0
		var wcol: Color = wd["color"]
		# ikon senjata (membesar sebentar saat ganti)
		var gtex: Texture2D = player.weapon_tex_for(cw)
		# Skala SERAGAM (lebar & tinggi dikali angka yang sama) supaya proporsi senjata asli tidak gepeng.
		# Senjata dimuat ke dalam kotak 46 x 24 px: yang panjang (Scream) dibatasi lebarnya, yang pendek (Pistol) dibatasi tingginya.
		var tex_w: float = float(gtex.get_width())
		var tex_h: float = float(gtex.get_height())
		var gscale: float = minf(46.0 / tex_w, 24.0 / tex_h)
		var gw: float = tex_w * gscale
		var gh: float = tex_h * gscale
		var pop: float = 1.0 + weapon_pop * 0.35
		var gc := Vector2(x + 23.0, y + 10.0)
		draw_set_transform(Vector2(shake_x, 0) + gc, 0.0, Vector2.ONE * pop)
		draw_texture_rect(gtex, Rect2(-gw * 0.5, -gh * 0.5, gw, gh), false)
		draw_set_transform(Vector2(shake_x, 0))
		var bx: float = x + 54.0
		var bw: float = width - 54.0 - 46.0
		if unlimited:
			# bar penuh + ikon tak terbatas
			var inf_c := Color(UIKit.CYAN, 0.9)
			draw_rect(Rect2(bx, y + 5.0, bw, 10), Color(1, 1, 1, 0.12))
			draw_rect(Rect2(bx, y + 5.0, bw, 10), Color(inf_c, 0.35))
			var sh: float = fmod(t * 0.7, 1.4) - 0.2          # kilau berjalan
			draw_rect(Rect2(bx + bw * clampf(sh, 0.0, 1.0) - 8.0, y + 5.0, 16.0, 10).intersection(Rect2(bx, y + 5.0, bw, 10)), Color(1, 1, 1, 0.45))
			var ih: float = 26.0 * (1.0 + ammo_pop * 0.2)
			var iw: float = ih * float(inf_tex.get_width()) / float(inf_tex.get_height())
			draw_texture_rect(inf_tex, Rect2(x + width - 22.0 - iw * 0.5, y + 10.0 - ih * 0.5, iw, ih), false, inf_c)
		else:
			var low: bool = ammo_shown <= 0.3
			var fc: Color = wcol
			if player.ammo <= 0:
				fc = UIKit.RED
			elif low:
				fc = UIKit.RED.lerp(wcol, 0.5 + 0.5 * sin(t * 12.0)) if ammo_shown <= 0.2 else UIKit.RED.lerp(wcol, 0.45)
			draw_rect(Rect2(bx, y + 5.0, bw, 10), Color(1, 1, 1, 0.12))
			draw_rect(Rect2(bx, y + 5.0, bw * ammo_shown, 10), fc)
			draw_rect(Rect2(bx, y + 5.0, bw * ammo_shown, 3), Color(1, 1, 1, 0.35))
			# garis pembagi per peluru (jika sedikit, mis. Scream 3 / Kurval 10)
			var mx: int = player.max_ammo()
			if mx <= 12 and mx > 1:
				for k in range(1, mx):
					var lx: float = bx + bw * float(k) / float(mx)
					draw_line(Vector2(lx, y + 5.0), Vector2(lx, y + 15.0), Color(0, 0, 0, 0.7), 2.0)
			draw_rect(Rect2(bx, y + 5.0, bw, 10), Color(0, 0, 0, 0.6), false, 1.5)
			var ns: float = 1.0 + ammo_pop * 0.45
			var ncol: Color = Color.WHITE if player.ammo > 0 else UIKit.RED
			draw_set_transform(Vector2(shake_x, 0) + Vector2(x + width - 22.0, y + 10.0), 0.0, Vector2.ONE * ns)
			UIKit.text_in(self, str(player.ammo), Rect2(-24, -14, 48, 28), 24, ncol, HORIZONTAL_ALIGNMENT_CENTER, 6)
			draw_set_transform(Vector2(shake_x, 0))

	## Kumpulkan power up aktif milik pemain ini + deteksi power up yang baru diambil (kartu berdenyut).
	func _collect_powerups(d: float) -> void:
		var items: Array = []
		if player.alive:
			if player.speed_time > 0.0:
				items.append({"id": "speed", "left": player.speed_time, "total": Player.BOOST_DURATION})
			if player.jump_time > 0.0:
				items.append({"id": "jump", "left": player.jump_time, "total": Player.BOOST_DURATION})
			if player.shield_hits > 0:
				items.append({"id": "shield", "left": player.shield_time, "total": Player.SHIELD_DURATION, "badge": player.shield_hits})
			if player.invis_time > 0.0:
				items.append({"id": "invisible", "left": player.invis_time, "total": Player.INVISIBLE_DURATION})
			if player.swap_time > 0.0:
				items.append({"id": "swap_position", "left": player.swap_time, "total": Player.SWAP_WINDOW, "pulse": true})
			if player.recent_pickup_time > 0.0 and player.recent_pickup != "":
				items.append({"id": player.recent_pickup, "left": player.recent_pickup_time, "total": Player.PICKUP_FLASH, "text": player.recent_pickup_note})
		var seen: Dictionary = {}
		for it in items:
			var id: String = String(it["id"])
			var left: float = float(it["left"])
			seen[id] = true
			if not pu_last.has(id) or left > float(pu_last[id]) + 0.05:
				pu_pop[id] = 1.0
			pu_last[id] = left
		for id in pu_last.keys():
			if not seen.has(id):
				pu_last.erase(id)
		for id in pu_pop.keys():
			pu_pop[id] = maxf(float(pu_pop[id]) - d * 4.0, 0.0)
		pu_items = items

	## Power up aktif: kartu BESAR (ikon + cincin hitung mundur + angka detik + nama + bar) di LUAR panel.
	## HUD kiri (P1 / P3) -> kartu di kanan panel, HUD kanan (P2 / P4) -> kartu di kiri panel. Maksimal 3 kartu per baris.
	## Warna & nama tiap power up diambil dari Player.PU_INFO. Kartu berdenyut saat baru diambil, berkedip merah saat hampir habis.
	func _draw_powerups(_col: Color) -> void:
		var right_side: bool = idx % 2 == 1
		var cw: float = 72.0
		var ch: float = 66.0
		var gap: float = 4.0
		for k in pu_items.size():
			var it: Dictionary = pu_items[k]
			var id: String = String(it["id"])
			var left: float = float(it["left"])
			var total: float = maxf(float(it["total"]), 0.01)
			var frac: float = clampf(left / total, 0.0, 1.0)
			var pcol: Color = Player.pu_color(id)
			var instant: bool = it.has("text")
			var pulse: bool = bool(it.get("pulse", false))
			var low: bool = (not instant) and left <= (3.0 if total > 4.0 else 1.0)
			var blink: bool = low and sin(t * 14.0) > 0.0
			var pop: float = float(pu_pop.get(id, 0.0))
			# posisi kartu (pojok kiri-atas)
			var row: int = k / 3
			var colk: int = k % 3
			var x: float = (-10.0 - cw - float(colk) * (cw + gap)) if right_side else (size.x + 10.0 + float(colk) * (cw + gap))
			var y: float = 8.0 + float(row) * (ch + gap)
			var center := Vector2(x + cw * 0.5, y + ch * 0.5)
			# denyut saat baru diambil (membesar lalu kembali)
			var sc: float = 1.0 + 0.28 * pop
			draw_set_transform(Vector2(shake_x, 0) + center, 0.0, Vector2.ONE * sc)
			var tl := Vector2(-cw * 0.5, -ch * 0.5)
			var edge: Color = pcol
			if blink:
				edge = Color.WHITE
			elif pulse:
				edge = pcol.lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 12.0))
			var bg: Color = Color(0.04, 0.04, 0.1, 0.9).lerp(pcol, 0.20)
			if blink:
				bg = bg.lerp(UIKit.RED, 0.45)
			draw_rect(Rect2(tl + Vector2(3, 4), Vector2(cw, ch)), Color(0, 0, 0, 0.4))
			draw_rect(Rect2(tl, Vector2(cw, ch)), bg)
			draw_rect(Rect2(tl, Vector2(cw, 4)), edge)                         # garis warna di atas kartu
			draw_rect(Rect2(tl, Vector2(cw, ch)), edge, false, 2.0)
			if pop > 0.0:
				draw_rect(Rect2(tl, Vector2(cw, ch)), Color(1, 1, 1, 0.45 * pop))   # kilatan saat baru diambil
			# ikon + cincin hitung mundur
			var ic: Vector2 = tl + Vector2(22.0, 25.0)
			draw_circle(ic, 18.0, Color(0, 0, 0, 0.45))
			draw_arc(ic, 18.0, 0.0, TAU, 36, Color(1, 1, 1, 0.18), 4.0, true)
			if frac > 0.01:
				draw_arc(ic, 18.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 36, edge, 4.0, true)
			var path: String = "res://assets/sprites/powerups/%s.png" % id
			if ResourceLoader.exists(path):
				draw_texture_rect(Global.cached_tex(path), Rect2(ic - Vector2(13, 13), Vector2(26, 26)), false)
			# jumlah tahanan Shield (x2 -> x1) sebagai lencana di sudut ikon
			if it.has("badge"):
				var bc: Vector2 = ic + Vector2(13.0, 13.0)
				draw_circle(bc, 9.0, Color(0, 0, 0, 0.92))
				draw_arc(bc, 9.0, 0.0, TAU, 20, pcol, 2.0, true)
				UIKit.text_in(self, str(int(it["badge"])), Rect2(bc.x - 10.0, bc.y - 10.0, 20.0, 20.0), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 4)
			# angka sisa detik (atau teks pendek untuk power up instan)
			var tstr: String = ""
			var tfs: int = 26
			if instant:
				tstr = String(it["text"])
				tfs = 20 if tstr.length() <= 2 else 16
			elif left >= 3.0:
				tstr = str(int(ceil(left)))
			else:
				tstr = "%.1f" % left
				tfs = 20
			var tcol: Color = UIKit.RED if blink else Color.WHITE
			UIKit.text_in(self, tstr, Rect2(tl.x + 40.0, tl.y + 9.0, 30.0, 32.0), tfs, tcol, HORIZONTAL_ALIGNMENT_CENTER, 5)
			# nama power up (Swap berganti ke "SHOOT!" supaya pemain tahu harus menekan tembak)
			var nm: String = Player.pu_name(id)
			if pulse and fmod(t, 1.0) < 0.5:
				nm = "SHOOT!"
			var nfs: int = 14
			while nfs > 9 and UIKit.text_w(nm, nfs) > cw - 6.0:
				nfs -= 1
			UIKit.text_in(self, nm, Rect2(tl.x + 2.0, tl.y + 44.0, cw - 4.0, 16.0), nfs, pcol.lightened(0.35), HORIZONTAL_ALIGNMENT_CENTER, 5)
			# bar sisa waktu
			var bar := Rect2(tl.x + 5.0, tl.y + ch - 7.0, cw - 10.0, 4.0)
			draw_rect(bar, Color(0, 0, 0, 0.6))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), edge)
		draw_set_transform(Vector2(shake_x, 0))


class BannerFx extends Control:
	var text: String = ""
	var color: Color = Color.WHITE
	var fsize: int = 110
	var show_t: float = 0.0     # 0..1 animasi masuk
	var bar: float = 0.0        # tinggi pita
	var shown: bool = false
	var tw: Tween

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func show_text(s: String, c: Color, fs: int) -> void:
		text = s
		color = c
		fsize = clampi(fs, 60, 120)
		while fsize > 36 and UIKit.text_w(s, fsize) > 1120.0:
			fsize -= 4
		shown = true
		visible = true
		if tw:
			tw.kill()
		show_t = 0.0
		tw = UIKit.tw(self)
		tw.set_parallel(true)
		tw.tween_property(self, "show_t", 1.0, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "bar", 1.0, 0.25).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

	func clear() -> void:
		if not shown:
			return
		shown = false
		if tw:
			tw.kill()
		tw = UIKit.tw(self)
		tw.set_parallel(true)
		tw.tween_property(self, "bar", 0.0, 0.25)
		tw.tween_property(self, "show_t", 0.0, 0.2)
		tw.chain().tween_callback(_finish_clear)

	## Dipanggil saat animasi tutup selesai: paksa banner hilang total.
	## (Bug lama: frame terakhir tidak digambar ulang sehingga dua garis pita tertinggal di tengah layar.)
	func _finish_clear() -> void:
		if shown:
			return
		bar = 0.0
		show_t = 0.0
		visible = false
		queue_redraw()

	func _process(_d: float) -> void:
		if shown or bar > 0.001:
			if not visible:
				visible = true
			queue_redraw()
		elif visible:
			# pengaman: kalau animasi tertutup/terputus, banner tetap disembunyikan
			bar = 0.0
			show_t = 0.0
			visible = false
			queue_redraw()

	func _draw() -> void:
		# garis tepi pita (5 px) baru digambar kalau pita sudah cukup tinggi,
		# supaya tidak ada garis tipis yang tersisa saat pita menutup
		if bar <= 0.02:
			return
		var cy: float = size.y * 0.5 - 20.0
		var bh: float = (fsize * 1.25) * bar
		var band := Rect2(0, cy - bh * 0.5, size.x, bh)
		draw_rect(band, Color(0, 0, 0, 0.6))
		draw_rect(Rect2(band.position.x, band.position.y - 5, size.x, 5), Color(color, 0.95))
		draw_rect(Rect2(band.position.x, band.end.y, size.x, 5), Color(color, 0.95))
		if show_t <= 0.001:
			return
		var sc: float = 1.0 + (1.0 - show_t) * 1.4
		draw_set_transform(Vector2(size.x * 0.5, cy), deg_to_rad(-2.0), Vector2.ONE * maxf(sc, 0.9))
		var r := Rect2(-size.x * 0.5, -fsize * 0.65, size.x, fsize * 1.3)
		var a: float = clampf(show_t * 1.5, 0.0, 1.0)
		UIKit.text_in(self, text, Rect2(r.position + Vector2(8, 9), r.size), fsize, Color(0, 0, 0, 0.55 * a))
		UIKit.text_in(self, text, r, fsize, Color(color, a), HORIZONTAL_ALIGNMENT_CENTER, 18)
		draw_set_transform(Vector2.ZERO)


# ------------------------------------------------------------------ pause / end overlay
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	pause_root = Control.new()
	pause_root.theme = Global.ui_theme
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_root.visible = false
	pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(pause_root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.02, 0.02, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_root.add_child(dim)

	overlay_poster = UIKit.Poster.new(null, Color.WHITE, "", Vector2(250, 330))
	overlay_poster.position = Vector2(150, 190)
	overlay_poster.visible = false
	pause_root.add_child(overlay_poster)
	overlay_team_poster = TeamPoster.new()
	overlay_team_poster.position = Vector2(150, 190)
	overlay_team_poster.visible = false
	pause_root.add_child(overlay_team_poster)

	overlay_title = UIKit.Banner.new("PAUSED", 70)
	overlay_title.position = Vector2(640.0 - overlay_title.size.x * 0.5, 92)
	pause_root.add_child(overlay_title)

	var defs := [
		["resume", "RESUME", _toggle_pause],
		["rematch", "REMATCH", _rematch],
		["teams", "CHANGE TEAMS", _to_teams],
		["select", "CHANGE FIGHTERS", _to_select],
		["menu", "MAIN MENU", _to_menu],
	]
	for d in defs:
		var b := UIKit.FancyButton.new(d[1], Vector2(480, 68), 38)
		b.visible = false
		b.activated.connect(d[2])
		var id: String = d[0]
		b.hovered.connect(func() -> void: _overlay_select(overlay_list.find(id)))
		pause_root.add_child(b)
		overlay_btns[id] = b

	overlay_prompt = UIKit.make_prompt(pause_root)
	UIInput.pressed.connect(_on_ui_input)


func _open_overlay(mode: String, winner: int = -1) -> void:
	overlay_mode = mode
	overlay_open = true
	_overlay_ready_ms = Time.get_ticks_msec() + (500 if mode == "end" else 0)
	pause_root.visible = true
	pause_root.modulate.a = 0.0
	UIKit.tw(pause_root).tween_property(pause_root, "modulate:a", 1.0, 0.2)

	if mode == "pause":
		overlay_list = ["resume", "rematch", "teams", "select", "menu"] if team_mode else ["resume", "rematch", "select", "menu"]
		overlay_title.plate = UIKit.GOLD
		overlay_title.set_text("PAUSED")
		overlay_poster.visible = false
		overlay_team_poster.visible = false
	else:
		overlay_list = ["rematch", "teams", "select", "menu"] if team_mode else ["rematch", "select", "menu"]
		var wt: int = winner_team if winner_team >= 0 else team_ids[winner]
		var col: Color = _team_color(wt)
		overlay_title.plate = col
		overlay_title.text_color = Color.WHITE
		overlay_title.set_text("%s WINS!" % _team_label(wt))
		var pst: Control = overlay_poster
		overlay_poster.visible = false
		overlay_team_poster.visible = false
		if _team_is_group(wt):
			# TIM: tampilkan semua anggota, kill terbanyak paling atas (seri -> nomor pemain terkecil)
			var mem: Array[Player] = _team_players(wt)
			mem.sort_custom(func(a: Player, b: Player) -> bool:
				if kills[a.index] != kills[b.index]:
					return kills[a.index] > kills[b.index]
				return a.index < b.index)
			var infos: Array = []
			for m in mem:
				infos.append({"tex": m.portrait_tex(false), "col": Global.PLAYER_COLORS[m.index], "kills": kills[m.index], "name": Global.character_name(m.index, m.char_idx)})
			overlay_team_poster.setup(infos, col, Global.team_name(wt))
			pst = overlay_team_poster
		else:
			overlay_poster.tex = players[winner].portrait_tex(false)
			overlay_poster.color = col
			overlay_poster.tag = Global.character_name(winner, players[winner].char_idx)
		var is_team := pst == overlay_team_poster
		pst.visible = true
		pst.position = Vector2(88, 178) if is_team else Vector2(150, 190)
		pst.rotation = deg_to_rad(-3.0 if is_team else -6.0)
		pst.scale = Vector2.ONE * 0.2
		pst.pivot_offset = pst.size * 0.5
		var base_y: float = pst.position.y
		var pt := UIKit.tw(pst)
		pt.tween_property(pst, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		if is_team:
			# kartu "dibagikan": mulai menumpuk lalu terkipas terbuka
			overlay_team_poster.spread = 0.0
			var sp := UIKit.tw(overlay_team_poster)
			sp.tween_property(overlay_team_poster, "spread", 1.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)
		pt.tween_callback(func() -> void:
			var bob := UIKit.tw(pst)
			bob.set_loops()
			bob.tween_property(pst, "position:y", base_y - 9.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			bob.tween_property(pst, "position:y", base_y + 9.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT))
	overlay_title.position = Vector2(640.0 - overlay_title.size.x * 0.5 + (120.0 if mode == "end" else 0.0), 92)
	overlay_title.scale = Vector2.ONE * 0.3
	UIKit.tw(overlay_title).tween_property(overlay_title, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var x: float = 640.0 - 240.0 + (120.0 if mode == "end" else 0.0)
	var k := 0
	for id in overlay_btns:
		var b: UIKit.FancyButton = overlay_btns[id]
		var show: bool = overlay_list.has(id)
		b.visible = show
		if show:
			var base := Vector2(x, 230 + k * 82)
			b.position = base + Vector2(-90, 0)
			b.modulate.a = 0.0
			var tw := UIKit.tw(b)
			tw.set_parallel(true)
			tw.tween_property(b, "position", base, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.05 * k + 0.1)
			tw.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(0.05 * k + 0.1)
			k += 1
	overlay_idx = 0
	_overlay_select(0, false)
	if mode == "pause":
		overlay_prompt.set_prompts([[&"dpad_ud", "NAVIGATE"], [&"accept", "SELECT"], [&"start", "RESUME"]])
	else:
		overlay_prompt.set_prompts([[&"dpad_ud", "NAVIGATE"], [&"accept", "SELECT"]])


func _close_overlay() -> void:
	overlay_open = false
	pause_root.visible = false


func _overlay_select(i: int, sound: bool = true) -> void:
	if i < 0 or i >= overlay_list.size():
		return
	if sound and i != overlay_idx:
		Global.play_sfx("ui_hover", -8.0)
	overlay_idx = i
	for k in overlay_list.size():
		(overlay_btns[overlay_list[k]] as UIKit.FancyButton).set_selected(k == i)


func _on_ui_input(source: int, action: StringName) -> void:
	if not is_inside_tree():
		return
	if not overlay_open:
		if state == State.MATCH_END and is_instance_valid(victory_show) and (action == &"accept" or action == &"fire"):
			victory_show.skip()   # lewati animasi kemenangan -> langsung ke layar pilihan
			return
		if action == &"start" and source >= 0:
			_toggle_pause()
		return
	match action:
		&"up":
			_overlay_select(posmod(overlay_idx - 1, overlay_list.size()))
		&"down":
			_overlay_select(posmod(overlay_idx + 1, overlay_list.size()))
		&"accept":
			if Time.get_ticks_msec() < _overlay_ready_ms:
				return      # cegah tombol tembak yang sedang ditekan beruntun langsung memilih tombol
			(overlay_btns[overlay_list[overlay_idx]] as UIKit.FancyButton).press()
		&"back":
			if source != UIInput.GENERIC_SOURCE and overlay_mode == "pause":
				_toggle_pause()
		&"start":
			if overlay_mode == "pause":
				_toggle_pause()


func _toggle_pause() -> void:
	if state == State.MATCH_END:
		return
	var p: bool = not get_tree().paused
	get_tree().paused = p
	if p:
		Global.play_sfx("ui_pause")
		_open_overlay("pause")
	else:
		Global.play_sfx("ui_resume", -2.0)
		_close_overlay()


func _rematch() -> void:
	Global.goto("game")


func _to_teams() -> void:
	Global.play_music("menu")
	Global.goto("team")


func _to_select() -> void:
	Global.play_music("menu")
	Global.goto("select")


func _to_menu() -> void:
	Global.play_music("menu")
	Global.goto("menu")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if overlay_open and overlay_mode == "end":
			return
		_toggle_pause()


# ------------------------------------------------------------------ round flow
func _start_round() -> void:
	round_num += 1
	state = State.INTRO
	intro_stage = 0
	state_timer = 1.8
	sudden_death = false
	time_left = float(Global.match_time)
	powerup_timer = minf(5.0, float(Global.POWERUP_AMOUNTS[Global.powerup_amount]["min"]))

	for c in bullets_root.get_children():
		c.queue_free()
	for c in powerups_root.get_children():
		c.queue_free()
	_reset_hazards()

	var spawns: Array = _spawn_positions()
	for i in players.size():
		players[i].reset(spawns[i], map["respawn"])

	# FINAL ROUND hanya kalau SEMUA pemain sudah menang (WINS_TO_MATCH - 1) round,
	# bukan cukup satu pemain saja.
	var final_round := not wins.is_empty()
	for w in wins:
		if w < Global.WINS_TO_MATCH - 1:
			final_round = false

	if final_round:
		_show_message("FINAL ROUND", Color("ff4040"))
		Global.play_sfx("final_round")
	else:
		_show_message("ROUND %d" % round_num, Color("ffd23f"))
		Global.play_round_sfx(round_num)
	low_time_tick = -1
	_update_timer_label()
	_refresh_all_panels()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return

	if msg_clear > 0.0:
		msg_clear -= delta
		if msg_clear <= 0.0:
			_clear_message()

	match state:
		State.INTRO:
			state_timer -= delta
			if state_timer <= 0.0:
				if intro_stage == 0:
					intro_stage = 1
					state_timer = 0.9
					_show_message("FIGHT!", Color("ff4040"))
					Global.play_sfx("fight")
				else:
					state = State.PLAYING
					_clear_message()
					for p in players:
						p.controls_enabled = true
		State.PLAYING:
			if not sudden_death and Global.match_time != Global.TIME_INFINITE:
				time_left -= delta
				if time_left <= 0.0:
					time_left = 0.0
					_update_timer_label()
					_on_time_up()
			_update_timer_label()
			_update_powerups(delta)
			_update_hazards(delta)
		State.ROUND_END:
			state_timer -= delta
			if state_timer <= 0.0:
				var w := _match_winner()
				if w >= 0:
					_end_match(w)
				else:
					_start_round()


func _alive_players() -> Array[Player]:
	var res: Array[Player] = []
	for p in players:
		if p.alive:
			res.append(p)
	return res


# ------------------------------------------------------------------ tim
## Anggota sebuah tim. Tanpa mode tim, tiap pemain = satu tim sendiri (nomor tim = nomor pemain).
func _team_players(team: int) -> Array[Player]:
	var res: Array[Player] = []
	for p in players:
		if team_ids[p.index] == team:
			res.append(p)
	return res


## Nomor tim yang masih punya anggota hidup.
func _alive_team_ids() -> Array[int]:
	var res: Array[int] = []
	for p in players:
		if p.alive and not res.has(team_ids[p.index]):
			res.append(team_ids[p.index])
	return res


## Tim berisi >= 2 pemain? (tim solo tetap memakai nama karakter & warna pemain)
func _team_is_group(team: int) -> bool:
	return team_mode and _team_players(team).size() >= 2


func _team_label(team: int) -> String:
	if _team_is_group(team):
		return Global.team_name(team)
	var m: Array[Player] = _team_players(team)
	if m.is_empty():
		return "?"
	return Global.character_name(m[0].index, m[0].char_idx)


func _team_color(team: int) -> Color:
	if _team_is_group(team):
		return Global.team_color(team)
	var m: Array[Player] = _team_players(team)
	return Global.PLAYER_COLORS[m[0].index] if not m.is_empty() else Color.WHITE


## Sisa darah tim dalam persen: jumlah darah anggota yang hidup / total darah penuh seluruh anggota.
## Dengan persentase, tim besar tidak otomatis menang hanya karena anggotanya lebih banyak.
func _team_hp_ratio(team: int) -> float:
	var members: Array[Player] = _team_players(team)
	if members.is_empty():
		return 0.0
	var sum := 0.0
	var full := 0.0
	for m in members:
		full += m.max_hp
		if m.alive:
			sum += m.hp
	return sum / maxf(full, 0.001)


## Titik spawn tiap pemain. Mode tim: anggota satu tim dimunculkan berdekatan (urut dari kiri ke kanan
## menurut nomor tim) supaya tim tidak terpencar di awal ronde.
func _spawn_positions() -> Array:
	var spawns: Array = map["spawns"][Global.player_count]
	if not team_mode:
		return spawns
	var slots: Array = spawns.duplicate()
	slots.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var order: Array = []
	for i in players.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		if team_ids[a] != team_ids[b]:
			return team_ids[a] < team_ids[b]
		return a < b)
	var res: Array = []
	res.resize(players.size())
	for k in order.size():
		res[int(order[k])] = slots[k]
	return res


func _on_player_died(p: Player) -> void:
	# catat kill (hanya dari peluru / pisau lawan, bukan lava / duri)
	if p.killer >= 0 and p.killer != p.index and p.killer < kills.size() and team_ids[p.killer] != team_ids[p.index]:
		kills[p.killer] += 1
	p.killer = -1
	if state != State.PLAYING:
		return
	var alive_teams: Array[int] = _alive_team_ids()
	if alive_teams.size() == 1:
		_end_round(alive_teams[0])
	elif alive_teams.is_empty():
		_end_round(-1)


func _on_time_up() -> void:
	# Menang = sisa darah (persen) terbanyak. Kalau seri -> sudden death.
	var best := -1.0
	var ratios := {}
	for t in _alive_team_ids():
		var r: float = _team_hp_ratio(t)
		ratios[t] = r
		best = maxf(best, r)
	var cand_teams: Array[int] = []
	for t in ratios:
		if is_equal_approx(float(ratios[t]), best):
			cand_teams.append(int(t))
	if cand_teams.is_empty():
		_end_round(-1)
		return
	if cand_teams.size() == 1:
		_end_round(cand_teams[0])
		return
	sudden_death = true
	# Sudden Death TIDAK langsung mulai: pemain yang masih bertarung dikembalikan ke posisi awal,
	# lalu lewat intro (tulisan SUDDEN DEATH! -> FIGHT!) seperti awal ronde. Kontrol dikunci selama intro.
	state = State.INTRO
	intro_stage = 0
	state_timer = 1.8
	msg_clear = 0.0
	_show_message("SUDDEN DEATH!", Color("ff4040"))
	Global.play_sfx("sudden_death")
	Global.play_sfx("alarm_sting", -8.0)

	# bersihkan peluru, power up, dan rintangan supaya start-nya adil
	for c in bullets_root.get_children():
		c.queue_free()
	for c in powerups_root.get_children():
		c.queue_free()
	_reset_hazards()
	powerup_timer = minf(5.0, float(Global.POWERUP_AMOUNTS[Global.powerup_amount]["min"]))

	var spawns: Array = _spawn_positions()
	for i in players.size():
		var p: Player = players[i]
		if not p.alive:
			continue
		if cand_teams.has(team_ids[i]):
			p.reset(spawns[i], map["respawn"])     # kembali ke titik awal, status/power up bersih
			p.set_hp(1.0)
			p.set_knife_only(true)
		else:
			p.die()
	_update_timer_label()
	_refresh_all_panels()


## winner = nomor tim pemenang ronde (tanpa mode tim = nomor pemain), -1 = seri.
## Semua anggota tim pemenang mendapat +1 kemenangan.
func _end_round(winner: int) -> void:
	if state != State.PLAYING:
		return
	state = State.ROUND_END
	state_timer = 3.0
	msg_clear = 0.0
	for p in players:
		p.controls_enabled = false
		if p.alive:
			p.invuln = 99.0
			p.modulate.a = 1.0
	if winner >= 0:
		var match_done := false
		for m in _team_players(winner):
			wins[m.index] += 1
			if wins[m.index] >= Global.WINS_TO_MATCH:
				match_done = true
		if match_done:
			# menang match: tanpa notifikasi, langsung ke animasi kemenangan
			state_timer = 0.5
		else:
			_show_message("%s WINS!" % _team_label(winner), _team_color(winner), 80)
			Global.play_sfx("round_win", -3.0)
	else:
		_show_message("DRAW!", Color.WHITE)
		Global.play_sfx("round_draw", -3.0)
	_refresh_all_panels()


## Nomor tim yang sudah memenuhi target kemenangan (-1 = belum ada).
func _match_winner() -> int:
	for i in wins.size():
		if wins[i] >= Global.WINS_TO_MATCH:
			return team_ids[i]
	return -1


func _end_match(w_team: int) -> void:
	state = State.MATCH_END
	winner_team = w_team
	_clear_message()
	Global.prewarm_synth()
	# wakil tim untuk animasi: anggota yang masih hidup dengan darah terbanyak
	var members: Array[Player] = _team_players(w_team)
	var wp: Player = members[0]
	for m in members:
		if m.alive and (not wp.alive or m.hp > wp.hp):
			wp = m
	winner_idx = wp.index
	# suara pengisi: tim (>1 anggota) -> "Team One Win"; pemain sendiri -> "<Nama> Win"
	# Kalau pemenang menang dengan darah masih utuh (tidak berkurang, mis. 3 dari 3) -> ditambah "Flawless Victory"
	var flawless: bool = wp.alive and wp.hp >= wp.max_hp - 0.001
	if team_mode and _team_is_group(w_team):
		Global.play_team_win_voice(w_team, Global.VOICE_WIN_DELAY, flawless)
	else:
		Global.play_win_voice(wp.char_idx, Global.VOICE_WIN_DELAY, flawless)
	var layer := CanvasLayer.new()
	layer.layer = 21
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var vs := VictoryShow.new()
	vs.g = self
	vs.winner = wp
	vs.flawless = flawless
	vs.win_idx = wp.index
	vs.col = _team_color(w_team)
	vs.win_name = _team_label(w_team)
	vs.hp_left = clampf(wp.hp, 0.05, wp.max_hp)             # sisa HP asli pemenang (boleh pecahan)
	var sc := PackedStringArray()
	if team_mode:
		# skor per TIM (urut nomor tim), bukan per pemain
		var seen: Array[int] = []
		for i in players.size():
			if not seen.has(team_ids[i]):
				seen.append(team_ids[i])
		seen.sort()
		for t in seen:
			sc.append(str(wins[_team_players(t)[0].index]))
	else:
		for w in wins:
			sc.append(str(w))
	vs.score_text = " - ".join(sc)
	vs.open_overlay.connect(_on_victory_open)
	layer.add_child(vs)
	victory_show = vs


## Animasi kemenangan selesai (atau dilewati): bekukan permainan dan buka layar pilihan.
func _on_victory_open() -> void:
	get_tree().paused = true
	_open_overlay("end", winner_idx)


# ------------------------------------------------------------------ power up
func _update_powerups(delta: float) -> void:
	if Global.allowed_powerups().is_empty():
		return          # power up dimatikan / semua dilarang di BATTLE SETTINGS
	powerup_timer -= delta
	if powerup_timer > 0.0:
		return
	var cfg: Dictionary = Global.POWERUP_AMOUNTS[Global.powerup_amount]
	powerup_timer = rng.randf_range(float(cfg["min"]), float(cfg["max"]))
	if powerups_root.get_child_count() < int(cfg["cap"]):
		_spawn_powerup()


func _spawn_powerup() -> void:
	var pos: Vector2
	if map.has("powerup_spots"):
		# map dengan rintangan: power up hanya muncul di titik aman yang sudah ditentukan (simetris),
		# bukan di platform bergerak / rapuh / di atas duri.
		var free_spots: Array[Vector2] = []
		for s in map["powerup_spots"]:
			var sp: Vector2 = s
			var taken := false
			for pu0 in powerups_root.get_children():
				if (pu0 as Node2D).position.distance_to(sp) < 60.0:
					taken = true
			if not taken:
				free_spots.append(sp)
		if free_spots.is_empty():
			return
		pos = free_spots[rng.randi() % free_spots.size()]
	else:
		var rects: Array = []
		rects.append_array(map["platforms"])
		rects.append_array(map["solids"])
		var r: Rect2 = rects[rng.randi() % rects.size()]
		var x: float = rng.randf_range(r.position.x + 40.0, r.end.x - 40.0)
		pos = Vector2(x, r.position.y - 34.0)
		# jangan muncul di atas duri / kaktus (objek tambahan di Earth & Hell berdiri di lantai)
		for _try in 10:
			var on_spike := false
			for sd in map.get("spikes", []):
				var sr: Rect2 = (sd as Dictionary)["rect"]
				if sr.grow(30.0).has_point(pos):
					on_spike = true
					break
			if not on_spike:
				break
			r = rects[rng.randi() % rects.size()]
			x = rng.randf_range(r.position.x + 40.0, r.end.x - 40.0)
			pos = Vector2(x, r.position.y - 34.0)
	var types: Array = Global.allowed_powerups()
	if sudden_death:
		types.erase("ammo_refill")        # Sudden Death hanya pisau -> isi peluru tidak berguna
	if _alive_players().size() < 2:
		types.erase("swap_position")      # Swap Position butuh minimal 2 pemain hidup
	if types.is_empty():
		return
	var pu := Powerup.new()
	pu.setup(String(types[rng.randi() % types.size()]))
	pu.position = pos
	powerups_root.add_child(pu)
	Global.play_sfx("pu_spawn", -10.0)


# ------------------------------------------------------------------ swap position
## Dipanggil Player saat menekan tembak ketika punya Swap Position.
## Semua pemain yang masih hidup (2-4 pemain) diacak posisinya: tiap pemain pindah ke posisi pemain lain
## (acak, tidak ada yang tetap di tempat). Pada 2 pemain ini sama dengan saling bertukar.
## Mengembalikan false kalau tidak ada pemain lain yang bisa ditukar.
func shuffle_positions(initiator: Player) -> bool:
	var group: Array[Player] = []
	for pl in players:
		if pl.alive and not pl.vanished:
			group.append(pl)
	if group.size() < 2 or not group.has(initiator):
		return false

	var n: int = group.size()
	var order: Array = []
	for i in n:
		order.append(i)
	var ok := false
	for _try in 30:
		order.shuffle()
		ok = true
		for i in n:
			if int(order[i]) == i:
				ok = false
				break
		if ok:
			break
	if not ok:
		for i in n:
			order[i] = (i + 1) % n          # cadangan: geser satu posisi

	var old_pos: Array[Vector2] = []
	for pl in group:
		old_pos.append(pl.global_position)

	for i in n:
		var who: Player = group[i]
		var from_pos: Vector2 = old_pos[i]
		var to_pos: Vector2 = old_pos[int(order[i])]
		var pcol: Color = Global.PLAYER_COLORS[who.index]
		UIKit.burst(self, from_pos, pcol, 14, 260.0, 6.0, 0.45, 100.0)
		UIKit.ring(self, from_pos, Color("8ed457"), 90.0, 0.4)
		who.teleport_to(to_pos)
		UIKit.burst(self, to_pos, pcol, 14, 260.0, 6.0, 0.45, 100.0)
		UIKit.ring(self, to_pos, Color("8ed457"), 90.0, 0.4)
		Global.rumble(who.index, 0.3, 0.5, 0.15)

	Global.play_sfx("pu_swap")
	Global.play_sfx("swap_shuffle", -4.0)
	shake(6.0)
	return true


# ================================================================== animasi kemenangan MATCH (VERSUS)
## Urutan (waktu nyata, tidak ikut slow-mo):
##   0.0 - 1.0 s   BUILD-UP : layar menggelap + zoom ke pemenang, riser naik, detak jantung, partikel tersedot masuk
##   1.0 s         IMPACT   : flash putih, slow-mo, gelombang kejut, sinar berputar, meriam konfeti, crash + anthem
##   1.1 - 4.8 s   SHOW     : tulisan "VICTORY!" jatuh huruf demi huruf, bintang, pelat nama, kembang api, pemenang melompat
##   4.8 s         layar pilihan (REMATCH / CHANGE FIGHTERS / MAIN MENU) terbuka; kembang api + konfeti tetap jalan
## ACCEPT saat show berjalan = lewati langsung ke layar pilihan.
class VicFx:
	static var _glow: Texture2D = null
	static var _vig: Texture2D = null
	static var _add: CanvasItemMaterial = null

	static func glow() -> Texture2D:
		if _glow == null:
			var gr := Gradient.new()
			gr.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
			gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.0)])
			var tx := GradientTexture2D.new()
			tx.gradient = gr
			tx.width = 64
			tx.height = 64
			tx.fill = GradientTexture2D.FILL_RADIAL
			tx.fill_from = Vector2(0.5, 0.5)
			tx.fill_to = Vector2(1.0, 0.5)
			_glow = tx
		return _glow

	static func vignette() -> Texture2D:
		if _vig == null:
			var gr := Gradient.new()
			gr.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			gr.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0.01, 0.06, 0.7)])
			var tx := GradientTexture2D.new()
			tx.gradient = gr
			tx.width = 256
			tx.height = 256
			tx.fill = GradientTexture2D.FILL_RADIAL
			tx.fill_from = Vector2(0.5, 0.5)
			tx.fill_to = Vector2(1.0, 0.5)
			_vig = tx
		return _vig

	static func additive() -> CanvasItemMaterial:
		if _add == null:
			_add = CanvasItemMaterial.new()
			_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		return _add

	static func txt(ci: CanvasItem, s: String, rect: Rect2, fs: int, col: Color,
			align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, outline: int = 0) -> void:
		UIKit.text_in(ci, s, rect, fs, col, align, outline, Color(0, 0, 0, col.a))

	static func ease_out(p: float) -> float:
		return 1.0 - pow(1.0 - clampf(p, 0.0, 1.0), 3.0)

	static func ease_in(p: float) -> float:
		var q: float = clampf(p, 0.0, 1.0)
		return q * q * q

	static func back(p: float) -> float:
		var q: float = clampf(p, 0.0, 1.0) - 1.0
		return 1.0 + 2.70158 * q * q * q + 1.70158 * q * q

	static func elastic(p: float) -> float:
		if p <= 0.0:
			return 0.0
		if p >= 1.0:
			return 1.0
		return pow(2.0, -10.0 * p) * sin((p * 10.0 - 0.75) * (TAU / 3.0)) + 1.0

	## Kilauan 4 sudut.
	static func sparkle(c: Vector2, r: float, rot: float = 0.0) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 8:
			var rad: float = r if i % 2 == 0 else r * 0.2
			var a: float = rot + float(i) * PI * 0.25
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
		return pts

	## Teks huruf-per-huruf: tiap huruf jatuh + membal, lalu bergoyang halus dan disapu kilau putih.
	static func wave_text(ci: CanvasItem, s: String, center: Vector2, fs: int, t: float, t0: float, col: Color,
			stagger: float = 0.05, drop: float = 200.0, exit_t: float = 1.0e9, outline: int = 14) -> void:
		var n: int = s.length()
		var ws: Array[float] = []
		var total: float = 0.0
		for i in n:
			var w: float = UIKit.text_w(s[i], fs)
			if s[i] == " ":
				w = float(fs) * 0.3
			ws.append(w)
			total += w
		var x: float = center.x - total * 0.5
		var sweep: float = center.x - total * 0.5 - 150.0 + (total + 300.0) * fposmod((t - t0 - 0.9) / 1.7, 1.0)
		for i in n:
			var w2: float = ws[i]
			var lx: float = x + w2 * 0.5
			x += w2
			if s[i] == " ":
				continue
			var p: float = clampf((t - t0 - stagger * float(i)) / 0.55, 0.0, 1.0)
			if p <= 0.0:
				continue
			var e: float = elastic(p)
			var xo: float = clampf((t - exit_t - 0.03 * float(i)) / 0.45, 0.0, 1.0)
			var off := Vector2(0.0, -(1.0 - e) * drop - xo * xo * 340.0 + sin(t * 5.0 + float(i) * 0.6) * 4.0 * p)
			var sc: float = (1.0 + (1.0 - e) * 1.6) * (1.0 + xo * 0.6)
			var rot: float = (1.0 - e) * (0.55 if i % 2 == 0 else -0.55)
			var al: float = minf(p * 6.0, 1.0) * (1.0 - xo)
			var shine: float = clampf(1.0 - absf(lx - sweep) / 110.0, 0.0, 1.0) if t > t0 + 0.9 else 0.0
			var fill: Color = col.lerp(Color.WHITE, shine * 0.85)
			ci.draw_set_transform(Vector2(lx, center.y) + off, rot, Vector2.ONE * sc)
			var r := Rect2(-w2 * 0.5 - 6.0, -float(fs) * 0.65, w2 + 12.0, float(fs) * 1.3)
			UIKit.text_in(ci, s[i], r, fs, Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, outline + 18, Color(col, 0.2 * al))
			UIKit.text_in(ci, s[i], Rect2(r.position + Vector2(6, 9), r.size), fs, Color(0, 0, 0, 0.55 * al))
			UIKit.text_in(ci, s[i], r, fs, Color(fill, al), HORIZONTAL_ALIGNMENT_CENTER, outline, Color(0, 0, 0, al))
		ci.draw_set_transform(Vector2.ZERO)


## Lapisan gambar: isinya digambar oleh fungsi milik pemiliknya. additive = blend cahaya.
class VicLayer extends Control:
	var draw_fn: Callable

	func _init(additive: bool = false) -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if additive:
			material = VicFx.additive()

	func _draw() -> void:
		if draw_fn.is_valid():
			draw_fn.call(self)


class VictoryShow extends Control:
	signal open_overlay

	const BUILD := 1.0       # lama build-up sebelum ledakan
	const OPEN_T := 4.8      # kapan layar pilihan dibuka
	const HEART_COL := Color("ff4d6d")

	var g                    # game (Node2D)
	var winner: Player
	var win_idx: int = 0
	var col: Color = Color.WHITE
	var win_name: String = ""
	var score_text: String = ""
	var flawless: bool = false   # menang dengan darah masih utuh -> judul "FLAWLESS VICTORY!"
	var title_text: String = "VICTORY!"
	var title_fs: int = 138
	var hp_left: float = 3.0     # sisa HP pemenang (pecahan ikut dihitung, sama seperti HUD)
	var hearts: int = 3          # jumlah hati yang digambar = hp_left dibulatkan ke atas
	var heart_tex: Texture2D

	var t: float = 0.0
	var dt: float = 0.0
	var _us: int = 0
	var rng := RandomNumberGenerator.new()
	var bg: VicLayer
	var glow: VicLayer
	var top: VicLayer
	var palette: Array[Color] = []

	var events: Array = []
	var parts: Array = []        # percikan cahaya
	var rockets: Array = []      # roket kembang api
	var confetti: Array = []
	var glints: Array = []       # kilau bintang
	var rings: Array = []        # gelombang kejut
	var flash: float = 0.0
	var shake_v: float = 0.0
	var impact_done: bool = false
	var opened: bool = false
	var focus_w: Vector2 = Vector2(640.0, 400.0)   # posisi pemenang di dunia
	var focus: Vector2 = Vector2(640.0, 400.0)     # posisi pemenang di layar
	var layout_top: bool = true
	var title_y: float = 170.0
	var star_y: float = 290.0
	var plate_y: float = 385.0

	var _acc_in: float = 0.0
	var _next_fw: float = 0.0
	var _fw_count: int = 0
	var _next_hop: float = 0.0
	var _next_glint: float = 0.0
	var _acc_rain: float = 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _ready() -> void:
		rng.randomize()
		_us = Time.get_ticks_usec()
		heart_tex = Global.cached_tex("res://assets/sprites/ui/heart.png")
		hearts = maxi(1, ceili(hp_left - 0.001))
		_setup_title()
		palette = [col.lightened(0.2), UIKit.GOLD, Color.WHITE, Color("4fd8ff"), Color("ff5fa2"), Color("ff8a3a"), Color("4be3a0"), Color("b36bff")]
		bg = VicLayer.new(false)
		bg.draw_fn = _draw_bg
		add_child(bg)
		glow = VicLayer.new(true)
		glow.draw_fn = _draw_glow
		add_child(glow)
		top = VicLayer.new(false)
		top.draw_fn = _draw_top
		add_child(top)
		if is_instance_valid(winner):
			focus_w = winner.global_position + Vector2(0.0, -30.0)
		focus = _w2s(focus_w)
		_build_events()

	func _exit_tree() -> void:
		Engine.time_scale = 1.0
		Global.set_music_volume(Global.music_volume)   # kembalikan volume musik yang diturunkan saat show

	func _w2s(p: Vector2) -> Vector2:
		return (p - g.cam.position) * g.cam.zoom.x

	# ---------------------------------------------------------------- jadwal suara & kejadian
	func _ev(at: float, id: String, arg: int = 0) -> void:
		events.append({"t": at, "id": id, "arg": arg, "done": false})

	func _build_events() -> void:
		_ev(0.0, "riser")
		_ev(0.30, "beat", 0)
		_ev(0.58, "beat", 1)
		_ev(0.82, "beat", 2)
		_ev(BUILD, "impact")
		_ev(BUILD + 0.10, "anthem")
		for i in 8:
			_ev(BUILD + 0.28 + 0.07 * float(i), "letter", i)
		_ev(BUILD + 0.70, "crowd")
		_ev(BUILD + 0.85, "plate")
		for k in hearts:
			_ev(BUILD + 1.15 + 0.2 * float(k), "star", k)
		_ev(BUILD + 1.9, "shimmer")
		_ev(OPEN_T - 0.5, "outro")

	func _syn(id: String, db: float, pitch: float = 1.0, fallback: String = "") -> void:
		if not Global.play_synth(id, db, pitch, "Celebrate") and fallback != "":
			Global.play_sfx(fallback, db, pitch)

	func _run_event(e: Dictionary) -> void:
		e["done"] = true
		match String(e["id"]):
			"riser":
				_syn("vic_riser", -2.0, 1.0, "ui_whoosh")
			"beat":
				var k: int = int(e["arg"])
				Global.play_sfx("wall_impact", -9.0 + 2.0 * float(k), 0.5 + 0.07 * float(k))
				shake_v = maxf(shake_v, 3.0 + 1.5 * float(k))
			"impact":
				_do_impact()
			"anthem":
				if Global.has_synth("vic_anthem"):
					Global.play_synth("vic_anthem", -2.0, 1.0, "Celebrate")
				else:
					Global.play_synth("clear_fanfare", -3.0, 1.0, "Celebrate")
			"letter":
				var k2: int = int(e["arg"])
				Global.play_synth("coin", -11.0, 0.85 + 0.09 * float(k2), "Celebrate")
				shake_v = maxf(shake_v, 4.0)
			"crowd":
				Global.play_synth("applause", -6.0, 1.0, "Celebrate")
				Global.play_sfx("win_pip", -6.0, 1.2)
			"plate":
				Global.play_sfx("ui_whoosh", -4.0, 0.9)
				Global.play_sfx("perk_open", -8.0, 1.0)
				_syn("chime", -6.0, 1.0)
				shake_v = maxf(shake_v, 7.0)
				_add_ring(Vector2(640.0, plate_y), col.lightened(0.3), 700.0, 0.7, 18.0)
				for k3 in 28:
					var a: float = rng.randf() * TAU
					_spark(Vector2(640.0, plate_y), Vector2(cos(a), sin(a)) * rng.randf_range(200.0, 700.0), palette[rng.randi() % palette.size()], rng.randf_range(0.5, 1.0), rng.randf_range(12.0, 22.0), 380.0, 2.0, true)
			"star":
				var k4: int = int(e["arg"])
				Global.play_sfx("star", -4.0, 0.9 + 0.17 * float(k4))
				_syn("chime", -8.0, 1.0 + 0.19 * float(k4))
				shake_v = maxf(shake_v, 5.0)
				var sc: Vector2 = Vector2(640.0 + (float(k4) - float(hearts - 1) * 0.5) * 118.0, star_y)
				_add_ring(sc, HEART_COL, 260.0, 0.55, 10.0)
				for k5 in 22:
					var a2: float = rng.randf() * TAU
					_spark(sc, Vector2(cos(a2), sin(a2)) * rng.randf_range(120.0, 520.0), HEART_COL if k5 % 2 == 0 else Color.WHITE, rng.randf_range(0.5, 0.9), rng.randf_range(10.0, 20.0), 300.0, 2.0, true)
			"shimmer":
				_syn("shimmer", -8.0, 1.0)
			"outro":
				Global.play_sfx("ui_whoosh", -6.0, 1.25)

	func _do_impact() -> void:
		impact_done = true
		flash = 1.0
		shake_v = 30.0
		layout_top = focus.y > 330.0
		if layout_top:
			title_y = 170.0
			star_y = 290.0
			plate_y = 385.0
		else:
			title_y = 345.0
			star_y = 455.0
			plate_y = 545.0
		Global.rumble(win_idx, 0.9, 1.0, 0.9)
		_syn("clear_boom", -1.0, 0.9, "nuke")
		_syn("vic_crash", -2.0, 1.0)
		_syn("stab", -4.0, 0.8)
		Global.play_sfx("won", 0.0)
		Global.play_sfx("match_fanfare", -4.0)
		Global.play_sfx("wall_impact", -2.0, 0.45)
		_add_ring(focus, Color.WHITE, 1500.0, 0.9, 30.0)
		_add_ring(focus, col, 1300.0, 1.0, 26.0, 0.10)
		_add_ring(focus, UIKit.GOLD, 1100.0, 1.1, 22.0, 0.20)
		_add_ring(focus, col.lightened(0.4), 900.0, 1.2, 18.0, 0.32)
		for k in 160:
			var a: float = rng.randf() * TAU
			_spark(focus, Vector2(cos(a), sin(a)) * rng.randf_range(200.0, 1100.0), palette[rng.randi() % palette.size()], rng.randf_range(0.7, 1.5), rng.randf_range(14.0, 30.0), 260.0, 1.9, true)
		for k2 in 28:
			var a2: float = rng.randf() * TAU
			_glint(focus, Vector2(cos(a2), sin(a2)) * rng.randf_range(150.0, 700.0), rng.randf_range(0.7, 1.3), rng.randf_range(22.0, 50.0))
		# meriam konfeti dari dua sudut bawah
		for side in 2:
			var sx: float = 30.0 if side == 0 else 1250.0
			for k3 in 80:
				var ang: float = deg_to_rad(-68.0 + rng.randf_range(-16.0, 16.0)) if side == 0 else deg_to_rad(-112.0 + rng.randf_range(-16.0, 16.0))
				_confetti_piece(Vector2(sx, 710.0), Vector2(cos(ang), sin(ang)) * rng.randf_range(700.0, 1500.0))

	# ---------------------------------------------------------------- pembuat partikel
	func _spark(p: Vector2, v: Vector2, c: Color, life: float, size: float, grav: float, drag: float, trail: bool) -> void:
		if parts.size() > 1500:
			return
		parts.append({"p": p, "pp": p, "v": v, "life": life, "max": life, "size": size, "col": c, "grav": grav, "drag": drag, "trail": trail})

	func _glint(p: Vector2, v: Vector2, life: float, size: float) -> void:
		if glints.size() > 160:
			return
		glints.append({"p": p, "v": v, "life": life, "max": life, "size": size, "rot": rng.randf() * TAU, "rv": rng.randf_range(-3.0, 3.0),
			"col": Color.WHITE if rng.randf() < 0.5 else UIKit.GOLD})

	func _add_ring(p: Vector2, c: Color, max_r: float, dur: float, w: float, delay: float = 0.0) -> void:
		rings.append({"t0": t + delay, "p": p, "col": c, "r": max_r, "dur": dur, "w": w})

	func _confetti_piece(p: Vector2, v: Vector2) -> void:
		if confetti.size() > 320:
			return
		confetti.append({"p": p, "v": v, "rot": rng.randf() * TAU, "rv": rng.randf_range(-7.0, 7.0), "flip": rng.randf() * TAU,
			"fv": rng.randf_range(4.0, 11.0), "w": rng.randf_range(10.0, 18.0), "h": rng.randf_range(16.0, 28.0),
			"col": palette[rng.randi() % palette.size()], "sway": rng.randf() * TAU})

	func _launch_rocket() -> void:
		var tx: float = rng.randf_range(140.0, 1140.0)
		var ty: float = rng.randf_range(90.0, 330.0)
		var from := Vector2(tx + rng.randf_range(-90.0, 90.0), 760.0)
		rockets.append({"from": from, "p": from, "to": Vector2(tx, ty), "t": 0.0, "dur": rng.randf_range(0.55, 0.85), "col": palette[rng.randi() % palette.size()]})
		Global.play_synth("whistle", -13.0 if t < OPEN_T else -18.0, rng.randf_range(0.85, 1.25), "Celebrate")

	func _firework_burst(pos: Vector2, c: Color) -> void:
		var style: int = rng.randi() % 3     # 0 cincin, 1 bola, 2 cincin ganda
		var n: int = 46
		for k in n:
			var a: float = TAU * float(k) / float(n) + rng.randf() * 0.08
			var sp: float = 330.0
			var cc: Color = c
			match style:
				1:
					sp = rng.randf_range(120.0, 380.0)
				2:
					if k % 2 == 1:
						sp = 190.0
						cc = UIKit.GOLD
			_spark(pos, Vector2(cos(a), sin(a)) * sp, cc, rng.randf_range(1.0, 1.6), rng.randf_range(16.0, 26.0), 160.0, 1.7, true)
		_spark(pos, Vector2.ZERO, Color.WHITE, 0.3, 380.0, 0.0, 0.0, false)
		for k2 in 6:
			var a2: float = rng.randf() * TAU
			_glint(pos, Vector2(cos(a2), sin(a2)) * rng.randf_range(60.0, 220.0), rng.randf_range(0.5, 0.9), rng.randf_range(16.0, 32.0))
		Global.play_synth("pop", -8.0 if t < OPEN_T else -13.0, rng.randf_range(0.85, 1.25), "Celebrate")
		shake_v = maxf(shake_v, 2.0)

	# ---------------------------------------------------------------- kontrol dari luar
	func skip() -> void:
		if opened or t < BUILD + 1.2 or t >= OPEN_T - 0.6:
			return
		t = OPEN_T - 0.45
		for e in events:
			if not bool(e["done"]) and float(e["t"]) < t:
				e["done"] = true

	# ---------------------------------------------------------------- update
	func _process(_d: float) -> void:
		var now: int = Time.get_ticks_usec()
		dt = clampf(float(now - _us) / 1000000.0, 0.0, 0.1)
		_us = now
		t += dt
		for e in events:
			if not bool(e["done"]) and t >= float(e["t"]):
				_run_event(e)
		_update_time_scale()
		_update_music()
		_update_camera()
		_update_actors()
		_update_particles()
		flash = maxf(flash - dt * 2.6, 0.0)
		if not opened and t >= OPEN_T:
			opened = true
			Engine.time_scale = 1.0
			open_overlay.emit()
		bg.queue_redraw()
		glow.queue_redraw()
		top.queue_redraw()

	func _update_time_scale() -> void:
		var ts: float = 1.0
		if t < BUILD:
			ts = lerpf(1.0, 0.45, VicFx.ease_out(t / 0.5))
		elif t < BUILD + 0.3:
			ts = 0.1
		elif t < BUILD + 1.3:
			ts = lerpf(0.1, 0.55, VicFx.ease_out((t - BUILD - 0.3) / 1.0))
		elif t < BUILD + 2.3:
			ts = lerpf(0.55, 1.0, VicFx.ease_out((t - BUILD - 1.3) / 1.0))
		Engine.time_scale = ts

	## Musik latar diturunkan selama show supaya fanfare menonjol, lalu naik lagi pelan-pelan.
	func _update_music() -> void:
		if t > OPEN_T + 2.0:
			return
		var idx: int = AudioServer.get_bus_index("Music")
		if idx < 0:
			return
		var duck: float = -14.0 * clampf(t / 0.6, 0.0, 1.0) * (1.0 - clampf((t - (OPEN_T + 0.3)) / 1.5, 0.0, 1.0))
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(Global.music_volume, 0.0001)) + duck)

	func _zoom_at(tt: float) -> float:
		var z: float
		if tt < BUILD:
			z = 1.0 + 0.20 * smoothstep(0.0, 1.0, tt / BUILD)
		else:
			var u: float = tt - BUILD
			z = lerpf(1.16, 1.06, clampf(u / 3.0, 0.0, 1.0)) + 0.14 * exp(-u * 6.0)
		var bk: float = smoothstep(0.0, 1.0, clampf((tt - (OPEN_T - 0.8)) / 0.8, 0.0, 1.0))
		return lerpf(z, 1.0, bk)

	func _update_camera() -> void:
		var target: Vector2 = focus_w
		if is_instance_valid(winner):
			target = winner.global_position + Vector2(0.0, -30.0)
		target = Vector2(clampf(target.x, 0.0, 1280.0), clampf(target.y, 0.0, 720.0))
		focus_w = focus_w.lerp(target, minf(dt * 5.0, 1.0))
		var jit := Vector2.ZERO
		if Global.screen_shake and shake_v > 0.05:
			jit = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake_v
		shake_v = lerpf(shake_v, 0.0, minf(dt * 6.0, 1.0))
		if shake_v <= 0.05:
			shake_v = 0.0
		if t < OPEN_T:
			var z: float = _zoom_at(t)
			g.cam.zoom = Vector2.ONE * z
			g.cam.position = focus_w - focus_w / z + jit
		else:
			g.cam.zoom = Vector2.ONE
			g.cam.position = jit
		focus = _w2s(focus_w)

	func _update_actors() -> void:
		if not impact_done:
			# build-up: percikan cahaya tersedot ke pemenang
			_acc_in += dt * (30.0 + 110.0 * clampf(t / BUILD, 0.0, 1.0))
			while _acc_in >= 1.0:
				_acc_in -= 1.0
				var a: float = rng.randf() * TAU
				var p0: Vector2 = focus + Vector2(cos(a), sin(a)) * rng.randf_range(260.0, 520.0)
				_spark(p0, (focus - p0) / 0.42, palette[rng.randi() % palette.size()], 0.42, 18.0, 0.0, 0.0, true)
			return
		# pemenang melompat girang
		if t >= BUILD + 0.6 and t < OPEN_T - 1.0 and t >= _next_hop and is_instance_valid(winner) and winner.alive:
			_next_hop = t + 0.8
			if winner.is_on_floor():
				winner.velocity.y = -580.0
				winner._squash(Vector2(0.72, 1.35))
				Global.play_sfx("jump", -9.0, rng.randf_range(1.15, 1.35))
				var feet: Vector2 = _w2s(winner.global_position + Vector2(0.0, 28.0))
				_add_ring(feet, UIKit.GOLD, 160.0, 0.45, 8.0)
				for k in 12:
					var a2: float = rng.randf_range(PI, TAU)
					_spark(feet, Vector2(cos(a2), sin(a2)) * rng.randf_range(100.0, 320.0), UIKit.GOLD, rng.randf_range(0.3, 0.6), rng.randf_range(10.0, 18.0), 500.0, 1.5, true)
		# kembang api
		if t >= BUILD + 0.45 and t >= _next_fw:
			_launch_rocket()
			_fw_count += 1
			var gap: float
			if _fw_count < 8:
				gap = rng.randf_range(0.28, 0.5)
			elif t < OPEN_T:
				gap = rng.randf_range(0.5, 0.9)
			else:
				gap = rng.randf_range(0.9, 1.5)
			_next_fw = t + gap
		# kilau di sekitar pemenang
		if t >= _next_glint:
			_next_glint = t + (0.07 if t < OPEN_T else 0.25)
			var a3: float = rng.randf() * TAU
			var gp: Vector2 = focus + Vector2(cos(a3), sin(a3)) * rng.randf_range(50.0, 260.0)
			_glint(gp, Vector2(0.0, -rng.randf_range(10.0, 50.0)), rng.randf_range(0.5, 0.9), rng.randf_range(14.0, 34.0))
		# hujan konfeti dari atas
		_acc_rain += dt * 50.0
		while _acc_rain >= 1.0:
			_acc_rain -= 1.0
			_confetti_piece(Vector2(rng.randf_range(-20.0, 1300.0), -24.0), Vector2(rng.randf_range(-40.0, 40.0), rng.randf_range(80.0, 200.0)))

	func _update_particles() -> void:
		for i in range(parts.size() - 1, -1, -1):
			var q: Dictionary = parts[i]
			q["life"] = float(q["life"]) - dt
			if float(q["life"]) <= 0.0:
				parts.remove_at(i)
				continue
			q["pp"] = q["p"]
			var v: Vector2 = q["v"]
			v *= (1.0 - minf(float(q["drag"]) * dt, 1.0))
			v.y += float(q["grav"]) * dt
			q["v"] = v
			q["p"] = Vector2(q["p"]) + v * dt
		for i in range(glints.size() - 1, -1, -1):
			var q2: Dictionary = glints[i]
			q2["life"] = float(q2["life"]) - dt
			if float(q2["life"]) <= 0.0:
				glints.remove_at(i)
				continue
			q2["p"] = Vector2(q2["p"]) + Vector2(q2["v"]) * dt
			q2["v"] = Vector2(q2["v"]) * (1.0 - minf(1.5 * dt, 1.0))
			q2["rot"] = float(q2["rot"]) + float(q2["rv"]) * dt
		for i in range(confetti.size() - 1, -1, -1):
			var c: Dictionary = confetti[i]
			var cv: Vector2 = c["v"]
			cv.y += 900.0 * dt
			cv.x *= (1.0 - minf(0.9 * dt, 1.0))
			if cv.y > 230.0:
				cv.y = lerpf(cv.y, 230.0, minf(dt * 3.0, 1.0))
			c["v"] = cv
			var cp: Vector2 = Vector2(c["p"]) + cv * dt
			cp.x += sin(t * 3.0 + float(c["sway"])) * 38.0 * dt
			c["p"] = cp
			c["rot"] = float(c["rot"]) + float(c["rv"]) * dt
			c["flip"] = float(c["flip"]) + float(c["fv"]) * dt
			if cp.y > 790.0 or cp.x < -80.0 or cp.x > 1360.0:
				confetti.remove_at(i)
		for i in range(rockets.size() - 1, -1, -1):
			var r: Dictionary = rockets[i]
			r["t"] = float(r["t"]) + dt
			var u: float = clampf(float(r["t"]) / float(r["dur"]), 0.0, 1.0)
			var e: float = 1.0 - pow(1.0 - u, 2.0)
			var p: Vector2 = Vector2(r["from"]).lerp(Vector2(r["to"]), e) + Vector2(sin(u * 16.0) * 8.0 * (1.0 - u), 0.0)
			r["p"] = p
			_spark(p, Vector2(rng.randf_range(-30.0, 30.0), rng.randf_range(30.0, 90.0)), Color(r["col"]).lerp(Color.WHITE, 0.5), 0.35, 14.0, 0.0, 2.0, false)
			if u >= 1.0:
				_firework_burst(Vector2(r["to"]), Color(r["col"]))
				rockets.remove_at(i)

	# ---------------------------------------------------------------- gambar: latar gelap + sorotan
	func _draw_bg(ci: CanvasItem) -> void:
		var kin: float = smoothstep(0.0, 1.0, clampf(t / BUILD, 0.0, 1.0))
		var kout: float = 1.0 - smoothstep(0.0, 1.0, clampf((t - OPEN_T) / 0.6, 0.0, 1.0))
		var k: float = kin * kout
		if k <= 0.001:
			return
		ci.draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.01, 0.05, 0.42 * k))
		ci.draw_texture_rect(VicFx.vignette(), Rect2(focus - Vector2(1300.0, 850.0), Vector2(2600.0, 1700.0)), false, Color(1, 1, 1, k))

	# ---------------------------------------------------------------- gambar: cahaya (additive)
	func _draw_glow(ci: CanvasItem) -> void:
		var c: Vector2 = focus
		var pre: float = VicFx.ease_out(clampf((t - 0.15) / (BUILD - 0.15), 0.0, 1.0)) * 0.35
		var post: float = VicFx.ease_out(clampf((t - BUILD) / 0.35, 0.0, 1.0))
		var amb: float = lerpf(1.0, 0.14, clampf((t - (OPEN_T - 0.3)) / 0.9, 0.0, 1.0))
		var k: float = (pre + post * 0.65) * amb
		if k > 0.01:
			# sinar berputar
			var n: int = 18
			for i in n:
				var a0: float = t * 0.5 + float(i) * TAU / float(n)
				var a1: float = a0 + TAU / float(n) * 0.42
				var rc: Color = col if i % 2 == 0 else UIKit.GOLD.lerp(col, 0.25)
				ci.draw_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * 1500.0, c + Vector2(cos(a1), sin(a1)) * 1500.0]),
					PackedColorArray([Color(rc, 0.42 * k), Color(rc, 0.0), Color(rc, 0.0)]))
			# aura pemenang
			var pulse: float = 1.0 + 0.08 * sin(t * 6.0)
			var gs: float = (260.0 + 380.0 * k) * pulse
			ci.draw_texture_rect(VicFx.glow(), Rect2(c - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false, Color(col.lightened(0.2), 0.75 * minf(k * 1.2, 1.0)))
			var cs: float = gs * 0.45
			ci.draw_texture_rect(VicFx.glow(), Rect2(c - Vector2(cs, cs) * 0.5, Vector2(cs, cs)), false, Color(1, 1, 1, 0.55 * k))
		if post > 0.0:
			# pilar cahaya naik dari pemenang
			ci.draw_texture_rect(VicFx.glow(), Rect2(c.x - 120.0, c.y - 900.0, 240.0, 1100.0), false, Color(1, 1, 1, 0.45 * post * amb))
		if t < BUILD:
			# cincin menyempit ke arah pemenang
			for j in 3:
				var pj: float = fposmod(t * 1.6 + float(j) / 3.0, 1.0)
				ci.draw_arc(c, (1.0 - pj) * 420.0 + 30.0, 0.0, TAU, 64, Color(col, 0.55 * pj * clampf(t / 0.4, 0.0, 1.0)), 5.0, true)
		if impact_done:
			# garis kecepatan memancar saat ledakan
			var sp: float = (t - BUILD) / 0.5
			if sp > 0.0 and sp < 1.0:
				for i in 44:
					var ang: float = float(i) * TAU / 44.0 + sin(float(i) * 12.9898) * 0.05
					var dir := Vector2(cos(ang), sin(ang))
					var r0: float = 160.0 + 2200.0 * VicFx.ease_out(sp)
					var ln: float = 380.0 * (1.0 - sp) + 40.0
					ci.draw_line(c + dir * r0, c + dir * (r0 + ln), Color(1, 1, 1, 0.9 * (1.0 - sp)), 4.0 * (1.0 - sp) + 1.0)
		# gelombang kejut
		for rg in rings:
			var p: float = (t - float(rg["t0"])) / float(rg["dur"])
			if p < 0.0 or p > 1.0:
				continue
			var rr: float = float(rg["r"]) * VicFx.ease_out(p)
			var rcol: Color = rg["col"]
			var w: float = maxf(float(rg["w"]) * (1.0 - p), 2.0)
			var rp: Vector2 = rg["p"]
			ci.draw_arc(rp, rr, 0.0, TAU, 96, Color(rcol, 0.85 * (1.0 - p)), w, true)
			ci.draw_arc(rp, rr, 0.0, TAU, 96, Color(rcol, 0.22 * (1.0 - p)), w * 3.5, true)
		# percikan
		for q in parts:
			var lf: float = float(q["life"]) / float(q["max"])
			var sz: float = float(q["size"]) * (0.3 + 0.7 * lf)
			var qc: Color = q["col"]
			var qp: Vector2 = q["p"]
			if bool(q["trail"]):
				ci.draw_line(Vector2(q["pp"]), qp, Color(qc, 0.55 * lf), maxf(3.0 * lf, 1.0), true)
			ci.draw_texture_rect(VicFx.glow(), Rect2(qp - Vector2(sz, sz), Vector2(sz, sz) * 2.0), false, Color(qc, clampf(lf * 1.6, 0.0, 1.0)))
		# kepala roket
		for r in rockets:
			var rp2: Vector2 = r["p"]
			ci.draw_texture_rect(VicFx.glow(), Rect2(rp2 - Vector2(30, 30), Vector2(60, 60)), false, Color(Color(r["col"]), 0.9))
			ci.draw_circle(rp2, 4.0, Color.WHITE)
		# kilau bintang
		for q2 in glints:
			var u: float = 1.0 - float(q2["life"]) / float(q2["max"])
			var s: float = float(q2["size"]) * sin(PI * clampf(u, 0.0, 1.0))
			if s <= 0.5:
				continue
			var gp: Vector2 = q2["p"]
			var gc: Color = q2["col"]
			ci.draw_texture_rect(VicFx.glow(), Rect2(gp - Vector2(s, s), Vector2(s, s) * 2.0), false, Color(gc, 0.55))
			ci.draw_colored_polygon(VicFx.sparkle(gp, s, float(q2["rot"])), Color(gc, 0.95))

	# ---------------------------------------------------------------- gambar: konfeti, bar sinema, teks, flash
	func _draw_top(ci: CanvasItem) -> void:
		for c in confetti:
			var cp: Vector2 = c["p"]
			var cw: float = float(c["w"]) * absf(cos(float(c["flip"]))) + 1.0
			var chh: float = float(c["h"])
			var a: float = float(c["rot"])
			var ax := Vector2(cos(a), sin(a)) * cw * 0.5
			var ay := Vector2(-sin(a), cos(a)) * chh * 0.5
			var cc: Color = c["col"]
			var shade: float = 0.35 * (1.0 - absf(cos(float(c["flip"]))))
			ci.draw_colored_polygon(PackedVector2Array([cp - ax - ay, cp + ax - ay, cp + ax + ay, cp - ax + ay]), cc.darkened(shade))
		# bar sinema atas-bawah
		var bin: float = VicFx.ease_out(clampf(t / 0.55, 0.0, 1.0))
		var bout: float = VicFx.ease_in(clampf((t - (OPEN_T - 0.15)) / 0.55, 0.0, 1.0))
		var bh: float = 84.0 * bin * (1.0 - bout)
		if bh > 0.5:
			ci.draw_rect(Rect2(0.0, 0.0, 1280.0, bh), Color(0, 0, 0, 0.93))
			ci.draw_rect(Rect2(0.0, 720.0 - bh, 1280.0, bh), Color(0, 0, 0, 0.93))
			if impact_done:
				ci.draw_rect(Rect2(0.0, bh - 4.0, 1280.0, 4.0), Color(col, 0.9))
				ci.draw_rect(Rect2(0.0, 720.0 - bh, 1280.0, 4.0), Color(col, 0.9))
		if impact_done and t < OPEN_T + 0.8:
			_draw_title(ci)
		if flash > 0.01:
			ci.draw_rect(Rect2(Vector2.ZERO, size), Color(col.lerp(Color.WHITE, 0.75), 0.92 * flash))

	## Satu hati. fill = 0..1 (bagian yang terisi dari kiri, sama seperti hati di HUD).
	## Bagian yang kosong digambar gelap supaya jelas berapa HP yang hilang.
	func _draw_heart(ci: CanvasItem, c: Vector2, r: float, rot: float, al: float, fill: float = 1.0) -> void:
		if r <= 0.5:
			return
		fill = clampf(fill, 0.0, 1.0)
		var hs: float = r * 1.25      # setengah lebar hati
		if heart_tex != null:
			var tw: float = float(heart_tex.get_width())
			var th: float = float(heart_tex.get_height())
			ci.draw_set_transform(c + Vector2(4.0, 6.0), rot, Vector2.ONE)
			ci.draw_texture_rect(heart_tex, Rect2(-hs, -hs, hs * 2.0, hs * 2.0), false, Color(0, 0, 0, 0.5 * al))
			ci.draw_set_transform(c, rot, Vector2.ONE)
			if fill < 0.999:
				ci.draw_texture_rect(heart_tex, Rect2(-hs, -hs, hs * 2.0, hs * 2.0), false, Color(0.12, 0.12, 0.14, 0.85 * al))
			if fill > 0.001:
				var glow_w: float = hs * 2.24 * fill
				ci.draw_texture_rect_region(heart_tex, Rect2(-hs * 1.12, -hs * 1.12, glow_w, hs * 2.24), Rect2(0.0, 0.0, tw * fill, th), Color(1, 1, 1, 0.25 * al))
				ci.draw_texture_rect_region(heart_tex, Rect2(-hs, -hs, hs * 2.0 * fill, hs * 2.0), Rect2(0.0, 0.0, tw * fill, th), Color(1, 1, 1, al))
		else:
			var pts := PackedVector2Array()
			for n in 40:
				var a: float = TAU * float(n) / 40.0
				var hx: float = 16.0 * pow(sin(a), 3.0)
				var hy: float = -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))
				pts.append(Vector2(hx, hy) * (r / 17.0))
			ci.draw_set_transform(c + Vector2(4.0, 6.0), rot, Vector2.ONE)
			ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.5 * al))
			ci.draw_set_transform(c, rot, Vector2.ONE)
			if fill < 0.999:
				ci.draw_colored_polygon(pts, Color(0.12, 0.12, 0.14, 0.85 * al))
			if fill > 0.001:
				var edge: float = lerpf(-16.0, 16.0, fill) * (r / 17.0)
				var clip_rect := PackedVector2Array([Vector2(-r * 3.0, -r * 3.0), Vector2(edge, -r * 3.0), Vector2(edge, r * 3.0), Vector2(-r * 3.0, r * 3.0)])
				for piece in Geometry2D.intersect_polygons(pts, clip_rect):
					ci.draw_colored_polygon(piece, Color(HEART_COL, al))
			ci.draw_polyline(UIKit.closed(pts), Color("ffd0d8", al), 4.0, true)
		ci.draw_set_transform(Vector2.ZERO)

	## Tentukan judul: "FLAWLESS VICTORY!" (darah utuh) atau "VICTORY!" biasa.
	## Judul panjang otomatis dikecilkan supaya muat di layar (lebar maks 1180 px dari 1280).
	func _setup_title() -> void:
		title_text = "FLAWLESS VICTORY!" if flawless else "VICTORY!"
		title_fs = 138
		var total: float = 0.0
		for i in title_text.length():
			total += float(title_fs) * 0.3 if title_text[i] == " " else UIKit.text_w(title_text[i], title_fs)
		if total > 1180.0:
			title_fs = maxi(40, int(floor(float(title_fs) * 1180.0 / total)))

	func _draw_title(ci: CanvasItem) -> void:
		var exit_t: float = OPEN_T - 0.5
		var stagger: float = 0.07 if not flawless else 0.045   # judul panjang: huruf jatuh lebih rapat supaya tidak kelamaan
		VicFx.wave_text(ci, title_text, Vector2(640.0, title_y), title_fs, t, BUILD + 0.12, UIKit.GOLD, stagger, 260.0, exit_t, 16)
		ci.draw_set_transform(Vector2.ZERO)
		var pout: float = clampf((t - exit_t) / 0.45, 0.0, 1.0)
		# hati = sisa nyawa pemenang
		for k in hearts:
			var ts: float = BUILD + 1.15 + 0.2 * float(k)
			var p: float = (t - ts) / 0.5
			if p <= 0.0 or pout >= 1.0:
				continue
			var mid: bool = hearts % 2 == 1 and k * 2 == hearts - 1
			var beat: float = 1.0 + 0.07 * sin(t * 6.0 + float(k))
			var r: float = (46.0 if mid else 34.0) * VicFx.elastic(p) * (1.0 - VicFx.ease_in(pout) * 0.8) * beat
			var rot: float = (1.0 - VicFx.ease_out(p)) * 0.9 + sin(t * 2.0 + float(k)) * 0.06
			var hc := Vector2(640.0 + (float(k) - float(hearts - 1) * 0.5) * 118.0, star_y - (14.0 if mid else 0.0) + sin(t * 2.0 + float(k)) * 3.0)
			var al: float = clampf(p * 5.0, 0.0, 1.0) * (1.0 - pout)
			_draw_heart(ci, hc, r, rot, al, clampf(hp_left - float(k), 0.0, 1.0))
		# pelat nama pemenang
		var pt0: float = BUILD + 0.85
		var pin: float = clampf((t - pt0) / 0.55, 0.0, 1.0)
		if pin <= 0.0 or pout >= 1.0:
			return
		var slide: float = (1.0 - VicFx.back(pin)) * 1500.0 - VicFx.ease_in(pout) * 1500.0
		var w: float = maxf(UIKit.text_w(win_name, 64) + 180.0, 520.0)
		var h: float = 96.0
		var x: float = 640.0 - w * 0.5 + slide
		var y: float = plate_y - h * 0.5
		var pp: PackedVector2Array = UIKit.slanted(w, h, 26.0, x, y)
		ci.draw_colored_polygon(UIKit.slanted(w, h, 26.0, x + 8.0, y + 10.0), Color(0, 0, 0, 0.5))
		ci.draw_polygon(pp, PackedColorArray([col.lightened(0.15), col.lightened(0.15), col.darkened(0.35), col.darkened(0.35)]))
		# kilau menyapu pelat
		var sx: float = x + (fposmod(t * 0.7, 2.0) - 0.3) * w
		var band := PackedVector2Array([Vector2(sx + 30.0, y), Vector2(sx + 90.0, y), Vector2(sx + 60.0, y + h), Vector2(sx, y + h)])
		var clip: Array = Geometry2D.intersect_polygons(band, pp)
		if clip.size() > 0:
			ci.draw_colored_polygon(clip[0], Color(1, 1, 1, 0.28))
		ci.draw_polyline(UIKit.closed(pp), Color(1, 1, 1, 0.95), 4.0, true)
		VicFx.txt(ci, win_name, Rect2(x, y, w, h), 64, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10)
		var sa: float = clampf((t - pt0 - 0.25) / 0.3, 0.0, 1.0) * (1.0 - pout)
		if sa > 0.0:
			VicFx.txt(ci, "MATCH WINNER   %s" % score_text, Rect2(x, plate_y + 52.0, w, 40.0), 30, Color(UIKit.GOLD, sa), HORIZONTAL_ALIGNMENT_CENTER, 7)
