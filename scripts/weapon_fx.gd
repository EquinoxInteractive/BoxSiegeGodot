extends RefCounted
## Efek visual & "game feel" senjata. Semua digambar lewat kode (tanpa aset baru).
## Dipakai dengan:   const WeaponFx = preload("res://scripts/weapon_fx.gd")
##
##   muzzle()      kilatan moncong + percikan + selongsong peluru + asap (beda tiap senjata)
##   impact()      efek saat peluru kena dinding / pemain
##   slash()       busur tebasan pisau
##   stab_hit()    percikan saat pisau mengenai pemain
##   float_text()  tulisan melayang ("NO AMMO", "PISTOL!", "KNIFE")
##
## Warna tiap senjata diambil dari Global.WEAPONS ("color" & "glow"), angka efek ada di STYLE di bawah.

## kick_px  = seberapa jauh senjata terhentak ke belakang (px)
## kick_deg = seberapa naik moncongnya (derajat)
## shake    = getar layar, rumble = [lemah, kuat, durasi], squash = penyok badan pemain
const STYLE := {
	"smith": {"flash_len": 36.0, "flash_w": 18.0, "shake": 1.6, "rumble": [0.25, 0.05, 0.07],
		"kick_px": 9.0, "kick_deg": 12.0, "casing": true, "smoke": 0, "squash": 0.0},
	"kurval": {"flash_len": 48.0, "flash_w": 24.0, "shake": 3.4, "rumble": [0.4, 0.3, 0.12],
		"kick_px": 15.0, "kick_deg": 18.0, "casing": true, "smoke": 3, "squash": 0.07},
	"flamer": {"flash_len": 40.0, "flash_w": 22.0, "shake": 0.7, "rumble": [0.35, 0.1, 0.05],
		"kick_px": 4.0, "kick_deg": 3.0, "casing": false, "smoke": 0, "squash": 0.0},
	"scream": {"flash_len": 78.0, "flash_w": 46.0, "shake": 10.0, "rumble": [0.9, 1.0, 0.35],
		"kick_px": 24.0, "kick_deg": 24.0, "casing": false, "smoke": 5, "squash": 0.2},
	"pistol": {"flash_len": 24.0, "flash_w": 12.0, "shake": 1.0, "rumble": [0.15, 0.0, 0.05],
		"kick_px": 7.0, "kick_deg": 15.0, "casing": true, "smoke": 0, "squash": 0.0},
	"knife": {"flash_len": 0.0, "flash_w": 0.0, "shake": 1.0, "rumble": [0.1, 0.0, 0.04],
		"kick_px": 0.0, "kick_deg": 0.0, "casing": false, "smoke": 0, "squash": 0.0},
}


## Gabungan angka efek (STYLE) + warna senjata (Global.WEAPONS).
static func style(id: String) -> Dictionary:
	var base: Dictionary = STYLE["smith"]
	if STYLE.has(id):
		base = STYLE[id]
	var st: Dictionary = base.duplicate()
	var w: Dictionary = {}
	if Global.WEAPONS.has(id):
		w = Global.WEAPONS[id]
	st["color"] = w.get("color", Color("ffd23f"))
	st["glow"] = w.get("glow", Color("ff8a1f"))
	return st


# ------------------------------------------------------------------ moncong
static func muzzle(parent: Node, pos: Vector2, dir: int, id: String) -> void:
	if parent == null:
		return
	var st: Dictionary = style(id)
	var col: Color = st["color"]
	var glow: Color = st["glow"]

	var life: float = 0.12 if id == "scream" else 0.07
	var f := MuzzleFlash.new()
	f.setup(dir, float(st["flash_len"]), float(st["flash_w"]), col, glow, life)
	f.position = pos
	f.z_index = 51
	parent.add_child(f)

	match id:
		"flamer":
			flame_puff(parent, pos + Vector2(dir * 6.0, 0.0), dir, 4)
		"scream":
			UIKit.ring(parent, pos, col, 150.0, 0.38)
			UIKit.ring(parent, pos, Color.WHITE, 80.0, 0.22)
			sparks(parent, pos, dir, col, 22, 620.0)
			sparks(parent, pos, dir, Color.WHITE, 8, 420.0)
		"kurval":
			sparks(parent, pos, dir, col, 10, 420.0)
		_:
			sparks(parent, pos, dir, col, 6, 340.0)

	if bool(st["casing"]):
		var c := Casing.new()
		c.setup(Vector2(-dir * randf_range(40.0, 120.0), randf_range(-340.0, -230.0)), randf_range(-18.0, 18.0))
		c.position = pos + Vector2(-dir * 26.0, -4.0)
		c.z_index = 48
		parent.add_child(c)

	var smoke_n: int = int(st["smoke"])
	if smoke_n > 0:
		smoke(parent, pos, dir, smoke_n)


