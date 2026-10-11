extends Control
## Layar "SELECT YOUR TEAMS" (mode versus 3-4 pemain), muncul setelah semua pemain READY di layar pilih fighter
## dan sebelum BATTLE SETTINGS.
##
##  - Ada 4 jalur TEAM 01 - TEAM 04. Awalnya tiap pemain berdiri di jalurnya sendiri (semua sendiri-sendiri = FFA).
##  - Tiap pemain menggeser kartunya sendiri KIRI / KANAN untuk bergabung ke jalur lain, lalu menekan TEMBAK / ACCEPT = READY.
##  - Batas anggota satu tim: 4 pemain -> maksimal 3, 3 pemain -> maksimal 2 (jadi 1v1v1v1, 2v1v1, 2v2, 3v1 ...).
##  - Tim yang lebih banyak anggotanya dari tim terkecil kena NERF ringan (angkanya tampil di jalur tim itu).
##  - Hasil pembagian disimpan di Global.team_of dan dibaca game.gd.
##  - Mouse: klik kartu = pilih, klik jalur = pindahkan kartu terpilih, klik kartu terpilih lagi = READY.

const LANES := 4
const LANE_W := 320.0
const TOKEN_W := 288.0
const TOKEN_H := 92.0
const TOKEN_Y0 := 256.0
const TOKEN_STEP := 102.0
const COUNTDOWN_FROM := 2.0

var n: int = 3
var lanes: Array[TeamLane] = []
var tokens: Array[TeamToken] = []
var ready_flags: Array[bool] = [false, false, false, false]
var summary: SummaryPlate
var title_block: TitleBlock
var bg: UIKit.FxBackground
var prompt: UIKit.PromptBar
var status: UIKit.PadStatus
var back_btn: UIKit.FancyButton

var leaving := false
var countdown_on := false
var cd_time: float = 0.0
var mouse_slot: int = 0
var _cd_guard: int = 0
var _enter_ms: int = 0
var _last_confirm: Array[int] = [0, 0, 0, 0]


static func slot_pos(lane: int, k: int) -> Vector2:
	return Vector2(float(lane) * LANE_W + (LANE_W - TOKEN_W) * 0.5, TOKEN_Y0 + float(k) * TOKEN_STEP)


