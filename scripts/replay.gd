extends Control
## Layar REPLAY (dibuka dari tombol REPLAY di menu utama).
##   LIST      daftar replay tersimpan + panel detail (kiri: kartu, kanan: info) + tombol WATCH / LOCK / DELETE
##   SETTINGS  pengaturan replay (3 tab: RECORDING, PLAYBACK, AUDIO & LIST) - langsung tersimpan saat diubah
##   VIEW      pemutar video (ReplayView)
##
## Semua tombol bisa dipakai dengan MOUSE, KEYBOARD, dan CONTROLLER:
##   LIST       ATAS/BAWAH pilih replay, KANAN dari kartu = tombol WATCH. Tombol di sebelah kanan kartu: REC/SETTINGS/BACK (atas) dan WATCH/LOCK/DELETE (bawah),
##              ATAS/BAWAH antar keduanya (REC<->WATCH, SETTINGS<->LOCK, BACK<->DELETE), KIRI dari REC atau WATCH = kembali ke kartu replay
##              ENTER / A = jalankan yang terpilih, TAB (Y) kunci, DELETE / X hapus, E (R1) pengaturan, ESC / B kembali
##   SETTINGS   ATAS/BAWAH pilih baris, KIRI/KANAN ubah nilai, Q / E (L1 / R1) ganti tab, ESC / B kembali
##              ATAS dari baris pertama = tab / BACK di atas (KIRI/KANAN pindah, ENTER pilih, BAWAH kembali ke baris)
##   Mouse: klik kartu = pilih / tonton, roda mouse = geser daftar, semua tombol (termasuk tab + BACK di settings) punya efek hover + tekan.

const LIST_X := 40.0
const LIST_Y := 130.0
const CARD_W := 724.0
const CARD_H := 88.0
const CARD_STEP := 98.0
const LIST_H := 490.0

const Z_CARDS := 0
const Z_ACTIONS := 1
const Z_HEADER := 2

const S_ROWS := 0                  # fokus settings: baris pengaturan di bawah
const S_HEAD := 1                  # fokus settings: tab + tombol BACK di atas

var bg: UIKit.FxBackground
var prompt: UIKit.PromptBar
var current: String = "list"
var leaving: bool = false
var busy: bool = false

var replays: Array = []
var sel: int = 0
var scroll: float = 0.0
var cards: Array = []
var clip: Control
var list_root: Control
var detail: DetailPanel
var info: InfoBar
var empty_panel: EmptyPanel
var scroll_ind: ScrollInd
var banner: UIKit.Banner
var chip_watch: ReplayUI.Chip
var chip_lock: ReplayUI.Chip
var chip_del: ReplayUI.Chip
var chip_rec: ReplayUI.Chip
var chip_set: ReplayUI.Chip
var chip_back: ReplayUI.Chip
var head_chips: Array = []
var act_chips: Array = []
var zone: int = Z_CARDS
var head_idx: int = 0
var act_idx: int = 0

var settings_root: Control
var set_banner: UIKit.Banner
var set_auto: UIKit.Banner
var set_back: ReplayUI.Chip
var tab: int = 0
var tab_chips: Array = []
var tab_line: TabLine
var tab_items: Array = []          # per tab: Array kontrol yang bisa dipilih
var tab_roots: Array = []
var tab_idx: Array = [0, 0, 0]
var desc_box: DescBox
var tab_desc: Array = []           # per tab: Array teks deskripsi per item
var set_zone: int = S_ROWS
var set_head_idx: int = 0          # 0..2 = tab, 3 = tombol BACK
var set_head_chips: Array = []     # tab_chips + set_back (urutan navigasi kiri-kanan)

var dialog: ReplayUI.ConfirmDialog
var curtain: Curtain
var confirm_mode: String = ""

var view: ReplayView = null
var _root_tw: Tween


# ================================================================== siklus
func _ready() -> void:
	ReplayStore.ensure_loaded()
	theme = Global.ui_theme
	Global.play_music("menu")

	bg = UIKit.FxBackground.new(Color("0a0a18"), Color("26101f"), Color("ff4a5a"))
	add_child(bg)
	bg.set_image(Global.map_background("hell"), 0.78, 0.8)

	_build_list()
	_build_settings()
	dialog = ReplayUI.ConfirmDialog.new()
	dialog.confirmed.connect(_confirm_yes)
	dialog.cancelled.connect(_on_confirm_cancel)
	add_child(dialog)
	prompt = UIKit.make_prompt(self)
	curtain = Curtain.new()
	add_child(curtain)

	UIInput.pressed.connect(_on_input)
	_refresh_list(true)
	_show("list", false)
	_intro()


func _exit_tree() -> void:
	if UIInput.pressed.is_connected(_on_input):
		UIInput.pressed.disconnect(_on_input)


func _process(delta: float) -> void:
	# gulir halus daftar kartu (tidak tergantung frame rate)
	var maxs: float = maxf(float(replays.size()) * CARD_STEP - LIST_H + 10.0, 0.0)
	var target: float = clampf(float(sel) * CARD_STEP - CARD_STEP * 2.0, 0.0, maxs)
	scroll = lerpf(scroll, target, 1.0 - exp(-delta * 12.0))
	for i in cards.size():
		(cards[i] as Control).position = Vector2(0.0, float(i) * CARD_STEP - scroll)
	scroll_ind.set_state(scroll, maxs, float(replays.size()) * CARD_STEP)


