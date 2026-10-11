extends Control
## Layar "CHOOSE YOUR FIGHTER" bergaya game fighting PlayStation.
##  - Grid roster di tengah berisi SEMUA karakter (bisa dipakai pemain mana saja).
##  - Tiap pemain punya KURSOR sendiri (warna pemain) + panel potret besar di kiri / kanan.
##  - Karakter yang sudah DIKUNCI satu pemain tidak bisa dikunci pemain lain (kotaknya diredupkan + lencana pemilik).
##  - Alur tiap pemain: pilih fighter -> kunci (tombol tembak / accept) -> pilih senjata -> READY.
##  - Semua READY -> hitung mundur 3-2-1 -> (3-4 pemain: layar TEAM) -> layar BATTLE SETTINGS (map, waktu, power up, dll).
##  - Boleh dipakai bersamaan oleh semua controller / keyboard layout yang terhubung.

const CHAR_COUNT := 24                 # jumlah karakter di roster (harus sama dengan Global.CHARACTERS.size())
const RANDOM_CELL := 24                # sel RANDOM = tepat setelah karakter terakhir
const CELLS := 25
const PANEL_TOP := 96.0
const PANEL_BOTTOM := 628.0
const PANEL_W := 384.0
const COUNTDOWN_FROM := 3.0

var n: int = 2
var st: SelState
var panels: Array[FighterPanel] = []
var roster: RosterGrid
var cdbox: CountdownBox
var title: TitleBar
var bg: UIKit.FxBackground
var prompt: UIKit.PromptBar
var status: UIKit.PadStatus
var back_btn: UIKit.FancyButton

var leaving := false
var countdown_on := false
var cd_time: float = 0.0
var _cd_guard: int = 0
var _last_confirm: Array[int] = [0, 0, 0, 0]


# ================================================================== state bersama
class SelState extends RefCounted:
	var n: int = 2
	var cursor: Array[int] = [0, 0, 0, 0]            # 0..23 karakter, 24 = RANDOM (awal: tiap pemain di POJOK, lihat _init)
	var stage: Array[int] = [0, 0, 0, 0]             # 0 = pilih fighter, 1 = pilih senjata, 2 = READY
	var weapon: Array[int] = [0, 0, 0, 0]            # indeks Global.WEAPON_ORDER
	var locked: Array[int] = [-1, -1, -1, -1]        # karakter yang sudah dikunci (-1 = belum)
	var rolling: Array[bool] = [false, false, false, false]
	# ---- skin (Shop/Inventory): sk 0 = biasa, 1 = sedang memilih SKIN KARAKTER, 2 = sedang memilih SKIN SENJATA
	var sk: Array[int] = [0, 0, 0, 0]
	var cskin: Array[String] = ["", "", "", ""]
	var wskin: Array[String] = ["", "", "", ""]

	func _init(count: int = 2) -> void:
		n = count
		# Posisi awal kursor = pojok grid sesuai nomor pemain (tetap di pojok walau jumlah karakter bertambah):
		# P1 kiri-atas, P2 kanan-atas, P3 kiri-bawah, P4 kanan-bawah.
		var last_col: int = RosterGrid.COLS - 1
		var last_row: int = RosterGrid.ROWS - 1
		cursor = [
			RosterGrid.cell_at(0, 0), RosterGrid.cell_at(last_col, 0),
			RosterGrid.cell_at(0, last_row), RosterGrid.cell_at(last_col, last_row),
		]

	## Pemain yang sudah mengunci karakter ini (selain `except`); -1 kalau bebas.
	func owner_of(ch: int, except: int = -1) -> int:
		for i in n:
			if i != except and locked[i] == ch:
				return i
		return -1

	func all_ready() -> bool:
		for i in n:
			if stage[i] < 2:
				return false
		return true

	func ready_count() -> int:
		var c := 0
		for i in n:
			if stage[i] >= 2:
				c += 1
		return c


