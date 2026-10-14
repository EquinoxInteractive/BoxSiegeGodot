class_name AboutUI
extends RefCounted
## Komponen UI untuk layar ABOUT US. Semua digambar lewat kode dan memakai bahasa visual yang sama
## dengan menu lain (UIKit): bentuk miring, kilau berjalan, fokus yang halus, mouse + keyboard + controller.
##
##   AboutButton   tombol "ABOUT US" di pojok kiri atas menu utama
##   AboutPanel    panel berhalaman (tab ABOUT / TEAM / INFO / LEGAL) yang ditampilkan di layar "about"
##   PageView      isi tiap halaman (dipakai AboutPanel)
##
## ISI / TEKS / LOGO diubah di `about_data.gd`, bukan di file ini.

const BODY_FONT_PATH := "res://assets/fonts/lilita_one.ttf"
const ACCENT := Color("4fd8ff")

static var _tex_cache := {}
static var _body_font: Font = null


# ------------------------------------------------------------------ helper statis
## Memuat gambar (dengan cache). Mengembalikan null kalau file belum ada / belum di-import.
static func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_tex_cache[path] = t
	return t


## Minta Godot memuat gambar + font di THREAD LAIN (tidak memblok game). Panggil sedini mungkin (menu.gd _ready).
## Saat nanti dipakai, load() sudah selesai / tinggal mengambil dari cache sehingga tidak ada patah.
static func preload_assets() -> void:
	var paths: Array = [BODY_FONT_PATH, AboutData.STUDIO_LOGO]
	for m in AboutData.TEAM:
		var d: Dictionary = m
		paths.append(String(d.get("logo", "")))
	for c in AboutData.CONTACT:
		var cd: Dictionary = c
		paths.append(String(cd.get("icon", "")))
	for p in paths:
		var path: String = String(p)
		if path != "" and ResourceLoader.exists(path) and not _tex_cache.has(path):
			ResourceLoader.load_threaded_request(path)


## Daftar pekerjaan pemanasan glyph: tiap elemen = [font, ukuran, outline, teks pendek].
## Menggambar sebuah glyph untuk PERTAMA KALI itu mahal (font dirasterisasi + dimasukkan ke atlas tekstur, apalagi yang
## berkontur). Daftar ini mencerminkan semua teks di layar About (ukuran + tebal kontur yang SAMA dengan _draw di bawah),
## lalu GlyphWarmer menggambarnya sedikit demi sedikit di balik layar, sehingga saat About dibuka semuanya sudah siap.
static func glyph_jobs() -> Array:
	var jobs: Array = []
	var tf: Font = UIKit.font()
	var bf: Font = body_font()
	# ---- halaman ABOUT (paling sering dibuka pertama)
	_job(jobs, tf, 52, 0, AboutData.SCREEN_TITLE)
	_job(jobs, tf, 30, 0, "BACK")
	_job(jobs, tf, 28, 0, "".join(AboutData.PAGE_TITLES))
	_job(jobs, tf, 24, 4, "0123456789/")
	_job(jobs, tf, 48, 7, AboutData.STUDIO_NAME_TOP)
	_job(jobs, tf, 34, 6, AboutData.STUDIO_NAME_BOTTOM)
	_job(jobs, tf, 16, 3, AboutData.STUDIO_TAGLINE)
	_job(jobs, tf, 40, 6, AboutData.ABOUT_HEADING)
	_job(jobs, tf, 19, 4, AboutData.MESSAGE_HEADING)
	_job(jobs, tf, 84, 0, "\u201c")
	_job(jobs, tf, 16, 3, "\u2014 " + AboutData.MESSAGE_SIGNATURE)
	var all_body: String = "".join([
		AboutData.fill(AboutData.ABOUT_TEXT), AboutData.fill(AboutData.MESSAGE_TEXT),
		AboutData.fill(AboutData.ACK_TEXT), AboutData.fill(AboutData.LEGAL_TEXT_1),
		AboutData.fill(AboutData.LEGAL_TEXT_2)])
	for fs in range(22, 14, -1):
		_job(jobs, bf, fs, 0, all_body)
	# ---- halaman TEAM
	_job(jobs, tf, 40, 6, AboutData.TEAM_HEADING)
	_job(jobs, tf, 17, 3, AboutData.TEAM_STUDIO_LABEL)
	_job(jobs, tf, 26, 5, AboutData.STUDIO_NAME_TOP + " " + AboutData.STUDIO_NAME_BOTTOM)
	var names := ""
	var roles := ""
	for m in AboutData.TEAM:
		var d: Dictionary = m
		names += String(d.get("name", ""))
		for r in d.get("roles", []):
			roles += String(r)
	_job(jobs, tf, 42, 7, names)
	_job(jobs, tf, 21, 3, roles)
	_job(jobs, tf, 16, 3, AboutData.TEAM_HINT)
	# ---- halaman INFO
	_job(jobs, tf, 38, 6, AboutData.TECH_HEADING + AboutData.CONTACT_HEADING)
	var t_labels := ""
	var t_values := ""
	for row in AboutData.TECH_INFO:
		t_labels += String(row[0])
		t_values += String(row[1])
	_job(jobs, tf, 21, 3, t_labels)
	_job(jobs, tf, 30, 5, t_values)
	var c_badges := ""
	var c_labels := ""
	var c_values := ""
	for c in AboutData.CONTACT:
		var cd: Dictionary = c
		c_badges += String(cd.get("badge", ""))
		c_labels += String(cd.get("label", ""))
		c_values += String(cd.get("value", ""))
	_job(jobs, tf, 17, 3, c_badges)
	_job(jobs, tf, 20, 3, c_badges)
	_job(jobs, tf, 15, 3, c_labels)
	_job(jobs, tf, 28, 5, c_values)
	_job(jobs, tf, 14, 3, AboutData.CONTACT_HINT)
	# ---- halaman LEGAL
	_job(jobs, tf, 38, 6, AboutData.ACK_HEADING + AboutData.LEGAL_HEADING)
	_job(jobs, tf, 30, 5, AboutData.fill(AboutData.LEGAL_COPYRIGHT))
	_job(jobs, tf, 19, 4, AboutData.fill(AboutData.LEGAL_RIGHTS))
	return jobs


