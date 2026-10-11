class_name AiBrain
extends RefCounted
## Otak musuh campaign. Menghasilkan input yang SAMA dengan yang dibaca pemain manusia
## ({move, jump, down, shoot, swap}), jadi musuh memakai fisika, senjata, peluru, power up
## dan rintangan arena yang persis sama dengan pemain.
##
## Perilaku: cari jalan lewat NavMap (lompat / turun platform / jamur pantul), jaga jarak tempur sesuai
## senjata, menembak dalam rentetan (burst) setelah waktu reaksi, menghindar peluru, tidak jatuh ke lava,
## melompati duri, dan mengisi ulang peluru. Boss punya sifat tambahan: dash, leap.

var game: Node
var stats: Dictionary = {}
var rng := RandomNumberGenerator.new()

var node_id: int = -1
var frozen: float = 0.0           # >0: membeku (tidak bergerak / menembak)
var think_delay: float = 0.0      # jeda awal setelah muncul

var _frame: int = 0
var _react: float = 0.0
var _seen_t: float = 0.0
var _burst_left: int = 0
var _pause: float = 0.0
var _last_cd: float = 0.0
var _dodge_cd: float = 0.0
var _stuck_t: float = 0.0
var _last_x: float = 0.0
var _jump_hold: float = 0.0
var _reload_t: float = 0.0
var _strafe_dir: int = 1
var _strafe_t: float = 0.0
var _goal_x: float = 0.0
var _air_dir: float = 0.0
var _dash_t: float = 0.0
var _dash_cd: float = 4.0
var _leap_cd: float = 3.0
var _edge_kind: String = ""
var _los_cache: bool = false
var _los_t: float = 0.0


func setup(g: Node, st: Dictionary, seed_val: int) -> void:
	game = g
	stats = st
	rng.seed = seed_val
	_strafe_dir = 1 if rng.randf() < 0.5 else -1
	_strafe_t = rng.randf_range(0.8, 2.0)
	_dash_cd = rng.randf_range(3.0, 6.0)
	_leap_cd = rng.randf_range(2.0, 5.0)
	_burst_left = 0
	_pause = rng.randf_range(0.2, 0.6)


func _has_trait(t: String) -> bool:
	return (stats.get("traits", []) as Array).has(t)


func think(p: Player, delta: float) -> Dictionary:
	var out := {"move": 0.0, "jump": false, "down": false, "shoot": false, "swap": false}
	_frame += 1
	if frozen > 0.0:
		frozen -= delta
		return out
	if think_delay > 0.0:
		think_delay -= delta
		return out
	var hero: Player = game.hero
	if hero == null or not is_instance_valid(hero) or not hero.alive or hero.vanished:
		return out
	var nav: NavMap = game.nav

	_dodge_cd = maxf(_dodge_cd - delta, 0.0)
	_jump_hold = maxf(_jump_hold - delta, 0.0)
	_strafe_t -= delta
	_pause = maxf(_pause - delta, 0.0)
	_dash_t = maxf(_dash_t - delta, 0.0)
	_dash_cd -= delta
	_leap_cd -= delta
	_los_t -= delta

	_reload(p, delta)

	var px: float = p.global_position.x
	var feet := Vector2(px, p.global_position.y + 30.0 * p.size_mult)
	var on_floor: bool = p.is_on_floor()
	if on_floor:
		node_id = nav.node_at(feet, node_id)
	var hfeet := Vector2(hero.global_position.x, hero.global_position.y + 30.0)
	var tnode: int = nav.node_at(hfeet, -1)

	var dx: float = hero.global_position.x - px
	var dy: float = hero.global_position.y - p.global_position.y
	var adx: float = absf(dx)
	var ady: float = absf(dy)
	var dirx: float = signf(dx) if absf(dx) > 1.0 else float(p.facing)
	var weapon_range: float = float(stats["range"])
	var knife_user: bool = bool(stats.get("knife_only", false))
	var tol: float = float(stats["aim_tol"]) * p.size_mult
	var los: bool = _line_of_sight(p, hero)

	# ---------------- menembak
	var aligned: bool = ady <= tol and los
	var in_reach: bool = adx <= weapon_range * 1.25
	if knife_user:
		in_reach = adx <= 70.0 * p.size_mult and ady <= 52.0 * p.size_mult
	var facing_ok: bool = p.facing == int(dirx)
	if aligned and in_reach:
		_seen_t += delta
	else:
		_seen_t = maxf(_seen_t - delta * 2.0, 0.0)
		if _seen_t <= 0.0:
			_react = float(stats["reaction"])
	if aligned and in_reach and facing_ok and _seen_t > 0.0:
		_react = maxf(_react - delta, 0.0)
		if _react <= 0.0 and _pause <= 0.0:
			var auto: bool = bool(Global.WEAPONS[p.current_weapon()].get("auto", false))
			if auto:
				out["shoot"] = true
			else:
				out["shoot"] = (_frame % 2 == 0)
			if _burst_left <= 0:
				var b: Array = stats["burst"]
				_burst_left = rng.randi_range(int(b[0]), int(b[1]))
	# hitung rentetan: tiap tembakan (cooldown naik) mengurangi sisa burst
	if p.shoot_cd > _last_cd + 0.04:
		_burst_left -= 1
		if _burst_left <= 0:
			_burst_left = 0
			_pause = rng.randf_range(0.45, 1.1) * float(stats.get("rate", 1.0))
	_last_cd = p.shoot_cd

	# ---------------- bergerak
	var move: float = 0.0
	var same_level: bool = ady <= tol + 20.0 and (tnode == node_id or los)
	if _dash_t > 0.0 and on_floor:
		move = dirx
		if adx > 20.0:
			out["move"] = move
	if same_level and _dash_t <= 0.0:
		move = _engage(p, dirx, adx, weapon_range, knife_user)
	elif _dash_t <= 0.0:
		move = _navigate(p, nav, node_id, tnode, hero, out, on_floor)
	if _dash_t > 0.0:
		move = dirx
	# selalu menghadap pemain saat berdiri (supaya bisa menembak)
	if absf(move) < 0.01 and aligned:
		move = dirx * 0.05

	# ---------------- keselamatan: tepi platform & rintangan darat
	move = _safe_move(p, nav, move, on_floor, same_level, out)

	# ---------------- boss: dash & leap
	if _has_trait("dash") and _dash_cd <= 0.0 and adx > 140.0 and on_floor and _seen_t > 0.1:
		_dash_cd = rng.randf_range(5.5, 8.5)
		_dash_t = 1.1
		p.speed_time = 1.1
		p.status_changed.emit(p)
		Global.play_sfx("whoosh_dash", -6.0)
	if _has_trait("leap") and _leap_cd <= 0.0 and adx > 170.0 and on_floor:
		_leap_cd = rng.randf_range(3.5, 6.0)
		out["jump"] = true
		_jump_hold = 0.5
		move = dirx

	# ---------------- menghindar peluru
	if on_floor and _dodge_cd <= 0.0:
		if _incoming_bullet(p) and rng.randf() < float(stats["dodge"]):
			out["jump"] = true
			_jump_hold = 0.4
			_dodge_cd = 0.9
			if rng.randf() < 0.5:
				move = -dirx * 0.8

	# ---------------- anti macet
	if on_floor and absf(move) > 0.3:
		if absf(px - _last_x) < 3.0 * delta * 60.0 * 0.1:
			_stuck_t += delta
		else:
			_stuck_t = 0.0
		if _stuck_t > 0.9:
			_stuck_t = 0.0
			out["jump"] = true
			_jump_hold = 0.5
			_strafe_dir = -_strafe_dir
	else:
		_stuck_t = 0.0
	_last_x = px

	out["move"] = move
	if _jump_hold > 0.0:
		out["jump"] = true
	return out


