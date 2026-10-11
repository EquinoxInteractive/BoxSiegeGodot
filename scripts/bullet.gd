class_name Bullet
extends Area2D
## Peluru: lurus horizontal, kena pemain lain = kurangi darah, kena lantai = hilang.
## Tampilan beda tiap senjata: slug (smith / kurval / pistol), bola api (flamer), gelombang jeritan (scream).

const WeaponFx = preload("res://scripts/weapon_fx.gd")

var dir: int = 1
var speed: float = 900.0
var damage: float = 1.0
var shooter: int = 0
var team: int = -1               # campaign: peluru tidak melukai pemain satu tim (-1 = versus, semua kena)
var weapon: String = "smith"
var max_range: float = 0.0       # 0 = tanpa batas jarak
var travelled: float = 0.0
var skin_color: Color = Color(0, 0, 0, 0)   # warna peluru dari skin senjata (alpha 0 = pakai warna asli)


func setup(d: int, spd: float, dmg: float, shooter_idx: int, weapon_id: String = "smith", rng_px: float = 0.0) -> void:
	dir = d
	speed = spd
	damage = dmg
	shooter = shooter_idx
	weapon = weapon_id
	max_range = rng_px


func _ready() -> void:
	collision_layer = 0
	# Area hanya mendeteksi PEMAIN (layer 3). Lantai / dinding dicek terpisah lewat raycast tipis di
	# _physics_process, supaya hitbox peluru yang tinggi (mis. Scream) tidak "menyentuh" lantai tempat
	# pemain berdiri lalu meledak seketika.
	collision_mask = 4

	var st: Dictionary = WeaponFx.style(weapon)
	var art := Art.new()
	art.kind = weapon
	art.col = st["color"]
	art.glow = st["glow"]
	if skin_color.a > 0.0:
		art.col = skin_color
		art.glow = skin_color.lightened(0.3)
	art.tex = Global.cached_tex("res://assets/sprites/guns/bullet.png")

	var shape_size := Vector2(22, 8)
	var shape_off := Vector2.ZERO
	match weapon:
		"kurval":
			art.body = Vector2(32, 11)
			art.tail = 54.0
			art.tint = Color(1.0, 0.62, 0.45)
			shape_size = Vector2(28, 10)
		"pistol":
			art.body = Vector2(17, 6)
			art.tail = 26.0
			art.tint = Color(1.0, 0.95, 0.8)
			shape_size = Vector2(16, 7)
		"flamer":
			shape_size = Vector2(26, 22)
		"scream":
			shape_size = Vector2(40, 58)
			shape_off = Vector2(4, 0)
		_:
			art.body = Vector2(24, 8)
			art.tail = 40.0
	art.scale.x = float(dir)       # gambar dibuat menghadap kanan, dibalik kalau menembak ke kiri
	add_child(art)

	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = shape_size
	cs.shape = shape
	cs.position = Vector2(shape_off.x * float(dir), shape_off.y)
	add_child(cs)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var step: float = dir * speed * delta
	# raycast garis tengah peluru ke lantai / dinding (layer 1). Sekaligus mencegah peluru
	# secepat Scream menembus dinding tipis saat framerate turun.
	var from: Vector2 = global_position
	var to: Vector2 = from + Vector2(step, 0.0)
	var q := PhysicsRayQueryParameters2D.create(from, to, 1)
	q.hit_from_inside = true
	var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var scene := get_tree().current_scene
		if scene != null:
			WeaponFx.impact(scene, hit["position"], weapon, dir, false)
		Global.play_sfx("wall_impact", -12.0, randf_range(0.9, 1.12))
		queue_free()
		return
	position.x += step
	travelled += absf(step)
	if position.x < -120.0 or position.x > 1400.0:
		queue_free()
		return
	if max_range > 0.0 and travelled >= max_range:
		var scene2 := get_tree().current_scene
		if scene2 != null:
			WeaponFx.impact(scene2, global_position, weapon, dir, false)
		queue_free()


