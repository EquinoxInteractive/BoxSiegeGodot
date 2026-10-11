class_name Hazards
extends RefCounted
## Semua rintangan arena. Dibuat murni dari kode (tanpa aset baru) dan dipakai oleh game.gd
## berdasarkan data di map_data.gd:
##   MovingPlatform  platform bergerak (gerak sinus, kecepatan pelan supaya adil)
##   CrumblePlatform platform rapuh: diinjak -> bergetar -> hilang -> muncul lagi
##   SpikeStrip      duri / kaktus: -1 darah, pemain terpental ke atas
##   BouncePad       jamur pantul
##   DartTrap + Arrow  jebakan panah dari dinding (ada peringatan merah sebelum menembak)
##   ice()           permukaan es licin (efeknya dihitung di Player lewat Game.surface_grip)
##   ambient()       partikel suasana per map ("snow", "dust", "leaves", "motes", "bubbles", "stars", "sparks")
##   --- rintangan baru (map Ocean / Space / Factory) ---
##   UpdraftVent     geyser laut (menyembur berkala, ada peringatan buih) & lift anti-gravitasi (selalu aktif)
##   Portal          portal teleport berpasangan (kiri <-> kanan)
##   Conveyor        ban berjalan (mendorong pemain di atasnya)
##   SawBlade        gergaji bulat di rel (kena = -1 darah + terpental, sama seperti duri)
##   DartTrap kind "cannon"  meriam kapal (peluru bola besar, lebih lambat dari panah)


# ------------------------------------------------------------------ gambar blok
## Blok bertekstur (sama dengan lantai/platform biasa) yang digambar relatif ke pojok kiri-atas (0,0).
static func block_art(size: Vector2, tex: Texture2D, edge: Color, one_way: bool) -> Node2D:
	var root := Node2D.new()

	var spr := Sprite2D.new()
	spr.texture = tex
	spr.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	spr.centered = false
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, size.x / 4.0, size.y / 4.0)
	spr.scale = Vector2(4, 4)
	spr.z_index = -10
	root.add_child(spr)

	var strip := ColorRect.new()
	strip.color = edge
	strip.size = Vector2(size.x, 6)
	strip.z_index = -9
	root.add_child(strip)

	if one_way:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, 0.35)
		shade.position = Vector2(0, size.y - 4)
		shade.size = Vector2(size.x, 4)
		shade.z_index = -9
		root.add_child(shade)
	return root


## Garis tepi putih tipis supaya platform "spesial" (bergerak / rapuh) mudah dikenali.
static func outline(size: Vector2, color: Color) -> Line2D:
	var l := Line2D.new()
	l.points = PackedVector2Array([
		Vector2(1, 1), Vector2(size.x - 1, 1), Vector2(size.x - 1, size.y - 1),
		Vector2(1, size.y - 1), Vector2(1, 1),
	])
	l.width = 2.0
	l.default_color = color
	l.z_index = -8
	return l


# ------------------------------------------------------------------ platform bergerak
class MovingPlatform extends AnimatableBody2D:
	var origin: Vector2
	var move: Vector2 = Vector2.ZERO
	var period: float = 6.0
	var phase: float = 0.0
	var t: float = 0.0

	func setup(rect: Rect2, tex: Texture2D, edge: Color, mv: Vector2, per: float, ph: float) -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		sync_to_physics = true
		collision_layer = 2          # one-way, sama seperti platform biasa
		collision_mask = 0
		origin = rect.position
		move = mv
		period = maxf(per, 0.5)
		phase = ph

		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		cs.shape = shape
		cs.position = rect.size * 0.5
		cs.one_way_collision = true
		cs.one_way_collision_margin = 10.0
		add_child(cs)

		add_child(Hazards.block_art(rect.size, tex, edge, true))
		add_child(Hazards.outline(rect.size, Color(1, 1, 1, 0.55)))
		position = _pos_at(0.0)

	func _pos_at(time: float) -> Vector2:
		return origin + move * sin(TAU * time / period + phase)

	func reset_motion() -> void:
		t = 0.0
		position = _pos_at(0.0)

	func _physics_process(delta: float) -> void:
		t += delta
		position = _pos_at(t)


# ------------------------------------------------------------------ platform rapuh
class CrumblePlatform extends StaticBody2D:
	const SHAKE_TIME := 0.55
	const GONE_TIME := 3.0

	var size: Vector2
	var mode: int = 0                # 0 = utuh, 1 = bergetar, 2 = hilang
	var timer: float = 0.0
	var art: Node2D
	var cs: CollisionShape2D
	var sensor: Area2D
	var fade: Tween

	func setup(rect: Rect2, tex: Texture2D, edge: Color) -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		size = rect.size
		position = rect.position
		collision_layer = 2
		collision_mask = 0

		cs = CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = size
		cs.shape = shape
		cs.position = size * 0.5
		cs.one_way_collision = true
		cs.one_way_collision_margin = 8.0
		add_child(cs)

		art = Hazards.block_art(size, tex, edge, true)
		art.modulate = Color(1.0, 0.93, 0.82)
		add_child(art)
		# retakan bergerigi supaya kelihatan rapuh
		for cx in [0.27, 0.66]:
			var crack := Line2D.new()
			crack.default_color = Color(0, 0, 0, 0.55)
			crack.width = 2.0
			crack.z_index = -8
			var bx: float = size.x * cx
			crack.points = PackedVector2Array([
				Vector2(bx, 6), Vector2(bx + 5, 11), Vector2(bx - 2, 15),
				Vector2(bx + 6, 19), Vector2(bx + 2, size.y - 2),
			])
			art.add_child(crack)
		art.add_child(Hazards.outline(size, Color(1, 0.9, 0.6, 0.45)))

		# sensor: seluruh platform + sedikit area di atasnya
		sensor = Area2D.new()
		sensor.collision_layer = 0
		sensor.collision_mask = 4
		var sc := CollisionShape2D.new()
		var ss := RectangleShape2D.new()
		ss.size = Vector2(size.x - 4.0, size.y + 14.0)
		sc.shape = ss
		sc.position = Vector2(size.x * 0.5, size.y * 0.5 - 7.0)
		sensor.add_child(sc)
		add_child(sensor)

	func reset_state() -> void:
		if fade:
			fade.kill()
		mode = 0
		timer = 0.0
		art.position = Vector2.ZERO
		art.modulate = Color(1.0, 0.93, 0.82)
		cs.set_deferred("disabled", false)

	func _stood_on() -> bool:
		for b in sensor.get_overlapping_bodies():
			if b is Player:
				var p: Player = b
				if p.alive and not p.vanished and p.is_on_floor():
					var feet: float = p.global_position.y + 30.0
					if absf(feet - global_position.y) < 10.0:
						return true
		return false

	func _occupied() -> bool:
		for b in sensor.get_overlapping_bodies():
			if b is Player:
				var p: Player = b
				if p.alive and not p.vanished:
					return true
		return false

	func _physics_process(delta: float) -> void:
		match mode:
			0:
				if _stood_on():
					mode = 1
					timer = SHAKE_TIME
					Global.play_sfx("crumble_warn", -6.0)
			1:
				timer -= delta
				art.position = Vector2(randf_range(-2.5, 2.5), randf_range(-1.5, 1.5))
				art.modulate = Color(1.0, 0.75 + 0.2 * sin(timer * 40.0), 0.6)
				if timer <= 0.0:
					_fall()
			2:
				timer -= delta
				if timer <= 0.0 and not _occupied():
					_restore()

	func _fall() -> void:
		mode = 2
		timer = GONE_TIME
		cs.set_deferred("disabled", true)
		art.position = Vector2.ZERO
		var parent := get_parent()
		if parent != null:
			UIKit.burst(parent, global_position + Vector2(size.x * 0.5, size.y * 0.5), Color("d9b874"), 22, 240.0, 8.0, 0.7, 900.0)
		Global.play_sfx("crumble_fall", -8.0)
		if fade:
			fade.kill()
		fade = create_tween()
		fade.tween_property(art, "modulate:a", 0.0, 0.25)

	func _restore() -> void:
		mode = 0
		cs.set_deferred("disabled", false)
		art.position = Vector2.ZERO
		art.modulate = Color(1.0, 0.93, 0.82, 0.0)
		if fade:
			fade.kill()
		fade = create_tween()
		fade.tween_property(art, "modulate:a", 1.0, 0.35)


