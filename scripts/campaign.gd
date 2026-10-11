extends "res://scripts/game.gd"
## Mode CAMPAIGN (single player). Memakai dunia, fisika, senjata, peluru, power up, dan rintangan dari game.gd,
## tetapi alurnya: LEVEL -> beberapa WAVE musuh (AI) -> hasil + bintang -> pilih PERK -> level berikutnya.
## 250 level (5 chapter x 10 dunia x 5 level), boss di akhir tiap dunia. Data level / musuh / perk: scripts/campaign_data.gd.
## Otak musuh: scripts/ai_brain.gd, peta navigasi musuh: scripts/nav_map.gd.

const WeaponFx = preload("res://scripts/weapon_fx.gd")

var run: Dictionary = {}
var level_n: int = 1
var lvl: Dictionary = {}
var boss_level: bool = false

var hero: Player
var enemies: Array[Player] = []
var nav: NavMap
var hazard_rects: Array[Rect2] = []
var drop_points: Array[Vector2] = []

var ph: String = "intro"            # intro, spawning, fight, wave_clear, level_clear, tally, perk, dead, over, complete
var ph_t: float = 0.0
var wave_i: int = -1
var start_wave: int = 0             # wave awal saat level dimulai (>0 = melanjutkan wave tempat pemain mati)
var spawn_queue: Array = []         # [{kind}]
var spawn_cd: float = 0.0

var kill_total: int = 0
var score_gain: int = 0
var dmg_taken: float = 0.0
var combo: int = 0
var combo_t: float = 0.0
var level_time: float = 0.0
var died_here: int = 0
var last_hp: float = 3.0
var boss_state: Dictionary = {}     # Player -> {"enraged", "summons"}
var slow_until: int = 0
var ammo_t: float = 0.0

var camp_hud: CampHud
var panel_layer: CanvasLayer
var panel: Control = null
var tally_data: Dictionary = {}
var _quitting: bool = false
var _exit_dest: String = ""            # tujuan keluar ("map" / "menu") yang menunggu pemain memilih perk dulu

# --- animasi LEVEL CLEAR (waktu nyata, tidak ikut melambat saat slow-motion)
const CLEAR_OPEN_T := 4.1           # detik sejak level clear sampai panel hasil dibuka
const CLEAR_OPEN_T_BOSS := 4.7
var clear_fx: ClearFx = null
var clear_t: float = 0.0
var clear_dt: float = 0.0
var clear_us: int = 0
var clear_open: bool = false
var clear_open_t: float = 4.1
var clear_events: Array = []        # [{t, id, done}]
var clear_fw_next: float = 0.0
var clear_fw_count: int = 0
var clear_fw_max: int = 6
var clear_hop_next: float = 0.0
var clear_zoom: float = 1.0
var clear_focus: Vector2 = Vector2(640, 500)
var clear_layer: CanvasLayer = null
var prev_best: int = 0
var prev_stars: int = 0

# --- animasi KEKALAHAN: YOU DIED / GAME OVER (waktu nyata, tidak ikut melambat saat slow-motion)
var defeat_fx: DefeatFx = null
var defeat_layer: CanvasLayer = null
var defeat_gray: ColorRect = null
var defeat_t: float = 0.0
var defeat_dt: float = 0.0
var defeat_us: int = 0
var defeat_open: bool = false
var defeat_open_t: float = 3.6
var defeat_over: bool = false
var defeat_events: Array = []       # [{t, id, arg, done}]
var defeat_zoom: float = 1.0
var defeat_zoom_open: float = 1.0
var defeat_focus: Vector2 = Vector2(640, 500)
var defeat_lives_before: int = 1
var defeat_slots: int = 3

## Layar memudar jadi hitam-putih (kemerahan) saat pahlawan kalah. Membaca layar di bawahnya (screen texture).
const DEFEAT_SHADER := """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec3 c = textureLod(scr, SCREEN_UV, 0.0).rgb;
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	vec3 d = mix(c, vec3(g) * vec3(1.0, 0.8, 0.8), amount);
	COLOR = vec4(d, 1.0);
}
"""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	run = Global.campaign_run
	if run.is_empty():
		run = CampaignData.new_run()
		Global.campaign_run = run
	level_n = clampi(int(run["level"]), 1, CampaignData.TOTAL_LEVELS)
	lvl = CampaignData.level(level_n)
	boss_level = CampaignData.is_boss_level(level_n)
	map = MapData.get_map(String(lvl["map"]), CampaignData.map_variant(level_n))
	_music_reset()
	Global.play_music("boss" if boss_level else "campaign")
	Global.prewarm_synth()   # suara perayaan LEVEL CLEAR dibangun di latar belakang

	cam = Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(cam)
	cam.make_current()

	_build_world()
	nav = NavMap.new()
	nav.build(map, moving_platforms)
	for d in map.get("spikes", []):
		hazard_rects.append(d["rect"])
	for r in map.get("lava", []):
		hazard_rects.append(r)
	# rintangan baru: jangan munculkan musuh di jalur gergaji / di dalam portal
	for d in map.get("saws", []):
		var sv: Vector2 = d["pos"]
		var mv: Vector2 = d["move"]
		var rad: float = float(d["radius"]) + 10.0
		hazard_rects.append(Rect2(sv.x - absf(mv.x) - rad, sv.y - absf(mv.y) - rad, absf(mv.x) * 2.0 + rad * 2.0, absf(mv.y) * 2.0 + rad * 2.0))
	for d in map.get("portals", []):
		hazard_rects.append((d["a"] as Rect2).grow(14.0))
		hazard_rects.append((d["b"] as Rect2).grow(14.0))
	drop_points = nav.stand_points(hazard_rects, 60.0)

	_build_players()
	_build_hud()
	_build_overlay()
	_build_panels()
	UIInput.pressed.connect(_on_camp_input)

	if level_n == CampaignData.checkpoint_of(level_n) and not bool(run.get("practice", false)):
		CampaignData.mark_checkpoint(run)
	CampaignData.save_run(run)
	_begin_level()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	_music_reset()
	if UIInput.pressed.is_connected(_on_camp_input):
		UIInput.pressed.disconnect(_on_camp_input)


# ------------------------------------------------------------------ bangun
func _build_players() -> void:
	var sel: Dictionary = {"character": 0, "weapon": "smith"}
	if Global.selections.size() >= 1:
		sel = Global.selections[0]
	hero = Player.new()
	players_root.add_child(hero)
	hero.team = 0
	CampaignData.apply_perks(hero, run["perks"])
	hero.setup(0, int(sel["character"]), String(sel["weapon"]), self)
	Cosmetics.apply_to_player(hero, sel)
	hero.tag.add_theme_color_override("font_color", Color("4be3a0"))
	hero.died.connect(_on_player_died)
	hero.status_changed.connect(_on_player_status)
	hero.status_changed.connect(_on_hero_status)
	players.append(hero)
	wins.append(0)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud_root = Control.new()
	hud_root.theme = Global.ui_theme
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud_root)

	var h := PlayerHud.new(0, hero)
	h.position = Vector2(14, 12)
	h.max_hearts = int(hero.max_hp)
	h.show_wins = false
	h.hp_shown = hero.max_hp
	h.last_hp = hero.max_hp
	h.sub_text = "PERKS  %d" % _perk_total()
	hud_root.add_child(h)
	huds.append(h)

	camp_hud = CampHud.new()
	camp_hud.g = self
	hud_root.add_child(camp_hud)

	banner = BannerFx.new()
	hud_root.add_child(banner)


func _build_overlay() -> void:
	super._build_overlay()
	(overlay_btns["rematch"] as UIKit.FancyButton).text = "RESTART LEVEL"
	(overlay_btns["select"] as UIKit.FancyButton).text = "LEVEL MAP"
	for id in overlay_btns:
		(overlay_btns[id] as UIKit.FancyButton).queue_redraw()


func _build_panels() -> void:
	panel_layer = CanvasLayer.new()
	panel_layer.layer = 22
	panel_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(panel_layer)


## Kembalikan musik ke kondisi normal (animasi kalah memperlambat & meredam musik).
func _music_reset() -> void:
	if Global._music != null:
		Global._music.pitch_scale = 1.0
		Global._music.volume_db = 0.0


func _perk_total() -> int:
	var t: int = 0
	for id in run["perks"]:
		t += int(run["perks"][id])
	return t


func _rematch() -> void:
	Global.goto("campaign")


func _to_select() -> void:
	Global.play_music("menu")
	Global.goto("campaign_hub")


func _toggle_pause() -> void:
	if panel != null or ph in ["tally", "perk", "over", "complete", "died", "dead"]:
		return
	super._toggle_pause()


# ------------------------------------------------------------------ alur level
func _begin_level() -> void:
	_reset_hazards()
	CampaignData.apply_perks(hero, run["perks"])
	var sp: Array = map["spawns"][2]
	hero.reset(sp[0], map["respawn"])
	hero.facing = 1
	last_hp = hero.hp
	kill_total = 0
	score_gain = 0
	dmg_taken = 0.0
	combo = 0
	combo_t = 0.0
	level_time = 0.0
	died_here = 0
	wave_i = -1
	start_wave = 0
	var rs: Variant = run.get("resume", null)
	if rs is Dictionary and int((rs as Dictionary).get("level", -1)) == level_n:
		start_wave = clampi(int((rs as Dictionary).get("wave", 0)), 0, _total_waves() - 1)
	# Nyawa berlaku PER LEVEL: tiap level baru dimulai dengan nyawa penuh (tidak terbawa dari level sebelumnya).
	# Kalau sedang melanjutkan level yang sama setelah mati, sisa nyawa tetap dipakai.
	var resuming: bool = rs is Dictionary and int((rs as Dictionary).get("level", -1)) == level_n
	if not resuming:
		run["lives"] = CampaignData.START_LIVES
		CampaignData.save_run(run)
	level_time = 25.0 * float(start_wave)   # waktu wave yang dilewati dihitung, supaya bonus waktu tetap adil
	ph = "intro"
	intro_stage = 0
	ph_t = 1.5
	_show_message(CampaignData.level_text(level_n), Color("ffd23f"))
	Global.play_sfx("level_start")
	camp_hud.hint_t = 6.0 if String(lvl["hint"]) != "" else 0.0
	powerup_timer = rng.randf_range(float(lvl["pu"][0]), float(lvl["pu"][1])) * 0.6
	_refresh_all_panels()


func _total_waves() -> int:
	return (lvl["waves"] as Array).size()


func _start_wave(i: int) -> void:
	wave_i = i
	spawn_queue.clear()
	var has_boss: bool = false
	for e in (lvl["waves"] as Array)[i]:
		var kind: String = String(e[0])
		if bool((CampaignData.ENEMIES[kind] as Dictionary).get("boss", false)):
			has_boss = true
		for k in int(e[1]):
			spawn_queue.append({"kind": kind})
	spawn_queue.shuffle()
	# boss selalu muncul pertama supaya efek masuknya terlihat
	for k in spawn_queue.size():
		if String(spawn_queue[k]["kind"]).begins_with("boss_"):
			var b: Dictionary = spawn_queue[k]
			spawn_queue.remove_at(k)
			spawn_queue.insert(0, b)
			break
	spawn_cd = 0.5
	ph = "spawning"
	if has_boss:
		_show_message("WARNING!", Color("ff4040"), 110)
		msg_clear = 1.5
		Global.play_sfx("boss_intro")
		shake(10.0)
	else:
		_show_message("WAVE %d / %d" % [i + 1, _total_waves()], Color("ffd23f"), 84)
		msg_clear = 1.1
		Global.play_sfx("wave_start", -3.0)


func _alive_enemies() -> int:
	var n: int = 0
	for e in enemies:
		if is_instance_valid(e) and e.alive:
			n += 1
	return n


func enemies_left() -> int:
	return _alive_enemies() + spawn_queue.size()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if msg_clear > 0.0:
		msg_clear -= delta
		if msg_clear <= 0.0:
			_clear_message()
	if ph in ["spawning", "fight", "wave_clear", "level_clear"]:
		level_time += delta if ph in ["spawning", "fight"] else 0.0
	combo_t = maxf(combo_t - delta, 0.0)
	if combo_t <= 0.0 and combo > 0:
		combo = 0

	match ph:
		"intro":
			ph_t -= delta
			if ph_t <= 0.0:
				if intro_stage == 0:
					intro_stage = 1
					ph_t = 1.2
					if boss_level:
						_show_message(String(lvl["name"]), Color("ff4040"), 96)
					else:
						_show_message(String(lvl["name"]), Color("ffffff"), 90)
				else:
					_clear_message()
					hero.controls_enabled = true
					if CampaignData.perk_count(run["perks"], "aegis") > 0:
						hero.apply_powerup("shield")
					_start_wave(start_wave)
		"spawning":
			_update_hazards(delta)
			_update_powerups(delta)
			_regen_ammo(delta)
			_process_spawn_queue(delta)
			if spawn_queue.is_empty():
				ph = "fight"
		"fight":
			_regen_ammo(delta)
			_update_hazards(delta)
			_update_powerups(delta)
			_process_spawn_queue(delta)
			_update_bosses()
			if spawn_queue.is_empty() and _alive_enemies() == 0:
				_wave_cleared()
		"wave_clear":
			_update_hazards(delta)
			ph_t -= delta
			if ph_t <= 0.0:
				_start_wave(wave_i + 1)
		"level_clear":
			pass   # pertunjukan dikendalikan _clear_tick() (waktu nyata) dari _process
		"dead":
			pass   # pertunjukan dikendalikan _defeat_tick() (waktu nyata) dari _process


## Peluru senjata utama pulih pelan-pelan selama bertarung (mode campaign lebih panjang dari versus).
## Interval = ~22 detik / kapasitas, dibatasi 0.8 - 7 detik per peluru.
func _regen_ammo(delta: float) -> void:
	var mx: int = hero.max_ammo()
	if mx < 0 or not hero.alive or hero.knife_only or hero.ammo >= mx:
		ammo_t = 0.0
		return
	ammo_t += delta
	var interval: float = clampf(22.0 / float(mx), 0.8, 7.0)
	if ammo_t >= interval:
		ammo_t = 0.0
		hero.ammo += 1
		hero._sync_weapon(true)
		hero.status_changed.emit(hero)


func _process(delta: float) -> void:
	super._process(delta)
	if ph == "level_clear":
		_clear_tick()
	elif defeat_fx != null and ph in ["dead", "died", "over"]:
		_defeat_tick()
	if slow_until > 0 and Time.get_ticks_msec() >= slow_until:
		slow_until = 0
		if hit_stop_t <= 0.0:
			Engine.time_scale = 1.0
	# warna beku
	for e in enemies:
		if not is_instance_valid(e) or not e.alive or e.brain == null:
			continue
		var fr: float = float((e.brain as AiBrain).frozen)
		if fr > 0.0:
			e.body_sprite.modulate = e.body_sprite.modulate.lerp(Color(0.55, 0.85, 1.25), minf(delta * 12.0, 1.0))
		elif e.body_sprite.modulate.r < 0.99 and e.body_sprite.modulate.r > 0.4:
			e.body_sprite.modulate = e.body_sprite.modulate.lerp(Color.WHITE, minf(delta * 8.0, 1.0))


func slowmo(duration: float, scale: float = 0.3) -> void:
	Engine.time_scale = scale
	slow_until = Time.get_ticks_msec() + int(duration * 1000.0)


# ------------------------------------------------------------------ musuh
func _spawn_point_for(kind: String) -> Vector2:
	var pts: Array[Vector2] = nav.stand_points(hazard_rects, 50.0)
	if pts.is_empty():
		return Vector2(1130, 609)
	var far: Array[Vector2] = []
	var best: Vector2 = pts[0]
	var best_d: float = -1.0
	for p in pts:
		var d: float = p.distance_to(hero.global_position)
		var taken: bool = false
		for e in enemies:
			if is_instance_valid(e) and e.alive and e.global_position.distance_to(p) < 90.0:
				taken = true
		if taken:
			continue
		if d > best_d:
			best_d = d
			best = p
		if d >= 380.0:
			far.append(p)
	if bool((CampaignData.ENEMIES[kind] as Dictionary).get("boss", false)):
		return best
	if far.is_empty():
		return best
	return far[rng.randi() % far.size()]


func _process_spawn_queue(delta: float) -> void:
	if spawn_queue.is_empty():
		return
	spawn_cd -= delta
	if spawn_cd > 0.0:
		return
	var cap: int = 7
	if _alive_enemies() >= cap:
		spawn_cd = 0.3
		return
	var item: Dictionary = spawn_queue.pop_front()
	_spawn_enemy(String(item["kind"]))
	spawn_cd = 0.55


func _spawn_enemy(kind: String) -> Player:
	var st: Dictionary = CampaignData.enemy_stats(kind, level_n)
	var feet: Vector2 = _spawn_point_for(kind)
	var m: float = float(st.get("size", 1.0))
	var e := Player.new()
	players_root.add_child(e)
	e.team = 1
	e.max_hp = float(st["hp"])
	e.dmg_out = float(st["dmg"])
	e.speed_scale = float(st["speed"])
	e.jump_scale = float(st["jump"])
	e.rate_scale = float(st.get("rate", 1.0))
	var chars: Array = st["chars"]
	var ch: int = int(chars[rng.randi() % chars.size()])
	e.setup(int(st["skin"]), ch, String(st["weapon"]), self)
	e.set_size_mult(m)
	e.tag.text = String(st["name"])
	e.tag.add_theme_color_override("font_color", Color("ff5a5a") if not bool(st.get("boss", false)) else Color("ffd23f"))
	var brain := AiBrain.new()
	brain.setup(self, st, rng.randi())
	brain.think_delay = 0.75
	e.brain = brain
	e.reset(feet + Vector2(0, -30.0 * m - 2.0), map["respawn"])
	if bool(st.get("knife_only", false)):
		e.set_knife_only(true)
	e.invuln = 0.9
	e.controls_enabled = true
	if bool(st.get("shield", false)):
		e.shield_hits = Player.SHIELD_HITS
		e.shield_time = 14.0
		e.fx.pop = 1.0
	e.died.connect(_on_player_died)
	var bar := EnemyBar.new()
	bar.p = e
	bar.boss = bool(st.get("boss", false))
	bar.z_index = 3
	e.add_child(bar)
	players.append(e)
	enemies.append(e)
	if bool(st.get("boss", false)):
		boss_state[e] = {"enraged": false, "summons": 0, "stats": st}
	# efek muncul
	var c: Color = Color("ffd23f") if bool(st.get("boss", false)) else Color("ff5a5a")
	UIKit.ring(self, e.global_position, c, 100.0 * m, 0.45)
	UIKit.burst(self, e.global_position, c, 16, 260.0, 6.0, 0.5, 80.0)
	Global.play_sfx("enemy_spawn", -6.0, randf_range(0.92, 1.1))
	return e


func _on_player_died(p: Player) -> void:
	if p == hero:
		_hero_died()
	else:
		_enemy_died(p)


