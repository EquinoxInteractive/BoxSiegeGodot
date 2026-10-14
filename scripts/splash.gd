extends Control
## ======================================================================================
##  SPLASH / KREDIT PEMBUKA  (scene pertama saat game dibuka)
## ======================================================================================
## Urutan:   1) GODOT ENGINE   2) EQUINOX   3) 3 DEVELOPER
## Tiap slide: fade in -> tahan -> fade out, dengan latar yang menyesuaikan logonya
## (Godot = biru gelap, Equinox = terang keperakan karena logonya abu-abu gelap, Developer = ungu gelap).
## Setelah slide terakhir selesai, otomatis lanjut ke LOADING SCREEN (scenes/loading.tscn).
## Tekan tombol apa saja / klik / tombol controller untuk melewati SLIDE YANG SEDANG TAMPIL saja:
## Godot -> (skip) Equinox -> (skip) Developer -> (skip) Loading screen. Satu kali tekan = satu slide.
##
## Teks & foto developer diambil dari about_data.gd (AboutData), jadi kalau Anda mengganti anggota tim
## di sana, kredit ini ikut berubah. Logo Godot: assets/sprites/about/godot.png.
##
## Mengubah durasi: ubah FADE_IN / HOLD / FADE_OUT di bawah.

const NEXT_SCENE := "res://scenes/loading.tscn"

const LEAD_IN := 0.5                 # layar hitam sebelum slide pertama (detik)
const GAP := 0.3                     # layar hitam di antara slide (detik)
const FADE_IN := 1.0                 # lama fade in
const FADE_OUT := 0.85               # lama fade out
const HOLD_GODOT := 2.0              # lama logo ditahan penuh
const HOLD_EQUINOX := 2.3
const HOLD_DEVS := 3.0
const SKIP_FADE := 0.28              # fade out cepat saat kredit dilewati
const SKIP_DELAY := 0.35             # tombol skip baru aktif setelah slide muncul sekian detik (supaya tidak terpencet tak sengaja)
const SKIP_GAP := 0.12               # jeda hitam singkat sebelum slide berikutnya saat di-skip

const GODOT_LOGO := "res://assets/sprites/about/godot.png"
const FONT_PATH := "res://assets/fonts/lilita_one.ttf"

var _font: Font
var _slides: Array = []
var _hint: Label
var _i: int = 0
var _t: float = 0.0
var _elapsed: float = 0.0
var _skipping: bool = false
var _slide_age: float = 0.0          # detik sejak slide aktif mulai (untuk SKIP_DELAY per slide)
var _skip_t: float = 0.0
var _skip_a0: float = 0.0
var _finished: bool = false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	_font = load(FONT_PATH) as Font
	# game ini sedang dibuka: serahkan semua persiapan berat ke LOADING SCREEN (timer lama di Global tidak dipakai)
	Global.boot_managed = true

	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)

	_slides = [GodotSlide.new(_font), EquinoxSlide.new(_font), DevSlide.new(_font)]
	(_slides[0] as Slide).hold = HOLD_GODOT
	(_slides[1] as Slide).hold = HOLD_EQUINOX
	(_slides[2] as Slide).hold = HOLD_DEVS
	for s in _slides:
		var sl: Slide = s
		sl.visible = false
		add_child(sl)

	_hint = Label.new()
	_hint.text = "PRESS ANY KEY TO SKIP"
	_hint.add_theme_font_override("font", _font)
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.position = Vector2(1280.0 - 24.0 - 400.0, 720.0 - 38.0)
	_hint.size = Vector2(400.0, 24.0)
	_hint.modulate.a = 0.0
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

	_begin_slide()


func _begin_slide(pre: float = -1.0) -> void:
	_slide_age = 0.0
	_elapsed = 0.0                       # petunjuk "PRESS ANY KEY" muncul lagi di tiap slide
	if pre < 0.0:
		pre = LEAD_IN if _i == 0 else GAP
	_t = -pre
	var s: Slide = _slides[_i]
	s.visible = true
	s.modulate.a = 0.0
	_hint.add_theme_color_override("font_color", s.hint_color)