## Pecah teks menjadi potongan kecil berisi karakter unik (maks 8 huruf) supaya tiap pekerjaan sangat ringan.
static func _job(jobs: Array, f: Font, fs: int, outline: int, s: String) -> void:
	var seen := {}
	var chunk: String = ""
	for i in s.length():
		var ch: String = s[i]
		if ch == " " or seen.has(ch):
			continue
		seen[ch] = true
		chunk += ch
		if chunk.length() >= 8:
			jobs.append([f, fs, outline, chunk])
			chunk = ""
	if chunk != "":
		jobs.append([f, fs, outline, chunk])


## Font untuk paragraf (lebih mudah dibaca daripada font judul). Cadangan: font UI game.
static func body_font() -> Font:
	if _body_font == null:
		if ResourceLoader.exists(BODY_FONT_PATH):
			_body_font = load(BODY_FONT_PATH) as Font
		if _body_font == null:
			_body_font = UIKit.font()
	return _body_font


## Titik tengah horizontal sebuah panel miring pada ketinggian y (y relatif terhadap atas panel).
static func cx(r: Rect2, skew: float, y: float) -> float:
	return r.position.x + (r.size.x + skew * (1.0 - 2.0 * y / r.size.y)) * 0.5


## Gambar potret / logo di dalam lingkaran dengan cincin warna. Kalau gambar tidak ada, tampil huruf awal.
static func draw_avatar(ci: CanvasItem, texture: Texture2D, c: Vector2, r: float, ring: Color,
		ring_w: float = 5.0, letter: String = "", bg: Color = Color(0.08, 0.08, 0.18), zoom: float = 1.0) -> void:
	ci.draw_circle(c + Vector2(4, 6), r + ring_w, Color(0, 0, 0, 0.45))
	ci.draw_circle(c, r, bg)
	if texture != null:
		var seg := 56
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in seg:
			var a: float = TAU * float(i) / float(seg)
			var d := Vector2(cos(a), sin(a))
			pts.append(c + d * r)
			uvs.append(Vector2(0.5, 0.5) + d * 0.5 * zoom)   # zoom > 1 = gambar tampil lebih kecil di dalam lingkaran
		ci.draw_colored_polygon(pts, Color.WHITE, uvs, texture)
	elif letter != "":
		UIKit.text_in(ci, letter.substr(0, 1).to_upper(), Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), int(r * 1.1), ring.lightened(0.3), HORIZONTAL_ALIGNMENT_CENTER, 4)
	ci.draw_arc(c, r + ring_w * 0.5, 0.0, TAU, 64, ring, ring_w, true)


## Warna pada gradasi (daftar warna hex, t = 0..1).
static func grad_color(stops: Array, t: float) -> Color:
	if stops.is_empty():
		return Color.WHITE
	if stops.size() == 1:
		return Color(String(stops[0]))
	var f: float = clampf(t, 0.0, 1.0) * float(stops.size() - 1)
	var i: int = mini(int(f), stops.size() - 2)
	return Color(String(stops[i])).lerp(Color(String(stops[i + 1])), f - float(i))


## Lencana logo bulat untuk baris CONTACT: lingkaran (warna / gradasi) + cincin aksen + logo putih di tengah.
## icon = null -> tampil teks cadangan (fallback). dim = redupkan (baris tanpa link). on = baris sedang terpilih.
static func draw_badge(ci: CanvasItem, icon: Texture2D, c: Vector2, r: float, accent: Color, fill: Color,
		gradient: Array = [], fallback: String = "", dim: bool = false, on: bool = false) -> void:
	var a: float = 0.55 if dim else 1.0
	ci.draw_circle(c + Vector2(3, 5), r + 3.0, Color(0, 0, 0, 0.45 * a))
	if gradient.size() >= 2:
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for i in 48:
			var ang: float = TAU * float(i) / 48.0
			var d := Vector2(cos(ang), sin(ang))
			pts.append(c + d * r)
			# gradasi diagonal: kiri-bawah (t = 0) -> kanan-atas (t = 1)
			var t: float = 0.5 + (d.x - d.y) * 0.3536
			var col: Color = grad_color(gradient, t)
			col.a = a
			cols.append(col)
		ci.draw_polygon(pts, cols)
	else:
		ci.draw_circle(c, r, Color(fill, a))
	if icon != null:
		var gs: float = r * 1.3
		ci.draw_texture_rect(icon, Rect2(c - Vector2(gs, gs) * 0.5, Vector2(gs, gs)), false, Color(1, 1, 1, a))
	elif fallback != "":
		UIKit.text_in(ci, fallback, Rect2(c.x - r, c.y - r, r * 2.0, r * 2.0), 20, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 3)
	var ring: Color = accent.lerp(Color.WHITE, 0.55 if on else 0.0)
	ci.draw_arc(c, r, 0.0, TAU, 48, Color(ring, 0.95 * a), 4.0 if on else 3.0, true)


## Buka link di browser bawaan (atau tampilkan toast kalau link kosong). Link boleh apa saja (http, https, mailto, dll).
static func open_link(url: String, title: String, shown: String, accent: Color) -> void:
	if url == "":
		Global.play_sfx("ui_error", -10.0)
		UIInput.toast(title, shown, accent)
		return
	Global.play_sfx("ui_confirm", -3.0)
	OS.shell_open(url)
	UIInput.toast("OPENING LINK", url, accent)


## Panel miring gelap dengan garis aksen di tepi atas. tint = seberapa kuat warna aksen meresap ke latar (0..1).
static func plate(ci: CanvasItem, r: Rect2, skew: float, accent: Color, tint: float = 0.0, lit: float = 0.0) -> void:
	var w: float = r.size.x
	var h: float = r.size.y
	ci.draw_colored_polygon(UIKit.slanted(w, h, skew, r.position.x + 6.0, r.position.y + 8.0), Color(0, 0, 0, 0.42))
	var pts := UIKit.slanted(w, h, skew, r.position.x, r.position.y)
	var base_top := Color(0.08, 0.08, 0.17, 0.92)
	var base_bot := Color(0.04, 0.04, 0.1, 0.94)
	var c0: Color = base_top.lerp(accent.darkened(0.55), clampf(tint, 0.0, 1.0))
	var c1: Color = base_bot.lerp(accent.darkened(0.8), clampf(tint, 0.0, 1.0))
	ci.draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
	ci.draw_polyline(UIKit.closed(pts), Color(1, 1, 1, 0.16).lerp(accent.lightened(0.5), lit), 2.0 + lit * 1.5, true)
	var bh: float = 6.0
	var bar := PackedVector2Array([
		Vector2(r.position.x + skew, r.position.y),
		Vector2(r.position.x + w, r.position.y),
		Vector2(r.position.x + w - skew * bh / h, r.position.y + bh),
		Vector2(r.position.x + skew * (1.0 - bh / h), r.position.y + bh),
	])
	ci.draw_colored_polygon(bar, accent)


