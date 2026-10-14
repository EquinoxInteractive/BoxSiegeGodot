class_name ReplayRecorder
extends RefCounted
## Perekam replay untuk mode VERSUS. Dibuat oleh game.gd saat match dimulai, di-tick tiap frame fisika.
##
## Cara kerja: bukan merekam input, tapi merekam KEADAAN dunia (posisi pemain, peluru, power up, rintangan) beberapa kali
## per detik ("snapshot"). Pemutar (replay_world.gd) menggambar ulang snapshot itu dan menginterpolasinya, sehingga
## replay selalu sama persis dengan yang terjadi walaupun ada fisika / random di dalam game.
##
## Susunan satu snapshot = PackedFloat32Array:
##   [0..H-1]  header: t, state, time_left, sudden_death, round, jumlah_peluru, jumlah_powerup, jumlah_panah
##   lalu      P x PS  float data tiap pemain (lihat konstanta PL_*)
##   lalu      M x 2   posisi platform bergerak,  S x 2 posisi gergaji,  C x 2 (mode, alpha) platform rapuh
##   lalu      peluru (6 float), power up (5 float), panah jebakan (5 float)

const H := 8                    # panjang header snapshot
const PS := 25                  # jumlah float per pemain
const BUL := 6
const PUP := 5
const ARW := 5

# indeks di dalam blok pemain
const PL_X := 0
const PL_Y := 1
const PL_FACE := 2
const PL_ALIVE := 3
const PL_HP := 4
const PL_VANISHED := 5
const PL_WEAPON := 6
const PL_KICK := 7
const PL_KNIFE_T := 8
const PL_SWAP_ANIM := 9
const PL_AMMO := 10
const PL_INVIS := 11
const PL_SHIELD_HITS := 12
const PL_SHIELD_TIME := 13
const PL_SWAP_TIME := 14
const PL_SPEED := 15
const PL_JUMP := 16
const PL_INVULN := 17
const PL_SQ_X := 18
const PL_SQ_Y := 19
const PL_ALPHA := 20
const PL_FLASH := 21
const PL_BODY_SHOWN := 22
const PL_WINS := 23
const PL_KILLS := 24

var game: Node
var hz: int = 30
var interval: float = 1.0 / 30.0
var time: float = 0.0                 # waktu rekaman (detik, hanya menghitung waktu main - pause tidak ikut)
var acc: float = 0.0
var active: bool = false
var finished: bool = false

var flat: PackedFloat32Array = PackedFloat32Array()
var starts: PackedInt32Array = PackedInt32Array()

var weapons: Array = []               # daftar id senjata / peluru -> indeks
var pu_types: Array = []              # daftar tipe power up -> indeks
var rounds: Array = []                # [{num, start, end, winner, winner_label, winner_color}]
var events: Array = []                # [{t, type, killer, victim, round}]
var header: Dictionary = {}

var _ids: Dictionary = {}             # instance id -> nomor kecil
var _next_id: int = 1
var _p_count: int = 0
var _m_count: int = 0
var _s_count: int = 0
var _c_count: int = 0


## Mulai merekam. g = game.gd (sudah selesai _build_players / _build_world).
func begin(g: Node) -> void:
	game = g
	ReplayStore.ensure_loaded()
	hz = ReplayStore.record_hz()
	interval = 1.0 / float(hz)
	_p_count = g.players.size()
	_m_count = g.moving_platforms.size()
	_s_count = g.saws.size()
	_c_count = g.crumbles.size()

	var plist: Array = []
	for p in g.players:
		var pl: Player = p
		var tid: int = int(g.team_ids[pl.index])
		plist.append({
			"index": pl.index,
			"char": pl.char_idx,
			"weapon": pl.weapon_id,
			"name": Global.character_name(pl.index, pl.char_idx),
			"color": Global.PLAYER_COLORS[pl.index],
			"skin": pl.skin_id,
			"wskins": pl.wskins.duplicate(),
			"loadout": pl.loadout_data.duplicate(),
			"team": tid,
			"team_color": Global.team_color(tid) if g.team_mode else Global.PLAYER_COLORS[pl.index],
			"team_level": Global.team_nerf_level(tid) if g.team_mode else 0,
		})
	header = {
		"map": g.map.duplicate(true),
		"map_id": String(g.map.get("id", "earth")),
		"map_name": String(Global.MAPS.get(String(g.map.get("id", "earth")), {}).get("name", "ARENA")),
		"hz": hz,
		"players": plist,
		"team_mode": g.team_mode,
		"team_ids": g.team_ids.duplicate(),
		"wins_to_match": Global.WINS_TO_MATCH,
		"match_time": Global.match_time,
		"counts": [_p_count, _m_count, _s_count, _c_count],
	}
	active = true
	_capture()           # snapshot pertama (t = 0)


