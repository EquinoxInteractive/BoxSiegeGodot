class_name ReplayUI
extends RefCounted
## Komponen UI untuk fitur REPLAY. Semua digambar lewat kode (tanpa aset baru) dan memakai bahasa visual yang sama
## dengan menu lain (UIKit): bentuk miring, kilau berjalan, animasi masuk bertahap, fokus yang halus.
##
##   DockButton    tombol REPLAY di menu utama
##   Chip          tombol kecil beranimasi (daftar replay, pengaturan, dialog). Fokus = keyboard / controller / mouse hover.
##   ConfirmDialog dialog konfirmasi (hapus replay, hapus semua)
##   PauseMenu     menu jeda di dalam pemutar replay (daftar tombol + kartu info replay)
##   HelpPanel     panel bantuan kontrol di pemutar replay
##   EndPanel      layar "REPLAY FINISHED"
##   draw_icon()   kumpulan ikon kecil
##
## Semua panel dikendalikan satu nilai animasi (open_t) sehingga membuka / menutup bisa dibatalkan di tengah jalan tanpa patah-patah.

const DANGER := Color("ff5a5a")
const DANGER_SOFT := Color("ff7a7a")


# ================================================================== helper statis
static func ease_out_back(x: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	var p: float = clampf(x, 0.0, 1.0) - 1.0
	return 1.0 + c3 * p * p * p + c1 * p * p


static func ease_out_cubic(x: float) -> float:
	var p: float = 1.0 - clampf(x, 0.0, 1.0)
	return 1.0 - p * p * p


## Pita kilau miring yang berjalan di dalam bentuk `shape` (dipotong supaya tidak keluar dari tombol).
static func shine(ci: CanvasItem, shape: PackedVector2Array, w: float, h: float, phase: float, alpha: float) -> void:
	var sx: float = phase * w
	var band := PackedVector2Array([Vector2(sx + 14.0, 0.0), Vector2(sx + 58.0, 0.0), Vector2(sx + 44.0, h), Vector2(sx, h)])
	var res: Array = Geometry2D.intersect_polygons(band, shape)
	if not res.is_empty():
		ci.draw_colored_polygon(res[0], Color(1, 1, 1, alpha))


## Ikon kecil. c = pusat, s = setengah ukuran kira-kira.
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	var lw: float = maxf(s * 0.16, 2.0)
	match id:
		"play":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.34, -0.55) * s, c + Vector2(-0.34, 0.55) * s, c + Vector2(0.6, 0.0) * s]), col)
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-0.45, -0.5) * s, Vector2(0.3, 1.0) * s), col)
			ci.draw_rect(Rect2(c + Vector2(0.15, -0.5) * s, Vector2(0.3, 1.0) * s), col)
		"restart":
			var r: float = s * 0.5
			ci.draw_arc(c, r, 0.7, TAU - 0.5, 20, col, lw, true)
			var a: float = TAU - 0.5
			var tip: Vector2 = c + Vector2(cos(a), sin(a)) * r
			var dir := Vector2(-sin(a), cos(a))
			var side := Vector2(-dir.y, dir.x)
			ci.draw_colored_polygon(PackedVector2Array([tip + dir * s * 0.36, tip + side * s * 0.26, tip - side * s * 0.26]), col)
		"cards":
			ci.draw_rect(Rect2(c + Vector2(-0.6, -0.42) * s, Vector2(1.2, 0.84) * s), col, false, lw)
			ci.draw_rect(Rect2(c + Vector2(-0.38, -0.2) * s, Vector2(0.42, 0.4) * s), col)
		"sound":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.6, -0.2) * s, c + Vector2(-0.34, -0.2) * s, c + Vector2(0.0, -0.5) * s,
				c + Vector2(0.0, 0.5) * s, c + Vector2(-0.34, 0.2) * s, c + Vector2(-0.6, 0.2) * s]), col)
			ci.draw_arc(c + Vector2(0.02, 0.0) * s, s * 0.3, -0.9, 0.9, 10, col, lw * 0.8, true)
			ci.draw_arc(c + Vector2(0.02, 0.0) * s, s * 0.56, -0.9, 0.9, 12, col, lw * 0.8, true)
		"music":
			ci.draw_circle(c + Vector2(-0.28, 0.38) * s, s * 0.24, col)
			ci.draw_line(c + Vector2(-0.06, 0.34) * s, c + Vector2(-0.06, -0.55) * s, col, lw, true)
			ci.draw_line(c + Vector2(-0.06, -0.55) * s, c + Vector2(0.46, -0.3) * s, col, lw, true)
		"help":
			UIKit.text_in(ci, "?", Rect2(c - Vector2(s, s), Vector2(s * 2.0, s * 2.0)), int(s * 1.7), col, HORIZONTAL_ALIGNMENT_CENTER)
		"info":
			ci.draw_arc(c, s * 0.62, 0.0, TAU, 24, col, lw * 0.8, true)
			ci.draw_circle(c + Vector2(0.0, -0.26) * s, s * 0.09, col)
			ci.draw_line(c + Vector2(0.0, -0.06) * s, c + Vector2(0.0, 0.34) * s, col, lw * 0.9, true)
		"list":
			for k in 3:
				var y: float = c.y + (float(k) - 1.0) * s * 0.46
				ci.draw_circle(Vector2(c.x - s * 0.55, y), s * 0.09, col)
				ci.draw_line(Vector2(c.x - s * 0.28, y), Vector2(c.x + s * 0.6, y), col, lw * 0.85, true)
		"home":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.64, 0.0) * s, c + Vector2(0.0, -0.58) * s, c + Vector2(0.64, 0.0) * s]), col, lw, true)
			ci.draw_rect(Rect2(c + Vector2(-0.44, 0.0) * s, Vector2(0.88, 0.58) * s), col, false, lw)
			ci.draw_rect(Rect2(c + Vector2(-0.1, 0.2) * s, Vector2(0.2, 0.38) * s), col)
		"lock":
			UIKit.draw_lock(ci, c, s * 1.5, col)
		"unlock":
			ci.draw_arc(c + Vector2(0.18, -0.38) * s, s * 0.34, PI, TAU - 0.3, 12, col, lw, true)
			ci.draw_rect(Rect2(c + Vector2(-0.5, -0.1) * s, Vector2(1.0, 0.7) * s), col)
			ci.draw_rect(Rect2(c + Vector2(-0.07, 0.1) * s, Vector2(0.14, 0.26) * s), Color(0, 0, 0, 0.6))
		"trash":
			ci.draw_line(c + Vector2(-0.58, -0.38) * s, c + Vector2(0.58, -0.38) * s, col, lw, true)
			ci.draw_rect(Rect2(c + Vector2(-0.18, -0.6) * s, Vector2(0.36, 0.22) * s), col, false, lw * 0.8)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.44, -0.26) * s, c + Vector2(0.44, -0.26) * s, c + Vector2(0.36, 0.62) * s, c + Vector2(-0.36, 0.62) * s]), col)
			for k in 3:
				var x: float = c.x + (float(k) - 1.0) * s * 0.22
				ci.draw_line(Vector2(x, c.y - s * 0.12), Vector2(x, c.y + s * 0.44), Color(0, 0, 0, 0.45), lw * 0.6)
		"gear":
			ci.draw_arc(c, s * 0.34, 0.0, TAU, 20, col, lw * 1.3, true)
			for k in 8:
				var an: float = float(k) * TAU / 8.0
				ci.draw_line(c + Vector2(cos(an), sin(an)) * s * 0.44, c + Vector2(cos(an), sin(an)) * s * 0.68, col, lw * 1.2, true)
		"rec":
			ci.draw_arc(c, s * 0.64, 0.0, TAU, 24, col, lw * 0.9, true)
			ci.draw_circle(c, s * 0.34, col)
		"back":
			ci.draw_line(c + Vector2(0.55, 0.0) * s, c + Vector2(-0.5, 0.0) * s, col, lw, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.12, -0.42) * s, c + Vector2(-0.56, 0.0) * s, c + Vector2(-0.12, 0.42) * s]), col, lw, true)
		"x":
			ci.draw_line(c + Vector2(-0.5, -0.5) * s, c + Vector2(0.5, 0.5) * s, col, lw * 1.2, true)
			ci.draw_line(c + Vector2(0.5, -0.5) * s, c + Vector2(-0.5, 0.5) * s, col, lw * 1.2, true)
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.55, 0.05) * s, c + Vector2(-0.15, 0.45) * s, c + Vector2(0.6, -0.45) * s]), col, lw * 1.2, true)
		"warn":
			var tri := PackedVector2Array([c + Vector2(0.0, -0.66) * s, c + Vector2(0.7, 0.52) * s, c + Vector2(-0.7, 0.52) * s, c + Vector2(0.0, -0.66) * s])
			ci.draw_polyline(tri, col, lw, true)
			ci.draw_line(c + Vector2(0.0, -0.2) * s, c + Vector2(0.0, 0.12) * s, col, lw, true)
			ci.draw_circle(c + Vector2(0.0, 0.32) * s, lw * 0.6, col)
		"eye":
			var top := PackedVector2Array()
			var bot := PackedVector2Array()
			for k in range(0, 13):
				var fx: float = -1.0 + float(k) / 6.0
				var hy: float = 0.55 * s * (1.0 - fx * fx)
				top.append(c + Vector2(fx * s * 0.9, -hy))
				bot.append(c + Vector2(fx * s * 0.9, hy))
			ci.draw_polyline(top, col, lw * 0.9, true)
			ci.draw_polyline(bot, col, lw * 0.9, true)
			ci.draw_circle(c, s * 0.26, col)
		"kill":
			ci.draw_arc(c, s * 0.42, 0.0, TAU, 20, col, lw * 0.8, true)
			for k in 4:
				var an: float = float(k) * TAU / 4.0
				ci.draw_line(c + Vector2(cos(an), sin(an)) * s * 0.28, c + Vector2(cos(an), sin(an)) * s * 0.72, col, lw * 0.8, true)
			ci.draw_circle(c, s * 0.12, col)