# ------------------------------------------------------------------ duri & kaktus
class SpikeStrip extends Node2D:
	var rect: Rect2
	var area: Area2D

	func setup(r: Rect2, style: String) -> void:
		rect = r
		position = r.position
		z_index = -5
		if style == "cactus":
			var n := maxi(int(round(r.size.x / 36.0)), 1)
			var uw := r.size.x / float(n)
			for i in n:
				add_child(_cactus(Vector2(i * uw, 0.0), uw, r.size.y))
		else:
			var n2 := maxi(int(round(r.size.x / 40.0)), 1)
			var uw2 := r.size.x / float(n2)
			var tex := Global.cached_tex("res://assets/sprites/stages/%s_spike.png" % style)
			for i in n2:
				var x0: float = i * uw2
				# lingkaran peringatan merah di belakang duri
				var glow := Polygon2D.new()
				glow.color = Color(1.0, 0.15, 0.1, 0.38)
				glow.polygon = PackedVector2Array([
					Vector2(x0 - 3.0, r.size.y + 2.0), Vector2(x0 + uw2 * 0.5, -5.0), Vector2(x0 + uw2 + 3.0, r.size.y + 2.0),
				])
				add_child(glow)
				var s := Sprite2D.new()
				s.texture = tex
				s.centered = false
				s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
				s.region_enabled = true
				s.region_rect = Rect2(48, 0, 263, 180)   # segitiga di dalam kanvas 360x180
				s.scale = Vector2(uw2 / 263.0, r.size.y / 180.0)
				s.position = Vector2(x0, 0.0)
				add_child(s)
				# kilau ujung runcing
				var tip := Polygon2D.new()
				tip.color = Color(0.95, 0.95, 0.9, 0.75)
				tip.polygon = PackedVector2Array([
					Vector2(x0 + uw2 * 0.5, 1.0), Vector2(x0 + uw2 * 0.5 + uw2 * 0.12, r.size.y * 0.3),
					Vector2(x0 + uw2 * 0.5 - uw2 * 0.12, r.size.y * 0.3),
				])
				add_child(tip)

		# hitbox sedikit lebih kecil dari gambar supaya terasa adil
		area = Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 4
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		var hb := Rect2(8.0, r.size.y * 0.35, maxf(r.size.x - 16.0, 8.0), r.size.y * 0.65)
		sh.size = hb.size
		cs.shape = sh
		cs.position = hb.position + hb.size * 0.5
		area.add_child(cs)
		add_child(area)

	func _cactus(origin: Vector2, w: float, h: float) -> Node2D:
		var c := Node2D.new()
		c.position = origin
		var dark := Color("2f7d32")
		var mid := Color("46a84a")
		var line := Color("1c4d1f")
		var cx: float = w * 0.5
		var tw: float = w * 0.34
		# batang
		_poly(c, [Vector2(cx - tw * 0.5, h), Vector2(cx - tw * 0.5, h * 0.12), Vector2(cx - tw * 0.25, 0.0),
			Vector2(cx + tw * 0.25, 0.0), Vector2(cx + tw * 0.5, h * 0.12), Vector2(cx + tw * 0.5, h)], dark)
		_poly(c, [Vector2(cx - tw * 0.1, h), Vector2(cx - tw * 0.1, 3.0), Vector2(cx + tw * 0.25, 3.0),
			Vector2(cx + tw * 0.5 - 2.0, h * 0.14), Vector2(cx + tw * 0.5 - 2.0, h)], mid)
		# lengan kiri & kanan
		_poly(c, [Vector2(cx - tw * 0.5, h * 0.62), Vector2(2.0, h * 0.62), Vector2(2.0, h * 0.3),
			Vector2(2.0 + tw * 0.45, h * 0.3), Vector2(2.0 + tw * 0.45, h * 0.5), Vector2(cx - tw * 0.5, h * 0.5)], dark)
		_poly(c, [Vector2(cx + tw * 0.5, h * 0.7), Vector2(w - 2.0, h * 0.7), Vector2(w - 2.0, h * 0.38),
			Vector2(w - 2.0 - tw * 0.45, h * 0.38), Vector2(w - 2.0 - tw * 0.45, h * 0.58), Vector2(cx + tw * 0.5, h * 0.58)], dark)
		# duri putih kecil
		for k in 5:
			var yy: float = h * (0.12 + 0.17 * k)
			var l := Line2D.new()
			l.default_color = Color(1, 1, 0.85, 0.9)
			l.width = 1.5
			l.points = PackedVector2Array([Vector2(cx - tw * 0.5 - 3.0, yy), Vector2(cx - tw * 0.5, yy + 2.0)])
			c.add_child(l)
			var r2 := Line2D.new()
			r2.default_color = Color(1, 1, 0.85, 0.9)
			r2.width = 1.5
			r2.points = PackedVector2Array([Vector2(cx + tw * 0.5 + 3.0, yy + 4.0), Vector2(cx + tw * 0.5, yy + 6.0)])
			c.add_child(r2)
		var out := Line2D.new()
		out.default_color = line
		out.width = 2.0
		out.points = PackedVector2Array([Vector2(cx - tw * 0.5, h), Vector2(cx - tw * 0.5, h * 0.12), Vector2(cx - tw * 0.25, 0.0),
			Vector2(cx + tw * 0.25, 0.0), Vector2(cx + tw * 0.5, h * 0.12), Vector2(cx + tw * 0.5, h)])
		c.add_child(out)
		# bayangan merah peringatan di bawah
		var warn := Polygon2D.new()
		warn.color = Color(1.0, 0.15, 0.1, 0.25)
		warn.polygon = PackedVector2Array([Vector2(1.0, h + 2.0), Vector2(1.0, h - 6.0), Vector2(w - 1.0, h - 6.0), Vector2(w - 1.0, h + 2.0)])
		c.add_child(warn)
		return c

	func _poly(parent: Node2D, pts: Array, color: Color) -> void:
		var p := Polygon2D.new()
		p.color = color
		p.polygon = PackedVector2Array(pts)
		parent.add_child(p)