# ------------------------------------------------------------------ pertarungan di tingkat yang sama
func _engage(p: Player, dirx: float, adx: float, weapon_range: float, knife_user: bool) -> float:
	if knife_user:
		return dirx if adx > 30.0 * p.size_mult else 0.0
	if adx > weapon_range:
		return dirx
	if adx < weapon_range * 0.5:
		return -dirx * 0.9
	# di rentang yang pas: sesekali melangkah ke samping supaya sulit dibidik
	if _strafe_t <= 0.0:
		_strafe_t = rng.randf_range(0.8, 2.2)
		_strafe_dir = 1 if rng.randf() < 0.5 else -1
	if stats.get("weapon", "") == "scream":
		return 0.0
	return float(_strafe_dir) * 0.45


# ------------------------------------------------------------------ navigasi antar platform
func _navigate(p: Player, nav: NavMap, from: int, to: int, hero: Player, out: Dictionary, on_floor: bool) -> float:
	var px: float = p.global_position.x
	var hx: float = hero.global_position.x
	if from < 0:
		return signf(hx - px)
	if to < 0 or from == to:
		# pemain di udara di atas / dekat platform yang sama: dekati saja
		return signf(hx - px) if absf(hx - px) > 30.0 else 0.0
	var e: Dictionary = nav.next_edge(from, to, hero.global_position)
	if e.is_empty():
		return signf(hx - px)
	var kind: String = String(e["kind"])
	var a: Dictionary = nav.cur(from)
	var b: Dictionary = nav.cur(int(e["to"]))
	var bx0: float = float(b["x0"])
	var bx1: float = float(b["x1"])
	var cx: float = (bx0 + bx1) * 0.5
	_edge_kind = kind
	if not on_floor:
		# di udara: terus bergerak ke arah tujuan
		var tgt: float = _goal_x if _goal_x != 0.0 else cx
		if kind == "pad":
			tgt = cx
		return signf(tgt - px) if absf(tgt - px) > 12.0 else 0.0
	match kind:
		"up":
			var tx: float = clampf(px, bx0 + 26.0, bx1 - 26.0)
			_goal_x = tx
			var gap: float = maxf(maxf(bx0 - px, px - bx1), 0.0)
			if gap <= 0.0:
				out["jump"] = true
				_jump_hold = 0.55
				return 0.0 if absf(px - tx) < 8.0 else signf(tx - px) * 0.6
			var rise: float = float(a["y"]) - float(b["y"])
			if gap <= NavMap.reach_up(rise) * 0.55 and _near_edge(a, px, signf(tx - px)):
				out["jump"] = true
				_jump_hold = 0.55
			return signf(tx - px)
		"gap":
			var dir: float = signf(cx - px)
			_goal_x = clampf(px + dir * 200.0, bx0 + 20.0, bx1 - 20.0)
			if _near_edge(a, px, dir):
				out["jump"] = true
				_jump_hold = 0.55
			return dir
		"drop_through":
			var lo: float = maxf(float(a["x0"]), bx0) + 22.0
			var hi: float = minf(float(a["x1"]), bx1) - 22.0
			if hi < lo:
				lo = (lo + hi) * 0.5
				hi = lo
			var tx2: float = clampf(hx, lo, hi)
			if absf(px - tx2) < 10.0:
				out["down"] = true
				return 0.0
			return signf(tx2 - px)
		"drop_side":
			# keluar dari platform lewat sisi yang menghadap pemain (kalau pemain tepat di bawah: sisi terdekat)
			var dir3: float
			var ax0: float = float(a["x0"])
			var ax1: float = float(a["x1"])
			if hx < ax0:
				dir3 = -1.0
			elif hx > ax1:
				dir3 = 1.0
			else:
				dir3 = -1.0 if (px - ax0) < (ax1 - px) else 1.0
			var tx3: float = clampf(hx, bx0 + 20.0, bx1 - 20.0)
			_goal_x = tx3
			var gx: float = maxf(maxf(bx0 - float(a["x1"]), float(a["x0"]) - bx1), 0.0)
			if gx > 70.0 and _near_edge(a, px, dir3):
				out["jump"] = true
				_jump_hold = 0.5
			return dir3
		"pad":
			var padx: float = float(e["pad_x"])
			_goal_x = cx
			return signf(padx - px) if absf(padx - px) > 6.0 else 0.0
	return signf(hx - px)