## Satu keycap (tombol keyboard) kecil. Mengembalikan lebar yang terpakai.
static func keycap(ci: CanvasItem, key: String, x: float, cy: float, a: float, col: Color = UIKit.GOLD) -> float:
	var h: float = 28.0
	var arrow: bool = key == "LEFT" or key == "RIGHT" or key == "UP" or key == "DOWN"
	var w: float = 34.0 if arrow else maxf(34.0, UIKit.text_w(key, 18) + 20.0)
	var pts: PackedVector2Array = UIKit.slanted(w, h, 6.0, x, cy - h * 0.5)
	ci.draw_colored_polygon(UIKit.slanted(w, h, 6.0, x + 1.5, cy - h * 0.5 + 3.0), Color(0, 0, 0, 0.5 * a))
	ci.draw_colored_polygon(pts, Color(0.13, 0.13, 0.26, 0.97 * a))
	ci.draw_polyline(UIKit.closed(pts), Color(col, 0.85 * a), 2.0, true)
	if arrow:
		var c := Vector2(x + w * 0.5 + 1.0, cy)
		var q: float = 6.0
		var tri: PackedVector2Array
		match key:
			"LEFT": tri = PackedVector2Array([c + Vector2(q, -q), c + Vector2(-q, 0), c + Vector2(q, q)])
			"RIGHT": tri = PackedVector2Array([c + Vector2(-q, -q), c + Vector2(q, 0), c + Vector2(-q, q)])
			"UP": tri = PackedVector2Array([c + Vector2(-q, q), c + Vector2(0, -q), c + Vector2(q, q)])
			_: tri = PackedVector2Array([c + Vector2(-q, -q), c + Vector2(0, q), c + Vector2(q, -q)])
		ci.draw_colored_polygon(tri, Color(1, 1, 1, a))
	else:
		UIKit.text_in(ci, key, Rect2(x + 3.0, cy - h * 0.5, w - 3.0, h), 18, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER)
	return w


## Wadah gambar generik: pemilik memberi `painter` (Callable yang menerima CanvasItem).
class Box extends Control:
	var painter: Callable

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


# ================================================================== DockButton (menu utama)
## Tombol REPLAY di menu utama (kanan atas, di bawah indikator P1-P4): terpisah dari daftar menu & dari SHOP / INVENTORY.
## Titik merah berdenyut (ikon REC) + jumlah replay tersimpan. Saat terpilih: naik sedikit, kilau berjalan, cincin gelombang.
class DockButton extends Control:
	signal activated
	signal hovered

	var selected: bool = false
	var sel: float = 0.0
	var flash: float = 0.0
	var t: float = 0.0
	var accent: Color = Color("ff4a5a")
	var saved: int = 0
	var rec_on: bool = true

	func _init() -> void:
		size = Vector2(262, 62)
		custom_minimum_size = size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		ReplayStore.ensure_loaded()          # pengaturan REC harus sudah dibaca dari file sebelum tombol dibuat
		saved = ReplayStore.count()
		rec_on = ReplayStore.enabled

	func _ready() -> void:
		mouse_entered.connect(func() -> void: hovered.emit())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			press()

	func set_selected(v: bool) -> void:
		selected = v

	func press() -> void:
		Global.play_sfx("ui_confirm", -3.0)
		flash = 1.0
		activated.emit()

	func _process(d: float) -> void:
		t += d
		sel = lerpf(sel, 1.0 if selected else 0.0, 1.0 - exp(-d * 14.0))
		flash = maxf(flash - d * 3.0, 0.0)
		scale = Vector2.ONE * (1.0 + 0.06 * sel + 0.06 * flash * flash)
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var sk: float = 16.0
		var lift: float = -3.0 * sel
		draw_set_transform(Vector2(0.0, lift))
		var pts: PackedVector2Array = UIKit.slanted(w - 8.0, h - 8.0, sk, 4.0, 4.0)
		draw_colored_polygon(UIKit.slanted(w - 8.0, h - 8.0, sk, 9.0, 10.0 - lift), Color(0, 0, 0, 0.5))
		var top: Color = Color(0.14, 0.06, 0.1, 0.95).lerp(accent.darkened(0.2), sel)
		var bot: Color = Color(0.05, 0.03, 0.06, 0.95).lerp(accent.darkened(0.65), sel)
		draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
		if sel > 0.02:
			ReplayUI.shine(self, pts, w, h, fmod(t * 0.8, 1.9) - 0.4, 0.2 * sel)
		draw_polyline(UIKit.closed(pts), accent.lerp(Color.WHITE, 0.6 * sel + 0.4 * flash), 3.0 + 2.0 * sel, true)
		if flash > 0.0:
			draw_colored_polygon(pts, Color(1, 1, 1, 0.5 * flash))
		# ikon rekam: lingkaran + titik merah berdenyut (+ cincin gelombang saat terpilih)
		var c := Vector2(44.0, h * 0.5)
		var pulse: float = 0.6 + 0.4 * sin(t * 4.0)
		if rec_on and sel > 0.05:
			for k in 2:
				var ph: float = fmod(t * 0.9 + float(k) * 0.5, 1.0)
				draw_arc(c, 22.0 + ph * 16.0, 0.0, TAU, 28, Color(accent, (1.0 - ph) * 0.6 * sel), 2.0, true)
		draw_circle(c, 22.0, Color(0, 0, 0, 0.5))
		draw_arc(c, 22.0, 0.0, TAU, 28, Color(accent, 0.6 + 0.4 * sel), 3.0, true)
		if rec_on:
			draw_circle(c, 11.0, Color(1.0, 0.25, 0.3, pulse))
		else:
			draw_circle(c, 11.0, Color(0.5, 0.5, 0.55, 0.8))
		UIKit.text_in(self, "REPLAY", Rect2(80.0, 4.0, w - 100.0, 36.0), 32, Color.WHITE.lerp(accent.lightened(0.5), 0.5 * sel), HORIZONTAL_ALIGNMENT_LEFT, 7)
		var sub: String = "%d SAVED" % saved if saved > 0 else "WATCH YOUR MATCHES"
		if not rec_on and saved == 0:
			sub = "RECORDING IS OFF"
		UIKit.text_in(self, sub, Rect2(80.0, 36.0, w - 100.0, 20.0), 16, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT, 3)
		if sel > 0.05:
			UIKit.draw_chevron(self, Vector2(w - 24.0 + sin(t * 8.0) * 3.0, h * 0.5), 10.0, 1, Color(accent.lightened(0.4), sel))
		draw_set_transform(Vector2.ZERO)


