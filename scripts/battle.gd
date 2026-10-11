extends Control
## Layar "BATTLE SETTINGS" (setelah semua pemain READY di layar pilih fighter).
## Urutan dari atas ke bawah:
##   MAP (kartu besar)  ->  TIME (30 detik - 5 menit atau INFINITE)  ->  ROUNDS  ->  OBJECTS (FEWER / NORMAL / MORE / EXTREME)
##   ->  POWER-UPS ON/OFF  ->  POWER-UP AMOUNT  ->  POWER-UP LIST (izinkan / larang tiap power up)  ->  START
## Semua pemain / controller boleh mengatur. ATAS/BAWAH pindah baris, KIRI/KANAN ubah nilai, ACCEPT = pilih / mulai.
## Pengaturan tersimpan otomatis (user://match.cfg) dan dipakai lagi di pertandingan berikutnya.

const ROW_COUNT := 8                 # 0 MAP, 1 TIME, 2 ROUNDS, 3 OBJECTS, 4 POWERUPS, 5 AMOUNT, 6 LIST, 7 START
const ROW_MAP := 0
const ROW_TIME := 1
const ROW_ROUNDS := 2
const ROW_OBJECTS := 3
const ROW_PU_ON := 4
const ROW_PU_AMOUNT := 5
const ROW_PU_LIST := 6
const ROW_START := 7
const ROW_H := 42.0                  # tinggi baris opsi (dipadatkan supaya 6 baris + START muat di layar)
const ROW_PITCH := 46.0
const LEFT_X := 36.0
const LEFT_W := 760.0
const RIGHT_X := 826.0
const RIGHT_W := 418.0

var bg: UIKit.FxBackground
var prompt: UIKit.PromptBar
var status: UIKit.PadStatus
var back_btn: UIKit.FancyButton
var title: UIKit.Banner

var map_card: MapCard
var rows: Dictionary = {}            # indeks baris -> OptionRow
var start_bar: StartBar
var summary: SummaryCard
var list_panel: PowerListPanel

var focus: int = 0
var map_idx: int = 0
var leaving := false
var in_list := false
var _last_accept: int = 0
var _enter_ms: int = 0


# ================================================================== kartu MAP
class MapCard extends Control:
	signal clicked(dir: int)

	var map_idx: int = 0
	var active: bool = false
	var t: float = 0.0
	var slide: float = 0.0
	var pop: float = 1.0
	var flash: float = 0.0
	var nudge: float = 0.0
	var _hit := {}

	func _init() -> void:
		size = Vector2(760, 212)
		custom_minimum_size = size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP

	func change(dir: int) -> void:
		slide = float(dir)
		pop = 0.86
		flash = 0.8
		nudge = float(dir)
		var tw := UIKit.tw(self)
		tw.set_parallel(true)
		tw.tween_property(self, "slide", 0.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "pop", 1.0, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "flash", 0.0, 0.3)
		tw.tween_property(self, "nudge", 0.0, 0.22)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for k in _hit:
				var r: Rect2 = _hit[k]["rect"]
				if r.has_point(event.position):
					clicked.emit(int(_hit[k]["dir"]))
					return
			clicked.emit(0)

	func _draw() -> void:
		_hit.clear()
		var w: float = size.x
		var h: float = size.y
		var pul: float = 0.5 + 0.5 * sin(t * 5.0)
		var sk := 22.0
		var pts := UIKit.slanted(w, h, sk)
		draw_colored_polygon(UIKit.slanted(w, h, sk, 7, 9), Color(0, 0, 0, 0.5))
		var top := Color(0.1, 0.12, 0.24, 0.94)
		var bot := Color(0.03, 0.04, 0.09, 0.95)
		draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
		draw_polyline(UIKit.closed(pts), UIKit.GOLD if active else Color(1, 1, 1, 0.2), 4.0 if active else 2.0, true)

		var mid: String = Global.MAP_ORDER[map_idx]
		var mdata: Dictionary = Global.MAPS[mid]
		var m_ok: bool = bool(mdata["enabled"])
		var pal: Array = Global.MAP_PALETTES.get(mid, Global.MAP_PALETTES["earth"])
		var acc: Color = pal[2]

		# ----- label
		UIKit.text_in(self, "MAP", Rect2(sk + 18, 8, 120, 34), 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 6)

		# ----- preview besar
		var pv := Rect2(sk + 18, 46, 304, 156)
		var cen := pv.get_center()
		draw_rect(Rect2(pv.position - Vector2(4, 4), pv.size + Vector2(8, 8)), Color(acc, 0.9 if active else 0.5))
		draw_rect(pv, Color(0, 0, 0, 1))
		var tex: Texture2D = Global.map_background(mid)
		var sc: float = pop * (1.0 + 0.015 * sin(t * 1.4))
		var clip_c := cen + Vector2(slide * 40.0, 0)
		var pr := Rect2(clip_c - pv.size * 0.5 * sc, pv.size * sc)
		# potong ke dalam kotak preview (sederhana: gambar bagian yang beririsan saja)
		var vis := pr.intersection(pv)
		if vis.size.x > 0.0 and vis.size.y > 0.0:
			var u0: float = (vis.position.x - pr.position.x) / pr.size.x
			var v0: float = (vis.position.y - pr.position.y) / pr.size.y
			var u1: float = (vis.end.x - pr.position.x) / pr.size.x
			var v1: float = (vis.end.y - pr.position.y) / pr.size.y
			var ts: Vector2 = tex.get_size()
			var src := Rect2(u0 * ts.x, v0 * ts.y, (u1 - u0) * ts.x, (v1 - v0) * ts.y)
			draw_texture_rect_region(tex, vis, src, Color.WHITE if m_ok else Color(0.3, 0.3, 0.3))
		if mid == Global.RANDOM_MAP and m_ok:
			draw_rect(pv, Color(0.06, 0.03, 0.14, 0.55))
			UIKit.text_in(self, "?", pv, 130, Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_CENTER, 10)
			UIKit.text_in(self, "RANDOM EACH MATCH", Rect2(pv.position.x, pv.end.y - 38, pv.size.x, 28), 20, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 5)
		if flash > 0.0:
			draw_rect(pv, Color(1, 1, 1, 0.7 * flash))
		# kilau
		var sh: float = fmod(t * 0.5, 1.8) - 0.4
		var gx: float = pv.position.x + sh * pv.size.x
		var band := PackedVector2Array([Vector2(gx + 14, pv.position.y), Vector2(gx + 44, pv.position.y), Vector2(gx + 30, pv.end.y), Vector2(gx, pv.end.y)])
		var clipped: Array = Geometry2D.intersect_polygons(band, PackedVector2Array([pv.position, Vector2(pv.end.x, pv.position.y), pv.end, Vector2(pv.position.x, pv.end.y)]))
		if not clipped.is_empty() and (clipped[0] as PackedVector2Array).size() >= 3:
			draw_colored_polygon(clipped[0], Color(1, 1, 1, 0.14))
		if not m_ok:
			UIKit.draw_lock(self, cen, 40.0, Color(1, 1, 1, 0.9))
		# panah
		var cc: Color = Color(UIKit.GOLD, 1.0) if active else Color(1, 1, 1, 0.35)
		var ap: float = 1.0 + (pul * 0.25 if active else 0.0)
		UIKit.draw_chevron(self, Vector2(pv.position.x - 14 - maxf(-nudge, 0.0) * 5.0, cen.y), 12.0 * ap, -1, cc)
		UIKit.draw_chevron(self, Vector2(pv.end.x + 14 + maxf(nudge, 0.0) * 5.0, cen.y), 12.0 * ap, 1, cc)
		_hit["l"] = {"rect": Rect2(pv.position.x - 40, pv.position.y, 80, pv.size.y), "dir": -1}
		_hit["r"] = {"rect": Rect2(pv.end.x - 40, pv.position.y, 80, pv.size.y), "dir": 1}

		# ----- nama & info
		var ix: float = pv.end.x + 34.0
		var mname: String = mdata["name"] if m_ok else "%s (SOON)" % mdata["name"]
		var nxo: float = slide * 20.0
		UIKit.text_in(self, mname, Rect2(ix + nxo, 40, w - ix - 30, 66), 60, Color(1, 1, 1, 1.0 - absf(slide) * 0.6), HORIZONTAL_ALIGNMENT_LEFT, 10)
		UIKit.text_in(self, "%d / %d" % [map_idx + 1, Global.MAP_ORDER.size()], Rect2(ix, 104, 140, 26), 22, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_LEFT, 4)

		# ----- strip thumbnail semua map
		var count: int = Global.MAP_ORDER.size()
		var gap := 6.0
		var tw_: float = minf(46.0, (w - ix - 28.0 - gap * float(count - 1)) / float(count))   # menyesuaikan jumlah map
		var th_: float = tw_ * 27.0 / 46.0
		var sx: float = ix
		var sy: float = 146.0
		for k in count:
			var tr := Rect2(sx + k * (tw_ + gap), sy, tw_, th_)
			var on: bool = k == map_idx
			var id2: String = Global.MAP_ORDER[k]
			var tt: Texture2D = Global.map_background(id2)
			if on:
				draw_rect(tr.grow(3.0), Color(UIKit.GOLD, 0.6 + 0.4 * pul))
			draw_texture_rect(tt, tr, false, Color.WHITE if on else Color(0.55, 0.55, 0.6))
			if id2 == Global.RANDOM_MAP:
				draw_rect(tr, Color(0.06, 0.03, 0.14, 0.5))
				UIKit.text_in(self, "?", tr, int(th_ * 0.9), Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_CENTER, 4)
			if on:
				draw_rect(tr, Color.WHITE, false, 2.0)
			_hit["t%d" % k] = {"rect": tr, "dir": 0, "map": k}

	func map_at(pos: Vector2) -> int:
		for k in _hit:
			if _hit[k].has("map") and (_hit[k]["rect"] as Rect2).has_point(pos):
				return int(_hit[k]["map"])
		return -1