func _enemy_died(e: Player) -> void:
	var st: Dictionary = {}
	if e.brain != null:
		st = (e.brain as AiBrain).stats
	var is_boss: bool = bool(st.get("boss", false))
	kill_total += 1
	combo = combo + 1 if combo_t > 0.0 else 1
	combo_t = 4.0
	var mult: float = 1.0 + 0.25 * float(mini(combo - 1, 8))
	var gain: int = int(float(st.get("score", 100)) * mult)
	_add_score(gain)
	WeaponFx.float_text(self, e.global_position + Vector2(0, -70 * e.size_mult), "+%d" % gain, Color("ffd23f"), 22)
	if combo >= 3:
		WeaponFx.float_text(self, e.global_position + Vector2(0, -100 * e.size_mult), "COMBO x%d" % combo, Color("ff8a3a"), 20)
		Global.play_sfx("combo", -6.0, minf(1.0 + 0.06 * float(combo), 1.6))
	Global.play_sfx("enemy_die", -4.0, randf_range(0.92, 1.08))
	var vamp: int = CampaignData.perk_count(run["perks"], "vampire")
	if vamp > 0 and hero.alive and rng.randf() < 0.15 * float(vamp):
		hero.heal(0.5)
		WeaponFx.float_text(self, hero.global_position + Vector2(0, -74), "LIFE STEAL", Color("c0306a"), 20)
	# jatuhan power up
	var chance: float = 0.16 + 0.07 * float(CampaignData.perk_count(run["perks"], "scavenger"))
	if is_boss:
		_drop_powerup(e.global_position, "")
		_drop_powerup(e.global_position + Vector2(90, 0), "")
		boss_state.erase(e)
		slowmo(0.9, 0.3)
		shake(16.0)
		if camp_hud != null:
			camp_hud.flash = 0.8
		Global.play_sfx("boss_die")
	elif rng.randf() < chance:
		_drop_powerup(e.global_position, "")
	call_deferred("_fade_enemy", e)


func _fade_enemy(e: Player) -> void:
	if not is_instance_valid(e):
		return
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(e, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		enemies.erase(e)
		players.erase(e)
		if is_instance_valid(e):
			e.queue_free())


func _add_score(v: int) -> void:
	score_gain += v
	_check_extra_life()


func _check_extra_life() -> void:
	var nxt: int = int(run.get("next_life", 15000))
	while int(run["score"]) + score_gain >= nxt:
		nxt += 15000
		run["next_life"] = nxt
		if int(run["lives"]) < CampaignData.MAX_LIVES:
			run["lives"] = int(run["lives"]) + 1
			Global.play_sfx("extra_life")
			WeaponFx.float_text(self, hero.global_position + Vector2(0, -110), "1UP!", Color("b36bff"), 30)
			UIKit.ring(self, hero.global_position, Color("b36bff"), 140.0, 0.6)


func _update_bosses() -> void:
	for e in boss_state.keys():
		if not is_instance_valid(e) or not e.alive:
			continue
		var bs: Dictionary = boss_state[e]
		var st: Dictionary = bs["stats"]
		var frac: float = e.hp / maxf(e.max_hp, 0.01)
		var traits: Array = st.get("traits", [])
		if traits.has("enrage") and frac <= 0.5 and not bool(bs["enraged"]):
			bs["enraged"] = true
			e.rate_scale *= 0.72
			e.speed_scale *= 1.14
			e.dmg_out *= 1.1
			UIKit.ring(self, e.global_position, Color("ff3030"), 220.0, 0.6)
			UIKit.burst(self, e.global_position, Color("ff4040"), 30, 420.0, 8.0, 0.8, 100.0)
			WeaponFx.float_text(self, e.global_position + Vector2(0, -120), "ENRAGED!", Color("ff4040"), 30)
			Global.play_sfx("boss_roar")
			shake(9.0)
		if traits.has("summon"):
			var need: int = 0
			if frac <= 0.66:
				need = 1
			if frac <= 0.33:
				need = 2
			if int(bs["summons"]) < need:
				bs["summons"] = int(bs["summons"]) + 1
				var d: float = CampaignData.difficulty(level_n)
				var pool: Array = ["grunt", "rusher"] if d < 0.4 else (["gunner", "hopper"] if d < 0.75 else ["guard", "hopper"])
				for k in 2:
					spawn_queue.append({"kind": pool[k % pool.size()]})
				spawn_cd = 0.2
				ph = "spawning"
				WeaponFx.float_text(self, e.global_position + Vector2(0, -120), "REINFORCEMENTS!", Color("ffd23f"), 24)
				Global.play_sfx("wave_start", -3.0)


# ------------------------------------------------------------------ power up
func _update_powerups(delta: float) -> void:
	powerup_timer -= delta
	if powerup_timer > 0.0:
		return
	var pu: Array = lvl["pu"]
	powerup_timer = rng.randf_range(float(pu[0]), float(pu[1]))
	if powerups_root.get_child_count() < int(lvl["cap"]):
		_spawn_powerup()


func _pick_pu_type() -> String:
	var w := {
		"heal": 3.0 if hero.hp < hero.max_hp - 0.9 else 0.5,
		"shield": 2.0,
		"speed": 2.0,
		"jump": 1.4,
		"invisible": 0.9,
		"ammo_refill": 4.0 if float(hero.ammo) < float(hero.max_ammo()) * 0.5 else 1.6,
		"swap_position": 0.5 if _alive_enemies() > 0 else 0.0,
		"nuke": 1.0 if _alive_enemies() >= 2 else 0.2,
		"freeze": 1.1 if _alive_enemies() >= 2 else 0.2,
	}
	var total: float = 0.0
	for k in w:
		total += float(w[k])
	var r: float = rng.randf() * total
	for k in w:
		r -= float(w[k])
		if r <= 0.0:
			return String(k)
	return "heal"


func _spawn_powerup() -> void:
	var pos: Vector2
	if map.has("powerup_spots"):
		var free: Array[Vector2] = []
		for s in map["powerup_spots"]:
			var sp: Vector2 = s
			var taken := false
			for pu0 in powerups_root.get_children():
				if (pu0 as Node2D).position.distance_to(sp) < 60.0:
					taken = true
			if not taken:
				free.append(sp)
		if free.is_empty():
			return
		pos = free[rng.randi() % free.size()]
	else:
		var rects: Array = []
		rects.append_array(map["platforms"])
		rects.append_array(map["solids"])
		var r: Rect2 = rects[rng.randi() % rects.size()]
		pos = Vector2(rng.randf_range(r.position.x + 40.0, r.end.x - 40.0), r.position.y - 34.0)
	_make_powerup(_pick_pu_type(), pos)
	Global.play_sfx("pu_spawn", -10.0)


func _make_powerup(type: String, pos: Vector2) -> void:
	var pu := Powerup.new()
	pu.setup(type)
	pu.human_only = true
	pu.position = pos
	powerups_root.add_child(pu)


## Jatuhkan power up di titik aman terdekat dari posisi (type "" = acak sesuai kebutuhan pemain).
func _drop_powerup(from: Vector2, type: String) -> void:
	if drop_points.is_empty():
		return
	var best: Vector2 = drop_points[0]
	var bd: float = 1e12
	for p in drop_points:
		var d: float = p.distance_to(from)
		var occupied: bool = false
		for pu0 in powerups_root.get_children():
			if (pu0 as Node2D).position.distance_to(p + Vector2(0, -34)) < 60.0:
				occupied = true
		if not occupied and d < bd:
			bd = d
			best = p
	var t: String = type if type != "" else _pick_pu_type()
	call_deferred("_make_powerup", t, best + Vector2(0, -34))     # dibuat setelah callback fisika selesai
	UIKit.ring(self, best + Vector2(0, -34), Player.pu_color(t), 70.0, 0.4)
	Global.play_sfx("pu_spawn", -8.0)


## Efek power up khusus campaign (dipanggil Player.apply_powerup).
func campaign_powerup(p: Player, type: String) -> void:
	match type:
		"nuke":
			Global.play_sfx("nuke")
			if camp_hud != null:
				camp_hud.flash = 1.0
			shake(15.0)
			UIKit.ring(self, p.global_position, Color("ff6a2a"), 700.0, 0.6)
			for e in enemies.duplicate():
				if is_instance_valid(e) and e.alive:
					var dir: int = 1 if e.global_position.x >= p.global_position.x else -1
					UIKit.burst(self, e.global_position, Color("ff8a3a"), 20, 400.0, 8.0, 0.7)
					e.take_damage(2.2, dir, true, true)
			WeaponFx.float_text(self, p.global_position + Vector2(0, -100), "BOOM!", Color("ff6a2a"), 30)
		"freeze":
			Global.play_sfx("freeze")
			UIKit.ring(self, p.global_position, Color("8fe8ff"), 700.0, 0.7)
			for e in enemies:
				if is_instance_valid(e) and e.alive and e.brain != null:
					(e.brain as AiBrain).frozen = 4.5
					UIKit.burst(self, e.global_position, Color("bff3ff"), 14, 220.0, 6.0, 0.6, 100.0)
			WeaponFx.float_text(self, p.global_position + Vector2(0, -100), "FREEZE!", Color("8fe8ff"), 30)


# ------------------------------------------------------------------ hasil wave & level
func _on_hero_status(p: Player) -> void:
	if p.hp < last_hp:
		dmg_taken += last_hp - p.hp
	last_hp = p.hp


func _wave_cleared() -> void:
	if wave_i + 1 >= _total_waves():
		_level_cleared()
		return
	ph = "wave_clear"
	ph_t = 2.2
	_show_message("WAVE CLEAR!", Color("4be3a0"), 90)
	msg_clear = 1.6
	Global.play_sfx("wave_clear")
	for c in bullets_root.get_children():
		c.queue_free()
	if hero.alive:
		hero._refill_ammo()
		hero.heal(0.5)
		WeaponFx.float_text(self, hero.global_position + Vector2(0, -100), "+1/2 HEART", Color("4be3a0"), 22)
	_drop_powerup(hero.global_position + Vector2(rng.randf_range(-200, 200), 0), "")


func _level_cleared() -> void:
	ph = "level_clear"
	run.erase("resume")
	ph_t = 99.0
	hero.controls_enabled = false
	hero.invuln = 99.0
	hero.modulate.a = 1.0
	for c in bullets_root.get_children():
		c.queue_free()
	for c in powerups_root.get_children():
		c.queue_free()

	var par: float = 25.0 * float(_total_waves()) + (50.0 if boss_level else 0.0)
	var time_bonus: int = maxi(int((par - level_time)) * 10, 0)
	var flawless: bool = dmg_taken <= 0.001
	var flaw_bonus: int = 1000 if flawless else 0
	_add_score(time_bonus + flaw_bonus)
	var stars: int = 1
	if dmg_taken <= 4.0:
		stars = 2
	if dmg_taken <= 1.5 and died_here == 0:
		stars = 3
	var total: int = int(run["score"]) + score_gain
	# rekor lama (untuk label NEW RECORD) dibaca sebelum hasil baru disimpan
	var old: Dictionary = CampaignData.load_save()
	prev_best = int((old["best"] as Dictionary).get(level_n, 0))
	prev_stars = int((old["stars"] as Dictionary).get(level_n, 0))
	tally_data = {"time_bonus": time_bonus, "flawless": flaw_bonus, "stars": stars, "gain": score_gain, "total": total,
		"from": int(run["score"]), "record": prev_best > 0 and score_gain > prev_best, "first": prev_stars == 0}
	CampaignData.record_result(level_n, stars, score_gain, total, CampaignData.grade_rank(stars, flawless))
	# koin Shop: pertama kali = penuh sesuai bintang, main ulang = jauh lebih sedikit (lihat Cosmetics.award_level)
	var reward: Dictionary = Cosmetics.award_level(level_n, stars, boss_level)
	tally_data["coins"] = int(reward["coins"])
	tally_data["coin_first"] = bool(reward["first"])
	tally_data["coin_improved"] = bool(reward["improved"])
	_start_clear_show()


# ------------------------------------------------------------------ pertunjukan LEVEL CLEAR
func w2s(p: Vector2) -> Vector2:
	return (p - cam.position) * cam.zoom.x


func _additive() -> CanvasItemMaterial:
	return Fx.additive()


func _start_clear_show() -> void:
	_clear_message()
	clear_t = 0.0
	clear_dt = 0.0
	clear_us = Time.get_ticks_usec()
	clear_open = false
	clear_open_t = CLEAR_OPEN_T_BOSS if boss_level else CLEAR_OPEN_T
	clear_fw_next = 0.6
	clear_fw_count = 0
	clear_fw_max = 12 if boss_level else 6
	clear_hop_next = 0.55
	clear_zoom = 1.0
	clear_focus = hero.global_position
	slowmo(0.7, 0.28)
	shake(18.0)

	# HUD memudar supaya layar bersih (sinematik)
	if hud_root != null:
		UIKit.tw(hud_root).tween_property(hud_root, "modulate:a", 0.0, 0.4)

	clear_layer = CanvasLayer.new()
	clear_layer.layer = 15
	clear_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(clear_layer)
	clear_fx = ClearFx.new()
	clear_fx.g = self
	clear_fx.boss = boss_level
	clear_fx.flawless = bool(tally_data["flawless"] > 0)
	clear_fx.sub_text = "%s  -  %s" % [CampaignData.level_text(level_n), String(lvl["name"])]
	clear_fx.open_t = clear_open_t
	clear_layer.add_child(clear_fx)

	# ---- dampak pertama: ledakan di pahlawan
	var hp: Vector2 = hero.global_position
	clear_fx.add_ring(w2s(hp), Color("4be3a0"), 900.0, 0.9, 22.0, 0.0)
	clear_fx.add_ring(w2s(hp), Color("ffd23f"), 700.0, 0.8, 16.0, 0.1)
	clear_fx.add_ring(w2s(hp), Color.WHITE, 500.0, 0.7, 12.0, 0.2)
	clear_fx.add_flash(w2s(hp), Color("fff3a0"), 700.0)
	_glow_burst(hp, Color("4be3a0"), 70, 620.0, 0.55, 1.1, 300.0, 140.0)
	_glow_burst(hp, Color("ffd23f"), 50, 460.0, 0.45, 1.0, 300.0, 120.0)
	UIKit.ring(self, hp, Color("4be3a0"), 260.0, 0.7)

	# ---- suara berlapis
	Global.play_sfx("level_clear", -1.0)
	if not Global.play_synth("clear_boom", -2.0):
		Global.play_sfx("nuke", -6.0)
	if not Global.play_synth("clear_fanfare", -5.0, 1.0, "Celebrate"):
		Global.play_sfx("match_fanfare", -4.0, 1.0, "Celebrate")
	if boss_level:
		Global.play_sfx("won", -8.0)

	# ---- jadwal kejadian berikutnya
	clear_events.clear()
	_ev(0.08, "cannons")
	_ev(0.30, "shimmer")
	_ev(0.45, "applause")
	_ev(0.90, "rain")
	_ev(0.95, "subtitle")
	for i in "LEVEL CLEAR!".length():
		_ev(0.38 + 0.055 * float(i), "tick", i)
	if boss_level:
		_ev(1.45, "boss_tag")
	if clear_fx.flawless:
		_ev(1.85, "flawless")
		clear_fx.stamp_t = 1.85
	if boss_level:
		clear_fx.boss_t = 1.45


func _ev(t: float, id: String, arg: int = 0) -> void:
	clear_events.append({"t": t, "id": id, "arg": arg, "done": false})


func _run_clear_event(e: Dictionary) -> void:
	var hp: Vector2 = hero.global_position
	match String(e["id"]):
		"cannons":
			_confetti_cannon(Vector2(30, 740), Vector2(0.55, -1.0))
			_confetti_cannon(Vector2(1250, 740), Vector2(-0.55, -1.0))
			Global.play_synth("pop", -8.0, 1.25, "Celebrate")
			Global.play_synth("pop", -8.0, 1.0, "Celebrate")
			shake(8.0)
		"shimmer":
			if not Global.play_synth("shimmer", -9.0, 1.0, "Celebrate"):
				Global.play_sfx("win_pip", -8.0)
		"applause":
			Global.play_synth("applause", -11.0, 1.0, "Celebrate")
		"rain":
			_confetti_rain(clear_open_t - 0.5)
		"subtitle":
			Global.play_sfx("ui_whoosh", -8.0, 1.25)
		"tick":
			Global.play_sfx("score_tick", -9.0, 0.85 + 0.05 * float(int(e["arg"])))
		"boss_tag":
			Global.play_synth("stab", -5.0, 0.8, "Celebrate")
			Global.play_sfx("boss_roar", -9.0, 1.1)
			shake(14.0)
			clear_fx.add_ring(Vector2(640, 322), Color("ff4040"), 800.0, 0.8, 20.0, 0.0)
			clear_fx.add_flash(Vector2(640, 470), Color("ff6a4a"), 600.0)
		"flawless":
			Global.play_synth("stab", -6.0, 1.25, "Celebrate")
			Global.play_sfx("wall_impact", -2.0, 0.7)
			shake(11.0)
			clear_fx.add_ring(Vector2(1070, 226), Color("ffd23f"), 520.0, 0.7, 16.0, 0.0)
			clear_fx.add_flash(Vector2(1070, 226), Color("fff3a0"), 520.0)
			clear_fx.add_sparks(Vector2(1070, 226), Color("ffd23f"), 26, 420.0)
	e["done"] = true


func _clear_tick() -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = clampf(float(now - clear_us) / 1000000.0, 0.0, 0.1)
	clear_us = now
	if get_tree().paused:
		clear_dt = 0.0
		return
	clear_dt = dt
	clear_t += dt

	for e in clear_events:
		if not bool(e["done"]) and clear_t >= float(e["t"]):
			_run_clear_event(e)

	# zoom kamera: hentakan masuk lalu pelan-pelan, kembali normal saat panel hasil terbuka
	var z: float = 1.0
	if not clear_open:
		var punch: float = Fx.ease_out(clampf(clear_t / 0.14, 0.0, 1.0))
		z = 1.0 + 0.16 * punch - 0.09 * clampf((clear_t - 0.14) / 3.0, 0.0, 1.0)
	else:
		z = lerpf(clear_zoom, 1.0, clampf((clear_t - clear_open_t) / 0.6, 0.0, 1.0))
	clear_zoom = z
	var f: Vector2 = Vector2(clampf(hero.global_position.x, 0.0, 1280.0), clampf(hero.global_position.y, 0.0, 720.0))
	cam.zoom = Vector2.ONE * z
	cam.position = f - f / z   # zoom berpusat di pahlawan, tepi layar tetap terjaga

	# kembang api
	if clear_fw_count < clear_fw_max and clear_t >= clear_fw_next:
		_launch_firework()
		clear_fw_count += 1
		clear_fw_next = clear_t + (rng.randf_range(0.28, 0.5) if clear_fw_count < 5 else rng.randf_range(0.55, 0.9))
	# pahlawan melompat-lompat girang
	if clear_t >= clear_hop_next and clear_t < clear_open_t + 1.5 and hero.alive:
		clear_hop_next = clear_t + 0.78
		if hero.is_on_floor():
			hero.velocity.y = -560.0
			hero._squash(Vector2(0.72, 1.35))
			Global.play_sfx("jump", -9.0, rng.randf_range(1.15, 1.35))
			clear_fx.add_sparks(w2s(hero.global_position + Vector2(0, 28)), Color("ffd23f"), 10, 240.0)
			_glow_burst(hero.global_position + Vector2(0, 28), Color("ffe680"), 14, 260.0, 0.3, 0.6, 500.0, 60.0)

	if not clear_open and clear_t >= clear_open_t:
		clear_open = true
		_open_tally()


func _skip_clear_show() -> void:
	if clear_open or clear_t < 1.0:
		return
	clear_t = maxf(clear_t, clear_open_t)