# ================================================================== Chip
## Tombol kecil beranimasi. Hover mouse hanya MEMINDAHKAN FOKUS (lewat sinyal hovered); yang menyala adalah yang "active".
## Dengan begitu mouse, keyboard, dan controller memakai satu penanda yang sama (seperti FancyButton di menu lain).
class Chip extends Control:
	signal pressed
	signal hovered

	var text: String = ""
	var col: Color = UIKit.GOLD
	var fs: int = 22
	var icon: String = ""
	var disabled: bool = false
	var active: bool = false
	var sk_override: float = -1.0       # kemiringan khusus (< 0 = otomatis dari tinggi)
	var icon_s: float = -1.0            # ukuran ikon khusus (< 0 = otomatis)
	var pad: float = 24.0               # ruang napas isi di dalam bentuk tombol
	var icon_left: bool = false         # true = ikon di kiri, TEKS tepat di tengah tombol (untuk tombol lebar seperti tab)
	var lit: float = 0.0:
		set(v):
			lit = v
			queue_redraw()
	var flash: float = 0.0:
		set(v):
			flash = v
			queue_redraw()
	var focused: bool = false           # fokus kursor (mouse hover / keyboard) tanpa mengubah status active
	var foc: float = 0.0:
		set(v):
			foc = v
			queue_redraw()
	var _tw: Tween
	var _ftw: Tween
	var _t: float = 0.0
	var _shaking: bool = false

	func _init(t: String, sz: Vector2, c: Color, f: int = 22, ic: String = "") -> void:
		text = t
		size = sz
		custom_minimum_size = sz
		col = c
		fs = f
		icon = ic
		pivot_offset = sz * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_NONE

	func _ready() -> void:
		mouse_entered.connect(func() -> void:
			if not disabled:
				hovered.emit())
		set_process(active or focused)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			press()

	func set_text(t: String) -> void:
		text = t
		queue_redraw()

	func set_color(c: Color) -> void:
		col = c
		queue_redraw()

	func set_active(v: bool, instant: bool = false) -> void:
		if v == active and not instant:
			return
		active = v
		set_process(v or focused)
		if _tw:
			_tw.kill()
		if is_inside_tree() and not instant:
			_tw = UIKit.tw(self)
			_tw.set_parallel(true)
			_tw.tween_property(self, "lit", 1.0 if v else 0.0, 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			_tw.tween_property(self, "scale", Vector2.ONE * (1.05 if v else 1.0), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			lit = 1.0 if v else 0.0
			scale = Vector2.ONE * (1.05 if v else 1.0)

	## Fokus kursor: tombol menyala lebih lembut dari "active" + garis putih berdenyut + sedikit membesar.
	## Dipakai agar mouse hover / keyboard / controller punya penanda yang sama pada tombol yang bukan tab aktif.
	func set_focus(v: bool, instant: bool = false) -> void:
		if v == focused and not instant:
			return
		focused = v
		set_process(v or active)
		if _ftw:
			_ftw.kill()
		if is_inside_tree() and not instant:
			_ftw = UIKit.tw(self)
			_ftw.tween_property(self, "foc", 1.0 if v else 0.0, 0.18).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		else:
			foc = 1.0 if v else 0.0

	func press() -> void:
		if disabled:
			Global.play_sfx("ui_error", -10.0)
			shake()
			return
		Global.play_sfx("ui_confirm", -4.0)
		flash = 1.0
		if is_inside_tree():
			UIKit.tw(self).tween_property(self, "flash", 0.0, 0.35)
		pressed.emit()

	func shake() -> void:
		if _shaking or not is_inside_tree():
			return
		_shaking = true
		var x0: float = position.x
		var t := UIKit.tw(self)
		t.tween_property(self, "position:x", x0 + 8.0, 0.04)
		t.tween_property(self, "position:x", x0 - 8.0, 0.06)
		t.tween_property(self, "position:x", x0, 0.04)
		t.tween_callback(func() -> void: _shaking = false)

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var a: float = 0.4 if disabled else 1.0
		var sk: float = sk_override if sk_override >= 0.0 else minf(h * 0.28, 14.0)
		var kk: float = maxf(lit, foc * 0.85)
		var lift: float = -2.0 * kk
		var fz: float = 1.0 + 0.045 * foc
		draw_set_transform(Vector2(0.0, lift) + pivot_offset * (1.0 - fz), 0.0, Vector2.ONE * fz)
		var pts: PackedVector2Array = UIKit.slanted(w - 6.0, h - 6.0, sk, 0.0, 0.0)
		draw_colored_polygon(UIKit.slanted(w - 6.0, h - 6.0, sk, 4.0, 5.0 - lift), Color(0, 0, 0, 0.5 * a))
		var c0: Color = Color(0.1, 0.1, 0.2, 0.94).lerp(col.lightened(0.3), kk)
		var c1: Color = Color(0.05, 0.05, 0.12, 0.94).lerp(col.darkened(0.12), kk)
		c0.a *= a
		c1.a *= a
		draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
		if kk < 0.99:
			draw_colored_polygon(UIKit.slanted(5.0, h - 6.0, sk, 0.0, 0.0), Color(col, 0.7 * (1.0 - kk) * a))
		if (active or foc > 0.02) and not disabled:
			ReplayUI.shine(self, pts, w, h, fmod(_t * 0.9, 1.9) - 0.4, 0.26 * maxf(1.0 if active else 0.0, foc))
		var bc: Color = col.lightened(0.2).lerp(Color.WHITE, kk)
		bc.a = lerpf(0.55, 1.0, kk) * a
		draw_polyline(UIKit.closed(pts), bc, 2.0 + kk, true)
		if foc > 0.01 and not disabled:
			# bingkai luar putih berdenyut = penanda "kursor ada di sini"
			var fp: PackedVector2Array = UIKit.slanted(w - 6.0 + 10.0, h - 6.0 + 10.0, sk, -5.0, -5.0)
			draw_polyline(UIKit.closed(fp), Color(1, 1, 1, (0.5 + 0.3 * sin(_t * 7.0)) * foc), 2.0, true)
		if flash > 0.0:
			draw_colored_polygon(pts, Color(1, 1, 1, 0.75 * flash))
		var tc: Color = col.lightened(0.35).lerp(UIKit.INK, kk)
		tc.a = a
		# Pusat jajar genjang tepat di tengah lebar bentuk (w - 6) pada tinggi berapa pun.
		var shape_w: float = w - 6.0
		var shape_h: float = h - 6.0
		var f: int = fs
		var isz: float = icon_s if icon_s >= 0.0 else minf(shape_h * 0.34, 17.0)
		var gap: float = 8.0 if icon_s >= 0.0 else 10.0
		var tsz: float = UIKit.text_w(text, f)
		if icon != "" and icon_left:
			# ikon menempel di kiri, teks dipusatkan terhadap seluruh tombol
			var side: float = sk * 0.5 + 14.0 + isz * 2.0 + 8.0
			var avail_t: float = shape_w - side * 2.0
			while tsz > avail_t and f > 12:
				f -= 1
				tsz = UIKit.text_w(text, f)
			ReplayUI.draw_icon(self, icon, Vector2(sk * 0.5 + 14.0 + isz, shape_h * 0.5), isz, tc)
			UIKit.text_in(self, text, Rect2(0.0, 0.0, shape_w, shape_h), f, tc, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var avail: float = shape_w - sk - pad
			var total: float = tsz if icon == "" else isz * 2.0 + gap + tsz
			while total > avail and f > 12:
				f -= 1
				isz = minf(isz, float(f) * 0.62)
				tsz = UIKit.text_w(text, f)
				total = tsz if icon == "" else isz * 2.0 + gap + tsz
			var gx: float = (shape_w - total) * 0.5
			if icon != "":
				ReplayUI.draw_icon(self, icon, Vector2(gx + isz, shape_h * 0.5), isz, tc)
				UIKit.text_in(self, text, Rect2(gx + isz * 2.0 + gap, 0.0, tsz + 8.0, shape_h), f, tc, HORIZONTAL_ALIGNMENT_LEFT)
			else:
				UIKit.text_in(self, text, Rect2(gx, 0.0, tsz + 8.0, shape_h), f, tc, HORIZONTAL_ALIGNMENT_LEFT)
		draw_set_transform(Vector2.ZERO)


# ================================================================== ConfirmDialog
## Dialog konfirmasi. open() -> pop-in; focus kiri/kanan; confirmed / cancelled.
class ConfirmDialog extends Control:
	signal confirmed
	signal cancelled

	const BW := 620.0
	const BH := 300.0

	var is_open: bool = false
	var focus: int = 1                 # 0 = tombol YA, 1 = BATAL
	var title: String = ""
	var body: String = ""
	var accent: Color = ReplayUI.DANGER
	var icon: String = "trash"
	var open_t: float = 0.0:
		set(v):
			open_t = v
			_apply()
	var dim: ColorRect
	var box: ReplayUI.Box
	var yes: ReplayUI.Chip
	var no: ReplayUI.Chip
	var _tw: Tween
	var _t: float = 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		dim = ColorRect.new()
		dim.color = Color(0.01, 0.01, 0.06, 0.78)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		box = ReplayUI.Box.new()
		box.size = Vector2(BW, BH)
		box.position = Vector2(640.0 - BW * 0.5, 360.0 - BH * 0.5)
		box.pivot_offset = box.size * 0.5
		box.painter = _paint
		add_child(box)
		yes = ReplayUI.Chip.new("DELETE", Vector2(240, 58), ReplayUI.DANGER, 28, "trash")
		yes.position = Vector2(50, 212)
		yes.pressed.connect(func() -> void: _finish(true))
		yes.hovered.connect(func() -> void: _set_focus(0, true))
		box.add_child(yes)
		no = ReplayUI.Chip.new("CANCEL", Vector2(240, 58), UIKit.GOLD, 28, "back")
		no.position = Vector2(330, 212)
		no.pressed.connect(func() -> void: _finish(false))
		no.hovered.connect(func() -> void: _set_focus(1, true))
		box.add_child(no)

	func open(t: String, b: String, yes_label: String = "DELETE", col: Color = ReplayUI.DANGER, ic: String = "trash") -> void:
		title = t
		body = b
		accent = col
		icon = ic
		yes.set_text(yes_label)
		yes.set_color(col)
		is_open = true
		visible = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus = 1
		yes.set_active(false, true)
		no.set_active(true, true)
		Global.play_sfx("ui_panel", -5.0)
		if _tw:
			_tw.kill()
		_tw = UIKit.tw(self)
		_tw.tween_property(self, "open_t", 1.0, 0.34).set_trans(Tween.TRANS_LINEAR)

	func close() -> void:
		if not is_open:
			return
		is_open = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _tw:
			_tw.kill()
		_tw = UIKit.tw(self)
		_tw.tween_property(self, "open_t", 0.0, 0.16).set_trans(Tween.TRANS_LINEAR)
		_tw.tween_callback(func() -> void:
			if not is_open:
				visible = false)

	func _finish(yes_pick: bool) -> void:
		close()
		if yes_pick:
			confirmed.emit()
		else:
			Global.play_sfx("ui_back", -6.0)
			cancelled.emit()

	func _set_focus(i: int, sound: bool) -> void:
		if i == focus:
			return
		focus = i
		yes.set_active(i == 0)
		no.set_active(i == 1)
		if sound:
			Global.play_sfx("ui_hover", -8.0)

	## Input dari keyboard / controller.
	func handle(action: StringName) -> void:
		match action:
			&"left", &"right", &"up", &"down":
				_set_focus(1 - focus, true)
			&"accept":
				(yes if focus == 0 else no).press()
			&"back":
				_finish(false)

	func _apply() -> void:
		var e: float = ReplayUI.ease_out_back(open_t)
		dim.modulate.a = clampf(open_t * 3.0, 0.0, 1.0)
		box.scale = Vector2.ONE * lerpf(0.8, 1.0, e)
		box.modulate.a = clampf(open_t * 3.5, 0.0, 1.0)

	func _process(d: float) -> void:
		if visible:
			_t += d
			box.queue_redraw()

	func _paint(ci: CanvasItem) -> void:
		var pts: PackedVector2Array = UIKit.slanted(BW, BH, 22.0)
		ci.draw_colored_polygon(UIKit.slanted(BW, BH, 22.0, 7.0, 9.0), Color(0, 0, 0, 0.55))
		var top := Color(0.09, 0.05, 0.1, 0.98)
		var bot := Color(0.04, 0.03, 0.08, 0.98)
		ci.draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
		ReplayUI.shine(ci, pts, BW, BH, fmod(_t * 0.35, 2.4) - 0.5, 0.05)
		var pulse: float = 0.75 + 0.25 * sin(_t * 5.0)
		ci.draw_polyline(UIKit.closed(pts), Color(accent, pulse), 3.0, true)
		# ikon besar di dalam lingkaran
		var c := Vector2(BW * 0.5, 64.0)
		ci.draw_circle(c, 34.0, Color(accent, 0.18))
		ci.draw_arc(c, 34.0, 0.0, TAU, 32, Color(accent, 0.9), 3.0, true)
		ReplayUI.draw_icon(ci, icon, c, 20.0, accent.lightened(0.25))
		UIKit.text_in(ci, title, Rect2(0, 100, BW, 56), 42, accent.lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER, 8)
		UIKit.text_in(ci, body, Rect2(0, 154, BW, 40), 24, Color(1, 1, 1, 0.82), HORIZONTAL_ALIGNMENT_CENTER, 4)


# ================================================================== PauseMenu
## Menu jeda pemutar replay: judul PAUSED, daftar tombol (ikon + label + saklar ON/OFF) dan kartu info replay di kanan.
class MenuItem extends Control:
	signal activated
	signal hovered

	var label: String = ""
	var icon: String = ""
	var kind: String = "action"        # "action" | "toggle"
	var danger: bool = false
	var on: bool = false
	var knob: float = 0.0:
		set(v):
			knob = v
			queue_redraw()
	var selected: bool = false
	var sel: float = 0.0:
		set(v):
			sel = v
			queue_redraw()
	var flash: float = 0.0:
		set(v):
			flash = v
			queue_redraw()
	var _tw: Tween
	var _ktw: Tween
	var _t: float = 0.0

	func _init(l: String, ic: String, k: String, dng: bool, sz: Vector2) -> void:
		label = l
		icon = ic
		kind = k
		danger = dng
		size = sz
		custom_minimum_size = sz
		pivot_offset = sz * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE

	func _ready() -> void:
		mouse_entered.connect(func() -> void: hovered.emit())
		set_process(selected)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			activated.emit()

	func set_selected(v: bool) -> void:
		if v == selected:
			return
		selected = v
		set_process(v)
		if _tw:
			_tw.kill()
		if is_inside_tree():
			_tw = UIKit.tw(self)
			_tw.tween_property(self, "sel", 1.0 if v else 0.0, 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		else:
			sel = 1.0 if v else 0.0

	func set_on(v: bool, instant: bool = false) -> void:
		if v == on and not instant:
			return
		on = v
		if _ktw:
			_ktw.kill()
		if is_inside_tree() and not instant:
			_ktw = UIKit.tw(self)
			_ktw.tween_property(self, "knob", 1.0 if v else 0.0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			knob = 1.0 if v else 0.0

	func pop() -> void:
		flash = 1.0
		if is_inside_tree():
			UIKit.tw(self).tween_property(self, "flash", 0.0, 0.35)

	func _process(d: float) -> void:
		_t += d
		queue_redraw()

	func _draw() -> void:
		var accent: Color = ReplayUI.DANGER_SOFT if danger else UIKit.GOLD
		var shift: float = sel * 26.0
		var bw: float = size.x - 30.0
		var bh: float = size.y - 4.0
		var sk: float = 16.0
		var pts: PackedVector2Array = UIKit.slanted(bw, bh, sk, shift, 0.0)
		draw_colored_polygon(UIKit.slanted(bw, bh, sk, shift + 5.0, 6.0), Color(0, 0, 0, 0.45))
		var base := Color(0.07, 0.07, 0.16, 0.88)
		var c0: Color = base.lerp(accent.lightened(0.35), sel)
		var c1: Color = base.lerp(accent.darkened(0.12), sel)
		draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
		if sel < 0.99:
			draw_colored_polygon(UIKit.slanted(6.0, bh, 2.0, shift + 3.0, 0.0), Color(accent, 0.55 * (1.0 - sel)))
		if selected:
			ReplayUI.shine(self, pts, bw + shift, bh, fmod(_t * 0.75, 1.8) - 0.35, 0.28)
		draw_polyline(UIKit.closed(pts), Color(1, 1, 1, lerpf(0.16, 0.95, sel)), 2.0 + sel * 1.5, true)
		if flash > 0.0:
			draw_colored_polygon(pts, Color(1, 1, 1, 0.8 * flash))
		var ink: Color = Color.WHITE.lerp(UIKit.INK, sel)
		# ikon dalam lingkaran kecil
		var ic := Vector2(shift + sk + 22.0, bh * 0.5)
		draw_circle(ic, 17.0, Color(accent, 0.16).lerp(Color(UIKit.INK, 0.14), sel))
		ReplayUI.draw_icon(self, icon, ic, 10.0, accent.lerp(UIKit.INK, sel))
		UIKit.text_in(self, label, Rect2(shift + sk + 50.0, 0.0, bw - 190.0, bh), 28, ink, HORIZONTAL_ALIGNMENT_LEFT)
		if kind == "toggle":
			var pill := Rect2(shift + bw - sk - 96.0, bh * 0.5 - 15.0, 88.0, 30.0)
			var sb := StyleBoxFlat.new()
			sb.bg_color = UIKit.GREEN.darkened(0.2).lerp(Color(0.25, 0.25, 0.3), 1.0 - knob)
			sb.set_corner_radius_all(15)
			sb.border_color = Color(1, 1, 1, 0.7)
			sb.set_border_width_all(2)
			draw_style_box(sb, pill)
			var kx: float = pill.position.x + 4.0 + knob * (pill.size.x - 30.0 - 8.0)
			draw_circle(Vector2(kx + 13.0, pill.position.y + 15.0), 11.0, Color.WHITE)
			var txt_x: float = pill.position.x + (10.0 if knob > 0.5 else 38.0)
			UIKit.text_in(self, "ON" if knob > 0.5 else "OFF", Rect2(txt_x, pill.position.y, 50.0, 30.0), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		elif sel > 0.01:
			var bob: float = sin(_t * 9.0) * 3.0 * sel
			UIKit.draw_chevron(self, Vector2(shift + bw - sk - 12.0 + bob, bh * 0.5), 9.0, 1, Color(UIKit.INK, sel))


class InfoCard extends Control:
	const CW := 500.0
	const CH := 484.0

	var info: Dictionary = {}
	var intro: float = 0.0
	var _t: float = 0.0
	var _tw: Tween

	func _init() -> void:
		size = Vector2(CW, CH)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_info(d: Dictionary) -> void:
		info = d
		intro = 0.0
		if _tw:
			_tw.kill()
		if is_inside_tree():
			_tw = UIKit.tw(self)
			_tw.tween_property(self, "intro", 1.0, 1.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT).set_delay(0.25)
		else:
			intro = 1.0

	func _process(d: float) -> void:
		if visible:
			_t += d
			queue_redraw()

	func _draw() -> void:
		var pts: PackedVector2Array = UIKit.slanted(CW, CH, 22.0)
		draw_colored_polygon(UIKit.slanted(CW, CH, 22.0, 7.0, 9.0), Color(0, 0, 0, 0.5))
		draw_colored_polygon(pts, Color(0.05, 0.05, 0.12, 0.95))
		draw_polyline(UIKit.closed(pts), Color(UIKit.GOLD, 0.9), 3.0, true)
		if info.is_empty():
			return
		# gambar arena (zoom pelan)
		var pr := Rect2(44.0, 22.0, 420.0, 186.0)
		var tex: Texture2D = Global.map_background(String(info.get("map_id", "earth")))
		if tex != null:
			var z: float = 1.0 + 0.07 * ReplayUI.ease_out_cubic(intro) + 0.01 * sin(_t * 0.6)
			var ts: Vector2 = tex.get_size()
			var sz: Vector2 = ts / z
			draw_texture_rect_region(tex, pr, Rect2((ts - sz) * 0.5, sz))
		draw_polygon(PackedVector2Array([pr.position + Vector2(0, 80), pr.position + Vector2(pr.size.x, 80), pr.end, Vector2(pr.position.x, pr.end.y)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.85), Color(0, 0, 0, 0.85)]))
		draw_rect(pr, Color(0, 0, 0, 0.85), false, 3.0)
		UIKit.text_in(self, String(info.get("map_name", "ARENA")), Rect2(pr.position.x + 14.0, pr.end.y - 56.0, 380.0, 48.0), 40, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 8)
		# lencana REPLAY
		var bp: PackedVector2Array = UIKit.slanted(112.0, 28.0, 9.0, pr.position.x + 10.0, pr.position.y + 10.0)
		draw_colored_polygon(bp, Color(0, 0, 0, 0.62))
		draw_circle(Vector2(pr.position.x + 34.0, pr.position.y + 24.0), 6.0, Color(1.0, 0.2, 0.2, 0.55 + 0.45 * sin(_t * 4.0)))
		UIKit.text_in(self, "REPLAY", Rect2(pr.position.x + 48.0, pr.position.y + 10.0, 70.0, 28.0), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 4)
		# ronde + waktu
		var tt: float = float(info.get("t", 0.0))
		var dur: float = maxf(float(info.get("duration", 1.0)), 0.1)
		UIKit.text_in(self, "ROUND %d" % int(info.get("round", 1)), Rect2(44.0, 218.0, 220.0, 46.0), 38, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 7)
		UIKit.text_in(self, "%s / %s" % [ReplayStore.format_clock(tt), ReplayStore.format_clock(dur)], Rect2(CW - 280.0, 218.0, 236.0, 46.0), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 6)
		# progress ronde
		var bx: float = 44.0
		var bwid: float = 420.0
		var by: float = 276.0
		draw_rect(Rect2(bx, by, bwid, 14.0), Color(1, 1, 1, 0.14))
		for r in info.get("rounds", []):
			var rs: float = float((r as Dictionary)["start"])
			var re: float = float((r as Dictionary)["end"])
			if re < 0.0:
				re = dur
			var wc: Color = (r as Dictionary).get("color", Color(0.7, 0.7, 0.75))
			draw_rect(Rect2(bx + rs / dur * bwid, by, maxf((minf(re, dur) - rs) / dur * bwid, 2.0), 14.0), Color(wc, 0.4))
			draw_rect(Rect2(bx + rs / dur * bwid - 1.0, by - 3.0, 2.0, 20.0), Color(1, 1, 1, 0.6))
		var fillw: float = tt / dur * bwid * ReplayUI.ease_out_cubic(intro)
		draw_rect(Rect2(bx, by, fillw, 14.0), Color(UIKit.GOLD, 0.95))
		draw_rect(Rect2(bx, by, bwid, 14.0), Color(0, 0, 0, 0.7), false, 2.0)
		draw_circle(Vector2(bx + fillw, by + 7.0), 8.0, Color.WHITE)
		# pemain
		var pl: Array = info.get("players", [])
		var n: int = pl.size()
		var cell: float = bwid / float(maxi(n, 1))
		for i in n:
			var pd: Dictionary = pl[i]
			var col: Color = pd["color"]
			var cx: float = bx + cell * (float(i) + 0.5)
			var pa: float = clampf(intro * 3.0 - float(i) * 0.3, 0.0, 1.0)
			var r := Rect2(cx - 31.0, 322.0 - (1.0 - ReplayUI.ease_out_back(pa)) * 20.0, 62.0, 62.0)
			draw_rect(Rect2(r.position - Vector2(3, 3), r.size + Vector2(6, 6)), Color(col, pa))
			draw_texture_rect(Global.character_texture(0, int(pd["char"])), r, false, Color(1, 1, 1, pa))
			UIKit.text_in(self, String(pd.get("name", "P%d" % (i + 1))), Rect2(cx - cell * 0.5, 392.0, cell, 22.0), 17, Color(1, 1, 1, pa), HORIZONTAL_ALIGNMENT_CENTER, 4)
			UIKit.text_in(self, "%d KILLS" % int(pd.get("kills", 0)), Rect2(cx - cell * 0.5, 414.0, cell, 20.0), 15, Color(col.lightened(0.4), 0.9 * pa), HORIZONTAL_ALIGNMENT_CENTER, 3)
			var wins_t: int = int(info.get("wins_to_match", 3))
			var wn: int = int(pd.get("wins", 0))
			var pw: float = 14.0
			var px0: float = cx - (float(wins_t) * (pw + 4.0) - 4.0) * 0.5
			for k in wins_t:
				var pr2 := Rect2(px0 + float(k) * (pw + 4.0), 440.0, pw, 12.0)
				draw_rect(pr2, Color(col, 0.95 * pa) if k < wn else Color(1, 1, 1, 0.14 * pa))
		var foot: String = "FIRST TO %d WINS" % int(info.get("wins_to_match", 3))
		UIKit.text_in(self, foot, Rect2(0.0, CH - 28.0, CW, 22.0), 15, Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 3)


class PauseMenu extends Control:
	signal activated(i: int)
	signal hovered(i: int)

	const ITEM_W := 500.0
	const ITEM_H := 54.0
	const STEP := 56.0
	const X0 := 90.0
	const Y0 := 148.0

	var is_open: bool = false
	var open_t: float = 0.0:
		set(v):
			open_t = v
			_apply()
	var dim: ColorRect
	var title: UIKit.Banner
	var tag: ReplayUI.Box
	var items: Array = []
	var bases: Array = []
	var card: ReplayUI.InfoCard
	var prompt: UIKit.PromptBar
	var prompt_holder: Control
	var _tw: Tween
	var _sel: int = -1
	var _t: float = 0.0
	var _card_base: Vector2

	## defs: [{label, icon, kind, danger, gap}] — gap = ruang tambahan sebelum tombol (pemisah kelompok).
	func _init(defs: Array) -> void:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		position = Vector2.ZERO
		size = Vector2(1280, 720)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

		dim = ColorRect.new()
		dim.color = Color(0.02, 0.02, 0.08, 0.8)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)

		title = UIKit.Banner.new("PAUSED", 64)
		title.position = Vector2(X0 + 20.0, 46.0)
		add_child(title)

		tag = ReplayUI.Box.new()
		tag.size = Vector2(150, 34)
		tag.position = Vector2(X0 + 20.0 + title.size.x + 24.0, 72.0)
		tag.painter = _paint_tag
		add_child(tag)

		var y: float = Y0
		for i in defs.size():
			var d: Dictionary = defs[i]
			y += float(d.get("gap", 0.0))
			var it := MenuItem.new(String(d["label"]), String(d["icon"]), String(d.get("kind", "action")), bool(d.get("danger", false)), Vector2(ITEM_W, ITEM_H))
			it.position = Vector2(X0, y)
			add_child(it)
			items.append(it)
			bases.append(it.position)
			it.hovered.connect(func() -> void: hovered.emit(i))
			it.activated.connect(func() -> void: activated.emit(i))
			y += STEP

		card = ReplayUI.InfoCard.new()
		card.position = Vector2(690.0, Y0)
		_card_base = card.position
		add_child(card)

		prompt = UIKit.make_prompt(self)
		prompt_holder = prompt.get_parent()
		prompt.set_prompts([[&"dpad_ud", "NAVIGATE"], [&"accept", "SELECT"], [&"back", "RESUME"]])

	func open(info: Dictionary, states: Array, sel: int) -> void:
		is_open = true
		visible = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		card.set_info(info)
		set_states(states, true)
		_sel = -1
		select(sel)
		if _tw:
			_tw.kill()
		_tw = UIKit.tw(self)
		_tw.tween_property(self, "open_t", 1.0, 0.7 - 0.7 * open_t).set_trans(Tween.TRANS_LINEAR)

	func close() -> void:
		if not is_open:
			return
		is_open = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _tw:
			_tw.kill()
		_tw = UIKit.tw(self)
		_tw.tween_property(self, "open_t", 0.0, 0.2 * maxf(open_t, 0.2)).set_trans(Tween.TRANS_LINEAR)
		_tw.tween_callback(func() -> void:
			if not is_open:
				visible = false)

	func select(i: int) -> void:
		if i == _sel:
			return
		_sel = i
		for k in items.size():
			(items[k] as MenuItem).set_selected(k == i)

	## states: nilai ON/OFF untuk tombol berjenis "toggle" (urut sesuai kemunculan).
	func set_states(states: Array, instant: bool = false) -> void:
		var k: int = 0
		for it in items:
			var mi: MenuItem = it
			if mi.kind == "toggle":
				if k < states.size():
					mi.set_on(bool(states[k]), instant)
				k += 1

	func pop(i: int) -> void:
		if i >= 0 and i < items.size():
			(items[i] as MenuItem).pop()

	func _apply() -> void:
		var t: float = open_t
		dim.modulate.a = clampf(t * 4.0, 0.0, 1.0)
		var tp: float = clampf(t / 0.45, 0.0, 1.0)
		title.pivot_offset = title.size * 0.5
		title.scale = Vector2.ONE * lerpf(1.8, 1.0, ReplayUI.ease_out_back(tp))
		title.modulate.a = clampf(tp * 3.0, 0.0, 1.0)
		tag.modulate.a = clampf((t - 0.15) * 4.0, 0.0, 1.0)
		for i in items.size():
			var p: float = clampf((t - float(i) * 0.045) / 0.4, 0.0, 1.0)
			var it: MenuItem = items[i]
			it.position = (bases[i] as Vector2) + Vector2(-120.0 * (1.0 - ReplayUI.ease_out_back(p)), 0.0)
			it.modulate.a = clampf(p * 2.5, 0.0, 1.0)
		var cp: float = clampf((t - 0.12) / 0.5, 0.0, 1.0)
		card.position = _card_base + Vector2(150.0 * (1.0 - ReplayUI.ease_out_cubic(cp)), 0.0)
		card.modulate.a = clampf(cp * 2.5, 0.0, 1.0)
		prompt_holder.modulate.a = clampf((t - 0.3) * 4.0, 0.0, 1.0)

	func _process(d: float) -> void:
		if visible:
			_t += d
			tag.queue_redraw()

	func _paint_tag(ci: CanvasItem) -> void:
		var pts: PackedVector2Array = UIKit.slanted(150.0, 34.0, 12.0)
		ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
		ci.draw_polyline(UIKit.closed(pts), Color(1, 0.3, 0.35, 0.8), 2.0, true)
		ci.draw_circle(Vector2(30.0, 17.0), 7.0, Color(1.0, 0.25, 0.3, 0.55 + 0.45 * sin(_t * 4.0)))
		UIKit.text_in(ci, "REPLAY", Rect2(46.0, 0.0, 100.0, 34.0), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 4)


# ================================================================== HelpPanel
class HelpPanel extends Control:
	signal dismissed

	const BW := 820.0
	const BH := 556.0

	var is_open: bool = false
	var open_t: float = 0.0:
		set(v):
			open_t = v
			_apply()
	var dim: ColorRect
	var box: ReplayUI.Box
	var close_btn: ReplayUI.Chip
	var prompt: UIKit.PromptBar
	var prompt_holder: Control
	var _tw: Tween
	var _t: float = 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		position = Vector2.ZERO
		size = Vector2(1280, 720)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		dim = ColorRect.new()
		dim.color = Color(0.01, 0.01, 0.06, 0.8)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		box = ReplayUI.Box.new()
		box.size = Vector2(BW, BH)
		box.position = Vector2(640.0 - BW * 0.5, 54.0)
		box.pivot_offset = box.size * 0.5
		box.painter = _paint
		add_child(box)
		close_btn = ReplayUI.Chip.new("CLOSE", Vector2(170, 46), UIKit.GOLD, 24, "x")
		close_btn.position = Vector2(BW - 200.0, 12.0)
		close_btn.set_active(true, true)
		close_btn.pressed.connect(func() -> void: dismissed.emit())
		box.add_child(close_btn)
		prompt = UIKit.make_prompt(self)
		prompt_holder = prompt.get_parent()
		prompt.set_prompts([[&"accept", "CLOSE"], [&"back", "CLOSE"]])

	func open() -> void:
		if is_open:
			return
		is_open = true
		visible = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		Global.play_sfx("ui_panel", -6.0)
		if _tw:
			_tw.kill()
		_tw = UIKit.tw(self)
		_tw.tween_property(self, "open_t", 1.0, 0.8 * (1.0 - open_t) + 0.05).set_trans(Tween.TRANS_LINEAR)

	func close() -> void:
		if not is_open:
			return
		is_open = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _tw:
			_tw.kill()
		_tw = UIKit.tw(self)
		_tw.tween_property(self, "open_t", 0.0, 0.18 * maxf(open_t, 0.2)).set_trans(Tween.TRANS_LINEAR)
		_tw.tween_callback(func() -> void:
			if not is_open:
				visible = false)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			dismissed.emit()

	func _apply() -> void:
		var e: float = ReplayUI.ease_out_back(clampf(open_t / 0.4, 0.0, 1.0))
		dim.modulate.a = clampf(open_t * 4.0, 0.0, 1.0)
		box.scale = Vector2.ONE * lerpf(0.9, 1.0, e)
		box.modulate.a = clampf(open_t * 4.0, 0.0, 1.0)
		prompt_holder.modulate.a = clampf((open_t - 0.4) * 4.0, 0.0, 1.0)

	func _process(d: float) -> void:
		if visible:
			_t += d
			box.queue_redraw()

	func _groups() -> Array:
		var sk: int = int(ReplayStore.skip_seconds())
		return [
			[
				["PLAYBACK", [
					[["SPACE", "K"], "PLAY / PAUSE"],
					[["LEFT", "RIGHT"], "SKIP %d SEC  (J / L)" % sk],
					[["UP", "DOWN"], "PLAYBACK SPEED"],
					[[",", "."], "STEP 1 FRAME (PAUSED)"],
					[["HOME", "END"], "START / END"],
				]],
				["NAVIGATION", [
					[["Q", "E"], "PREVIOUS / NEXT KILL"],
					[["MOUSE"], "CLICK BAR OR KILL BADGE"],
				]],
			],
			[
				["VIEW", [
					[["TAB", "M"], "PLAYER CARDS"],
					[["U"], "HIDE CONTROL BAR"],
					[["H"], "THIS HELP"],
					[["ESC"], "PAUSE MENU"],
				]],
				["CONTROLLER", [
					[["D-PAD"], "MOVE  /  CHANGE"],
					[["A / X"], "PRESS SELECTED BUTTON"],
					[["L1", "R1"], "PREVIOUS / NEXT KILL"],
					[["Y"], "PLAYER CARDS"],
					[["X"], "NEXT ROUND"],
					[["B"], "PAUSE MENU"],
				]],
			],
		]

	func _paint(ci: CanvasItem) -> void:
		var pts: PackedVector2Array = UIKit.slanted(BW, BH, 22.0)
		ci.draw_colored_polygon(UIKit.slanted(BW, BH, 22.0, 7.0, 9.0), Color(0, 0, 0, 0.55))
		var top := Color(0.07, 0.07, 0.16, 0.98)
		var bot := Color(0.04, 0.04, 0.1, 0.98)
		ci.draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
		ReplayUI.shine(ci, pts, BW, BH, fmod(_t * 0.3, 2.6) - 0.5, 0.045)
		ci.draw_polyline(UIKit.closed(pts), Color(UIKit.GOLD, 0.95), 3.0, true)
		ReplayUI.draw_icon(ci, "help", Vector2(66.0, 40.0), 15.0, UIKit.GOLD)
		UIKit.text_in(ci, "REPLAY CONTROLS", Rect2(96.0, 12.0, 460.0, 56.0), 44, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 8)
		ci.draw_line(Vector2(36.0, 76.0), Vector2(BW - 36.0, 76.0), Color(1, 1, 1, 0.16), 2.0)
		var cols: Array = _groups()
		var k: int = 0
		for ci_idx in cols.size():
			var x: float = 40.0 + float(ci_idx) * 392.0
			var y: float = 92.0
			for g in cols[ci_idx]:
				var ga: float = _row_alpha(k)
				k += 1
				UIKit.text_in(ci, String(g[0]), Rect2(x + 4.0 + (1.0 - ga) * 24.0, y, 300.0, 30.0), 21, Color(UIKit.CYAN, ga), HORIZONTAL_ALIGNMENT_LEFT, 4)
				ci.draw_line(Vector2(x, y + 30.0), Vector2(x + 360.0, y + 30.0), Color(UIKit.CYAN, 0.35 * ga), 2.0)
				y += 36.0
				for row in g[1]:
					var ra: float = _row_alpha(k)
					k += 1
					var off: float = (1.0 - ra) * 30.0
					var kx: float = x + 4.0 + off
					for key in row[0]:
						kx += ReplayUI.keycap(ci, String(key), kx, y + 15.0, ra) + 6.0
					UIKit.text_in(ci, String(row[1]), Rect2(x + 170.0 + off, y, 200.0, 30.0), 18, Color(1, 1, 1, 0.9 * ra), HORIZONTAL_ALIGNMENT_LEFT, 3)
					y += 34.0
				y += 10.0
		var pulse: float = 0.45 + 0.25 * sin(_t * 3.0)
		UIKit.text_in(ci, "PRESS ANY BUTTON OR CLICK TO CLOSE", Rect2(0.0, BH - 44.0, BW, 30.0), 18, Color(1, 1, 1, pulse), HORIZONTAL_ALIGNMENT_CENTER)

	func _row_alpha(k: int) -> float:
		return ReplayUI.ease_out_cubic(clampf((open_t - 0.18 - float(k) * 0.02) / 0.35, 0.0, 1.0))


# ================================================================== EndPanel
class EndPanel extends Control:
	signal again
	signal list
	signal hovered(i: int)

	const BW := 660.0
	const BH := 450.0

	var is_open: bool = false
	var focus: int = 0
	var meta: Dictionary = {}
	var rounds_n: int = 0
	var duration: float = 0.0
	var open_t: float = 0.0:
		set(v):
			open_t = v
			_apply()
	var count_t: float = 0.0
	var dim: ColorRect
	var box: ReplayUI.Box
	var btn_again: ReplayUI.Chip
	var btn_list: ReplayUI.Chip
	var prompt: UIKit.PromptBar
	var prompt_holder: Control
	var _tw: Tween
	var _ctw: Tween
	var _t: float = 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		position = Vector2.ZERO
		size = Vector2(1280, 720)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		dim = ColorRect.new()
		dim.color = Color(0, 0, 0.04, 0.7)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		box = ReplayUI.Box.new()
		box.size = Vector2(BW, BH)
		box.position = Vector2(640.0 - BW * 0.5, 360.0 - BH * 0.5 - 10.0)
		box.pivot_offset = box.size * 0.5
		box.painter = _paint
		add_child(box)
		btn_again = ReplayUI.Chip.new("WATCH AGAIN", Vector2(270, 64), UIKit.GREEN, 28, "restart")
		btn_again.position = Vector2(46, BH - 94.0)
		btn_again.pressed.connect(func() -> void: again.emit())
		btn_again.hovered.connect(func() -> void: hovered.emit(0))
		box.add_child(btn_again)
		btn_list = ReplayUI.Chip.new("BACK TO LIST", Vector2(270, 64), UIKit.GOLD, 28, "list")
		btn_list.position = Vector2(BW - 46.0 - 270.0, BH - 94.0)
		btn_list.pressed.connect(func() -> void: list.emit())
		btn_list.hovered.connect(func() -> void: hovered.emit(1))
		box.add_child(btn_list)
		prompt = UIKit.make_prompt(self)
		prompt_holder = prompt.get_parent()
		prompt.set_prompts([[&"dpad_lr", "SELECT"], [&"accept", "CONFIRM"], [&"back", "BACK TO LIST"]])

	func setup(m: Dictionary, rounds_count: int, dur: float) -> void:
		meta = m
		rounds_n = rounds_count
		duration = dur

	func set_focus(i: int) -> void:
		if i == focus and btn_again.active == (i == 0):
			return
		focus = i
		btn_again.set_active(i == 0)
		btn_list.set_active(i == 1)

	func open() -> void:
		if is_open:
			return
		is_open = true
		visible = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		set_focus(0)
		btn_again.set_active(true, true)
		btn_list.set_active(false, true)
		Global.play_sfx("ui_panel", -5.0)
		count_t = 0.0
		if _tw:
			_tw.kill()
		_tw = UIKit.tw(self)
		_tw.tween_property(self, "open_t", 1.0, 0.5 * (1.0 - open_t) + 0.05).set_trans(Tween.TRANS_LINEAR)
		if _ctw:
			_ctw.kill()
		_ctw = UIKit.tw(self)
		_ctw.tween_property(self, "count_t", 1.0, 1.1).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT).set_delay(0.3)
		if bool(meta.get("finished", true)):
			var wc: Color = meta.get("winner_color", UIKit.GOLD)
			UIKit.burst(self, Vector2(640.0, 250.0), wc, 34, 420.0, 7.0, 1.0)
			UIKit.burst(self, Vector2(640.0, 250.0), UIKit.GOLD, 22, 320.0, 6.0, 0.9)

	func close() -> void:
		if not is_open:
			return
		is_open = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if _tw:
			_tw.kill()
		_tw = UIKit.tw(self)
		_tw.tween_property(self, "open_t", 0.0, 0.2 * maxf(open_t, 0.2)).set_trans(Tween.TRANS_LINEAR)
		_tw.tween_callback(func() -> void:
			if not is_open:
				visible = false)

	func _apply() -> void:
		var e: float = ReplayUI.ease_out_back(clampf(open_t / 0.55, 0.0, 1.0))
		dim.modulate.a = clampf(open_t * 3.0, 0.0, 1.0)
		box.scale = Vector2.ONE * lerpf(0.78, 1.0, e)
		box.modulate.a = clampf(open_t * 3.5, 0.0, 1.0)
		prompt_holder.modulate.a = clampf((open_t - 0.4) * 4.0, 0.0, 1.0)

	func _process(d: float) -> void:
		if visible:
			_t += d
			box.queue_redraw()

	func _paint(ci: CanvasItem) -> void:
		var wc: Color = meta.get("winner_color", Color.WHITE)
		var done: bool = bool(meta.get("finished", true)) and String(meta.get("winner_label", "")) != ""
		var accent: Color = wc if done else UIKit.GOLD
		var pts: PackedVector2Array = UIKit.slanted(BW, BH, 24.0)
		ci.draw_colored_polygon(UIKit.slanted(BW, BH, 24.0, 8.0, 10.0), Color(0, 0, 0, 0.55))
		var top := Color(0.08, 0.08, 0.18, 0.98)
		var bot := Color(0.04, 0.04, 0.1, 0.98)
		ci.draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
		# sorot warna pemenang dari atas
		ci.draw_polygon(PackedVector2Array([Vector2(24.0, 0), Vector2(BW, 0), Vector2(BW - 24.0, 150.0), Vector2(0, 150.0)]),
			PackedColorArray([Color(accent, 0.26), Color(accent, 0.26), Color(accent, 0.0), Color(accent, 0.0)]))
		ReplayUI.shine(ci, pts, BW, BH, fmod(_t * 0.4, 2.4) - 0.5, 0.05)
		ci.draw_polyline(UIKit.closed(pts), Color(accent.lerp(UIKit.GOLD, 0.35), 0.95), 3.0, true)
		UIKit.text_in(ci, "REPLAY FINISHED", Rect2(0.0, 14.0, BW, 56.0), 46, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 8)
		var ea: float = ReplayUI.ease_out_cubic(clampf((open_t - 0.25) / 0.4, 0.0, 1.0))
		if done:
			# potret pemenang
			var pl: Array = meta.get("players", [])
			var wt: int = int(meta.get("winner_team", -1))
			var n: int = pl.size()
			var ps: float = 56.0
			var total: float = float(n) * (ps + 14.0) - 14.0
			var x0: float = (BW - total) * 0.5
			for i in n:
				var pd: Dictionary = pl[i]
				var win: bool = int(pd.get("team", -1)) == wt
				var r := Rect2(x0 + float(i) * (ps + 14.0), 82.0 - (1.0 - ea) * 14.0, ps, ps)
				var col: Color = pd["color"]
				ci.draw_rect(Rect2(r.position - Vector2(3, 3), r.size + Vector2(6, 6)), Color(UIKit.GOLD if win else col, ea * (1.0 if win else 0.45)))
				ci.draw_texture_rect(Global.character_texture(0, int(pd["char"])), r, false, Color(1, 1, 1, ea * (1.0 if win else 0.5)))
				if win:
					ReplayUI.draw_icon(ci, "check", Vector2(r.end.x - 4.0, r.end.y - 4.0), 9.0, Color(UIKit.GREEN, ea))
			UIKit.text_in(ci, "%s WINS THE MATCH" % String(meta.get("winner_label", "")), Rect2(0.0, 150.0, BW, 52.0), 40, Color(wc, ea), HORIZONTAL_ALIGNMENT_CENTER, 8)
			var sc: String = String(meta.get("score", ""))
			if sc != "":
				UIKit.text_in(ci, "SCORE  " + sc, Rect2(0.0, 198.0, BW, 36.0), 28, Color(1, 1, 1, 0.9 * ea), HORIZONTAL_ALIGNMENT_CENTER, 5)
		else:
			UIKit.text_in(ci, "MATCH WAS NOT FINISHED", Rect2(0.0, 120.0, BW, 50.0), 36, Color(1, 1, 1, 0.8 * ea), HORIZONTAL_ALIGNMENT_CENTER, 6)
		# statistik (menghitung naik)
		var stats: Array = [
			[str(int(roundf(float(rounds_n) * count_t))), "ROUNDS"],
			[str(int(roundf(float(int(meta.get("kills", 0))) * count_t))), "KILLS"],
			[ReplayStore.format_clock(duration * count_t), "LENGTH"],
		]
		var sw: float = (BW - 92.0) / 3.0
		for i in 3:
			var cx: float = 46.0 + sw * (float(i) + 0.5)
			var sa: float = ReplayUI.ease_out_cubic(clampf((open_t - 0.35 - float(i) * 0.06) / 0.35, 0.0, 1.0))
			UIKit.text_in(ci, String(stats[i][0]), Rect2(cx - sw * 0.5, 246.0 + (1.0 - sa) * 14.0, sw, 56.0), 48, Color(UIKit.GOLD, sa), HORIZONTAL_ALIGNMENT_CENTER, 7)
			UIKit.text_in(ci, String(stats[i][1]), Rect2(cx - sw * 0.5, 298.0, sw, 24.0), 18, Color(1, 1, 1, 0.6 * sa), HORIZONTAL_ALIGNMENT_CENTER, 3)
			if i > 0:
				ci.draw_line(Vector2(46.0 + sw * float(i), 258.0), Vector2(46.0 + sw * float(i), 316.0), Color(1, 1, 1, 0.15 * sa), 2.0)