# ------------------------------------------------------------------ dampak peluru
static func impact(parent: Node, pos: Vector2, id: String, dir: int, _hit_player: bool) -> void:
	if parent == null:
		return
	var st: Dictionary = style(id)
	var col: Color = st["color"]
	var glow: Color = st["glow"]
	match id:
		"flamer":
			flame_puff(parent, pos, -dir, 6)
			UIKit.burst(parent, pos, glow, 5, 140.0, 4.0, 0.3, -100.0)
		"scream":
			UIKit.ring(parent, pos, col, 130.0, 0.4)
			UIKit.ring(parent, pos, Color.WHITE, 70.0, 0.25)
			UIKit.burst(parent, pos, col, 22, 460.0, 8.0, 0.55, 200.0)
		_:
			sparks(parent, pos, -dir, col, 8, 340.0)
			UIKit.burst(parent, pos, Color.WHITE, 3, 160.0, 3.0, 0.15, 0.0)


# ------------------------------------------------------------------ pisau
static func slash(parent: Node, pos: Vector2, dir: int) -> void:
	if parent == null:
		return
	var s := SlashFx.new()
	s.setup(dir)
	s.position = pos
	s.z_index = 52
	parent.add_child(s)


static func stab_hit(parent: Node, pos: Vector2, dir: int) -> void:
	if parent == null:
		return
	UIKit.burst(parent, pos, Color("ff4a4a"), 18, 460.0, 6.0, 0.5, 800.0)
	sparks(parent, pos, dir, Color.WHITE, 10, 520.0)
	UIKit.ring(parent, pos, Color("ffdddd"), 90.0, 0.25)


# ------------------------------------------------------------------ partikel
static func sparks(parent: Node, pos: Vector2, dir: int, color: Color, count: int, speed: float) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.22
	p.explosiveness = 1.0
	p.direction = Vector2(dir, -0.25)
	p.spread = 38.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 700)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.0
	p.color = color
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.z_index = 50
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func smoke(parent: Node, pos: Vector2, dir: int, count: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.7
	p.explosiveness = 0.8
	p.direction = Vector2(dir, -0.6)
	p.spread = 30.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, -50)
	p.scale_amount_min = 5.0
	p.scale_amount_max = 9.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 1.6))
	p.scale_amount_curve = curve
	p.color = Color(0.85, 0.85, 0.9, 0.55)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.7))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.z_index = 49
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func flame_puff(parent: Node, pos: Vector2, dir: int, count: int) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = count
	p.lifetime = 0.32
	p.explosiveness = 0.9
	p.direction = Vector2(dir, -0.15)
	p.spread = 24.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 320.0
	p.gravity = Vector2(0, -260)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve
	p.color = Color.WHITE
	var g := Gradient.new()
	g.set_color(0, Color("fff2a0"))
	g.set_color(1, Color(0.9, 0.1, 0.0, 0.0))
	g.add_point(0.35, Color("ff9a1f"))
	g.add_point(0.7, Color("e63a12"))
	p.color_ramp = g
	p.z_index = 50
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


# ------------------------------------------------------------------ teks melayang
static func float_text(parent: Node, pos: Vector2, text: String, color: Color, fsize: int = 22) -> void:
	if parent == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Global.font_ui)
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 8)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(160, 0)
	l.size = Vector2(160, 30)
	l.position = pos - Vector2(80, 0)
	l.pivot_offset = Vector2(80, 15)
	l.scale = Vector2.ONE * 0.4
	l.z_index = 60
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", pos.y - 34.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.5)
	tw.chain().tween_callback(l.queue_free)