## Kilau berjalan yang dipotong mengikuti bentuk tombol.
static func shine(ci: CanvasItem, shape: PackedVector2Array, w: float, h: float, phase: float, alpha: float) -> void:
	var sx: float = phase * w
	var band := PackedVector2Array([Vector2(sx + 14.0, 0.0), Vector2(sx + 58.0, 0.0), Vector2(sx + 44.0, h), Vector2(sx, h)])
	var res: Array = Geometry2D.intersect_polygons(band, shape)
	if not res.is_empty():
		ci.draw_colored_polygon(res[0], Color(1, 1, 1, alpha))


# ================================================================== AboutButton
## Tombol di pojok kiri atas menu utama. Dipasang di daftar "dock" menu.gd (index ABOUT_DOCK).
class AboutButton extends Control:
	signal activated
	signal hovered

	var selected: bool = false
	var sel: float = 0.0
	var flash: float = 0.0
	var t: float = 0.0
	var accent: Color = AboutUI.ACCENT
	var logo: Texture2D

	func _init() -> void:
		size = Vector2(304, 62)
		custom_minimum_size = size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		focus_mode = Control.FOCUS_NONE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		logo = AboutUI.tex(AboutData.STUDIO_LOGO)

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
		if not is_visible_in_tree():
			return
		t += d
		var target: float = 1.0 if selected else 0.0
		var old_sel: float = sel
		sel = lerpf(sel, target, 1.0 - exp(-d * 14.0))
		if absf(sel - target) < 0.003:
			sel = target
		var old_flash: float = flash
		flash = maxf(flash - d * 3.0, 0.0)
		var sc: Vector2 = Vector2.ONE * (1.0 + 0.06 * sel + 0.05 * flash * flash)
		if sc != scale:
			scale = sc
		# gambar ulang HANYA kalau ada yang bergerak (hemat CPU saat tombol diam)
		if selected or sel != old_sel or flash != old_flash:
			queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var sk: float = 16.0
		var lift: float = -3.0 * sel
		draw_set_transform(Vector2(0.0, lift))
		var pts: PackedVector2Array = UIKit.slanted(w - 8.0, h - 8.0, sk, 4.0, 4.0)
		draw_colored_polygon(UIKit.slanted(w - 8.0, h - 8.0, sk, 9.0, 10.0 - lift), Color(0, 0, 0, 0.5))
		var top: Color = Color(0.07, 0.1, 0.18, 0.95).lerp(accent.darkened(0.3), sel)
		var bot: Color = Color(0.03, 0.04, 0.09, 0.95).lerp(accent.darkened(0.7), sel)
		draw_polygon(pts, PackedColorArray([top, top, bot, bot]))
		if sel > 0.02:
			AboutUI.shine(self, pts, w, h, fmod(t * 0.8, 1.9) - 0.4, 0.2 * sel)
		draw_polyline(UIKit.closed(pts), accent.lerp(Color.WHITE, 0.6 * sel + 0.4 * flash), 3.0 + 2.0 * sel, true)
		if flash > 0.0:
			draw_colored_polygon(pts, Color(1, 1, 1, 0.5 * flash))
		# logo studio di dalam lingkaran (cincin berdenyut saat terpilih)
		var c := Vector2(46.0, h * 0.5)
		if sel > 0.05:
			for k in 2:
				var ph: float = fmod(t * 0.9 + float(k) * 0.5, 1.0)
				draw_arc(c, 23.0 + ph * 14.0, 0.0, TAU, 28, Color(accent, (1.0 - ph) * 0.55 * sel), 2.0, true)
		AboutUI.draw_avatar(self, logo, c, 22.0, accent.lerp(Color.WHITE, 0.5 * sel), 3.0, "i", Color(0.08, 0.08, 0.18), 1.3)
		UIKit.text_in(self, AboutData.BUTTON_TITLE, Rect2(84.0, 4.0, w - 108.0, 36.0), 32, Color.WHITE.lerp(accent.lightened(0.5), 0.5 * sel), HORIZONTAL_ALIGNMENT_LEFT, 7)
		UIKit.text_in(self, AboutData.BUTTON_SUBTITLE, Rect2(84.0, 38.0, w - 108.0, 20.0), 15, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_LEFT, 3)
		if sel > 0.05:
			UIKit.draw_chevron(self, Vector2(w - 26.0 + sin(t * 8.0) * 3.0, h * 0.5), 10.0, 1, Color(accent.lightened(0.4), sel))
		draw_set_transform(Vector2.ZERO)