# ------------------------------------------------------------------ jamur pantul
class BouncePad extends Node2D:
	var rect: Rect2
	var power: float = -1050.0
	var area: Area2D
	var squash: float = 0.0

	func setup(r: Rect2, pw: float) -> void:
		rect = r
		power = pw
		position = r.position
		z_index = -4
		area = Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 4
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = Vector2(r.size.x - 8.0, r.size.y)
		cs.shape = sh
		cs.position = r.size * 0.5
		area.add_child(cs)
		add_child(area)

	func pulse() -> void:
		squash = 1.0
		create_tween().tween_property(self, "squash", 0.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w: float = rect.size.x
		var h: float = rect.size.y
		var sq: float = squash
		# batang
		draw_rect(Rect2(w * 0.38, h * 0.5, w * 0.24, h * 0.5), Color("f1e3c8"))
		draw_rect(Rect2(w * 0.38, h * 0.5, w * 0.06, h * 0.5), Color(0, 0, 0, 0.12))
		# topi (setengah elips), menggepeng saat dipijak
		var cap_h: float = h * (0.62 - 0.22 * sq)
		var pts := PackedVector2Array()
		for i in 21:
			var a: float = PI + PI * float(i) / 20.0
			pts.append(Vector2(w * 0.5 + cos(a) * w * 0.5, h * 0.62 + sin(a) * cap_h))
		draw_colored_polygon(pts, Color("e23d5a"))
		draw_polyline(pts, Color("7a1229"), 2.5, true)
		draw_circle(Vector2(w * 0.3, h * 0.38), 4.5, Color("ffe9ee"))
		draw_circle(Vector2(w * 0.55, h * 0.26 + sq * 5.0), 5.5, Color("ffe9ee"))
		draw_circle(Vector2(w * 0.74, h * 0.42), 4.0, Color("ffe9ee"))
		# tanda panah ke atas
		var bob: float = 3.0 * sin(Time.get_ticks_msec() * 0.006)
		var ac := Vector2(w * 0.5, -10.0 + bob)
		draw_colored_polygon(PackedVector2Array([ac + Vector2(0, -8), ac + Vector2(9, 4), ac + Vector2(-9, 4)]), Color(1, 1, 1, 0.75))


# ------------------------------------------------------------------ jebakan panah
class Arrow extends Area2D:
	var dir: int = 1
	var speed: float = 620.0
	var kind: String = "dart"        # "dart" = panah, "cannon" = bola meriam

	func setup(d: int, spd: float, k: String = "dart") -> void:
		dir = d
		speed = spd
		kind = k

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		collision_layer = 0
		collision_mask = 5          # lantai/dinding/piramida (1) + pemain (4)
		z_index = 3
		var cs := CollisionShape2D.new()
		if kind == "cannon":
			var cshape := CircleShape2D.new()
			cshape.radius = 15.0
			cs.shape = cshape
		else:
			var sh := RectangleShape2D.new()
			sh.size = Vector2(46, 12)
			cs.shape = sh
		add_child(cs)
		body_entered.connect(_on_body_entered)

	func _physics_process(delta: float) -> void:
		position.x += dir * speed * delta
		if position.x < -80.0 or position.x > 1360.0:
			queue_free()

	func _on_body_entered(body: Node) -> void:
		if body is Player:
			var p: Player = body
			if not p.alive or p.vanished or p.invuln > 0.0:
				return          # panah menembus pemain yang kebal / sudah mati
			p.take_damage(1, dir)
		else:
			var scene := get_tree().current_scene
			if scene != null:
				var spark: Color = Color("ffb347") if kind == "cannon" else Color("e8dc8a")
				UIKit.burst(scene, global_position, spark, 8, 180.0, 4.0, 0.3, 400.0)
		queue_free()

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if kind == "cannon":
			# jejak asap di belakang + bola besi dengan kilau
			var back: float = -float(dir)
			draw_circle(Vector2(back * 44.0, 0.0), 6.0, Color(0.75, 0.75, 0.78, 0.18))
			draw_circle(Vector2(back * 32.0, 0.0), 9.0, Color(0.75, 0.75, 0.78, 0.28))
			draw_circle(Vector2(back * 20.0, 0.0), 12.0, Color(0.85, 0.8, 0.7, 0.4))
			draw_circle(Vector2.ZERO, 18.0, Color(1.0, 0.45, 0.1, 0.28))
			draw_circle(Vector2.ZERO, 16.0, Color("1d2027"))
			draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 24, Color("0b0c10"), 2.0, true)
			draw_circle(Vector2(-5.0, -5.0), 5.0, Color(0.62, 0.68, 0.8, 0.85))
			return
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(float(dir), 1.0))
		draw_rect(Rect2(-24, -2, 36, 4), Color("8a5a2b"))
		draw_colored_polygon(PackedVector2Array([Vector2(10, -8), Vector2(26, 0), Vector2(10, 8)]), Color("dfe6ea"))
		draw_colored_polygon(PackedVector2Array([Vector2(-24, -2), Vector2(-30, -8), Vector2(-16, -2)]), Color("ff5a3c"))
		draw_colored_polygon(PackedVector2Array([Vector2(-24, 2), Vector2(-30, 8), Vector2(-16, 2)]), Color("ff5a3c"))
		draw_set_transform(Vector2.ZERO)