# ------------------------------------------------------------------ tick
func tick(delta: float) -> void:
	if not active:
		return
	time += delta
	acc += delta
	if acc >= interval:
		acc = fmod(acc, interval)
		_capture()


## Paksa satu snapshot sekarang (dipakai di momen penting: akhir ronde / akhir match).
func force_capture() -> void:
	if active:
		_capture()


func duration() -> float:
	return time


func frame_count() -> int:
	return starts.size()


# ------------------------------------------------------------------ event
func on_round_start(num: int) -> void:
	if not active:
		return
	rounds.append({"num": num, "start": time, "end": -1.0, "winner": -2, "winner_label": "", "winner_color": Color.WHITE})


## winner = nomor tim pemenang ronde (-1 = seri).
func on_round_end(winner: int, label: String, color: Color) -> void:
	if not active or rounds.is_empty():
		return
	var r: Dictionary = rounds[rounds.size() - 1]
	r["end"] = time
	r["winner"] = winner
	r["winner_label"] = label
	r["winner_color"] = color
	force_capture()


## killer = nomor pemain pembunuh (-1 = bukan pemain: lava, duri, jatuh, panah jebakan).
func on_death(killer: int, victim: int) -> void:
	if not active:
		return
	var rn: int = 0
	if not rounds.is_empty():
		rn = int((rounds[rounds.size() - 1] as Dictionary)["num"])
	events.append({"t": time, "type": "kill" if killer >= 0 and killer != victim else "death",
		"killer": killer, "victim": victim, "round": rn})


# ------------------------------------------------------------------ indeks
func _wid(id: String) -> int:
	var i: int = weapons.find(id)
	if i < 0:
		weapons.append(id)
		i = weapons.size() - 1
	return i


func _pid(id: String) -> int:
	var i: int = pu_types.find(id)
	if i < 0:
		pu_types.append(id)
		i = pu_types.size() - 1
	return i


func _stable_id(inst_id: int, fresh: Dictionary) -> int:
	var n: int = int(_ids.get(inst_id, 0))
	if n == 0:
		n = _next_id
		_next_id += 1
	fresh[inst_id] = n
	return n