func _launch_firework() -> void:
	var cols: Array = [Color("4be3a0"), Color("ffd23f"), Color("ff5fa2"), Color("4fd8ff"), Color("ff8a3a"), Color("b36bff"), Color("ffffff")]
	var col: Color = cols[rng.randi() % cols.size()]
	var target: Vector2
	if clear_fw_count % 2 == 0:
		target = Vector2(rng.randf_range(110.0, 1170.0), rng.randf_range(90.0, 200.0))
	else:
		var side: float = -1.0 if rng.randf() < 0.5 else 1.0
		target = Vector2(640.0 + side * rng.randf_range(430.0, 570.0), rng.randf_range(150.0, 400.0))
	var r := FwRocket.new()
	r.g = self
	r.from = Vector2(clampf(target.x + rng.randf_range(-80.0, 80.0), 40.0, 1240.0), 740.0)
	r.to = target
	r.col = col
	r.dur = rng.randf_range(0.5, 0.7)
	r.z_index = 54
	add_child(r)
	Global.play_synth("whistle", -14.0, rng.randf_range(0.9, 1.2), "Celebrate")


func firework_burst(pos: Vector2, col: Color) -> void:
	Global.play_synth("pop", -7.0, rng.randf_range(0.85, 1.25), "Celebrate")
	_glow_burst(pos, col, 80, 460.0, 0.42, 1.5, 130.0, 170.0)
	_glow_burst(pos, Color.WHITE.lerp(col, 0.4), 36, 250.0, 0.32, 1.1, 110.0, 150.0)
	_glow_burst(pos, Color("fff3a0"), 14, 120.0, 0.5, 0.8, 0.0, 120.0)
	UIKit.ring(self, pos, col, 190.0, 0.55)
	shake(2.2)
	if clear_fx != null:
		clear_fx.add_flash(w2s(pos), col, 520.0)
		clear_fx.add_sparks(w2s(pos), col, 10, 300.0)
	# percikan kedua (berderak) sedikit terlambat
	get_tree().create_timer(0.32).timeout.connect(func() -> void:
		if is_inside_tree():
			_glow_burst(pos + Vector2(rng.randf_range(-30, 30), rng.randf_range(-20, 40)), col.lightened(0.3), 26, 200.0, 0.24, 0.9, 200.0, 130.0))


## Ledakan partikel bercahaya (tekstur radial + blend additive) -> lebih halus daripada kotak piksel.
func _glow_burst(pos: Vector2, col: Color, count: int, speed: float, psize: float, life: float, grav: float = 140.0, damp: float = 120.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.25
	p.initial_velocity_max = speed
	p.damping_min = damp * 0.7
	p.damping_max = damp
	p.gravity = Vector2(0, grav)
	p.scale_amount_min = psize * 0.5
	p.scale_amount_max = psize
	p.texture = Fx.glow()
	p.material = Fx.additive()
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	gr.colors = PackedColorArray([Color(1, 1, 1, 1), col, Color(col, 0.0)])
	p.color_ramp = gr
	p.z_index = 55
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


func _confetti_cannon(pos: Vector2, dir: Vector2) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = 90
	p.lifetime = 2.8
	p.explosiveness = 0.95
	p.direction = dir.normalized()
	p.spread = 24.0
	p.initial_velocity_min = 650.0
	p.initial_velocity_max = 1250.0
	p.damping_min = 90.0
	p.damping_max = 190.0
	p.gravity = Vector2(0, 760)
	p.angular_velocity_min = -700.0
	p.angular_velocity_max = 700.0
	p.scale_amount_min = 5.0
	p.scale_amount_max = 11.0
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 1.0])
	gr.colors = PackedColorArray([Color("ffd23f"), Color("4be3a0"), Color("ff5fa2"), Color("4fd8ff"), Color("ffffff"), Color("ff8a3a")])
	p.color_initial_ramp = gr
	p.z_index = 56
	add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Hujan confetti dari atas layar selama durasi tertentu (lalu berhenti sendiri).
func _confetti_rain(dur: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 14
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var conf := CPUParticles2D.new()
	conf.position = Vector2(640, -20)
	conf.amount = 110
	conf.lifetime = 3.2
	conf.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	conf.emission_rect_extents = Vector2(680, 4)
	conf.direction = Vector2(0, 1)
	conf.spread = 14.0
	conf.initial_velocity_min = 140.0
	conf.initial_velocity_max = 300.0
	conf.gravity = Vector2(0, 140)
	conf.angular_velocity_min = -300.0
	conf.angular_velocity_max = 300.0
	conf.scale_amount_min = 5.0
	conf.scale_amount_max = 10.0
	var gr := Gradient.new()
	gr.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	gr.colors = PackedColorArray([Color("ffd23f"), Color("4be3a0"), Color("ff5fa2"), Color("4fd8ff"), Color("ffffff")])
	conf.color_initial_ramp = gr
	layer.add_child(conf)
	get_tree().create_timer(maxf(dur, 0.5)).timeout.connect(func() -> void:
		if is_instance_valid(conf):
			conf.emitting = false)
	get_tree().create_timer(maxf(dur, 0.5) + 4.0).timeout.connect(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free())


func _stop_clear_show() -> void:
	clear_fw_max = 0
	clear_events.clear()
	if is_instance_valid(clear_fx):
		var fx: Control = clear_fx
		var tw := UIKit.tw(fx)
		tw.tween_property(fx, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func() -> void:
			if is_instance_valid(clear_layer):
				clear_layer.queue_free())


func _hero_died() -> void:
	if ph in ["level_clear", "tally", "perk", "complete"]:
		return
	var prev_ph: String = ph
	ph = "dead"
	run["lives"] = int(run["lives"]) - 1
	died_here += 1
	# Masih punya nyawa -> level dilanjutkan dari wave tempat mati (tidak mengulang wave 1).
	# Nyawa habis -> tidak ada yang disimpan: kembali ke checkpoint dan mulai dari wave 1.
	if int(run["lives"]) > 0:
		var w: int = maxi(wave_i, 0)
		if prev_ph == "wave_clear":
			w = mini(wave_i + 1, _total_waves() - 1)
		run["resume"] = {"level": level_n, "wave": w}
	else:
		run.erase("resume")
	for e in enemies:
		if is_instance_valid(e):
			e.controls_enabled = false
	combo = 0
	CampaignData.save_run(run)
	_start_defeat_show()


# ------------------------------------------------------------------ pertunjukan KEKALAHAN
func _dv(t: float, id: String, arg: int = 0) -> void:
	defeat_events.append({"t": t, "id": id, "arg": arg, "done": false})


func _start_defeat_show() -> void:
	_clear_message()
	defeat_t = 0.0
	defeat_dt = 0.0
	defeat_us = Time.get_ticks_usec()
	defeat_open = false
	defeat_zoom = 1.0
	defeat_zoom_open = 1.0
	var left: int = maxi(int(run["lives"]), 0)
	defeat_over = left <= 0
	defeat_lives_before = clampi(left + 1, 1, CampaignData.MAX_LIVES)
	defeat_slots = clampi(maxi(defeat_lives_before, 3), 3, CampaignData.MAX_LIVES)
	var hearts_t0: float = 1.5
	var brk: float = hearts_t0 + 0.12 * float(defeat_lives_before) + 0.55
	defeat_open_t = brk + (1.6 if defeat_over else 1.25)
	defeat_focus = Vector2(clampf(hero.global_position.x, 90.0, 1190.0), clampf(hero.global_position.y, 150.0, 610.0))
	slow_until = 0
	shake(18.0)

	defeat_layer = CanvasLayer.new()
	defeat_layer.layer = 15
	defeat_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(defeat_layer)

	# lapisan hitam-putih (membaca layar di bawahnya)
	defeat_gray = ColorRect.new()
	defeat_gray.color = Color.WHITE
	defeat_gray.set_anchors_preset(Control.PRESET_FULL_RECT)
	defeat_gray.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = DEFEAT_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("amount", 0.0)
	defeat_gray.material = mat
	defeat_layer.add_child(defeat_gray)

	defeat_fx = DefeatFx.new()
	defeat_fx.g = self
	defeat_fx.over = defeat_over
	defeat_fx.lives_before = defeat_lives_before
	defeat_fx.slots = defeat_slots
	defeat_fx.lives_left = left
	defeat_fx.open_t = defeat_open_t
	defeat_fx.hearts_t0 = hearts_t0
	defeat_fx.brk_t = brk
	defeat_fx.focus = defeat_focus
	defeat_fx.sub_text = "%s  -  %s" % [CampaignData.level_text(level_n), String(lvl["name"])]
	defeat_layer.add_child(defeat_fx)

	# ---- jadwal kejadian
	defeat_events.clear()
	_dv(0.0, "impact")
	_dv(0.12, "crack")
	var title: String = "GAME OVER" if defeat_over else "YOU DIED"
	for i in title.length():
		if title[i] != " ":
			_dv(0.3 + 0.07 * float(i) + 0.38, "land", i)
	_dv(0.55, "voice")
	_dv(1.15, "ribbon")
	for i in defeat_lives_before:
		_dv(hearts_t0 + 0.12 * float(i), "heart", i)
	_dv(brk - 0.4, "tremble")
	_dv(brk, "break")
	if defeat_over:
		_dv(brk + 0.55, "stamp")
	else:
		_dv(brk + 0.3, "lives_text")


func _run_defeat_event(e: Dictionary) -> void:
	var fx: DefeatFx = defeat_fx
	match String(e["id"]):
		"impact":
			Global.play_sfx("hero_down", -1.0)
			Global.play_sfx("wall_impact", -2.0, 0.55)
			fx.add_ring(defeat_focus, Color("ff3b30"), 900.0, 0.9, 22.0, 0.0)
			fx.add_ring(defeat_focus, Color("ff8a3a"), 650.0, 0.8, 14.0, 0.08)
			fx.add_ring(defeat_focus, Color.WHITE, 420.0, 0.6, 10.0, 0.16)
			fx.add_flash(defeat_focus, Color("ff5a40"), 760.0)
			fx.add_sparks(defeat_focus, Color("ff3b30"), 46, 640.0)
			fx.add_sparks(defeat_focus, Color("ffb060"), 30, 420.0)
			UIKit.ring(self, hero.global_position, Color("ff3b30"), 220.0, 0.6)
		"crack":
			Global.play_sfx("shield_break", -3.0, 0.7)
			fx.start_cracks()
			shake(9.0)
		"land":
			fx.letter_land(int(e["arg"]))
		"voice":
			if defeat_over:
				Global.play_sfx("game_over", -2.0)
			else:
				Global.play_sfx("ui_error", -6.0, 0.7)
		"ribbon":
			Global.play_sfx("ui_whoosh", -8.0, 0.8)
		"heart":
			Global.play_sfx("ui_hover", -7.0, 0.8 + 0.08 * float(int(e["arg"])))
		"tremble":
			Global.play_sfx("crumble_warn", -9.0, 1.2)
		"break":
			Global.play_sfx("shield_break", -2.0, 0.8)
			Global.play_sfx("dead", -8.0, 0.9)
			shake(14.0)
			fx.heart_break()
		"lives_text":
			Global.play_sfx("ui_whoosh", -7.0, 1.0)
			fx.lives_t = fx.t
		"stamp":
			Global.play_sfx("wall_impact", -1.0, 0.7)
			shake(16.0)
			fx.stamp_t = fx.t
			fx.add_ring(Vector2(640, 590), Color("ff3b30"), 520.0, 0.7, 16.0, 0.0)
			fx.add_flash(Vector2(640, 590), Color("ff6a4a"), 560.0)
			fx.add_sparks(Vector2(640, 590), Color("ff3b30"), 30, 460.0)
	e["done"] = true


func _defeat_tick() -> void:
	var now: int = Time.get_ticks_usec()
	var dt: float = clampf(float(now - defeat_us) / 1000000.0, 0.0, 0.1)
	defeat_us = now
	if get_tree().paused:
		defeat_dt = 0.0
		return
	defeat_dt = dt
	defeat_t += dt

	for e in defeat_events:
		if not bool(e["done"]) and defeat_t >= float(e["t"]):
			_run_defeat_event(e)

	# slow-motion di awal, lalu pelan-pelan kembali normal
	if hit_stop_t <= 0.0:
		Engine.time_scale = 1.0 if defeat_open else lerpf(0.22, 1.0, smoothstep(0.4, 1.9, defeat_t))

	# HUD memudar, layar menjadi hitam-putih
	if hud_root != null:
		hud_root.modulate.a = 1.0 - smoothstep(0.0, 0.5, defeat_t)
	if defeat_gray != null:
		(defeat_gray.material as ShaderMaterial).set_shader_parameter("amount", 0.92 * smoothstep(0.0, 0.9, defeat_t))

	# musik melambat & meredam (seperti kaset diperlambat), pulih saat menu pilihan terbuka
	var mus: AudioStreamPlayer = Global._music
	if mus != null and ph != "over":
		var k: float = smoothstep(0.0, 1.2, defeat_t)
		if defeat_open:
			k = 1.0 - smoothstep(0.0, 0.8, defeat_t - defeat_open_t)
		mus.pitch_scale = lerpf(1.0, 0.6, k)
		mus.volume_db = lerpf(0.0, -9.0, k)

	# kamera: hentakan masuk, lalu zoom perlahan ke pahlawan; kembali normal saat menu terbuka
	var z: float = 1.0
	if not defeat_open:
		z = 1.0 + 0.12 * Fx.ease_out(clampf(defeat_t / 0.16, 0.0, 1.0)) + 0.07 * smoothstep(0.16, defeat_open_t, defeat_t)
		defeat_zoom_open = z
	else:
		z = lerpf(defeat_zoom_open, 1.0, smoothstep(0.0, 1.0, (defeat_t - defeat_open_t) / 0.7))
	defeat_zoom = z
	cam.zoom = Vector2.ONE * z
	cam.position = defeat_focus - defeat_focus / z

	if not defeat_open and defeat_t >= defeat_open_t:
		defeat_open = true
		if hit_stop_t <= 0.0:
			Engine.time_scale = 1.0
		if defeat_over:
			_open_game_over()
		else:
			_open_died_menu()


func _skip_defeat_show() -> void:
	if defeat_open or defeat_t < 1.6:
		return
	for ev in defeat_events:
		ev["done"] = true   # lewati tanpa memutar semua suara sekaligus
	defeat_t = maxf(defeat_t, defeat_open_t)


func _retry_level() -> void:
	if _quitting:
		return
	_quitting = true
	CampaignData.save_run(run)
	Global.goto("campaign")


# ------------------------------------------------------------------ panel
func _close_panel() -> void:
	if panel != null:
		panel.queue_free()
		panel = null


func _open_tally() -> void:
	ph = "tally"
	_clear_message()
	_close_panel()
	var t := TallyPanel.new()
	t.g = self
	t.level_text = "%s  -  %s" % [CampaignData.level_text(level_n), String(lvl["name"])]
	var flaw: int = int(tally_data["flawless"])
	t.rows = [
		{"label": "KILLS", "kind": "int", "val": float(kill_total), "col": Color.WHITE},
		{"label": "TIME", "kind": "time", "val": level_time, "col": Color.WHITE},
		{"label": "DAMAGE TAKEN", "kind": "dmg", "val": dmg_taken, "col": Color.WHITE},
		{"label": "TIME BONUS", "kind": "plus", "val": float(tally_data["time_bonus"]), "col": Color("4be3a0")},
		{"label": "FLAWLESS", "kind": "plus" if flaw > 0 else "text", "val": float(flaw), "text": "-", "col": Color("ffd23f")},
		{"label": "LEVEL SCORE", "kind": "int", "val": float(tally_data["gain"]), "col": Color("4fd8ff"), "hi": true},
		{"label": "COINS" if bool(tally_data.get("coin_first", true)) else "COINS (REPLAY)", "kind": "plus", "val": float(tally_data.get("coins", 0)), "col": Color("ffcd3c")},
	]
	t.stars = int(tally_data["stars"])
	t.total_from = int(tally_data["from"])
	t.total_to = int(tally_data["total"])
	t.new_record = bool(tally_data["record"])
	t.first_clear = bool(tally_data["first"])
	t.boss = boss_level
	t.flawless = flaw > 0
	match t.stars:
		3: t.grade = "S" if flaw > 0 else "A"
		2: t.grade = "B"
		_: t.grade = "C"
	t.finished.connect(_after_tally)
	t.chosen.connect(_on_tally_choice)
	panel_layer.add_child(t)
	panel = t


func _after_tally() -> void:
	run["score"] = int(tally_data["total"])
	_close_panel()
	_stop_clear_show()
	if level_n >= CampaignData.TOTAL_LEVELS:
		_open_complete()
		return
	var count: int = 4 if boss_level else 3
	var ids: Array[String] = CampaignData.roll_perks(run["perks"], rng, count)
	if ids.is_empty():
		_finish_level()
		return
	_open_perk(ids)


func _open_perk(ids: Array[String]) -> void:
	ph = "perk"
	var pk := PerkPicker.new()
	pk.ids = ids
	pk.perks = run["perks"]
	pk.bonus_text = "BOSS DEFEATED" if boss_level else ""
	pk.picked.connect(_on_perk_picked)
	panel_layer.add_child(pk)
	panel = pk
	Global.play_sfx("perk_open")


## Pilihan di panel LEVEL CLEAR selain CONTINUE: kembali ke LEVEL MAP (id "map") atau MAIN MENU (id "menu").
## Hasil level sudah tersimpan (bintang & skor terbaik); progres run dimajukan ke level berikutnya
## supaya tombol CONTINUE di level map melanjutkan dari level setelah ini.
## Pemain tetap memilih PERK dulu (sama seperti CONTINUE) sebelum keluar; kalau tidak ada perk tersisa langsung keluar.
func _on_tally_choice(id: String) -> void:
	if _quitting or _exit_dest != "":
		return
	run["score"] = int(tally_data["total"])
	if level_n >= CampaignData.TOTAL_LEVELS:
		_quitting = true
		CampaignData.clear_run()
		_stop_clear_show()
		Global.play_music("menu")
		Global.goto("campaign_hub" if id == "map" else "menu")
		return
	var count: int = 4 if boss_level else 3
	var ids: Array[String] = CampaignData.roll_perks(run["perks"], rng, count)
	if ids.is_empty():
		_leave_to(id, true)
		return
	_exit_dest = id
	_close_panel()
	_stop_clear_show()
	_open_perk(ids)


## Simpan progres run (level berikutnya) lalu keluar ke LEVEL MAP / MAIN MENU.
func _leave_to(id: String, give_boss_life: bool) -> void:
	if _quitting:
		return
	_quitting = true
	run["score"] = int(tally_data["total"])
	run["level"] = level_n + 1
	CampaignData.save_run(run)
	_stop_clear_show()
	Global.play_music("menu")
	Global.goto("campaign_hub" if id == "map" else "menu")


func _on_perk_picked(id: String) -> void:
	var pk: Dictionary = run["perks"]
	pk[id] = int(pk.get(id, 0)) + 1
	Global.play_sfx("perk_pick")
	if _exit_dest != "":
		_leave_to(_exit_dest, false)       # keluar lewat LEVEL MAP / MAIN MENU: perk sudah dipilih
		return
	_finish_level()


func _finish_level() -> void:
	if _quitting:
		return
	_quitting = true
	run["level"] = level_n + 1
	CampaignData.save_run(run)
	await get_tree().create_timer(0.45).timeout
	Global.goto("campaign")


## Pemain mati tapi masih punya nyawa: jangan langsung mengulang level. Tampilkan menu pilihan dulu.
## (Nyawa sudah dikurangi & run sudah disimpan di _hero_died, jadi LEVEL MAP / MAIN MENU melanjutkan dari level ini.)
func _open_died_menu() -> void:
	ph = "died"
	_clear_message()
	var c := ChoicePanel.new()
	c.defeat = true
	c.title = "YOU DIED"
	c.plate = Color("ff4040")
	var left: int = maxi(int(run["lives"]), 0)
	var rw: int = int((run.get("resume", {}) as Dictionary).get("wave", 0))
	c.lines = [["LIVES LEFT  %d" % left, Color("ff8a8a")],
		["%s  -  %s" % [CampaignData.level_text(level_n), String(lvl["name"])], Color(1, 1, 1, 0.7)]]
	if _total_waves() > 1:
		c.lines.append(["CONTINUE FROM WAVE %d / %d" % [rw + 1, _total_waves()], Color("ffd23f")])
	c.buttons = [["restart", "RETRY  -  WAVE %d" % (rw + 1) if _total_waves() > 1 else "RESTART LEVEL"], ["map", "LEVEL MAP"], ["menu", "MAIN MENU"]]
	c.chosen.connect(_on_choice)
	panel_layer.add_child(c)
	panel = c
	Global.play_sfx("ui_panel")


func _open_game_over() -> void:
	ph = "over"
	_clear_message()
	var c := ChoicePanel.new()
	c.defeat = true
	c.title = "GAME OVER"
	c.plate = Color("ff4040")
	c.lines = [["SCORE  %d" % (int(run["score"]) + score_gain), Color.WHITE],
		["%s  -  %s" % [CampaignData.level_text(level_n), String(lvl["name"])], Color(1, 1, 1, 0.7)]]
	c.buttons = [["restart", "RESTART LEVEL %d" % CampaignData.local_n(level_n)], ["map", "LEVEL MAP"], ["menu", "MAIN MENU"]]
	c.chosen.connect(_on_choice)
	panel_layer.add_child(c)
	panel = c
	Global.play_sfx("ui_panel")
	_music_reset()
	Global.play_music("menu")


func _open_complete() -> void:
	ph = "complete"
	_close_panel()
	var data: Dictionary = CampaignData.load_save()
	var c := ChoicePanel.new()
	c.title = "CAMPAIGN COMPLETE!"
	c.plate = Color("ffd23f")
	c.lines = [["FINAL SCORE  %d" % int(run["score"]), Color("ffd23f")],
		["TOTAL STARS  %d / %d" % [CampaignData.total_stars(data), CampaignData.TOTAL_LEVELS * 3], Color.WHITE],
		["THE OMEGA CORE IS DESTROYED. THE ARENA IS YOURS.", Color(1, 1, 1, 0.75)]]
	c.buttons = [["map", "LEVEL MAP"], ["menu", "MAIN MENU"]]
	c.chosen.connect(_on_choice)
	panel_layer.add_child(c)
	panel = c
	CampaignData.clear_run()
	Global.play_sfx("match_fanfare")
	Global.play_sfx("won", -4.0)
	_confetti()


func _on_choice(id: String) -> void:
	if _quitting:
		return
	match id:
		"restart":
			_retry_level()
		"continue":
			_quitting = true
			CampaignData.restore_checkpoint(run)
			CampaignData.save_run(run)
			Global.goto("campaign")
		"map":
			_quitting = true
			CampaignData.save_run(run)
			Global.play_music("menu")
			Global.goto("campaign_hub")
		"menu":
			_quitting = true
			CampaignData.save_run(run)
			Global.play_music("menu")
			Global.goto("menu")


func _confetti() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 21
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	var conf := CPUParticles2D.new()
	conf.position = Vector2(640, -20)
	conf.amount = 90
	conf.lifetime = 3.4
	conf.preprocess = 0.5
	conf.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	conf.emission_rect_extents = Vector2(660, 4)
	conf.direction = Vector2(0, 1)
	conf.spread = 12.0
	conf.initial_velocity_min = 120.0
	conf.initial_velocity_max = 260.0
	conf.gravity = Vector2(0, 120)
	conf.angular_velocity_min = -240.0
	conf.angular_velocity_max = 240.0
	conf.scale_amount_min = 5.0
	conf.scale_amount_max = 10.0
	var gr := Gradient.new()
	gr.set_color(0, Color("ffd23f"))
	gr.add_point(0.5, Color("4be3a0"))
	gr.set_color(1, Color.WHITE)
	conf.color_initial_ramp = gr
	layer.add_child(conf)


func _on_camp_input(_source: int, action: StringName) -> void:
	if get_tree().paused:
		return
	if ph == "level_clear" and (action == &"accept" or action == &"fire"):
		_skip_clear_show()   # lewati sinematik -> langsung ke hasil
		return
	if ph == "dead" and defeat_fx != null and (action == &"accept" or action == &"fire"):
		_skip_defeat_show()   # lewati sinematik kalah -> langsung ke menu pilihan
		return
	if panel == null:
		return
	if panel.has_method("handle"):
		panel.call("handle", action)


# ================================================================== HUD campaign
class CampHud extends Control:
	var g                       # scene campaign (campaign.gd)
	var t: float = 0.0
	var hint_t: float = 0.0
	var flash: float = 0.0
	var score_shown: float = 0.0
	var heart_tex: Texture2D

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		heart_tex = Global.cached_tex("res://assets/sprites/ui/heart.png")

	func _process(d: float) -> void:
		t += d
		hint_t = maxf(hint_t - d, 0.0)
		flash = maxf(flash - d * 2.2, 0.0)
		var target: float = float(int(g.run["score"]) + int(g.score_gain))
		score_shown = lerpf(score_shown, target, minf(d * 8.0, 1.0))
		if absf(score_shown - target) < 1.0:
			score_shown = target
		queue_redraw()

	func _draw() -> void:
		_draw_center()
		_draw_right()
		_draw_boss_bar()
		_draw_hint()
		if flash > 0.01:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.8 * flash))

	func _draw_center() -> void:
		var w: float = 230.0
		var ox: float = 525.0
		var pts := UIKit.slanted(w, 96, 22, ox, 4)
		draw_colored_polygon(UIKit.slanted(w, 96, 22, ox + 5, 10), Color(0, 0, 0, 0.45))
		draw_colored_polygon(pts, Color(0.05, 0.05, 0.12, 0.88))
		var edge: Color = Color("ff4040") if g.boss_level else Color(1, 1, 1, 0.35)
		draw_polyline(UIKit.closed(pts), edge, 3.0, true)
		UIKit.text_in(self, "LEVEL %d" % CampaignData.local_n(g.level_n), Rect2(ox, 8, w, 44), 44, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8)
		var waves: int = g.lvl["waves"].size()
		var wv: int = clampi(g.wave_i + 1, 1, waves)
		var line: String = "WAVE %d/%d" % [wv, waves]
		if g.ph in ["spawning", "fight"]:
			line += "   ENEMIES %d" % g.enemies_left()
		UIKit.text_in(self, line, Rect2(ox, 52, w, 24), 19, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 5)
		var wname: String = String(CampaignData.WORLDS[CampaignData.world_of(g.level_n)]["name"])
		if CampaignData.chapter_of(g.level_n) > 0:
			wname = "CH%d  %s" % [CampaignData.chapter_of(g.level_n) + 1, wname]
		UIKit.text_in(self, wname, Rect2(ox, 74, w, 22), 16, Color(UIKit.GOLD, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 5)

	func _draw_right() -> void:
		var w: float = 250.0
		var h: float = 118.0
		var ox: float = 1280.0 - 14.0 - w
		var oy: float = 12.0
		var pts := UIKit.slanted(w, h, 20, ox, oy)
		draw_colored_polygon(UIKit.slanted(w, h, 20, ox + 5, oy + 6), Color(0, 0, 0, 0.45))
		draw_colored_polygon(pts, Color(0.04, 0.04, 0.1, 0.84))
		draw_polyline(UIKit.closed(pts), Color(UIKit.CYAN, 0.9), 3.0, true)
		UIKit.text_in(self, "SCORE", Rect2(ox + 34, oy + 4, 120, 22), 17, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT, 4)
		UIKit.text_in(self, str(int(score_shown)), Rect2(ox + 22, oy + 22, w - 56, 46), 46, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 6, Color.BLACK, Global.font_digital)
		# combo
		if g.combo >= 2:
			var mult: float = 1.0 + 0.25 * float(mini(g.combo - 1, 8))
			var pulse: float = 1.0 + 0.06 * sin(t * 14.0)
			UIKit.text_in(self, "COMBO x%d  (x%.2f)" % [g.combo, mult], Rect2(ox + 30, oy + 68, w - 50, 20), int(18.0 * pulse), Color("ff8a3a"), HORIZONTAL_ALIGNMENT_RIGHT, 5)
			var frac: float = clampf(g.combo_t / 4.0, 0.0, 1.0)
			draw_rect(Rect2(ox + 40, oy + 90, w - 70, 5), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(ox + 40, oy + 90, (w - 70) * frac, 5), Color("ff8a3a"))
		# nyawa
		UIKit.text_in(self, "LIVES", Rect2(ox + 30, oy + 96, 70, 18), 14, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT, 4)
		var lives: int = maxi(int(g.run["lives"]), 0)
		for k in lives:
			var c := Vector2(ox + 112 + float(k) * 24.0, oy + 105)
			var bob: float = sin(t * 3.0 + float(k)) * 1.2
			draw_texture_rect(heart_tex, Rect2(c.x - 10, c.y - 10 + bob, 20, 20), false, Color("b36bff"))

	func _draw_boss_bar() -> void:
		for e in g.boss_state.keys():
			if not is_instance_valid(e) or not e.alive:
				continue
			var st: Dictionary = g.boss_state[e]["stats"]
			var frac: float = clampf(e.hp / maxf(e.max_hp, 0.01), 0.0, 1.0)
			var w: float = 700.0
			var x: float = (1280.0 - w) * 0.5
			var y: float = 660.0
			var enr: bool = bool(g.boss_state[e]["enraged"])
			draw_rect(Rect2(x - 4, y - 4, w + 8, 30), Color(0, 0, 0, 0.7))
			var col: Color = Color("ff4040") if enr else Color("ffb43a")
			if enr:
				col = col.lerp(Color.WHITE, 0.2 + 0.2 * sin(t * 12.0))
			draw_rect(Rect2(x, y, w * frac, 22), col)
			draw_rect(Rect2(x, y, w * frac, 7), Color(1, 1, 1, 0.3))
			draw_rect(Rect2(x, y, w, 22), Color(1, 1, 1, 0.9), false, 2.0)
			for q in [0.33, 0.66]:
				draw_line(Vector2(x + w * q, y), Vector2(x + w * q, y + 22), Color(0, 0, 0, 0.8), 2.0)
			UIKit.text_in(self, String(st["name"]), Rect2(x, y - 34, w, 30), 28, Color("ffd23f"), HORIZONTAL_ALIGNMENT_CENTER, 7)
			return

	func _draw_hint() -> void:
		if hint_t <= 0.0:
			return
		var s: String = String(g.lvl["hint"])
		if s == "":
			return
		var a: float = clampf(minf(hint_t, 6.0 - hint_t) * 2.0, 0.0, 1.0)
		var fs: int = 24
		var tw: float = UIKit.text_w(s, fs) + 70.0
		var r := Rect2((1280.0 - tw) * 0.5, 600.0, tw, 40.0)
		draw_colored_polygon(UIKit.slanted(r.size.x, r.size.y, 14, r.position.x, r.position.y), Color(0, 0, 0, 0.6 * a))
		UIKit.text_in(self, s, r, fs, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 5)


# ================================================================== bar darah musuh
class EnemyBar extends Node2D:
	var p: Player
	var boss: bool = false
	var shown: float = 1.0
	var t: float = 0.0

	func _process(d: float) -> void:
		if p == null:
			return
		t += d
		var target: float = clampf(p.hp / maxf(p.max_hp, 0.01), 0.0, 1.0)
		shown = lerpf(shown, target, minf(d * 9.0, 1.0))
		visible = p.alive
		queue_redraw()

	func _draw() -> void:
		if p == null or not p.alive:
			return
		var m: float = p.size_mult
		var w: float = 46.0 * m
		var y: float = -(76.0 * m)
		draw_rect(Rect2(-w * 0.5 - 2, y - 2, w + 4, 9), Color(0, 0, 0, 0.75))
		var col: Color = Color("ff4a4a").lerp(Color("ffd23f"), 1.0 - shown)
		if shown > 0.6:
			col = Color("5be07a").lerp(Color("ffd23f"), (1.0 - shown) * 2.0)
		draw_rect(Rect2(-w * 0.5, y, w * shown, 5), col)
		draw_rect(Rect2(-w * 0.5, y, w * shown, 2), Color(1, 1, 1, 0.35))
		if p.shield_hits > 0:
			draw_rect(Rect2(-w * 0.5, y - 5, w, 2), Color(0.45, 0.85, 1.0, 0.9))
		var brain: Variant = p.brain
		if brain != null and float((brain as AiBrain).frozen) > 0.0:
			draw_arc(Vector2.ZERO, 42.0 * m, 0.0, TAU, 24, Color(0.6, 0.9, 1.0, 0.9), 3.0, true)
			for k in 6:
				var a: float = float(k) * TAU / 6.0
				draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * 42.0 * m, Color(0.8, 0.95, 1.0, 0.5), 2.0)
		if boss and p.rate_scale < 0.9 and brain != null:
			draw_arc(Vector2.ZERO, 46.0 * m + sin(t * 10.0) * 3.0, 0.0, TAU, 28, Color(1.0, 0.25, 0.2, 0.5), 3.0, true)