class DartTrap extends Node2D:
	const WARN_TIME := 1.0
	const ARROW_SPEED := 620.0

	var side: int = -1               # -1 = dinding kiri (menembak ke kanan), 1 = dinding kanan
	var y: float = 612.0
	var first_delay: float = 7.0
	var interval: float = 9.0
	var timer: float = 7.0
	var arrows_root: Node2D
	var warn: float = 0.0            # 0..1 kekuatan peringatan
	var flash: float = 0.0
	var kind: String = "dart"        # "dart" = jebakan panah batu, "cannon" = meriam kapal

	func setup(s: int, yy: float, first: float, every: float, root: Node2D, k: String = "dart") -> void:
		kind = k
		side = s
		y = yy
		first_delay = first
		interval = every
		arrows_root = root
		timer = first_delay
		position = Vector2(0.0 if side < 0 else 1280.0, y)
		scale.x = 1.0 if side < 0 else -1.0
		z_index = -4

	func reset() -> void:
		timer = first_delay
		warn = 0.0
		flash = 0.0
		queue_redraw()

	## Dipanggil game.gd hanya saat ronde berjalan (PLAYING).
	func tick(delta: float) -> void:
		timer -= delta
		if timer <= WARN_TIME:
			warn = clampf(1.0 - timer / WARN_TIME, 0.0, 1.0)
		if timer <= 0.0:
			_fire()
			timer = interval
			warn = 0.0
		flash = maxf(flash - delta * 4.0, 0.0)
		queue_redraw()

	func _fire() -> void:
		flash = 1.0
		var a := Arrow.new()
		var cannon: bool = kind == "cannon"
		a.setup(1 if side < 0 else -1, 470.0 if cannon else ARROW_SPEED, kind)
		var mx: float = 58.0 if cannon else 34.0
		a.position = Vector2(mx if side < 0 else 1280.0 - mx, y)
		arrows_root.add_child(a)
		if cannon:
			Global.play_sfx("wall_impact", -6.0, randf_range(0.6, 0.72))
			var scene := get_tree().current_scene
			if scene != null:
				UIKit.burst(scene, a.position, Color("ffb347"), 10, 220.0, 5.0, 0.35, 200.0)
		else:
			Global.play_sfx("arrow_fire", -9.0, randf_range(0.95, 1.08))

	func _draw() -> void:
		# garis bidik peringatan (sampai tengah arena)
		if warn > 0.0:
			var pulse: float = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.03)
			draw_line(Vector2(40, 0), Vector2(620, 0), Color(1.0, 0.2, 0.15, 0.25 + 0.55 * warn * pulse), 4.0)
		if kind == "cannon":
			_draw_cannon()
			return
		# kepala jebakan dari batu
		var stone := Color("7a7864")
		draw_rect(Rect2(0, -30, 36, 60), stone)
		draw_rect(Rect2(0, -30, 36, 60), Color("2f2e24"), false, 3.0)
		draw_rect(Rect2(0, -30, 8, 60), Color(1, 1, 1, 0.12))
		var glow := Color(1.0, 0.25, 0.1).lerp(Color(1.0, 0.9, 0.5), flash)
		var ga: float = clampf(0.25 + warn * 0.75 + flash, 0.0, 1.0)
		draw_rect(Rect2(20, -9, 16, 18), Color("17160f"))
		draw_rect(Rect2(22, -7, 14, 14), Color(glow, ga))
		# ukiran
		draw_line(Vector2(6, -20), Vector2(6, 20), Color("2f2e24"), 2.0)
		draw_line(Vector2(12, -22), Vector2(16, -22), Color("2f2e24"), 2.0)
		draw_line(Vector2(12, 22), Vector2(16, 22), Color("2f2e24"), 2.0)

	## Meriam kapal: kereta kayu + laras besi + roda; moncongnya menyala saat akan menembak.
	func _draw_cannon() -> void:
		var wood := Color("6b4425")
		var wood_d := Color("3b2413")
		var iron := Color("3b414d")
		# dudukan di dinding
		draw_rect(Rect2(0, -22, 22, 44), wood)
		draw_rect(Rect2(0, -22, 22, 44), wood_d, false, 3.0)
		draw_line(Vector2(0, -8), Vector2(22, -8), wood_d, 2.0)
		draw_line(Vector2(0, 8), Vector2(22, 8), wood_d, 2.0)
		# laras
		draw_colored_polygon(PackedVector2Array([Vector2(10, -14), Vector2(54, -10), Vector2(54, 10), Vector2(10, 14)]), iron)
		draw_polyline(PackedVector2Array([Vector2(10, -14), Vector2(54, -10), Vector2(54, 10), Vector2(10, 14)]), Color("14161b"), 2.5)
		draw_line(Vector2(14, -10), Vector2(50, -7), Color(1, 1, 1, 0.22), 2.0)
		draw_rect(Rect2(46, -13, 8, 26), Color("272b34"))
		draw_rect(Rect2(46, -13, 8, 26), Color("0e0f13"), false, 2.0)
		# roda
		draw_circle(Vector2(18, 20), 11.0, wood_d)
		draw_circle(Vector2(18, 20), 8.0, wood)
		draw_circle(Vector2(18, 20), 2.5, Color("1a120a"))
		draw_line(Vector2(18, 12), Vector2(18, 28), wood_d, 2.0)
		draw_line(Vector2(10, 20), Vector2(26, 20), wood_d, 2.0)
		# nyala di moncong
		var glow := Color(1.0, 0.3, 0.1).lerp(Color(1.0, 0.9, 0.5), flash)
		var ga: float = clampf(warn * 0.8 + flash, 0.0, 1.0)
		if ga > 0.01:
			draw_circle(Vector2(56, 0), 8.0 + 8.0 * flash, Color(glow, ga * 0.7))
			draw_circle(Vector2(56, 0), 4.0 + 3.0 * flash, Color(1.0, 0.95, 0.7, ga))