func _process(d: float) -> void:
	if _finished:
		return
	_elapsed += d
	_slide_age += d
	_hint.modulate.a = clampf((_elapsed - 1.2) * 1.5, 0.0, 1.0) * (0.0 if _skipping else 1.0)

	var s: Slide = _slides[_i]
	if _skipping:
		_skip_t += d
		s.modulate.a = _skip_a0 * (1.0 - clampf(_skip_t / SKIP_FADE, 0.0, 1.0))
		if _skip_t >= SKIP_FADE:
			_skipping = false
			_next_slide(SKIP_GAP)            # hanya pindah ke slide BERIKUTNYA, tidak langsung ke loading
		return

	_t += d
	var a: float = _alpha(_t, s.hold)
	s.modulate.a = a
	if _t > 0.0:
		s.animate(_t, a)
	if _t >= FADE_IN + s.hold + FADE_OUT:
		_next_slide()


## Sembunyikan slide aktif, lanjut ke slide berikutnya; kalau sudah slide terakhir -> loading screen.
func _next_slide(pre: float = -1.0) -> void:
	(_slides[_i] as Slide).visible = false
	_i += 1
	if _i >= _slides.size():
		_finish()
	else:
		_begin_slide(pre)


## 0 -> 1 (fade in) -> tahan -> 1 -> 0 (fade out), dengan kurva halus.
func _alpha(t: float, hold: float) -> float:
	if t <= 0.0:
		return 0.0
	if t < FADE_IN:
		return _smooth(t / FADE_IN)
	if t < FADE_IN + hold:
		return 1.0
	return 1.0 - _smooth((t - FADE_IN - hold) / FADE_OUT)


static func _smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _input(event: InputEvent) -> void:
	if _skipping or _finished or _slide_age < SKIP_DELAY:
		return
	var go: bool = false
	if event is InputEventKey and event.pressed and not event.echo:
		go = true
	elif event is InputEventMouseButton and event.pressed:
		go = true
	elif event is InputEventJoypadButton and event.pressed:
		go = true
	if go:
		_skipping = true
		_skip_t = 0.0
		_skip_a0 = (_slides[_i] as Slide).modulate.a
		get_viewport().set_input_as_handled()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	get_tree().change_scene_to_file(NEXT_SCENE)


# ================================================================== dasar slide
class Slide extends Control:
	var hold: float = 2.0
	var hint_color: Color = Color(0.6, 0.64, 0.72, 0.8)

	func _init() -> void:
		position = Vector2.ZERO
		size = Vector2(1280.0, 720.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## t = detik sejak slide mulai (fade in dimulai di t = 0), a = alpha saat ini.
	func animate(_t: float, _a: float) -> void:
		pass

	func _ease_out(x: float) -> float:
		x = clampf(x, 0.0, 1.0)
		return 1.0 - pow(1.0 - x, 3.0)

	## Latar gradasi radial (tengah terang -> tepi gelap), selalu dihaluskan (LINEAR) supaya tidak terlihat berpiksel.
	func _radial(inner: Color, outer: Color, rect: Rect2, center: Vector2 = Vector2(0.5, 0.5), radius: float = 0.75, tex_size: Vector2i = Vector2i(512, 288)) -> TextureRect:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 1.0])
		g.colors = PackedColorArray([inner, outer])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = tex_size.x
		gt.height = tex_size.y
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = center
		gt.fill_to = center + Vector2(radius, 0.0)
		var tr := TextureRect.new()
		tr.texture = gt
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.position = rect.position
		tr.size = rect.size
		tr.pivot_offset = rect.size * 0.5
		add_child(tr)
		return tr

	## Teks rata tengah dengan jarak antar huruf (tracking).
	func _label(txt: String, font: Font, fs: int, col: Color, y: float, track: int = 0) -> Label:
		var fv := FontVariation.new()
		fv.base_font = font
		fv.spacing_glyph = track
		var l := Label.new()
		l.text = txt
		l.add_theme_font_override("font", fv)
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", col)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.position = Vector2(float(track) * 0.5, y)      # spasi ikut ditambahkan setelah huruf terakhir -> geser setengahnya
		l.size = Vector2(1280.0, float(fs) * 1.4)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		return l

	func _logo(path: String, px: float, center: Vector2) -> TextureRect:
		var tr := TextureRect.new()
		if path != "" and ResourceLoader.exists(path):
			tr.texture = load(path) as Texture2D
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.size = Vector2(px, px)
		tr.position = center - tr.size * 0.5
		tr.pivot_offset = tr.size * 0.5
		add_child(tr)
		return tr