func _on_body_entered(body: Node) -> void:
	if not (body is Player):
		return
	var p: Player = body
	if p.index == shooter or not p.alive:
		return
	if team >= 0 and p.team == team:
		return
	p.take_damage(damage, dir, false, true, shooter)
	var scene := get_tree().current_scene
	if scene != null:
		WeaponFx.impact(scene, global_position, weapon, dir, true)
	queue_free()


# ================================================================== gambar peluru
class Art extends Node2D:
	var kind: String = "smith"
	var col: Color = Color("ffd23f")
	var glow: Color = Color("ff8a1f")
	var tex: Texture2D
	var body: Vector2 = Vector2(24, 8)     # ukuran sprite peluru (smith / kurval / pistol)
	var tail: float = 40.0                 # panjang jejak
	var tint: Color = Color.WHITE
	var age: float = 0.0
	var phase: float = 0.0

	func _init() -> void:
		phase = randf() * 100.0

	func _process(delta: float) -> void:
		age += delta
		queue_redraw()

	func _draw() -> void:
		match kind:
			"flamer":
				_draw_flame()
			"scream":
				_draw_wave()
			_:
				_draw_slug()

	## Peluru biasa: jejak bergradien (ekor transparan -> kepala terang) + sprite peluru.
	func _draw_slug() -> void:
		var grow: float = minf(age * 40.0, 1.0)            # jejak memanjang cepat saat ditembakkan
		var ln: float = tail * grow
		var h: float = body.y * 0.55
		var hx: float = -body.x * 0.2
		draw_polygon(
			PackedVector2Array([Vector2(-ln, 0.0), Vector2(hx, -h), Vector2(hx, h)]),
			PackedColorArray([Color(glow, 0.0), Color(glow, 0.55), Color(glow, 0.55)]))
		draw_circle(Vector2(hx, 0.0), body.y * 1.1, Color(glow, 0.2))
		if tex != null:
			draw_texture_rect(tex, Rect2(-body.x * 0.5, -body.y * 0.5, body.x, body.y), false, tint)

	## Flamer: bola api yang berkedip, ekornya gumpalan api yang mengecil dan memerah.
	func _draw_flame() -> void:
		var tt: float = age + phase
		var grow: float = 1.0 + minf(age * 0.9, 0.45)
		for i in range(5, 0, -1):
			var f: float = float(i) / 5.0
			var off := Vector2(-f * 40.0, sin(tt * 38.0 + f * 5.0) * 4.0 * f)
			var r: float = (13.0 - f * 8.0 + sin(tt * 52.0 + f * 3.0) * 1.5) * grow
			var c: Color = Color("ff9a1f").lerp(Color("c42a0a"), f)
			draw_circle(off, r, Color(c, 0.55 * (1.0 - f * 0.55)))
		var r1: float = (13.0 + sin(tt * 45.0) * 2.0) * grow
		draw_circle(Vector2.ZERO, r1, Color("ff5a14", 0.9))
		draw_circle(Vector2.ZERO, r1 * 0.72, Color("ffa526", 0.95))
		draw_circle(Vector2.ZERO, r1 * 0.45, Color("ffe27a"))
		draw_circle(Vector2(2.0, 0.0), r1 * 0.2, Color.WHITE)

	## Scream: inti terang + gelombang suara ")))" yang berdenyut.
	func _draw_wave() -> void:
		var tt: float = age * 22.0 + phase
		var pulse: float = 1.0 + 0.08 * sin(tt)
		draw_circle(Vector2.ZERO, 24.0 * pulse, Color(glow, 0.22))
		draw_circle(Vector2.ZERO, 13.0 * pulse, Color(col, 0.55))
		draw_circle(Vector2.ZERO, 6.0, Color.WHITE)
		for i in 3:
			var fi: float = float(i)
			var cx: float = -10.0 - fi * 22.0
			var rad: float = (34.0 - fi * 5.0) * pulse
			var a: float = 0.95 - fi * 0.28
			var wd: float = 7.0 - fi * 1.5
			draw_arc(Vector2(cx, 0.0), rad, deg_to_rad(-52.0), deg_to_rad(52.0), 18, Color(col, a), wd, true)
			draw_arc(Vector2(cx, 0.0), rad, deg_to_rad(-52.0), deg_to_rad(52.0), 18, Color(1, 1, 1, a * 0.9), wd * 0.4, true)