# ------------------------------------------------------------------ geyser laut & lift anti-gravitasi
## Zona dorong ke atas (rect = koordinat dunia).
##   kind "geyser"  : menyembur berkala. Urutan: diam -> PERINGATAN (buih + garis merah) -> menyembur -> diam.
##   kind "antigrav": lift cahaya, selalu aktif.
## Semua pemain (dan musuh campaign) diperlakukan sama; arah dorong selalu ke atas, jadi mudah dibaca.
class UpdraftVent extends Node2D:
	var rect: Rect2
	var kind: String = "geyser"
	var first_delay: float = 3.0
	var rest_time: float = 3.4
	var warn_time: float = 1.0
	var active_time: float = 1.5
	var lift: float = 4600.0          # percepatan ke atas (gravitasi pemain = 2000)
	var max_rise: float = 640.0       # kecepatan naik maksimum (px/detik)
	var timer: float = 3.0
	var state: int = 0                # 0 diam, 1 peringatan, 2 menyembur
	var anim: float = 0.0
	var _sfx_cd: float = 0.0

	func setup(r: Rect2, k: String, first: float, rest: float, warn: float, active: float, lift_pw: float, rise: float) -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		rect = r
		kind = k
		first_delay = first
		rest_time = rest
		warn_time = warn
		active_time = active
		lift = lift_pw
		max_rise = rise
		position = r.position
		z_index = 3 if kind == "geyser" else -3
		reset()

	func reset() -> void:
		state = 0
		timer = first_delay
		queue_redraw()

	func is_active() -> bool:
		return kind != "geyser" or state == 2

	## Dipanggil game.gd hanya saat ronde berjalan (PLAYING).
	func tick(delta: float) -> void:
		if kind != "geyser":
			return
		timer -= delta
		match state:
			0:
				if timer <= warn_time:
					state = 1
					Global.play_sfx("swap_shuffle", -14.0, randf_range(1.4, 1.6))
			1:
				if timer <= 0.0:
					state = 2
					timer = active_time
					Global.play_sfx("whoosh_dash", -5.0, randf_range(0.6, 0.7))
					var scene := get_tree().current_scene
					if scene != null:
						UIKit.burst(scene, Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y - 6.0), Color("bfefff"), 16, 260.0, 6.0, 0.5, 500.0)
			2:
				if timer <= 0.0:
					state = 0
					timer = rest_time

	## Dorong satu pemain kalau dia berada di dalam zona.
	func push(p: Player, delta: float) -> void:
		if not is_active() or not p.alive or p.vanished:
			return
		if not rect.has_point(p.global_position):
			return
		p.velocity.y = maxf(p.velocity.y - lift * delta, -max_rise)
		p.launched = true         # supaya pemotong lompat tidak membatalkan dorongan
		p.coyote_timer = 0.0

	func _process(d: float) -> void:
		anim += d
		queue_redraw()

	func _draw() -> void:
		if kind == "geyser":
			_draw_geyser()
		else:
			_draw_antigrav()

	func _draw_geyser() -> void:
		var w: float = rect.size.x
		var h: float = rect.size.y
		var cx: float = w * 0.5
		# karang / lubang semburan di permukaan air
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 36.0, h + 8.0), Vector2(cx - 22.0, h - 12.0), Vector2(cx + 22.0, h - 12.0), Vector2(cx + 36.0, h + 8.0)]), Color("2f6a78"))
		draw_polyline(PackedVector2Array([Vector2(cx - 36.0, h + 8.0), Vector2(cx - 22.0, h - 12.0), Vector2(cx + 22.0, h - 12.0), Vector2(cx + 36.0, h + 8.0)]), Color("123943"), 2.5)
		draw_line(Vector2(cx - 18.0, h - 9.0), Vector2(cx + 4.0, h - 9.0), Color(1, 1, 1, 0.25), 2.0)
		draw_rect(Rect2(cx - 14.0, h - 14.0, 28.0, 5.0), Color("0b232a"))
		if state == 0:
			# gelembung kecil naik pelan
			for i in 4:
				var f: float = fposmod(anim * 0.45 + float(i) * 0.25, 1.0)
				draw_circle(Vector2(cx + sin(anim * 2.0 + float(i) * 2.0) * 9.0, h - 16.0 - f * 46.0), 2.0 + float(i % 2), Color(0.8, 0.96, 1.0, 0.5 * (1.0 - f)))
		elif state == 1:
			var k: float = clampf(1.0 - timer / maxf(warn_time, 0.01), 0.0, 1.0)
			var pulse: float = 0.5 + 0.5 * sin(anim * 26.0)
			# garis peringatan merah di sisi zona (sama seperti jebakan lain)
			var top_y: float = h * (1.0 - 0.35 - 0.4 * k)
			for yy in range(int(top_y), int(h) - 10, 22):
				draw_line(Vector2(cx - w * 0.42, float(yy)), Vector2(cx - w * 0.42, float(yy) + 11.0), Color(1.0, 0.25, 0.15, 0.25 + 0.6 * k * pulse), 3.0)
				draw_line(Vector2(cx + w * 0.42, float(yy)), Vector2(cx + w * 0.42, float(yy) + 11.0), Color(1.0, 0.25, 0.15, 0.25 + 0.6 * k * pulse), 3.0)
			# buih mendidih + semburan kecil
			for i in 9:
				var f2: float = fposmod(anim * (1.6 + 0.2 * float(i % 3)) + float(i) * 0.37, 1.0)
				var bx: float = cx + sin(float(i) * 2.3 + anim * 4.0) * w * 0.3
				draw_circle(Vector2(bx, h - 14.0 - f2 * (50.0 + 90.0 * k)), 3.0 + 2.0 * float(i % 3), Color(0.85, 0.98, 1.0, 0.65 * (1.0 - f2)))
			draw_rect(Rect2(cx - 11.0, h - 14.0 - 24.0 * k, 22.0, 24.0 * k), Color(0.6, 0.9, 1.0, 0.55))
			draw_circle(Vector2(cx, h - 16.0), 20.0 + 6.0 * pulse, Color(1, 1, 1, 0.2 + 0.25 * k))
		else:
			var grow: float = clampf((active_time - timer) / 0.22, 0.0, 1.0)
			var shrink: float = clampf(timer / 0.3, 0.0, 1.0)
			var top: float = h - (h - 8.0) * grow * (0.35 + 0.65 * shrink)
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			var n := 16
			for i in n + 1:
				var f3: float = float(i) / float(n)
				var yy2: float = lerpf(h - 12.0, top, f3)
				var hw: float = w * 0.34 * (1.0 - 0.22 * f3) + sin(anim * 11.0 + f3 * 9.0) * 3.0
				left.append(Vector2(cx - hw, yy2))
				right.append(Vector2(cx + hw, yy2))
			var poly := PackedVector2Array()
			for pt in left:
				poly.append(pt)
			for i in range(right.size() - 1, -1, -1):
				poly.append(right[i])
			draw_colored_polygon(poly, Color(0.5, 0.86, 1.0, 0.68))
			# inti terang & garis aliran
			var core := PackedVector2Array([Vector2(cx - w * 0.14, h - 12.0), Vector2(cx - w * 0.1, top + 10.0), Vector2(cx + w * 0.1, top + 10.0), Vector2(cx + w * 0.14, h - 12.0)])
			draw_colored_polygon(core, Color(0.85, 0.98, 1.0, 0.55))
			for i in 5:
				var f4: float = fposmod(anim * 2.2 + float(i) * 0.2, 1.0)
				var yy3: float = lerpf(h - 14.0, top + 8.0, f4)
				draw_line(Vector2(cx - w * 0.2, yy3), Vector2(cx - w * 0.2, yy3 - 14.0), Color(1, 1, 1, 0.6 * (1.0 - f4)), 2.0)
				draw_line(Vector2(cx + w * 0.2, yy3 - 6.0), Vector2(cx + w * 0.2, yy3 - 20.0), Color(1, 1, 1, 0.6 * (1.0 - f4)), 2.0)
			# kepala buih di puncak
			for i in 6:
				var ox: float = (float(i) - 2.5) * w * 0.12
				draw_circle(Vector2(cx + ox, top + 4.0 + sin(anim * 9.0 + float(i)) * 3.0), 9.0 + float(i % 2) * 3.0, Color(1, 1, 1, 0.85))
			draw_circle(Vector2(cx, h - 14.0), 26.0, Color(1, 1, 1, 0.3))

	func _draw_antigrav() -> void:
		var w: float = rect.size.x
		var h: float = rect.size.y
		var cx: float = w * 0.5
		# kolom cahaya: pekat di bawah, memudar di atas
		var c_top := Color(0.35, 0.95, 1.0, 0.03)
		var c_bot := Color(0.35, 0.95, 1.0, 0.26)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([c_top, c_top, c_bot, c_bot]))
		var edge_a: float = 0.55 + 0.2 * sin(anim * 5.0)
		draw_line(Vector2(0, 0), Vector2(0, h), Color(0.55, 1.0, 1.0, edge_a), 2.0)
		draw_line(Vector2(w, 0), Vector2(w, h), Color(0.55, 1.0, 1.0, edge_a), 2.0)
		# tanda panah naik yang bergerak ke atas
		var cnt := 5
		for i in cnt:
			var f: float = fposmod(anim * 0.55 + float(i) / float(cnt), 1.0)
			var yy: float = h - 16.0 - f * (h - 16.0)
			var a: float = sin(f * PI) * 0.85
			draw_polyline(PackedVector2Array([Vector2(cx - 15.0, yy + 9.0), Vector2(cx, yy - 5.0), Vector2(cx + 15.0, yy + 9.0)]), Color(0.8, 1.0, 1.0, a), 3.0, true)
		# butiran cahaya
		for i in 8:
			var f2: float = fposmod(anim * (0.3 + 0.07 * float(i % 4)) + float(i) * 0.19, 1.0)
			draw_circle(Vector2(6.0 + fposmod(float(i) * 37.0, w - 12.0), h - f2 * h), 1.8, Color(1, 1, 1, 0.7 * sin(f2 * PI)))
		# pemancar di lantai
		draw_rect(Rect2(-3.0, h - 8.0, w + 6.0, 8.0), Color("1a2150"))
		draw_rect(Rect2(-3.0, h - 8.0, w + 6.0, 8.0), Color("5bf0ff"), false, 2.0)
		draw_rect(Rect2(cx - 14.0, h - 6.0, 28.0, 3.0), Color(0.6, 1.0, 1.0, 0.6 + 0.4 * sin(anim * 6.0)))