# ================================================================== baris opsi
class OptionRow extends Control:
	signal clicked(row: int, dir: int)

	var row: int = 0
	var label_text: String = ""
	var kind: String = "choice"          # time | rounds | toggle | choice | button
	var value: int = 0
	var options: Array[String] = []
	var detail: String = ""
	var active: bool = false
	var disabled: bool = false
	var t: float = 0.0
	var pop: float = 1.0
	var nudge: float = 0.0
	var _hit := {}

	func _init(r: int = 0, text: String = "", k: String = "choice", sz: Vector2 = Vector2(760, 48)) -> void:
		row = r
		label_text = text
		kind = k
		size = sz
		custom_minimum_size = sz
		pivot_offset = sz * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP

	func change_fx(dir: int) -> void:
		pop = 1.3
		nudge = float(dir)
		var tw := UIKit.tw(self)
		tw.set_parallel(true)
		tw.tween_property(self, "pop", 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(self, "nudge", 0.0, 0.22)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for k in _hit:
				var r: Rect2 = _hit[k]["rect"]
				if r.has_point(event.position):
					clicked.emit(row, int(_hit[k]["dir"]))
					return
			clicked.emit(row, 0)

	func _arrows(cx0: float, cx1: float, cy: float, show_l: bool, show_r: bool) -> void:
		var pul: float = 1.0 + (0.5 + 0.5 * sin(t * 6.0)) * 0.25 if active else 1.0
		var col: Color = UIKit.GOLD if active else Color(1, 1, 1, 0.3)
		if disabled:
			col = Color(1, 1, 1, 0.12)
		if show_l:
			UIKit.draw_chevron(self, Vector2(cx0 - maxf(-nudge, 0.0) * 4.0, cy), 10.0 * pul, -1, col)
		if show_r:
			UIKit.draw_chevron(self, Vector2(cx1 + maxf(nudge, 0.0) * 4.0, cy), 10.0 * pul, 1, col)
		_hit["l"] = {"rect": Rect2(cx0 - 26, 0, 52, size.y), "dir": -1}
		_hit["r"] = {"rect": Rect2(cx1 - 26, 0, 52, size.y), "dir": 1}

	func _draw() -> void:
		_hit.clear()
		var w: float = size.x
		var h: float = size.y
		var sk := 16.0
		var shift: float = 12.0 if active else 0.0
		var al: float = 0.4 if disabled else 1.0
		var pts := UIKit.slanted(w - 24.0, h, sk, shift, 0)
		draw_colored_polygon(UIKit.slanted(w - 24.0, h, sk, shift + 5, 6), Color(0, 0, 0, 0.4))
		var base := Color(0.07, 0.07, 0.16, 0.88)
		var hi := Color(0.22, 0.18, 0.05, 0.96)
		draw_colored_polygon(pts, base.lerp(hi, 1.0 if active else 0.0))
		draw_polyline(UIKit.closed(pts), UIKit.GOLD if active else Color(1, 1, 1, 0.16), 3.0 if active else 2.0, true)
		UIKit.text_in(self, label_text, Rect2(shift + sk + 16, 0, 260, h), 28, Color(UIKit.GOLD.lerp(Color.WHITE, 0.0 if active else 0.7), al), HORIZONTAL_ALIGNMENT_LEFT)

		var cx: float = shift + 520.0
		var cy: float = h * 0.5
		draw_set_transform(Vector2(cx, cy), 0.0, Vector2.ONE * pop)
		match kind:
			"time":
				if value == Global.TIME_INFINITE:
					var itex: Texture2D = Global.cached_tex("res://assets/sprites/ui/infinite.png")
					var bob: float = 1.0 + sin(t * 2.4) * 0.05
					draw_texture_rect_region(itex, Rect2(Vector2(-34, -17) * bob, Vector2(68, 34) * bob), Rect2(300, 360, 800, 400), Color(1, 1, 1, al))
				else:
					UIKit.text_in(self, Global.format_time(value), Rect2(-80, -h * 0.5, 160, h), 40, Color(1, 1, 1, al), HORIZONTAL_ALIGNMENT_CENTER, 0, Color.BLACK, Global.font_digital)
			"rounds":
				var total: int = Global.MAX_WINS
				var pw := 30.0
				var gap := 8.0
				var x0: float = -(total * pw + (total - 1) * gap) * 0.5
				for k in total:
					var on: bool = k < value
					var rr := Rect2(x0 + k * (pw + gap), -11, pw, 22)
					var sp := UIKit.slanted(rr.size.x, rr.size.y, 7, rr.position.x, rr.position.y)
					draw_colored_polygon(sp, Color(UIKit.GOLD, al) if on else Color(1, 1, 1, 0.16))
					draw_polyline(UIKit.closed(sp), Color(0, 0, 0, 0.8), 1.5, true)
			"toggle":
				var on2: bool = value > 0
				var pill := Rect2(-70, -19, 140, 38)
				var sb := StyleBoxFlat.new()
				sb.bg_color = UIKit.GREEN.darkened(0.2) if on2 else Color(0.25, 0.25, 0.3)
				sb.set_corner_radius_all(19)
				sb.border_color = Color(1, 1, 1, 0.7 * al)
				sb.set_border_width_all(2)
				draw_style_box(sb, pill)
				var kx: float = pill.position.x + (pill.size.x - 34.0 - 4.0 if on2 else 4.0)
				draw_circle(Vector2(kx + 17.0, 0), 14.0, Color.WHITE)
				UIKit.text_in(self, "ON" if on2 else "OFF", Rect2(pill.position.x + (12 if on2 else 46), pill.position.y, 90, pill.size.y), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
			"choice":
				var cnt: int = options.size()
				var sw := 36.0
				var gp := 6.0
				var x1: float = -(cnt * sw + (cnt - 1) * gp) * 0.5
				UIKit.text_in(self, options[value] if value < cnt else "", Rect2(-90, -h * 0.5 - 3, 180, h * 0.62), 28, Color(1, 1, 1, al), HORIZONTAL_ALIGNMENT_CENTER, 5)
				for k in cnt:
					var on3: bool = k <= value
					var sr := Rect2(x1 + k * (sw + gp), h * 0.5 - 11, sw, 6)
					draw_rect(sr, Color(UIKit.GOLD, al) if on3 else Color(1, 1, 1, 0.16))
			"button":
				UIKit.text_in(self, detail, Rect2(-120, -h * 0.5, 240, h), 26, Color(1, 1, 1, al), HORIZONTAL_ALIGNMENT_CENTER, 5)
		draw_set_transform(Vector2.ZERO)
		if kind == "toggle":
			_arrows(cx - 100.0, cx + 100.0, cy, true, true)
		elif kind == "button":
			_arrows(cx - 150.0, cx + 150.0, cy, false, true)
		elif kind == "time":
			_arrows(cx - 100.0, cx + 100.0, cy, value > Global.MIN_TIME or value == Global.TIME_INFINITE, value != Global.TIME_INFINITE)
		elif kind == "rounds":
			_arrows(cx - 110.0, cx + 110.0, cy, value > Global.MIN_WINS, value < Global.MAX_WINS)
		else:
			_arrows(cx - 120.0, cx + 120.0, cy, value > 0, value < options.size() - 1)


# ================================================================== tombol START
class StartBar extends Control:
	signal clicked

	var active: bool = false
	var ok: bool = true
	var t: float = 0.0
	var flash: float = 0.0

	func _init() -> void:
		size = Vector2(760, 52)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_STOP

	func press() -> void:
		flash = 1.0
		UIKit.tw(self).tween_property(self, "flash", 0.0, 0.4)

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var pts := UIKit.slanted(w - 24.0, h, 22, 0, 0)
		draw_colored_polygon(UIKit.slanted(w - 24.0, h, 22, 6, 7), Color(0, 0, 0, 0.45))
		var c0: Color = UIKit.GREEN.lightened(0.2) if ok else Color(0.3, 0.3, 0.34)
		var c1: Color = UIKit.GREEN.darkened(0.25) if ok else Color(0.2, 0.2, 0.24)
		if not active:
			c0 = c0.darkened(0.35)
			c1 = c1.darkened(0.35)
		draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
		if active and ok:
			var ph: float = fmod(t * 0.8, 1.6) - 0.3
			var sx: float = ph * (w - 24.0)
			var band := PackedVector2Array([Vector2(sx + 14, 0), Vector2(sx + 64, 0), Vector2(sx + 50, h), Vector2(sx, h)])
			var res: Array = Geometry2D.intersect_polygons(band, pts)
			if not res.is_empty():
				draw_colored_polygon(res[0], Color(1, 1, 1, 0.3))
		draw_polyline(UIKit.closed(pts), Color.WHITE if active else Color(1, 1, 1, 0.4), 4.0 if active else 2.0, true)
		if flash > 0.0:
			draw_colored_polygon(pts, Color(1, 1, 1, flash))
		var bob: float = sin(t * 7.0) * 3.0 if active else 0.0
		UIKit.text_in(self, "START BATTLE!" if ok else "LOCKED", Rect2(0, 0, w - 24.0, h), 40, UIKit.INK if ok else Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
		if active and ok:
			UIKit.draw_chevron(self, Vector2(w * 0.5 + 150.0 + bob, h * 0.5), 12.0, 1, UIKit.INK)
			UIKit.draw_chevron(self, Vector2(w * 0.5 - 168.0 - bob, h * 0.5), 12.0, -1, UIKit.INK)


# ================================================================== ringkasan (kolom kanan)
class SummaryCard extends Control:
	var t: float = 0.0

	func _init() -> void:
		size = Vector2(418, 464)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var pts := UIKit.slanted(w, h, 22)
		draw_colored_polygon(UIKit.slanted(w, h, 22, 7, 9), Color(0, 0, 0, 0.5))
		var top := Color(0.08, 0.1, 0.22, 0.92)
		var bot := Color(0.03, 0.04, 0.09, 0.95)
		draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
		draw_polyline(UIKit.closed(pts), Color(1, 1, 1, 0.2), 2.0, true)

		UIKit.text_in(self, "FIGHTERS", Rect2(38, 8, 200, 34), 28, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 6)
		var teams_on: bool = Global.teams_active()
		if teams_on:
			# ringkasan susunan tim, mis. "3 v 1" / "2 v 2" / "2 v 1 v 1"
			var sizes: Array[int] = []
			for tt in Global.MAX_TEAMS:
				if Global.team_size(tt) > 0:
					sizes.append(Global.team_size(tt))
			sizes.sort()
			sizes.reverse()
			var parts := PackedStringArray()
			for z in sizes:
				parts.append(str(z))
			UIKit.text_in(self, "TEAMS  " + " v ".join(parts), Rect2(150, 8, w - 150 - 36, 34), 24, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_RIGHT, 5)
		var n: int = Global.selections.size()
		var rh: float = 66.0
		for i in n:
			var sel: Dictionary = Global.selections[i]
			var col: Color = Global.PLAYER_COLORS[i]
			var r := Rect2(24, 46 + i * (rh + 6.0), w - 48, rh)
			var rp := UIKit.slanted(r.size.x, r.size.y, 12, r.position.x, r.position.y)
			var c0: Color = col.darkened(0.45)
			var c1: Color = col.darkened(0.8)
			draw_polygon(rp, PackedColorArray([c0, c0, c1, c1]))
			draw_polyline(UIKit.closed(rp), col, 3.0, true)
			if teams_on:
				var tcol: Color = Global.team_color(int(Global.team_of[i]))
				draw_colored_polygon(UIKit.slanted(22.0, r.size.y, 12.0, r.position.x, r.position.y), tcol)
			var pr := Rect2(r.position.x + 22, r.position.y + 5, 56, 56)
			draw_rect(pr.grow(3.0), col)
			draw_texture_rect(Cosmetics.char_tex(int(sel["character"]), String(sel.get("skin", ""))), pr, false)
			UIKit.text_in(self, "P%d" % (i + 1), Rect2(pr.end.x + 10, r.position.y + 2, 50, 30), 24, col.lightened(0.3), HORIZONTAL_ALIGNMENT_LEFT, 5)
			UIKit.text_in(self, Global.character_name(0, int(sel["character"])), Rect2(pr.end.x + 56, r.position.y + 2, 170, 30), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 5)
			var wid: String = sel["weapon"]
			UIKit.text_in(self, str(Global.WEAPONS[wid]["name"]), Rect2(pr.end.x + 10, r.position.y + 32, 140, 28), 20, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_LEFT, 4)
			var gtex: Texture2D = Cosmetics.weapon_tex(wid, String(sel.get("wskin", "")), i)
			var gr := Rect2(r.end.x - 98, r.position.y + 8, 76, 50)
			var ts: Vector2 = gtex.get_size()
			var sc: float = minf(gr.size.x / ts.x, gr.size.y / ts.y)
			draw_texture_rect(gtex, Rect2(gr.get_center() - ts * sc * 0.5, ts * sc), false)

		# ----- strip power up
		var py: float = 46.0 + 4 * (rh + 6.0) + 2.0
		UIKit.text_in(self, "POWER-UPS", Rect2(38, py, 200, 28), 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 6)
		var all_off: bool = not Global.powerups_on
		var icon := 42.0
		var gap := 9.0
		var total: float = Global.POWERUP_ORDER.size() * icon + (Global.POWERUP_ORDER.size() - 1) * gap
		var x0: float = (w - total) * 0.5
		for k in Global.POWERUP_ORDER.size():
			var id: String = Global.POWERUP_ORDER[k]
			var allowed: bool = bool(Global.powerup_allowed.get(id, true)) and not all_off
			var ir := Rect2(x0 + k * (icon + gap), py + 32.0, icon, icon)
			var pc: Color = Global.POWERUPS[id]["color"]
			draw_rect(ir.grow(3.0), Color(pc, 0.9) if allowed else Color(0.3, 0.3, 0.34, 0.8))
			draw_rect(ir, Color(0.05, 0.06, 0.12))
			var tex: Texture2D = Global.cached_tex("res://assets/sprites/powerups/%s.png" % id)
			draw_texture_rect(tex, ir.grow(-2.0), false, Color.WHITE if allowed else Color(0.3, 0.3, 0.34, 0.8))
			if not allowed:
				draw_line(ir.position + Vector2(4, 4), ir.end - Vector2(4, 4), Color(1, 0.3, 0.3), 4.0)
				draw_line(Vector2(ir.end.x - 4, ir.position.y + 4), Vector2(ir.position.x + 4, ir.end.y - 4), Color(1, 0.3, 0.3), 4.0)

		# ----- strip OBJECTS (kepadatan rintangan arena)
		var oy: float = py + 32.0 + icon + 14.0
		UIKit.text_in(self, "OBJECTS", Rect2(38, oy, 160, 28), 24, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, 6)
		var dl: int = Global.OBJECT_DENSITIES.size()
		var pw := 18.0
		var pg := 5.0
		var px0: float = (w - (dl * pw + (dl - 1) * pg)) * 0.5
		for k2 in dl:
			var pr := Rect2(px0 + k2 * (pw + pg), oy + 9.0, pw, 10.0)
			draw_rect(pr, UIKit.GOLD if k2 <= Global.object_density else Color(1, 1, 1, 0.16))
		UIKit.text_in(self, str(Global.OBJECT_DENSITIES[Global.object_density]["name"]), Rect2(w - 38.0 - 130.0, oy, 130, 28), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 5)


# ================================================================== panel daftar power up
class PowerListPanel extends Control:
	signal changed
	signal closed

	const COLS := 4
	var cur: int = 0                 # 0..N-1 kartu power up, N = ALLOW ALL, N+1 = BAN ALL, N+2 = DONE
	var t: float = 0.0
	var pop: Array[float] = []

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false
		for i in Global.POWERUP_ORDER.size():
			pop.append(1.0)

	func count() -> int:
		return Global.POWERUP_ORDER.size()

	func open() -> void:
		cur = 0
		visible = true
		modulate.a = 0.0
		UIKit.tw(self).tween_property(self, "modulate:a", 1.0, 0.2)

	func close() -> void:
		visible = false
		closed.emit()

	func _process(d: float) -> void:
		t += d
		if visible:
			queue_redraw()

	func card_rect(k: int) -> Rect2:
		var cw := 236.0
		var ch := 150.0
		var gx := 16.0
		var rows: int = (count() + COLS - 1) / COLS
		var in_row: int = mini(COLS, count() - (k / COLS) * COLS)
		var x0: float = (1280.0 - (in_row * cw + (in_row - 1) * gx)) * 0.5
		return Rect2(x0 + (k % COLS) * (cw + gx), 190.0 + (k / COLS) * (ch + gx), cw, ch)

	func btn_rect(k: int) -> Rect2:
		var bw := 230.0
		var gx := 16.0
		var x0: float = (1280.0 - (3 * bw + 2 * gx)) * 0.5
		return Rect2(x0 + (k - count()) * (bw + gx), 568.0, bw, 52.0)

	func _punch(k: int, from_v: float) -> void:
		pop[k] = from_v
		UIKit.tw(self).tween_method(func(v: float) -> void: pop[k] = v, from_v, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func toggle(k: int) -> void:
		var id: String = Global.POWERUP_ORDER[k]
		Global.powerup_allowed[id] = not bool(Global.powerup_allowed.get(id, true))
		_punch(k, 0.7)
		Global.play_sfx("ui_toggle_on" if bool(Global.powerup_allowed.get(id, true)) else "ui_toggle_off", -6.0)
		changed.emit()

	func set_all(v: bool) -> void:
		for id in Global.POWERUP_ORDER:
			Global.powerup_allowed[id] = v
		for k in count():
			_punch(k, 0.75)
		Global.play_sfx("ui_toggle_on" if v else "ui_toggle_off", -6.0)
		changed.emit()

	func activate() -> void:
		var n: int = count()
		if cur < n:
			toggle(cur)
		elif cur == n:
			set_all(true)
		elif cur == n + 1:
			set_all(false)
		else:
			close()

	func move(dx: int, dy: int) -> void:
		var old: int = cur
		var n: int = count()
		var rows: int = (n + COLS - 1) / COLS
		if cur < n:
			var col: int = cur % COLS
			var row: int = cur / COLS
			if dx != 0:
				var in_row: int = mini(COLS, n - row * COLS)
				col = posmod(col + dx, in_row)
				cur = row * COLS + col
			elif dy > 0:
				if row < rows - 1:
					cur = mini(cur + COLS, n - 1)
				else:
					cur = n + clampi(col * 3 / COLS, 0, 2)
			elif dy < 0:
				if row > 0:
					cur = cur - COLS
				else:
					cur = n + clampi(col * 3 / COLS, 0, 2)
		else:
			if dx != 0:
				cur = n + posmod(cur - n + dx, 3)
			elif dy < 0:
				cur = clampi(((rows - 1) * COLS) + (cur - n) * 1, 0, n - 1)
			elif dy > 0:
				cur = clampi((cur - n) * COLS / 3, 0, n - 1)
		if cur != old:
			Global.play_sfx("ui_move", -12.0)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			for k in count() + 3:
				var r: Rect2 = card_rect(k) if k < count() else btn_rect(k)
				if r.has_point(event.position):
					cur = k
					activate()
					return

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.06, 0.9))
		var pul: float = 0.5 + 0.5 * sin(t * 6.0)
		var n: int = count()
		# judul
		var tt := "POWER-UP LIST"
		var fs := 52
		var tw: float = UIKit.text_w(tt, fs)
		UIKit.text_in(self, tt, Rect2((size.x - tw) * 0.5, 36, tw, 64), fs, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 10)
		UIKit.text_in(self, "Choose which power-ups are ALLOWED to appear in the arena", Rect2(0, 100, size.x, 30), 22, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 5)
		var allowed_n := 0
		for id in Global.POWERUP_ORDER:
			if bool(Global.powerup_allowed.get(id, true)):
				allowed_n += 1
		UIKit.text_in(self, "%d / %d ALLOWED" % [allowed_n, n], Rect2(0, 132, size.x, 28), 24, UIKit.GREEN if allowed_n > 0 else Color("ff6a6a"), HORIZONTAL_ALIGNMENT_CENTER, 5)

		for k in n:
			var id: String = Global.POWERUP_ORDER[k]
			var info: Dictionary = Global.POWERUPS[id]
			var pc: Color = info["color"]
			var allowed: bool = bool(Global.powerup_allowed.get(id, true))
			var on: bool = cur == k
			var r: Rect2 = card_rect(k)
			var sc: float = pop[k] * (1.04 if on else 1.0)
			draw_set_transform(r.get_center(), 0.0, Vector2.ONE * sc)
			var lr := Rect2(-r.size * 0.5, r.size)
			var pts := UIKit.slanted(lr.size.x, lr.size.y, 16, lr.position.x, lr.position.y)
			draw_colored_polygon(UIKit.slanted(lr.size.x, lr.size.y, 16, lr.position.x + 6, lr.position.y + 7), Color(0, 0, 0, 0.5))
			var c0: Color = pc.darkened(0.55) if allowed else Color(0.14, 0.14, 0.18)
			var c1: Color = pc.darkened(0.85) if allowed else Color(0.07, 0.07, 0.1)
			draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
			var bc: Color = UIKit.GOLD if on else (pc if allowed else Color(1, 1, 1, 0.14))
			var bw: float = (4.0 + pul * 1.5) if on else 2.0
			draw_polyline(UIKit.closed(pts), bc, bw, true)
			var ir := Rect2(-r.size.x * 0.5 + 34, -r.size.y * 0.5 + 18, 70, 70)
			draw_rect(ir.grow(3.0), Color(pc, 0.9) if allowed else Color(0.3, 0.3, 0.34, 0.8))
			draw_rect(ir, Color(0.05, 0.06, 0.12))
			var bob: float = sin(t * 3.0 + k) * 2.0 if allowed else 0.0
			var tex: Texture2D = Global.cached_tex("res://assets/sprites/powerups/%s.png" % id)
			draw_texture_rect(tex, Rect2(ir.position + Vector2(2, 2 + bob), ir.size - Vector2(4, 4)), false, Color.WHITE if allowed else Color(0.3, 0.3, 0.34, 0.85))
			if not allowed:
				draw_line(ir.position + Vector2(4, 4), ir.end - Vector2(4, 4), Color(1, 0.3, 0.3), 5.0)
				draw_line(Vector2(ir.end.x - 4, ir.position.y + 4), Vector2(ir.position.x + 4, ir.end.y - 4), Color(1, 0.3, 0.3), 5.0)
			var tx: float = ir.end.x + 12.0
			var tw2: float = r.size.x * 0.5 - tx - 12.0
			var nm: String = str(info["name"])
			var nfs := 24
			while nfs > 14 and UIKit.text_w(nm, nfs) > tw2:
				nfs -= 1
			UIKit.text_in(self, nm, Rect2(tx, -r.size.y * 0.5 + 18, tw2, 34), nfs, Color.WHITE if allowed else Color(1, 1, 1, 0.45), HORIZONTAL_ALIGNMENT_LEFT, 5)
			var ds: String = str(info["desc"])
			var dfs := 15
			while dfs > 10 and UIKit.text_w(ds, dfs) > tw2:
				dfs -= 1
			UIKit.text_in(self, ds, Rect2(tx, -r.size.y * 0.5 + 52, tw2, 36), dfs, Color(1, 1, 1, 0.65 if allowed else 0.3), HORIZONTAL_ALIGNMENT_LEFT)
			# lencana status
			var br := Rect2(-r.size.x * 0.5 + 34, r.size.y * 0.5 - 44, r.size.x - 68, 30)
			var bp := UIKit.slanted(br.size.x, br.size.y, 8, br.position.x, br.position.y)
			draw_colored_polygon(bp, UIKit.GREEN.darkened(0.3) if allowed else Color("a02828"))
			draw_polyline(UIKit.closed(bp), Color(1, 1, 1, 0.8), 2.0, true)
			UIKit.text_in(self, "ALLOWED" if allowed else "BANNED", br, 22, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 4)
			draw_set_transform(Vector2.ZERO)

		# tombol bawah
		var labels := ["ALLOW ALL", "BAN ALL", "DONE"]
		var cols := [UIKit.GREEN, Color("ff6a6a"), UIKit.GOLD]
		for k in 3:
			var r2: Rect2 = btn_rect(n + k)
			var on2: bool = cur == n + k
			var bp2 := UIKit.slanted(r2.size.x, r2.size.y, 14, r2.position.x, r2.position.y)
			var cc: Color = cols[k]
			var b0: Color = cc.lightened(0.2) if on2 else Color(0.08, 0.08, 0.16, 0.9)
			var b1: Color = cc.darkened(0.2) if on2 else Color(0.05, 0.05, 0.1, 0.9)
			draw_polygon(bp2, PackedColorArray([b0, b0, b1, b1]))
			draw_polyline(UIKit.closed(bp2), Color.WHITE if on2 else Color(1, 1, 1, 0.25), 3.0 if on2 else 2.0, true)
			UIKit.text_in(self, labels[k], r2, 30, UIKit.INK if on2 else Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER)


# ================================================================== setup
func _ready() -> void:
	theme = Global.ui_theme
	Global.play_music("menu")
	_enter_ms = Time.get_ticks_msec()

	# tanpa pilihan fighter (mis. scene dibuka langsung): beri bawaan supaya layar tetap bisa dicoba
	if Global.selections.size() != Global.player_count:
		Global.selections = []
		for i in Global.player_count:
			Global.selections.append({"character": i * 4, "weapon": "pistol"})

	map_idx = maxi(Global.MAP_ORDER.find(Global.map_id), 0)

	bg = UIKit.FxBackground.new()
	add_child(bg)
	_apply_map_visual(true)

	title = UIKit.Banner.new("BATTLE SETTINGS", 44)
	title.position = Vector2(24, 12)
	add_child(title)

	status = UIKit.PadStatus.new()
	status.position = Vector2(1280 - 350 - 14, 16)
	status.shown = Global.player_count
	add_child(status)

	# --- MAP (paling atas)
	map_card = MapCard.new()
	map_card.position = Vector2(LEFT_X, 82)
	map_card.map_idx = map_idx
	map_card.clicked.connect(_on_map_clicked)
	add_child(map_card)

	# --- baris-baris di bawah MAP
	var defs := [
		[ROW_TIME, "TIME", "time"], [ROW_ROUNDS, "ROUNDS", "rounds"], [ROW_OBJECTS, "OBJECTS", "choice"],
		[ROW_PU_ON, "POWER-UPS", "toggle"], [ROW_PU_AMOUNT, "POWER-UP AMOUNT", "choice"], [ROW_PU_LIST, "POWER-UP LIST", "button"],
	]
	var y := 82.0 + 212.0 + 10.0
	for d in defs:
		var r := OptionRow.new(d[0], d[1], d[2], Vector2(LEFT_W, ROW_H))
		r.position = Vector2(LEFT_X, y)
		r.clicked.connect(_on_row_clicked)
		add_child(r)
		rows[d[0]] = r
		y += ROW_PITCH
	for o in Global.OBJECT_DENSITIES:
		(rows[ROW_OBJECTS] as OptionRow).options.append(str(o["name"]))
	for a in Global.POWERUP_AMOUNTS:
		(rows[ROW_PU_AMOUNT] as OptionRow).options.append(str(a["name"]))
	start_bar = StartBar.new()
	start_bar.position = Vector2(LEFT_X, y + 4.0)
	start_bar.clicked.connect(_on_start_clicked)
	add_child(start_bar)

	summary = SummaryCard.new()
	summary.position = Vector2(RIGHT_X, 90)
	add_child(summary)

	back_btn = UIKit.FancyButton.new("BACK", Vector2(190, 46), 28)
	back_btn.position = Vector2(10, 656)
	back_btn.accent = Color("ff7a7a")
	back_btn.activated.connect(_on_back)
	back_btn.modulate.a = 0.85
	add_child(back_btn)

	prompt = UIKit.make_prompt(self)

	list_panel = PowerListPanel.new()
	list_panel.changed.connect(_refresh_rows)
	list_panel.closed.connect(func() -> void:
		in_list = false
		_refresh_rows()
		_update_prompts())
	add_child(list_panel)

	_refresh_rows()
	_update_prompts()
	UIInput.pressed.connect(_on_input)
	UIInput.kind_changed.connect(func(_k: String) -> void: _update_prompts())
	_play_intro()


func _exit_tree() -> void:
	if UIInput.pressed.is_connected(_on_input):
		UIInput.pressed.disconnect(_on_input)


func _play_intro() -> void:
	title.position.x = -500.0
	UIKit.tw(title).tween_property(title, "position:x", 24.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.05)
	var items: Array[Control] = [map_card]
	for k in [ROW_TIME, ROW_ROUNDS, ROW_OBJECTS, ROW_PU_ON, ROW_PU_AMOUNT, ROW_PU_LIST]:
		items.append(rows[k])
	items.append(start_bar)
	for i in items.size():
		var c: Control = items[i]
		var target: Vector2 = c.position
		c.position.x = target.x - 600.0
		c.modulate.a = 0.0
		var t := UIKit.tw(c)
		t.set_parallel(true)
		t.tween_property(c, "position:x", target.x, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08 + i * 0.06)
		t.tween_property(c, "modulate:a", 1.0, 0.25).set_delay(0.08 + i * 0.06)
	var st_target: Vector2 = summary.position
	summary.position.x += 560.0
	summary.modulate.a = 0.0
	var st := UIKit.tw(summary)
	st.set_parallel(true)
	st.tween_property(summary, "position:x", st_target.x, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)
	st.tween_property(summary, "modulate:a", 1.0, 0.25).set_delay(0.2)


func _apply_map_visual(instant: bool = false) -> void:
	var mid: String = Global.MAP_ORDER[map_idx]
	var pal: Array = Global.MAP_PALETTES.get(mid, Global.MAP_PALETTES["earth"])
	bg.set_palette(pal[0], pal[1], pal[2], 0.0 if instant else 0.6)
	bg.set_image(Global.map_background(mid), 0.78, 0.0 if instant else 0.5)


## Sinkronkan tampilan semua baris dengan nilai di Global.
func _refresh_rows() -> void:
	var r1: OptionRow = rows[ROW_TIME]
	r1.value = Global.match_time
	var r2: OptionRow = rows[ROW_ROUNDS]
	r2.value = Global.WINS_TO_MATCH
	var ro: OptionRow = rows[ROW_OBJECTS]
	ro.value = Global.object_density
	var r3: OptionRow = rows[ROW_PU_ON]
	r3.value = 1 if Global.powerups_on else 0
	var r4: OptionRow = rows[ROW_PU_AMOUNT]
	r4.value = Global.powerup_amount
	r4.disabled = not Global.powerups_on
	var r5: OptionRow = rows[ROW_PU_LIST]
	var cnt := 0
	for id in Global.POWERUP_ORDER:
		if bool(Global.powerup_allowed.get(id, true)):
			cnt += 1
	r5.detail = "%d / %d ALLOWED" % [cnt, Global.POWERUP_ORDER.size()]
	r5.disabled = not Global.powerups_on
	for k in rows:
		(rows[k] as OptionRow).active = (k == focus) and not in_list
	map_card.active = focus == ROW_MAP and not in_list
	start_bar.active = focus == ROW_START and not in_list
	start_bar.ok = bool(Global.MAPS[Global.MAP_ORDER[map_idx]]["enabled"])


func _set_focus(f: int) -> void:
	var nf: int = clampi(f, 0, ROW_COUNT - 1)
	if nf == focus:
		return
	focus = nf
	Global.play_sfx("ui_hover", -9.0)
	_refresh_rows()
	_update_prompts()


# ================================================================== input
func _on_input(_source: int, action: StringName) -> void:
	if leaving or Time.get_ticks_msec() - _enter_ms < 350:
		return
	if in_list:
		match action:
			&"left":
				list_panel.move(-1, 0)
			&"right":
				list_panel.move(1, 0)
			&"up":
				list_panel.move(0, -1)
			&"down":
				list_panel.move(0, 1)
			&"accept", &"fire":
				if _accept_ok():
					list_panel.activate()
			&"back", &"start":
				list_panel.close()
		return
	match action:
		&"up":
			_set_focus(focus - 1)
		&"down":
			_set_focus(focus + 1)
		&"left":
			_change(-1)
		&"right":
			_change(1)
		&"prev":
			_change(-1)
		&"next":
			_change(1)
		&"accept", &"fire":
			if _accept_ok():
				_activate()
		&"start":
			_on_start()
		&"back":
			_on_back()


## Tombol tembak keyboard memancarkan "accept" + "fire" sekaligus -> abaikan yang kedua.
func _accept_ok() -> bool:
	var now: int = Time.get_ticks_msec()
	if now - _last_accept < 150:
		return false
	_last_accept = now
	return true


func _change(dir: int) -> void:
	match focus:
		ROW_MAP:
			map_idx = posmod(map_idx + dir, Global.MAP_ORDER.size())
			Global.map_id = Global.MAP_ORDER[map_idx]
			map_card.map_idx = map_idx
			map_card.change(dir)
			_apply_map_visual()
			Global.play_sfx("ui_marimba", -9.0)
		ROW_TIME:
			var old: int = Global.match_time
			Global.match_time = Global.step_time(old, dir)
			if old == Global.match_time:
				Global.play_sfx("ui_error", -14.0)
			else:
				(rows[ROW_TIME] as OptionRow).change_fx(dir)
				Global.play_sfx("ui_marimba", -9.0)
		ROW_ROUNDS:
			var oldw: int = Global.WINS_TO_MATCH
			Global.WINS_TO_MATCH = clampi(oldw + dir, Global.MIN_WINS, Global.MAX_WINS)
			if oldw == Global.WINS_TO_MATCH:
				Global.play_sfx("ui_error", -14.0)
			else:
				(rows[ROW_ROUNDS] as OptionRow).change_fx(dir)
				Global.play_sfx("ui_marimba", -9.0)
		ROW_OBJECTS:
			var oldo: int = Global.object_density
			Global.object_density = clampi(oldo + dir, 0, Global.OBJECT_DENSITIES.size() - 1)
			if oldo == Global.object_density:
				Global.play_sfx("ui_error", -14.0)
			else:
				(rows[ROW_OBJECTS] as OptionRow).change_fx(dir)
				Global.play_sfx("ui_marimba", -9.0)
		ROW_PU_ON:
			Global.powerups_on = not Global.powerups_on
			(rows[ROW_PU_ON] as OptionRow).change_fx(dir)
			Global.play_sfx("ui_toggle_on" if Global.powerups_on else "ui_toggle_off", -6.0)
		ROW_PU_AMOUNT:
			if not Global.powerups_on:
				Global.play_sfx("ui_error", -14.0)
			else:
				var olda: int = Global.powerup_amount
				Global.powerup_amount = clampi(olda + dir, 0, Global.POWERUP_AMOUNTS.size() - 1)
				if olda == Global.powerup_amount:
					Global.play_sfx("ui_error", -14.0)
				else:
					(rows[ROW_PU_AMOUNT] as OptionRow).change_fx(dir)
					Global.play_sfx("ui_marimba", -9.0)
		ROW_PU_LIST:
			if dir > 0:
				_activate()
	_refresh_rows()


func _activate() -> void:
	match focus:
		ROW_MAP, ROW_TIME, ROW_ROUNDS:
			_change(1)
		ROW_OBJECTS:
			# di nilai tertinggi, tombol accept kembali ke FEWER (siklus), panah kiri/kanan tetap berhenti di ujung
			if Global.object_density >= Global.OBJECT_DENSITIES.size() - 1:
				Global.object_density = 0
				(rows[ROW_OBJECTS] as OptionRow).change_fx(-1)
				Global.play_sfx("ui_marimba", -9.0)
				_refresh_rows()
			else:
				_change(1)
		ROW_PU_ON:
			_change(1)
		ROW_PU_AMOUNT:
			_change(1)
		ROW_PU_LIST:
			if not Global.powerups_on:
				Global.play_sfx("hit", -14.0)
				UIInput.toast("POWER-UPS ARE OFF", "Turn them ON first", Color("ff7a7a"))
				return
			in_list = true
			list_panel.open()
			_refresh_rows()
			_update_prompts()
			Global.play_sfx("ui_panel", -6.0)
		ROW_START:
			_on_start()


func _on_map_clicked(dir: int) -> void:
	if leaving or in_list:
		return
	var tmap: int = map_card.map_at(map_card.get_local_mouse_position())
	focus = ROW_MAP
	if tmap >= 0 and tmap != map_idx:
		var d: int = 1 if tmap > map_idx else -1
		map_idx = tmap
		Global.map_id = Global.MAP_ORDER[map_idx]
		map_card.map_idx = map_idx
		map_card.change(d)
		_apply_map_visual()
		Global.play_sfx("ui_marimba", -9.0)
	elif dir != 0:
		_change(dir)
	_refresh_rows()
	_update_prompts()


func _on_row_clicked(row: int, dir: int) -> void:
	if leaving or in_list:
		return
	focus = row
	if dir != 0:
		_change(dir)
	else:
		_activate()
	_refresh_rows()
	_update_prompts()


func _on_start_clicked() -> void:
	if leaving or in_list:
		return
	focus = ROW_START
	_on_start()


func _update_prompts() -> void:
	if prompt == null:
		return
	if in_list:
		prompt.set_prompts([[&"dpad", "MOVE"], [&"accept", "ALLOW / BAN"], [&"back", "DONE"]])
		return
	var acc: String = "START" if focus == ROW_START else ("OPEN" if focus == ROW_PU_LIST else "NEXT VALUE")
	var items: Array = [[&"dpad_ud", "ROW"], [&"dpad_lr", "CHANGE"], [&"accept", acc]]
	if UIInput.kind == "pad":
		items.append([&"start", "START NOW"])
	items.append([&"back", "BACK"])
	prompt.set_prompts(items)


func _on_back() -> void:
	if leaving:
		return
	leaving = true
	Global.save_match_settings()
	# 3-4 pemain: kembali ke layar TEAM (bukan langsung ke pilih fighter)
	Global.goto("team" if (Global.player_count >= 3 and not Global.campaign_mode) else "select")


func _on_start() -> void:
	if leaving:
		return
	var mid: String = Global.MAP_ORDER[map_idx]
	if not bool(Global.MAPS[mid]["enabled"]):
		Global.play_sfx("hit", -10.0)
		UIInput.toast("MAP COMING SOON", "Pick another map", Color("ff7a7a"))
		return
	leaving = true
	Global.map_id = mid
	Global.save_match_settings()
	start_bar.press()
	Global.play_sfx("ui_launch", -4.0)
	for i in Global.selections.size():
		UIInput.rumble(Global.device_of(i), 0.4, 0.8, 0.3)
	UIKit.burst(self, start_bar.position + Vector2(380, 28), UIKit.GREEN, 40, 520.0, 8.0)
	await get_tree().create_timer(0.35).timeout
	Global.goto("game")