# ================================================================== slide 1: GODOT
class GodotSlide extends Slide:
	var logo: TextureRect
	var glow: TextureRect
	var made: Label
	var name_l: Label
	var eng: Label
	var line: ColorRect
	var _y: Dictionary = {}

	func _init(font: Font) -> void:
		super()
		hint_color = Color(0.55, 0.62, 0.74, 0.8)
		_radial(Color("2a3a56"), Color("0d1017"), Rect2(0, 0, 1280, 720), Vector2(0.5, 0.44), 0.8)
		glow = _radial(Color(0.28, 0.56, 0.78, 0.55), Color(0.28, 0.56, 0.78, 0.0), Rect2(640 - 340, 330 - 340, 680, 680), Vector2(0.5, 0.5), 0.5, Vector2i(256, 256))
		made = _label("MADE WITH", font, 22, Color("8ea6c4"), 124.0, 16)
		logo = _logo(GODOT_LOGO, 230.0, Vector2(640, 325))
		name_l = _label("GODOT", font, 76, Color("f2f6fb"), 450.0, 14)
		eng = _label("ENGINE", font, 28, Color("7fb2dd"), 548.0, 26)
		line = ColorRect.new()
		line.color = Color("478cbf")
		line.size = Vector2(0.0, 3.0)
		line.position = Vector2(640.0, 604.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
		for n in [made, name_l, eng]:
			_y[n] = (n as Label).position.y

	func animate(t: float, a: float) -> void:
		var k: float = _ease_out(t / 1.8)
		logo.scale = Vector2.ONE * lerpf(0.86, 1.0, k)
		glow.scale = Vector2.ONE * (1.0 + 0.05 * sin(t * 2.0))
		var rise: float = (1.0 - _ease_out(t / 1.3)) * 16.0
		for n in [made, name_l, eng]:
			var l: Label = n
			l.position.y = float(_y[l]) + rise
		var w: float = 220.0 * _ease_out((t - 0.5) / 1.2)
		line.size.x = w
		line.position.x = 640.0 - w * 0.5
		line.modulate.a = a


# ================================================================== slide 2: EQUINOX
class EquinoxSlide extends Slide:
	var logo: TextureRect
	var glow: TextureRect
	var top_l: Label
	var bot_l: Label
	var tag_l: Label
	var line: ColorRect
	var _y: Dictionary = {}

	func _init(font: Font) -> void:
		super()
		hint_color = Color(0.52, 0.56, 0.66, 0.8)
		# latar gelap kebiruan (navy-charcoal) dengan cahaya lembut di tengah, seperti logo resmi Equinox
		_radial(Color("232837"), Color("0d0f16"), Rect2(0, 0, 1280, 720), Vector2(0.5, 0.42), 0.85)
		glow = _radial(Color(0.75, 0.80, 0.95, 0.10), Color(0.75, 0.80, 0.95, 0.0), Rect2(640 - 330, 280 - 330, 660, 660), Vector2(0.5, 0.5), 0.5, Vector2i(256, 256))
		logo = _logo(AboutData.STUDIO_LOGO, 330.0, Vector2(640, 280))
		logo.modulate = Color(1.25, 1.25, 1.3, 1.0)       # sisi gelap logo diangkat sedikit supaya tetap terbaca di latar gelap
		top_l = _label(AboutData.STUDIO_NAME_TOP, font, 78, Color("c9cdd6"), 432.0, 24)
		bot_l = _label(AboutData.STUDIO_NAME_BOTTOM, font, 28, Color("eef0f5"), 524.0, 30)
		tag_l = _label(AboutData.STUDIO_TAGLINE, font, 16, Color("7c8394"), 582.0, 12)
		line = ColorRect.new()
		line.color = Color("4a5164")
		line.size = Vector2(0.0, 2.0)
		line.position = Vector2(640.0, 574.0)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(line)
		for n in [top_l, bot_l, tag_l]:
			_y[n] = (n as Label).position.y

	func animate(t: float, a: float) -> void:
		var k: float = _ease_out(t / 1.7)
		logo.scale = Vector2.ONE * lerpf(0.88, 1.0, k)
		logo.rotation = deg_to_rad(lerpf(-4.0, 0.0, k))
		glow.scale = Vector2.ONE * (1.0 + 0.05 * sin(t * 1.8))
		var rise: float = (1.0 - _ease_out(t / 1.3)) * 16.0
		for n in [top_l, bot_l, tag_l]:
			var l: Label = n
			l.position.y = float(_y[l]) + rise
		var w: float = 110.0 * _ease_out((t - 0.5) / 1.2)
		line.size.x = w
		line.position.x = 640.0 - w * 0.5
		line.modulate.a = a


# ================================================================== slide 3: 3 DEVELOPER
## Gaya sama dengan slide Godot & Equinox: latar navy gelap, tipografi ber-tracking, garis tipis.
## Interaktif (halus): arahkan mouse ke foto -> foto membesar sedikit, cincin menyala, nama & peran berwarna aksen,
## dan garis kecil di bawah nama memanjang. Kartu lain tidak berubah.
class DevSlide extends Slide:
	var title_l: Label
	var title_line: ColorRect
	var sign_l: Label
	var cards: Array = []
	var avatars: Array = []
	var names: Array = []
	var roles: Array = []
	var lines: Array = []
	var accents: Array = []
	var _y_title: float = 0.0
	var _y_sign: float = 0.0

	const CARD_Y := 150.0                  # posisi atas kartu (avatar berpusat di CARD_Y + 150)

	func _init(font: Font) -> void:
		super()
		hint_color = Color(0.52, 0.56, 0.66, 0.8)
		_radial(Color("232837"), Color("0d0f16"), Rect2(0, 0, 1280, 720), Vector2(0.5, 0.45), 0.85)

		title_l = _label("DEVELOPED BY", font, 30, Color("c9cdd6"), 74.0, 22)
		_y_title = title_l.position.y
		title_line = ColorRect.new()
		title_line.color = Color("4a5164")
		title_line.size = Vector2(0.0, 2.0)
		title_line.position = Vector2(640.0, 128.0)
		title_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(title_line)

		var team: Array = AboutData.TEAM
		var n: int = team.size()
		var gap: float = 340.0 if n <= 3 else 1100.0 / float(n)
		for i in n:
			var m: Dictionary = team[i]
			var accent: Color = Color(String(m.get("accent", "ffd23f")))
			var cx: float = 640.0 + (float(i) - float(n - 1) * 0.5) * gap

			var card := Control.new()
			card.size = Vector2(300.0, 400.0)
			card.position = Vector2(cx - 150.0, CARD_Y)
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(card)

			var av := Avatar.new()
			av.accent = accent
			var lp: String = String(m.get("logo", ""))
			if lp != "" and ResourceLoader.exists(lp):
				av.tex = load(lp) as Texture2D
			av.size = Vector2(300.0, 300.0)
			av.phase = float(i) * 1.3
			card.add_child(av)

			var nm := _card_label(String(m.get("name", "")), font, 38, Color("eef0f5"), 0, Vector2(0.0, 300.0))
			card.add_child(nm)
			var rl: Array = m.get("roles", [])
			var role_txt: String = "  /  ".join(PackedStringArray(rl)).to_upper()
			var ro := _card_label(role_txt, font, 17, Color("7c8394"), 7, Vector2(0.0, 352.0))
			card.add_child(ro)
			var ln := ColorRect.new()                 # garis kecil di bawah peran, memanjang saat di-hover
			ln.color = accent
			ln.size = Vector2(0.0, 2.0)
			ln.position = Vector2(150.0, 386.0)
			ln.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(ln)

			cards.append(card)
			avatars.append(av)
			names.append(nm)
			roles.append(ro)
			lines.append(ln)
			accents.append(accent)

		sign_l = _label(AboutData.MESSAGE_SIGNATURE, font, 15, Color("5d6578"), 664.0, 10)
		_y_sign = sign_l.position.y

	func _card_label(txt: String, font: Font, fs: int, col: Color, track: int, pos: Vector2) -> Label:
		var fv := FontVariation.new()
		fv.base_font = font
		fv.spacing_glyph = track
		var l := Label.new()
		l.text = txt
		l.add_theme_font_override("font", fv)
		l.add_theme_font_size_override("font_size", fs)
		l.add_theme_color_override("font_color", col)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.position = pos + Vector2(float(track) * 0.5, 0.0)
		l.size = Vector2(300.0, float(fs) * 1.4)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return l

	func animate(t: float, a: float) -> void:
		var rise_t: float = (1.0 - _ease_out(t / 1.0)) * 14.0
		title_l.position.y = _y_title + rise_t
		sign_l.position.y = _y_sign + rise_t
		var w: float = 110.0 * _ease_out((t - 0.4) / 1.2)
		title_line.size.x = w
		title_line.position.x = 640.0 - w * 0.5
		title_line.modulate.a = a
		sign_l.modulate.a = clampf((t - 0.9) / 0.9, 0.0, 1.0)
		for i in cards.size():
			var c: Control = cards[i]
			var local: float = t - 0.15 - float(i) * 0.2          # kartu muncul satu per satu (berurutan)
			var k: float = _ease_out(local / 1.0)
			c.modulate.a = clampf(local / 0.9, 0.0, 1.0)
			c.position.y = CARD_Y + (1.0 - k) * 26.0
			var av: Avatar = avatars[i]
			av.t = t
			var hv: float = av.hover
			var acc: Color = accents[i]
			(names[i] as Label).add_theme_color_override("font_color", Color("eef0f5").lerp(acc.lerp(Color.WHITE, 0.25), hv))
			(roles[i] as Label).add_theme_color_override("font_color", Color("7c8394").lerp(acc, hv))
			var lw: float = 90.0 * hv
			(lines[i] as ColorRect).size.x = lw
			(lines[i] as ColorRect).position.x = 150.0 - lw * 0.5


## Foto developer berbentuk lingkaran: cincin tipis berwarna aksen, cahaya sangat lembut, reaksi halus saat di-hover.
class Avatar extends Control:
	var tex: Texture2D = null
	var accent: Color = Color("ffd23f")
	var t: float = 0.0
	var phase: float = 0.0
	var hover: float = 0.0                 # 0..1, halus
	const R := 100.0

	func _process(d: float) -> void:
		var c: Vector2 = size * 0.5
		var over: bool = is_visible_in_tree() and get_global_mouse_position().distance_to(get_global_rect().position + c) < R + 12.0
		hover = lerpf(hover, 1.0 if over else 0.0, minf(1.0, d * 10.0))
		queue_redraw()

	func _draw() -> void:
		var h: float = hover
		var r: float = R * (1.0 + 0.06 * h)
		var c: Vector2 = size * 0.5 + Vector2(0.0, sin(t * 1.4 + phase) * 3.0)
		for k in 4:                                        # cahaya lembut (menguat saat hover)
			draw_circle(c, r + 8.0 + float(k) * 10.0, Color(accent.r, accent.g, accent.b, (0.035 + 0.04 * h) * float(4 - k) / 4.0))
		draw_circle(c + Vector2(3.0, 7.0), r + 5.0, Color(0, 0, 0, 0.45))
		draw_circle(c, r + 4.0, Color(0.06, 0.07, 0.10, 1.0))
		if tex != null:
			var pts := PackedVector2Array()
			var uvs := PackedVector2Array()
			var seg: int = 96
			for i in seg + 1:
				var a: float = TAU * float(i) / float(seg)
				var d := Vector2(cos(a), sin(a))
				pts.append(c + d * r)
				uvs.append(Vector2(0.5, 0.5) + d * 0.5)
			draw_colored_polygon(pts, Color.WHITE, uvs, tex)
		else:
			draw_circle(c, r, Color(0.12, 0.13, 0.18))
		var ring: Color = Color(accent.r, accent.g, accent.b, 0.75 + 0.25 * h).lerp(Color.WHITE, 0.2 * h)
		draw_arc(c, r + 2.0, 0.0, TAU, 96, ring, 3.0 + 1.5 * h, true)