func _near_edge(a: Dictionary, px: float, dir: float) -> bool:
	var edge: float = float(a["x1"]) if dir > 0.0 else float(a["x0"])
	return absf(edge - px) < 46.0


# ------------------------------------------------------------------ keselamatan
func _safe_move(p: Player, nav: NavMap, move: float, on_floor: bool, engaging: bool, out: Dictionary) -> float:
	if absf(move) < 0.01 or not on_floor:
		return move
	var px: float = p.global_position.x
	var feet_y: float = p.global_position.y + 30.0 * p.size_mult
	var dir: float = signf(move)
	# 1) tidak berjalan keluar dari platform saat bertarung (kecuali sedang menyeberang lewat navigasi)
	if engaging and node_id >= 0:
		var c: Dictionary = nav.cur(node_id)
		if (dir > 0.0 and px + 30.0 > float(c["x1"])) or (dir < 0.0 and px - 30.0 < float(c["x0"])):
			return 0.0
	# 2) duri / lava di depan: lompati kalau sempit, kalau tidak berhenti
	for r in game.hazard_rects:
		var rect: Rect2 = r
		if feet_y < rect.position.y - 8.0 or feet_y > rect.end.y + 70.0:
			continue
		var ahead: float = (rect.position.x - px) if dir > 0.0 else (px - rect.end.x)
		var inside: bool = px >= rect.position.x - 4.0 and px <= rect.end.x + 4.0
		if inside:
			continue
		if ahead > -4.0 and ahead < 78.0:
			if rect.size.x <= 190.0 and not _is_pit(rect):
				out["jump"] = true
				_jump_hold = 0.6
				return dir
			return 0.0
	return move


## Lava (terbenam di bawah lantai) tidak bisa dilompati dari lantai biasa.
func _is_pit(rect: Rect2) -> bool:
	return rect.size.y >= 50.0 and rect.end.y >= 700.0


func _incoming_bullet(p: Player) -> bool:
	var root: Node = game.bullets_root
	if root == null:
		return false
	for c in root.get_children():
		var b := c as Bullet
		if b == null or b.team == 1:
			continue
		var rel: float = (p.global_position.x - b.global_position.x) * float(b.dir)
		if rel < 20.0 or rel > 360.0:
			continue
		if absf(b.global_position.y - p.global_position.y) < 38.0 * p.size_mult:
			return true
	return false


func _line_of_sight(p: Player, hero: Player) -> bool:
	if _los_t > 0.0:
		return _los_cache
	_los_t = 0.08
	var space: PhysicsDirectSpaceState2D = p.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(p.global_position, hero.global_position, 1)
	_los_cache = space.intersect_ray(q).is_empty()
	return _los_cache


func _reload(p: Player, delta: float) -> void:
	var mx: int = p.max_ammo()
	if mx < 0 or p.knife_only:
		return
	if p.ammo <= 0:
		_reload_t += delta
		if _reload_t > 3.2:
			_reload_t = 0.0
			p._refill_ammo()
	else:
		_reload_t = 0.0