# ================================================================== pustaka efek LEVEL CLEAR
class Fx:
	static var _glow: Texture2D = null
	static var _vig: Texture2D = null
	static var _add: CanvasItemMaterial = null

	## Bulatan cahaya lembut (putih -> transparan). Diwarnai lewat modulate / color_ramp.
	static func glow() -> Texture2D:
		if _glow == null:
			var gr := Gradient.new()
			gr.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
			gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0.0)])
			var t := GradientTexture2D.new()
			t.gradient = gr
			t.width = 64
			t.height = 64
			t.fill = GradientTexture2D.FILL_RADIAL
			t.fill_from = Vector2(0.5, 0.5)
			t.fill_to = Vector2(1.0, 0.5)
			_glow = t
		return _glow

	## Vignette: tengah bening, tepi gelap.
	static func vignette() -> Texture2D:
		if _vig == null:
			var gr := Gradient.new()
			gr.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
			gr.colors = PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0.01, 0.06, 0.6)])
			var t := GradientTexture2D.new()
			t.gradient = gr
			t.width = 256
			t.height = 256
			t.fill = GradientTexture2D.FILL_RADIAL
			t.fill_from = Vector2(0.5, 0.5)
			t.fill_to = Vector2(1.0, 0.5)
			_vig = t
		return _vig

	static func additive() -> CanvasItemMaterial:
		if _add == null:
			_add = CanvasItemMaterial.new()
			_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		return _add

	## Teks beroutline hitam yang ikut memudar (alpha outline = alpha warna).
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

	## Teks huruf-per-huruf: tiap huruf jatuh + membal (elastic), lalu bergoyang halus dan disapu kilau putih.
	## exit_t = waktu mulai keluar (huruf terbang ke atas).
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


## Lapisan cahaya (blend additive). Isinya digambar oleh fungsi milik pemiliknya.
class GlowLayer extends Control:
	var draw_fn: Callable

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		material = Fx.additive()

	func _draw() -> void:
		if draw_fn.is_valid():
			draw_fn.call(self)


