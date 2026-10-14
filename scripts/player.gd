class_name Player
extends CharacterBody2D
## Satu pemain: gerak, lompat, tembak / pisau, darah, dan efek power up.

signal died(player: Player)
signal status_changed(player: Player)

const WeaponFx = preload("res://scripts/weapon_fx.gd")

const SIZE := 60.0
const GRAVITY := 2000.0
const MOVE_SPEED := 340.0
const ACCEL := 2800.0
const FRICTION := 3200.0
const JUMP_VELOCITY := -760.0
const COYOTE := 0.08
const BOOST_DURATION := 10.0     # Speed Boost & Jump Boost (detik)
const SHIELD_DURATION := 7.0     # Shield aktif maksimal 7 detik
const SHIELD_HITS := 2           # Shield pecah setelah menahan 2 tembakan
const INVISIBLE_DURATION := 3.0  # Invisible (detik)
const SWAP_WINDOW := 3.0         # waktu untuk memakai Swap Position (detik)
const SPEED_BOOST := 1.5
const JUMP_BOOST := 1.35
const SWITCH_TIME := 0.2        # jeda setelah ganti senjata <-> pisau (detik)
const DRAW_TIME := 0.4          # jeda menarik pistol setelah peluru Scream habis
const BUFFER_TIME := 0.12       # tap yang ditekan sedikit sebelum jeda selesai tetap dihitung
const GRIP_X := 16.0            # jarak pangkal senjata (genggaman) dari tengah badan
const KNIFE_MUZZLE_X := 56.0    # (dipakai efek tebasan)
const PICKUP_FLASH := 1.6       # lama kartu power up instan (HEAL / AMMO) tampil di HUD (detik)

## Info tampilan tiap power up: nama + warna khas. Dipakai kartu HUD (game.gd),
## penanda di atas kepala pemain, dan efek saat mengambil power up.
const PU_INFO := {
	"heal": {"name": "HEAL", "color": Color("4be3a0")},
	"speed": {"name": "SPEED", "color": Color("ff5d4d")},
	"jump": {"name": "JUMP", "color": Color("3d8bff")},
	"shield": {"name": "SHIELD", "color": Color(0.45, 0.85, 1.0)},
	"invisible": {"name": "INVISIBLE", "color": Color("b36bff")},
	"ammo_refill": {"name": "AMMO", "color": Color("ff9d2e")},
	"swap_position": {"name": "SWAP", "color": Color("8ed457")},
	# power up khusus CAMPAIGN (tidak muncul di mode versus)
	"nuke": {"name": "NUKE", "color": Color("ff6a2a")},
	"freeze": {"name": "FREEZE", "color": Color("8fe8ff")},
}

## Kontrol (keyboard & controller) tiap pemain ada di Global.key_bindings / Global.pad_bindings
## dan bisa diubah di SETTINGS > CONTROLS SETUP. Perangkat pemain: Global.device_of(index).

## --- Mode CAMPAIGN (single player): tim, otak AI, dan pengali. Semua bernilai netral di mode versus.
var team: int = -1                 # -1 = versus (semua saling serang); 0 = pemain campaign; 1 = musuh
var brain: RefCounted = null       # AiBrain (musuh). null = dikendalikan keyboard / controller
var max_hp: float = float(Global.MAX_HP)
var size_mult: float = 1.0         # boss lebih besar
var speed_scale: float = 1.0       # pengali kecepatan lari
var jump_scale: float = 1.0        # pengali tinggi lompat
var dmg_out: float = 1.0           # pengali damage peluru / pisau yang dikeluarkan
var dmg_in: float = 1.0            # pengali damage yang diterima
var rate_scale: float = 1.0        # pengali jeda tembak (kecil = lebih cepat)
var ammo_mult: float = 1.0         # pengali jumlah peluru senjata utama
var knife_mult: float = 1.0        # pengali damage pisau
var killer: int = -1              # versus: nomor pemain yang memberi pukulan mematikan (-1 = bukan pemain, mis. lava)
var nerf_dmg: float = 1.0          # TEAM: pengali damage peluru untuk tim yang lebih banyak anggotanya (lihat nerf_mult)
var team_level: int = 0            # TEAM: level nerf tim ini (0 = seimbang)
var team_mark: TeamMark = null     # TEAM: pelat warna tim di belakang nama
var body_shape: CollisionShape2D

var index: int = 0
var char_idx: int = 0
# ---- kosmetik (skin & aksesoris dari Shop/Inventory); kosong = tampilan asli
var skin_id: String = ""                  # skin karakter
var wskins: Dictionary = {}               # weapon_id -> skin_id
var loadout_data: Dictionary = {}         # aksesoris yang terpasang (slot -> acc_id), milik pemain ini
var acc_nodes: Array = []                 # sprite aksesoris yang terpasang
var weapon_id: String = "smith"      # senjata utama pilihan pemain (smith / kurval / flamer / scream)
var game: Node = null

var hp: float = 3.0
var alive: bool = true
var facing: int = 1
var controls_enabled: bool = false
var respawn_pos: Vector2 = Vector2(640, 300)

var speed_time: float = 0.0
var jump_time: float = 0.0
var shield_time: float = 0.0       # sisa waktu Shield
var shield_hits: int = 0           # sisa tembakan yang bisa ditahan Shield (0 = tidak ada Shield)
var invis_time: float = 0.0        # sisa waktu Invisible
var swap_time: float = 0.0         # sisa waktu Swap Position (selama > 0 pemain tidak bisa menembak; tombol tembak = tukar posisi)
var recent_pickup: String = ""     # power up instan terakhir (heal / ammo_refill) -> kartu sementara di HUD
var recent_pickup_note: String = ""  # teks kartu: "+1", "FULL"
var recent_pickup_time: float = 0.0
var fire_lock: bool = false        # true = tombol tembak harus DILEPAS dulu sebelum boleh menembak lagi (setelah swap / swap habis)
var shoot_cd: float = 0.0
var invuln: float = 0.0
var drop_timer: float = 0.0
var coyote_timer: float = 0.0
var jump_was_down: bool = false

# --- senjata
var ammo: int = 0                  # sisa peluru senjata utama
var knife_out: bool = false        # true = sedang memegang pisau
var knife_only: bool = false       # true = SUDDEN DEATH: hanya boleh pakai pisau, tidak bisa ganti senjata
var shoot_was_down: bool = false
var swap_was_down: bool = false
var fire_buffer: float = 0.0
var shown_weapon: String = ""      # senjata yang sedang tampil di tangan
var sfx_cd: float = 0.0
var empty_text_cd: float = 0.0
var hit_sfx_cd: float = 0.0
var knife_hit_t: float = -1.0      # hitung mundur sampai bilah mengenai (<0 = tidak sedang menebas)
var knife_t: float = -1.0          # waktu animasi tebasan (<0 = tidak sedang menebas)
var kick: float = 0.0              # hentakan senjata (pegas, kembali halus)
var kick_v: float = 0.0
var swap_anim: float = 0.0         # animasi ganti senjata 1 -> 0
var gun_base_scale: float = 0.1
var gun_tex_w: float = 100.0
var gun_len: float = 56.0         # panjang senjata yang dipegang (px)