# ------------------------------------------------------------------ snapshot
func _capture() -> void:
	var g: Node = game
	var f := PackedFloat32Array()

	var bullets: Array = []
	for c in g.bullets_root.get_children():
		if c is Bullet and not c.is_queued_for_deletion():
			bullets.append(c)
	var pups: Array = []
	for c in g.powerups_root.get_children():
		if c is Powerup and not c.is_queued_for_deletion():
			pups.append(c)
	var arrows: Array = []
	if g.traps_root != null:
		for c in g.traps_root.get_children():
			if c is Hazards.Arrow and not c.is_queued_for_deletion():
				arrows.append(c)

	f.append(time)
	f.append(float(g.state))
	f.append(float(g.time_left))
	f.append(1.0 if g.sudden_death else 0.0)
	f.append(float(g.round_num))
	f.append(float(bullets.size()))
	f.append(float(pups.size()))
	f.append(float(arrows.size()))

	for p in g.players:
		var pl: Player = p
		var shown: String = pl.shown_weapon if pl.shown_weapon != "" else pl.weapon_id
		var base: float = maxf(pl.base_scale, 0.0001)
		f.append(pl.global_position.x)
		f.append(pl.global_position.y)
		f.append(float(pl.facing))
		f.append(1.0 if pl.alive else 0.0)
		f.append(pl.hp)
		f.append(1.0 if pl.vanished else 0.0)
		f.append(float(_wid(shown)))
		f.append(pl.kick)
		f.append(pl.knife_t)
		f.append(pl.swap_anim)
		f.append(float(pl.ammo))
		f.append(pl.invis_time)
		f.append(float(pl.shield_hits))
		f.append(pl.shield_time)
		f.append(pl.swap_time)
		f.append(pl.speed_time)
		f.append(pl.jump_time)
		f.append(pl.invuln)
		f.append(pl.body_sprite.scale.x / base)
		f.append(pl.body_sprite.scale.y / base)
		f.append(pl.modulate.a)
		f.append(pl.body_sprite.modulate.g)
		f.append(1.0 if pl.body_sprite.visible else 0.0)
		f.append(float(g.wins[pl.index]))
		f.append(float(g.kills[pl.index]))

	for mp in g.moving_platforms:
		f.append(mp.position.x)
		f.append(mp.position.y)
	for sw in g.saws:
		f.append(sw.position.x)
		f.append(sw.position.y)
	for cp in g.crumbles:
		f.append(float(cp.mode))
		f.append(cp.art.modulate.a)

	var fresh: Dictionary = {}
	for b in bullets:
		var bu: Bullet = b
		f.append(float(_stable_id(bu.get_instance_id(), fresh)))
		f.append(bu.global_position.x)
		f.append(bu.global_position.y)
		f.append(float(bu.dir))
		f.append(float(_wid(bu.weapon)))
		f.append(float(bu.shooter))
	for pu in pups:
		var po: Powerup = pu
		f.append(float(_stable_id(po.get_instance_id(), fresh)))
		f.append(po.global_position.x)
		f.append(po.global_position.y)
		f.append(float(_pid(po.type)))
		f.append(po.life)
	for ar in arrows:
		var a: Hazards.Arrow = ar
		f.append(float(_stable_id(a.get_instance_id(), fresh)))
		f.append(a.global_position.x)
		f.append(a.global_position.y)
		f.append(float(a.dir))
		f.append(1.0 if a.kind == "cannon" else 0.0)
	_ids = fresh

	starts.append(flat.size())
	flat.append_array(f)


# ------------------------------------------------------------------ selesai
## Hentikan rekaman & kemas jadi {meta, data}. completed = true kalau match selesai sampai ada pemenang.
func finish(completed: bool, winner_team: int, winner_label: String, winner_color: Color, score_text: String) -> Dictionary:
	if not active or finished:
		return {}
	_capture()
	active = false
	finished = true
	if not rounds.is_empty():
		var last: Dictionary = rounds[rounds.size() - 1]
		if float(last["end"]) < 0.0:
			last["end"] = time

	var n_kills: int = 0
	for e in events:
		if String((e as Dictionary)["type"]) == "kill":
			n_kills += 1
	var plist: Array = header["players"]
	var pm: Array = []
	for p in plist:
		var pd: Dictionary = p
		pm.append({"char": pd["char"], "name": pd["name"], "color": pd["color"], "team": pd["team"], "team_color": pd["team_color"]})
	var meta: Dictionary = {
		"duration": time,
		"map_id": header["map_id"],
		"map_name": header["map_name"],
		"player_count": plist.size(),
		"players": pm,
		"team_mode": header["team_mode"],
		"rounds": rounds.size(),
		"kills": n_kills,
		"finished": completed,
		"winner_team": winner_team,
		"winner_label": winner_label,
		"winner_color": winner_color,
		"score": score_text,
		"hz": hz,
	}
	var data: Dictionary = {
		"header": header,
		"weapons": weapons,
		"pu_types": pu_types,
		"rounds": rounds,
		"events": events,
		"starts": starts,
		"flat": flat,
	}
	return {"meta": meta, "data": data}