# ------------------------------------------------------------------ portal teleport
## Dua portal berpasangan (kiri <-> kanan, selalu cermin). Masuk ke satu = muncul di pasangannya
## dengan kecepatan yang sama. Ada jeda singkat supaya tidak bolak-balik terus (diatur game.gd).
class Portal extends Node2D:
	var rect: Rect2
	var color: Color = Color("5bf0ff")
	var partner: Portal = null
	var anim: float = 0.0
	var flash: float = 0.0
	var phase: float = 0.0

	func setup(r: Rect2, c: Color, ph: float) -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		rect = r
		color = c
		phase = ph
		position = r.position
		z_index = -2

	## Posisi tengah badan pemain saat keluar dari portal ini (kaki tepat di dasar portal).
	func exit_point() -> Vector2:
		return Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y - 30.0)

	func pulse() -> void:
		flash = 1.0

	func _process(d: float) -> void:
		anim += d
		flash = maxf(flash - d * 2.6, 0.0)
		queue_redraw()

	func _draw() -> void:
		var w: float = rect.size.x
		var h: float = rect.size.y
		var c := Vector2(w * 0.5, h * 0.5)
		var rx: float = w * 0.5
		var ry: float = h * 0.5
		var pulse_s: float = 1.0 + 0.04 * sin(anim * 4.0 + phase) + 0.18 * flash
		# lonjong (lingkaran yang digepengkan)
		draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
		draw_circle(Vector2.ZERO, rx * 1.5 * pulse_s, Color(color, 0.1 + 0.2 * flash))
		draw_circle(Vector2.ZERO, rx * 1.2 * pulse_s, Color(color, 0.14 + 0.2 * flash))
		draw_circle(Vector2.ZERO, rx * pulse_s, color.darkened(0.78))
		draw_circle(Vector2.ZERO, rx * 0.8 * pulse_s, Color(color.darkened(0.55), 0.9))
		# pusaran
		for i in 3:
			var a0: float = anim * (2.4 + 0.7 * float(i)) * (1.0 if i % 2 == 0 else -1.0) + phase + float(i) * 2.0
			var rr: float = rx * (0.28 + 0.2 * float(i)) * pulse_s
			draw_arc(Vector2.ZERO, rr, a0, a0 + 2.3, 14, color.lightened(0.25 + 0.15 * float(i)), 2.5, true)
		draw_circle(Vector2.ZERO, rx * 0.16 * pulse_s, Color(1, 1, 1, 0.75 + 0.25 * flash))
		draw_arc(Vector2.ZERO, rx * pulse_s, 0.0, TAU, 40, color.lightened(0.35), 4.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# bantalan di bawah portal
		draw_rect(Rect2(-4.0, h - 3.0, w + 8.0, 6.0), Color(color.darkened(0.5), 0.95))
		draw_line(Vector2(-4.0, h - 3.0), Vector2(w + 4.0, h - 3.0), color.lightened(0.3), 2.0)


# ------------------------------------------------------------------ ban berjalan
## Permukaan yang menyeret pemain ke satu arah. rect.position.y = permukaan, speed (px/detik): + kanan, - kiri.
## Seretannya lemah (pemain lari 340 px/detik) tapi terasa; bisa dilawan dengan berlari berlawanan arah.
class Conveyor extends Node2D:
	var rect: Rect2
	var speed: float = 100.0
	var anim: float = 0.0

	func setup(r: Rect2, spd: float) -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		rect = r
		speed = spd
		position = r.position
		z_index = -7

	func _process(d: float) -> void:
		anim += speed * d
		queue_redraw()

	func _draw() -> void:
		var w: float = rect.size.x
		var h: float = 10.0
		var dir: float = 1.0 if speed >= 0.0 else -1.0
		draw_rect(Rect2(0, 0, w, h), Color("1b1e27"))
		draw_rect(Rect2(0, 0, w, 2), Color("6c7488"))
		draw_rect(Rect2(0, h - 2.0, w, 2), Color("0d0f14"))
		# tanda panah kuning bergerak searah ban
		var gap := 26.0
		var off: float = fposmod(anim, gap)
		var x: float = off - gap
		while x < w:
			if x > 10.0 and x < w - 16.0:
				draw_polyline(PackedVector2Array([Vector2(x - 3.0 * dir, 1.5), Vector2(x + 4.0 * dir, 5.0), Vector2(x - 3.0 * dir, 8.5)]), Color("ffc933"), 2.5)
			x += gap
		# rol di kedua ujung
		for ex in [7.0, w - 7.0]:
			var ec := Vector2(ex, h * 0.5)
			draw_circle(ec, 7.0, Color("3a4050"))
			draw_arc(ec, 7.0, 0.0, TAU, 14, Color("0d0f14"), 2.0, true)
			var ang: float = anim * 0.12
			draw_line(ec, ec + Vector2(cos(ang), sin(ang)) * 5.0, Color("ffc933"), 2.0)
			draw_line(ec, ec - Vector2(cos(ang), sin(ang)) * 5.0, Color("ffc933"), 2.0)


# ------------------------------------------------------------------ gergaji bulat di rel
## Gergaji meluncur bolak-balik di sepanjang rel (gerak sinus, kecepatan pelan supaya adil).
## Kena = -1 darah + terpental (sama seperti duri). Rel digambar jelas supaya jalurnya mudah dibaca.
class SawBlade extends Node2D:
	var origin: Vector2
	var move: Vector2
	var period: float = 5.0
	var phase: float = 0.0
	var radius: float = 30.0
	var t: float = 0.0
	var spin: float = 0.0
	var area: Area2D

	func setup(c: Vector2, mv: Vector2, per: float, ph: float, rad: float) -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		origin = c
		move = mv
		period = maxf(per, 0.5)
		phase = ph
		radius = rad
		z_index = 1
		position = _pos_at(0.0)

		# rel di belakang gergaji (digambar di koordinat dunia)
		var rail := Line2D.new()
		rail.top_level = true
		rail.z_index = -6
		rail.width = 10.0
		rail.default_color = Color("14161d")
		rail.points = PackedVector2Array([origin - mv, origin + mv])
		add_child(rail)
		var rail_hi := Line2D.new()
		rail_hi.top_level = true
		rail_hi.z_index = -6
		rail_hi.width = 3.0
		rail_hi.default_color = Color("7b849b")
		rail_hi.points = PackedVector2Array([origin - mv, origin + mv])
		add_child(rail_hi)
		for end_pt in [origin - mv, origin + mv]:
			var cap := Polygon2D.new()
			cap.top_level = true
			cap.z_index = -6
			cap.color = Color("ffc933")
			cap.polygon = PackedVector2Array([Vector2(-7, -7), Vector2(7, -7), Vector2(7, 7), Vector2(-7, 7)])
			cap.global_position = end_pt
			add_child(cap)

		area = Area2D.new()
		area.collision_layer = 0
		area.collision_mask = 4
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new()
		sh.radius = radius * 0.8          # sedikit lebih kecil dari gambar supaya terasa adil
		cs.shape = sh
		area.add_child(cs)
		add_child(area)

	func _pos_at(time: float) -> Vector2:
		return origin + move * sin(TAU * time / period + phase)

	func reset_motion() -> void:
		t = 0.0
		position = _pos_at(0.0)

	func _physics_process(delta: float) -> void:
		t += delta
		position = _pos_at(t)

	func _process(d: float) -> void:
		spin += d * 9.0
		queue_redraw()

	func _draw() -> void:
		# cincin peringatan merah
		draw_circle(Vector2.ZERO, radius + 7.0, Color(1.0, 0.15, 0.1, 0.22))
		var pts := PackedVector2Array()
		var teeth := 14
		for i in teeth * 2:
			var a: float = spin + TAU * float(i) / float(teeth * 2)
			var rr: float = radius if i % 2 == 0 else radius * 0.8
			pts.append(Vector2(cos(a), sin(a)) * rr)
		draw_colored_polygon(pts, Color("c9d2e3"))
		draw_polyline(PackedVector2Array(Array(pts) + [pts[0]]), Color("4a5265"), 2.0, true)
		draw_circle(Vector2.ZERO, radius * 0.62, Color("8f99ae"))
		draw_arc(Vector2.ZERO, radius * 0.62, 0.0, TAU, 28, Color("4a5265"), 2.0, true)
		for i in 4:
			var a2: float = -spin * 0.6 + TAU * float(i) / 4.0
			draw_circle(Vector2(cos(a2), sin(a2)) * radius * 0.4, 2.5, Color("3a4152"))
		draw_circle(Vector2.ZERO, radius * 0.22, Color("ffc933"))
		draw_circle(Vector2.ZERO, radius * 0.1, Color("1a1d26"))



# ------------------------------------------------------------------ es licin
## Lapisan es tipis di atas permukaan. Efek licin dihitung di game.gd (surface_grip).
static func ice(r: Rect2) -> Node2D:
	var root := Node2D.new()
	root.position = r.position
	root.z_index = -8
	var base := ColorRect.new()
	base.color = Color(0.45, 0.85, 1.0, 0.92)
	base.size = Vector2(r.size.x, maxf(r.size.y, 10.0))
	root.add_child(base)
	var shine := ColorRect.new()
	shine.color = Color(1, 1, 1, 0.85)
	shine.size = Vector2(r.size.x, 2)
	root.add_child(shine)
	var n := int(r.size.x / 34.0)
	for i in n:
		var g := ColorRect.new()
		g.color = Color(1, 1, 1, 0.55)
		g.position = Vector2(14.0 + i * 34.0, 3.0)
		g.size = Vector2(12, 2)
		root.add_child(g)
	return root


# ------------------------------------------------------------------ partikel suasana
static func ambient(kind: String) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.process_mode = Node.PROCESS_MODE_PAUSABLE
	p.z_index = 4
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	match kind:
		"snow":
			p.position = Vector2(640, -20)
			p.emission_rect_extents = Vector2(680, 4)
			p.amount = 110
			p.lifetime = 8.5
			p.preprocess = 8.5
			p.direction = Vector2(0.18, 1.0)
			p.spread = 16.0
			p.initial_velocity_min = 45.0
			p.initial_velocity_max = 95.0
			p.gravity = Vector2(0, 10)
			p.scale_amount_min = 2.0
			p.scale_amount_max = 4.5
			p.color = Color(1, 1, 1, 0.85)
		"dust":
			p.position = Vector2(-30, 360)
			p.emission_rect_extents = Vector2(4, 360)
			p.amount = 60
			p.lifetime = 6.0
			p.preprocess = 6.0
			p.direction = Vector2(1.0, 0.06)
			p.spread = 8.0
			p.initial_velocity_min = 170.0
			p.initial_velocity_max = 320.0
			p.gravity = Vector2.ZERO
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.5
			p.color = Color(0.95, 0.8, 0.5, 0.35)
		"leaves":
			p.position = Vector2(640, -20)
			p.emission_rect_extents = Vector2(680, 4)
			p.amount = 26
			p.lifetime = 10.0
			p.preprocess = 10.0
			p.direction = Vector2(-0.25, 1.0)
			p.spread = 22.0
			p.initial_velocity_min = 30.0
			p.initial_velocity_max = 70.0
			p.gravity = Vector2(-6, 18)
			p.angular_velocity_min = -180.0
			p.angular_velocity_max = 180.0
			p.scale_amount_min = 4.0
			p.scale_amount_max = 8.0
			var gr := Gradient.new()
			gr.set_color(0, Color("5fae3a"))
			gr.set_color(1, Color("b6e36a"))
			p.color_initial_ramp = gr
		"motes":
			p.position = Vector2(640, 730)
			p.emission_rect_extents = Vector2(680, 4)
			p.amount = 55
			p.lifetime = 9.0
			p.preprocess = 9.0
			p.direction = Vector2(0.1, -1.0)
			p.spread = 14.0
			p.initial_velocity_min = 18.0
			p.initial_velocity_max = 48.0
			p.gravity = Vector2.ZERO
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.0
			p.color = Color(1.0, 0.88, 0.45, 0.5)
		"bubbles":
			p.position = Vector2(640, 740)
			p.emission_rect_extents = Vector2(680, 4)
			p.amount = 46
			p.lifetime = 9.0
			p.preprocess = 9.0
			p.direction = Vector2(0.05, -1.0)
			p.spread = 12.0
			p.initial_velocity_min = 24.0
			p.initial_velocity_max = 70.0
			p.gravity = Vector2.ZERO
			p.scale_amount_min = 2.0
			p.scale_amount_max = 5.0
			p.color = Color(0.8, 0.96, 1.0, 0.38)
		"stars":
			p.position = Vector2(640, 360)
			p.emission_rect_extents = Vector2(660, 360)
			p.amount = 70
			p.lifetime = 6.0
			p.preprocess = 6.0
			p.direction = Vector2(-1.0, 0.1)
			p.spread = 10.0
			p.initial_velocity_min = 6.0
			p.initial_velocity_max = 16.0
			p.gravity = Vector2.ZERO
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.2
			var sg := Gradient.new()
			sg.set_color(0, Color(0.8, 0.95, 1.0, 0.0))
			sg.set_color(1, Color(1.0, 0.85, 1.0, 0.0))
			sg.add_point(0.5, Color(1.0, 1.0, 1.0, 0.85))
			p.color_ramp = sg
		"sparks":
			p.position = Vector2(640, -20)
			p.emission_rect_extents = Vector2(680, 4)
			p.amount = 34
			p.lifetime = 4.5
			p.preprocess = 4.5
			p.direction = Vector2(0.15, 1.0)
			p.spread = 24.0
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 190.0
			p.gravity = Vector2(0, 360)
			p.scale_amount_min = 1.5
			p.scale_amount_max = 3.0
			var fg := Gradient.new()
			fg.set_color(0, Color(1.0, 0.85, 0.35, 0.95))
			fg.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
			p.color_ramp = fg
		_:
			p.free()
			return null
	return p