var body_sprite: Sprite2D
var gun_sprite: Sprite2D
var tag: Label
var fx: StatusFx                   # gambar Shield & penanda Swap Position
var base_scale: float = SIZE / 180.0
var was_on_floor: bool = false
var squash_tw: Tween
var flash_tw: Tween
var step_t: float = 0.0
var vanished: bool = false     # true = pemain sudah "hilang" (mati di lava / jatuh): fisika & input dibekukan sampai reset()
var launch_cd: float = 0.0        # jeda singkat agar jamur pantul tidak memicu berkali-kali
var launched: bool = false        # true selama melesat naik dari jamur pantul (tidak kena pemotong lompat)
var _reset_id: int = 0         # penanda reset terakhir, supaya aktivasi collision yang tertunda tidak bentrok dengan reset berikutnya


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	collision_layer = 4          # layer 3 = pemain
	collision_mask = 3           # layer 1 (lantai) + layer 2 (platform)

	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(50, 60)
	cs.shape = shape
	add_child(cs)
	body_shape = cs

	body_sprite = Sprite2D.new()
	body_sprite.scale = Vector2.ONE * base_scale
	add_child(body_sprite)

	gun_sprite = Sprite2D.new()
	add_child(gun_sprite)

	tag = Label.new()
	tag.custom_minimum_size = Vector2(60, 0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.position = Vector2(-30, -66)
	tag.add_theme_font_override("font", Global.font_ui)
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_constant_override("outline_size", 8)
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(tag)

	fx = StatusFx.new()
	fx.p = self
	fx.z_index = 1
	add_child(fx)


func setup(idx: int, character: int, weapon: String, game_node: Node) -> void:
	index = idx
	char_idx = character
	weapon_id = weapon if Global.WEAPONS.has(weapon) else "smith"
	game = game_node
	ammo = max_ammo()
	shown_weapon = ""
	_sync_weapon(false)
	# label di atas kepala = nama karakter yang dipakai (warna tetap warna pemain), dipusatkan sesuai lebar teks
	tag.text = Global.character_name(idx, char_idx)
	var tag_fs: int = 22
	while tag_fs > 14 and UIKit.text_w(tag.text, tag_fs) > 130.0:
		tag_fs -= 1
	tag.add_theme_font_size_override("font_size", tag_fs)
	var tag_w: float = maxf(UIKit.text_w(tag.text, tag_fs) + 20.0, 60.0)
	tag.custom_minimum_size = Vector2(tag_w, 0)
	tag.size = Vector2(tag_w, 30)
	tag.position = Vector2(-tag_w * 0.5, -66)
	tag.add_theme_color_override("font_color", Global.PLAYER_COLORS[idx])


func reset(pos: Vector2, respawn: Vector2) -> void:
	# --- pulihkan SEMUA state yang bisa tertinggal dari ronde sebelumnya ---
	vanished = false
	killer = -1
	_reset_id += 1
	set_physics_process(true)          # sebelumnya dimatikan saat mati di lava -> pemain tidak bisa gerak & kebal selamanya
	set_process(true)
	# PENTING: layer pemain sengaja TETAP 0 dulu. Body kinematik baru benar-benar pindah ke posisi baru
	# di step fisika berikutnya. Kalau layer langsung dikembalikan ke 4 sementara server fisika masih
	# memakai posisi lama (di dalam lava), Area2D lava mendeteksi "overlap palsu" dan mengirim body_entered
	# satu frame kemudian -> pemain tiba-tiba kena lava (efek + darah -1 + teleport) di awal ronde.
	# Layer dikembalikan ke 4 di _enable_collision_after_sync() setelah posisi baru sudah diterapkan.
	collision_layer = 0
	collision_mask = 3
	if squash_tw:
		squash_tw.kill()
	if flash_tw:
		flash_tw.kill()
	body_sprite.scale = Vector2.ONE * base_scale
	body_sprite.modulate = Color.WHITE
	jump_was_down = false
	coyote_timer = 0.0
	was_on_floor = false
	step_t = 0.0
	position = pos
	respawn_pos = respawn
	velocity = Vector2.ZERO
	hp = max_hp
	alive = true
	controls_enabled = false
	speed_time = 0.0
	jump_time = 0.0
	shield_time = 0.0
	shield_hits = 0
	invis_time = 0.0
	swap_time = 0.0
	recent_pickup = ""
	recent_pickup_note = ""
	recent_pickup_time = 0.0
	fire_lock = false
	shoot_cd = 0.0
	invuln = 0.0
	launch_cd = 0.0
	launched = false
	drop_timer = 0.0
	collision_mask = 3
	modulate = Color.WHITE
	visible = true
	z_index = 0
	body_sprite.texture = portrait_tex(false)
	_show_accessories(true)
	body_sprite.visible = true
	gun_sprite.visible = true
	tag.visible = true
	if fx != null:
		fx.visible = true
		fx.reset()
	if team_mark != null:
		team_mark.visible = true
	facing = 1 if pos.x < 640.0 else -1

	# senjata: peluru penuh lagi tiap ronde, kembali memegang senjata utama
	ammo = max_ammo()
	knife_out = false
	knife_only = false
	shoot_was_down = false
	swap_was_down = false
	fire_buffer = 0.0
	knife_hit_t = -1.0
	knife_t = -1.0
	kick = 0.0
	kick_v = 0.0
	swap_anim = 0.0
	sfx_cd = 0.0
	empty_text_cd = 0.0
	hit_sfx_cd = 0.0
	shown_weapon = ""
	_sync_weapon(false)
	_animate_gun(0.0)

	status_changed.emit(self)
	_enable_collision_after_sync(_reset_id)


## Kembalikan layer pemain (4) setelah server fisika menerapkan posisi spawn yang baru.
## Dilewati kalau sementara itu ada reset lain, atau pemain sudah mati / hilang lagi.
func _enable_collision_after_sync(id: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.physics_frame
	await tree.physics_frame
	if id != _reset_id or not is_inside_tree():
		return
	if vanished or not alive:
		return
	collision_layer = 4


# ------------------------------------------------------------------ input
func _key(action: String) -> bool:
	var km: Dictionary = Global.key_bindings[index]
	if not km.has(action):
		return false
	return Input.is_physical_key_pressed(int(km[action]) as Key)


## Tombol controller (>= 1000 = trigger analog L2/R2).
func _pad_down(dev: int, code: int) -> bool:
	if code >= Global.PAD_AXIS_BASE:
		return Input.get_joy_axis(dev, (code - Global.PAD_AXIS_BASE) as JoyAxis) > 0.5
	return Input.is_joy_button_pressed(dev, code as JoyButton)


## Pemain HANYA memakai perangkat yang dipilihnya di CONTROLS SETUP:
## controller (kalau terpasang) atau keyboard. Tidak dicampur.
func _read_input() -> Dictionary:
	var move := 0.0
	var jump := false
	var down := false
	var shoot := false
	var swap := false

	var dev: int = Global.device_of(index)
	if dev >= 0 and UIInput.pads().has(dev):
		var pb: Dictionary = Global.pad_bindings[index]
		var ax := Input.get_joy_axis(dev, JOY_AXIS_LEFT_X)
		var ay := Input.get_joy_axis(dev, JOY_AXIS_LEFT_Y)
		if absf(ax) > 0.3:
			move = signf(ax)
		var l: bool = _pad_down(dev, int(pb["left"]))
		var r: bool = _pad_down(dev, int(pb["right"]))
		if l and not r:
			move = -1.0
		elif r and not l:
			move = 1.0
		jump = ay < -0.75 or _pad_down(dev, int(pb["up"]))
		down = ay > 0.7 or _pad_down(dev, int(pb["down"]))
		shoot = _pad_down(dev, int(pb["shoot"]))
		swap = _pad_down(dev, int(pb.get("swap", JOY_BUTTON_Y)))
	else:
		if _key("left"):
			move -= 1.0
		if _key("right"):
			move += 1.0
		jump = _key("up")
		down = _key("down")
		shoot = _key("shoot")
		swap = _key("swap")

	return {"move": move, "jump": jump, "down": down, "shoot": shoot, "swap": swap}


# ------------------------------------------------------------------ physics
func _physics_process(delta: float) -> void:
	if vanished:
		velocity = Vector2.ZERO
		return
	shoot_cd = maxf(shoot_cd - delta, 0.0)
	_tick_timers(delta)

	var inp := {"move": 0.0, "jump": false, "down": false, "shoot": false, "swap": false}
	if controls_enabled and alive:
		inp = brain.call("think", self, delta) if brain != null else _read_input()

	var on_floor := is_on_floor()
	if on_floor:
		coyote_timer = COYOTE
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
		velocity.y += GRAVITY * delta

	# Horizontal
	var move: float = inp["move"]
	var speed_mult: float = SPEED_BOOST if speed_time > 0.0 else 1.0
	var rate: float = ACCEL if absf(move) > 0.01 else FRICTION
	# permukaan es (map Snow): tarikan lantai kecil -> licin. Berlaku sama untuk semua pemain.
	if on_floor and game != null and game.has_method("surface_grip"):
		rate *= float(game.surface_grip(self))
	velocity.x = move_toward(velocity.x, move * MOVE_SPEED * speed_mult * speed_scale, rate * delta)
	if absf(move) > 0.01:
		facing = 1 if move > 0.0 else -1

	# Jump
	var jump_down: bool = inp["jump"]
	if jump_down and not jump_was_down and coyote_timer > 0.0:
		var jump_mult: float = JUMP_BOOST if jump_time > 0.0 else 1.0
		velocity.y = JUMP_VELOCITY * jump_mult * jump_scale
		coyote_timer = 0.0
		Global.play_sfx("jump", -6.0)
		_squash(Vector2(0.78, 1.28))
		_dust(8)
	jump_was_down = jump_down
	# lompat lebih pendek kalau tombol dilepas
	if not jump_down and velocity.y < -300.0 and not launched:
		velocity.y = move_toward(velocity.y, -300.0, 4000.0 * delta)

	# Turun lewat platform
	if inp["down"] and on_floor and drop_timer <= 0.0:
		drop_timer = 0.25
		collision_mask = 1
		position.y += 2.0
	if drop_timer > 0.0:
		drop_timer -= delta
		if drop_timer <= 0.0:
			collision_mask = 3

	# Ganti senjata <-> pisau
	var swap_down: bool = inp["swap"]
	if swap_down and not swap_was_down and controls_enabled and alive:
		_toggle_knife()
	swap_was_down = swap_down

	# Tembak / tebas
	_handle_fire(inp["shoot"], delta)

	# pisau mengenai sasaran sesaat setelah ayunan dimulai
	if knife_hit_t > 0.0:
		knife_hit_t -= delta
		if knife_hit_t <= 0.0:
			knife_hit_t = -1.0
			_knife_strike()

	var vy_before: float = velocity.y
	move_and_slide()
	if launched and (velocity.y >= 0.0 or is_on_floor()):
		launched = false
	if is_on_floor() and not was_on_floor and vy_before > 380.0 and alive:
		_squash(Vector2(1.3, 0.72))
		_dust(10)
		Global.play_sfx("land", -8.0 + minf((vy_before - 380.0) / 260.0, 5.0), randf_range(0.95, 1.08))
		if game != null and vy_before > 900.0:
			game.shake(3.0)
	was_on_floor = is_on_floor()
	# debu langkah saat berlari
	if alive and is_on_floor() and absf(velocity.x) > 200.0:
		step_t -= delta
		if step_t <= 0.0:
			step_t = 0.16
			_dust(2)

	# Jatuh keluar layar
	if position.y > 900.0:
		if alive:
			hazard_hit(respawn_pos)
		else:
			_vanish()


func _process(delta: float) -> void:
	# animasi senjata dijalankan tiap frame gambar (bukan tiap frame fisika) supaya halus di layar 120/144 Hz
	_animate_gun(minf(delta, 1.0 / 30.0))


func _tick_timers(delta: float) -> void:
	launch_cd = maxf(launch_cd - delta, 0.0)
	sfx_cd = maxf(sfx_cd - delta, 0.0)
	empty_text_cd = maxf(empty_text_cd - delta, 0.0)
	hit_sfx_cd = maxf(hit_sfx_cd - delta, 0.0)
	recent_pickup_time = maxf(recent_pickup_time - delta, 0.0)
	if invuln > 0.0:
		invuln -= delta
		if alive:
			modulate.a = 0.45 if fmod(invuln, 0.2) > 0.1 else 1.0
		if invuln <= 0.0 and alive:
			modulate.a = 1.0
	if speed_time > 0.0:
		speed_time -= delta
		if speed_time <= 0.0:
			status_changed.emit(self)
	if jump_time > 0.0:
		jump_time -= delta
		if jump_time <= 0.0:
			status_changed.emit(self)
	if shield_hits > 0:
		shield_time -= delta
		if shield_time <= 0.0:
			_shield_expire()
	if invis_time > 0.0:
		invis_time -= delta
		# 0.7 detik terakhir berkedip supaya pemain tahu Invisible akan habis
		var show_now: bool = invis_time <= 0.0 or (invis_time < 0.7 and fmod(invis_time, 0.2) > 0.1)
		_set_body_shown(show_now)
		if invis_time <= 0.0:
			invis_time = 0.0
			status_changed.emit(self)
	if swap_time > 0.0:
		swap_time -= delta
		if swap_time <= 0.0:
			swap_time = 0.0
			fire_lock = true        # swap habis sambil menahan tembak -> jangan langsung menembak
			status_changed.emit(self)


# ------------------------------------------------------------------ senjata
func max_ammo() -> int:
	var base: int = int(Global.WEAPONS[weapon_id]["ammo"])
	if base < 0 or is_equal_approx(ammo_mult, 1.0):
		return base
	return maxi(base, int(round(float(base) * ammo_mult)))


## TEAM: pengali damage peluru karena nerf tim. Senjata sekali-mati (damage >= darah maksimal, mis. Scream)
## tidak dikurangi damage-nya (identitas senjata tetap), tapi jeda tembaknya ikut diperlambat lewat rate_scale.
func nerf_mult(base_damage: float) -> float:
	if base_damage >= max_hp - 0.001:
		return 1.0
	return nerf_dmg


## TEAM: pasang tim + nerf. Dipanggil game.gd saat membangun pemain (hanya kalau mode tim aktif).
func apply_team_balance(team_id: int, color: Color, level: int, nerf: Dictionary) -> void:
	team = team_id
	team_level = level
	nerf_dmg = float(nerf.get("dmg", 1.0))
	rate_scale = float(nerf.get("rate", 1.0))
	speed_scale = float(nerf.get("speed", 1.0))
	jump_scale = float(nerf.get("jump", 1.0))
	tag.add_theme_color_override("font_color", Color.WHITE)
	if team_mark != null:
		team_mark.queue_free()
	team_mark = TeamMark.new()
	team_mark.color = color
	team_mark.plate_w = maxf(tag.size.x, 60.0) + 14.0
	team_mark.level = level
	add_child(team_mark)
	move_child(team_mark, 0)      # paling belakang: tampil di bawah badan & teks nama
	team_mark.visible = alive and tag.visible


## Senjata yang sedang dipegang sekarang:
##   - pisau, kalau pemain menekan tombol ganti
##   - pistol, kalau peluru senjata utama habis DAN senjata itu punya "fallback" (Scream)
##   - selain itu: senjata utama (Smith / Kurval / Flamer / Scream)
## Selama peluru Scream masih ada, pistol tidak bisa dipakai sama sekali.
## Tekstur karakter (dengan skin kalau ada). Dipakai juga oleh HUD.
func portrait_tex(dead: bool) -> Texture2D:
	if skin_id == "":
		return Global.character_texture(index, char_idx, dead)
	return Cosmetics.char_tex(char_idx, skin_id, dead, index)


func weapon_tex_for(weapon: String) -> Texture2D:
	return Cosmetics.weapon_tex(weapon, String(wskins.get(weapon, "")), index)


## Pasang skin + aksesoris dari inventory. Hanya dipanggil untuk pemain manusia (musuh campaign tidak memakai skin).
func apply_cosmetics(skin: String, weapon_skins: Dictionary, loadout: Dictionary) -> void:
	skin_id = skin
	wskins = weapon_skins.duplicate()
	loadout_data = loadout.duplicate()
	for n in acc_nodes:
		if is_instance_valid(n):
			(n as Node).queue_free()
	acc_nodes = Cosmetics.attach_accessories(body_sprite, char_idx, loadout)
	body_sprite.texture = portrait_tex(false)
	shown_weapon = ""
	_sync_weapon(false)


func _show_accessories(on: bool) -> void:
	for n in acc_nodes:
		if is_instance_valid(n):
			(n as CanvasItem).visible = on


func current_weapon() -> String:
	if knife_only or knife_out:
		return Global.MELEE_WEAPON
	var fb: String = String(Global.WEAPONS[weapon_id].get("fallback", ""))
	if ammo <= 0 and max_ammo() >= 0 and fb != "":
		return fb
	return weapon_id


## Pasang sprite sesuai senjata yang sedang dipegang. Dipanggil setiap kali current_weapon() mungkin berubah.
func _sync_weapon(animate: bool = true) -> void:
	var cur: String = current_weapon()
	if cur == shown_weapon:
		return
	shown_weapon = cur
	var tex: Texture2D = weapon_tex_for(cur)
	gun_sprite.texture = tex
	gun_tex_w = float(tex.get_width())
	gun_len = float(Global.WEAPONS[cur].get("hold_len", 56.0))
	gun_base_scale = gun_len / gun_tex_w
	gun_sprite.scale = Vector2.ONE * gun_base_scale
	if animate:
		swap_anim = 1.0
	status_changed.emit(self)


## Posisi moncong senjata (relatif ke tengah badan, searah hadap) - ikut panjang senjata yang dipegang.
func muzzle_x() -> float:
	if current_weapon() == Global.MELEE_WEAPON:
		return KNIFE_MUZZLE_X * size_mult
	return (GRIP_X + gun_len - 4.0) * size_mult


## Sudden Death: paksa pemain memegang pisau dan kunci pilihan senjata (tidak bisa diubah sampai ronde selesai).
func set_knife_only(on: bool) -> void:
	knife_only = on
	if not on:
		return
	knife_out = true
	fire_buffer = 0.0
	knife_hit_t = -1.0
	knife_t = -1.0
	_sync_weapon(true)


func _toggle_knife() -> void:
	if knife_only:
		return        # Sudden Death: pisau terkunci
	knife_out = not knife_out
	shoot_cd = maxf(shoot_cd, SWITCH_TIME)
	fire_buffer = 0.0
	knife_hit_t = -1.0
	knife_t = -1.0
	Global.play_sfx("click", -8.0, 1.5)
	_sync_weapon(true)
	var p := _fx_parent()
	if p != null:
		var nm: String = String(Global.WEAPONS[current_weapon()]["name"])
		WeaponFx.float_text(p, global_position + Vector2(0, -74), nm, Color("dfe8ff"), 20)


## Tombol tembak: senjata "auto" (Flamer) boleh ditahan, senjata lain harus tap-tap.
func _handle_fire(shoot: bool, delta: float) -> void:
	var pressed: bool = shoot and not shoot_was_down
	shoot_was_down = shoot
	fire_buffer = maxf(fire_buffer - delta, 0.0)
	if pressed:
		fire_buffer = BUFFER_TIME
	if game == null or not alive or not controls_enabled:
		return
	# Power up Swap Position: selama aktif pemain TIDAK bisa menembak / menebas.
	# Menekan tombol tembak = tukar posisi dengan pemain lain. Kalau tidak ditekan, cukup tunggu sampai habis.
	if swap_time > 0.0:
		fire_buffer = 0.0
		if pressed:
			_use_swap()
		return
	# Setelah swap dipakai / habis: tombol tembak yang masih ditahan TIDAK boleh menembak (termasuk senjata auto
	# seperti Flamer). Tembakan baru boleh setelah tombol dilepas dulu.
	if fire_lock:
		fire_buffer = 0.0
		if not shoot:
			fire_lock = false
		return
	var id: String = current_weapon()
	var w: Dictionary = Global.WEAPONS[id]
	var wants: bool = fire_buffer > 0.0
	if bool(w.get("auto", false)) and shoot:
		wants = true
	if not wants or shoot_cd > 0.0:
		return
	fire_buffer = 0.0
	if String(w.get("kind", "gun")) == "melee":
		_knife_attack(w)
	else:
		_fire_gun(id, w)


func _fire_gun(id: String, w: Dictionary) -> void:
	var uses_ammo: bool = int(w["ammo"]) >= 0
	if uses_ammo and ammo <= 0:
		_empty_click()
		return
	shoot_cd = float(w["cooldown"]) * rate_scale
	if uses_ammo:
		ammo -= 1
	game.spawn_bullet(self, id)
	# suara (dengan sedikit variasi nada supaya tidak monoton; Flamer dibatasi agar tidak menumpuk)
	if sfx_cd <= 0.0:
		sfx_cd = float(w.get("sfx_gap", 0.0))
		Global.play_sfx(String(w["sfx"]), float(w.get("sfx_vol", -4.0)), randf_range(0.95, 1.06))
	velocity.x -= facing * float(w.get("recoil", 40.0))
	_fire_fx(id)
	if uses_ammo and ammo <= 0:
		_on_ammo_out(id)
	status_changed.emit(self)


## Peluru senjata utama baru saja habis.
func _on_ammo_out(id: String) -> void:
	var fb: String = String(Global.WEAPONS[id].get("fallback", ""))
	var p := _fx_parent()
	if fb != "":
		# Scream habis -> langsung ganti ke pistol (pistol baru siap setelah DRAW_TIME)
		shoot_cd = minf(shoot_cd, DRAW_TIME)
		_sync_weapon(true)
		if p != null:
			WeaponFx.float_text(p, global_position + Vector2(0, -74), "PISTOL!", Color("fff0b0"), 22)
	elif p != null:
		WeaponFx.float_text(p, global_position + Vector2(0, -74), "EMPTY!", Color("ff6a5a"), 22)


func _empty_click() -> void:
	shoot_cd = 0.3
	Global.play_sfx("gun_empty", -4.0)
	kick = 0.45
	kick_v = 0.0
	if empty_text_cd <= 0.0:
		empty_text_cd = 0.8
		var p := _fx_parent()
		if p != null:
			WeaponFx.float_text(p, global_position + Vector2(0, -74), "NO AMMO", Color("ff6a5a"), 20)


func _knife_attack(w: Dictionary) -> void:
	shoot_cd = float(w["cooldown"])
	knife_t = 0.0
	knife_hit_t = float(w.get("hit_delay", 0.07))
	Global.play_slash(-3.0)
	velocity.x += facing * 180.0          # sedikit melompat maju saat menebas
	_rb( 0.1, 0.0, 0.04)


## Saat bilah mengenai: cek semua pemain lain yang ada di depan dalam jangkauan pendek.
func _knife_strike() -> void:
	if not alive or game == null:
		return
	var w: Dictionary = Global.WEAPONS[Global.MELEE_WEAPON]
	var reach: float = float(w["reach"]) * size_mult
	var reach_y: float = float(w["reach_y"]) * size_mult
	var p := _fx_parent()
	WeaponFx.slash(p, global_position + Vector2(facing * 10.0 * size_mult, 6.0), facing)
	for o in game.players:
		var other: Player = o
		if other == self or not other.alive or other.vanished:
			continue
		if team >= 0 and other.team == team:
			continue          # campaign: tidak melukai sesama tim
		var dx: float = (other.global_position.x - global_position.x) * facing
		var dy: float = absf(other.global_position.y - global_position.y)
		if dx < -14.0 or dx > reach or dy > reach_y:
			continue
		var before: float = other.hp
		other.take_damage(float(w["damage"]) * dmg_out * knife_mult, facing, false, true, index)
		if other.hp < before:
			WeaponFx.stab_hit(p, other.global_position, facing)
			Global.play_sfx("knife_hit", -4.0, randf_range(0.94, 1.08))
			game.shake(5.0)
			_rb( 0.4, 0.6, 0.12)


# ------------------------------------------------------------------ animasi senjata
## Hentakan senjata memakai pegas teredam: menyentak ke belakang, memantul sedikit, lalu diam. Halus di semua refresh rate.
func _animate_gun(dt: float) -> void:
	if dt > 0.0:
		kick_v += (-kick * 460.0 - kick_v * 25.0) * dt
		kick += kick_v * dt
		swap_anim = maxf(swap_anim - dt * 4.2, 0.0)
		if knife_t >= 0.0:
			knife_t += dt
			if knife_t > 0.3:
				knife_t = -1.0

	var id: String = shown_weapon if shown_weapon != "" else weapon_id
	var st: Dictionary = WeaponFx.style(id)
	var pos := Vector2(facing * (GRIP_X + gun_len * 0.5), 8.0)   # gambar senjata berpusat di tengah, pangkalnya di GRIP_X
	var rot: float = 0.0
	var sc: float = 1.0
	var off := Vector2.ZERO

	if id == Global.MELEE_WEAPON:
		# titik putar di gagang pisau
		off = Vector2(gun_tex_w * 0.36, 0.0)
		pos.x = facing * (GRIP_X + gun_len * 0.14)
		if knife_t >= 0.0:
			var ang: float = 0.0
			var fwd: float = 0.0
			if knife_t < 0.07:
				# tarik ke belakang (antisipasi)
				var u1: float = knife_t / 0.07
				var e1: float = u1 * u1 * (3.0 - 2.0 * u1)
				ang = lerpf(0.0, -75.0, e1)
				fwd = lerpf(0.0, -6.0, e1)
			elif knife_t < 0.14:
				# tebas cepat
				var u2: float = (knife_t - 0.07) / 0.07
				var e2: float = 1.0 - pow(1.0 - u2, 3.0)
				ang = lerpf(-75.0, 70.0, e2)
				fwd = lerpf(-6.0, 16.0, e2)
			else:
				# kembali ke posisi siap
				var u3: float = clampf((knife_t - 0.14) / 0.16, 0.0, 1.0)
				var e3: float = u3 * u3 * (3.0 - 2.0 * u3)
				ang = lerpf(70.0, 0.0, e3)
				fwd = lerpf(16.0, 0.0, e3)
			rot = facing * deg_to_rad(ang)
			pos.x += facing * fwd
		else:
			rot = facing * deg_to_rad(-12.0)     # pisau dipegang agak miring saat siaga
	else:
		var px: float = float(st["kick_px"])
		var deg: float = float(st["kick_deg"])
		pos.x -= facing * kick * px
		pos.y -= kick * 1.5
		rot = -facing * kick * deg_to_rad(deg)
		sc = 1.0 + 0.10 * maxf(kick, 0.0)

	# animasi ganti senjata: naik dari bawah sambil berputar
	if swap_anim > 0.0:
		var e: float = swap_anim * swap_anim
		pos.y += e * 16.0
		rot += facing * e * 1.1

	gun_sprite.offset = off
	gun_sprite.position = pos * size_mult
	gun_sprite.rotation = rot
	# cermin lewat scale.x (bukan flip_h) supaya titik putar pisau ikut terbalik dengan benar
	gun_sprite.flip_h = false
	gun_sprite.scale = Vector2(float(facing) * gun_base_scale * sc, gun_base_scale * sc) * size_mult


# ------------------------------------------------------------------ health
## amount boleh pecahan (0.25, 0.5, 1.5 ...). weapon_hit = true untuk peluru / pisau:
## tidak memberi "kebal sesaat" supaya senjata cepat seperti Flamer tetap kena tiap peluru.
func take_damage(amount: float, from_dir: int = 0, ignore_invuln: bool = false, weapon_hit: bool = false, attacker: int = -1) -> void:
	if not alive:
		return
	if invuln > 0.0 and not ignore_invuln:
		return
	# Shield menahan SEMUA damage (peluru, pisau, panah jebakan, lava, duri, jatuh). Yang berkurang shield-nya, bukan darah.
	# (Respawn / lontaran akibat lava & duri tetap terjadi, itu diatur di hazard_hit() / spike_hit().)
	if shield_hits > 0:
		_shield_absorb(from_dir)
		return
	amount *= dmg_in
	hp = maxf(hp - amount, 0.0)
	if hit_sfx_cd <= 0.0:
		hit_sfx_cd = 0.07
		Global.play_sfx("hit", -2.0 - (1.0 - clampf(amount, 0.0, 1.0)) * 6.0)
	velocity.x += from_dir * (60.0 + 70.0 * minf(amount, 1.5))
	if not weapon_hit:
		invuln = 0.25
	_hit_fx(from_dir, amount)
	if hp <= 0.001:
		killer = attacker
		die()
	status_changed.emit(self)


func heal(amount: float) -> void:
	if not alive:
		return
	hp = minf(hp + amount, max_hp)
	status_changed.emit(self)


func set_hp(value: float) -> void:
	hp = clampf(value, 0.0, max_hp)
	status_changed.emit(self)


func die() -> void:
	if not alive:
		return
	alive = false
	hp = 0.0
	controls_enabled = false
	invuln = 0.0
	shield_hits = 0
	shield_time = 0.0
	invis_time = 0.0
	swap_time = 0.0
	recent_pickup_time = 0.0
	body_sprite.visible = true         # kalau mati saat Invisible, badan tetap terlihat
	if fx != null:
		fx.visible = false
	knife_hit_t = -1.0
	knife_t = -1.0
	modulate = Color(1, 1, 1, 0.85)
	z_index = -1
	body_sprite.texture = portrait_tex(true)
	_show_accessories(false)
	gun_sprite.visible = false
	tag.visible = false
	if team_mark != null:
		team_mark.visible = false
	velocity.x *= 0.3
	set_deferred("collision_layer", 0)   # mayat tidak menahan peluru / memicu lava & power up lagi
	Global.play_sfx("dead")
	_death_fx()
	died.emit(self)
	status_changed.emit(self)


## Kena lava / jatuh: -1 darah, lalu muncul lagi di titik respawn.
func hazard_hit(respawn: Vector2) -> void:
	if not alive or vanished:
		return
	Global.play_sfx("lava_burn", -4.0)
	take_damage(1.0, 0, true)
	if alive:
		Global.play_sfx("respawn", -6.0)
		position = respawn
		velocity = Vector2.ZERO
		invuln = 1.5
		drop_timer = 0.0
		collision_mask = 3
	else:
		_vanish()


## Kena duri / kaktus: -1 darah, terpental ke atas (tidak di-teleport), kebal sebentar supaya tidak kena berulang.
func spike_hit(dir: int) -> void:
	if not alive or vanished or invuln > 0.0:
		return
	Global.play_sfx("spike_hit", -4.0)
	take_damage(1.0, 0, true)
	if alive:
		velocity = Vector2(dir * 280.0, -620.0)
		invuln = 1.2
		drop_timer = 0.0
		collision_mask = 3
		coyote_timer = 0.0


## Dilontarkan ke atas (jamur pantul). Mengembalikan true kalau lontaran terjadi.
func launch(vy: float) -> bool:
	if not alive or vanished or launch_cd > 0.0:
		return false
	launch_cd = 0.3
	launched = true
	velocity.y = vy
	coyote_timer = 0.0
	Global.play_sfx("bounce_pad", -6.0, randf_range(0.95, 1.08))
	_squash(Vector2(0.72, 1.35))
	_dust(12)
	return true


## Pemain mati di lava / jatuh: sembunyikan & bekukan. TIDAK mematikan physics_process
## (itu yang dulu bikin pemain tidak bisa bergerak di ronde berikutnya) - cukup flag, dan reset() menghapusnya.
func _vanish() -> void:
	vanished = true
	visible = false
	velocity = Vector2.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)


func apply_powerup(type: String) -> void:
	if not alive:
		return
	var was_full: bool = hp >= max_hp
	match type:
		"heal":
			heal(1.0)
			_flash_pickup(type, "FULL" if was_full else "+1")
			Global.play_sfx("pu_heal")
		"jump":
			jump_time = BOOST_DURATION
			Global.play_sfx("pu_jump")
		"speed":
			speed_time = BOOST_DURATION
			Global.play_sfx("pu_speed")
		"shield":
			shield_hits = SHIELD_HITS
			shield_time = SHIELD_DURATION
			if fx != null:
				fx.pop = 1.0
			Global.play_sfx("pu_shield")
		"invisible":
			invis_time = INVISIBLE_DURATION
			_set_body_shown(false)
			Global.play_sfx("pu_invisible")
		"ammo_refill":
			_refill_ammo()
			_flash_pickup(type, "FULL")
			Global.play_sfx("pu_ammo_refill")
		"swap_position":
			swap_time = SWAP_WINDOW
			shoot_was_down = true      # tombol tembak yang sedang ditahan tidak langsung dihitung sebagai "tukar"
			fire_buffer = 0.0
			fire_lock = false
			Global.play_sfx("pu_swap_position")
			var fxp := _fx_parent()
			if fxp != null:
				WeaponFx.float_text(fxp, global_position + Vector2(0, -118), "SHOOT = SWAP!", pu_color(type), 22)
		"nuke", "freeze":
			# efek khusus campaign ditangani game (campaign.gd)
			if game != null and game.has_method("campaign_powerup"):
				game.campaign_powerup(self, type)
				_flash_pickup(type, "!")
	_pickup_label(type, was_full)
	_pickup_fx(type)
	status_changed.emit(self)


## Warna / nama power up (dipakai HUD di game.gd lewat Player.pu_color / Player.pu_name).
static func pu_color(type: String) -> Color:
	if PU_INFO.has(type):
		return PU_INFO[type]["color"]
	return Color.WHITE


static func pu_name(type: String) -> String:
	if PU_INFO.has(type):
		return String(PU_INFO[type]["name"])
	return type.to_upper()


## Power up instan (HEAL / AMMO): tampilkan kartu sebentar di HUD supaya pemain tahu efeknya.
func _flash_pickup(type: String, note: String) -> void:
	recent_pickup = type
	recent_pickup_note = note
	recent_pickup_time = PICKUP_FLASH


## Teks melayang di dekat pemain saat mengambil power up (Ammo & Swap sudah punya teks sendiri).
func _pickup_label(type: String, full_before: bool) -> void:
	var txt: String = ""
	match type:
		"heal":
			txt = "HP FULL" if full_before else "HEAL +1"
		"speed":
			txt = "SPEED BOOST!"
		"jump":
			txt = "JUMP BOOST!"
		"shield":
			txt = "SHIELD x%d!" % SHIELD_HITS
	if txt == "":
		return
	var p := _fx_parent()
	if p != null:
		WeaponFx.float_text(p, global_position + Vector2(0, -74), txt, pu_color(type), 22)


## Ammo Refill: peluru senjata utama kembali penuh sesuai jumlah awal senjatanya.
## Scream yang pelurunya sudah habis (sedang memakai pistol) -> peluru reset ke 3, Scream dipegang lagi
## dan pistol disembunyikan sampai peluru Scream habis lagi (diatur otomatis oleh current_weapon()).
func _refill_ammo() -> void:
	if knife_only:
		return      # Sudden Death: hanya pisau, tidak ada peluru yang perlu diisi
	var mx: int = max_ammo()
	if mx < 0:
		return      # senjata tanpa batas peluru, tidak ada yang perlu diisi
	var before: String = current_weapon()
	ammo = mx
	var after: String = current_weapon()
	if after != before:
		shoot_cd = maxf(shoot_cd, SWITCH_TIME)    # jeda singkat saat menarik senjata utama lagi
		fire_buffer = 0.0
	_sync_weapon(true)
	var p := _fx_parent()
	if p != null:
		var nm: String = String(Global.WEAPONS[after]["name"])
		var txt: String = "%s READY!" % nm if after != before else "AMMO FULL!"
		WeaponFx.float_text(p, global_position + Vector2(0, -74), txt, Color("ff9d2e"), 22)


# ------------------------------------------------------------------ shield
## Shield menahan satu tembakan. Setelah SHIELD_HITS kali, shield pecah.
func _shield_absorb(from_dir: int) -> void:
	shield_hits -= 1
	velocity.x += from_dir * 40.0
	if hit_sfx_cd <= 0.0:
		hit_sfx_cd = 0.07
		if shield_hits > 0:
			Global.play_sfx("pu_shield", -6.0, 1.5)
		else:
			Global.play_sfx("shield_break", -3.0)
	var p := _fx_parent()
	var col := Color(0.45, 0.85, 1.0)
	if fx != null:
		fx.pop = 1.0
	if p != null:
		UIKit.burst(p, global_position, col, 10, 220.0, 5.0, 0.35, 100.0)
	_rb( 0.2, 0.3, 0.08)
	if shield_hits <= 0:
		shield_hits = 0
		shield_time = 0.0
		if p != null:
			UIKit.burst(p, global_position, col, 26, 380.0, 7.0, 0.6, 300.0)
			UIKit.ring(p, global_position, col, 120.0, 0.45)
			WeaponFx.float_text(p, global_position + Vector2(0, -74), "SHIELD BREAK!", col, 20)
		if game != null:
			game.shake(4.0)
	status_changed.emit(self)


## Waktu Shield habis sebelum pecah.
func _shield_expire() -> void:
	shield_hits = 0
	shield_time = 0.0
	var p := _fx_parent()
	if p != null:
		UIKit.ring(p, global_position, Color(0.45, 0.85, 1.0, 0.8), 90.0, 0.35)
	status_changed.emit(self)


# ------------------------------------------------------------------ invisible
## Tampilkan / sembunyikan seluruh tubuh pemain (badan, senjata, label, shield).
func _set_body_shown(v: bool) -> void:
	body_sprite.visible = v
	gun_sprite.visible = v and alive
	tag.visible = v and alive
	if team_mark != null:
		team_mark.visible = v and alive
	if fx != null:
		fx.visible = v and alive


# ------------------------------------------------------------------ swap position
func _use_swap() -> void:
	if game == null or not game.has_method("shuffle_positions"):
		return
	if bool(game.shuffle_positions(self)):
		swap_time = 0.0
		fire_lock = true
		fire_buffer = 0.0
		shoot_cd = maxf(shoot_cd, 0.15)
		if fx != null:
			fx.queue_redraw()
		status_changed.emit(self)
	else:
		var p := _fx_parent()
		if p != null:
			WeaponFx.float_text(p, global_position + Vector2(0, -74), "NO TARGET", Color("ff6a5a"), 20)


## Ubah ukuran badan (boss campaign): hitbox, sprite, label, dan efek status ikut membesar.
func set_size_mult(m: float) -> void:
	size_mult = m
	base_scale = SIZE / 180.0 * m
	body_sprite.scale = Vector2.ONE * base_scale
	if body_shape != null:
		(body_shape.shape as RectangleShape2D).size = Vector2(50.0, 60.0) * m
	tag.position.y = -66.0 * m
	if fx != null:
		fx.scale = Vector2.ONE * m


## Getar controller hanya untuk pemain manusia (musuh campaign tidak boleh menggetarkan controller siapa pun).
func _rb(weak: float, strong: float, duration: float) -> void:
	if brain == null:
		Global.rumble(index, weak, strong, duration)


## Dipindahkan paksa ke posisi lain (dipakai Swap Position).
func teleport_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	drop_timer = 0.0
	collision_mask = 3
	coyote_timer = 0.0
	launched = false
	_squash(Vector2(0.75, 1.3))


# ------------------------------------------------------------------ efek visual & getar
func _squash(v: Vector2) -> void:
	if squash_tw:
		squash_tw.kill()
	body_sprite.scale = Vector2.ONE * base_scale * v
	squash_tw = create_tween()
	squash_tw.tween_property(body_sprite, "scale", Vector2.ONE * base_scale, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fx_parent() -> Node:
	return game if game != null else get_parent()


func _dust(amount: int) -> void:
	var p := _fx_parent()
	if p == null:
		return
	UIKit.burst(p, global_position + Vector2(0, 30), Color(1, 1, 1, 0.7), amount, 120.0, 4.0, 0.35, 200.0)


## Semua efek saat menembak: kilatan moncong, selongsong, asap, hentakan senjata, getar layar & controller.
func _fire_fx(id: String) -> void:
	var st: Dictionary = WeaponFx.style(id)
	var p := _fx_parent()
	if p != null:
		var pos: Vector2 = global_position + Vector2(facing * muzzle_x(), 3.0)
		WeaponFx.muzzle(p, pos, facing, id)
	kick = 1.0
	kick_v = 0.0
	var sq: float = float(st["squash"])
	if sq > 0.0:
		_squash(Vector2(1.0 + sq, 1.0 - sq * 0.8))
	var rb: Array = st["rumble"]
	_rb( float(rb[0]), float(rb[1]), float(rb[2]))
	if game != null:
		game.shake(float(st["shake"]))
		if id == "scream":
			game.hit_stop(0.03)       # jeda sekejap supaya tembakan Scream terasa berat


## Efek terkena tembakan. Makin kecil damage makin ringan efeknya (supaya Flamer tidak membuat layar membeku).
func _hit_fx(from_dir: int, amount: float) -> void:
	var power: float = clampf(amount / 1.5, 0.15, 1.0)
	var p := _fx_parent()
	if p != null:
		UIKit.burst(p, global_position, Global.PLAYER_COLORS[index].lightened(0.2), int(4.0 + 10.0 * power), 150.0 + 150.0 * power, 6.0, 0.45)
		if power > 0.5:
			UIKit.burst(p, global_position, Color.WHITE, 6, 200.0, 4.0, 0.25)
	_rb( 0.2 + 0.5 * power, 0.5 * power, 0.08 + 0.14 * power)
	if game != null:
		game.shake(1.5 + 3.5 * power)
		if amount >= 1.0:
			game.hit_stop(0.03 + 0.015 * power)
	if flash_tw:
		flash_tw.kill()
	body_sprite.modulate = Color(3, 3, 3, 1)
	flash_tw = create_tween()
	flash_tw.tween_property(body_sprite, "modulate", Color.WHITE, 0.18)
	if power > 0.4:
		_squash(Vector2(1.2 - from_dir * 0.0, 0.85))


func _death_fx() -> void:
	var p := _fx_parent()
	if p != null:
		UIKit.burst(p, global_position, Global.PLAYER_COLORS[index], 36, 520.0, 9.0, 0.9)
		UIKit.burst(p, global_position, Color.WHITE, 14, 380.0, 6.0, 0.5)
		UIKit.ring(p, global_position, Global.PLAYER_COLORS[index], 160.0, 0.55)
	_rb( 1.0, 1.0, 0.5)
	if game != null:
		game.shake(11.0)
		game.hit_stop(0.12)


func _pickup_fx(type: String) -> void:
	var p := _fx_parent()
	if p == null:
		return
	var col: Color = pu_color(type)
	UIKit.burst(p, global_position, col, 20, 300.0, 6.0, 0.6, 100.0)
	UIKit.ring(p, global_position, col, 110.0, 0.45)
	_rb( 0.2, 0.4, 0.15)


# ================================================================== penanda TIM (pelat di belakang nama)
## Pelat miring berwarna tim + segitiga penunjuk ke kepala.
class TeamMark extends Node2D:
	var color: Color = Color.WHITE
	var plate_w: float = 120.0
	var level: int = 0
	var t: float = 0.0

	func _process(d: float) -> void:
		t += d
		if visible:
			queue_redraw()

	func _draw() -> void:
		var w: float = plate_w
		var h: float = 30.0
		var x: float = -w * 0.5
		var y: float = -68.0
		var pulse: float = 0.5 + 0.5 * sin(t * 3.0)
		var pts := UIKit.slanted(w, h, 9.0, x, y)
		draw_colored_polygon(UIKit.slanted(w, h, 9.0, x + 2.0, y + 3.0), Color(0, 0, 0, 0.45))
		draw_colored_polygon(pts, Color(color.darkened(0.62), 0.9))
		draw_polyline(UIKit.closed(pts), Color(color, 0.75 + 0.25 * pulse), 2.5, true)
		# garis aksen tipis di tepi bawah pelat
		draw_line(Vector2(x + 4.0, y + h - 2.0), Vector2(x + w - 4.0, y + h - 2.0), Color(color, 0.55), 2.0, true)
		# segitiga penunjuk
		draw_colored_polygon(PackedVector2Array([Vector2(-8, y + h + 0.5), Vector2(8, y + h + 0.5), Vector2(0, y + h + 9.0)]), Color(color, 0.95))



# ================================================================== efek status (Shield & Swap Position)
class StatusFx extends Node2D:
	var p: Player
	var t: float = 0.0
	var pop: float = 0.0      # denyut saat shield kena / baru diambil
	var was_active: bool = false

	func reset() -> void:
		pop = 0.0
		was_active = false
		queue_redraw()

	## PENTING: Godot hanya menggambar ulang saat queue_redraw() dipanggil; gambar terakhir tetap tertinggal di layar.
	## Jadi saat status berakhir (swap dipakai / shield habis) harus ada SATU redraw lagi supaya gambar lama terhapus.
	func _process(d: float) -> void:
		t += d
		pop = maxf(pop - d * 4.0, 0.0)
		if p == null:
			return
		var active: bool = p.alive and (p.shield_hits > 0 or p.swap_time > 0.0 or p.speed_time > 0.0 or p.jump_time > 0.0)
		if active or was_active or pop > 0.0:
			queue_redraw()
		was_active = active

	func _draw() -> void:
		if p == null or not p.alive:
			return
		if p.shield_hits > 0:
			_draw_shield()
		if p.swap_time > 0.0:
			_draw_swap()
		_draw_badges()

	## Gelembung shield: 2 tembakan = lingkaran utuh, 1 tembakan = retak (putus-putus). Berkedip saat hampir habis.
	func _draw_shield() -> void:
		var r: float = 44.0 * (1.0 + 0.12 * pop)
		var a: float = 1.0
		if p.shield_time < 1.5:
			a = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 18.0))
		var col := Color(0.45, 0.85, 1.0)
		draw_circle(Vector2.ZERO, r, Color(col, 0.10 * a))
		if p.shield_hits >= 2:
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(col, 0.9 * a), 3.0, true)
			draw_arc(Vector2.ZERO, r - 5.0, 0.0, TAU, 40, Color(1, 1, 1, 0.3 * a), 2.0, true)
		else:
			for k in 6:
				var a0: float = t * 1.5 + float(k) * TAU / 6.0
				draw_arc(Vector2.ZERO, r, a0, a0 + 0.7, 8, Color(col, 0.85 * a), 3.0, true)

	## Penanda Swap Position: dua panah berputar + busur hitung mundur + teks "SHOOT!" di atas kepala.
	func _draw_swap() -> void:
		var col := Color("8ed457")
		var frac: float = clampf(p.swap_time / Player.SWAP_WINDOW, 0.0, 1.0)
		var r: float = 46.0
		draw_arc(Vector2.ZERO, r + 8.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 48, Color(col, 0.9), 4.0, true)
		for k in 2:
			var a0: float = t * 3.0 + float(k) * PI
			draw_arc(Vector2.ZERO, r, a0, a0 + 1.9, 14, Color(1, 1, 1, 0.85), 4.0, true)
			var tip := Vector2(cos(a0 + 1.9), sin(a0 + 1.9)) * r
			var ang: float = a0 + 1.9 + PI * 0.5
			var dirv := Vector2(cos(ang), sin(ang))
			var side := Vector2(-dirv.y, dirv.x)
			draw_colored_polygon(PackedVector2Array([tip + dirv * 12.0, tip + side * 8.0, tip - side * 8.0]), Color(col, 0.95))
		if fmod(t, 0.5) < 0.32:
			UIKit.text_in(self, "SHOOT!", Rect2(-60, -142, 120, 24), 20, col, HORIZONTAL_ALIGNMENT_CENTER, 7)


	## Daftar power up aktif: [id, sisa 0..1, sisa detik, total detik, jumlah]
	func _active_list() -> Array:
		var a: Array = []
		if p.speed_time > 0.0:
			a.append(["speed", p.speed_time / Player.BOOST_DURATION, p.speed_time, Player.BOOST_DURATION, 0])
		if p.jump_time > 0.0:
			a.append(["jump", p.jump_time / Player.BOOST_DURATION, p.jump_time, Player.BOOST_DURATION, 0])
		if p.shield_hits > 0:
			a.append(["shield", p.shield_time / Player.SHIELD_DURATION, p.shield_time, Player.SHIELD_DURATION, p.shield_hits])
		if p.swap_time > 0.0:
			a.append(["swap_position", p.swap_time / Player.SWAP_WINDOW, p.swap_time, Player.SWAP_WINDOW, 0])
		return a

	## Penanda power up di atas kepala: ikon besar + cincin hitung mundur berwarna.
	## Semua pemain bisa melihat power up lawan; cincin berkedip putih saat waktunya hampir habis.
	func _draw_badges() -> void:
		if p.brain != null:
			return          # musuh campaign: tidak menampilkan penanda power up di atas kepala
		var list: Array = _active_list()
		var n: int = list.size()
		if n == 0:
			return
		var step: float = 42.0
		var x0: float = -step * float(n - 1) * 0.5
		for k in n:
			var it: Array = list[k]
			var id: String = String(it[0])
			var frac: float = clampf(float(it[1]), 0.0, 1.0)
			var left: float = float(it[2])
			var total: float = float(it[3])
			var c: Color = Player.pu_color(id)
			var ctr := Vector2(x0 + step * float(k), -92.0 + sin(t * 3.0 + float(k)) * 1.5)
			var low: bool = left <= (3.0 if total > 4.0 else 1.0)
			var ring_c: Color = Color.WHITE if (low and sin(t * 16.0) > 0.0) else c
			draw_circle(ctr, 19.0, Color(0.03, 0.03, 0.08, 0.9))
			draw_circle(ctr, 19.0, Color(c, 0.25))
			draw_arc(ctr, 19.0, 0.0, TAU, 36, Color(1, 1, 1, 0.18), 4.0, true)
			if frac > 0.01:
				draw_arc(ctr, 19.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 36, ring_c, 4.0, true)
			var path: String = "res://assets/sprites/powerups/%s.png" % id
			if ResourceLoader.exists(path):
				draw_texture_rect(Global.cached_tex(path), Rect2(ctr - Vector2(14, 14), Vector2(28, 28)), false)
			if int(it[4]) > 0:
				var bc: Vector2 = ctr + Vector2(14, 14)
				draw_circle(bc, 9.0, Color(0, 0, 0, 0.9))
				draw_arc(bc, 9.0, 0.0, TAU, 20, c, 2.0, true)
				UIKit.text_in(self, str(int(it[4])), Rect2(bc.x - 10.0, bc.y - 10.0, 20.0, 20.0), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 4)