# ================================================================== jalur tim
class TeamLane extends Control:
	signal clicked(lane: int)

	const TOKEN_W := 288.0
	const TOKEN_H := 92.0
	const TOKEN_Y0 := 256.0
	const TOKEN_STEP := 102.0
	const TILT := 0.17

	var lane: int = 0
	var t: float = 0.0
	var occ: float = 0.0            # 0..1: seberapa "menyala" jalur ini (ada anggota)
	var flash: float = 0.0
	var members: int = 0
	var cap: int = 3
	var level: int = 0              # level nerf tim ini

	func _init(i: int = 0) -> void:
		lane = i
		size = Vector2(320, 720)
		custom_minimum_size = size
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_members(m: int, c: int, lv: int) -> void:
		if m > members:
			pulse()
		members = m
		cap = c
		level = lv

	func pulse() -> void:
		flash = 1.0
		UIKit.tw(self).tween_property(self, "flash", 0.0, 0.55)

	func _process(d: float) -> void:
		t += d
		var target: float = 1.0 if members > 0 else 0.0
		occ = lerpf(occ, target, 1.0 - exp(-d * 7.0))
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(lane)

	# teks / pita yang berputar miring (gaya poster tim)
	func _ang() -> float:
		var sgn: float = -1.0 if lane < 2 else 1.0     # jalur kiri miring ke kiri atas, kanan ke kanan atas -> membentuk "V"
		return -PI * 0.5 + sgn * TILT

	func _draw_scroll_text(cx: float, label: String, fs: int, scroll: float, fill: Color, edge: Color, edge_w: int) -> void:
		var fnt: Font = UIKit.font()
		var tw: float = fnt.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var period: float = tw + 80.0
		draw_set_transform(Vector2(cx, size.y * 0.5), _ang(), Vector2.ONE)
		var s: float = -640.0 - period + fposmod(scroll, period)
		while s < 640.0:
			var p := Vector2(s, float(fs) * 0.36)
			if edge.a > 0.02:
				draw_string_outline(fnt, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, edge_w, edge)
			draw_string(fnt, p, label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fill)
			s += period
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw_band(cx: float, thick: float, col: Color, label: String, fs: int, scroll: float, ink: Color) -> void:
		var fnt: Font = UIKit.font()
		var lw: float = fnt.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var period: float = lw + 130.0
		draw_set_transform(Vector2(cx, size.y * 0.5), _ang(), Vector2.ONE)
		draw_rect(Rect2(-700.0, -thick * 0.5, 1400.0, thick), col)
		draw_rect(Rect2(-700.0, -thick * 0.5, 1400.0, 2.0), Color(1, 1, 1, 0.45 * col.a))
		draw_rect(Rect2(-700.0, thick * 0.5 - 2.0, 1400.0, 2.0), Color(0, 0, 0, 0.35 * col.a))
		var s: float = -700.0 - period + fposmod(scroll, period)
		while s < 700.0:
			for c in 3:
				var x0: float = s + float(c) * 17.0
				draw_colored_polygon(PackedVector2Array([Vector2(x0, -6.0), Vector2(x0 + 8.0, 0.0), Vector2(x0, 6.0)]), ink)
			draw_string(fnt, Vector2(s + 62.0, float(fs) * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)
			s += period
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var col: Color = Global.team_color(lane)
		var lit: float = occ
		# ----- dasar jalur (sedikit transparan supaya efek latar tetap terlihat)
		var c_top: Color = Color(0.02, 0.025, 0.05, 0.9).lerp(Color(col.darkened(0.72), 0.92), 0.3 + 0.5 * lit)
		var c_bot := Color(0.0, 0.0, 0.0, 0.92)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([c_top, c_top, c_bot, c_bot]))

		# ----- teks besar "TEAM 0X" berputar + pita POINT / ASSIST
		var name_txt: String = Global.team_name(lane)
		var fill := Color(1, 1, 1, lerpf(0.08, 0.95, lit))
		var edge := Color(col, lerpf(0.0, 0.95, lit))
		_draw_scroll_text(w * 0.5, name_txt, 112, t * 46.0, fill, edge, 6)
		_draw_band(w * 0.5 + 122.0, 30.0, Color(col, lerpf(0.18, 1.0, lit)), "POINT", 20, -t * 70.0, Color(0.03, 0.04, 0.08, 0.9))
		_draw_band(w * 0.5 - 132.0, 22.0, Color(col.darkened(0.3), lerpf(0.14, 0.85, lit)), "ASSIST", 15, t * 52.0, Color(0.03, 0.04, 0.08, 0.85))

		# ----- tepi jalur + kilatan saat ada yang bergabung
		draw_line(Vector2(1.5, 0), Vector2(1.5, h), Color(col, 0.3 + 0.5 * lit), 3.0)
		if flash > 0.0:
			draw_rect(Rect2(0, 0, w, h), Color(col.lightened(0.5), flash * 0.22))

		# ----- plat nama tim
		var hy := 104.0
		var hp := UIKit.slanted(w - 36.0, 42.0, 14.0, 18.0, hy)
		draw_colored_polygon(UIKit.slanted(w - 36.0, 42.0, 14.0, 23.0, hy + 5.0), Color(0, 0, 0, 0.5))
		var h0: Color = col.lerp(col.darkened(0.55), 1.0 - lit)
		var h1: Color = h0.darkened(0.35)
		draw_polygon(hp, PackedColorArray([h0, h0, h1, h1]))
		draw_polyline(UIKit.closed(hp), Color(1, 1, 1, 0.35 + 0.6 * lit), 2.0 + lit, true)
		UIKit.text_in(self, name_txt, Rect2(18.0 + 14.0, hy, w - 36.0 - 14.0, 42.0), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6)

		# ----- kapasitas (kotak kecil: terisi = anggota)
		var pw := 34.0
		var gp := 8.0
		var px0: float = (w - (float(cap) * pw + float(cap - 1) * gp)) * 0.5
		for k in cap:
			var rr := Rect2(px0 + float(k) * (pw + gp), 156.0, pw, 11.0)
			var sp := UIKit.slanted(rr.size.x, rr.size.y, 5.0, rr.position.x, rr.position.y)
			draw_colored_polygon(sp, col if k < members else Color(1, 1, 1, 0.14))
			draw_polyline(UIKit.closed(sp), Color(0, 0, 0, 0.7), 1.5, true)

		# ----- kotak HANDICAP (hanya tim yang lebih banyak anggotanya)
		if level > 0:
			var nerf: Dictionary = Global.TEAM_NERF[level]
			var bx := 22.0
			var by := 176.0
			var bw: float = w - 44.0
			var bh := 70.0
			var bp := UIKit.slanted(bw, bh, 12.0, bx, by)
			var bl: float = 0.5 + 0.5 * sin(t * 4.0)
			draw_colored_polygon(bp, Color(0.28, 0.04, 0.05, 0.9))
			draw_polyline(UIKit.closed(bp), Color(1.0, 0.36, 0.3, 0.6 + 0.3 * bl), 2.0, true)
			for k in level:
				var ac := Vector2(bx + 28.0 + float(k) * 15.0, by + 15.0)
				draw_colored_polygon(PackedVector2Array([ac + Vector2(-6, -5), ac + Vector2(6, -5), ac + Vector2(0, 6)]), Color(1.0, 0.4, 0.34))
			UIKit.text_in(self, "HANDICAP", Rect2(bx + 28.0 + float(level) * 15.0 + 4.0, by + 3.0, 130, 24), 18, Color(1.0, 0.5, 0.42), HORIZONTAL_ALIGNMENT_LEFT, 4)
			var dmg_p: int = roundi((1.0 - float(nerf["dmg"])) * 100.0)
			var rate_p: int = roundi((1.0 - 1.0 / float(nerf["rate"])) * 100.0)
			var spd_p: int = roundi((1.0 - float(nerf["speed"])) * 100.0)
			var lines: Array[String] = ["DAMAGE -%d%%" % dmg_p, "FIRE RATE -%d%%" % rate_p, "SPEED -%d%%" % spd_p]
			for k in 3:
				UIKit.text_in(self, lines[k], Rect2(bx + 30.0, by + 26.0 + float(k) * 14.0, bw - 50.0, 14), 13, Color(1, 1, 1, 0.82), HORIZONTAL_ALIGNMENT_LEFT, 3)

		# ----- slot kosong (garis putus tipis) di tempat kartu pemain akan berdiri
		for k in cap:
			if k < members:
				continue
			var sr := Rect2((w - TOKEN_W) * 0.5, TOKEN_Y0 + float(k) * TOKEN_STEP, TOKEN_W, TOKEN_H)
			var spts := UIKit.slanted(sr.size.x, sr.size.y, 14.0, sr.position.x, sr.position.y)
			draw_colored_polygon(spts, Color(col, 0.045))
			draw_polyline(UIKit.closed(spts), Color(col, 0.2 + 0.1 * sin(t * 2.0 + float(k))), 2.0, true)
			if k == members:
				UIKit.text_in(self, "OPEN SLOT" if members > 0 else "EMPTY", sr, 24, Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 4)