# ================================================================== kilatan moncong
class MuzzleFlash extends Node2D:
	var dir: int = 1
	var length: float = 34.0
	var width: float = 16.0
	var color: Color = Color("ffd23f")
	var glow: Color = Color("ff8a1f")
	var life: float = 0.07
	var t: float = 0.0

	func setup(d: int, ln: float, w: float, c: Color, g: Color, l: float) -> void:
		dir = d
		length = ln
		width = w
		color = c
		glow = g
		life = l
		rotation = randf_range(-0.14, 0.14)
		scale = Vector2.ONE * randf_range(0.9, 1.12)

	func _process(delta: float) -> void:
		t += delta
		if t >= life:
			queue_free()
			return
		queue_redraw()

	func _star(ln: float, w: float) -> PackedVector2Array:
		var s: float = float(dir)
		return PackedVector2Array([
			Vector2(-4.0 * s, 0.0),
			Vector2(ln * 0.22 * s, -w * 0.62),
			Vector2(ln * 0.40 * s, -w * 0.16),
			Vector2(ln * s, 0.0),
			Vector2(ln * 0.40 * s, w * 0.16),
			Vector2(ln * 0.22 * s, w * 0.62),
		])

	func _draw() -> void:
		var p: float = clampf(t / life, 0.0, 1.0)
		var grow: float = 1.0 - pow(1.0 - p, 3.0)          # membesar cepat
		var a: float = 1.0 - p                              # lalu memudar
		var ln: float = length * (0.45 + 0.55 * grow)
		var w: float = width * (0.7 + 0.3 * grow)
		var s: float = float(dir)
		draw_circle(Vector2(s * ln * 0.15, 0.0), w * 0.95, Color(glow, 0.22 * a))
		draw_colored_polygon(_star(ln, w), Color(color, 0.95 * a))
		draw_colored_polygon(_star(ln * 0.62, w * 0.55), Color(1, 1, 1, 0.95 * a))
		draw_line(Vector2(s * ln * 0.05, 0.0), Vector2(s * ln * 0.22, -w * 1.1), Color(color, 0.8 * a), 3.0)
		draw_line(Vector2(s * ln * 0.05, 0.0), Vector2(s * ln * 0.22, w * 1.1), Color(color, 0.8 * a), 3.0)
		draw_circle(Vector2(s * 3.0, 0.0), w * 0.42 * (1.0 - p * 0.5), Color(1, 1, 1, a))


# ================================================================== selongsong peluru
class Casing extends Node2D:
	var vel: Vector2 = Vector2.ZERO
	var spin: float = 0.0
	var age: float = 0.0
	var life: float = 0.9

	func setup(v: Vector2, sp: float) -> void:
		vel = v
		spin = sp

	func _process(delta: float) -> void:
		age += delta
		if age >= life:
			queue_free()
			return
		vel.y += 1500.0 * delta
		position += vel * delta
		rotation += spin * delta
		modulate.a = clampf((life - age) / 0.25, 0.0, 1.0)

	func _draw() -> void:
		draw_rect(Rect2(-4, -2, 8, 4), Color("d9a63b"))
		draw_rect(Rect2(-4, -2, 8, 1.5), Color("ffe08a"))
		draw_rect(Rect2(2, -2, 2, 4), Color("a8741f"))


# ================================================================== tebasan pisau
class SlashFx extends Node2D:
	var dir: int = 1
	var t: float = 0.0
	var life: float = 0.2
	var radius: float = 74.0

	func setup(d: int) -> void:
		dir = d

	func _process(delta: float) -> void:
		t += delta
		if t >= life:
			queue_free()
			return
		queue_redraw()

	func _point(a: float) -> Vector2:
		return Vector2(cos(a) * float(dir), sin(a)) * radius

	func _draw() -> void:
		var p: float = clampf(t / life, 0.0, 1.0)
		var sweep: float = deg_to_rad(150.0)
		var a0: float = deg_to_rad(-75.0)
		var head: float = a0 + sweep * (1.0 - pow(1.0 - minf(p * 2.4, 1.0), 3.0))     # kepala menyapu cepat
		var tail: float = a0 + sweep * clampf((p - 0.2) / 0.8, 0.0, 1.0)              # ekor menyusul lalu hilang
		if head - tail < 0.02:
			return
		var steps: int = 18
		var fade: float = 1.0 - smoothstep(0.4, 1.0, p)
		var prev: Vector2 = _point(tail)
		for i in range(1, steps + 1):
			var u: float = float(i) / float(steps)
			var cur: Vector2 = _point(lerpf(tail, head, u))
			var wd: float = lerpf(2.0, 15.0, u)                 # makin tebal ke arah kepala
			draw_line(prev, cur, Color(0.55, 0.8, 1.0, 0.35 * fade), wd + 8.0)
			draw_line(prev, cur, Color(0.85, 0.95, 1.0, 0.8 * fade), wd)
			draw_line(prev, cur, Color(1, 1, 1, fade), wd * 0.38)
			prev = cur
		draw_circle(_point(head), 7.0 * fade, Color(1, 1, 1, 0.9 * fade))