# ================================================================== judul
class TitleBar extends Control:
	var t: float = 0.0
	var text: String = "CHOOSE YOUR FIGHTER"

	func _init() -> void:
		size = Vector2(1280, 84)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var cx: float = size.x * 0.5
		var cy: float = 44.0
		# bar tipis berpendar di kiri & kanan
		var bar_c := Color(0.3, 0.8, 1.0)
		for side in [-1, 1]:
			var x0: float = cx + side * 330.0
			var x1: float = cx + side * 640.0
			draw_line(Vector2(x0, cy + 22), Vector2(x1, cy + 22), Color(bar_c, 0.55), 3.0, true)
			draw_line(Vector2(x0, cy + 28), Vector2(x1, cy + 28), Color(bar_c, 0.2), 2.0, true)
			var sx: float = lerpf(x0, x1, fmod(t * 0.55 + (0.5 if side > 0 else 0.0), 1.0))
			draw_rect(Rect2(sx - 30, cy + 20, 60, 4), Color(1, 1, 1, 0.8))
		# kilau bintang di belakang teks
		for k in 10:
			var a: float = t * 0.25 + k * TAU / 10.0
			var a2: float = a + 0.09
			var rr: float = 230.0 + 40.0 * sin(t * 1.3 + k)
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx, cy), Vector2(cx, cy) + Vector2(cos(a) * rr, sin(a) * rr * 0.16),
				Vector2(cx, cy) + Vector2(cos(a2) * rr, sin(a2) * rr * 0.16),
			]), Color(0.7, 0.9, 1.0, 0.07))
		var fs := 54
		var tw: float = UIKit.text_w(text, fs)
		var r := Rect2(cx - tw * 0.5, 0, tw, size.y - 6)
		UIKit.text_in(self, text, Rect2(r.position + Vector2(3, 5), r.size), fs, Color(0, 0, 0, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
		UIKit.text_in(self, text, r, fs, Color(0.75, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 10, Color(0.02, 0.1, 0.2))
		# kilap lewat
		var sweep: float = fmod(t * 0.45, 2.2) - 0.6
		var gx: float = r.position.x + sweep * tw
		draw_colored_polygon(PackedVector2Array([
			Vector2(gx, 10), Vector2(gx + 36, 10), Vector2(gx + 16, 66), Vector2(gx - 20, 66),
		]), Color(1, 1, 1, 0.16))


# ================================================================== grid roster
class RosterGrid extends Control:
	signal cell_clicked(cell: int)

	## Susunan grid: 16 karakter pertama = blok 4x4 di kiri (kolom 0-3),
	## 8 karakter baru (indeks 16-23) = blok 2x4 di kanan (kolom 4-5).
	const COLS := 6
	const ROWS := 4
	const CELL := 68.0
	const GAP := 6.0
	const PAD := 12.0
	const RAND_H := 38.0

	static func cell_col(i: int) -> int:
		return i % 4 if i < 16 else 4 + (i - 16) % 2

	static func cell_row(i: int) -> int:
		return i / 4 if i < 16 else (i - 16) / 2

	static func cell_at(col: int, row: int) -> int:
		return row * 4 + col if col < 4 else 16 + row * 2 + (col - 4)

	var st: SelState
	var t: float = 0.0
	var crect: Array[Rect2] = [Rect2(), Rect2(), Rect2(), Rect2()]
	var bump: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var _init_done := false

	func _init(s: SelState = null) -> void:
		st = s
		var gw: float = COLS * CELL + (COLS - 1) * GAP
		size = Vector2(gw + PAD * 2.0, PAD * 2.0 + ROWS * CELL + (ROWS - 1) * GAP + GAP + RAND_H)
		custom_minimum_size = size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP

	func cell_rect(i: int) -> Rect2:
		if i == RANDOM_CELL:
			var gw: float = COLS * CELL + (COLS - 1) * GAP
			return Rect2(PAD, PAD + ROWS * (CELL + GAP), gw, RAND_H)
		return Rect2(PAD + cell_col(i) * (CELL + GAP), PAD + cell_row(i) * (CELL + GAP), CELL, CELL)

	func punch(slot: int) -> void:
		bump[slot] = 1.0

	func _process(d: float) -> void:
		t += d
		for i in st.n:
			var target: Rect2 = cell_rect(st.cursor[i])
			if not _init_done:
				crect[i] = target
			else:
				var k: float = 1.0 - exp(-d * 20.0)
				crect[i] = Rect2(crect[i].position.lerp(target.position, k), crect[i].size.lerp(target.size, k))
			bump[i] = maxf(bump[i] - d * 4.5, 0.0)
		_init_done = true
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for i in CELLS:
				if cell_rect(i).has_point(event.position):
					cell_clicked.emit(i)
					return

	func _draw() -> void:
		# ----- bingkai
		var body := Rect2(Vector2.ZERO, size)
		draw_rect(Rect2(body.position + Vector2(6, 8), body.size), Color(0, 0, 0, 0.45))
		draw_rect(body, Color(0.03, 0.05, 0.11, 0.88))
		draw_rect(Rect2(0, 0, size.x, 36), Color(0.3, 0.7, 1.0, 0.07))
		draw_rect(body, Color(1, 1, 1, 0.5), false, 2.0)
		for corner in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), Vector2(size.x, size.y)]:
			var sx: float = -1.0 if corner.x > 0 else 1.0
			var sy: float = -1.0 if corner.y > 0 else 1.0
			draw_line(corner + Vector2(-sx * 3, -sy * 3), corner + Vector2(sx * 22, -sy * 3), UIKit.GOLD, 4.0)
			draw_line(corner + Vector2(-sx * 3, -sy * 3), corner + Vector2(-sx * 3, sy * 22), UIKit.GOLD, 4.0)

		# ----- sel karakter
		for i in CHAR_COUNT:
			var r: Rect2 = cell_rect(i)
			var owner: int = st.owner_of(i)
			draw_rect(r, Color(0.08, 0.09, 0.16))
			var tex: Texture2D = Global.character_texture(0, i)
			var ins := r.grow(-2.0)
			draw_texture_rect(tex, ins, false, Color.WHITE if owner < 0 else Color(0.5, 0.5, 0.55))
			if owner >= 0:
				var oc: Color = Global.PLAYER_COLORS[owner]
				draw_rect(r, Color(oc.r, oc.g, oc.b, 0.22))
				draw_rect(r, Color(0, 0, 0, 0.35))
				draw_rect(r, oc, false, 3.0)
				var bw := 34.0
				var br := Rect2(r.end.x - bw - 3, r.end.y - 20, bw, 17)
				draw_colored_polygon(UIKit.slanted(br.size.x, br.size.y, 6, br.position.x, br.position.y), oc.darkened(0.15))
				UIKit.text_in(self, "P%d" % (owner + 1), br, 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 3)
			else:
				draw_rect(r, Color(1, 1, 1, 0.28), false, 2.0)

		# ----- sel RANDOM
		var rr: Rect2 = cell_rect(RANDOM_CELL)
		draw_rect(rr, Color(0.1, 0.09, 0.2))
		draw_rect(Rect2(rr.position, Vector2(rr.size.x, rr.size.y * 0.5)), Color(1, 1, 1, 0.05))
		draw_rect(rr, Color(1, 1, 1, 0.28), false, 2.0)
		var qy: float = sin(t * 3.0) * 2.0
		UIKit.text_in(self, "?", Rect2(rr.position.x + 20, rr.position.y + qy, 40, rr.size.y), 40, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 6)
		UIKit.text_in(self, "RANDOM", Rect2(rr.position.x + 66, rr.position.y, rr.size.x - 132, rr.size.y), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6)
		UIKit.text_in(self, "?", Rect2(rr.end.x - 60, rr.position.y + qy, 40, rr.size.y), 40, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 6)

		# ----- kursor tiap pemain
		var pulse: float = 0.5 + 0.5 * sin(t * 8.0)
		for i in st.n:
			var col: Color = Global.PLAYER_COLORS[i]
			var locked: bool = st.stage[i] >= 1
			var cr: Rect2 = crect[i].grow(2.0 + bump[i] * 5.0)
			# cahaya luar
			draw_rect(cr.grow(5.0 + pulse * 2.0), Color(col.r, col.g, col.b, 0.22 + 0.1 * pulse), false, 4.0)
			if locked:
				draw_rect(cr, Color(col.r, col.g, col.b, 0.3))
			draw_rect(cr, col, false, 4.0 if locked else 3.0)
			# siku sudut
			var bl: float = 14.0
			for corner2 in [cr.position, Vector2(cr.end.x, cr.position.y), Vector2(cr.position.x, cr.end.y), cr.end]:
				var sx2: float = -1.0 if corner2.x == cr.end.x else 1.0
				var sy2: float = -1.0 if corner2.y == cr.end.y else 1.0
				draw_line(corner2, corner2 + Vector2(sx2 * bl, 0), Color.WHITE, 4.0)
				draw_line(corner2, corner2 + Vector2(0, sy2 * bl), Color.WHITE, 4.0)
			# tag pemain di sudut masing-masing
			var tw := 36.0
			var th := 18.0
			var tp := Vector2.ZERO
			match i:
				0: tp = Vector2(cr.position.x - 4, cr.position.y - th - 2)
				1: tp = Vector2(cr.end.x - tw + 4, cr.position.y - th - 2)
				2: tp = Vector2(cr.position.x - 4, cr.end.y + 2)
				_: tp = Vector2(cr.end.x - tw + 4, cr.end.y + 2)
			var tpts := UIKit.slanted(tw, th, 7, tp.x, tp.y)
			draw_colored_polygon(tpts, col)
			draw_polyline(UIKit.closed(tpts), Color.WHITE, 1.5, true)
			UIKit.text_in(self, "P%d" % (i + 1), Rect2(tp, Vector2(tw, th)), 15, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 3)
			if locked:
				UIKit.draw_lock(self, cr.get_center(), 22.0, Color(1, 1, 1, 0.95))


# ================================================================== panel pemain
class FighterPanel extends Control:
	signal clicked(panel: FighterPanel, zone: String, dir: int)

	var idx: int = 0
	var st: SelState
	var color: Color = Color.WHITE
	var compact: bool = false
	var left_side: bool = true
	var device_text: String = "KEYBOARD"
	var device_pad: bool = false

	var t: float = 0.0
	var shown: int = -99
	var slide: float = 0.0
	var pop: float = 1.0
	var flash: float = 0.0
	var shake: float = 0.0
	var wpop: float = 1.0
	var nudge: float = 0.0
	var hop: float = 0.0
	var stamp: float = 1.0
	var ready_t: float = 0.0
	var lock_t: float = 0.0
	var _prev_ready := false
	var _hit := {}

	func _init(i: int = 0, s: SelState = null, sz: Vector2 = Vector2(396, 532), is_compact: bool = false, is_left: bool = true) -> void:
		idx = i
		st = s
		color = Global.PLAYER_COLORS[i]
		size = sz
		custom_minimum_size = sz
		compact = is_compact
		left_side = is_left
		pivot_offset = sz * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP

	# ---- efek
	func shown_char() -> int:
		return st.locked[idx] if st.stage[idx] >= 1 else st.cursor[idx]

	func _process(d: float) -> void:
		t += d
		var c: int = shown_char()
		if c != shown:
			var dir: int = 1 if c > shown else -1
			if shown == -99:
				dir = 0
			shown = c
			if dir != 0:
				slide = float(dir)
				pop = 0.82
				flash = 0.7
				var tw := UIKit.tw(self)
				tw.set_parallel(true)
				tw.tween_property(self, "slide", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(self, "pop", 1.0, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(self, "flash", 0.0, 0.25)
		queue_redraw()

	func lock_fx() -> void:
		Global.play_sfx("pu_ammo_refill", -8.0)
		Global.play_sfx("ui_ready", -7.0)
		UIInput.rumble(Global.device_of(idx), 0.2, 0.4, 0.15)
		flash = 1.0
		lock_t = 1.0
		var tw := UIKit.tw(self)
		tw.set_parallel(true)
		tw.tween_property(self, "flash", 0.0, 0.35)
		tw.tween_property(self, "lock_t", 0.0, 0.7)
		var cen := position + _portrait_rect().get_center()
		UIKit.burst(get_parent(), cen, color.lightened(0.3), 20, 280.0, 6.0)
		UIKit.ring(get_parent(), cen, color, 130.0, 0.45)

	func weapon_fx(dir: int) -> void:
		wpop = 0.6
		nudge = float(dir)
		var tw := UIKit.tw(self)
		tw.set_parallel(true)
		tw.tween_property(self, "wpop", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "nudge", 0.0, 0.22)
		Global.play_sfx("ui_marimba", -9.0, 1.0 + 0.06 * float(dir))

	func deny() -> void:
		Global.play_sfx("ui_error", -8.0)
		UIInput.rumble(Global.device_of(idx), 0.5, 0.0, 0.12)
		var tw := UIKit.tw(self)
		for k in [14.0, -12.0, 8.0, -5.0, 0.0]:
			tw.tween_property(self, "shake", k, 0.045)

	func ready_fx(v: bool) -> void:
		var tw := UIKit.tw(self)
		tw.set_parallel(true)
		tw.tween_property(self, "ready_t", 1.0 if v else 0.0, 0.25)
		if v:
			Global.play_sfx("ui_ready", -3.0)
			UIInput.rumble(Global.device_of(idx), 0.0, 0.5, 0.18)
			stamp = 2.4
			tw.tween_property(self, "stamp", 1.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			hop = 1.0
			tw.tween_property(self, "hop", 0.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			var cen := position + _portrait_rect().get_center()
			UIKit.burst(get_parent(), cen, UIKit.GREEN, 28, 320.0, 7.0)
			UIKit.ring(get_parent(), cen, UIKit.GREEN, 170.0, 0.5)
		else:
			Global.play_sfx("ui_back", -7.0)

	# ---- layout
	func _header_rect() -> Rect2:
		return Rect2(0, 0, size.x, 44.0 if not compact else 40.0)

	func _portrait_rect() -> Rect2:
		if compact:
			return Rect2(16, 48, 150, 150)
		var ps: float = 306.0
		return Rect2((size.x - ps) * 0.5, 54, ps, ps)

	func _name_rect() -> Rect2:
		if compact:
			return Rect2(10, size.y - 58, size.x - 20, 48)
		return Rect2(10, 370, size.x - 20, 58)

	func _plate_rect() -> Rect2:
		if compact:
			return Rect2(182, 48, size.x - 182 - 14, 150)
		return Rect2(24, 440, size.x - 48, 78)

	# ---- mouse
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for zone in _hit:
				var r: Rect2 = _hit[zone]["rect"]
				if r.has_point(event.position):
					clicked.emit(self, zone, int(_hit[zone]["dir"]))
					return

	# ---- gambar
	func _fit(tex: Texture2D, box: Rect2) -> Rect2:
		var ts: Vector2 = tex.get_size()
		var sc: float = minf(box.size.x / ts.x, box.size.y / ts.y)
		var sz: Vector2 = ts * sc
		return Rect2(box.position + (box.size - sz) * 0.5, sz)

	func _fit_font(s: String, max_w: float, start: int) -> int:
		var fs := start
		while fs > 16 and UIKit.text_w(s, fs) > max_w:
			fs -= 2
		return fs

	func _draw() -> void:
		_hit.clear()
		var w: float = size.x
		var h: float = size.y
		var stage: int = st.stage[idx]
		var focus: float = 0.5 + 0.5 * sin(t * 5.0)
		var sk := 22.0
		draw_set_transform(Vector2(shake, 0))

		# ----- badan panel
		draw_colored_polygon(UIKit.slanted(w, h, sk, 8, 10), Color(0, 0, 0, 0.5))
		var body := UIKit.slanted(w, h, sk)
		var top_c: Color = Color(0.1, 0.12, 0.24, 0.94).lerp(color.darkened(0.6), 0.45).lerp(Color(0.05, 0.22, 0.14, 0.95), ready_t * 0.7)
		var bot_c: Color = Color(0.03, 0.04, 0.09, 0.95).lerp(Color(0.02, 0.1, 0.07, 0.95), ready_t)
		draw_polygon(body, PackedColorArray([top_c, top_c, bot_c, bot_c]))
		var edge: Color = color.lerp(UIKit.GREEN, ready_t)
		draw_polyline(UIKit.closed(body), edge, 4.0 + ready_t * 2.0, true)

		# ----- header
		var hr := _header_rect()
		var hp := UIKit.slanted(104, hr.size.y - 8, 12, 20, 4)
		draw_colored_polygon(hp, color)
		draw_polyline(UIKit.closed(hp), Color.BLACK, 3.0, true)
		UIKit.text_in(self, "P%d" % (idx + 1), Rect2(20, 4, 104, hr.size.y - 8), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6)
		var stext := "SELECT FIGHTER"
		var scol: Color = Color(1, 1, 1, 0.55 + 0.45 * focus)
		if stage == 1:
			stext = "SELECT WEAPON"
			if st.sk[idx] == 1:
				stext = "SELECT SKIN"
			elif st.sk[idx] == 2:
				stext = "GUN SKIN"
		elif stage >= 2:
			stext = "READY!"
			scol = UIKit.GREEN
		if st.rolling[idx]:
			stext = "RANDOM..."
			scol = UIKit.GOLD
		var dw: float = UIKit.text_w(device_text, 18)
		var sx0: float = 136.0
		UIKit.text_in(self, stext, Rect2(sx0, 2, w - sx0 - dw - 60.0, hr.size.y), 22 if compact else 26, scol, HORIZONTAL_ALIGNMENT_LEFT, 5)
		UIKit.text_in(self, device_text, Rect2(w - 24 - dw - 4, 2, dw + 4, hr.size.y), 18, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_RIGHT)
		var ic := Vector2(w - 24 - dw - 26, hr.size.y * 0.5 + 1)
		if device_pad:
			UIKit.draw_pad_icon(self, ic, 26.0, color.lightened(0.2))
		else:
			UIKit.draw_keys_icon(self, ic, 26.0, color.lightened(0.2))

		# ----- potret
		var pr := _portrait_rect()
		var ch: int = shown_char()
		var is_rand: bool = ch == RANDOM_CELL
		var owner: int = -1 if is_rand else st.owner_of(ch, idx)
		var taken: bool = owner >= 0 and stage == 0
		var bpts := UIKit.slanted(pr.size.x, pr.size.y, 16, pr.position.x, pr.position.y)
		var lc: Color = color.lightened(0.2).lerp(Color(0.3, 0.8, 0.5), ready_t * 0.5)
		var dc: Color = color.darkened(0.65)
		if taken:
			lc = Color(0.35, 0.1, 0.1)
			dc = Color(0.1, 0.02, 0.02)
		draw_polygon(bpts, PackedColorArray([lc, lc, dc, dc]))
		var cen := pr.get_center()
		for k in 14:
			var a0: float = t * 0.35 + k * TAU / 14.0
			var a1: float = a0 + 0.12
			var rad: float = pr.size.x * 0.56
			draw_colored_polygon(PackedVector2Array([cen, cen + Vector2(cos(a0), sin(a0)) * rad, cen + Vector2(cos(a1), sin(a1)) * rad]), Color(1, 1, 1, 0.08 + ready_t * 0.05))
		draw_polyline(UIKit.closed(bpts), Color(1, 1, 1, 0.6), 2.0, true)

		var ps: float = pr.size.x * 0.82
		var bob: float = sin(t * 2.6) * 4.0
		var jump: float = -absf(hop) * 30.0
		var sp := cen + Vector2(slide * pr.size.x * 0.24, bob + jump + 4.0)
		var sq: float = 1.0 + sin(t * 2.6) * 0.012
		draw_set_transform(Vector2(shake, 0) + sp, 0.0, Vector2(pop * sq, pop / sq))
		var al: float = 1.0 - absf(slide) * 0.7
		if is_rand:
			draw_rect(Rect2(-ps * 0.5, -ps * 0.5, ps, ps), Color(0.08, 0.06, 0.18, 0.9 * al))
			draw_rect(Rect2(-ps * 0.5, -ps * 0.5, ps, ps), Color(1, 1, 1, 0.5 * al), false, 3.0)
			UIKit.text_in(self, "?", Rect2(-ps * 0.5, -ps * 0.5 + sin(t * 4.0) * 4.0, ps, ps), int(ps * 0.8), UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 12)
		else:
			var show_cos: bool = stage >= 1 and st.locked[idx] == ch
			var tex: Texture2D = Cosmetics.char_tex(ch, st.cskin[idx] if show_cos else "")
			draw_rect(Rect2(-ps * 0.5 - 4, -ps * 0.5 - 4, ps + 8, ps + 8), Color(0, 0, 0, 0.75 * al))
			var tint: Color = Color(1, 1, 1, al) if not taken else Color(0.45, 0.35, 0.35, al)
			var plo: Dictionary = Cosmetics.loadout(ch, st.cskin[idx]) if show_cos else {}
			Cosmetics.draw_accessories(self, ch, plo, Rect2(-ps * 0.5, -ps * 0.5, ps, ps), tint, 0)
			draw_texture_rect(tex, Rect2(-ps * 0.5, -ps * 0.5, ps, ps), false, tint)
			Cosmetics.draw_accessories(self, ch, plo, Rect2(-ps * 0.5, -ps * 0.5, ps, ps), tint, 1)
			if flash > 0.0:
				draw_rect(Rect2(-ps * 0.5, -ps * 0.5, ps, ps), Color(1, 1, 1, 0.85 * flash))
			if lock_t > 0.0:
				draw_rect(Rect2(-ps * 0.5 - 6, -ps * 0.5 - 6, ps + 12, ps + 12), Color(color.lightened(0.4), lock_t), false, 6.0)
		draw_set_transform(Vector2(shake, 0))

		# TAKEN
		if taken:
			var oc: Color = Global.PLAYER_COLORS[owner]
			draw_set_transform(Vector2(shake, 0) + cen, deg_to_rad(-10.0), Vector2.ONE)
			var tr := Rect2(-pr.size.x * 0.42, -26, pr.size.x * 0.84, 52)
			draw_rect(tr, Color(0.05, 0.0, 0.0, 0.85))
			draw_rect(tr, oc, false, 4.0)
			UIKit.text_in(self, "TAKEN BY P%d" % (owner + 1), tr, _fit_font("TAKEN BY P%d" % (owner + 1), tr.size.x - 14.0, 30 if not compact else 22), Color(1, 0.45, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 6)
			draw_set_transform(Vector2(shake, 0))

		# READY stamp
		if stage >= 2:
			draw_set_transform(Vector2(shake, 0) + cen, deg_to_rad(-8.0), Vector2.ONE * stamp)
			var sr := Rect2(-pr.size.x * 0.4, -24 if compact else -28, pr.size.x * 0.8, 48 if compact else 56)
			draw_rect(sr, Color(0.0, 0.12, 0.06, 0.88))
			draw_rect(sr, UIKit.GREEN, false, 4.0)
			UIKit.text_in(self, "READY!", sr, _fit_font("READY!", sr.size.x - 16.0, 42 if not compact else 30), UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER, 8)
			draw_set_transform(Vector2(shake, 0))

		# panah ganti karakter (hint saat tahap 0)
		if stage == 0:
			var cc: Color = Color(UIKit.GOLD, 0.7 + 0.3 * focus)
			var cyy: float = pr.get_center().y
			UIKit.draw_chevron(self, Vector2(pr.position.x - 4, cyy), 9.0, -1, cc)
			UIKit.draw_chevron(self, Vector2(pr.end.x + 4, cyy), 9.0, 1, cc)

		# ----- nama (banner miring ala game fighting)
		var nr := _name_rect()
		var npts := UIKit.slanted(nr.size.x, nr.size.y, 22, nr.position.x, nr.position.y)
		var n0: Color = color.darkened(0.25)
		var n1: Color = color.darkened(0.7)
		if taken:
			n0 = Color(0.45, 0.08, 0.08)
			n1 = Color(0.15, 0.02, 0.02)
		draw_polygon(npts, PackedColorArray([n0, n0, n1, n1]))
		draw_colored_polygon(UIKit.slanted(nr.size.x, 6, 22, nr.position.x, nr.position.y), Color(1, 1, 1, 0.18))
		draw_polyline(UIKit.closed(npts), Color(1, 1, 1, 0.85), 3.0, true)
		var nm: String = "RANDOM" if is_rand else Global.character_name(0, ch)
		var nfs: int = _fit_font(nm, nr.size.x - 70.0, 46 if not compact else 38)
		var nxo: float = slide * 26.0
		UIKit.text_in(self, nm, Rect2(nr.position.x + nxo, nr.position.y, nr.size.x, nr.size.y), nfs, Color(1, 1, 1, al), HORIZONTAL_ALIGNMENT_CENTER, 9)

		# ----- senjata
		if stage == 1 and st.sk[idx] == 1:
			_draw_skin_plate(_plate_rect())
		else:
			_draw_weapon_plate(_plate_rect(), stage)

		# ----- selimut redup kalau panel READY
		draw_set_transform(Vector2.ZERO)

	## Panel pemilih SKIN KARAKTER (muncul di tempat panel senjata, tepat setelah karakter dikunci).
	func _draw_skin_plate(pl: Rect2) -> void:
		var focus: float = 0.5 + 0.5 * sin(t * 5.0)
		var ppts := UIKit.slanted(pl.size.x, pl.size.y, 10, pl.position.x, pl.position.y)
		draw_colored_polygon(ppts, Color(0, 0, 0, 0.5))
		draw_polyline(UIKit.closed(ppts), UIKit.GOLD, 3.0, true)
		var ch: int = st.locked[idx]
		var opts: Array = ["" ] + Cosmetics.owned_skin_ids(ch)
		var cur: String = st.cskin[idx]
		var wc: Color = Color(UIKit.GOLD, 1.0)
		var wpul: float = 1.0 + focus * 0.25
		var cy: float = pl.position.y + pl.size.y * 0.5
		UIKit.draw_chevron(self, Vector2(pl.position.x + 20 - maxf(-nudge, 0) * 4.0, cy), 9.0 * wpul, -1, wc)
		UIKit.draw_chevron(self, Vector2(pl.end.x - 20 + maxf(nudge, 0) * 4.0, cy), 9.0 * wpul, 1, wc)
		_hit["wp_l"] = {"rect": Rect2(pl.position.x, pl.position.y, pl.size.x * 0.22, pl.size.y), "dir": -1}
		_hit["wp_r"] = {"rect": Rect2(pl.end.x - pl.size.x * 0.22, pl.position.y, pl.size.x * 0.22, pl.size.y), "dir": 1}
		var nm: String = "DEFAULT"
		var rc: Color = Color(1, 1, 1, 0.7)
		var rn: String = "ORIGINAL"
		if cur != "":
			var info: Array = Cosmetics.char_skin_info(cur)
			nm = String(info[1])
			rc = Cosmetics.rarity_color(String(info[2]))
			rn = String(Cosmetics.RARITY_NAMES[String(info[2])])
		UIKit.text_in(self, "CHARACTER SKIN", Rect2(pl.position.x, pl.position.y + 6, pl.size.x, 18), 14, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_CENTER, 3)
		var nr := Rect2(pl.position.x + 28, pl.position.y + pl.size.y * 0.5 - 30, pl.size.x - 56, 40)
		UIKit.text_in(self, nm, nr, _fit_font(nm, nr.size.x, 32), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 7)
		UIKit.text_in(self, rn, Rect2(pl.position.x, nr.end.y - 8, pl.size.x, 20), 15, rc, HORIZONTAL_ALIGNMENT_CENTER, 4)
		# titik indikator
		var idxo: int = maxi(opts.find(cur), 0)
		var dots: int = opts.size()
		var dw: float = minf(18.0, (pl.size.x - 80.0) / float(maxi(dots, 1)))
		var dx0: float = pl.position.x + pl.size.x * 0.5 - dw * float(dots - 1) * 0.5
		for k in dots:
			var dc: Color = Color(UIKit.GOLD, 1.0) if k == idxo else Color(1, 1, 1, 0.25)
			draw_circle(Vector2(dx0 + dw * float(k), pl.end.y - 8), 3.5 if k == idxo else 2.5, dc)

	func _draw_weapon_plate(pl: Rect2, stage: int) -> void:
		var active: bool = stage == 1
		var dim: float = 1.0 if stage <= 1 else 0.6
		var focus: float = 0.5 + 0.5 * sin(t * 5.0)
		var ppts := UIKit.slanted(pl.size.x, pl.size.y, 10, pl.position.x, pl.position.y)
		draw_colored_polygon(ppts, Color(0, 0, 0, 0.5))
		draw_polyline(UIKit.closed(ppts), UIKit.GOLD if active else Color(1, 1, 1, 0.16), 3.0 if active else 2.0, true)
		var wid: String = Global.WEAPON_ORDER[st.weapon[idx]]
		var wdata: Dictionary = Global.WEAPONS[wid]
		var w_ok: bool = bool(wdata["enabled"])
		var wc: Color = Color(UIKit.GOLD, 1.0) if active else Color(1, 1, 1, 0.3)
		var wpul: float = 1.0 + (focus * 0.25 if active else 0.0)
		var wide: bool = pl.size.x > pl.size.y * 2.2
		var cy: float = pl.position.y + (pl.size.y * 0.42 if not wide else pl.size.y * 0.42)
		UIKit.draw_chevron(self, Vector2(pl.position.x + 20 - maxf(-nudge, 0) * 4.0, cy), 9.0 * wpul, -1, wc)
		UIKit.draw_chevron(self, Vector2(pl.end.x - 20 + maxf(nudge, 0) * 4.0, cy), 9.0 * wpul, 1, wc)
		_hit["wp_l"] = {"rect": Rect2(pl.position.x, pl.position.y, pl.size.x * 0.22, pl.size.y), "dir": -1}
		_hit["wp_r"] = {"rect": Rect2(pl.end.x - pl.size.x * 0.22, pl.position.y, pl.size.x * 0.22, pl.size.y), "dir": 1}

		var gun_box: Rect2
		var stat_x: float = 0.0
		var stat_w: float = 0.0
		var stat_y: float = 0.0
		var name_rect: Rect2
		if wide:
			gun_box = Rect2(pl.position.x + 40, pl.position.y + 4, pl.size.x * 0.4, pl.size.y - 30)
			stat_x = gun_box.end.x + 14
			stat_w = pl.end.x - 40 - stat_x
			stat_y = pl.position.y + 7
			name_rect = Rect2(pl.position.x, pl.end.y - 27, pl.size.x, 24)
		else:
			gun_box = Rect2(pl.position.x + 34, pl.position.y + 6, pl.size.x - 68, pl.size.y * 0.36)
			stat_x = pl.position.x + 22
			stat_w = pl.size.x - 44
			stat_y = pl.position.y + pl.size.y * 0.36 + 36
			name_rect = Rect2(pl.position.x, pl.position.y + pl.size.y * 0.36 + 8, pl.size.x, 26)
		var wsk: String = st.wskin[idx] if (st.sk[idx] == 2 or stage >= 2) else ""
		var gtex: Texture2D = Cosmetics.weapon_tex(wid, wsk, idx)
		var gr: Rect2 = _fit(gtex, gun_box)
		var gc := gr.get_center()
		draw_set_transform(Vector2(shake, 0) + gc, deg_to_rad(sin(t * 2.0) * 2.0), Vector2.ONE * wpop)
		draw_texture_rect(gtex, Rect2(-gr.size * 0.5, gr.size), false, Color(1, 1, 1, dim) if w_ok else Color(0.3, 0.3, 0.34, dim))
		draw_set_transform(Vector2(shake, 0))
		if not w_ok:
			UIKit.draw_lock(self, gc, 24.0, Color(1, 1, 1, 0.9))
		var stt: Dictionary = Global.weapon_stats(wid)
		var labels := ["DMG", "RATE", "SPD"]
		var keys := ["damage", "rate", "speed"]
		var row_h: float = 16.0 if wide else 15.0
		for k in 3:
			var by: float = stat_y + k * row_h
			UIKit.text_in(self, labels[k], Rect2(stat_x, by - 3, 38, 16), 13, Color(1, 1, 1, 0.7 * dim), HORIZONTAL_ALIGNMENT_LEFT)
			var bw: float = stat_w - 40.0
			draw_rect(Rect2(stat_x + 38, by + 1, bw, 7), Color(1, 1, 1, 0.14))
			if not stt.is_empty():
				draw_rect(Rect2(stat_x + 38, by + 1, bw * float(stt[keys[k]]) * wpop, 7), Color(UIKit.GOLD, dim))
		var wname: String = wdata["name"] if w_ok else "%s  (SOON)" % wdata["name"]
		if w_ok:
			var am: int = int(wdata.get("ammo", -1))
			wname += "  -  %s" % ("UNLIMITED" if am < 0 else "%d AMMO" % am)
		var wname_col: Color = Color(1, 1, 1, dim) if w_ok else Color(1, 0.5, 0.5, dim)
		if st.sk[idx] == 2 and stage == 1:
			var winfo: Array = Cosmetics.weapon_skin_info(wid, wsk)
			wname = "%s  -  %s" % [wdata["name"], "DEFAULT SKIN" if winfo.is_empty() else String(winfo[1])]
			if not winfo.is_empty():
				wname_col = Cosmetics.rarity_color(String(winfo[2])).lerp(Color.WHITE, 0.35)
		elif wsk != "":
			var winfo2: Array = Cosmetics.weapon_skin_info(wid, wsk)
			if not winfo2.is_empty():
				wname = "%s  -  %s" % [wdata["name"], String(winfo2[1])]
		UIKit.text_in(self, wname, name_rect, _fit_font(wname, name_rect.size.x - 20.0, 22), wname_col, HORIZONTAL_ALIGNMENT_CENTER, 5)


# ================================================================== kotak hitung mundur
class CountdownBox extends Control:
	var st: SelState
	var value: int = -1
	var pop: float = 1.0
	var t: float = 0.0

	func _init(s: SelState = null) -> void:
		st = s
		size = Vector2(380, 108)
		custom_minimum_size = size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_value(v: int) -> void:
		value = v
		pop = 1.5
		UIKit.tw(self).tween_property(self, "pop", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var pts := UIKit.slanted(w, h, 24)
		draw_colored_polygon(UIKit.slanted(w, h, 24, 6, 7), Color(0, 0, 0, 0.5))
		var counting: bool = value >= 0
		var c0: Color = Color(0.05, 0.07, 0.15, 0.92)
		if counting:
			c0 = c0.lerp(Color(0.05, 0.25, 0.14, 0.95), 0.6)
		draw_colored_polygon(pts, c0)
		draw_polyline(UIKit.closed(pts), UIKit.GREEN if counting else Color(1, 1, 1, 0.3), 3.0, true)
		if counting:
			draw_set_transform(Vector2(w * 0.5, h * 0.5 + 8), 0.0, Vector2.ONE * pop)
			UIKit.text_in(self, str(value), Rect2(-80, -46, 160, 92), 96, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 12, Color.BLACK, Global.font_digital)
			draw_set_transform(Vector2.ZERO)
			UIKit.text_in(self, "ALL READY!", Rect2(30, 4, w - 60, 24), 20, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER, 5)
		else:
			var rc: int = st.ready_count()
			UIKit.text_in(self, "WAITING FOR FIGHTERS", Rect2(30, 10, w - 60, 34), 26, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 6)
			var dot_w := 46.0
			var total: float = st.n * dot_w + (st.n - 1) * 10.0
			var x0: float = (w - total) * 0.5 + 6.0
			for i in st.n:
				var r := Rect2(x0 + i * (dot_w + 10.0), 50, dot_w, 30)
				var rp := UIKit.slanted(r.size.x, r.size.y, 8, r.position.x, r.position.y)
				var rd: bool = st.stage[i] >= 2
				var col: Color = Global.PLAYER_COLORS[i]
				draw_colored_polygon(rp, col.lightened(0.1) if rd else Color(0.12, 0.12, 0.2))
				draw_polyline(UIKit.closed(rp), Color.WHITE if rd else Color(1, 1, 1, 0.3), 2.0, true)
				UIKit.text_in(self, "P%d" % (i + 1), r, 20, Color.WHITE if rd else Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 4)
			UIKit.text_in(self, "%d / %d READY" % [rc, st.n], Rect2(30, h - 24, w - 60, 18), 15, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)


# ================================================================== dekorasi arena (lantai perspektif & sorot)
class StageFx extends Control:
	var t: float = 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		# sorot dari atas
		for k in 3:
			var x: float = w * (0.22 + 0.28 * k) + sin(t * 0.5 + k * 2.0) * 60.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(x - 8, 0), Vector2(x + 8, 0), Vector2(x + 150, h * 0.8), Vector2(x - 150, h * 0.8),
			]), Color(0.6, 0.85, 1.0, 0.035))
		# lantai perspektif
		var hy: float = h * 0.8
		draw_rect(Rect2(0, hy, w, h - hy), Color(0, 0, 0, 0.35))
		var vp := Vector2(w * 0.5, hy - 120.0)
		for k in range(-12, 13):
			var xb: float = w * 0.5 + k * 120.0
			draw_line(Vector2(w * 0.5 + k * 22.0, hy), Vector2(xb, h), Color(0.4, 0.8, 1.0, 0.1), 2.0)
		for k in 7:
			var f: float = fmod(float(k) / 7.0 + t * 0.06, 1.0)
			var y: float = hy + pow(f, 1.8) * (h - hy)
			draw_line(Vector2(0, y), Vector2(w, y), Color(0.4, 0.8, 1.0, 0.04 + f * 0.1), 2.0)
		draw_line(Vector2(0, hy), Vector2(w, hy), Color(0.4, 0.85, 1.0, 0.35), 2.0)
		# vignette atas-bawah
		draw_rect(Rect2(0, 0, w, 6), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(0, h - 6, w, 6), Color(0, 0, 0, 0.5))


# ================================================================== setup
func _ready() -> void:
	theme = Global.ui_theme
	Global.play_music("menu")

	n = Global.player_count
	st = SelState.new(n)
	if Global.selections.size() == n:
		# kembali dari layar lain: posisi kursor & senjata dipulihkan, pemain tinggal mengunci ulang
		for i in n:
			st.cursor[i] = clampi(int(Global.selections[i]["character"]), 0, CHAR_COUNT - 1)
			st.weapon[i] = maxi(Global.WEAPON_ORDER.find(Global.selections[i]["weapon"]), 0)
	# pastikan kursor awal tidak bertumpuk di sel yang sama
	for i in n:
		for j in i:
			if st.cursor[i] == st.cursor[j]:
				st.cursor[i] = (st.cursor[i] + 1) % CHAR_COUNT

	bg = UIKit.FxBackground.new()
	add_child(bg)
	bg.set_palette(Color("060a20"), Color("2a0a26"), Color("4fd8ff"), 0.0)
	add_child(StageFx.new())

	title = TitleBar.new()
	title.position = Vector2(0, 8)
	add_child(title)

	status = UIKit.PadStatus.new()
	status.position = Vector2(1280 - 350 - 14, 14)
	status.shown = n
	add_child(status)

	roster = RosterGrid.new(st)
	roster.position = Vector2((1280.0 - roster.size.x) * 0.5, 92.0)
	roster.cell_clicked.connect(_on_cell_clicked)
	add_child(roster)

	# panel pemain: P1 & P3 di kiri, P2 & P4 di kanan
	var left_ids: Array[int] = []
	var right_ids: Array[int] = []
	for i in n:
		if i % 2 == 0:
			left_ids.append(i)
		else:
			right_ids.append(i)
	for side in 2:
		var ids: Array[int] = left_ids if side == 0 else right_ids
		var is_compact: bool = ids.size() > 1
		var ph: float = (PANEL_BOTTOM - PANEL_TOP - 12.0) * 0.5 if is_compact else (PANEL_BOTTOM - PANEL_TOP)
		for k in ids.size():
			var i: int = ids[k]
			var p := FighterPanel.new(i, st, Vector2(PANEL_W, ph), is_compact, side == 0)
			p.position = Vector2(18.0 if side == 0 else 1280.0 - 18.0 - PANEL_W, PANEL_TOP + k * (ph + 12.0))
			p.clicked.connect(_on_panel_clicked)
			add_child(p)
			panels.append(p)
	panels.sort_custom(func(a: FighterPanel, b: FighterPanel) -> bool: return a.idx < b.idx)
	_refresh_devices()

	cdbox = CountdownBox.new(st)
	cdbox.position = Vector2((1280.0 - cdbox.size.x) * 0.5, roster.position.y + roster.size.y + 22.0)
	add_child(cdbox)

	back_btn = UIKit.FancyButton.new("BACK", Vector2(190, 46), 28)
	back_btn.position = Vector2(10, 656)
	back_btn.accent = Color("ff7a7a")
	back_btn.activated.connect(_on_back)
	back_btn.modulate.a = 0.85
	add_child(back_btn)

	prompt = UIKit.make_prompt(self)
	_update_prompts()

	UIInput.pressed.connect(_on_input)
	UIInput.pad_changed.connect(func(_d: int, _c: bool) -> void: _refresh_devices.call_deferred())

	_play_intro()


func _exit_tree() -> void:
	if UIInput.pressed.is_connected(_on_input):
		UIInput.pressed.disconnect(_on_input)


func _play_intro() -> void:
	title.position.y = -90.0
	UIKit.tw(title).tween_property(title, "position:y", 8.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	roster.scale = Vector2.ONE * 0.8
	roster.modulate.a = 0.0
	var rt := UIKit.tw(roster)
	rt.set_parallel(true)
	rt.tween_property(roster, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
	rt.tween_property(roster, "modulate:a", 1.0, 0.3).set_delay(0.15)
	for p in panels:
		var target: Vector2 = p.position
		p.position.x += -520.0 if p.left_side else 520.0
		p.modulate.a = 0.0
		var t := UIKit.tw(p)
		t.set_parallel(true)
		t.tween_property(p, "position:x", target.x, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1 + p.idx * 0.08)
		t.tween_property(p, "modulate:a", 1.0, 0.25).set_delay(0.1 + p.idx * 0.08)
	cdbox.modulate.a = 0.0
	UIKit.tw(cdbox).tween_property(cdbox, "modulate:a", 1.0, 0.4).set_delay(0.5)


## Nama perangkat input untuk tiap panel.
func _refresh_devices() -> void:
	var pads: Array[int] = UIInput.pads()
	for p in panels:
		var dev: int = Global.device_of(p.idx)
		if dev >= 0 and pads.has(dev):
			p.device_pad = true
			p.device_text = "PAD %d" % (pads.find(dev) + 1)
		else:
			p.device_pad = false
			p.device_text = "KEYBOARD"
	_update_prompts()


# ================================================================== input
## Pemain mana yang dikendalikan oleh sumber input ini.
## Pemain yang memilih CONTROLLER hanya dikendalikan controller-nya; keybind keyboard-nya diabaikan.
func _slot_for(source: int) -> int:
	if source >= 0:
		return Global.slot_of_device(source)
	if UIInput.is_generic(source):
		# tombol umum (Enter / Q / E / Tab / panah) dipakai pemain 1 kalau P1 memakai keyboard
		return 0 if (n > 0 and not Global.uses_pad(0)) else -1
	var k: int = UIInput.layout_of(source)
	if k >= n or Global.uses_pad(k):
		return -1
	return k


func _on_input(source: int, action: StringName) -> void:
	if leaving:
		return
	var slot: int = _slot_for(source)
	if slot < 0:
		# ESC / Backspace tetap bisa kembali ke menu walau P1 memakai controller
		if action == &"back" and UIInput.is_generic(source) and not countdown_on:
			_on_back()
		return
	if st.rolling[slot]:
		return
	match action:
		&"left":
			_nav(slot, -1, 0)
		&"right":
			_nav(slot, 1, 0)
		&"up":
			_nav(slot, 0, -1)
		&"down":
			_nav(slot, 0, 1)
		&"prev":
			_step_cursor(slot, -1)
		&"next":
			_step_cursor(slot, 1)
		&"extra":
			if st.stage[slot] == 0 and not countdown_on:
				_roll(slot)
		&"fire", &"accept":
			_confirm(slot)
		&"back":
			_back(slot)
	_update_prompts()


func _nav(slot: int, dx: int, dy: int) -> void:
	if countdown_on:
		return
	match st.stage[slot]:
		0:
			_move_cursor(slot, dx, dy)
		1:
			if dx != 0:
				if st.sk[slot] == 1:
					_cycle_cskin(slot, dx)
				elif st.sk[slot] == 2:
					_cycle_wskin(slot, dx)
				else:
					st.weapon[slot] = posmod(st.weapon[slot] + dx, Global.WEAPON_ORDER.size())
					st.wskin[slot] = ""
					panels[slot].weapon_fx(dx)


## Pilihan skin karakter yang dimiliki untuk karakter yang dikunci ("" = tampilan asli).
func _cskin_opts(slot: int) -> Array:
	return [""] + Cosmetics.owned_skin_ids(int(st.locked[slot]))


func _wskin_opts(slot: int) -> Array:
	return [""] + Cosmetics.owned_wskin_ids(String(Global.WEAPON_ORDER[st.weapon[slot]]))


func _cycle_cskin(slot: int, dir: int) -> void:
	var opts: Array = _cskin_opts(slot)
	var i: int = maxi(opts.find(st.cskin[slot]), 0)
	st.cskin[slot] = String(opts[posmod(i + dir, opts.size())])
	panels[slot].weapon_fx(dir)
	Global.play_sfx("ui_move", -10.0)


func _cycle_wskin(slot: int, dir: int) -> void:
	var opts: Array = _wskin_opts(slot)
	var i: int = maxi(opts.find(st.wskin[slot]), 0)
	st.wskin[slot] = String(opts[posmod(i + dir, opts.size())])
	panels[slot].weapon_fx(dir)
	Global.play_sfx("ui_move", -10.0)


## Setelah karakter dikunci: kalau punya skin -> pilih skin dulu (selalu mulai dari DEFAULT), kalau tidak langsung ke senjata (bypass).
func _enter_after_lock(slot: int) -> void:
	st.stage[slot] = 1
	st.wskin[slot] = ""
	if _cskin_opts(slot).size() > 1:
		st.sk[slot] = 1
		st.cskin[slot] = ""          # selalu mulai dari DEFAULT; skin dipilih manual oleh pemain
	else:
		st.sk[slot] = 0
		st.cskin[slot] = ""


func _move_cursor(slot: int, dx: int, dy: int) -> void:
	var c: int = st.cursor[slot]
	var nc: int = c
	if c == RANDOM_CELL:
		if dy != 0:
			nc = RosterGrid.cell_at(roster_col(slot), RosterGrid.ROWS - 1 if dy < 0 else 0)
	else:
		var col: int = RosterGrid.cell_col(c)
		var row: int = RosterGrid.cell_row(c)
		col = posmod(col + dx, RosterGrid.COLS)
		row += dy
		if row > RosterGrid.ROWS - 1 or row < 0:
			nc = RANDOM_CELL
			_last_col[slot] = col
		else:
			nc = RosterGrid.cell_at(col, row)
	if nc != c:
		st.cursor[slot] = nc
		roster.punch(slot)
		Global.play_sfx("ui_move", -12.0)


var _last_col: Array[int] = [0, 0, 0, 0]

func roster_col(slot: int) -> int:
	return _last_col[slot]


func _step_cursor(slot: int, dir: int) -> void:
	if st.stage[slot] == 1 and st.sk[slot] != 0 and not countdown_on:
		_nav(slot, dir, 0)     # tombol bahu juga bisa ganti skin
		return
	if st.stage[slot] != 0 or countdown_on:
		return
	var c: int = st.cursor[slot]
	var nc: int = posmod((c if c < CHAR_COUNT else CHAR_COUNT - 1) + dir, CHAR_COUNT)
	st.cursor[slot] = nc
	roster.punch(slot)
	Global.play_sfx("ui_move", -12.0)


func _confirm(slot: int) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_confirm[slot] < 150:
		return          # tombol tembak keyboard memancarkan "accept" + "fire" sekaligus
	_last_confirm[slot] = now
	if countdown_on:
		if now >= _cd_guard:
			_proceed()
		return
	match st.stage[slot]:
		0:
			var c: int = st.cursor[slot]
			if c == RANDOM_CELL:
				_roll(slot)
				return
			if st.owner_of(c, slot) >= 0:
				panels[slot].deny()
				UIInput.toast("FIGHTER TAKEN", "P%d already picked %s" % [st.owner_of(c, slot) + 1, Global.character_name(0, c)], Color("ff7a7a"))
				return
			st.locked[slot] = c
			_enter_after_lock(slot)
			panels[slot].lock_fx()
			Global.play_character_voice(c)       # suara nama karakter saat dipilih
		1:
			if st.sk[slot] == 1:
				# skin karakter terpilih -> lanjut pilih senjata
				st.sk[slot] = 0
				Cosmetics.set_last_cskin(int(st.locked[slot]), st.cskin[slot])
				panels[slot].lock_fx()
				Global.play_sfx("ui_confirm", -8.0)
				return
			var wid: String = Global.WEAPON_ORDER[st.weapon[slot]]
			if not bool(Global.WEAPONS[wid]["enabled"]):
				panels[slot].deny()
				UIInput.toast("WEAPON COMING SOON", "Pick another weapon", Color("ff7a7a"))
				return
			if st.sk[slot] == 0 and _wskin_opts(slot).size() > 1:
				# senjata punya skin yang dimiliki -> pilih skin senjata dulu sebelum READY
				st.sk[slot] = 2
				st.wskin[slot] = Cosmetics.last_wskin(wid)
				panels[slot].weapon_fx(1)
				Global.play_sfx("ui_confirm", -8.0)
				return
			if st.sk[slot] == 2:
				Cosmetics.set_last_wskin(wid, st.wskin[slot])
				st.sk[slot] = 0
			st.stage[slot] = 2
			panels[slot].ready_fx(true)
			Global.play_weapon_voice(wid)         # suara nama senjata saat dipilih (assets/sfx/voice/weapon_<id>.*)
			_check_countdown()


func _back(slot: int) -> void:
	if countdown_on:
		# batalkan hitung mundur: pemain ini kembali memilih senjata
		st.stage[slot] = 1
		st.sk[slot] = 0
		panels[slot].ready_fx(false)
		_check_countdown()
		return
	match st.stage[slot]:
		2:
			st.stage[slot] = 1
			st.sk[slot] = 0
			panels[slot].ready_fx(false)
		1:
			if st.sk[slot] == 2:
				st.sk[slot] = 0           # kembali ke pilih senjata
				Global.play_sfx("ui_back", -7.0)
				return
			if st.sk[slot] == 0 and _cskin_opts(slot).size() > 1:
				st.sk[slot] = 1           # kembali ke pilih skin karakter
				Global.play_sfx("ui_back", -7.0)
				return
			st.sk[slot] = 0
			st.cskin[slot] = ""
			st.stage[slot] = 0
			st.locked[slot] = -1
			Global.play_sfx("ui_back", -7.0)
		0:
			if slot == 0:
				_on_back()


## Acak karakter yang masih bebas dengan efek "roulette", lalu langsung dikunci.
func _roll(slot: int) -> void:
	if st.rolling[slot] or st.stage[slot] != 0:
		return
	st.rolling[slot] = true
	var steps := 13
	for k in steps:
		var free: Array[int] = []
		for c in CHAR_COUNT:
			if st.owner_of(c, slot) < 0:
				free.append(c)
		st.cursor[slot] = free[randi() % free.size()]
		roster.punch(slot)
		Global.play_sfx("ui_hover", -11.0 + k * 0.5, 0.9 + k * 0.045)
		await get_tree().create_timer(0.04 + k * 0.011).timeout
		if leaving or not is_inside_tree():
			return
	st.rolling[slot] = false
	if st.owner_of(st.cursor[slot], slot) >= 0:
		# (jarang) karakter terakhir keburu diambil pemain lain
		for c in CHAR_COUNT:
			if st.owner_of(c, slot) < 0:
				st.cursor[slot] = c
				break
	st.locked[slot] = st.cursor[slot]
	_enter_after_lock(slot)
	panels[slot].lock_fx()
	Global.play_character_voice(st.locked[slot])   # hasil RANDOM juga dibacakan
	_update_prompts()


func _check_countdown() -> void:
	var all: bool = st.all_ready()
	if all and not countdown_on:
		countdown_on = true
		cd_time = COUNTDOWN_FROM
		_cd_guard = Time.get_ticks_msec() + 500
		cdbox.set_value(int(COUNTDOWN_FROM))
		Global.play_sfx("ui_allready", -4.0)
		for p in panels:
			UIInput.rumble(Global.device_of(p.idx), 0.2, 0.4, 0.2)
	elif not all and countdown_on:
		countdown_on = false
		cdbox.value = -1
	_update_prompts()


func _process(delta: float) -> void:
	if countdown_on and not leaving:
		cd_time -= delta
		var v: int = int(ceil(cd_time))
		if v != cdbox.value and v > 0:
			cdbox.set_value(v)
			Global.play_sfx("count_beep", -8.0)
		if cd_time <= 0.0:
			_proceed()


func _on_cell_clicked(cell: int) -> void:
	# mouse: menggerakkan kursor pemain 1 (dan menekan sekali lagi untuk mengunci)
	if leaving or countdown_on or n < 1 or st.rolling[0]:
		return
	if st.stage[0] != 0:
		return
	if st.cursor[0] == cell:
		_confirm(0)
	else:
		st.cursor[0] = cell
		roster.punch(0)
		Global.play_sfx("ui_move", -12.0)
	_update_prompts()


func _on_panel_clicked(p: FighterPanel, zone: String, dir: int) -> void:
	if leaving or countdown_on:
		return
	if (zone == "wp_l" or zone == "wp_r") and st.stage[p.idx] == 1:
		_nav(p.idx, dir, 0)


func _update_prompts() -> void:
	if prompt == null:
		return
	if countdown_on:
		prompt.set_prompts([[&"none", "CONFIRM = SKIP"], [&"back", "CANCEL"]])
	else:
		prompt.set_prompts([
			[&"dpad", "MOVE"], [&"none", "SHOOT / ACCEPT = LOCK IN"],
			[&"extra", "RANDOM"], [&"back", "BACK"],
		])


func _on_back() -> void:
	if leaving:
		return
	leaving = true
	Global.play_music("menu")
	# campaign: kalau fighter sudah pernah dipilih, layar ini dibuka dari peta level -> kembali ke sana
	if Global.campaign_mode and not CampaignData.saved_fighter().is_empty():
		Global.goto("campaign_hub")
	else:
		Global.goto("menu")


func _proceed() -> void:
	if leaving:
		return
	leaving = true
	Global.selections = []
	for i in n:
		Global.selections.append({"character": st.locked[i], "weapon": Global.WEAPON_ORDER[st.weapon[i]],
			"skin": st.cskin[i], "wskin": st.wskin[i]})
		Cosmetics.set_last_cskin(int(st.locked[i]), st.cskin[i])
		Cosmetics.set_last_wskin(String(Global.WEAPON_ORDER[st.weapon[i]]), st.wskin[i])
	if Global.campaign_mode and n == 1:
		CampaignData.save_fighter(int(st.locked[0]), String(Global.WEAPON_ORDER[st.weapon[0]]))   # ingat pilihan untuk masuk berikutnya
	Global.assign_devices()
	Global.play_sfx("count_go", -6.0)
	for p in panels:
		UIInput.rumble(Global.device_of(p.idx), 0.4, 0.8, 0.3)
		UIKit.burst(self, p.position + p._portrait_rect().get_center(), Global.PLAYER_COLORS[p.idx].lightened(0.3), 30, 380.0, 8.0)
	await get_tree().create_timer(0.35).timeout
	if Global.campaign_mode:
		Global.goto("campaign_hub")
	elif n >= 3:
		Global.goto("team")        # 3-4 pemain: atur TIM dulu (bisa dibiarkan sendiri-sendiri), baru BATTLE SETTINGS
	else:
		Global.goto("battle")