# ================================================================== PageView
## Menggambar isi satu halaman (0 ABOUT, 1 TEAM, 2 INFO, 3 LEGAL).
class PageView extends Control:
	const GOLD := UIKit.GOLD
	const SKEW := 20.0

	var page: int = 0
	var focus: int = 0            # baris CONTACT yang terfokus (halaman INFO)
	var card_hover: int = -1      # kartu TEAM yang sedang di-hover mouse
	var t: float = 0.0
	var _tw: Tween
	var _memo := {}
	var _card_lit: Array[float] = []
	var fx: PageFx          # lapisan animasi (digambar ulang tiap frame); isi halaman statis hanya digambar saat perlu

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		for i in AboutData.TEAM.size():
			_card_lit.append(0.0)
		fx = PageFx.new()
		fx.view = self
		add_child(fx)

	func _ready() -> void:
		mouse_exited.connect(func() -> void:
			card_hover = -1
			mouse_default_cursor_shape = Control.CURSOR_ARROW)

	# ---------------------------------------------------------------- kontrol dari AboutPanel
	func show_page(p: int, dir: int, instant: bool = false) -> void:
		page = p
		card_hover = -1
		mouse_default_cursor_shape = Control.CURSOR_ARROW
		fx.queue_redraw()      # WAJIB: lapisan fx harus digambar ulang saat ganti halaman (kalau tidak, sorotan halaman lama tertinggal, mis. di LEGAL)
		if _tw:
			_tw.kill()
		if instant or dir == 0:
			position.x = 0.0
			modulate.a = 1.0
			queue_redraw()
			return
		modulate.a = 0.0
		position.x = float(dir) * 44.0
		_tw = UIKit.tw(self)
		_tw.set_parallel(true)
		_tw.tween_property(self, "modulate:a", 1.0, 0.22)
		_tw.tween_property(self, "position:x", 0.0, 0.3).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		queue_redraw()

	func move_focus(d: int) -> void:
		if page == 1:
			# TEAM: ATAS / BAWAH memilih kartu (controller / keyboard); kartu terpilih tampil seperti saat di-hover
			var n: int = AboutData.TEAM.size()
			if n == 0:
				return
			var f: int = 0 if card_hover < 0 else clampi(card_hover + d, 0, n - 1)
			if f != card_hover:
				card_hover = f
				Global.play_sfx("ui_hover", -8.0)
			return
		if page != 2:
			return
		var n2: int = AboutData.CONTACT.size()
		var f2: int = clampi(focus + d, 0, n2 - 1)
		if f2 != focus:
			focus = f2
			queue_redraw()
			Global.play_sfx("ui_hover", -8.0)

	func open_focused() -> void:
		if page == 1:
			open_member(card_hover)
			return
		if page != 2:
			return
		var c: Dictionary = AboutData.CONTACT[focus]
		AboutUI.open_link(String(c.get("url", "")), String(c.get("label", "")), String(c.get("value", "")), Color(String(c.get("accent", "4fd8ff"))))

	## Membuka link anggota tim (kartu TEAM).
	func open_member(i: int) -> void:
		if i < 0 or i >= AboutData.TEAM.size():
			return
		var m: Dictionary = AboutData.TEAM[i]
		AboutUI.open_link(String(m.get("url", "")), String(m.get("name", "")), AboutData.TEAM_NO_LINK, Color(String(m.get("accent", "ffd23f"))))

	func _card_at(p: Vector2) -> int:
		for i in AboutData.TEAM.size():
			if _card_rect(i).has_point(p):
				return i
		return -1

	# ---------------------------------------------------------------- input mouse
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			_update_hover(event.position)
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if page == 1:
				var k: int = _card_at(event.position)
				if k >= 0:
					card_hover = k
					open_member(k)
			elif page == 2:
				var i: int = _contact_at(event.position)
				if i >= 0:
					focus = i
					queue_redraw()
					open_focused()

	func _update_hover(p: Vector2) -> void:
		var hand: bool = false
		card_hover = -1
		if page == 1:
			card_hover = _card_at(p)
			if card_hover >= 0:
				var m: Dictionary = AboutData.TEAM[card_hover]
				hand = String(m.get("url", "")) != ""
		elif page == 2:
			var i: int = _contact_at(p)
			if i >= 0:
				if focus != i:
					focus = i
					queue_redraw()
					Global.play_sfx("ui_hover", -9.0)
				var c: Dictionary = AboutData.CONTACT[i]
				hand = String(c.get("url", "")) != ""
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hand else Control.CURSOR_ARROW

	func _process(d: float) -> void:
		if not is_visible_in_tree():
			return
		t += d
		# isi halaman (teks, panel) hanya digambar ulang saat kartu sedang bertransisi hover
		var moving: bool = false
		for i in _card_lit.size():
			var target: float = 1.0 if i == card_hover else 0.0
			var nv: float = lerpf(_card_lit[i], target, 1.0 - exp(-d * 12.0))
			if absf(nv - target) < 0.004:
				nv = target
			if nv != _card_lit[i]:
				_card_lit[i] = nv
				moving = true
		if moving:
			queue_redraw()
		if page <= 2:
			fx.queue_redraw()      # lapisan animasi ringan (tanpa teks)

	# ---------------------------------------------------------------- tata letak (dipakai gambar + hit-test)
	func _card_rect(i: int) -> Rect2:
		var n: int = maxi(AboutData.TEAM.size(), 1)
		var gap: float = 28.0
		var w: float = (size.x - gap * float(n - 1)) / float(n)
		return Rect2(float(i) * (w + gap), 66.0, w, size.y - 70.0)

	func _tech_rect() -> Rect2:
		return Rect2(0.0, 0.0, 500.0, size.y - 4.0)

	func _contact_plate() -> Rect2:
		return Rect2(524.0, 0.0, size.x - 524.0, size.y - 4.0)

	func _row_step(n: int) -> float:
		return minf(68.0, (size.y - 4.0 - 90.0) / float(maxi(n, 1)))

	func _contact_rect(i: int) -> Rect2:
		var pr: Rect2 = _contact_plate()
		var st: float = _row_step(AboutData.CONTACT.size())
		return Rect2(pr.position.x + 34.0, 80.0 + float(i) * st, pr.size.x - 34.0 - 46.0, st - 8.0)

	func _contact_at(p: Vector2) -> int:
		for i in AboutData.CONTACT.size():
			if _contact_rect(i).has_point(p):
				return i
		return -1

	# ---------------------------------------------------------------- helper teks
	func _measure(s: String, w: float, fs: int) -> float:
		var key: String = "%d|%d|%s" % [int(w), fs, s]
		if not _memo.has(key):
			_memo[key] = AboutUI.body_font().get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
		return float(_memo[key])

	## Ukuran font terbesar (<= start) agar teks muat dalam tinggi max_h.
	func _fit(s: String, w: float, max_h: float, start: int, min_fs: int) -> int:
		var key: String = "fit|%d|%d|%d|%s" % [int(w), int(max_h), start, s]
		if _memo.has(key):
			return int(_memo[key])
		var fs: int = start
		while fs > min_fs and _measure(s, w, fs) > max_h:
			fs -= 1
		_memo[key] = fs
		return fs

	## Paragraf dengan pembungkus baris otomatis. Mengembalikan tingginya.
	func _para(s: String, pos: Vector2, w: float, fs: int, col: Color) -> float:
		var f: Font = AboutUI.body_font()
		draw_multiline_string(f, Vector2(pos.x, pos.y + f.get_ascent(fs)), s, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, col)
		return _measure(s, w, fs)

	func _heading(s: String, x: float, y: float, w: float, fs: int = 38, col: Color = UIKit.GOLD) -> void:
		UIKit.text_in(self, s, Rect2(x, y, w, fs * 1.3), fs, col, HORIZONTAL_ALIGNMENT_LEFT, 6)

	func _divider(x0: float, x1: float, y: float) -> void:
		draw_line(Vector2(x0, y), Vector2(x1, y), Color(1, 1, 1, 0.14), 2.0, true)

	# ---------------------------------------------------------------- gambar
	func _draw() -> void:
		match page:
			0: _draw_about()
			1: _draw_team()
			2: _draw_info()
			3: _draw_legal()

	# ---------------------------------------------------------------- lapisan animasi (fx): hanya bentuk, tanpa teks
	const ABOUT_LOGO_R := 78.0

	func _about_logo_center() -> Vector2:
		return Vector2(AboutUI.cx(Rect2(0.0, 0.0, 340.0, size.y - 4.0), SKEW, 124.0), 124.0)

	func draw_fx(ci: CanvasItem) -> void:
		match page:
			0:
				var c: Vector2 = _about_logo_center()
				var R: float = ABOUT_LOGO_R
				ci.draw_arc(c, R + 18.0, t * 0.6, t * 0.6 + PI * 0.55, 24, Color(GOLD, 0.8), 3.0, true)
				ci.draw_arc(c, R + 18.0, t * 0.6 + PI, t * 0.6 + PI * 1.55, 24, Color(GOLD, 0.8), 3.0, true)
			1:
				for i in AboutData.TEAM.size():
					var m: Dictionary = AboutData.TEAM[i]
					var acc := Color(String(m.get("accent", "ffd23f")))
					var lit: float = _card_lit[i]
					var r: Rect2 = _card_rect(i)
					r.position.y -= 8.0 * lit
					var cy: float = 90.0
					var c := Vector2(AboutUI.cx(r, SKEW - 2.0, cy), r.position.y + cy + sin(t * 1.8 + float(i) * 1.3) * 2.5)
					AboutUI.draw_avatar(ci, AboutUI.tex(String(m.get("logo", ""))), c, 62.0, acc.lerp(Color.WHITE, 0.45 * lit), 5.0, String(m.get("name", "?")))
			2:
				if focus < 0 or focus >= AboutData.CONTACT.size():
					return
				var c: Dictionary = AboutData.CONTACT[focus]
				var acc := Color(String(c.get("accent", "ffffff")))
				var r: Rect2 = _contact_rect(focus)
				var pulse: float = 0.5 + 0.5 * sin(t * 5.0)
				var hl := UIKit.slanted(r.size.x, r.size.y, 10.0, r.position.x, r.position.y)
				ci.draw_colored_polygon(hl, Color(acc, 0.16 + 0.05 * pulse))
				ci.draw_polyline(UIKit.closed(hl), Color(acc.lightened(0.3), 0.9), 2.5, true)
				if String(c.get("url", "")) != "":
					var bc := Vector2(r.position.x + 40.0, r.position.y + r.size.y * 0.5)
					for k in 2:
						var ph: float = fmod(t * 0.9 + float(k) * 0.5, 1.0)
						ci.draw_arc(bc, 26.0 + ph * 12.0, 0.0, TAU, 28, Color(acc, (1.0 - ph) * 0.5), 2.0, true)
					UIKit.draw_chevron(ci, Vector2(r.end.x - 20.0 + sin(t * 8.0) * 3.0, r.position.y + r.size.y * 0.5 + 6.0), 8.0, 1, Color(acc.lightened(0.4), 0.95))

	## Mengisi cache ukuran teks (_memo) untuk satu halaman TANPA menggambar apa pun. Rumusnya sama persis dengan
	## _draw_about / _draw_legal, jadi saat halaman digambar pertama kali tidak perlu lagi mengukur teks.
	func prime_layout(p: int) -> void:
		var h: float = size.y - 4.0
		match p:
			0:
				var tw: float = (size.x - 360.0) - 52.0 - 66.0
				var about_s: String = AboutData.fill(AboutData.ABOUT_TEXT)
				var fs: int = _fit(about_s, tw, 150.0, 22, 16)
				_measure(about_s, tw, fs)
				var msg: String = AboutData.fill(AboutData.MESSAGE_TEXT)
				var qw: float = tw - 64.0
				var qfs: int = _fit(msg, qw, 78.0, 21, 15)
				_measure(msg, qw, qfs)
			2:
				for c in AboutData.CONTACT:
					var cd: Dictionary = c
					AboutUI.tex(String(cd.get("icon", "")))
			3:
				var pw: float = (size.x - 20.0) * 0.5
				var tw2: float = pw - 48.0 - 64.0
				var ack: String = AboutData.fill(AboutData.ACK_TEXT)
				var afs: int = _fit(ack, tw2, h - 100.0, 22, 15)
				_measure(ack, tw2, afs)
				var l1: String = AboutData.fill(AboutData.LEGAL_TEXT_1)
				var l2: String = AboutData.fill(AboutData.LEGAL_TEXT_2)
				_measure(l1, tw2, _fit(l1, tw2, 90.0, 21, 15))
				_measure(l2, tw2, _fit(l2, tw2, 90.0, 21, 15))

	# ---- halaman 1: ABOUT
	func _draw_about() -> void:
		var h: float = size.y - 4.0
		# kolom kiri: logo studio
		var lr := Rect2(0.0, 0.0, 340.0, h)
		AboutUI.plate(self, lr, SKEW, GOLD)
		var c: Vector2 = _about_logo_center()
		var R: float = ABOUT_LOGO_R
		draw_circle(c + Vector2(4, 6), R + 8.0, Color(0, 0, 0, 0.45))
		draw_circle(c, R + 4.0, Color(0.07, 0.07, 0.17))
		var logo: Texture2D = AboutUI.tex(AboutData.STUDIO_LOGO)
		if logo != null:
			var ls: float = R * 1.62
			draw_texture_rect(logo, Rect2(c - Vector2(ls, ls) * 0.5, Vector2(ls, ls)), false)
		else:
			UIKit.text_in(self, "E", Rect2(c.x - R, c.y - R, R * 2.0, R * 2.0), 90, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 6)
		draw_arc(c, R + 4.0, 0.0, TAU, 72, GOLD, 5.0, true)
		UIKit.text_in(self, AboutData.STUDIO_NAME_TOP, Rect2(lr.position.x + 10.0, 224.0, lr.size.x - 20.0, 54.0), 48, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 7)
		UIKit.text_in(self, AboutData.STUDIO_NAME_BOTTOM, Rect2(lr.position.x + 10.0, 272.0, lr.size.x - 20.0, 40.0), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6)
		UIKit.text_in(self, AboutData.STUDIO_TAGLINE, Rect2(lr.position.x + 10.0, 322.0, lr.size.x - 20.0, 22.0), 16, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 3)

		# kolom kanan: tentang + pesan developer
		var rr := Rect2(360.0, 0.0, size.x - 360.0, h)
		AboutUI.plate(self, rr, SKEW, UIKit.CYAN)
		var x0: float = rr.position.x + 52.0
		var tw: float = rr.size.x - 52.0 - 66.0
		_heading(AboutData.ABOUT_HEADING, x0, 12.0, tw, 40)
		var about_s: String = AboutData.fill(AboutData.ABOUT_TEXT)
		var fs: int = _fit(about_s, tw, 150.0, 22, 16)
		var ph: float = _para(about_s, Vector2(x0, 70.0), tw, fs, Color(1, 1, 1, 0.92))

		var msg: String = AboutData.fill(AboutData.MESSAGE_TEXT)
		var qx: float = x0 + 6.0
		var qw: float = tw - 64.0
		var qfs: int = _fit(msg, qw, 78.0, 21, 15)
		var qh: float = _measure(msg, qw, qfs)
		var box_h: float = 40.0 + qh + 34.0
		var by: float = maxf(70.0 + ph + 20.0, h - 22.0 - box_h)
		var bw: float = tw + 24.0
		var box := UIKit.slanted(bw, box_h, 12.0, x0 - 18.0, by)
		draw_colored_polygon(box, Color(1, 1, 1, 0.06))
		draw_polyline(UIKit.closed(box), Color(GOLD, 0.45), 2.0, true)
		draw_colored_polygon(UIKit.slanted(7.0, box_h, 0.0, x0 - 10.0, by), GOLD)
		UIKit.text_in(self, AboutData.MESSAGE_HEADING, Rect2(x0 + 6.0, by + 8.0, bw - 60.0, 26.0), 19, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 4)
		UIKit.text_in(self, "“", Rect2(x0 + bw - 78.0, by - 6.0, 56.0, 70.0), 84, Color(GOLD, 0.35), HORIZONTAL_ALIGNMENT_CENTER)
		_para(msg, Vector2(qx, by + 38.0), qw, qfs, Color(1, 1, 1, 0.9))
		UIKit.text_in(self, "— " + AboutData.MESSAGE_SIGNATURE, Rect2(x0 + 6.0, by + box_h - 30.0, bw - 56.0, 24.0), 16, GOLD, HORIZONTAL_ALIGNMENT_RIGHT, 3)

	# ---- halaman 2: TEAM
	func _draw_team() -> void:
		_heading(AboutData.TEAM_HEADING, 6.0, 0.0, 700.0, 40)
		UIKit.text_in(self, AboutData.TEAM_STUDIO_LABEL, Rect2(size.x - 420.0, 2.0, 412.0, 22.0), 17, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_RIGHT, 3)
		UIKit.text_in(self, AboutData.STUDIO_NAME_TOP + " " + AboutData.STUDIO_NAME_BOTTOM, Rect2(size.x - 420.0, 22.0, 412.0, 32.0), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 5)
		for i in AboutData.TEAM.size():
			var m: Dictionary = AboutData.TEAM[i]
			var acc := Color(String(m.get("accent", "ffd23f")))
			var lit: float = _card_lit[i]
			var r: Rect2 = _card_rect(i)
			r.position.y -= 8.0 * lit
			AboutUI.plate(self, r, SKEW - 2.0, acc, 0.3 + 0.35 * lit, lit)
			# (potret / logo anggota digambar di lapisan fx supaya bisa melayang tanpa menggambar ulang teks)
			var nm: String = String(m.get("name", ""))
			var ny: float = r.position.y + 168.0
			UIKit.text_in(self, nm, Rect2(r.position.x + 10.0, ny, r.size.x - 20.0, 46.0), 42, Color.WHITE.lerp(acc.lightened(0.5), 0.5 * lit), HORIZONTAL_ALIGNMENT_CENTER, 7)
			var roles: Array = m.get("roles", [])
			for k in roles.size():
				var rs: String = String(roles[k])
				var pw: float = UIKit.text_w(rs, 21) + 44.0
				var py: float = r.position.y + 224.0 + float(k) * 44.0
				var px: float = AboutUI.cx(r, SKEW - 2.0, py - r.position.y + 17.0) - pw * 0.5
				var pill := UIKit.slanted(pw, 34.0, 9.0, px, py)
				draw_colored_polygon(pill, Color(acc.darkened(0.45), 0.92))
				draw_polyline(UIKit.closed(pill), Color(acc.lightened(0.25), 0.9), 2.0, true)
				UIKit.text_in(self, rs, Rect2(px, py, pw, 34.0), 21, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 3)
			# petunjuk "klik untuk membuka link" (hanya kartu yang punya link, muncul saat disorot)
			if lit > 0.02 and String(m.get("url", "")) != "":
				UIKit.text_in(self, AboutData.TEAM_HINT, Rect2(r.position.x + 10.0, r.position.y + r.size.y - 38.0, r.size.x - 20.0, 26.0), 16, Color(acc.lightened(0.45), lit), HORIZONTAL_ALIGNMENT_CENTER, 3, Color(0, 0, 0, lit))

	# ---- halaman 3: INFO
	func _draw_info() -> void:
		# ---- TECHNICAL INFO
		var tr: Rect2 = _tech_rect()
		AboutUI.plate(self, tr, SKEW, GOLD)
		_heading(AboutData.TECH_HEADING, tr.position.x + 46.0, 12.0, tr.size.x - 80.0, 38)
		_divider(tr.position.x + 40.0, tr.end.x - 40.0, 66.0)
		var rows: Array = AboutData.TECH_INFO
		var st: float = _row_step(rows.size())
		for i in rows.size():
			var row: Array = rows[i]
			var y: float = 80.0 + float(i) * st
			var rh: float = st - 8.0
			draw_colored_polygon(UIKit.slanted(tr.size.x - 80.0, rh, 10.0, tr.position.x + 34.0, y), Color(1, 1, 1, 0.05 if i % 2 == 0 else 0.02))
			UIKit.text_in(self, String(row[0]), Rect2(tr.position.x + 62.0, y, 200.0, rh), 21, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT, 3)
			UIKit.text_in(self, String(row[1]), Rect2(tr.position.x + 200.0, y, tr.size.x - 200.0 - 70.0, rh), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, 5)
		# ---- CONTACT
		var cr: Rect2 = _contact_plate()
		AboutUI.plate(self, cr, SKEW, UIKit.CYAN)
		_heading(AboutData.CONTACT_HEADING, cr.position.x + 46.0, 12.0, cr.size.x - 80.0, 38)
		_divider(cr.position.x + 40.0, cr.end.x - 40.0, 66.0)
		for i in AboutData.CONTACT.size():
			var c: Dictionary = AboutData.CONTACT[i]
			var acc := Color(String(c.get("accent", "ffffff")))
			var url: String = String(c.get("url", ""))
			var has_link: bool = url != ""
			var r: Rect2 = _contact_rect(i)
			var on: bool = i == focus
			# latar baris (tipis) + logo bulat
			draw_colored_polygon(UIKit.slanted(r.size.x, r.size.y, 10.0, r.position.x, r.position.y), Color(1, 1, 1, 0.045))
			var bc := Vector2(r.position.x + 40.0, r.position.y + r.size.y * 0.5)
			var fill_col: Color = Color(String(c["fill"])) if c.has("fill") else acc.darkened(0.55)
			var grad: Array = c.get("gradient", [])
			AboutUI.draw_badge(self, AboutUI.tex(String(c.get("icon", ""))), bc, 24.0, acc, fill_col, grad, String(c.get("badge", "")), not has_link, on)
			var a: float = 1.0 if has_link else 0.55
			UIKit.text_in(self, String(c.get("label", "")), Rect2(r.position.x + 82.0, r.position.y + 3.0, r.size.x - 120.0, 18.0), 15, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_LEFT, 3)
			UIKit.text_in(self, String(c.get("value", "")), Rect2(r.position.x + 82.0, r.position.y + 20.0, r.size.x - 130.0, r.size.y - 22.0), 28, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_LEFT, 5)
			if on and has_link:
				UIKit.text_in(self, AboutData.CONTACT_HINT, Rect2(r.position.x, r.position.y + 3.0, r.size.x - 40.0, 18.0), 14, Color(acc.lightened(0.4), 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 3)

	# ---- halaman 4: LEGAL
	func _draw_legal() -> void:
		var h: float = size.y - 4.0
		var pw: float = (size.x - 20.0) * 0.5
		# ---- ACKNOWLEDGEMENTS
		var lr := Rect2(0.0, 0.0, pw, h)
		AboutUI.plate(self, lr, SKEW, UIKit.GREEN)
		var x0: float = lr.position.x + 48.0
		var tw: float = lr.size.x - 48.0 - 64.0
		_heading(AboutData.ACK_HEADING, x0, 12.0, tw, 38)
		_divider(x0 - 6.0, lr.end.x - 40.0, 66.0)
		var ack: String = AboutData.fill(AboutData.ACK_TEXT)
		var afs: int = _fit(ack, tw, h - 100.0, 22, 15)
		_para(ack, Vector2(x0, 82.0), tw, afs, Color(1, 1, 1, 0.9))
		# ---- LEGAL
		var rr := Rect2(pw + 20.0, 0.0, pw, h)
		AboutUI.plate(self, rr, SKEW, UIKit.RED)
		var x1: float = rr.position.x + 48.0
		_heading(AboutData.LEGAL_HEADING, x1, 12.0, tw, 38)
		_divider(x1 - 6.0, rr.end.x - 40.0, 66.0)
		UIKit.text_in(self, AboutData.fill(AboutData.LEGAL_COPYRIGHT), Rect2(x1, 78.0, tw, 38.0), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, 5)
		UIKit.text_in(self, AboutData.fill(AboutData.LEGAL_RIGHTS), Rect2(x1, 114.0, tw, 24.0), 19, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 4)
		var l1: String = AboutData.fill(AboutData.LEGAL_TEXT_1)
		var l2: String = AboutData.fill(AboutData.LEGAL_TEXT_2)
		var lfs: int = mini(_fit(l1, tw, 90.0, 21, 15), _fit(l2, tw, 90.0, 21, 15))
		var y: float = 156.0
		y += _para(l1, Vector2(x1, y), tw, lfs, Color(1, 1, 1, 0.88)) + 16.0
		_para(l2, Vector2(x1, y), tw, lfs, Color(1, 1, 1, 0.88))


# ================================================================== GlyphWarmer
## Pemanas glyph di balik layar. Node ini diletakkan JAUH di luar layar (tidak pernah tampak, tidak ada beban GPU),
## tetapi _draw-nya tetap berjalan, dan di situlah glyph dirasterisasi + masuk atlas font. Pekerjaan DIBAGI ke banyak
## frame dengan anggaran waktu kecil per frame (BUDGET_USEC), jadi tidak pernah ada satu frame pun yang berat.
## Berbeda dengan merender seluruh layar About sekaligus (yang menyebabkan patah beberapa detik setelah game dibuka).
class GlyphWarmer extends Control:
	signal finished

	const BUDGET_USEC := 2500        # maksimal ~2.5 ms per frame untuk pemanasan
	const FAR := Vector2(-6000.0, -6000.0)

	var _jobs: Array = []
	var _i: int = 0
	var _done: bool = false

	func _init() -> void:
		position = FAR
		size = Vector2(64.0, 64.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		_jobs = AboutUI.glyph_jobs()

	func _process(_d: float) -> void:
		if _done:
			return
		if _i >= _jobs.size():
			_done = true
			finished.emit()
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var t0: int = Time.get_ticks_usec()
		while _i < _jobs.size():
			var j: Array = _jobs[_i]
			var f: Font = j[0]
			var fs: int = j[1]
			var ol: int = j[2]
			var txt: String = j[3]
			if ol > 0:
				draw_string_outline(f, Vector2(0.0, 80.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ol, Color.BLACK)
			draw_string(f, Vector2(0.0, 80.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
			_i += 1
			if Time.get_ticks_usec() - t0 >= BUDGET_USEC:
				break


# ================================================================== PageFx
## Lapisan animasi di atas PageView: hanya menggambar bentuk sederhana (busur, potret, sorotan), tanpa teks,
## jadi aman digambar ulang tiap frame. Teks dan panel di PageView tidak ikut digambar ulang.
class PageFx extends Control:
	var view: PageView

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if view != null:
			view.draw_fx(self)


# ================================================================== AboutPanel
## Panel berhalaman: baris tab di atas, isi halaman di bawah.
## Navigasi: kiri / kanan = ganti halaman | atas / bawah + ACCEPT di halaman INFO = buka link | BACK = kembali.
## Mouse: klik tab, klik panah, klik baris kontak.
class AboutPanel extends Control:
	signal back_requested
	signal page_changed

	const TAB_H := 44.0
	const TAB_W := 226.0
	const TAB_GAP := 8.0
	const VIEW_Y := 60.0
	const HIT_PREV := -2
	const HIT_NEXT := -3

	var page: int = 0
	var view: PageView
	var tab_hover: int = -1
	var tab_lit: Array[float] = []
	var _hit_hover: int = -1

	func _init() -> void:
		size = Vector2(1160, 440)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_STOP
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		view = PageView.new()
		view.position = Vector2(0.0, VIEW_Y)
		view.size = Vector2(size.x, size.y - VIEW_Y)
		add_child(view)
		for i in _count():
			tab_lit.append(0.0)

	func _ready() -> void:
		mouse_exited.connect(func() -> void:
			_hit_hover = -1
			mouse_default_cursor_shape = Control.CURSOR_ARROW)

	func _count() -> int:
		return 4

	func _title(i: int) -> String:
		var titles: Array = AboutData.PAGE_TITLES
		return String(titles[i]) if i < titles.size() else "PAGE %d" % (i + 1)

	# ---------------------------------------------------------------- API untuk menu.gd
	func reset() -> void:
		page = 0
		_hit_hover = -1
		view.focus = 0
		view.show_page(0, 0, true)

	## PEMANASAN RINGAN: dipanggil menu.gd SETELAH GlyphWarmer selesai. Hanya mengisi cache ukuran teks, satu halaman
	## per frame, tanpa merender layar About sama sekali (jadi tidak ada lonjakan frame).
	func prime() -> void:
		view.prime_layout(0)
		await get_tree().process_frame
		if not is_inside_tree():
			return
		view.prime_layout(3)

	func handle(action: StringName) -> void:
		match action:
			&"left":
				_go(page - 1, -1)
			&"right":
				_go(page + 1, 1)
			&"up":
				view.move_focus(-1)
			&"down":
				view.move_focus(1)
			&"accept":
				if page == 2 or (page == 1 and view.card_hover >= 0):
					view.open_focused()
				else:
					_go(page + 1, 1)
			&"back":
				back_requested.emit()

	func _go(p: int, dir: int) -> void:
		var n: int = _count()
		p = posmod(p, n)
		if p == page:
			return
		page = p
		view.show_page(p, dir)
		queue_redraw()
		Global.play_sfx("ui_hover", -6.0)
		page_changed.emit()

	# ---------------------------------------------------------------- tab + mouse
	func _tab_rect(i: int) -> Rect2:
		return Rect2(float(i) * (TAB_W + TAB_GAP), 0.0, TAB_W, TAB_H)

	func _prev_rect() -> Rect2:
		return Rect2(size.x - 206.0, 0.0, 50.0, TAB_H)

	func _next_rect() -> Rect2:
		return Rect2(size.x - 58.0, 0.0, 50.0, TAB_H)

	func _hit(p: Vector2) -> int:
		for i in _count():
			if _tab_rect(i).has_point(p):
				return i
		if _prev_rect().has_point(p):
			return HIT_PREV
		if _next_rect().has_point(p):
			return HIT_NEXT
		return -1

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var h: int = _hit(event.position)
			if h != _hit_hover:
				_hit_hover = h
				queue_redraw()
				if h >= 0 and h != page:
					Global.play_sfx("ui_hover", -9.0)
			tab_hover = h if h >= 0 else -1
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h != -1 else Control.CURSOR_ARROW
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var h: int = _hit(event.position)
			if h >= 0:
				_go(h, 1 if h > page else -1)
			elif h == HIT_PREV:
				_go(page - 1, -1)
			elif h == HIT_NEXT:
				_go(page + 1, 1)

	func _process(d: float) -> void:
		if not is_visible_in_tree():
			return
		var moving: bool = false
		for i in tab_lit.size():
			var target: float = 1.0 if i == page else (0.4 if i == tab_hover else 0.0)
			var nv: float = lerpf(tab_lit[i], target, 1.0 - exp(-d * 14.0))
			if absf(nv - target) < 0.004:
				nv = target
			if nv != tab_lit[i]:
				tab_lit[i] = nv
				moving = true
		if moving:         # tab hanya digambar ulang saat sedang bertransisi
			queue_redraw()

	func _draw() -> void:
		var gold := UIKit.GOLD
		for i in _count():
			var r: Rect2 = _tab_rect(i)
			var lit: float = tab_lit[i]
			var pts := UIKit.slanted(r.size.x, r.size.y, 16.0, r.position.x, r.position.y)
			draw_colored_polygon(UIKit.slanted(r.size.x, r.size.y, 16.0, r.position.x + 4.0, r.position.y + 5.0), Color(0, 0, 0, 0.42))
			var base := Color(0.07, 0.07, 0.16, 0.9)
			var c0: Color = base.lerp(gold.lightened(0.3), lit)
			var c1: Color = base.lerp(gold.darkened(0.1), lit)
			draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
			draw_polyline(UIKit.closed(pts), Color(1, 1, 1, lerpf(0.16, 0.95, lit)), 2.0 + lit * 1.5, true)
			var tcol: Color = UIKit.INK if lit > 0.6 else Color(1, 1, 1, 0.85)
			UIKit.text_in(self, _title(i), Rect2(r.position.x + 8.0, r.position.y, r.size.x - 16.0, r.size.y), 28, tcol, HORIZONTAL_ALIGNMENT_CENTER)
		# penghitung halaman + panah
		var pc: Color = Color(gold, 1.0) if _hit_hover == HIT_PREV else Color(1, 1, 1, 0.55)
		var nc: Color = Color(gold, 1.0) if _hit_hover == HIT_NEXT else Color(1, 1, 1, 0.55)
		UIKit.draw_chevron(self, _prev_rect().get_center(), 9.0, -1, pc)
		UIKit.draw_chevron(self, _next_rect().get_center(), 9.0, 1, nc)
		UIKit.text_in(self, "%d / %d" % [page + 1, _count()], Rect2(size.x - 156.0, 0.0, 94.0, TAB_H), 24, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, 4)