## Animasi masuk layar: judul "membanting", tombol atas turun, kartu menyusul satu per satu, panel detail meluncur dari kanan.
func _intro() -> void:
	banner.pivot_offset = banner.size * 0.5
	banner.modulate.a = 0.0
	banner.scale = Vector2.ONE * 1.9
	var t := UIKit.tw(banner)
	t.set_parallel(true)
	t.tween_property(banner, "modulate:a", 1.0, 0.22)
	t.tween_property(banner, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(func() -> void:
		UIKit.ring(list_root, banner.position + banner.size * 0.5, UIKit.GOLD, 220.0, 0.55))
	for i in head_chips.size():
		_pop_in(head_chips[i], Vector2(0, -34), 0.18 + 0.06 * float(i))
	_pop_in(info, Vector2(-40, 0), 0.3)
	_pop_in(detail, Vector2(130, 0), 0.22, 0.5)
	for i in act_chips.size():
		_pop_in(act_chips[i], Vector2(0, 30), 0.4 + 0.06 * float(i))
	_pop_in(empty_panel, Vector2(0, 40), 0.25, 0.5)


## Geser + muncul dari offset ke posisi aslinya.
func _pop_in(n: Control, off: Vector2, delay: float, dur: float = 0.4) -> void:
	if n == null:
		return
	var base: Vector2 = n.position
	n.position = base + off
	n.modulate.a = 0.0
	var t := UIKit.tw(n)
	t.set_parallel(true)
	t.tween_property(n, "position", base, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
	t.tween_property(n, "modulate:a", 1.0, 0.2).set_delay(delay)


# ================================================================== tirai transisi
## Tirai transisi layar REPLAY <-> pemutar. Bilah miring (gaya sama dengan transisi scene game) menutup layar,
## lalu kartu judul (tag + nama arena + info) muncul selagi pemutar dimuat. Saat dibuka, bilah keluar ke sisi seberang.
## Ringan: hanya ~8 poligon + beberapa teks, digambar ulang hanya saat tirai terlihat.
class Curtain extends Control:
	signal done

	const STRIPS := 8
	const SKEW := 130.0

	var p: float = 0.0:                  # 0..1 = menutup, 1..2 = membuka
		set(v):
			p = v
			visible = v > 0.001 and v < 1.999
			queue_redraw()
	var card: float = 0.0:               # 0..1 = kartu judul muncul
		set(v):
			card = v
			queue_redraw()
	var tag: String = ""
	var title: String = ""
	var sub: String = ""
	var accent: Color = UIKit.GOLD
	var _t: float = 0.0
	var _tw: Tween

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false

	func setup(tag_s: String, title_s: String, sub_s: String, col: Color) -> void:
		tag = tag_s
		title = title_s
		sub = sub_s
		accent = col

	## Menutup layar. Sinyal `done` dikirim saat layar sudah tertutup penuh dan kartu judul tampil.
	func cover(dur: float = 0.4) -> void:
		if _tw:
			_tw.kill()
		card = 0.0
		p = 0.001
		_tw = UIKit.tw(self)
		_tw.tween_property(self, "p", 1.0, dur).set_trans(Tween.TRANS_LINEAR)
		_tw.parallel().tween_property(self, "card", 1.0, 0.3).set_delay(dur * 0.5)
		_tw.chain().tween_callback(func() -> void: done.emit())

	## Membuka layar. Sinyal `done` dikirim setelah tirai sepenuhnya hilang.
	func reveal(dur: float = 0.5) -> void:
		if _tw:
			_tw.kill()
		p = 1.0
		_tw = UIKit.tw(self)
		_tw.tween_property(self, "p", 2.0, dur).set_trans(Tween.TRANS_LINEAR)
		_tw.parallel().tween_property(self, "card", 0.0, 0.2).set_trans(Tween.TRANS_LINEAR)
		_tw.chain().tween_callback(func() -> void:
			p = 0.0
			done.emit())

	func _process(d: float) -> void:
		if visible:
			_t += d
			queue_redraw()

	static func _ease(x: float) -> float:
		var q: float = 1.0 - clampf(x, 0.0, 1.0)
		return 1.0 - q * q * q

	func _draw() -> void:
		if p <= 0.001 or p >= 1.999:
			return
		var w: float = size.x
		var h: float = size.y
		var sw: float = (w + SKEW) / float(STRIPS)
		for i in STRIPS:
			var order: float = float(i) / float(STRIPS - 1)
			var from_top: bool = i % 2 == 0
			var lp: float
			var y0: float
			var y1: float
			var edge_y: float
			if p <= 1.0:
				lp = _ease(p * 1.7 - order * 0.7)
				if lp <= 0.001:
					continue
				if from_top:
					y0 = 0.0
					y1 = h * lp
					edge_y = y1
				else:
					y0 = h * (1.0 - lp)
					y1 = h
					edge_y = y0
			else:
				lp = _ease((p - 1.0) * 1.7 - (1.0 - order) * 0.7)
				if lp >= 0.999:
					continue
				if from_top:
					y0 = h * lp
					y1 = h
					edge_y = y0
				else:
					y0 = 0.0
					y1 = h * (1.0 - lp)
					edge_y = y1
			if y1 - y0 < 0.5:
				continue
			var bx: float = float(i) * sw
			var xl0: float = bx - SKEW * y0 / h
			var xr0: float = xl0 + sw + 3.0
			var xl1: float = bx - SKEW * y1 / h
			var xr1: float = xl1 + sw + 3.0
			var odd: float = 0.0 if i % 2 == 0 else 0.03
			var c_top := Color(0.045 + odd, 0.045 + odd, 0.11 + odd * 1.4)
			var c_bot := Color(0.07 + odd, 0.06 + odd, 0.15 + odd * 1.4).lerp(accent, 0.05)
			draw_polygon(PackedVector2Array([Vector2(xl0, y0), Vector2(xr0, y0), Vector2(xr1, y1), Vector2(xl1, y1)]),
				PackedColorArray([c_top, c_top, c_bot, c_bot]))
			# garis tepi samping tipis (memberi kesan panel) + garis emas di tepi yang bergerak
			draw_line(Vector2(xl0, y0), Vector2(xl1, y1), Color(accent, 0.22), 2.0, true)
			if lp > 0.001 and lp < 0.999:
				var ex0: float = bx - SKEW * edge_y / h
				draw_line(Vector2(ex0, edge_y), Vector2(ex0 + sw + 3.0, edge_y), Color(accent, 0.28), 16.0, true)
				draw_line(Vector2(ex0, edge_y), Vector2(ex0 + sw + 3.0, edge_y), accent, 6.0, true)
		if card > 0.01:
			_draw_card(w, h)

	func _draw_card(w: float, h: float) -> void:
		var cx: float = w * 0.5
		var cy: float = h * 0.5
		var e: float = ReplayUI.ease_out_cubic(card)
		var back: float = ReplayUI.ease_out_back(card)
		var a: float = clampf(card * 1.6, 0.0, 1.0)
		# dua garis emas melebar dari tengah
		var lw: float = w * 0.6 * e
		draw_rect(Rect2(cx - lw * 0.5, cy - 82.0, lw, 3.0), Color(accent, 0.95 * a))
		draw_rect(Rect2(cx - lw * 0.5, cy + 84.0, lw, 3.0), Color(accent, 0.95 * a))
		# tag kecil (meluncur naik)
		UIKit.text_in(self, tag, Rect2(0.0, cy - 76.0 + (1.0 - e) * 18.0, w, 34.0), 26, Color(accent, a), HORIZONTAL_ALIGNMENT_CENTER, 5)
		# judul besar (membesar sedikit dengan efek pantul)
		var fs: int = 80 if UIKit.text_w(title, 80) < w * 0.7 else 56
		var sc: float = 0.86 + 0.14 * back
		draw_set_transform(Vector2(cx, cy + 2.0), 0.0, Vector2.ONE * sc)
		UIKit.text_in(self, title, Rect2(-w * 0.5, -46.0, w, 92.0), fs, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 10, Color(0, 0, 0, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# subteks
		UIKit.text_in(self, sub, Rect2(0.0, cy + 46.0 - (1.0 - e) * 14.0, w, 30.0), 22, Color(1, 1, 1, 0.72 * a), HORIZONTAL_ALIGNMENT_CENTER, 4)
		# indikator memuat: cincin tipis + busur emas berputar
		var sp := Vector2(cx, cy + 128.0)
		draw_arc(sp, 15.0, 0.0, TAU, 28, Color(1, 1, 1, 0.16 * a), 3.0, true)
		var r0: float = _t * 5.5
		draw_arc(sp, 15.0, r0, r0 + 2.2, 16, Color(accent, a), 4.0, true)


# ================================================================== komponen
class Card extends Control:
	signal picked
	signal hovered

	var meta: Dictionary = {}
	var selected: bool = false
	var s: float = 0.0
	var hv: float = 0.0              # 0..1 : kursor mouse sedang berada di atas kartu
	var hov: bool = false
	var kfocus: bool = false         # fokus keyboard / controller ada di kartu ini (efek sama seperti hover mouse)
	var down: float = 0.0            # 0..1 : tombol mouse sedang ditekan di kartu
	var _down_on: bool = false
	var thumb: Texture2D
	var flash: float = 0.0
	var ripple: float = 0.0
	var ripple_pos: Vector2 = Vector2.ZERO
	var _t: float = 0.0
	var intro: float = 1.0:
		set(v):
			intro = v
			modulate.a = clampf(v * 2.5, 0.0, 1.0)
			queue_redraw()

	func _init(m: Dictionary) -> void:
		meta = m
		size = Vector2(CARD_W, CARD_H)
		custom_minimum_size = size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_PASS         # PASS: roda mouse tetap sampai ke layar (geser daftar)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		thumb = Global.map_background(String(m.get("map_id", "earth")))

	func _ready() -> void:
		mouse_entered.connect(_on_enter)
		mouse_exited.connect(_on_exit)

	func _on_enter() -> void:
		hov = true
		hovered.emit()

	func _on_exit() -> void:
		hov = false
		_down_on = false

	## Dipanggil saat pemain pindah memakai keyboard / controller / roda mouse agar tidak ada dua kartu yang menyala.
	func clear_hover() -> void:
		hov = false
		_down_on = false

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			# mouse bergerak lagi di atas kartu (mis. setelah memakai keyboard) -> nyalakan lagi
			if not hov:
				hov = true
				hovered.emit()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				accept_event()
				_down_on = true
				ripple = 1.0
				ripple_pos = event.position
				picked.emit()
			else:
				_down_on = false

	func snap(v: bool) -> void:
		selected = v
		s = 1.0 if v else 0.0
		queue_redraw()

	func pop() -> void:
		flash = 1.0

	func _process(d: float) -> void:
		_t += d
		if _down_on and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_down_on = false
		# kartu bergeser (gulir) dan kursor sudah tidak di atasnya -> matikan efek hover
		if hov and not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()):
			hov = false
		var target: float = 1.0 if selected else 0.0
		var ht: float = 1.0 if (hov or kfocus) else 0.0
		s = lerpf(s, target, 1.0 - exp(-d * 14.0))
		hv = lerpf(hv, ht, 1.0 - exp(-d * 16.0))
		down = lerpf(down, 1.0 if _down_on else 0.0, 1.0 - exp(-d * 30.0))
		flash = maxf(flash - d * 3.0, 0.0)
		ripple = maxf(ripple - d * 2.2, 0.0)
		var sc: float = 1.0 + 0.012 * hv - 0.022 * down
		if absf(scale.x - sc) > 0.0005:
			scale = Vector2.ONE * sc
		if absf(s - target) > 0.002 or selected or flash > 0.0 or hv > 0.003 or absf(hv - ht) > 0.003 or ripple > 0.0 or down > 0.003:
			queue_redraw()

	func _draw() -> void:
		var e: float = ReplayUI.ease_out_back(intro)
		draw_set_transform(Vector2(-90.0 * (1.0 - e), 0.0))
		var shift: float = s * 18.0 + hv * 8.0
		var w: float = size.x - 24.0
		var h: float = size.y - 6.0
		var finished: bool = bool(meta.get("finished", true))
		var wc: Color = meta.get("winner_color", UIKit.GOLD) if finished else Color(0.55, 0.55, 0.62)
		var pts: PackedVector2Array = UIKit.slanted(w, h, 18.0, shift, 0.0)
		draw_colored_polygon(UIKit.slanted(w, h, 18.0, shift + 5.0, 6.0), Color(0, 0, 0, 0.42))
		# cahaya luar emas saat kursor berada di kartu
		if hv > 0.01:
			draw_polyline(UIKit.closed(UIKit.slanted(w + 10.0, h + 10.0, 18.0, shift - 5.0, -5.0)), Color(UIKit.GOLD, (0.22 + 0.1 * sin(_t * 6.0)) * hv), 6.0, true)
		var c0: Color = Color(0.07, 0.07, 0.16, 0.9).lerp(Color(0.26, 0.2, 0.05, 0.96), s).lerp(Color(0.4, 0.31, 0.08, 0.98), hv * 0.8)
		var c1: Color = Color(0.05, 0.05, 0.12, 0.9).lerp(Color(0.16, 0.12, 0.03, 0.96), s).lerp(Color(0.27, 0.2, 0.05, 0.98), hv * 0.8)
		draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
		if s > 0.02 or hv > 0.02:
			ReplayUI.shine(self, pts, w + shift, h, fmod(_t * (0.7 + 0.9 * hv), 1.9) - 0.4, 0.14 * s + 0.14 * hv)
		# garis warna pemenang di sisi kiri (melebar saat hover)
		draw_colored_polygon(UIKit.slanted(7.0 + 5.0 * hv, h, 18.0, shift, 0.0), Color(wc, minf(0.55 + 0.45 * maxf(s, hv), 1.0)))
		var bcol: Color = UIKit.GOLD.lerp(Color(1, 1, 1, 0.16), 1.0 - s).lerp(Color(1.0, 0.95, 0.7, 1.0), hv)
		draw_polyline(UIKit.closed(pts), bcol, 2.0 + s + hv * 1.5, true)
		if flash > 0.0:
			draw_colored_polygon(pts, Color(1, 1, 1, 0.5 * flash))
		# gambar kecil arena (zoom pelan saat hover) + ikon play
		var tr := Rect2(shift + 34.0, 10.0, 104.0, 58.0)
		if thumb != null:
			var ts: Vector2 = thumb.get_size()
			var zs: Vector2 = ts / (1.0 + 0.14 * hv)
			draw_texture_rect_region(thumb, tr, Rect2((ts - zs) * 0.5, zs))
		if s > 0.02 or hv > 0.02:
			draw_rect(tr, Color(0, 0, 0, 0.42 * maxf(s, hv) * (1.0 - 0.3 * hv)))
			var pc: Vector2 = tr.get_center()
			var pr: float = 17.0 * (1.0 + 0.06 * sin(_t * 5.0)) * (1.0 + 0.28 * hv)
			var pf: Color = Color(0, 0, 0, 0.55).lerp(Color(UIKit.GOLD, 0.95), hv * 0.9)
			pf.a *= maxf(s, hv)
			draw_circle(pc, pr, pf)
			draw_arc(pc, pr, 0.0, TAU, 24, Color(1, 1, 1, 0.85 * maxf(s, hv)), 2.5, true)
			if hv > 0.02:
				var ph: float = fmod(_t * 1.4, 1.0)
				draw_arc(pc, pr + 3.0 + ph * 14.0, 0.0, TAU, 28, Color(1, 1, 1, (1.0 - ph) * 0.7 * hv), 2.0, true)
			ReplayUI.draw_icon(self, "play", pc + Vector2(1, 0), 9.0 * (1.0 + 0.15 * hv), Color(1, 1, 1, maxf(s, hv)).lerp(UIKit.INK, hv))
		draw_rect(tr, Color(0, 0, 0, 0.8).lerp(UIKit.GOLD, hv), false, 2.0)
		# teks
		var pcnt: int = int(meta.get("player_count", 2))
		UIKit.text_in(self, String(meta.get("map_name", "ARENA")), Rect2(shift + 152.0, 6.0, 250.0, 34.0), 30, Color.WHITE.lerp(UIKit.GOLD, maxf(s, hv)), HORIZONTAL_ALIGNMENT_LEFT, 5)
		UIKit.text_in(self, "%d PLAYERS  %s" % [pcnt, ("TEAMS" if bool(meta.get("team_mode", false)) else "")], Rect2(shift + 152.0, 38.0, 250.0, 22.0), 17, Color(1, 1, 1, 0.7 + 0.2 * hv), HORIZONTAL_ALIGNMENT_LEFT, 3)
		UIKit.text_in(self, ReplayStore.format_date(int(meta.get("created", 0))), Rect2(shift + 152.0, 58.0, 250.0, 20.0), 16, Color(1, 1, 1, 0.5 + 0.2 * hv), HORIZONTAL_ALIGNMENT_LEFT, 3)
		# potret pemain kecil
		var pl: Array = meta.get("players", [])
		for i in pl.size():
			var pd: Dictionary = pl[i]
			var pr2 := Rect2(shift + 352.0 + float(i) * 30.0, 46.0, 24.0, 24.0)
			draw_rect(Rect2(pr2.position - Vector2(2, 2), pr2.size + Vector2(4, 4)), pd["color"])
			draw_texture_rect(Global.character_texture(0, int(pd["char"])), pr2, false)
		# kanan: durasi, skor
		UIKit.text_in(self, ReplayStore.format_clock(float(meta.get("duration", 0.0))), Rect2(size.x - 250.0, 6.0, 190.0, 38.0), 34, UIKit.GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 6)
		var sc: String = String(meta.get("score", ""))
		if finished:
			UIKit.text_in(self, sc, Rect2(size.x - 330.0, 44.0, 270.0, 26.0), 22, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 4)
		else:
			UIKit.text_in(self, "UNFINISHED", Rect2(size.x - 330.0, 44.0, 270.0, 26.0), 20, Color("ff7a7a"), HORIZONTAL_ALIGNMENT_RIGHT, 4)
		if bool(meta.get("locked", false)):
			UIKit.draw_lock(self, Vector2(size.x - 44.0, 56.0), 26.0, UIKit.GOLD)
		# hover: garis emas menyapu di bawah kartu + panah "buka" yang bergoyang
		if hv > 0.01:
			draw_rect(Rect2(shift + 22.0, h - 5.0, (w - 70.0) * hv, 3.0), Color(UIKit.GOLD, 0.9 * hv))
			UIKit.draw_chevron(self, Vector2(size.x - 48.0 + sin(_t * 8.0) * 3.0, 22.0), 8.0, 1, Color(UIKit.GOLD, hv))
		# riak klik
		if ripple > 0.0:
			draw_arc(ripple_pos, (1.0 - ripple) * 130.0 + 6.0, 0.0, TAU, 36, Color(1, 1, 1, 0.65 * ripple), 3.0, true)
		draw_set_transform(Vector2.ZERO)


class DetailPanel extends Control:
	var meta: Dictionary = {}
	var swap: float = 1.0:
		set(v):
			swap = v
			queue_redraw()
	var _tw: Tween
	var _t: float = 0.0

	func _init() -> void:
		size = Vector2(436, 490)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_meta_data(m: Dictionary, animate: bool = true) -> void:
		var changed: bool = String(m.get("id", "")) != String(meta.get("id", ""))
		meta = m
		if _tw:
			_tw.kill()
		if animate and changed and is_inside_tree():
			swap = 0.0
			_tw = UIKit.tw(self)
			_tw.tween_property(self, "swap", 1.0, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		else:
			swap = 1.0
		queue_redraw()

	func _process(d: float) -> void:
		if visible:
			_t += d
			queue_redraw()

	func _draw() -> void:
		var pts: PackedVector2Array = UIKit.slanted(size.x, size.y, 20.0)
		draw_colored_polygon(UIKit.slanted(size.x, size.y, 20.0, 6.0, 8.0), Color(0, 0, 0, 0.45))
		var top := Color(0.07, 0.07, 0.15, 0.95)
		var bot := Color(0.04, 0.04, 0.1, 0.95)
		draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
		ReplayUI.shine(self, pts, size.x, size.y, fmod(_t * 0.25, 2.8) - 0.5, 0.04)
		draw_polyline(UIKit.closed(pts), Color(1, 1, 1, 0.25), 2.0, true)
		if meta.is_empty():
			return
		var ease_v: float = ReplayUI.ease_out_cubic(swap)
		var ca: float = clampf(swap * 2.2, 0.0, 1.0)
		draw_set_transform(Vector2(26.0 * (1.0 - ease_v), 0.0))
		var finished: bool = bool(meta.get("finished", true))
		# gambar arena (zoom pelan saat berganti)
		var pr := Rect2(34.0, 16.0, 376.0, 190.0)
		var tex: Texture2D = Global.map_background(String(meta.get("map_id", "earth")))
		if tex != null:
			var z: float = 1.0 + 0.08 * (1.0 - ease_v)
			var ts: Vector2 = tex.get_size()
			var sz: Vector2 = ts / z
			draw_texture_rect_region(tex, pr, Rect2((ts - sz) * 0.5, sz), Color(1, 1, 1, ca))
		draw_polygon(PackedVector2Array([pr.position + Vector2(0, 110), pr.position + Vector2(pr.size.x, 110), pr.end, Vector2(pr.position.x, pr.end.y)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.8 * ca), Color(0, 0, 0, 0.8 * ca)]))
		draw_rect(pr, Color(0, 0, 0, 0.85 * ca), false, 3.0)
		UIKit.text_in(self, String(meta.get("map_name", "ARENA")), Rect2(pr.position.x + 10.0, pr.end.y - 48.0, 320.0, 40.0), 34, Color(1, 1, 1, ca), HORIZONTAL_ALIGNMENT_LEFT, 8)
		if bool(meta.get("locked", false)):
			var lp := Vector2(pr.end.x - 24.0, pr.position.y + 24.0)
			draw_circle(lp, 18.0, Color(0, 0, 0, 0.6 * ca))
			UIKit.draw_lock(self, lp, 22.0, Color(UIKit.GOLD, ca))
		UIKit.text_in(self, ReplayStore.format_date(int(meta.get("created", 0))), Rect2(34.0, 212.0, 376.0, 26.0), 20, Color(1, 1, 1, 0.65 * ca), HORIZONTAL_ALIGNMENT_LEFT, 3)
		var stats: String = "%s   %d ROUNDS   %d KILLS" % [ReplayStore.format_clock(float(meta.get("duration", 0.0))), int(meta.get("rounds", 0)), int(meta.get("kills", 0))]
		UIKit.text_in(self, stats, Rect2(34.0, 240.0, 380.0, 30.0), 23, Color(UIKit.GOLD, ca), HORIZONTAL_ALIGNMENT_LEFT, 4)
		var wt: int = int(meta.get("winner_team", -1))
		if finished:
			var wc: Color = meta.get("winner_color", Color.WHITE)
			UIKit.text_in(self, "WINNER  %s" % String(meta.get("winner_label", "")), Rect2(34.0, 274.0, 380.0, 30.0), 24, Color(wc, ca), HORIZONTAL_ALIGNMENT_LEFT, 5)
			UIKit.text_in(self, "SCORE  %s" % String(meta.get("score", "")), Rect2(34.0, 302.0, 380.0, 26.0), 20, Color(1, 1, 1, 0.8 * ca), HORIZONTAL_ALIGNMENT_LEFT, 4)
		else:
			UIKit.text_in(self, "MATCH WAS NOT FINISHED", Rect2(34.0, 278.0, 380.0, 30.0), 22, Color(1.0, 0.48, 0.48, ca), HORIZONTAL_ALIGNMENT_LEFT, 4)
		# pemain (pemenang diberi bingkai emas)
		var pl: Array = meta.get("players", [])
		for i in pl.size():
			var pd: Dictionary = pl[i]
			var col: Color = pd["color"]
			var win: bool = finished and int(pd.get("team", -2)) == wt
			var pa: float = clampf(swap * 2.2 - float(i) * 0.15, 0.0, 1.0)
			var r := Rect2(38.0 + float(i) * 70.0, 338.0 - (1.0 - pa) * 10.0, 54.0, 54.0)
			draw_rect(Rect2(r.position - Vector2(3, 3), r.size + Vector2(6, 6)), Color(UIKit.GOLD if win else col, pa))
			draw_texture_rect(Global.character_texture(0, int(pd["char"])), r, false, Color(1, 1, 1, pa))
			if win:
				ReplayUI.draw_icon(self, "check", Vector2(r.end.x - 3.0, r.end.y - 3.0), 8.0, Color(UIKit.GREEN, pa))
			UIKit.text_in(self, "P%d" % (i + 1), Rect2(r.position.x - 8.0, r.end.y + 4.0, r.size.x + 16.0, 20.0), 16, Color(1, 1, 1, pa), HORIZONTAL_ALIGNMENT_CENTER, 4)
		draw_set_transform(Vector2.ZERO)


## Info jumlah replay + meter penyimpanan.
class InfoBar extends Control:
	var meter: float = 0.0
	var target: float = 0.0

	func _init() -> void:
		size = Vector2(700, 32)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func refresh() -> void:
		var lim: int = ReplayStore.max_replays()
		target = clampf(float(ReplayStore.count()) / float(lim), 0.0, 1.0) if lim > 0 else 0.0
		queue_redraw()

	func _process(d: float) -> void:
		if absf(meter - target) > 0.001:
			meter = lerpf(meter, target, 1.0 - exp(-d * 8.0))
			queue_redraw()

	func _draw() -> void:
		var n: int = ReplayStore.count()
		var lim: int = ReplayStore.max_replays()
		var t1: String = "%d / %s SAVED" % [n, ("UNLIMITED" if lim <= 0 else str(lim))]
		var t2: String = "%s USED" % ReplayStore.format_bytes(ReplayStore.total_bytes())
		UIKit.text_in(self, t1, Rect2(0, 0, 300, size.y), 22, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_LEFT, 4)
		var x: float = UIKit.text_w(t1, 22) + 18.0
		if lim > 0:
			draw_rect(Rect2(x, size.y * 0.5 - 5.0, 150.0, 10.0), Color(1, 1, 1, 0.14))
			var col: Color = UIKit.GREEN.lerp(Color("ff7a7a"), clampf((meter - 0.6) / 0.4, 0.0, 1.0))
			draw_rect(Rect2(x, size.y * 0.5 - 5.0, 150.0 * meter, 10.0), col)
			draw_rect(Rect2(x, size.y * 0.5 - 5.0, 150.0, 10.0), Color(0, 0, 0, 0.7), false, 2.0)
			x += 168.0
		UIKit.text_in(self, t2, Rect2(x, 0, 300, size.y), 22, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_LEFT, 4)


class ScrollInd extends Control:
	var pos: float = 0.0
	var maxs: float = 0.0
	var total: float = 0.0

	func _init() -> void:
		size = Vector2(8, LIST_H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_state(p: float, m: float, tot: float) -> void:
		if is_equal_approx(p, pos) and is_equal_approx(m, maxs) and is_equal_approx(tot, total):
			return
		pos = p
		maxs = m
		total = tot
		visible = m > 1.0
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(2, 0, 4, size.y), Color(1, 1, 1, 0.1))
		var th: float = maxf(size.y * LIST_H / maxf(total, 1.0), 44.0)
		var ty: float = (pos / maxf(maxs, 1.0)) * (size.y - th)
		draw_rect(Rect2(0, ty, 8, th), Color(UIKit.GOLD, 0.9))
		draw_rect(Rect2(0, ty, 8, th), Color(0, 0, 0, 0.6), false, 1.5)


class EmptyPanel extends Control:
	var t: float = 0.0

	func _init() -> void:
		size = Vector2(900, 340)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		if visible:
			t += d
			queue_redraw()

	func _draw() -> void:
		var pts: PackedVector2Array = UIKit.slanted(size.x, size.y, 24.0)
		draw_colored_polygon(UIKit.slanted(size.x, size.y, 24.0, 6.0, 8.0), Color(0, 0, 0, 0.45))
		draw_colored_polygon(pts, Color(0.05, 0.05, 0.12, 0.92))
		ReplayUI.shine(self, pts, size.x, size.y, fmod(t * 0.3, 2.6) - 0.5, 0.05)
		draw_polyline(UIKit.closed(pts), Color(1, 1, 1, 0.25), 2.0, true)
		# ikon rekam melayang + cincin berdenyut
		var c := Vector2(size.x * 0.5, 84.0 + sin(t * 2.0) * 4.0)
		for k in 2:
			var ph: float = fmod(t * 0.7 + float(k) * 0.5, 1.0)
			draw_arc(c, 40.0 + ph * 34.0, 0.0, TAU, 40, Color(1.0, 0.3, 0.35, (1.0 - ph) * 0.55), 3.0, true)
		draw_circle(c, 40.0, Color(1.0, 0.25, 0.3, 0.2))
		draw_arc(c, 40.0, 0.0, TAU, 40, Color(1.0, 0.3, 0.35), 4.0, true)
		draw_circle(c, 17.0, Color(1.0, 0.3, 0.35, 0.65 + 0.35 * sin(t * 4.0)))
		UIKit.text_in(self, "NO REPLAYS YET", Rect2(0, 130, size.x, 60), 52, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER, 9)
		var on: bool = ReplayStore.enabled
		UIKit.text_in(self, "PLAY A VERSUS MATCH WITH RECORDING ON.", Rect2(0, 200, size.x, 34), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5)
		UIKit.text_in(self, "THE WHOLE MATCH, FROM ROUND 1 UNTIL SOMEONE WINS, IS SAVED HERE.", Rect2(0, 234, size.x, 30), 21, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 4)
		var l3: String = "RECORDING IS CURRENTLY ON" if on else "RECORDING IS CURRENTLY OFF  -  TURN IT ON WITH THE REC BUTTON"
		UIKit.text_in(self, l3, Rect2(0, 278, size.x, 34), 24, UIKit.GREEN if on else Color("ff7a7a"), HORIZONTAL_ALIGNMENT_CENTER, 5)


# ================================================================== layar LIST
func _build_list() -> void:
	list_root = Control.new()
	list_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	list_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(list_root)

	banner = UIKit.Banner.new("REPLAYS", 52)
	banner.position = Vector2(50, 24)
	list_root.add_child(banner)

	info = InfoBar.new()
	info.position = Vector2(54, 96)
	list_root.add_child(info)

	chip_rec = ReplayUI.Chip.new("REC ON", Vector2(166, 46), UIKit.GREEN, 24, "rec")
	chip_rec.position = Vector2(752, 36)
	chip_rec.pressed.connect(_toggle_rec)
	chip_rec.hovered.connect(_on_chip_hover.bind(Z_HEADER, 0))
	list_root.add_child(chip_rec)
	chip_set = ReplayUI.Chip.new("SETTINGS", Vector2(194, 46), UIKit.GOLD, 24, "gear")
	chip_set.position = Vector2(924, 36)
	chip_set.pressed.connect(_open_settings)
	chip_set.hovered.connect(_on_chip_hover.bind(Z_HEADER, 1))
	list_root.add_child(chip_set)
	chip_back = ReplayUI.Chip.new("BACK", Vector2(116, 46), Color("ff7a7a"), 24, "back")
	chip_back.position = Vector2(1124, 36)
	chip_back.pressed.connect(_go_back)
	chip_back.hovered.connect(_on_chip_hover.bind(Z_HEADER, 2))
	list_root.add_child(chip_back)
	head_chips = [chip_rec, chip_set, chip_back]

	clip = Control.new()
	clip.position = Vector2(LIST_X, LIST_Y)
	clip.size = Vector2(CARD_W + 10.0, LIST_H)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_root.add_child(clip)

	scroll_ind = ScrollInd.new()
	scroll_ind.position = Vector2(LIST_X + CARD_W + 16.0, LIST_Y)
	scroll_ind.visible = false
	list_root.add_child(scroll_ind)

	detail = DetailPanel.new()
	detail.position = Vector2(802, LIST_Y)
	list_root.add_child(detail)

	var cy: float = LIST_Y + 428.0
	chip_watch = ReplayUI.Chip.new("WATCH", Vector2(122, 44), UIKit.GREEN, 18, "play")
	chip_watch.position = Vector2(820, cy)
	chip_watch.pressed.connect(_play_selected)
	chip_watch.hovered.connect(_on_chip_hover.bind(Z_ACTIONS, 0))
	list_root.add_child(chip_watch)
	chip_lock = ReplayUI.Chip.new("LOCK", Vector2(122, 44), UIKit.GOLD, 18, "lock")
	chip_lock.position = Vector2(950, cy)
	chip_lock.pressed.connect(_toggle_lock)
	chip_lock.hovered.connect(_on_chip_hover.bind(Z_ACTIONS, 1))
	list_root.add_child(chip_lock)
	chip_del = ReplayUI.Chip.new("DELETE", Vector2(122, 44), ReplayUI.DANGER, 18, "trash")
	chip_del.position = Vector2(1080, cy)
	chip_del.pressed.connect(_ask_delete)
	chip_del.hovered.connect(_on_chip_hover.bind(Z_ACTIONS, 2))
	list_root.add_child(chip_del)
	for c in [chip_watch, chip_lock, chip_del]:
		(c as ReplayUI.Chip).sk_override = 9.0
		(c as ReplayUI.Chip).icon_s = 11.0
		(c as ReplayUI.Chip).pad = 10.0
	act_chips = [chip_watch, chip_lock, chip_del]

	empty_panel = EmptyPanel.new()
	empty_panel.position = Vector2(190, 200)
	list_root.add_child(empty_panel)


## Membuat ulang kartu dari penyimpanan. animate = kartu masuk satu per satu.
func _refresh_list(animate: bool = false) -> void:
	replays = ReplayStore.list_replays()
	for c in cards:
		(c as Control).queue_free()
	cards.clear()
	for i in replays.size():
		var card := Card.new(replays[i])
		card.position = Vector2(0, float(i) * CARD_STEP - scroll)
		clip.add_child(card)
		cards.append(card)
		card.hovered.connect(_card_hover.bind(i))
		card.picked.connect(_card_pick.bind(i))
		if animate:
			card.intro = 0.0
			var t := UIKit.tw(card)
			t.tween_property(card, "intro", 1.0, 0.5).set_trans(Tween.TRANS_LINEAR).set_delay(0.05 * float(mini(i, 9)) + 0.12)
	sel = clampi(sel, 0, maxi(replays.size() - 1, 0))
	if animate:
		scroll = 0.0
	var has: bool = not replays.is_empty()
	clip.visible = has
	detail.visible = has
	chip_watch.visible = has
	chip_lock.visible = has
	chip_del.visible = has
	empty_panel.visible = not has
	if not has and zone != Z_HEADER:
		zone = Z_HEADER
	_select(sel, false)
	for k in cards.size():
		(cards[k] as Card).snap(k == sel)
	chip_rec.set_text("REC ON" if ReplayStore.enabled else "REC OFF")
	chip_rec.set_color(UIKit.GREEN if ReplayStore.enabled else Color("ff7a7a"))
	info.refresh()
	_apply_focus()
	if current == "list":
		_update_prompts()


func _select(i: int, sound: bool = true) -> void:
	if replays.is_empty():
		return
	i = clampi(i, 0, replays.size() - 1)
	if sound and i != sel:
		Global.play_sfx("ui_hover", -8.0)
	var changed: bool = i != sel
	sel = i
	for k in cards.size():
		(cards[k] as Card).selected = k == sel
		(cards[k] as Card).kfocus = k == sel and zone == Z_CARDS
	var m: Dictionary = replays[sel]
	detail.set_meta_data(m, sound or changed)
	chip_lock.text = "UNLOCK" if bool(m.get("locked", false)) else "LOCK"
	chip_lock.icon = "unlock" if bool(m.get("locked", false)) else "lock"
	chip_lock.queue_redraw()
	bg.set_image(Global.map_background(String(m.get("map_id", "hell"))), 0.78, 0.45)


func _card_hover(i: int) -> void:
	if current == "list" and not dialog.is_open and view == null and not busy:
		# suara hover kartu: nada naik sedikit untuk kartu yang lebih bawah; tetap berbunyi walau kartu ini sudah terpilih
		# (mis. kursor datang dari tombol lain)
		var fresh: bool = i != sel or zone != Z_CARDS
		_select(i, false)
		if zone != Z_CARDS:
			zone = Z_CARDS
		_apply_focus()
		if fresh and not leaving:
			Global.play_sfx("ui_hover", -6.0, 1.0 + 0.04 * float(mini(i, 8)))


func _card_pick(i: int) -> void:
	if current != "list" or dialog.is_open or view != null or busy:
		return
	if i == sel:
		_play_selected()
	else:
		_select(i)
		zone = Z_CARDS
		_apply_focus()


func _on_chip_hover(z: int, i: int) -> void:
	if current != "list" or dialog.is_open or view != null or busy:
		return
	if zone == z and (z == Z_HEADER and head_idx == i or z == Z_ACTIONS and act_idx == i):
		return
	zone = z
	if z == Z_HEADER:
		head_idx = i
	else:
		act_idx = i
	Global.play_sfx("ui_hover", -8.0)
	_apply_focus()


## Nyalakan hanya satu fokus (kartu / tombol aksi / tombol atas).
func _apply_focus() -> void:
	for k in cards.size():
		(cards[k] as Card).kfocus = k == sel and zone == Z_CARDS
	for i in head_chips.size():
		(head_chips[i] as ReplayUI.Chip).set_active(zone == Z_HEADER and head_idx == i)
	for i in act_chips.size():
		(act_chips[i] as ReplayUI.Chip).set_active(zone == Z_ACTIONS and act_idx == i)


func _set_zone(z: int) -> void:
	if z == zone:
		return
	zone = z
	Global.play_sfx("ui_hover", -8.0)
	_apply_focus()


func _clear_card_hover() -> void:
	for c in cards:
		(c as Card).clear_hover()


func _nav(dx: int, dy: int) -> void:
	_clear_card_hover()
	if replays.is_empty():
		if dx != 0:
			head_idx = clampi(head_idx + dx, 0, head_chips.size() - 1)
			Global.play_sfx("ui_hover", -8.0)
			_apply_focus()
		return
	match zone:
		Z_CARDS:
			if dy < 0:
				if sel == 0:
					_set_zone(Z_HEADER)
				else:
					_select(sel - 1)
			elif dy > 0:
				_select(sel + 1)
			elif dx > 0:
				act_idx = 0                      # dari kartu ke kanan = tombol WATCH
				if zone == Z_ACTIONS:
					_apply_focus()
				_set_zone(Z_ACTIONS)
		Z_ACTIONS:
			if dx != 0:
				if dx < 0 and act_idx == 0:
					_set_zone(Z_CARDS)
				else:
					var ni: int = clampi(act_idx + dx, 0, act_chips.size() - 1)
					if ni != act_idx:
						act_idx = ni
						Global.play_sfx("ui_hover", -8.0)
						_apply_focus()
			elif dy < 0:
				head_idx = clampi(act_idx, 0, head_chips.size() - 1)   # WATCH -> REC, LOCK -> SETTINGS, DELETE -> BACK
				_set_zone(Z_HEADER)
		Z_HEADER:
			if dx != 0:
				if dx < 0 and head_idx == 0:
					_set_zone(Z_CARDS)           # dari REC ke kiri = kartu replay
				else:
					var hi: int = clampi(head_idx + dx, 0, head_chips.size() - 1)
					if hi != head_idx:
						head_idx = hi
						Global.play_sfx("ui_hover", -8.0)
						_apply_focus()
			elif dy > 0:
				act_idx = clampi(head_idx, 0, act_chips.size() - 1)    # REC -> WATCH, SETTINGS -> LOCK, BACK -> DELETE
				_set_zone(Z_ACTIONS)


func _list_accept() -> void:
	match zone:
		Z_CARDS:
			_play_selected()
		Z_ACTIONS:
			(act_chips[act_idx] as ReplayUI.Chip).press()
		Z_HEADER:
			(head_chips[head_idx] as ReplayUI.Chip).press()


func _toggle_rec() -> void:
	ReplayStore.enabled = not ReplayStore.enabled
	ReplayStore.save_settings()
	Global.play_sfx("ui_toggle_on" if ReplayStore.enabled else "ui_toggle_off", -6.0)
	UIInput.toast("REPLAY RECORDING " + ("ON" if ReplayStore.enabled else "OFF"), "Versus matches", UIKit.GREEN if ReplayStore.enabled else Color("ff7a7a"))
	chip_rec.set_text("REC ON" if ReplayStore.enabled else "REC OFF")
	chip_rec.set_color(UIKit.GREEN if ReplayStore.enabled else Color("ff7a7a"))
	empty_panel.queue_redraw()


func _toggle_lock() -> void:
	if replays.is_empty() or busy:
		return
	var m: Dictionary = replays[sel]
	var now: bool = ReplayStore.toggle_lock(String(m["id"]))
	m["locked"] = now
	(cards[sel] as Card).meta = m
	(cards[sel] as Card).pop()
	_select(sel, false)
	detail.queue_redraw()
	Global.play_sfx("pu_heal", -6.0)
	UIKit.burst(list_root, Vector2(LIST_X + CARD_W - 60.0, LIST_Y + float(sel) * CARD_STEP - scroll + 56.0), UIKit.GOLD, 14, 220.0, 5.0, 0.6, 400.0)
	UIInput.toast("REPLAY LOCKED" if now else "REPLAY UNLOCKED", "Locked replays are never auto-deleted" if now else "", UIKit.GOLD)


func _ask_delete() -> void:
	if replays.is_empty() or busy:
		return
	_open_confirm("delete", "DELETE THIS REPLAY?", "This cannot be undone.", "DELETE")


## Subteks kartu judul transisi: jumlah pemain, mode tim, dan durasi.
func _curtain_sub(m: Dictionary) -> String:
	var res: String = "%d PLAYERS" % int(m.get("player_count", 2))
	if bool(m.get("team_mode", false)):
		res += "  -  TEAMS"
	return res + "  -  " + ReplayStore.format_clock(float(m.get("duration", 0.0)))


## LIST -> VIEW. Tirai menutup layar dulu, replay dimuat saat layar tertutup (jadi tidak ada patah-patah),
## lalu tirai terbuka dan video masuk dengan zoom-out halus.
func _play_selected() -> void:
	if replays.is_empty() or view != null or leaving or busy:
		return
	var m: Dictionary = replays[sel]
	busy = true
	_clear_card_hover()
	Global.play_sfx("ui_start", -4.0)
	Global.play_sfx("ui_whoosh", -10.0)
	curtain.setup("NOW PLAYING", String(m.get("map_name", "ARENA")), _curtain_sub(m), UIKit.GOLD)
	move_child(curtain, get_child_count() - 1)
	curtain.cover(0.4)
	await curtain.done
	await get_tree().process_frame            # pastikan kartu judul sempat tergambar sebelum proses berat

	# ---- muat replay selagi layar tertutup penuh
	var err: String = ""
	var v: ReplayView = null
	var data: Dictionary = ReplayStore.load_replay(String(m["id"]))
	if data.is_empty():
		err = "The file is damaged or from a newer version"
	else:
		v = ReplayView.new()
		add_child(v)
		if not v.open(data, m):
			v.queue_free()
			v = null
			err = "Data is incomplete"
	if v == null:
		Global.play_sfx("ui_error", -6.0)
		curtain.reveal(0.4)
		UIInput.toast("CANNOT OPEN REPLAY", err, Color("ff7a7a"))
		if sel >= 0 and sel < cards.size():
			(cards[sel] as Card).pop()
		await curtain.done
		busy = false
		return

	view = v
	v.closed.connect(_on_view_closed)
	v.main_menu_requested.connect(_on_view_main_menu)
	var autoplay: bool = v.playing
	v.start_hint = not autoplay                # replay dibuka dalam keadaan jeda: tampilkan petunjuk "REPLAY PAUSED"
	v.playing = false                          # replay baru mulai jalan setelah tirai terbuka (tidak ada adegan yang terlewat)
	v.intro_prepare()
	list_root.visible = false
	settings_root.visible = false
	bg.visible = false
	prompt.get_parent().visible = false
	move_child(curtain, get_child_count() - 1)
	# beri waktu beberapa frame supaya frame pertama video sudah tergambar di balik tirai
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout

	# ---- buka tirai
	Global.play_sfx("ui_panel", -9.0)
	v.intro_play()
	curtain.reveal(0.55)
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(v) and view == v and not v.exit_menu and not v.ended:
		v.playing = autoplay
	await curtain.done
	busy = false


## Dipilih MAIN MENU dari menu jeda replay (pemutar sudah ditutup lewat sinyal closed).
func _on_view_main_menu() -> void:
	if leaving:
		return
	leaving = true
	Global.goto("menu")


## VIEW -> LIST. Video membeku + sedikit zoom-in sementara tirai menutup, lalu daftar replay masuk dengan animasi.
func _on_view_closed() -> void:
	var v: ReplayView = view
	if v == null:
		return
	# Tunggu satu frame: kalau yang dipilih MAIN MENU, sinyal main_menu_requested menyusul dan transisi global yang dipakai.
	await get_tree().process_frame
	if leaving or not is_instance_valid(v):
		return
	while busy:
		await get_tree().process_frame
		if leaving or not is_instance_valid(v):
			return
	busy = true
	curtain.setup("BACK TO", "REPLAYS", "%d SAVED" % ReplayStore.count(), UIKit.GOLD)
	move_child(curtain, get_child_count() - 1)
	Global.play_sfx("ui_whoosh", -8.0)
	v.outro_play(0.4)
	curtain.cover(0.4)
	await curtain.done

	# ---- layar tertutup penuh: bereskan pemutar dan siapkan daftar
	if is_instance_valid(v):
		v.queue_free()
	view = null
	bg.visible = true
	prompt.get_parent().visible = true
	_restore_list()
	await get_tree().process_frame

	# ---- buka tirai, daftar replay masuk (judul membanting, kartu menyusul, dst)
	curtain.reveal(0.5)
	_intro()
	await curtain.done
	busy = false


## Tampilkan lagi layar daftar (dipakai setelah menonton). Kartu dibuat ulang dan masuk dengan animasi.
func _restore_list() -> void:
	current = "list"
	settings_root.visible = false
	list_root.visible = true
	list_root.modulate.a = 1.0
	list_root.position = Vector2.ZERO
	_refresh_list(true)
	# daftar langsung berada di posisi kartu terpilih (tanpa menggulir dari atas)
	var maxs: float = maxf(float(replays.size()) * CARD_STEP - LIST_H + 10.0, 0.0)
	scroll = clampf(float(sel) * CARD_STEP - CARD_STEP * 2.0, 0.0, maxs)
	_update_prompts()


# ================================================================== layar SETTINGS
## Spesifikasi baris: [label, jenis, kunci, pilihan, deskripsi]
func _tab_specs() -> Array:
	return [
		[
			["RECORDING", "toggle", "enabled", [], "Records every VERSUS match automatically, from round 1 until someone wins the match."],
			["QUALITY", "choice", "quality", ReplayStore.QUALITY_NAMES, "How many snapshots per second are saved. Higher is smoother but the file is bigger."],
			["KEEP UNFINISHED", "toggle", "keep_unfinished", [], "Also save matches you quit before they end (shown as UNFINISHED)."],
			["MAX REPLAYS", "choice", "limit_idx", ReplayStore.LIMIT_NAMES, "How many replays can be stored at the same time."],
			["AUTO DELETE", "toggle", "auto_delete", [], "ON: the oldest unlocked replay is deleted when full. OFF: recording stops when full."],
		],
		[
			["DEFAULT SPEED", "choice", "speed_idx", ReplayStore.SPEED_NAMES, "Playback speed used when a replay starts."],
			["SKIP TIME", "choice", "skip_idx", ReplayStore.SKIP_NAMES, "How far the skip back / forward buttons jump."],
			["KILL LEAD-IN", "choice", "lead_idx", ReplayStore.LEAD_NAMES, "Jumping to a kill starts a little before it so you see how it happened."],
			["KILL MARKERS", "toggle", "show_markers", [], "Show who got each kill (and when) on the progress bar."],
			["PLAYER CARDS", "toggle", "show_hud", [], "Show health, wins and kills for every player while watching."],
			["AUTO PLAY", "toggle", "autoplay", [], "Start playing immediately when a replay is opened."],
			["AUTO HIDE UI", "toggle", "autohide_ui", [], "Hide the control bar after a few seconds without input, like a video player."],
		],
		[
			["SOUND FX", "toggle", "play_sfx", [], "Gunshots, hits and eliminations are played during replays."],
			["MUSIC", "toggle", "play_music", [], "Play the battle music while watching a replay."],
			["LIST ORDER", "choice", "sort_idx", ReplayStore.SORT_NAMES, "Sorting of the replay list."],
		],
	]


func _get_val(key: String) -> float:
	match key:
		"enabled": return 1.0 if ReplayStore.enabled else 0.0
		"quality": return float(ReplayStore.quality)
		"keep_unfinished": return 1.0 if ReplayStore.keep_unfinished else 0.0
		"limit_idx": return float(ReplayStore.limit_idx)
		"auto_delete": return 1.0 if ReplayStore.auto_delete else 0.0
		"speed_idx": return float(ReplayStore.speed_idx)
		"skip_idx": return float(ReplayStore.skip_idx)
		"lead_idx": return float(ReplayStore.lead_idx)
		"show_markers": return 1.0 if ReplayStore.show_markers else 0.0
		"show_hud": return 1.0 if ReplayStore.show_hud else 0.0
		"autoplay": return 1.0 if ReplayStore.autoplay else 0.0
		"autohide_ui": return 1.0 if ReplayStore.autohide_ui else 0.0
		"play_sfx": return 1.0 if ReplayStore.play_sfx else 0.0
		"play_music": return 1.0 if ReplayStore.play_music else 0.0
		"sort_idx": return float(ReplayStore.sort_idx)
	return 0.0


func _set_val(key: String, v: float) -> void:
	var on: bool = v > 0.5
	var i: int = int(roundf(v))
	match key:
		"enabled": ReplayStore.enabled = on
		"quality": ReplayStore.quality = i
		"keep_unfinished": ReplayStore.keep_unfinished = on
		"limit_idx": ReplayStore.limit_idx = i
		"auto_delete": ReplayStore.auto_delete = on
		"speed_idx": ReplayStore.speed_idx = i
		"skip_idx": ReplayStore.skip_idx = i
		"lead_idx": ReplayStore.lead_idx = i
		"show_markers": ReplayStore.show_markers = on
		"show_hud": ReplayStore.show_hud = on
		"autoplay": ReplayStore.autoplay = on
		"autohide_ui": ReplayStore.autohide_ui = on
		"play_sfx": ReplayStore.play_sfx = on
		"play_music": ReplayStore.play_music = on
		"sort_idx": ReplayStore.sort_idx = i
	ReplayStore.save_settings()


## Kotak deskripsi: teks berganti dengan transisi halus (geser + pudar).
class DescBox extends Control:
	var text: String = ""
	var shown: String = ""
	var swap: float = 1.0:
		set(v):
			swap = v
			queue_redraw()
	var _tw: Tween

	func _init() -> void:
		size = Vector2(1000, 74)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_text(t: String, animate: bool = true) -> void:
		if t == text:
			return
		text = t
		shown = t
		if _tw:
			_tw.kill()
		if animate and is_inside_tree():
			swap = 0.0
			_tw = UIKit.tw(self)
			_tw.tween_property(self, "swap", 1.0, 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		else:
			swap = 1.0

	func _draw() -> void:
		var pts: PackedVector2Array = UIKit.slanted(size.x, size.y, 14.0)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.5))
		draw_polyline(UIKit.closed(pts), Color(1, 1, 1, 0.16), 2.0, true)
		draw_colored_polygon(UIKit.slanted(6.0, size.y, 14.0, 0.0, 0.0), Color(UIKit.GOLD, 0.8))
		var e: float = ReplayUI.ease_out_cubic(swap)
		ReplayUI.draw_icon(self, "info", Vector2(52.0, size.y * 0.5), 14.0, Color(UIKit.GOLD, e))
		UIKit.text_in(self, shown, Rect2(84.0 + (1.0 - e) * 18.0, 0, size.x - 120, size.y), 22, Color(1, 1, 1, 0.88 * e), HORIZONTAL_ALIGNMENT_LEFT, 3)


## Meter penyimpanan di tab terakhir.
class StorageBar extends Control:
	func _init() -> void:
		size = Vector2(740, 40)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n: int = ReplayStore.count()
		var lim: int = ReplayStore.max_replays()
		var t1: String = "STORED: %d REPLAYS  -  %s" % [n, ReplayStore.format_bytes(ReplayStore.total_bytes())]
		UIKit.text_in(self, t1, Rect2(0, 0, 520, size.y), 22, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_LEFT, 3)
		if lim > 0:
			var x: float = size.x - 190.0
			var f: float = clampf(float(n) / float(lim), 0.0, 1.0)
			draw_rect(Rect2(x, size.y * 0.5 - 5.0, 170.0, 10.0), Color(1, 1, 1, 0.14))
			draw_rect(Rect2(x, size.y * 0.5 - 5.0, 170.0 * f, 10.0), UIKit.GREEN.lerp(Color("ff7a7a"), clampf((f - 0.6) / 0.4, 0.0, 1.0)))
			draw_rect(Rect2(x, size.y * 0.5 - 5.0, 170.0, 10.0), Color(0, 0, 0, 0.7), false, 2.0)


## Garis emas yang meluncur di bawah tab yang aktif.
class TabLine extends Control:
	func _init() -> void:
		size = Vector2(250, 8)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_colored_polygon(UIKit.slanted(size.x - 10.0, 6.0, 8.0, 0.0, 0.0), UIKit.GOLD)
		draw_colored_polygon(UIKit.slanted(size.x - 10.0, 6.0, 8.0, 0.0, 0.0), Color(1, 1, 1, 0.18 + 0.12 * sin(Time.get_ticks_msec() / 220.0)))

	func _process(_d: float) -> void:
		queue_redraw()


func _build_settings() -> void:
	settings_root = Control.new()
	settings_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(settings_root)

	set_banner = UIKit.Banner.new("REPLAY SETTINGS", 52)
	set_banner.position = Vector2(50, 24)
	settings_root.add_child(set_banner)
	set_auto = UIKit.Banner.new("AUTO-SAVED", 24, UIKit.GREEN, UIKit.INK, 18.0)
	set_auto.position = Vector2(set_banner.position.x + set_banner.size.x + 24.0, 38)
	settings_root.add_child(set_auto)

	set_back = ReplayUI.Chip.new("BACK", Vector2(116, 46), Color("ff7a7a"), 24, "back")
	set_back.position = Vector2(1124, 36)
	set_back.pressed.connect(_go_back)
	set_back.hovered.connect(_on_set_head_hover.bind(3))
	settings_root.add_child(set_back)

	var names: Array = ["RECORDING", "PLAYBACK", "AUDIO & LIST"]
	var icons: Array = ["rec", "play", "sound"]
	for k in 3:
		var c := ReplayUI.Chip.new(String(names[k]), Vector2(250, 44), UIKit.GOLD, 24, String(icons[k]))
		c.position = Vector2(270.0 + float(k) * 262.0, 108)
		c.icon_left = true
		c.pressed.connect(_set_tab.bind(k))
		c.hovered.connect(_on_set_head_hover.bind(k))
		settings_root.add_child(c)
		tab_chips.append(c)
	set_head_chips = tab_chips.duplicate()
	set_head_chips.append(set_back)
	tab_line = TabLine.new()
	tab_line.position = Vector2(270, 156)
	settings_root.add_child(tab_line)

	var specs: Array = _tab_specs()
	for t in 3:
		var root := Control.new()
		root.set_anchors_preset(Control.PRESET_FULL_RECT)
		root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		settings_root.add_child(root)
		tab_roots.append(root)
		var items: Array = []
		var descs: Array = []
		var rows: Array = specs[t]
		for i in rows.size():
			var sp: Array = rows[i]
			var row := UIKit.SettingRow.new(String(sp[0]), String(sp[1]), _get_val(String(sp[2])), Vector2(740, 46))
			if String(sp[1]) == "choice":
				row.options = sp[3]
			row.position = Vector2(270, 172.0 + float(i) * 50.0)
			row.set_meta("base", row.position)
			row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			root.add_child(row)
			items.append(row)
			descs.append(String(sp[4]))
			row.hovered.connect(_row_hover.bind(t, i))
			row.changed.connect(_row_changed.bind(t, i))
		if t == 2:
			var y: float = 172.0 + float(rows.size()) * 50.0 + 6.0
			var b1 := UIKit.FancyButton.new("DELETE ALL REPLAYS", Vector2(470, 46), 28)
			b1.accent = Color("ff5a5a")
			b1.tag = "PERMANENT"
			b1.position = Vector2(270, y)
			b1.set_meta("base", b1.position)
			b1.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b1.activated.connect(_ask_delete_all)
			b1.hovered.connect(_row_hover.bind(t, items.size()))
			root.add_child(b1)
			items.append(b1)
			descs.append("Permanently removes every saved replay, including locked ones.")
			var b2 := UIKit.FancyButton.new("RESET REPLAY SETTINGS", Vector2(470, 46), 28)
			b2.position = Vector2(270, y + 50.0)
			b2.set_meta("base", b2.position)
			b2.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b2.activated.connect(_reset_settings)
			b2.hovered.connect(_row_hover.bind(t, items.size()))
			root.add_child(b2)
			items.append(b2)
			descs.append("Puts all replay options back to their default values.")
			var st := StorageBar.new()
			st.position = Vector2(270, y + 106.0)
			st.set_meta("base", st.position)
			root.add_child(st)
		tab_items.append(items)
		tab_desc.append(descs)

	desc_box = DescBox.new()
	desc_box.position = Vector2(140, 546)
	settings_root.add_child(desc_box)


func _set_tab(k: int) -> void:
	if k == tab:
		return
	var dir: int = 1 if k > tab else -1
	tab = k
	Global.play_sfx("ui_marimba", -9.0)
	_apply_tab(dir, true)


func _apply_tab(dir: int = 1, animate: bool = false) -> void:
	for t in tab_roots.size():
		(tab_roots[t] as Control).visible = t == tab
		(tab_chips[t] as ReplayUI.Chip).set_active(t == tab, not animate)
	var tx: float = 270.0 + float(tab) * 262.0
	if animate and is_inside_tree():
		UIKit.tw(tab_line).tween_property(tab_line, "position:x", tx, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_stagger_tab(tab, dir)
	else:
		tab_line.position.x = tx
	_tab_select(int(tab_idx[tab]), false)
	_apply_set_focus()


## Baris-baris tab masuk satu per satu dari arah tab sebelumnya.
func _stagger_tab(k: int, dir: int) -> void:
	var root: Control = tab_roots[k]
	for ch in root.get_children():
		var c: Control = ch
		if not c.has_meta("base"):
			continue
		var base: Vector2 = c.get_meta("base")
		var idx: int = c.get_index()
		c.position = base + Vector2(70.0 * float(dir), 0.0)
		c.modulate.a = 0.0
		var d: float = 0.035 * float(idx)
		var t := UIKit.tw(c)
		t.set_parallel(true)
		t.tween_property(c, "position", base, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(d)
		t.tween_property(c, "modulate:a", 1.0, 0.18).set_delay(d)


func _tab_select(i: int, sound: bool = true) -> void:
	var items: Array = tab_items[tab]
	i = clampi(i, 0, items.size() - 1)
	if sound and i != int(tab_idx[tab]):
		Global.play_sfx("ui_hover", -8.0)
	tab_idx[tab] = i
	for k in items.size():
		(items[k] as Control).set_selected(k == i and set_zone == S_ROWS)
	if set_zone == S_ROWS:
		var d: Array = tab_desc[tab]
		desc_box.set_text(String(d[i]), sound)


func _row_hover(t: int, i: int) -> void:
	if current == "settings" and t == tab and not dialog.is_open and view == null and not busy:
		if set_zone != S_ROWS:
			set_zone = S_ROWS
			if i == int(tab_idx[tab]):
				Global.play_sfx("ui_hover", -8.0)
		_tab_select(i)
		_apply_set_focus()


## Kursor mouse masuk ke tab / tombol BACK di bagian atas settings (i: 0..2 = tab, 3 = BACK).
func _on_set_head_hover(i: int) -> void:
	if current != "settings" or dialog.is_open or view != null or busy or leaving:
		return
	if set_zone == S_HEAD and set_head_idx == i:
		return
	set_zone = S_HEAD
	set_head_idx = i
	Global.play_sfx("ui_hover", -8.0)
	_apply_set_focus()


## Pindah fokus settings antara baris (bawah) dan tombol atas.
func _set_set_zone(z: int) -> void:
	if z == set_zone:
		return
	set_zone = z
	if z == S_HEAD:
		set_head_idx = tab
	Global.play_sfx("ui_hover", -8.0)
	_apply_set_focus()
	if z == S_ROWS:
		_tab_select(int(tab_idx[tab]), false)


func _set_head_move(dx: int) -> void:
	var ni: int = clampi(set_head_idx + dx, 0, set_head_chips.size() - 1)
	if ni == set_head_idx:
		return
	set_head_idx = ni
	Global.play_sfx("ui_hover", -8.0)
	_apply_set_focus()


## Nyalakan hanya satu fokus di settings: salah satu tombol atas ATAU satu baris.
func _apply_set_focus() -> void:
	if tab_items.is_empty() or set_head_chips.is_empty():
		return
	for i in set_head_chips.size():
		(set_head_chips[i] as ReplayUI.Chip).set_focus(set_zone == S_HEAD and set_head_idx == i)
	var items: Array = tab_items[tab]
	var ri: int = clampi(int(tab_idx[tab]), 0, items.size() - 1)
	for k in items.size():
		(items[k] as Control).set_selected(set_zone == S_ROWS and k == ri)
	if set_zone == S_HEAD:
		var hints: Array = [
			"Recording options: what gets saved, quality, storage limit and auto delete.",
			"Playback options: speed, skipping, kill markers and the on-screen controls.",
			"Sound options while watching and the order of the replay list.",
			"Go back to the replay list. Every change is already saved automatically.",
		]
		desc_box.set_text(String(hints[clampi(set_head_idx, 0, hints.size() - 1)]), true)
	else:
		desc_box.set_text(String((tab_desc[tab] as Array)[ri]), true)


func _row_changed(v: float, t: int, i: int) -> void:
	var sp: Array = (_tab_specs()[t] as Array)[i]
	_set_val(String(sp[2]), v)


func _open_settings() -> void:
	if current == "settings":
		return
	Global.play_sfx("ui_panel", -5.0)
	_show("settings")


func _reset_settings() -> void:
	ReplayStore.reset_settings()
	Global.play_sfx("pu_heal", -6.0)
	UIInput.toast("REPLAY SETTINGS RESET", "Back to default", UIKit.GREEN)
	var specs: Array = _tab_specs()
	for t in 3:
		var rows: Array = specs[t]
		for i in rows.size():
			var row: UIKit.SettingRow = tab_items[t][i]
			row.value = _get_val(String((rows[i] as Array)[2]))
			row.queue_redraw()


func _ask_delete_all() -> void:
	if ReplayStore.count() == 0:
		Global.play_sfx("ui_error", -8.0)
		UIInput.toast("NOTHING TO DELETE", "There are no saved replays", Color(1, 1, 1, 0.8))
		return
	_open_confirm("all", "DELETE ALL REPLAYS?", "%d replays will be removed for good." % ReplayStore.count(), "DELETE ALL")


# ================================================================== konfirmasi
func _open_confirm(mode: String, title: String, text: String, yes_label: String) -> void:
	confirm_mode = mode
	prompt.set_prompts([[&"dpad_lr", "SELECT"], [&"accept", "CONFIRM"], [&"back", "CANCEL"]])
	dialog.open(title, text, yes_label, ReplayUI.DANGER, "trash")


func _on_confirm_cancel() -> void:
	confirm_mode = ""
	_update_prompts()


func _confirm_yes() -> void:
	var mode: String = confirm_mode
	confirm_mode = ""
	_update_prompts()
	if mode == "delete" and not replays.is_empty():
		var idx: int = sel
		var id: String = String((replays[idx] as Dictionary)["id"])
		Global.play_sfx("hit", -6.0)
		UIInput.toast("REPLAY DELETED", "", Color("ff7a7a"))
		_remove_card(idx, func() -> void:
			ReplayStore.delete_replay(id)
			_refresh_list(false))
	elif mode == "all":
		ReplayStore.delete_all()
		Global.play_sfx("hit", -6.0)
		UIInput.toast("ALL REPLAYS DELETED", "", Color("ff7a7a"))
		_refresh_list(false)
		for r in tab_items[2]:
			(r as Control).queue_redraw()
		for ch in (tab_roots[2] as Control).get_children():
			(ch as Control).queue_redraw()


## Kartu mengecil + pudar + percikan, baru dihapus sungguhan.
func _remove_card(i: int, done: Callable) -> void:
	if i < 0 or i >= cards.size():
		done.call()
		return
	busy = true
	var card: Card = cards[i]
	UIKit.burst(list_root, Vector2(LIST_X + CARD_W * 0.5, LIST_Y + float(i) * CARD_STEP - scroll + 44.0), ReplayUI.DANGER, 22, 300.0, 6.0, 0.6, 500.0)
	var t := UIKit.tw(card)
	t.tween_property(card, "intro", 0.0, 0.25).set_trans(Tween.TRANS_LINEAR)
	t.tween_callback(func() -> void:
		busy = false
		done.call())


# ================================================================== navigasi
## Pindah layar dengan transisi: layar lama meluncur keluar, layar baru meluncur masuk.
func _show(name_id: String, animate: bool = true) -> void:
	var old_name: String = current
	current = name_id
	var new_root: Control = list_root if name_id == "list" else settings_root
	var old_root: Control = settings_root if name_id == "list" else list_root
	if _root_tw:
		_root_tw.kill()
	var entering_settings: bool = name_id == "settings"
	new_root.visible = true
	if name_id == "list":
		_refresh_list(animate and old_name != "list")
	else:
		set_zone = S_ROWS
		_apply_tab(1, false)
		_stagger_tab(tab, 1)
		desc_box.set_text(String((tab_desc[tab] as Array)[int(tab_idx[tab])]), false)
	if not animate or old_name == name_id:
		new_root.modulate.a = 1.0
		new_root.position = Vector2.ZERO
		old_root.visible = false
		_update_prompts()
		return
	var dirx: float = 1.0 if entering_settings else -1.0
	new_root.modulate.a = 0.0
	new_root.position = Vector2(70.0 * dirx, 0.0)
	_root_tw = UIKit.tw(self)
	_root_tw.set_parallel(true)
	_root_tw.tween_property(new_root, "modulate:a", 1.0, 0.24)
	_root_tw.tween_property(new_root, "position", Vector2.ZERO, 0.34).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_root_tw.tween_property(old_root, "modulate:a", 0.0, 0.14)
	_root_tw.tween_property(old_root, "position", Vector2(-70.0 * dirx, 0.0), 0.16).set_trans(Tween.TRANS_QUAD)
	_root_tw.chain().tween_callback(func() -> void:
		if current != old_name:
			old_root.visible = false
			old_root.modulate.a = 1.0
			old_root.position = Vector2.ZERO)
	_update_prompts()


func _update_prompts() -> void:
	match current:
		"list":
			if replays.is_empty():
				prompt.set_prompts([[&"dpad_lr", "SELECT"], [&"accept", "OK"], [&"next", "SETTINGS"], [&"back", "BACK"]])
			else:
				prompt.set_prompts([[&"dpad_ud", "SELECT"], [&"accept", "WATCH"], [&"extra", "LOCK"], [&"alt", "DELETE", {"key": "DEL"}], [&"next", "SETTINGS"], [&"back", "BACK"]])
		"settings":
			prompt.set_prompts([[&"dpad_ud", "NAVIGATE"], [&"dpad_lr", "CHANGE"], [&"prev", "TAB"], [&"next", "TAB"], [&"back", "BACK"]])


func _go_back() -> void:
	if current == "settings":
		Global.play_sfx("ui_back", -5.0)
		_show("list")
		return
	if leaving:
		return
	leaving = true
	Global.goto("menu")


func _on_input(_source: int, action: StringName) -> void:
	if leaving or view != null:
		return
	if dialog.is_open:
		dialog.handle(action)
		return
	if busy:
		return
	if current == "list":
		match action:
			&"up": _nav(0, -1)
			&"down": _nav(0, 1)
			&"left": _nav(-1, 0)
			&"right": _nav(1, 0)
			&"accept": _list_accept()
			&"extra": _toggle_lock()
			&"alt": _ask_delete()
			&"next", &"start": _open_settings()
			&"back": _go_back()
	elif current == "settings":
		var items: Array = tab_items[tab]
		var i: int = int(tab_idx[tab])
		if set_zone == S_HEAD:
			# fokus di tab / tombol BACK (atas)
			match action:
				&"left": _set_head_move(-1)
				&"right": _set_head_move(1)
				&"down": _set_set_zone(S_ROWS)
				&"accept": (set_head_chips[set_head_idx] as ReplayUI.Chip).press()
				&"prev": _set_tab(posmod(tab - 1, 3))
				&"next": _set_tab(posmod(tab + 1, 3))
				&"back": _go_back()
			return
		match action:
			&"up":
				if i == 0:
					_set_set_zone(S_HEAD)        # dari baris pertama naik ke tab di atasnya
				else:
					_tab_select(i - 1)
			&"down": _tab_select(posmod(i + 1, items.size()))
			&"left":
				if items[i] is UIKit.SettingRow:
					(items[i] as UIKit.SettingRow).adjust(-1)
			&"right":
				if items[i] is UIKit.SettingRow:
					(items[i] as UIKit.SettingRow).adjust(1)
			&"accept":
				if items[i] is UIKit.FancyButton:
					(items[i] as UIKit.FancyButton).press()
				elif items[i] is UIKit.SettingRow:
					var row: UIKit.SettingRow = items[i]
					if row.kind == "toggle" or row.kind == "choice":
						row.adjust(1)
			&"prev": _set_tab(posmod(tab - 1, 3))
			&"next": _set_tab(posmod(tab + 1, 3))
			&"back": _go_back()


func _unhandled_key_input(event: InputEvent) -> void:
	if view != null or dialog.is_open or current != "list" or busy:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_DELETE:
		_ask_delete()


func _gui_input(event: InputEvent) -> void:
	# roda mouse = geser pilihan di daftar
	if view != null or current != "list" or dialog.is_open or busy:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_clear_card_hover()
			_select(sel - 1)
			zone = Z_CARDS
			_apply_focus()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_clear_card_hover()
			_select(sel + 1)
			zone = Z_CARDS
			_apply_focus()