# ================================================================== kartu pemain
class TeamToken extends Control:
	signal clicked(slot: int)

	var slot: int = 0
	var char_idx: int = 0
	var name_text: String = ""
	var device_text: String = "KEYBOARD"
	var team: int = 0
	var team_group: bool = false
	var is_ready: bool = false
	var selected: bool = false
	var target: Vector2 = Vector2.ZERO
	var delay: float = 0.0
	var t: float = 0.0
	var pop: float = 1.0
	var shake: float = 0.0
	var ready_glow: float = 0.0

	func _init(i: int = 0) -> void:
		slot = i
		size = Vector2(288, 92)
		custom_minimum_size = size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(slot)

	func move_fx() -> void:
		pop = 1.14
		UIKit.tw(self).tween_property(self, "pop", 1.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func ready_fx(on: bool) -> void:
		is_ready = on
		pop = 1.22 if on else 0.92
		var tw := UIKit.tw(self)
		tw.set_parallel(true)
		tw.tween_property(self, "pop", 1.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "ready_glow", 1.0 if on else 0.0, 0.3)

	func deny_fx() -> void:
		var tw := UIKit.tw(self)
		for v in [12.0, -10.0, 7.0, -4.0, 0.0]:
			tw.tween_property(self, "shake", v, 0.04)

	func _process(d: float) -> void:
		t += d
		if t >= delay:
			var old: Vector2 = position
			position = position.lerp(target, 1.0 - exp(-d * 12.0))
			var vx: float = (position.x - old.x) / maxf(d, 0.0001)
			rotation = lerpf(rotation, clampf(vx * 0.00018, -0.12, 0.12), 1.0 - exp(-d * 16.0))
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var pcol: Color = Global.PLAYER_COLORS[slot]
		var tcol: Color = Global.team_color(team)
		draw_set_transform(Vector2(shake, 0.0) + size * 0.5 * (1.0 - pop), 0.0, Vector2.ONE * pop)
		var pts := UIKit.slanted(w, h, 14.0)
		draw_colored_polygon(UIKit.slanted(w, h, 14.0, 6.0, 8.0), Color(0, 0, 0, 0.55))
		var c0: Color = Color(0.11, 0.12, 0.22, 0.97).lerp(Color(0.06, 0.26, 0.15, 0.98), ready_glow)
		var c1: Color = Color(0.03, 0.04, 0.09, 0.98).lerp(Color(0.02, 0.1, 0.06, 0.98), ready_glow)
		draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
		# kilau tipis
		var sh: float = fposmod(t * 0.45 + float(slot) * 0.3, 2.0) - 0.5
		var gx: float = sh * w
		var band := PackedVector2Array([Vector2(gx + 10, 0), Vector2(gx + 36, 0), Vector2(gx + 22, h), Vector2(gx - 4, h)])
		var clipped: Array = Geometry2D.intersect_polygons(band, pts)
		if not clipped.is_empty() and (clipped[0] as PackedVector2Array).size() >= 3:
			draw_colored_polygon(clipped[0], Color(1, 1, 1, 0.07))
		# garis aksen warna pemain di kiri
		draw_colored_polygon(UIKit.slanted(24.0, h, 14.0, 0.0, 0.0), pcol)
		var border: Color = Color(1, 1, 1, 0.3)
		if team_group:
			border = tcol
		if is_ready:
			border = UIKit.GREEN
		if selected:
			draw_polyline(UIKit.closed(UIKit.slanted(w + 8.0, h + 8.0, 14.0, -4.0, -4.0)), Color(UIKit.GOLD, 0.8 + 0.2 * sin(t * 8.0)), 2.0, true)
		draw_polyline(UIKit.closed(pts), border, 3.0 + ready_glow, true)

		# potret
		var pr := Rect2(32.0, 12.0, 68.0, 68.0)
		draw_rect(pr.grow(3.0), pcol)
		draw_texture_rect(Global.character_texture(0, char_idx), pr, false)
		# teks
		UIKit.text_in(self, "P%d" % (slot + 1), Rect2(112.0, 6.0, 60.0, 28.0), 22, pcol.lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT, 5)
		var fs := 26
		while fs > 15 and UIKit.text_w(name_text, fs) > 150.0:
			fs -= 1
		UIKit.text_in(self, name_text, Rect2(112.0, 30.0, 156.0, 30.0), fs, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 5)
		UIKit.text_in(self, device_text, Rect2(112.0, 62.0, 150.0, 22.0), 15, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, 3)
		# kanan atas: READY / panah geser
		if is_ready:
			var br := Rect2(w - 112.0, 8.0, 92.0, 26.0)
			var bp := UIKit.slanted(br.size.x, br.size.y, 8.0, br.position.x, br.position.y)
			draw_colored_polygon(bp, UIKit.GREEN.darkened(0.25))
			draw_polyline(UIKit.closed(bp), Color.WHITE, 2.0, true)
			UIKit.text_in(self, "READY", br, 19, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 4)
		else:
			var a: float = 0.5 + 0.5 * sin(t * 6.0)
			UIKit.draw_chevron(self, Vector2(w - 66.0 - a * 3.0, 21.0), 8.0, -1, Color(UIKit.GOLD, 0.55 + 0.45 * a))
			UIKit.draw_chevron(self, Vector2(w - 34.0 + a * 3.0, 21.0), 8.0, 1, Color(UIKit.GOLD, 0.55 + 0.45 * (1.0 - a)))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ================================================================== ringkasan susunan tim
class SummaryPlate extends Control:
	var parts: Array = []                 # [{txt, col}] contoh: 3 (hijau) v 1 (biru)
	var small_a: String = ""
	var small_b: String = ""
	var small_col: Color = Color.WHITE
	var counting: bool = false
	var cd_value: int = 0
	var pop: float = 1.0
	var count_pop: float = 1.0
	var t: float = 0.0
	var _sig: String = ""

	func _init() -> void:
		size = Vector2(640, 62)
		custom_minimum_size = size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_info(p: Array, a: String, b: String, c: Color) -> void:
		var sig: String = str(p) + a + b
		if sig != _sig:
			_sig = sig
			pop = 1.08
			UIKit.tw(self).tween_property(self, "pop", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		parts = p
		small_a = a
		small_b = b
		small_col = c

	func start_count() -> void:
		counting = true

	func stop_count() -> void:
		counting = false
		cd_value = 0

	func set_count(v: int) -> void:
		cd_value = v
		count_pop = 1.6
		UIKit.tw(self).tween_property(self, "count_pop", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_set_transform(size * 0.5 * (1.0 - pop), 0.0, Vector2.ONE * pop)
		var pts := UIKit.slanted(w, h, 22.0)
		draw_colored_polygon(UIKit.slanted(w, h, 22.0, 6.0, 7.0), Color(0, 0, 0, 0.55))
		var c0 := Color(0.05, 0.06, 0.12, 0.94)
		if counting:
			c0 = Color(0.05, 0.22, 0.12, 0.96)
		draw_colored_polygon(pts, c0)
		draw_polyline(UIKit.closed(pts), UIKit.GREEN if counting else Color(1, 1, 1, 0.3), 3.0, true)
		if counting:
			UIKit.text_in(self, "ALL READY!", Rect2(40.0, 0.0, w * 0.5 - 40.0, h), 34, UIKit.GREEN, HORIZONTAL_ALIGNMENT_LEFT, 7)
			draw_set_transform(Vector2(w * 0.5 + 120.0, h * 0.5 - 3.0), 0.0, Vector2.ONE * count_pop)
			UIKit.text_in(self, "STARTING  %d" % cd_value, Rect2(-150.0, -30.0, 300.0, 60.0), 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 8, Color.BLACK, Global.font_digital)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return
		# susunan tim: angka berwarna tim
		var fs := 40
		var x: float = 42.0
		for p in parts:
			var txt: String = str(p["txt"])
			var tw: float = UIKit.text_w(txt, fs)
			UIKit.text_in(self, txt, Rect2(x, 0.0, tw + 4.0, h), fs, p["col"], HORIZONTAL_ALIGNMENT_LEFT, 8)
			x += tw
		var lx: float = maxf(x + 30.0, w * 0.5)
		UIKit.text_in(self, small_a, Rect2(lx, 6.0, w - lx - 34.0, 28.0), 22, small_col, HORIZONTAL_ALIGNMENT_RIGHT, 5)
		UIKit.text_in(self, small_b, Rect2(lx, 32.0, w - lx - 34.0, 22.0), 15, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_RIGHT, 3)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ================================================================== judul "SELECT YOUR TEAMS"
class TitleBlock extends Control:
	var t: float = 0.0

	func _init() -> void:
		size = Vector2(520, 94)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var lime: Color = Global.team_color(0)
		var pts := UIKit.slanted(w, h, 30.0)
		draw_colored_polygon(UIKit.slanted(w, h, 30.0, 6.0, 8.0), Color(0, 0, 0, 0.6))
		var c0 := Color(0.02, 0.03, 0.05, 0.96)
		var c1 := Color(0.0, 0.0, 0.0, 0.96)
		draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
		draw_polyline(UIKit.closed(pts), Color(lime, 0.85), 3.0, true)
		# kotak 4 warna tim di kedua sisi
		for k in 4:
			var col: Color = Global.team_color(k)
			var a: float = 0.55 + 0.45 * sin(t * 3.0 + float(k) * 0.9)
			draw_rect(Rect2(52.0 + float(k) * 13.0, h - 17.0, 9.0, 9.0), Color(col, a))
			draw_rect(Rect2(w - 52.0 - 9.0 - float(k) * 13.0, h - 17.0, 9.0, 9.0), Color(col, a))
		UIKit.text_in(self, "SELECT YOUR", Rect2(0.0, 5.0, w, 26.0), 22, lime, HORIZONTAL_ALIGNMENT_CENTER, 5)
		UIKit.text_in(self, "TEAMS", Rect2(3.0, 25.0, w, 66.0), 58, Color(0, 0, 0, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
		UIKit.text_in(self, "TEAMS", Rect2(0.0, 22.0, w, 66.0), 58, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10, Color(0.06, 0.12, 0.02))
		# kilap lewat
		var sweep: float = fposmod(t * 0.4, 2.4) - 0.7
		var gx: float = sweep * w
		var band := PackedVector2Array([Vector2(gx, 0), Vector2(gx + 34, 0), Vector2(gx + 14, h), Vector2(gx - 20, h)])
		var clipped: Array = Geometry2D.intersect_polygons(band, pts)
		if not clipped.is_empty() and (clipped[0] as PackedVector2Array).size() >= 3:
			draw_colored_polygon(clipped[0], Color(1, 1, 1, 0.12))


# ================================================================== setup
func _ready() -> void:
	theme = Global.ui_theme
	Global.play_music("menu")
	_enter_ms = Time.get_ticks_msec()

	n = Global.player_count
	Global.sanitize_teams()
	# scene dibuka langsung tanpa pilih fighter: beri bawaan supaya layar tetap bisa dicoba
	if Global.selections.size() != n:
		Global.selections = []
		for i in n:
			Global.selections.append({"character": i * 4, "weapon": "pistol"})

	bg = UIKit.FxBackground.new()
	add_child(bg)
	bg.set_palette(Color("02030a"), Color("0a1020"), Global.team_color(0), 0.0)

	for i in LANES:
		var lane := TeamLane.new(i)
		lane.position = Vector2(float(i) * LANE_W, 0.0)
		lane.clicked.connect(_on_lane_clicked)
		add_child(lane)
		lanes.append(lane)

	for i in n:
		var tk := TeamToken.new(i)
		tk.char_idx = int(Global.selections[i]["character"])
		tk.name_text = Global.character_name(0, tk.char_idx)
		tk.clicked.connect(_on_token_clicked)
		add_child(tk)
		tokens.append(tk)
	tokens[mouse_slot].selected = true

	title_block = TitleBlock.new()
	title_block.position = Vector2((1280.0 - title_block.size.x) * 0.5, 8.0)
	add_child(title_block)

	status = UIKit.PadStatus.new()
	status.position = Vector2(1280 - 350 - 14, 16)
	status.shown = n
	add_child(status)

	summary = SummaryPlate.new()
	summary.position = Vector2((1280.0 - summary.size.x) * 0.5, 574.0)
	add_child(summary)

	back_btn = UIKit.FancyButton.new("BACK", Vector2(190, 46), 28)
	back_btn.position = Vector2(10, 656)
	back_btn.accent = Color("ff7a7a")
	back_btn.activated.connect(_on_back)
	back_btn.modulate.a = 0.85
	add_child(back_btn)

	prompt = UIKit.make_prompt(self)

	_refresh_devices()
	_relayout(true)
	_update_prompts()

	UIInput.pressed.connect(_on_input)
	UIInput.pad_changed.connect(func(_d: int, _c: bool) -> void: _refresh_devices.call_deferred())
	_play_intro()


func _exit_tree() -> void:
	if UIInput.pressed.is_connected(_on_input):
		UIInput.pressed.disconnect(_on_input)


func _play_intro() -> void:
	title_block.position.y = -130.0
	UIKit.tw(title_block).tween_property(title_block, "position:y", 8.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)
	for i in LANES:
		var lane: TeamLane = lanes[i]
		lane.position.y = -730.0
		UIKit.tw(lane).tween_property(lane, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT).set_delay(0.04 + float(i) * 0.08)
	for i in n:
		var tk: TeamToken = tokens[i]
		tk.position = tk.target + Vector2(0.0, -560.0)
		tk.delay = 0.38 + float(i) * 0.09
		tk.modulate.a = 0.0
		UIKit.tw(tk).tween_property(tk, "modulate:a", 1.0, 0.3).set_delay(tk.delay)
	summary.position.y = 760.0
	UIKit.tw(summary).tween_property(summary, "position:y", 574.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.5)


## Nama perangkat tiap kartu.
func _refresh_devices() -> void:
	var pads: Array[int] = UIInput.pads()
	for i in tokens.size():
		var dev: int = Global.device_of(i)
		if dev >= 0 and pads.has(dev):
			tokens[i].device_text = "PAD %d" % (pads.find(dev) + 1)
		else:
			tokens[i].device_text = "KEYBOARD"
	_update_prompts()


## Hitung ulang posisi semua kartu + info jalur + ringkasan. instant = langsung tanpa meluncur.
func _relayout(instant: bool = false) -> void:
	var cap: int = Global.team_cap()
	for l in LANES:
		var mem: Array[int] = Global.team_members(l)
		lanes[l].set_members(mem.size(), cap, Global.team_nerf_level(l))
		for k in mem.size():
			var tk: TeamToken = tokens[mem[k]]
			tk.target = slot_pos(l, k)
			tk.team = l
			tk.team_group = mem.size() >= 2
			if instant:
				tk.position = tk.target
	_update_summary()


func _update_summary() -> void:
	var sizes: Array = []
	for l in LANES:
		var sz: int = Global.team_size(l)
		if sz > 0:
			sizes.append([sz, l])
	sizes.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] > b[0]
		return a[1] < b[1])
	if not Global.teams_active():
		summary.set_info([{"txt": "FREE FOR ALL", "col": Color.WHITE}], "EVERYONE FOR THEMSELVES", "MOVE LEFT / RIGHT TO FORM TEAMS", Color(1, 1, 1, 0.8))
		return
	var parts: Array = []
	var any_nerf := false
	for k in sizes.size():
		if k > 0:
			parts.append({"txt": " v ", "col": Color(1, 1, 1, 0.75)})
		parts.append({"txt": str(sizes[k][0]), "col": Global.team_color(int(sizes[k][1]))})
		if Global.team_nerf_level(int(sizes[k][1])) > 0:
			any_nerf = true
	if any_nerf:
		summary.set_info(parts, "HANDICAP ACTIVE", "BIGGER TEAM IS SLIGHTLY NERFED", Color(1.0, 0.55, 0.35))
	else:
		summary.set_info(parts, "BALANCED MATCH", "EVEN TEAMS - NO HANDICAP", UIKit.GREEN)


# ================================================================== input
## Pemain mana yang dikendalikan oleh sumber input ini (sama seperti layar pilih fighter).
func _slot_for(source: int) -> int:
	if source >= 0:
		return Global.slot_of_device(source)
	if UIInput.is_generic(source):
		return 0 if (n > 0 and not Global.uses_pad(0)) else -1
	var k: int = UIInput.layout_of(source)
	if k >= n or Global.uses_pad(k):
		return -1
	return k


func _on_input(source: int, action: StringName) -> void:
	if leaving or Time.get_ticks_msec() - _enter_ms < 300:
		return
	var slot: int = _slot_for(source)
	if slot < 0:
		# ESC / Backspace tetap bisa kembali walau P1 memakai controller
		if action == &"back" and UIInput.is_generic(source) and not countdown_on:
			_on_back()
		return
	match action:
		&"left", &"prev":
			_move(slot, -1)
		&"right", &"next":
			_move(slot, 1)
		&"fire", &"accept":
			_confirm(slot)
		&"back":
			_back(slot)
		&"extra":
			_shuffle()
	_update_prompts()


## Geser kartu pemain ke jalur terdekat (arah dir) yang masih punya slot.
func _move(slot: int, dir: int) -> void:
	if countdown_on:
		return
	if ready_flags[slot]:
		tokens[slot].deny_fx()          # sedang READY: batalkan dulu kalau mau pindah
		Global.play_sfx("ui_error", -14.0)
		return
	var cap: int = Global.team_cap()
	var cur: int = Global.team_of[slot]
	var nl: int = cur + dir
	while nl >= 0 and nl < LANES:
		if Global.team_size(nl) < cap:
			_assign(slot, nl)
			return
		nl += dir
	# tidak ada jalur kosong ke arah itu
	var edge: bool = (cur == 0 and dir < 0) or (cur == LANES - 1 and dir > 0)
	if not edge:
		_deny(slot, "TEAM FULL", "Max %d players per team" % cap)
	else:
		tokens[slot].deny_fx()
		Global.play_sfx("ui_error", -16.0)


func _assign(slot: int, lane: int) -> void:
	if Global.team_of[slot] == lane:
		return
	Global.team_of[slot] = lane
	_relayout()
	tokens[slot].move_fx()
	var cnt: int = Global.team_size(lane)
	Global.play_sfx("ui_marimba", -9.0, 1.0 + 0.08 * float(cnt - 1))
	UIInput.rumble(Global.device_of(slot), 0.15, 0.3, 0.1)
	UIKit.burst(self, tokens[slot].target + Vector2(TOKEN_W * 0.5, TOKEN_H * 0.5), Global.team_color(lane), 14, 260.0, 6.0, 0.5, 300.0)


func _deny(slot: int, title_text: String, sub: String) -> void:
	tokens[slot].deny_fx()
	Global.play_sfx("ui_error", -8.0)
	UIInput.rumble(Global.device_of(slot), 0.5, 0.0, 0.12)
	UIInput.toast(title_text, sub, Color("ff7a7a"))


func _confirm(slot: int) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_confirm[slot] < 150:
		return          # tombol tembak keyboard memancarkan "accept" + "fire" sekaligus
	_last_confirm[slot] = now
	if countdown_on:
		if now >= _cd_guard:
			_proceed()
		return
	_set_ready(slot, not ready_flags[slot])


func _set_ready(slot: int, on: bool) -> void:
	ready_flags[slot] = on
	tokens[slot].ready_fx(on)
	if on:
		Global.play_sfx("ui_ready", -5.0)
		UIInput.rumble(Global.device_of(slot), 0.0, 0.5, 0.15)
		UIKit.burst(self, tokens[slot].position + Vector2(TOKEN_W * 0.5, TOKEN_H * 0.5), Global.PLAYER_COLORS[slot].lightened(0.3), 18, 300.0, 7.0, 0.55, 400.0)
	else:
		Global.play_sfx("ui_back", -9.0)
	_check_countdown()


func _back(slot: int) -> void:
	if countdown_on:
		_set_ready(slot, false)
		return
	if ready_flags[slot]:
		_set_ready(slot, false)
	elif slot == 0:
		_on_back()


## Acak pembagian tim (selalu sah: tidak melebihi batas anggota).
func _shuffle() -> void:
	if leaving:
		return
	for i in n:
		if ready_flags[i]:
			ready_flags[i] = false
			tokens[i].ready_fx(false)
	_check_countdown()
	var cap: int = Global.team_cap()
	var order: Array = []
	for i in n:
		order.append(i)
	order.shuffle()
	var counts: Array[int] = [0, 0, 0, 0]
	for i in order:
		var open: Array[int] = []
		for l in LANES:
			if counts[l] < cap:
				open.append(l)
		var pick: int = open[randi() % open.size()]
		counts[pick] += 1
		Global.team_of[int(i)] = pick
	_relayout()
	for i in n:
		tokens[i].move_fx()
	for l in lanes:
		l.pulse()
	Global.play_sfx("swap_shuffle", -5.0)


func _check_countdown() -> void:
	var all_ready := true
	for i in n:
		if not ready_flags[i]:
			all_ready = false
	if all_ready and not countdown_on:
		countdown_on = true
		cd_time = COUNTDOWN_FROM
		_cd_guard = Time.get_ticks_msec() + 450
		summary.start_count()
		summary.set_count(int(ceil(cd_time)))
		Global.play_sfx("ui_allready", -4.0)
		for i in n:
			UIInput.rumble(Global.device_of(i), 0.2, 0.4, 0.2)
		for l in lanes:
			l.pulse()
	elif not all_ready and countdown_on:
		countdown_on = false
		summary.stop_count()
	_update_prompts()


func _process(delta: float) -> void:
	if countdown_on and not leaving:
		cd_time -= delta
		var v: int = int(ceil(cd_time))
		if v != summary.cd_value and v > 0:
			summary.set_count(v)
			Global.play_sfx("count_beep", -8.0)
		if cd_time <= 0.0:
			_proceed()


# ------------------------------------------------------------------ mouse
func _on_token_clicked(slot: int) -> void:
	if leaving:
		return
	if mouse_slot == slot:
		_confirm(slot)
	else:
		tokens[mouse_slot].selected = false
		mouse_slot = slot
		tokens[slot].selected = true
		Global.play_sfx("ui_hover", -9.0)
	_update_prompts()


func _on_lane_clicked(lane: int) -> void:
	if leaving or countdown_on:
		return
	var slot: int = mouse_slot
	if ready_flags[slot]:
		tokens[slot].deny_fx()
		Global.play_sfx("ui_error", -14.0)
		return
	if Global.team_of[slot] == lane:
		return
	var cap: int = Global.team_cap()
	if Global.team_size(lane) >= cap:
		_deny(slot, "TEAM FULL", "Max %d players per team" % cap)
		return
	_assign(slot, lane)


# ------------------------------------------------------------------ prompt & navigasi
func _update_prompts() -> void:
	if prompt == null:
		return
	if countdown_on:
		prompt.set_prompts([[&"none", "CONFIRM = SKIP"], [&"back", "CANCEL"]])
	else:
		prompt.set_prompts([
			[&"dpad_lr", "CHANGE TEAM"], [&"none", "SHOOT / ACCEPT = READY"],
			[&"extra", "SHUFFLE"], [&"back", "BACK"],
		])


func _on_back() -> void:
	if leaving:
		return
	leaving = true
	Global.play_music("menu")
	Global.goto("select")


func _proceed() -> void:
	if leaving:
		return
	leaving = true
	Global.sanitize_teams()
	Global.play_sfx("count_go", -6.0)
	for i in n:
		UIInput.rumble(Global.device_of(i), 0.4, 0.8, 0.3)
		UIKit.burst(self, tokens[i].position + Vector2(TOKEN_W * 0.5, TOKEN_H * 0.5), Global.team_color(int(Global.team_of[i])).lightened(0.2), 30, 380.0, 8.0)
	for l in lanes:
		l.pulse()
	await get_tree().create_timer(0.35).timeout
	Global.goto("battle")