# ================================================================== overlay sinematik LEVEL CLEAR
class ClearFx extends Control:
	var g
	var t: float = 0.0
	var open_t: float = 4.1
	var boss: bool = false
	var flawless: bool = false
	var sub_text: String = ""
	var stamp_t: float = -1.0
	var boss_t: float = -1.0
	var cx: float = 640.0
	var cy: float = 322.0
	var rings: Array = []       # {p, col, maxr, dur, w, t0}
	var flashes: Array = []     # {p, col, size, t0}
	var sparks: Array = []      # {p, v, life, max, size, col}
	var glow: GlowLayer
	var rng := RandomNumberGenerator.new()
	var spark_acc: float = 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		rng.randomize()
		glow = GlowLayer.new()
		glow.draw_fn = _draw_glow
		add_child(glow)

	func add_ring(p: Vector2, col: Color, maxr: float, dur: float, w: float, delay: float = 0.0) -> void:
		rings.append({"p": p, "col": col, "maxr": maxr, "dur": dur, "w": w, "t0": t + delay})

	func add_flash(p: Vector2, col: Color, size: float) -> void:
		flashes.append({"p": p, "col": col, "size": size, "t0": t})

	func add_sparks(p: Vector2, col: Color, n: int, speed: float) -> void:
		for i in n:
			var a: float = rng.randf() * TAU
			var v: Vector2 = Vector2(cos(a), sin(a)) * speed * rng.randf_range(0.3, 1.0)
			var life: float = rng.randf_range(0.5, 1.1)
			sparks.append({"p": p, "v": v, "life": life, "max": life, "size": rng.randf_range(7.0, 15.0), "col": col})

	func _process(_d: float) -> void:
		t = g.clear_t
		var dt: float = g.clear_dt
		# kilauan bintang mengambang di sekitar judul
		if t > 0.3 and t < open_t + 0.3:
			spark_acc += dt * 26.0
			while spark_acc >= 1.0:
				spark_acc -= 1.0
				var life: float = rng.randf_range(0.7, 1.5)
				var pos := Vector2(cx + rng.randf_range(-460.0, 460.0), cy + rng.randf_range(-110.0, 110.0))
				var col: Color = Color("ffd23f") if rng.randf() < 0.5 else (Color("4be3a0") if rng.randf() < 0.5 else Color.WHITE)
				sparks.append({"p": pos, "v": Vector2(rng.randf_range(-20.0, 20.0), rng.randf_range(-60.0, -10.0)), "life": life,
					"max": life, "size": rng.randf_range(8.0, 20.0), "col": col, "tw": true})
		for i in range(sparks.size() - 1, -1, -1):
			var s: Dictionary = sparks[i]
			s["life"] = float(s["life"]) - dt
			s["p"] = Vector2(s["p"]) + Vector2(s["v"]) * dt
			if not bool(s.get("tw", false)):
				s["v"] = Vector2(s["v"]) * (1.0 - minf(dt * 3.0, 1.0)) + Vector2(0, 260) * dt
			if float(s["life"]) <= 0.0:
				sparks.remove_at(i)
		for i in range(rings.size() - 1, -1, -1):
			if t - float(rings[i]["t0"]) > float(rings[i]["dur"]):
				rings.remove_at(i)
		for i in range(flashes.size() - 1, -1, -1):
			if t - float(flashes[i]["t0"]) > 0.5:
				flashes.remove_at(i)
		queue_redraw()
		glow.queue_redraw()

	# ---------------------------------------------------------------- gambar normal
	func _draw() -> void:
		var exit_t: float = open_t - 0.4
		var a_in: float = smoothstep(0.0, 0.25, t)
		var a_out: float = 1.0 - smoothstep(open_t - 0.2, open_t + 0.4, t)
		# peredupan + vignette
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.02, 0.1, 0.3 * a_in * a_out))
		draw_texture_rect(Fx.vignette(), Rect2(-240, -170, 1760, 1060), false, Color(1, 1, 1, a_in * a_out))

		# pita hitam sinematik atas & bawah
		var bo: float = clampf((t - (open_t - 0.35)) / 0.4, 0.0, 1.0)
		var bh: float = 60.0 * Fx.ease_out(t / 0.4) * (1.0 - Fx.ease_out(bo))
		if bh > 0.5:
			draw_rect(Rect2(0, 0, 1280, bh), Color(0, 0, 0, 0.92))
			draw_rect(Rect2(0, 720.0 - bh, 1280, bh), Color(0, 0, 0, 0.92))
			draw_rect(Rect2(0, bh, 1280, 3), Color("4be3a0", 0.9))
			draw_rect(Rect2(0, 720.0 - bh - 3.0, 1280, 3), Color("ffd23f", 0.9))

		# pita judul
		var xo: float = clampf((t - exit_t) / 0.4, 0.0, 1.0)
		var band: float = 150.0 * Fx.ease_out((t - 0.1) / 0.4) * (1.0 - xo)
		if band > 1.0:
			var r := Rect2(0, cy - band * 0.5, 1280, band)
			draw_rect(r, Color(0.02, 0.05, 0.12, 0.7))
			draw_rect(Rect2(0, r.position.y - 5, 1280, 5), Color("4be3a0", 0.95))
			draw_rect(Rect2(0, r.end.y, 1280, 5), Color("ffd23f", 0.95))
			# garis-garis bergerak di pita
			var off: float = fposmod(t * 160.0, 80.0)
			for k in 18:
				var x0: float = float(k) * 80.0 - off
				draw_colored_polygon(PackedVector2Array([Vector2(x0 + 24, r.position.y), Vector2(x0 + 40, r.position.y),
					Vector2(x0 + 16, r.end.y), Vector2(x0, r.end.y)]), Color(1, 1, 1, 0.035))

		# JUDUL
		Fx.wave_text(self, "LEVEL CLEAR!", Vector2(cx, cy), 126, t, 0.2, Color("4be3a0"), 0.055, 220.0, exit_t, 16)

		# subjudul + tanda boss
		if t > 0.95:
			var p: float = Fx.ease_out((t - 0.95) / 0.45)
			var fade: float = 1.0 - xo
			var tw: float = UIKit.text_w(sub_text, 30) + 96.0
			var x: float = cx - tw * 0.5 - (1.0 - p) * 900.0
			var y: float = cy + 92.0
			draw_colored_polygon(UIKit.slanted(tw, 46, 18, x + 6, y + 8), Color(0, 0, 0, 0.5 * fade))
			var pts := UIKit.slanted(tw, 46, 18, x, y)
			draw_colored_polygon(pts, Color(0.04, 0.06, 0.16, 0.95 * fade))
			draw_polyline(UIKit.closed(pts), Color("ffd23f", fade), 3.0, true)
			Fx.txt(self, sub_text, Rect2(x, y, tw, 46), 30, Color(1, 1, 1, fade), HORIZONTAL_ALIGNMENT_CENTER, 6)
		if boss_t >= 0.0 and t > boss_t:
			var p2: float = (t - boss_t) / 0.3
			var s: float = lerpf(2.6, 1.0, Fx.back(p2)) + 0.04 * sin(t * 12.0)
			var fade2: float = (1.0 - xo) * minf(p2 * 4.0, 1.0)
			var bw: float = 520.0
			var bx: float = cx - bw * 0.5
			var by: float = cy + 150.0
			draw_set_transform(Vector2(cx, by + 28.0) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * maxf(0.0, 1.0 - p2) * 6.0, 0.0, Vector2.ONE * s)
			var pts2 := UIKit.slanted(bw, 56, 22, -bw * 0.5, -28.0)
			draw_polygon(pts2, PackedColorArray([Color(1.0, 0.35, 0.2, fade2), Color(1.0, 0.2, 0.15, fade2), Color(0.55, 0.05, 0.08, fade2), Color(0.55, 0.05, 0.08, fade2)]))
			draw_polyline(UIKit.closed(pts2), Color("ffd23f", fade2), 4.0, true)
			Fx.txt(self, "BOSS DEFEATED!", Rect2(-bw * 0.5, -28.0, bw, 56.0), 44, Color("fff3a0", fade2), HORIZONTAL_ALIGNMENT_CENTER, 9)
			draw_set_transform(Vector2.ZERO)
			bx += 0.0

		# stempel FLAWLESS
		if stamp_t >= 0.0 and t > stamp_t:
			var p3: float = (t - stamp_t) / 0.22
			var sc3: float = lerpf(3.4, 1.0, Fx.back(p3)) * (1.0 + 0.025 * sin(t * 9.0))
			var fade3: float = minf(p3 * 5.0, 1.0) * (1.0 - xo)
			draw_set_transform(Vector2(1070, 226), -0.16, Vector2.ONE * sc3)
			var sw: float = 330.0
			draw_rect(Rect2(-sw * 0.5, -36, sw, 72), Color(0.1, 0.06, 0.0, 0.8 * fade3))
			draw_rect(Rect2(-sw * 0.5, -36, sw, 72), Color("ffd23f", fade3), false, 6.0)
			draw_rect(Rect2(-sw * 0.5 + 8, -28, sw - 16, 56), Color("fff3a0", 0.7 * fade3), false, 2.0)
			Fx.txt(self, "FLAWLESS!", Rect2(-sw * 0.5, -36, sw, 72), 52, Color("ffe680", fade3), HORIZONTAL_ALIGNMENT_CENTER, 10)
			draw_set_transform(Vector2.ZERO)

		# bintang berputar di atas kepala pahlawan
		if t > 0.5 and t < open_t + 0.5 and is_instance_valid(g.hero):
			var hp: Vector2 = g.w2s(g.hero.global_position)
			var fo: float = smoothstep(0.5, 0.9, t) * (1.0 - smoothstep(open_t - 0.2, open_t + 0.5, t))
			for k in 3:
				var ang: float = t * 3.4 + float(k) * TAU / 3.0
				var c := hp + Vector2(cos(ang) * 56.0, sin(ang) * 15.0 - 92.0)
				var depth: float = 0.75 + 0.25 * sin(ang)
				var pts3 := CampaignData.star_points(c, 12.0 * depth + 3.0, t * 2.0)
				draw_colored_polygon(pts3, Color("ffd23f", fo))
				draw_polyline(UIKit.closed(pts3), Color("fff8c0", fo), 2.0, true)

		# kilat putih saat dampak
		var fl: float = 1.0 - clampf(t / 0.38, 0.0, 1.0)
		if fl > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.85 * fl * fl))

	# ---------------------------------------------------------------- gambar cahaya (additive)
	func _draw_glow(ci: CanvasItem) -> void:
		var exit_t: float = open_t - 0.4
		var xo: float = clampf((t - exit_t) / 0.5, 0.0, 1.0)
		# sinar matahari berputar di belakang judul
		var ra: float = smoothstep(0.1, 0.7, t) * (1.0 - xo)
		if ra > 0.01:
			var n: int = 16
			for k in n:
				var a0: float = t * 0.28 + float(k) * TAU / float(n)
				var a1: float = a0 + TAU / float(n) * 0.5
				var col: Color = Color("4be3a0") if k % 2 == 0 else Color("ffd23f")
				var pts := PackedVector2Array([Vector2(cx, cy), Vector2(cx, cy) + Vector2(cos(a0), sin(a0)) * 1300.0, Vector2(cx, cy) + Vector2(cos(a1), sin(a1)) * 1300.0])
				ci.draw_polygon(pts, PackedColorArray([Color(col, 0.11 * ra), Color(col, 0.0), Color(col, 0.0)]))
			var gs: float = 760.0 + 30.0 * sin(t * 3.0)
			ci.draw_texture_rect(Fx.glow(), Rect2(cx - gs * 0.5, cy - gs * 0.5, gs, gs), false, Color(0.3, 1.0, 0.7, 0.17 * ra))
		# cahaya emas di bawah pahlawan
		if is_instance_valid(g.hero) and t < open_t + 0.5:
			var hp: Vector2 = g.w2s(g.hero.global_position)
			var hs: float = 330.0 + 26.0 * sin(t * 6.0)
			ci.draw_texture_rect(Fx.glow(), Rect2(hp.x - hs * 0.5, hp.y - hs * 0.5, hs, hs), false, Color(1.0, 0.85, 0.35, 0.45 * smoothstep(0.0, 0.3, t) * (1.0 - xo)))
			# garis kecepatan radial saat dampak
			if t < 0.55:
				var lp: float = t / 0.55
				for k in 44:
					var a: float = float(k) * TAU / 44.0 + float(k % 3) * 0.05
					var d0: float = 70.0 + lp * 260.0 + float(k % 5) * 20.0
					var d1: float = d0 + 160.0 * (1.0 - lp) + 40.0
					ci.draw_line(hp + Vector2(cos(a), sin(a)) * d0, hp + Vector2(cos(a), sin(a)) * d1, Color(1, 1, 0.9, 0.75 * (1.0 - lp)), 3.0, true)
		# cincin gelombang kejut
		for r in rings:
			var p: float = (t - float(r["t0"])) / float(r["dur"])
			if p < 0.0 or p > 1.0:
				continue
			var rad: float = float(r["maxr"]) * (1.0 - pow(1.0 - p, 4.0))
			var col2: Color = r["col"]
			ci.draw_arc(Vector2(r["p"]), rad, 0.0, TAU, 72, Color(col2, 0.9 * (1.0 - p)), lerpf(float(r["w"]), 1.0, p), true)
		# kilatan cahaya
		for f in flashes:
			var p2: float = (t - float(f["t0"])) / 0.5
			var sz: float = float(f["size"]) * (0.4 + 0.8 * Fx.ease_out(p2))
			var fc: Color = f["col"]
			ci.draw_texture_rect(Fx.glow(), Rect2(Vector2(f["p"]) - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(fc, 0.8 * (1.0 - p2) * (1.0 - p2)))
		# kilauan
		for s in sparks:
			var lf: float = float(s["life"]) / float(s["max"])
			var sz2: float = float(s["size"]) * sin(clampf(lf, 0.0, 1.0) * PI)
			if sz2 < 1.5:
				continue
			var sc: Color = s["col"]
			ci.draw_colored_polygon(Fx.sparkle(Vector2(s["p"]), sz2 * 1.4, t * 2.0), Color(sc, 0.95))
			ci.draw_texture_rect(Fx.glow(), Rect2(Vector2(s["p"]) - Vector2(sz2, sz2) * 1.2, Vector2(sz2, sz2) * 2.4), false, Color(sc, 0.35))


# ================================================================== overlay sinematik KEKALAHAN (YOU DIED / GAME OVER)
## Urutan: kilat merah + gelombang kejut -> retakan layar -> huruf judul menghantam jatuh -> pita level ->
## deretan nyawa (satu hati pecah jadi dua) -> "LIVES LEFT" atau stempel "NO LIVES LEFT" -> menu pilihan.
## Waktu `t` diambil dari campaign.gd (waktu nyata) supaya tetap mulus walau game sedang slow-motion.
class DefeatFx extends Control:
	var g
	var t: float = 0.0
	var over: bool = false
	var lives_before: int = 1
	var slots: int = 3
	var lives_left: int = 0
	var open_t: float = 3.6
	var hearts_t0: float = 1.5
	var brk_t: float = 2.4
	var cx: float = 640.0
	var cy: float = 300.0
	var focus: Vector2 = Vector2(640, 500)
	var sub_text: String = ""
	var title: String = "YOU DIED"
	var fs: int = 132
	var centers: Array[float] = []
	var widths: Array[float] = []
	var cracks: Array = []              # {pts, delay}
	var crack_t: float = -1.0
	var break_t: float = -1.0
	var lives_t: float = -1.0
	var stamp_t: float = -1.0
	var rings: Array = []               # {p, col, maxr, dur, w, t0}
	var flashes: Array = []             # {p, col, size, t0}
	var sparks: Array = []              # {p, v, life, max, size, col, ember, seed}
	var glow: GlowLayer
	var heart_tex: Texture2D
	var rng := RandomNumberGenerator.new()
	var ember_acc: float = 0.0
	static var _red_vig: Texture2D = null

	const HEART_STEP := 70.0
	const HEART_Y := 508.0
	const HEART_SIZE := 58.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		rng.randomize()
		title = "GAME OVER" if over else "YOU DIED"
		fs = 132
		while fs > 60 and UIKit.text_w(title, fs) > 1080.0:
			fs -= 4
		var total: float = 0.0
		for i in title.length():
			var w: float = UIKit.text_w(title[i], fs)
			if title[i] == " ":
				w = float(fs) * 0.3
			widths.append(w)
			total += w
		var x: float = cx - total * 0.5
		for i in title.length():
			centers.append(x + widths[i] * 0.5)
			x += widths[i]
		heart_tex = Global.cached_tex("res://assets/sprites/ui/heart.png")
		glow = GlowLayer.new()
		glow.draw_fn = _draw_glow
		add_child(glow)

	## Vignette merah: tengah bening, tepi merah gelap (berdenyut seperti detak jantung).
	static func red_vig() -> Texture2D:
		if _red_vig == null:
			var gr := Gradient.new()
			gr.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
			gr.colors = PackedColorArray([Color(0.4, 0.0, 0.0, 0.0), Color(0.35, 0.0, 0.02, 0.0), Color(0.5, 0.0, 0.04, 0.85)])
			var tx := GradientTexture2D.new()
			tx.gradient = gr
			tx.width = 256
			tx.height = 256
			tx.fill = GradientTexture2D.FILL_RADIAL
			tx.fill_from = Vector2(0.5, 0.5)
			tx.fill_to = Vector2(1.0, 0.5)
			_red_vig = tx
		return _red_vig

	# ---------------------------------------------------------------- pemicu efek
	func add_ring(p: Vector2, col: Color, maxr: float, dur: float, w: float, delay: float = 0.0) -> void:
		rings.append({"p": p, "col": col, "maxr": maxr, "dur": dur, "w": w, "t0": t + delay})

	func add_flash(p: Vector2, col: Color, size_px: float) -> void:
		flashes.append({"p": p, "col": col, "size": size_px, "t0": t})

	func add_sparks(p: Vector2, col: Color, n: int, speed: float) -> void:
		for i in n:
			var a: float = rng.randf() * TAU
			var v: Vector2 = Vector2(cos(a), sin(a)) * speed * rng.randf_range(0.3, 1.0)
			var life: float = rng.randf_range(0.5, 1.2)
			sparks.append({"p": p, "v": v, "life": life, "max": life, "size": rng.randf_range(7.0, 15.0), "col": col, "ember": false, "seed": 0.0})

	func letter_land(i: int) -> void:
		if i >= centers.size():
			return
		var pos := Vector2(centers[i], cy + float(fs) * 0.35)
		add_sparks(pos, Color("ff6a4a"), 9, 300.0)
		add_ring(pos, Color("ff3b30"), 130.0, 0.4, 6.0)
		g.shake(3.5)
		Global.play_sfx("score_tick", -8.0, 0.5 + 0.035 * float(i))

	func heart_pos(i: int) -> Vector2:
		return Vector2(cx - float(slots - 1) * HEART_STEP * 0.5 + float(i) * HEART_STEP, HEART_Y)

	func heart_break() -> void:
		break_t = t
		var hp: Vector2 = heart_pos(lives_before - 1)
		add_ring(hp, Color("ff3b4a"), 300.0, 0.6, 12.0)
		add_flash(hp, Color("ff6a6a"), 380.0)
		add_sparks(hp, Color("ff3b4a"), 26, 380.0)
		add_sparks(hp, Color.WHITE, 8, 280.0)

	## Retakan layar menjalar dari titik kematian (garis bergerigi + percabangan).
	func start_cracks() -> void:
		crack_t = t
		cracks.clear()
		var n: int = 12
		for k in n:
			var ang: float = float(k) * TAU / float(n) + rng.randf_range(-0.2, 0.2)
			var maxlen: float = rng.randf_range(340.0, 760.0)
			var pts := PackedVector2Array([focus])
			var p: Vector2 = focus
			var sum: float = 0.0
			while sum < maxlen:
				var seg: float = rng.randf_range(34.0, 80.0)
				ang += rng.randf_range(-0.28, 0.28)
				p += Vector2(cos(ang), sin(ang)) * seg
				pts.append(p)
				sum += seg
				if rng.randf() < 0.22 and sum > 80.0:
					_add_branch(p, ang + (0.7 if rng.randf() < 0.5 else -0.7), sum * 0.0004 + rng.randf_range(0.04, 0.1))
			cracks.append({"pts": pts, "delay": rng.randf_range(0.0, 0.08)})

	func _add_branch(from: Vector2, ang0: float, delay: float) -> void:
		var pts := PackedVector2Array([from])
		var p: Vector2 = from
		var ang: float = ang0
		for k in rng.randi_range(3, 4):
			ang += rng.randf_range(-0.35, 0.35)
			p += Vector2(cos(ang), sin(ang)) * rng.randf_range(20.0, 50.0)
			pts.append(p)
		cracks.append({"pts": pts, "delay": delay + 0.12})

	# ---------------------------------------------------------------- update
	func _process(_d: float) -> void:
		t = g.defeat_t
		var dt: float = g.defeat_dt
		# bara api melayang naik dari bawah layar (terus berjalan sampai pindah scene)
		if t > 0.2:
			ember_acc += dt * 22.0
			while ember_acc >= 1.0:
				ember_acc -= 1.0
				if sparks.size() < 240:
					var cols: Array = [Color("ff3b30"), Color("ff8a3a"), Color("ffd23f"), Color("ff5a40")]
					var life: float = rng.randf_range(2.2, 4.2)
					sparks.append({"p": Vector2(rng.randf_range(-20.0, 1300.0), 735.0),
						"v": Vector2(rng.randf_range(-24.0, 24.0), -rng.randf_range(70.0, 190.0)),
						"life": life, "max": life, "size": rng.randf_range(7.0, 15.0),
						"col": cols[rng.randi() % cols.size()], "ember": true, "seed": rng.randf() * TAU})
		for i in range(sparks.size() - 1, -1, -1):
			var s: Dictionary = sparks[i]
			s["life"] = float(s["life"]) - dt
			if bool(s["ember"]):
				var sway: float = sin(float(s["life"]) * 3.0 + float(s["seed"])) * 26.0
				s["p"] = Vector2(s["p"]) + (Vector2(s["v"]) + Vector2(sway, 0.0)) * dt
			else:
				s["p"] = Vector2(s["p"]) + Vector2(s["v"]) * dt
				s["v"] = Vector2(s["v"]) * (1.0 - minf(dt * 2.6, 1.0)) + Vector2(0, 520) * dt
			if float(s["life"]) <= 0.0:
				sparks.remove_at(i)
		for i in range(rings.size() - 1, -1, -1):
			if t - float(rings[i]["t0"]) > float(rings[i]["dur"]):
				rings.remove_at(i)
		for i in range(flashes.size() - 1, -1, -1):
			if t - float(flashes[i]["t0"]) > 0.5:
				flashes.remove_at(i)
		queue_redraw()
		glow.queue_redraw()

	# ---------------------------------------------------------------- gambar normal
	func _draw() -> void:
		var exit_t: float = open_t - 0.45
		var xo: float = clampf((t - exit_t) / 0.45, 0.0, 1.0)
		var a_in: float = smoothstep(0.0, 0.4, t)

		# peredupan kemerahan + vignette (tetap ada di belakang menu pilihan)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.0, 0.02, 0.36 * a_in))
		var beat: float = pow(maxf(sin(t * 5.2), 0.0), 8.0)
		var vr := Rect2(-240, -170, 1760, 1060)
		draw_texture_rect(red_vig(), vr, false, Color(1, 1, 1, clampf((0.8 + 0.2 * beat) * a_in, 0.0, 1.0)))
		draw_texture_rect(Fx.vignette(), vr, false, Color(1, 1, 1, a_in))

		# pita hitam sinematik atas & bawah
		var bo: float = clampf((t - (open_t - 0.4)) / 0.4, 0.0, 1.0)
		var bh: float = 60.0 * Fx.ease_out(t / 0.4) * (1.0 - Fx.ease_out(bo))
		if bh > 0.5:
			draw_rect(Rect2(0, 0, 1280, bh), Color(0, 0, 0, 0.92))
			draw_rect(Rect2(0, 720.0 - bh, 1280, bh), Color(0, 0, 0, 0.92))
			draw_rect(Rect2(0, bh, 1280, 3), Color("ff4040", 0.9))
			draw_rect(Rect2(0, 720.0 - bh - 3.0, 1280, 3), Color("7a1020", 0.9))

		# pita judul
		var band: float = 160.0 * Fx.ease_out((t - 0.1) / 0.4) * (1.0 - xo)
		if band > 1.0:
			var r := Rect2(0, cy - band * 0.5, 1280, band)
			draw_rect(r, Color(0.08, 0.0, 0.02, 0.78))
			draw_rect(Rect2(0, r.position.y - 5, 1280, 5), Color("ff4040", 0.95))
			draw_rect(Rect2(0, r.end.y, 1280, 5), Color("7a1020", 0.95))
			var off: float = fposmod(-t * 120.0, 80.0)
			for k in 18:
				var x0: float = float(k) * 80.0 - off
				draw_colored_polygon(PackedVector2Array([Vector2(x0 + 24, r.position.y), Vector2(x0 + 40, r.position.y),
					Vector2(x0 + 16, r.end.y), Vector2(x0, r.end.y)]), Color(1, 0.3, 0.3, 0.04))

		_draw_cracks()
		_draw_title(xo)

		# subjudul: nama level
		if t > 1.15:
			var p: float = Fx.ease_out((t - 1.15) / 0.45)
			var fade: float = 1.0 - xo
			var tw: float = UIKit.text_w(sub_text, 30) + 96.0
			var x: float = cx - tw * 0.5 + (1.0 - p) * 900.0
			var y: float = cy + 104.0
			draw_colored_polygon(UIKit.slanted(tw, 46, 18, x + 6, y + 8), Color(0, 0, 0, 0.5 * fade))
			var pts := UIKit.slanted(tw, 46, 18, x, y)
			draw_colored_polygon(pts, Color(0.1, 0.02, 0.05, 0.95 * fade))
			draw_polyline(UIKit.closed(pts), Color("ff4040", fade), 3.0, true)
			Fx.txt(self, sub_text, Rect2(x, y, tw, 46), 30, Color(1, 1, 1, fade), HORIZONTAL_ALIGNMENT_CENTER, 6)

		_draw_hearts(xo)

		# "LIVES LEFT n" (masih punya nyawa)
		if not over and lives_t >= 0.0:
			var pl: float = (t - lives_t) / 0.4
			var sc: float = lerpf(0.4, 1.0, Fx.back(pl))
			var fl: float = minf(pl * 4.0, 1.0) * (1.0 - xo)
			var txt: String = "LIVES LEFT  %d" % lives_left
			var pw: float = UIKit.text_w(txt, 32) + 96.0
			draw_set_transform(Vector2(cx, 566.0), 0.0, Vector2.ONE * sc)
			var pp := UIKit.slanted(pw, 46, 18, -pw * 0.5, -23.0)
			draw_colored_polygon(pp, Color(0.1, 0.02, 0.05, 0.95 * fl))
			draw_polyline(UIKit.closed(pp), Color("ff8a8a", fl), 3.0, true)
			Fx.txt(self, txt, Rect2(-pw * 0.5, -23.0, pw, 46.0), 32, Color("ffb0b0", fl), HORIZONTAL_ALIGNMENT_CENTER, 6)
			draw_set_transform(Vector2.ZERO)

		# stempel "NO LIVES LEFT" (game over)
		if over and stamp_t >= 0.0 and t > stamp_t:
			var p3: float = (t - stamp_t) / 0.22
			var sc3: float = lerpf(3.4, 1.0, Fx.back(p3)) * (1.0 + 0.02 * sin(t * 9.0))
			var fade3: float = minf(p3 * 5.0, 1.0) * (1.0 - xo)
			var sw: float = 580.0
			draw_set_transform(Vector2(cx, 590.0), -0.06, Vector2.ONE * sc3)
			draw_rect(Rect2(-sw * 0.5, -38, sw, 76), Color(0.12, 0.0, 0.02, 0.88 * fade3))
			draw_rect(Rect2(-sw * 0.5, -38, sw, 76), Color("ff4040", fade3), false, 6.0)
			draw_rect(Rect2(-sw * 0.5 + 8, -30, sw - 16, 60), Color("ff9a8a", 0.6 * fade3), false, 2.0)
			Fx.txt(self, "NO LIVES LEFT", Rect2(-sw * 0.5, -38, sw, 76), 54, Color("ffb0a0", fade3), HORIZONTAL_ALIGNMENT_CENTER, 10)
			draw_set_transform(Vector2.ZERO)

		# kilat merah saat dampak
		var fl0: float = 1.0 - clampf(t / 0.32, 0.0, 1.0)
		if fl0 > 0.0:
			draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.7, 0.7, 0.8 * fl0 * fl0))

	## Retakan putih menjalar dari titik kematian; lama-lama meredup tapi tetap terlihat.
	func _draw_cracks() -> void:
		if crack_t < 0.0:
			return
		var life: float = lerpf(1.0, 0.4, smoothstep(1.0, 2.4, t))
		for c in cracks:
			var pts: PackedVector2Array = c["pts"]
			var pr: float = clampf((t - crack_t - float(c["delay"])) / 0.3, 0.0, 1.0)
			if pr <= 0.0 or pts.size() < 2:
				continue
			var f: float = pr * float(pts.size() - 1)
			var full: int = int(floor(f))
			var sub := PackedVector2Array()
			for k in range(0, mini(full + 1, pts.size())):
				sub.append(pts[k])
			if full < pts.size() - 1:
				sub.append(pts[full].lerp(pts[full + 1], f - float(full)))
			if sub.size() >= 2:
				draw_polyline(sub, Color(1.0, 0.25, 0.25, 0.3 * life), 7.0, true)
				draw_polyline(sub, Color(1.0, 0.92, 0.92, 0.85 * life), 2.5, true)

	## Huruf-huruf judul menghantam jatuh (percepatan), membal + gepeng, lalu bergetar halus; sesekali glitch RGB.
	func _draw_title(xo: float) -> void:
		var glitch: float = 1.0 if (t > 1.3 and fposmod(t, 2.6) < 0.14) else 0.0
		var base := Color("ff3b3b")
		for i in title.length():
			if title[i] == " ":
				continue
			var q: float = (t - 0.3 - 0.07 * float(i)) / 0.38
			if q <= 0.0:
				continue
			var off_y: float = 0.0
			var sx: float = 1.0
			var sy: float = 1.0
			var al: float = 1.0
			var flash: float = 0.0
			if q < 1.0:
				off_y = -(1.0 - q * q * q) * 300.0
				sx = 1.0 + (1.0 - q) * 0.9
				sy = sx
				al = minf(q * 4.0, 1.0)
				flash = (1.0 - q) * 0.7
			else:
				var rr: float = q - 1.0
				off_y = -absf(sin(rr * 9.0)) * 26.0 * exp(-rr * 6.0) + sin(t * 2.2 + float(i) * 0.7) * 2.5 * (1.0 - exp(-rr * 6.0))
				sx = 1.0 + 0.2 * exp(-rr * 12.0)
				sy = 1.0 - 0.2 * exp(-rr * 12.0)
			off_y += xo * xo * 170.0
			al *= 1.0 - xo
			sx *= 1.0 - 0.15 * xo
			sy *= 1.0 - 0.15 * xo
			var w: float = widths[i]
			var heat: float = 0.5 + 0.5 * sin(t * 3.0 + float(i) * 0.9)
			var fill: Color = base.lerp(Color("ff9a7a"), 0.25 * heat).lerp(Color.WHITE, flash)
			draw_set_transform(Vector2(centers[i], cy + off_y), 0.0, Vector2(sx, sy))
			var rt := Rect2(-w * 0.5 - 6.0, -float(fs) * 0.65, w + 12.0, float(fs) * 1.3)
			UIKit.text_in(self, title[i], rt, fs, Color(0, 0, 0, 0), HORIZONTAL_ALIGNMENT_CENTER, 34, Color(base, 0.2 * al))
			UIKit.text_in(self, title[i], Rect2(rt.position + Vector2(6, 9), rt.size), fs, Color(0, 0, 0, 0.55 * al))
			if glitch > 0.0 and q > 1.0:
				UIKit.text_in(self, title[i], Rect2(rt.position + Vector2(-8, 0), rt.size), fs, Color(0.2, 0.9, 1.0, 0.55 * al))
				UIKit.text_in(self, title[i], Rect2(rt.position + Vector2(8, 0), rt.size), fs, Color(1.0, 0.2, 0.5, 0.55 * al))
			UIKit.text_in(self, title[i], rt, fs, Color(fill, al), HORIZONTAL_ALIGNMENT_CENTER, 16, Color(0, 0, 0, al))
		draw_set_transform(Vector2.ZERO)

	## Deretan nyawa: yang tersisa berdenyut, yang hilang bergetar lalu pecah jadi dua dan jatuh.
	func _draw_hearts(xo: float) -> void:
		if heart_tex == null:
			return
		var fade: float = 1.0 - xo
		var ts: float = t - (hearts_t0 - 0.1)
		if ts <= 0.0:
			return
		# slot kosong (gelap)
		for i in slots:
			var sp: Vector2 = heart_pos(i)
			var sa: float = Fx.ease_out(ts / 0.3) * fade
			draw_texture_rect(heart_tex, Rect2(sp.x - HEART_SIZE * 0.5, sp.y - HEART_SIZE * 0.5, HEART_SIZE, HEART_SIZE), false, Color(0.15, 0.15, 0.18, 0.8 * sa))
		for i in lives_before:
			var hp: Vector2 = heart_pos(i)
			var p: float = Fx.elastic((t - (hearts_t0 + 0.12 * float(i))) / 0.5)
			if p <= 0.0:
				continue
			var lost: bool = i == lives_before - 1
			if lost and break_t >= 0.0 and t >= break_t:
				_draw_heart_halves(hp, fade)
				continue
			var sc: float = p * (1.0 + 0.04 * sin(t * 6.0 + float(i)))
			var offv := Vector2.ZERO
			var tint := Color(1, 1, 1, fade)
			if lost:
				var tr: float = clampf((t - (brk_t - 0.4)) / 0.4, 0.0, 1.0)
				offv = Vector2(sin(t * 80.0) * 5.0 * tr, cos(t * 95.0) * 3.0 * tr)
				tint = Color(1.0, 1.0 - 0.5 * tr, 1.0 - 0.5 * tr, fade)
			draw_set_transform(hp + offv, 0.0, Vector2.ONE * sc)
			draw_texture_rect(heart_tex, Rect2(-HEART_SIZE * 0.5, -HEART_SIZE * 0.5, HEART_SIZE, HEART_SIZE), false, tint)
			draw_set_transform(Vector2.ZERO)

	func _draw_heart_halves(hp: Vector2, fade: float) -> void:
		var bt: float = t - break_t
		var tw_px: float = float(heart_tex.get_width())
		var th_px: float = float(heart_tex.get_height())
		var al: float = (1.0 - clampf(bt / 1.1, 0.0, 1.0)) * fade
		if al <= 0.0:
			return
		for sd in [-1.0, 1.0]:
			var side: float = sd
			var pos := Vector2(hp.x + side * (HEART_SIZE * 0.25 + bt * 55.0), hp.y + bt * bt * 520.0 - bt * 70.0)
			var src := Rect2(0.0 if side < 0.0 else tw_px * 0.5, 0.0, tw_px * 0.5, th_px)
			draw_set_transform(pos, side * bt * 2.4, Vector2.ONE)
			draw_texture_rect_region(heart_tex, Rect2(-HEART_SIZE * 0.25, -HEART_SIZE * 0.5, HEART_SIZE * 0.5, HEART_SIZE), src, Color(1, 1, 1, al))
		draw_set_transform(Vector2.ZERO)

	# ---------------------------------------------------------------- gambar cahaya (additive)
	func _draw_glow(ci: CanvasItem) -> void:
		var exit_t: float = open_t - 0.45
		var xo: float = clampf((t - exit_t) / 0.5, 0.0, 1.0)
		# sinar merah gelap berputar pelan di belakang judul
		var ra: float = smoothstep(0.1, 0.8, t) * (1.0 - xo)
		if ra > 0.01:
			var n: int = 10
			for k in n:
				var a0: float = -t * 0.2 + float(k) * TAU / float(n)
				var a1: float = a0 + TAU / float(n) * 0.45
				var c0 := Vector2(cx, cy)
				ci.draw_polygon(PackedVector2Array([c0, c0 + Vector2(cos(a0), sin(a0)) * 1300.0, c0 + Vector2(cos(a1), sin(a1)) * 1300.0]),
					PackedColorArray([Color(1.0, 0.15, 0.15, 0.09 * ra), Color(1.0, 0.15, 0.15, 0.0), Color(1.0, 0.15, 0.15, 0.0)]))
			var gs: float = 820.0 + 36.0 * sin(t * 2.4)
			ci.draw_texture_rect(Fx.glow(), Rect2(cx - gs * 0.5, cy - gs * 0.5, gs, gs), false, Color(1.0, 0.15, 0.12, 0.2 * ra))
		# cahaya merah di titik kematian + garis kecepatan saat dampak
		if t < open_t + 0.3:
			var hs: float = 320.0 + 24.0 * sin(t * 5.0)
			ci.draw_texture_rect(Fx.glow(), Rect2(focus.x - hs * 0.5, focus.y - hs * 0.5, hs, hs), false, Color(1.0, 0.2, 0.15, 0.4 * smoothstep(0.0, 0.3, t) * (1.0 - xo)))
			if t < 0.5:
				var lp: float = t / 0.5
				for k in 40:
					var a: float = float(k) * TAU / 40.0 + float(k % 3) * 0.05
					var d0: float = 70.0 + lp * 260.0 + float(k % 5) * 20.0
					var d1: float = d0 + 150.0 * (1.0 - lp) + 36.0
					ci.draw_line(focus + Vector2(cos(a), sin(a)) * d0, focus + Vector2(cos(a), sin(a)) * d1, Color(1.0, 0.8, 0.75, 0.7 * (1.0 - lp)), 3.0, true)
		# roh pahlawan naik pelan ke atas (jejak cahaya kebiruan)
		var sa: float = smoothstep(0.35, 0.7, t) * (1.0 - smoothstep(1.7, 2.6, t))
		if sa > 0.01:
			for k in 12:
				var tk: float = t - 0.045 * float(k)
				var rise: float = Fx.ease_out(clampf((tk - 0.35) / 2.1, 0.0, 1.0)) * 280.0
				var sp := focus + Vector2(sin(tk * 3.2) * 18.0, -34.0 - rise)
				var sz: float = 62.0 - float(k) * 3.8
				ci.draw_texture_rect(Fx.glow(), Rect2(sp - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(0.7, 0.92, 1.0, sa * (0.8 - float(k) * 0.06)))
		# kilau lembut di belakang nyawa yang masih ada
		if t > hearts_t0:
			for i in range(0, lives_before - 1):
				var hp: Vector2 = heart_pos(i)
				var pp: float = Fx.ease_out((t - (hearts_t0 + 0.12 * float(i))) / 0.4)
				var gz: float = 120.0 + 8.0 * sin(t * 5.0 + float(i))
				ci.draw_texture_rect(Fx.glow(), Rect2(hp.x - gz * 0.5, hp.y - gz * 0.5, gz, gz), false, Color(1.0, 0.25, 0.3, 0.22 * pp * (1.0 - xo)))
		# cincin gelombang kejut
		for r in rings:
			var p: float = (t - float(r["t0"])) / float(r["dur"])
			if p < 0.0 or p > 1.0:
				continue
			var rad: float = float(r["maxr"]) * (1.0 - pow(1.0 - p, 4.0))
			var rc: Color = r["col"]
			ci.draw_arc(Vector2(r["p"]), rad, 0.0, TAU, 72, Color(rc, 0.9 * (1.0 - p)), lerpf(float(r["w"]), 1.0, p), true)
		# kilatan cahaya
		for f in flashes:
			var p2: float = (t - float(f["t0"])) / 0.5
			var fz: float = float(f["size"]) * (0.4 + 0.8 * Fx.ease_out(p2))
			var fc: Color = f["col"]
			ci.draw_texture_rect(Fx.glow(), Rect2(Vector2(f["p"]) - Vector2(fz, fz) * 0.5, Vector2(fz, fz)), false, Color(fc, 0.8 * (1.0 - clampf(p2, 0.0, 1.0)) * (1.0 - clampf(p2, 0.0, 1.0))))
		# percikan + bara api
		for s in sparks:
			var lf: float = clampf(float(s["life"]) / float(s["max"]), 0.0, 1.0)
			var sz2: float = float(s["size"]) * sin(lf * PI)
			if sz2 < 1.5:
				continue
			var sc: Color = s["col"]
			if bool(s["ember"]):
				ci.draw_texture_rect(Fx.glow(), Rect2(Vector2(s["p"]) - Vector2(sz2, sz2) * 1.1, Vector2(sz2, sz2) * 2.2), false, Color(sc, 0.55))
			else:
				ci.draw_colored_polygon(Fx.sparkle(Vector2(s["p"]), sz2 * 1.3, t * 2.0), Color(sc, 0.95))
				ci.draw_texture_rect(Fx.glow(), Rect2(Vector2(s["p"]) - Vector2(sz2, sz2) * 1.2, Vector2(sz2, sz2) * 2.4), false, Color(sc, 0.35))


# ================================================================== roket kembang api
class FwRocket extends Node2D:
	var g
	var from: Vector2 = Vector2.ZERO
	var to: Vector2 = Vector2.ZERO
	var col: Color = Color.WHITE
	var dur: float = 0.6
	var t: float = 0.0
	var trail: CPUParticles2D

	func _ready() -> void:
		position = from
		material = Fx.additive()
		trail = CPUParticles2D.new()
		trail.amount = 36
		trail.lifetime = 0.45
		trail.local_coords = false
		trail.direction = Vector2.DOWN
		trail.spread = 25.0
		trail.initial_velocity_min = 20.0
		trail.initial_velocity_max = 90.0
		trail.gravity = Vector2(0, 120)
		trail.scale_amount_min = 0.12
		trail.scale_amount_max = 0.26
		trail.texture = Fx.glow()
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		gr.colors = PackedColorArray([Color(1, 1, 0.9, 1), Color(col, 0.8), Color(col, 0.0)])
		trail.color_ramp = gr
		add_child(trail)
		trail.use_parent_material = true
		trail.emitting = true

	func _process(d: float) -> void:
		t += d
		var p: float = clampf(t / dur, 0.0, 1.0)
		var e: float = 1.0 - pow(1.0 - p, 2.0)
		position = from.lerp(to, e) + Vector2(sin(p * 18.0) * 6.0 * (1.0 - p), 0.0)
		queue_redraw()
		if p >= 1.0:
			g.firework_burst(position, col)
			queue_free()

	func _draw() -> void:
		draw_texture_rect(Fx.glow(), Rect2(-22, -22, 44, 44), false, Color(col, 0.9))
		draw_circle(Vector2.ZERO, 4.0, Color.WHITE)

# ================================================================== panel hasil level
class TallyPanel extends Control:
	signal finished
	signal chosen(id: String)   # "map" / "menu" (CONTINUE tetap lewat sinyal finished)
	const ROW0 := 0.7
	const ROW_DT := 0.3
	const COUNT_DUR := 0.5
	const PW := 780.0
	const PH := 570.0
	const PX := 250.0
	const PY := 20.0

	var g
	var level_text: String = ""
	var rows: Array = []            # {label, kind, val, text, col, hi}
	var stars: int = 0
	var total_from: int = 0
	var total_to: int = 0
	var grade: String = "C"
	var new_record: bool = false
	var first_clear: bool = false
	var boss: bool = false
	var flawless: bool = false

	var t: float = 0.0
	var _emitted: bool = false
	var events: Array = []
	var parts: Array = []           # partikel cahaya {p, v, life, max, size, col, grav}
	var shake_v: float = 0.0
	var star_pop: Array[float] = [0.0, 0.0, 0.0]
	var total_pop: float = 0.0
	var grade_pop: float = 0.0
	var rng := RandomNumberGenerator.new()
	var prompt: UIKit.PromptBar
	var glow: GlowLayer
	var _last_tick: float = -1.0
	# tombol pilihan di bawah panel (muncul setelah animasi hasil selesai)
	const BTN_W := 290.0
	const BTN_H := 56.0
	const BTN_Y := 606.0
	var _btn_ids: Array[String] = ["continue", "map", "menu"]
	var _btn_labels: Array[String] = ["CONTINUE", "LEVEL SELECT", "MAIN MENU"]
	var _btns: Array[UIKit.FancyButton] = []
	var _sel: int = 0
	var _revealed: bool = false
	var _reveal_ms: int = 0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		theme = Global.ui_theme
		rng.randomize()
		prompt = UIKit.make_prompt(self)
		prompt.fsize = 20
		prompt.gsize = 26.0
		prompt.set_prompts([[&"dpad_lr", "NAVIGATE"], [&"accept", "SELECT"]])
		prompt.modulate.a = 0.0
		var holder := prompt.get_parent() as Control
		if holder != null:
			holder.offset_top = -50
			holder.offset_bottom = -8
		glow = GlowLayer.new()
		glow.draw_fn = _draw_glow
		add_child(glow)
		_build_buttons()
		_build_events()

	func _build_buttons() -> void:
		var x0: float = (1280.0 - (BTN_W * float(_btn_ids.size() - 1) + BTN_W - 34.0)) * 0.5
		for i in _btn_ids.size():
			var label: String = _btn_labels[i]
			var fs: int = 24
			while fs > 14 and UIKit.text_w(label, fs) > BTN_W - 34.0 - 70.0:
				fs -= 1
			var b := UIKit.FancyButton.new(label, Vector2(BTN_W, BTN_H), fs)
			b.position = Vector2(x0 + BTN_W * float(i), BTN_Y)
			b.modulate.a = 0.0
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE   # baru bisa diklik setelah muncul
			if i == 0:
				b.accent = Color("4be3a0")
			elif i == 1:
				b.accent = Color("4fd8ff")
			add_child(b)
			var idx: int = i
			b.hovered.connect(func() -> void: _select(idx))
			b.activated.connect(func() -> void: _choose(idx))
			_btns.append(b)
		_select(0, false)

	func _select(i: int, sound: bool = true) -> void:
		if not _revealed and sound:
			return
		if i == _sel and sound:
			return
		_sel = i
		for k in _btns.size():
			_btns[k].set_selected(k == i)
		if sound:
			Global.play_sfx("ui_hover", -8.0)

	func _reveal_buttons() -> void:
		_revealed = true
		_reveal_ms = Time.get_ticks_msec() + 250   # cegah tombol langsung terpencet saat sinematik dilewati
		for i in _btns.size():
			var b: UIKit.FancyButton = _btns[i]
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			var base: Vector2 = b.position
			b.position = base + Vector2(0.0, 24.0)
			var tw := UIKit.tw(b)
			tw.set_parallel(true)
			tw.tween_property(b, "position", base, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.06 * float(i))
			tw.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(0.06 * float(i))
		_select(0, false)
		Global.play_sfx("ui_whoosh", -10.0, 1.2)

	func _choose(i: int) -> void:
		if _emitted or not _revealed or Time.get_ticks_msec() < _reveal_ms:
			return
		_emitted = true
		if _btn_ids[i] == "continue":
			finished.emit()
		else:
			chosen.emit(_btn_ids[i])

	# ---------------------------------------------------------------- jadwal
	func _rows_end() -> float:
		return ROW0 + float(rows.size()) * ROW_DT + 0.1

	func _star_t0() -> float:
		return _rows_end() + 0.15

	func _total_t0() -> float:
		return _rows_end() + 0.15

	func _total_dur() -> float:
		return 1.3

	func _grade_t() -> float:
		var last_star: float = _star_t0() + 0.5 * float(maxi(stars, 1))
		return maxf(last_star, _total_t0() + _total_dur()) + 0.2

	func _end_time() -> float:
		return _grade_t() + 0.75

	func _ev(at: float, id: String, arg: int = 0) -> void:
		events.append({"t": at, "id": id, "arg": arg, "done": false})

	func _build_events() -> void:
		_ev(0.0, "open")
		_ev(0.3, "head")
		for i in rows.size():
			var st: float = ROW0 + float(i) * ROW_DT
			_ev(st, "row", i)
			for j in 4:
				_ev(st + 0.1 + 0.09 * float(j), "tick", j + i)
			_ev(st + COUNT_DUR + 0.05, "rowdone", i)
		for k in stars:
			_ev(_star_t0() + 0.5 * float(k), "star", k)
		_ev(_total_t0() + _total_dur(), "totaldone")
		_ev(_grade_t(), "grade")
		if new_record:
			_ev(_grade_t() + 0.35, "record")
		if stars >= 3:
			_ev(_star_t0() + 0.5 * 2.0 + 0.25, "perfect")

	func _run_event(e: Dictionary, silent: bool) -> void:
		e["done"] = true
		if silent:
			return
		match String(e["id"]):
			"open":
				Global.play_sfx("ui_panel", -3.0)
				Global.play_sfx("ui_whoosh", -9.0, 0.8)
				_spark_burst(Vector2(PX + PW * 0.5, PY + 8.0), Color("4be3a0"), 26, 380.0)
			"head":
				Global.play_sfx("win_pip", -10.0, 1.3)
				_spark_burst(Vector2(PX + PW * 0.5, PY + 52.0), Color("ffd23f"), 18, 260.0)
			"row":
				Global.play_sfx("ui_hover", -9.0, 1.0 + 0.06 * float(int(e["arg"])))
			"tick":
				Global.play_sfx("score_tick", -9.0, 0.9 + 0.09 * float(int(e["arg"])))
			"rowdone":
				var r: Dictionary = rows[int(e["arg"])]
				if bool(r.get("hi", false)):
					Global.play_synth("coin", -8.0, 1.0)
					_spark_burst(Vector2(PX + PW - 120.0, _row_y(int(e["arg"])) + 18.0), Color("4fd8ff"), 20, 300.0)
				elif String(r["label"]).begins_with("COINS"):
					Global.play_synth("coin", -6.0, 1.15)
					_spark_burst(Vector2(PX + PW - 130.0, _row_y(int(e["arg"])) + 16.0), Color("ffcd3c"), 22, 320.0)
				elif String(r["label"]) == "FLAWLESS" and float(r["val"]) > 0.0:
					Global.play_synth("stab", -9.0, 1.2, "Celebrate")
					_spark_burst(Vector2(PX + PW - 140.0, _row_y(int(e["arg"])) + 18.0), Color("ffd23f"), 24, 340.0)
					shake_v = maxf(shake_v, 5.0)
				else:
					Global.play_sfx("ui_marimba", -10.0, 1.0 + 0.05 * float(int(e["arg"])))
			"star":
				var k: int = int(e["arg"])
				star_pop[k] = 1.0
				var c: Vector2 = _star_c(k)
				Global.play_sfx("star", -3.0, 0.9 + 0.17 * float(k))
				Global.play_synth("chime", -5.0, 1.0 + 0.19 * float(k), "Celebrate")
				Global.play_sfx("wall_impact", -6.0, 0.6)
				_spark_burst(c, Color("ffd23f"), 34, 460.0)
				_spark_burst(c, Color.WHITE, 12, 260.0)
				shake_v = maxf(shake_v, 7.0)
				if g != null:
					g.shake(4.0)
			"perfect":
				Global.play_synth("shimmer", -8.0, 1.1, "Celebrate")
				for k in 3:
					_spark_burst(_star_c(k), Color("fff3a0"), 20, 520.0)
			"totaldone":
				total_pop = 1.0
				Global.play_synth("coin", -6.0, 1.25)
				Global.play_sfx("extra_life", -12.0, 1.4)
				_spark_burst(Vector2(PX + PW - 180.0, PY + 520.0), Color("4fd8ff"), 36, 480.0)
			"grade":
				grade_pop = 1.0
				var gc: Vector2 = _grade_c()
				Global.play_synth("stab", -4.0, 1.0 if grade == "S" else 0.85, "Celebrate")
				Global.play_sfx("wall_impact", -2.0, 0.5)
				_spark_burst(gc, _grade_col(), 46, 560.0)
				_spark_burst(gc, Color.WHITE, 16, 320.0)
				shake_v = maxf(shake_v, 10.0)
				if g != null:
					g.shake(6.0)
				if grade == "S":
					Global.play_synth("applause", -10.0, 1.0, "Celebrate")
			"record":
				Global.play_sfx("perk_open", -4.0, 1.2)
				Global.play_synth("coin", -8.0, 1.5)
				_spark_burst(Vector2(PX + PW - 90.0, PY + 28.0), Color("ff4040"), 26, 380.0)

	func _spark_burst(p: Vector2, col: Color, n: int, speed: float) -> void:
		for i in n:
			var a: float = rng.randf() * TAU
			var v: Vector2 = Vector2(cos(a), sin(a)) * speed * rng.randf_range(0.25, 1.0)
			var life: float = rng.randf_range(0.55, 1.2)
			parts.append({"p": p, "v": v, "life": life, "max": life, "size": rng.randf_range(10.0, 26.0), "col": col, "grav": 420.0})

	# ---------------------------------------------------------------- input
	func handle(action: StringName) -> void:
		if _emitted:
			return
		if t < _end_time():
			if action == &"accept" or action == &"fire":
				_skip()
			return
		if not _revealed:
			return
		match action:
			&"left", &"up":
				_select(posmod(_sel - 1, _btns.size()))
			&"right", &"down":
				_select(posmod(_sel + 1, _btns.size()))
			&"accept", &"fire":
				_btns[_sel].press()

	func _skip() -> void:
		for e in events:
			if not bool(e["done"]):
				_run_event(e, true)
		t = _end_time()
		star_pop = [0.0, 0.0, 0.0]
		Global.play_sfx("ui_hover", -9.0)

	func _gui_input(event: InputEvent) -> void:
		# klik di area kosong hanya melewati animasi; pilihan dilakukan lewat tombol
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if t < _end_time():
				_skip()

	# ---------------------------------------------------------------- update
	func _process(d: float) -> void:
		t += d
		modulate.a = clampf(t / 0.2, 0.0, 1.0)
		for e in events:
			if not bool(e["done"]) and t >= float(e["t"]):
				_run_event(e, false)
		for k in 3:
			star_pop[k] = maxf(star_pop[k] - d * 2.2, 0.0)
		total_pop = maxf(total_pop - d * 2.4, 0.0)
		grade_pop = maxf(grade_pop - d * 1.6, 0.0)
		shake_v = lerpf(shake_v, 0.0, minf(d * 10.0, 1.0))
		# bunyi tik saat total dihitung naik
		var tt: float = t - _total_t0()
		if tt > 0.0 and tt < _total_dur() and t - _last_tick > 0.05:
			_last_tick = t
			Global.play_sfx("score_tick", -12.0, 0.8 + 0.9 * tt / _total_dur())
		for i in range(parts.size() - 1, -1, -1):
			var q: Dictionary = parts[i]
			q["life"] = float(q["life"]) - d
			q["v"] = Vector2(q["v"]) * (1.0 - minf(d * 2.2, 1.0)) + Vector2(0.0, float(q["grav"])) * d
			q["p"] = Vector2(q["p"]) + Vector2(q["v"]) * d
			if float(q["life"]) <= 0.0:
				parts.remove_at(i)
		if t >= _end_time() and not _revealed:
			_reveal_buttons()
		prompt.modulate.a = 0.55 + 0.45 * sin(t * 6.0) if t >= _end_time() else 0.0
		queue_redraw()
		glow.queue_redraw()

	# ---------------------------------------------------------------- tata letak
	func _row_y(i: int) -> float:
		return PY + 116.0 + float(i) * (34.0 if rows.size() <= 6 else 29.5)

	func _star_c(k: int) -> Vector2:
		return Vector2(PX + 160.0 + float(k) * 124.0, PY + 410.0)

	func _grade_c() -> Vector2:
		return Vector2(PX + PW - 170.0, PY + 408.0)

	func _grade_col() -> Color:
		match grade:
			"S": return Color("ffd23f")
			"A": return Color("4be3a0")
			"B": return Color("4fd8ff")
		return Color("b8c0d8")

	func _fmt(r: Dictionary, v: float) -> String:
		match String(r["kind"]):
			"int": return str(int(roundf(v)))
			"plus": return "+%d" % int(roundf(v))
			"time": return "%d:%02d" % [int(v) / 60, int(v) % 60]
			"dmg": return "%.1f" % v
		return String(r.get("text", ""))

	func _xf(ci: CanvasItem) -> void:
		var pin: float = clampf(t / 0.55, 0.0, 1.0)
		var sc: float = 0.5 + 0.5 * Fx.back(pin)
		var c := Vector2(640.0, PY + PH * 0.5)
		var sh := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * shake_v
		ci.draw_set_transform(c - c * sc + sh + Vector2(0.0, (1.0 - Fx.ease_out(pin)) * 60.0), 0.0, Vector2.ONE * sc)

	# ---------------------------------------------------------------- gambar
	func _draw() -> void:
		var pin: float = clampf(t / 0.55, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.07, 0.62 * clampf(t / 0.3, 0.0, 1.0)))
		draw_texture_rect(Fx.vignette(), Rect2(-200, -150, 1680, 1020), false, Color(1, 1, 1, clampf(t / 0.3, 0.0, 1.0)))
		_xf(self)
		var pts := UIKit.slanted(PW, PH, 28, PX, PY)
		draw_colored_polygon(UIKit.slanted(PW, PH, 28, PX + 9, PY + 12), Color(0, 0, 0, 0.55))
		draw_polygon(pts, PackedColorArray([Color(0.09, 0.12, 0.26, 0.97), Color(0.09, 0.12, 0.26, 0.97), Color(0.03, 0.04, 0.11, 0.98), Color(0.03, 0.04, 0.11, 0.98)]))
		# pola garis diagonal halus
		for k in 22:
			var x0: float = PX + 30.0 + float(k) * 36.0
			draw_line(Vector2(x0 + 28.0, PY + 4.0), Vector2(x0 - 28.0 + 10.0, PY + PH - 4.0), Color(1, 1, 1, 0.018), 8.0)
		# bingkai berkilau: warna mengalir
		var pulse: float = 0.5 + 0.5 * sin(t * 3.0)
		draw_polyline(UIKit.closed(pts), Color("4be3a0", 0.25 + 0.2 * pulse), 12.0, true)
		draw_polyline(UIKit.closed(pts), Color("4be3a0"), 4.0, true)
		# kilau menyapu panel
		var sw: float = fposmod(t * 0.55, 1.8)
		if sw < 1.0:
			var sx: float = PX + 40.0 + sw * (PW - 120.0)
			draw_colored_polygon(PackedVector2Array([Vector2(sx + 30, PY + 6), Vector2(sx + 80, PY + 6), Vector2(sx + 50, PY + PH - 6), Vector2(sx, PY + PH - 6)]), Color(1, 1, 1, 0.07))
		# pita atas
		draw_rect(Rect2(PX + 32, PY + 5, PW - 64, 5), Color("ffd23f", 0.9))

		# judul
		Fx.wave_text(self, "LEVEL CLEAR!", Vector2(640.0, PY + 50.0), 64, t, 0.15, Color("4be3a0"), 0.04, 120.0, 1.0e9, 10)
		var sub_a: float = clampf((t - 0.5) / 0.3, 0.0, 1.0)
		Fx.txt(self, level_text, Rect2(PX, PY + 84.0, PW, 26), 22, Color(1, 1, 1, 0.82 * sub_a), HORIZONTAL_ALIGNMENT_CENTER, 5)

		# baris hasil
		for i in rows.size():
			_draw_row(i)

		# pemisah
		if t > _rows_end():
			var la: float = clampf((t - _rows_end()) / 0.3, 0.0, 1.0)
			draw_line(Vector2(PX + 60.0, PY + 330.0), Vector2(PX + 60.0 + (PW - 160.0) * la, PY + 330.0), Color(1, 1, 1, 0.22), 2.0)

		# bintang
		for k in 3:
			_draw_star(k)
		# kata penilaian
		if stars > 0 and t > _star_t0() + 0.5 * float(stars - 1) + 0.15:
			var wp: float = (t - (_star_t0() + 0.5 * float(stars - 1) + 0.15)) / 0.35
			var words: Array = ["GOOD", "GREAT!", "PERFECT!!"]
			var wcols: Array = [Color("b8c0d8"), Color("4fd8ff"), Color("ffd23f")]
			var ws: float = lerpf(2.0, 1.0, Fx.back(wp))
			draw_set_transform(Vector2(PX + 284.0, PY + 482.0) + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake_v * 0.4, 0.0, Vector2.ONE * ws)
			Fx.txt(self, String(words[stars - 1]), Rect2(-160, -20, 320, 40), 34, Color(wcols[stars - 1], minf(wp * 4.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, 8)
			_xf(self)

		# medali rank
		_draw_grade()

		# total skor
		_draw_total()

		# label NEW RECORD
		if new_record and t > _grade_t() + 0.35:
			var rp: float = (t - (_grade_t() + 0.35)) / 0.3
			var rs: float = lerpf(2.4, 1.0, Fx.back(rp)) * (1.0 + 0.05 * sin(t * 10.0))
			draw_set_transform(Vector2(PX + PW - 100.0, PY + 30.0), 0.14, Vector2.ONE * rs)
			var rpts := UIKit.slanted(230, 42, 14, -115.0, -21.0)
			var ra: float = minf(rp * 4.0, 1.0)
			draw_colored_polygon(rpts, Color(0.9, 0.12, 0.15, ra))
			draw_polyline(UIKit.closed(rpts), Color("fff3a0", ra), 3.0, true)
			Fx.txt(self, "NEW RECORD!", Rect2(-115, -21, 230, 42), 28, Color(1, 1, 1, ra), HORIZONTAL_ALIGNMENT_CENTER, 6)
			_xf(self)

		draw_set_transform(Vector2.ZERO)

	func _draw_row(i: int) -> void:
		var r: Dictionary = rows[i]
		var st: float = ROW0 + float(i) * ROW_DT
		var p: float = clampf((t - st) / 0.28, 0.0, 1.0)
		if p <= 0.0:
			return
		var e: float = Fx.ease_out(p)
		var y: float = _row_y(i)
		var xo: float = (1.0 - e) * 160.0
		var hi: bool = bool(r.get("hi", false))
		if i % 2 == 0 or hi:
			var bc: Color = Color("4fd8ff", 0.14) if hi else Color(1, 1, 1, 0.045)
			draw_colored_polygon(UIKit.slanted(PW - 96.0, 32.0, 10, PX + 50.0 + xo, y), Color(bc, bc.a * p))
		var cp: float = clampf((t - st - 0.08) / COUNT_DUR, 0.0, 1.0)
		var v: float = float(r["val"]) * Fx.ease_out(cp)
		var txt: String = _fmt(r, v)
		var vc: Color = r["col"]
		if String(r["kind"]) == "text":
			vc = Color(vc, 0.6)
		# denyut setelah selesai menghitung
		var done_p: float = clampf((t - st - 0.08 - COUNT_DUR) / 0.3, 0.0, 1.0)
		var pop: float = 1.0 + 0.32 * sin(done_p * PI) if cp >= 1.0 and done_p < 1.0 else 1.0
		if cp < 1.0:
			vc = vc.lerp(Color.WHITE, 0.55)
		var fs: int = 34 if hi else 30
		if String(r["label"]).begins_with("COINS"):
			var ctex: Texture2D = Cosmetics.coin_tex()
			if ctex != null:
				var spin: float = absf(cos(t * 3.2))
				var cw: float = 26.0 * maxf(spin, 0.18)
				draw_texture_rect(ctex, Rect2(PX + 62.0 + xo - cw * 0.5, y + 3.0, cw, 26.0), false, Color(1, 1, 1, p))
		Fx.txt(self, String(r["label"]), Rect2(PX + 84.0 + xo, y, 330, 32), fs, Color(1, 1, 1, 0.85 * p), HORIZONTAL_ALIGNMENT_LEFT, 5)
		var vr := Rect2(PX + PW - 400.0 + xo, y, 300.0, 32.0)
		draw_set_transform(Vector2(vr.end.x, y + 16.0), 0.0, Vector2.ONE * pop)
		Fx.txt(self, txt, Rect2(-300.0, -16.0, 300.0, 32.0), fs + 2, Color(vc, p), HORIZONTAL_ALIGNMENT_RIGHT, 6)
		_xf(self)

	func _draw_star(k: int) -> void:
		var c: Vector2 = _star_c(k)
		# slot kosong
		var bob: float = sin(t * 2.0 + float(k)) * 1.5
		var slot := CampaignData.star_points(c + Vector2(0, bob), 50.0)
		draw_colored_polygon(slot, Color(0.12, 0.13, 0.22))
		draw_polyline(UIKit.closed(slot), Color(1, 1, 1, 0.12), 3.0, true)
		if k >= stars:
			return
		var ts: float = _star_t0() + 0.5 * float(k)
		var p: float = (t - ts) / 0.4
		if p <= 0.0:
			return
		var sc: float = lerpf(3.4, 1.0, Fx.back(p))
		var rot: float = lerpf(-TAU * 0.75, 0.0, Fx.ease_out(p)) + 0.05 * sin(t * 2.5 + float(k))
		var al: float = clampf(p * 5.0, 0.0, 1.0)
		var r: float = 50.0 * sc * (1.0 + 0.18 * star_pop[k])
		var pts := CampaignData.star_points(c, r, rot)
		draw_colored_polygon(pts, Color("ffd23f", al))
		var inner := CampaignData.star_points(c, r * 0.62, rot)
		draw_colored_polygon(inner, Color("ffe98a", al))
		draw_polyline(UIKit.closed(pts), Color("fff8c0", al), 4.0, true)
		# kilap berjalan di dalam bintang
		if p > 1.0:
			var sh: float = fposmod(t * 0.8 + float(k) * 0.3, 1.6)
			if sh < 1.0:
				var a: float = sh * TAU
				draw_line(c + Vector2(cos(a), sin(a)) * 12.0, c + Vector2(cos(a), sin(a)) * 40.0, Color(1, 1, 1, 0.8 * sin(sh * PI)), 4.0, true)

	func _draw_grade() -> void:
		var gp: float = (t - _grade_t()) / 0.35
		var c: Vector2 = _grade_c()
		Fx.txt(self, "RANK", Rect2(c.x - 70.0, c.y - 90.0, 140.0, 24.0), 20, Color(1, 1, 1, 0.6 * clampf((t - _grade_t() + 0.6) / 0.4, 0.0, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, 4)
		draw_circle(c, 56.0, Color(0, 0, 0, 0.35))
		draw_arc(c, 56.0, 0.0, TAU, 48, Color(1, 1, 1, 0.14), 4.0, true)
		if gp <= 0.0:
			return
		var col: Color = _grade_col()
		var sc: float = lerpf(3.0, 1.0, Fx.back(gp)) * (1.0 + 0.1 * grade_pop)
		var rot: float = lerpf(0.6, 0.0, Fx.ease_out(gp))
		var al: float = clampf(gp * 5.0, 0.0, 1.0)
		draw_set_transform(c, rot, Vector2.ONE * sc)
		draw_circle(Vector2.ZERO, 54.0, Color(col.darkened(0.55), al))
		draw_circle(Vector2.ZERO, 46.0, Color(col.darkened(0.2), al))
		draw_arc(Vector2.ZERO, 54.0, 0.0, TAU, 48, Color(col.lightened(0.5), al), 5.0, true)
		UIKit.text_in(self, grade, Rect2(-54, -54, 108, 108), 92, Color(1, 1, 1, al), HORIZONTAL_ALIGNMENT_CENTER, 12, Color(col.darkened(0.7), al))
		_xf(self)

	func _draw_total() -> void:
		var y: float = PY + 498.0
		var a: float = clampf((t - _total_t0() + 0.1) / 0.3, 0.0, 1.0)
		if a <= 0.0:
			return
		var q: float = Fx.ease_out(clampf((t - _total_t0()) / _total_dur(), 0.0, 1.0))
		var val: int = int(lerpf(float(total_from), float(total_to), q))
		var done: bool = q >= 1.0
		Fx.txt(self, "TOTAL SCORE", Rect2(PX + 84.0, y, 330, 54), 30, Color(1, 1, 1, 0.85 * a), HORIZONTAL_ALIGNMENT_LEFT, 6)
		var pop: float = 1.0 + 0.22 * total_pop
		draw_set_transform(Vector2(PX + PW - 100.0, y + 27.0), 0.0, Vector2.ONE * pop)
		var col: Color = Color("4fd8ff").lerp(Color.WHITE, 0.0 if done else 0.45)
		UIKit.text_in(self, str(val), Rect2(-420.0, -30.0, 420.0, 60.0), 58, Color(col, a), HORIZONTAL_ALIGNMENT_RIGHT, 7, Color(0, 0, 0, a), Global.font_digital)
		_xf(self)

	# ---------------------------------------------------------------- cahaya (additive)
	func _draw_glow(ci: CanvasItem) -> void:
		_xf(ci)
		# halo bintang
		for k in 3:
			if k >= stars:
				continue
			var p: float = (t - (_star_t0() + 0.5 * float(k))) / 0.4
			if p <= 0.0:
				continue
			var c: Vector2 = _star_c(k)
			var hs: float = 190.0 * (1.0 + 0.5 * star_pop[k]) + 14.0 * sin(t * 4.0 + float(k))
			ci.draw_texture_rect(Fx.glow(), Rect2(c.x - hs * 0.5, c.y - hs * 0.5, hs, hs), false, Color(1.0, 0.8, 0.25, 0.5 * clampf(p, 0.0, 1.0)))
		# sinar medali rank
		var gp: float = (t - _grade_t()) / 0.35
		if gp > 0.0:
			var c2: Vector2 = _grade_c()
			var col: Color = _grade_col()
			var n: int = 10
			var rr: float = 150.0 if grade == "S" else 100.0
			for k in n:
				var a0: float = t * 0.9 + float(k) * TAU / float(n)
				var a1: float = a0 + TAU / float(n) * 0.4
				ci.draw_polygon(PackedVector2Array([c2, c2 + Vector2(cos(a0), sin(a0)) * rr, c2 + Vector2(cos(a1), sin(a1)) * rr]),
					PackedColorArray([Color(col, 0.34 * clampf(gp, 0, 1)), Color(col, 0.0), Color(col, 0.0)]))
			var gs: float = 190.0 + 40.0 * grade_pop
			ci.draw_texture_rect(Fx.glow(), Rect2(c2.x - gs * 0.5, c2.y - gs * 0.5, gs, gs), false, Color(col, 0.5 * clampf(gp, 0, 1)))
		# cahaya total skor
		if t > _total_t0() + _total_dur():
			var tc := Vector2(PX + PW - 230.0, PY + 525.0)
			ci.draw_texture_rect(Fx.glow(), Rect2(tc.x - 240.0, tc.y - 60.0, 480.0, 120.0), false, Color(0.3, 0.85, 1.0, 0.18 + 0.2 * total_pop))
		# partikel
		for q in parts:
			var lf: float = float(q["life"]) / float(q["max"])
			var sz: float = float(q["size"]) * (0.3 + 0.7 * lf)
			var qc: Color = q["col"]
			ci.draw_texture_rect(Fx.glow(), Rect2(Vector2(q["p"]) - Vector2(sz, sz) * 0.5 * 2.0, Vector2(sz, sz) * 2.0), false, Color(qc, clampf(lf * 1.6, 0.0, 1.0)))
		ci.draw_set_transform(Vector2.ZERO)

# ================================================================== pilih perk
class PerkPicker extends Control:
	signal picked(id: String)
	var ids: Array[String] = []
	var perks: Dictionary = {}
	var bonus_text: String = ""
	var sel: int = 0
	var t: float = 0.0
	var _done: bool = false
	var _pop: Array[float] = []
	const CW := 250.0
	const CH := 340.0
	const GAP := 34.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		for i in ids.size():
			_pop.append(0.0)
		var pr := UIKit.make_prompt(self)
		pr.set_prompts([[&"dpad_lr", "CHOOSE"], [&"accept", "TAKE PERK"]])

	func _card_rect(i: int) -> Rect2:
		var total: float = float(ids.size()) * CW + float(ids.size() - 1) * GAP
		var x: float = (1280.0 - total) * 0.5 + float(i) * (CW + GAP)
		var slide: float = clampf((t - 0.12 * float(i)) * 4.0, 0.0, 1.0)
		var ease_v: float = 1.0 - pow(1.0 - slide, 3.0)
		return Rect2(x, 200.0 + (1.0 - ease_v) * 120.0, CW, CH)

	func handle(action: StringName) -> void:
		match action:
			&"left":
				_move(-1)
			&"right":
				_move(1)
			&"accept", &"fire":
				_choose()

	func _move(dir: int) -> void:
		var n: int = ids.size()
		var ns: int = posmod(sel + dir, n)
		if ns != sel:
			sel = ns
			_pop[sel] = 1.0
			Global.play_sfx("ui_hover", -8.0)

	func _choose() -> void:
		if _done or t < 0.6:
			return
		_done = true
		picked.emit(ids[sel])

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			for i in ids.size():
				if _card_rect(i).has_point(event.position) and i != sel:
					sel = i
					_pop[i] = 1.0
					Global.play_sfx("ui_hover", -8.0)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for i in ids.size():
				if _card_rect(i).has_point(event.position):
					sel = i
					_choose()

	func _process(d: float) -> void:
		t += d
		for i in _pop.size():
			_pop[i] = maxf(_pop[i] - d * 4.0, 0.0)
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.08, 0.8 * clampf(t * 5.0, 0.0, 1.0)))
		var a: float = clampf(t * 4.0, 0.0, 1.0)
		UIKit.text_in(self, "CHOOSE A PERK", Rect2(0, 80, 1280, 70), 68, Color(UIKit.GOLD, a), HORIZONTAL_ALIGNMENT_CENTER, 12)
		if bonus_text != "":
			UIKit.text_in(self, bonus_text, Rect2(0, 146, 1280, 36), 28, Color("b36bff", a), HORIZONTAL_ALIGNMENT_CENTER, 7)
		for i in ids.size():
			_draw_card(i)

	func _draw_card(i: int) -> void:
		var id: String = ids[i]
		var pdata: Dictionary = CampaignData.PERKS[id]
		var col: Color = pdata["color"]
		var r: Rect2 = _card_rect(i)
		var selected: bool = i == sel
		var sc: float = 1.0 + (0.06 if selected else 0.0) + 0.08 * _pop[i]
		var c: Vector2 = r.get_center()
		draw_set_transform(c, deg_to_rad(sin(t * 3.0 + float(i)) * 0.6 if selected else 0.0), Vector2.ONE * sc)
		var tl := -r.size * 0.5
		draw_rect(Rect2(tl + Vector2(6, 8), r.size), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(tl, r.size), Color(0.06, 0.07, 0.15, 0.97).lerp(col, 0.12 if selected else 0.04))
		var border: Color = col if selected else Color(col, 0.45)
		draw_rect(Rect2(tl, r.size), border, false, 5.0 if selected else 3.0)
		draw_rect(Rect2(tl, Vector2(r.size.x, 8)), border)
		# ikon
		var path: String = "res://assets/sprites/campaign/perk_%s.png" % id
		var icon_c := Vector2(0, tl.y + 96.0 + sin(t * 3.0 + float(i) * 1.7) * 3.0)
		draw_circle(icon_c, 62.0, Color(col, 0.18))
		draw_arc(icon_c, 62.0, 0.0, TAU, 40, Color(col, 0.7), 3.0, true)
		if ResourceLoader.exists(path):
			draw_texture_rect(Global.cached_tex(path), Rect2(icon_c - Vector2(48, 48), Vector2(96, 96)), false)
		# nama
		var nm: String = String(pdata["name"])
		var nfs: int = 30
		while nfs > 16 and UIKit.text_w(nm, nfs) > r.size.x - 24.0:
			nfs -= 1
		UIKit.text_in(self, nm, Rect2(tl.x, tl.y + 170, r.size.x, 40), nfs, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 7)
		var ds: String = String(pdata["desc"])
		var dfs: int = 20
		while dfs > 12 and UIKit.text_w(ds, dfs) > r.size.x - 24.0:
			dfs -= 1
		UIKit.text_in(self, ds, Rect2(tl.x, tl.y + 214, r.size.x, 30), dfs, col.lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER, 5)
		# tumpukan
		var have: int = int(perks.get(id, 0))
		var mx: int = mini(int(pdata["max"]), 6)
		if int(pdata["max"]) <= 6:
			var step: float = 26.0
			var x0: float = -step * float(mx - 1) * 0.5
			for k in mx:
				var pc := Vector2(x0 + float(k) * step, tl.y + 276.0)
				draw_circle(pc, 9.0, Color(0, 0, 0, 0.6))
				if k < have:
					draw_circle(pc, 7.0, col)
				elif k == have:
					draw_circle(pc, 7.0, Color(col, 0.35 + 0.35 * sin(t * 8.0)))
		UIKit.text_in(self, "NEW!" if have == 0 else "LV %d > %d" % [have, have + 1], Rect2(tl.x, tl.y + 296, r.size.x, 30), 20, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 5)
		draw_set_transform(Vector2.ZERO)


# ================================================================== panel pilihan (game over / tamat)
class ChoicePanel extends Control:
	signal chosen(id: String)
	var title: String = ""
	var plate: Color = UIKit.GOLD
	var lines: Array = []
	var buttons: Array = []
	var sel: int = 0
	var _btns: Array[UIKit.FancyButton] = []
	var _ready_ms: int = 0
	var _banner: UIKit.Banner
	var defeat: bool = false     # true = tampil setelah animasi kalah (latar sudah gelap, masuknya lebih dramatis)

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		theme = Global.ui_theme
		_ready_ms = Time.get_ticks_msec() + 600
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.02, 0.08, 0.78)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		_banner = UIKit.Banner.new(title, 64, plate, Color.WHITE)
		_banner.position = Vector2(640.0 - _banner.size.x * 0.5, 100)
		add_child(_banner)
		if defeat:
			# latar sudah digelapkan animasi kalah: dim ringan yang memudar masuk, judul jatuh + membal
			dim.color = Color(0.02, 0.0, 0.04, 0.42)
			dim.modulate.a = 0.0
			UIKit.tw(dim).tween_property(dim, "modulate:a", 1.0, 0.35)
			_ready_ms = Time.get_ticks_msec() + 500
			_banner.pivot_offset = _banner.size * 0.5
			_banner.scale = Vector2.ONE * 1.7
			_banner.modulate.a = 0.0
			var btw := UIKit.tw(_banner)
			btw.set_parallel(true)
			btw.tween_property(_banner, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			btw.tween_property(_banner, "modulate:a", 1.0, 0.2)
			btw.chain().tween_callback(func() -> void:
				# getaran kecil saat judul mendarat
				var st := UIKit.tw(_banner)
				var bx: float = 640.0 - _banner.size.x * 0.5
				for k in 4:
					st.tween_property(_banner, "position:x", bx + (7.0 - 2.0 * float(k)) * (1.0 if k % 2 == 0 else -1.0), 0.04)
				st.tween_property(_banner, "position:x", bx, 0.05))
		else:
			_banner.scale = Vector2.ONE * 0.3
			UIKit.tw(_banner).tween_property(_banner, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var y: float = 230.0
		var li: int = 0
		for l in lines:
			var lb := UIKit.label(String(l[0]), 30, l[1], 7)
			lb.size = Vector2(1280, 40)
			lb.position = Vector2(0, y)
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			add_child(lb)
			if defeat:
				# tiap baris naik pelan sambil memudar masuk, berurutan
				lb.modulate.a = 0.0
				lb.position.y = y + 18.0
				var ltw := UIKit.tw(lb)
				ltw.set_parallel(true)
				ltw.tween_property(lb, "position:y", y, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.22 + 0.1 * float(li))
				ltw.tween_property(lb, "modulate:a", 1.0, 0.3).set_delay(0.22 + 0.1 * float(li))
			li += 1
			y += 44.0
		y += 24.0
		for i in buttons.size():
			var b := UIKit.FancyButton.new(String(buttons[i][1]), Vector2(600, 64), 34)
			var base := Vector2(340, y + float(i) * 78.0)
			b.position = base + Vector2(-90, 0)
			b.modulate.a = 0.0
			add_child(b)
			var tw := UIKit.tw(b)
			tw.set_parallel(true)
			tw.tween_property(b, "position", base, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3 + 0.06 * float(i))
			tw.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(0.3 + 0.06 * float(i))
			var id: String = String(buttons[i][0])
			var idx: int = i
			b.hovered.connect(func() -> void: _select(idx))
			b.activated.connect(func() -> void: _pick(id))
			_btns.append(b)
		_select(0, false)
		var pr := UIKit.make_prompt(self)
		pr.set_prompts([[&"dpad_ud", "NAVIGATE"], [&"accept", "SELECT"]])

	func _select(i: int, sound: bool = true) -> void:
		if i == sel and sound:
			return
		sel = i
		for k in _btns.size():
			_btns[k].set_selected(k == i)
		if sound:
			Global.play_sfx("ui_hover", -8.0)

	func _pick(id: String) -> void:
		if Time.get_ticks_msec() < _ready_ms:
			return
		chosen.emit(id)

	func handle(action: StringName) -> void:
		match action:
			&"up":
				_select(posmod(sel - 1, _btns.size()))
			&"down":
				_select(posmod(sel + 1, _btns.size()))
			&"accept", &"fire":
				_pick(String(buttons[sel][0]))
