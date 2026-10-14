class_name UIKit
extends RefCounted
## Kumpulan komponen UI buatan sendiri (semua digambar lewat kode, tanpa aset gambar baru):
##   PadGlyph        glyph tombol PlayStation (✕ ○ □ △) / Xbox / keyboard, ikut berganti otomatis
##   PromptBar       baris petunjuk tombol di bawah layar
##   FxBackground    background animasi (shader + partikel + crossfade gambar)
##   FancyButton     tombol menu miring ala game konsol
##   SettingRow      baris pengaturan (slider / toggle / choice)
##   Poster          kartu potret karakter bergaya komik
##   ScreenTransition  transisi antar scene (bilah diagonal)
##   RingFx          efek gelombang kejut

const INK := Color("0b0b1c")
const PANEL := Color(0.06, 0.06, 0.14, 0.9)
const GOLD := Color("ffd23f")
const RED := Color("ff4040")
const GREEN := Color("4be3a0")
const CYAN := Color("4fd8ff")

const BG_SHADER := """
shader_type canvas_item;
uniform vec4 col_a : source_color = vec4(0.04, 0.04, 0.12, 1.0);
uniform vec4 col_b : source_color = vec4(0.14, 0.06, 0.28, 1.0);
uniform vec4 accent : source_color = vec4(1.0, 0.82, 0.25, 1.0);
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float alpha = 1.0;
uniform float stripes = 1.0;
void fragment() {
	vec2 uv = UV;
	vec2 px = uv * rect_size;
	vec3 c = mix(col_a.rgb, col_b.rgb, smoothstep(0.0, 1.0, uv.y));
	float g = 1.0 - length((uv - vec2(0.5, 0.42)) * vec2(1.2, 1.6));
	c += accent.rgb * max(g, 0.0) * 0.16;
	float d = (px.x * 0.7 + px.y) / 130.0 - TIME * 0.10;
	float f = fract(d);
	float s = smoothstep(0.0, 0.03, f) * (1.0 - smoothstep(0.42, 0.46, f));
	c += accent.rgb * s * 0.05 * stripes;
	vec2 cell = px / 12.0;
	vec2 q = fract(cell) - 0.5;
	float corner = smoothstep(0.30, 1.0, length((uv - 0.5) * 1.55));
	float r = 0.10 + corner * 0.36;
	float dots = 1.0 - smoothstep(r - 0.07, r, length(q));
	c = mix(c, c * 0.40, dots * corner);
	c *= mix(1.0, 0.55, smoothstep(0.35, 0.95, length((uv - 0.5) * vec2(1.1, 1.3))));
	COLOR = vec4(c, alpha);
}
"""


# ------------------------------------------------------------------ helper statis
static func tw(node: Node) -> Tween:
	var t := node.create_tween()
	t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return t


## Jajar genjang miring ("/") dengan lebar w, tinggi h.
static func slanted(w: float, h: float, skew: float, x: float = 0.0, y: float = 0.0) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x + skew, y), Vector2(x + w, y),
		Vector2(x + w - skew, y + h), Vector2(x, y + h),
	])


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var res := pts.duplicate()
	res.append(pts[0])
	return res


## Nama tombol keyboard yang enak dibaca di layar.
static func key_label(code: int) -> String:
	match code:
		KEY_SLASH: return "/"
		KEY_PERIOD: return "."
		KEY_KP_PERIOD: return "NUM ."
		KEY_COMMA: return ","
	var s: String = OS.get_keycode_string(code as Key).to_upper()
	return s.replace("KP ", "NUM ")


static func font() -> Font:
	return Global.font_ui if Global.font_ui != null else ThemeDB.fallback_font


## Gambar teks dengan baseline otomatis di tengah rect.
static func text_in(ci: CanvasItem, s: String, rect: Rect2, fsize: int, color: Color,
		align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER, outline: int = 0,
		outline_color: Color = Color.BLACK, f: Font = null) -> void:
	var fnt: Font = f if f != null else font()
	var asc: float = fnt.get_ascent(fsize)
	var desc: float = fnt.get_descent(fsize)
	var y: float = rect.position.y + (rect.size.y - (asc + desc)) * 0.5 + asc
	var pos := Vector2(rect.position.x, y)
	if outline > 0:
		ci.draw_string_outline(fnt, pos, s, align, rect.size.x, fsize, outline, outline_color)
	ci.draw_string(fnt, pos, s, align, rect.size.x, fsize, color)


static func text_w(s: String, fsize: int, f: Font = null) -> float:
	var fnt: Font = f if f != null else font()
	return fnt.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x


static func label(s: String, fsize: int, color: Color = Color.WHITE, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font())
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Ledakan partikel kotak-kotak (gaya pixel).
static func burst(parent: Node, pos: Vector2, color: Color, count: int = 24, speed: float = 280.0,
		psize: float = 6.0, life: float = 0.7, gravity: float = 700.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.scale_amount_min = psize * 0.5
	p.scale_amount_max = psize
	p.color = color
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	p.z_index = 50
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func ring(parent: Node, pos: Vector2, color: Color, radius: float = 120.0, dur: float = 0.5) -> void:
	var r := RingFx.new()
	r.position = pos
	r.color = color
	r.z_index = 49
	parent.add_child(r)
	r.play(radius, dur)


# ------------------------------------------------------------------ ikon gambar
static func draw_lock(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_arc(c + Vector2(0, -s * 0.28), s * 0.26, PI, TAU, 14, color, maxf(2.0, s * 0.1), true)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.36, -s * 0.28), Vector2(s * 0.72, s * 0.56)), color)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.06, -s * 0.08), Vector2(s * 0.12, s * 0.2)), Color(0, 0, 0, 0.6))


static func draw_pad_icon(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_circle(c + Vector2(-s * 0.3, 0), s * 0.3, color)
	ci.draw_circle(c + Vector2(s * 0.3, 0), s * 0.3, color)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.3), Vector2(s * 0.6, s * 0.6)), color)
	var dark := Color(0, 0, 0, 0.55)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.42, -s * 0.05), Vector2(s * 0.22, s * 0.1)), dark)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.36, -s * 0.11), Vector2(s * 0.1, s * 0.22)), dark)
	ci.draw_circle(c + Vector2(s * 0.28, -s * 0.07), s * 0.05, dark)
	ci.draw_circle(c + Vector2(s * 0.4, s * 0.05), s * 0.05, dark)


static func draw_keys_icon(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-s * 0.5, -s * 0.3), Vector2(s, s * 0.6)), color)
	var dark := Color(0, 0, 0, 0.55)
	for i in 4:
		ci.draw_rect(Rect2(c + Vector2(-s * 0.42 + i * s * 0.22, -s * 0.2), Vector2(s * 0.16, s * 0.16)), dark)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.3, s * 0.04), Vector2(s * 0.6, s * 0.14)), dark)


static func draw_chevron(ci: CanvasItem, c: Vector2, s: float, dir: int, color: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-dir * s * 0.5, -s), c + Vector2(dir * s * 0.5, 0), c + Vector2(-dir * s * 0.5, s),
	])
	ci.draw_colored_polygon(pts, color)


# ================================================================== PadGlyph
class PadGlyph extends Control:
	var action: StringName = &"accept"
	var h: float = 34.0
	var force: String = ""          # "" = ikuti input terakhir; "pad" / "key" = paksa
	var style_force: String = ""    # "ps" / "xbox" / "" (otomatis)
	var custom_key: String = ""     # teks keycap khusus (mis. tombol tembak pemain tertentu)
	var player: int = -1            # >= 0: glyph otomatis = TOMBOL TEMBAK pemain ini (ikut keybind & perangkat)
	var pill_override: String = ""  # teks pil khusus (dipakai mode player untuk tombol controller yang tidak punya ikon)
	var _sig: int = -1

	func _init(a: StringName = &"accept", height: float = 34.0, forced: String = "") -> void:
		action = a
		h = height
		force = forced
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_refresh_size()

	func _ready() -> void:
		UIInput.kind_changed.connect(_on_kind)

	func _on_kind(_k: String) -> void:
		_refresh_size()
		queue_redraw()

	func _kind() -> String:
		if player >= 0:
			return "pad" if Global.uses_pad(player) else "key"
		return force if force != "" else UIInput.kind

	func _style() -> String:
		if player >= 0:
			var d: int = Global.device_of(player)
			return UIInput.pad_style(d if d >= 0 else -2)
		return style_force if style_force != "" else UIInput.pad_style()

	## Mode player: samakan glyph dengan tombol tembak pemain (keyboard / controller) yang sekarang.
	## Mengembalikan true kalau tampilannya berubah (ukuran bisa ikut berubah).
	func sync_player() -> bool:
		if player < 0:
			return false
		var kd: int = 1 if Global.uses_pad(player) else 0
		var code: int = int(Global.pad_bindings[player]["shoot"]) if kd == 1 else int(Global.key_bindings[player]["shoot"])
		var st: int = 1 if _style() == "xbox" else 0
		var sig: int = kd * 1000000 + st * 100000 + code
		if sig == _sig:
			return false
		_sig = sig
		_resolve_player_glyph(kd == 1, code)
		_refresh_size()
		size = custom_minimum_size
		pivot_offset = size * 0.5
		queue_redraw()
		return true

	## Ubah kode tombol controller menjadi ikon yang sesuai (✕ ○ □ △ / L1 R1 / R2 / teks).
	func _resolve_player_glyph(on_pad: bool, code: int) -> void:
		pill_override = ""
		if not on_pad:
			custom_key = UIKit.key_label(code)
			return
		custom_key = ""
		if code >= Global.PAD_AXIS_BASE:
			if code - Global.PAD_AXIS_BASE == JOY_AXIS_TRIGGER_RIGHT:
				action = &"r2"
			else:
				action = &"pill"
				pill_override = Global.pad_button_name(code, _style())
			return
		match code:
			JOY_BUTTON_A: action = &"accept"
			JOY_BUTTON_B: action = &"back"
			JOY_BUTTON_X: action = &"alt"
			JOY_BUTTON_Y: action = &"extra"
			JOY_BUTTON_LEFT_SHOULDER: action = &"prev"
			JOY_BUTTON_RIGHT_SHOULDER: action = &"next"
			_:
				action = &"pill"
				pill_override = Global.pad_button_name(code, _style())

	func _key_text() -> String:
		if custom_key != "":
			return custom_key
		match action:
			&"accept": return "ENTER"
			&"back", &"start": return "ESC"
			&"alt": return "R"
			&"extra": return "TAB"
			&"prev": return "Q"
			&"next": return "E"
			&"r2": return _kn("shoot")
			&"dpad_lr": return "%s  %s" % [_kn("left"), _kn("right")]
			&"dpad_ud": return "%s  %s" % [_kn("up"), _kn("down")]
			&"dpad", &"stick": return "%s%s%s%s" % [_kn("up"), _kn("left"), _kn("down"), _kn("right")]
		return "?"

	## Nama tombol keyboard P1 untuk satu aksi (mengikuti keybind yang diatur pemain).
	func _kn(act: String) -> String:
		return UIKit.key_label(int(Global.key_bindings[0][act]))

	func _pill_text() -> String:
		if pill_override != "":
			return pill_override
		var xb: bool = _style() == "xbox"
		match action:
			&"start": return "MENU" if xb else "OPTIONS"
			&"prev": return "LB" if xb else "L1"
			&"next": return "RB" if xb else "R1"
			&"r2": return "RT" if xb else "R2"
		return ""

	func _refresh_size() -> void:
		var w: float = h
		if _kind() == "key":
			w = maxf(h, UIKit.text_w(_key_text(), int(h * 0.5)) + h * 0.7)
		elif _pill_text() != "":
			w = maxf(h * 1.2, UIKit.text_w(_pill_text(), int(h * 0.46)) + h * 0.6)
		custom_minimum_size = Vector2(w, h)

	func _draw() -> void:
		if _kind() == "key":
			_draw_key()
			return
		var c := size * 0.5
		match action:
			&"accept", &"back", &"alt", &"extra":
				_draw_face(c)
			&"dpad", &"dpad_lr", &"dpad_ud":
				_draw_dpad(c)
			&"stick":
				_draw_stick(c)
			_:
				_draw_pill(c)

	func _draw_key() -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.93, 0.93, 0.97)
		sb.set_corner_radius_all(int(h * 0.2))
		sb.border_color = Color(0.55, 0.57, 0.7)
		sb.border_width_bottom = int(maxf(3.0, h * 0.1))
		draw_style_box(sb, Rect2(Vector2.ZERO, size))
		var t: String = _key_text()
		if action == &"dpad_lr" or action == &"dpad_ud":
			t = t.replace("  ", " ")
		UIKit.text_in(self, t, Rect2(0, -2, size.x, size.y - 2), int(h * 0.5), UIKit.INK)

	func _draw_face(c: Vector2) -> void:
		var r: float = h * 0.5 - 1.0
		var xb: bool = _style() == "xbox"
		draw_circle(c, r, Color(0.07, 0.07, 0.14, 0.96))
		draw_arc(c, r, 0, TAU, 28, Color(1, 1, 1, 0.85), 2.0, true)
		var d: float = r * 0.46
		var w: float = maxf(2.5, h * 0.09)
		if xb:
			var letter := "A"
			var col := Color("5fd35f")
			match action:
				&"back": letter = "B"; col = Color("ff5a5a")
				&"alt": letter = "X"; col = Color("5aa0ff")
				&"extra": letter = "Y"; col = Color("ffd23f")
			UIKit.text_in(self, letter, Rect2(0, -1, size.x, size.y), int(h * 0.62), col)
			return
		match action:
			&"accept":
				var col := Color("6f9bff")
				draw_line(c + Vector2(-d, -d), c + Vector2(d, d), col, w, true)
				draw_line(c + Vector2(-d, d), c + Vector2(d, -d), col, w, true)
			&"back":
				draw_arc(c, d * 1.2, 0, TAU, 24, Color("ff5f78"), w, true)
			&"alt":
				draw_rect(Rect2(c - Vector2(d, d), Vector2(d * 2, d * 2)), Color("ff9ad8"), false, w)
			&"extra":
				var tri := PackedVector2Array([
					c + Vector2(0, -d * 1.2), c + Vector2(d * 1.15, d * 0.9),
					c + Vector2(-d * 1.15, d * 0.9), c + Vector2(0, -d * 1.2),
				])
				draw_polyline(tri, Color("4be3a0"), w, true)

	func _draw_pill(c: Vector2) -> void:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.07, 0.14, 0.96)
		sb.set_corner_radius_all(int(h * 0.3))
		sb.border_color = Color(1, 1, 1, 0.85)
		sb.set_border_width_all(2)
		draw_style_box(sb, Rect2(Vector2(0, h * 0.12), Vector2(size.x, size.y - h * 0.24)))
		UIKit.text_in(self, _pill_text(), Rect2(0, -1, size.x, size.y), int(h * 0.46), Color.WHITE)

	func _draw_dpad(c: Vector2) -> void:
		var t: float = h * 0.3
		var l: float = h * 0.46
		var base := Color(1, 1, 1, 0.55)
		var hi := UIKit.GOLD
		var lr: bool = action == &"dpad" or action == &"dpad_lr"
		var ud: bool = action == &"dpad" or action == &"dpad_ud"
		var cl: Color = hi if lr else base
		var cu: Color = hi if ud else base
		draw_rect(Rect2(c + Vector2(-l, -t * 0.5), Vector2(l - t * 0.5, t)), cl)
		draw_rect(Rect2(c + Vector2(t * 0.5, -t * 0.5), Vector2(l - t * 0.5, t)), cl)
		draw_rect(Rect2(c + Vector2(-t * 0.5, -l), Vector2(t, l - t * 0.5)), cu)
		draw_rect(Rect2(c + Vector2(-t * 0.5, t * 0.5), Vector2(t, l - t * 0.5)), cu)
		draw_rect(Rect2(c - Vector2(t * 0.5, t * 0.5), Vector2(t, t)), base)

	func _draw_stick(c: Vector2) -> void:
		var r: float = h * 0.46
		draw_arc(c, r, 0, TAU, 28, Color(1, 1, 1, 0.8), 2.0, true)
		draw_circle(c, r * 0.55, UIKit.GOLD)
		draw_arc(c, r * 0.55, 0, TAU, 20, Color(0, 0, 0, 0.5), 2.0, true)


# ================================================================== PromptBar
class PromptBar extends HBoxContainer:
	var gsize: float = 32.0
	var fsize: int = 24
	var plate: bool = true

	func _init() -> void:
		alignment = BoxContainer.ALIGNMENT_CENTER
		add_theme_constant_override("separation", 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## items: [[action, "TEKS"], ...]  atau [action, "TEKS", {"force": "pad"/"key", "key": "F"}]
	func set_prompts(items: Array) -> void:
		for c in get_children():
			remove_child(c)
			c.queue_free()
		for it in items:
			var box := HBoxContainer.new()
			box.add_theme_constant_override("separation", 8)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(box)
			if it[0] != &"none":   # &"none" = hanya teks, tanpa glyph tombol
				var g := PadGlyph.new(it[0], gsize)
				if it.size() > 2:
					var opts: Dictionary = it[2]
					g.force = opts.get("force", "")
					g.custom_key = opts.get("key", "")
					g._refresh_size()
				g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				box.add_child(g)
			var l := UIKit.label(String(it[1]), fsize, Color.WHITE, 5)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			box.add_child(l)
		queue_redraw()

	func _draw() -> void:
		if not plate:
			return
		var pad := 26.0
		var r := Rect2(-pad, -8, size.x + pad * 2.0, size.y + 16)
		draw_colored_polygon(UIKit.slanted(r.size.x, r.size.y, 18.0, r.position.x, r.position.y), Color(0, 0, 0, 0.55))
		draw_polyline(UIKit.closed(UIKit.slanted(r.size.x, r.size.y, 18.0, r.position.x, r.position.y)), Color(1, 1, 1, 0.14), 2.0, true)


# ================================================================== FxBackground
## Shader latar dibuat SEKALI lalu dipakai semua FxBackground (menu, shop, inventory, dst).
## Dulu tiap layar membuat Shader baru -> dikompilasi ulang di GPU saat layar dibuka (patah di awal).
static var _bg_shader: Shader = null


class FxBackground extends Control:
	var rect: ColorRect
	var mat: ShaderMaterial
	var img_a: TextureRect
	var img_b: TextureRect
	var particles: CPUParticles2D
	var _front_is_a := true
	var _pal_tw: Tween
	var _zoom_tw: Tween

	func _init(a: Color = Color("0a0a1e"), b: Color = Color("24104a"), accent: Color = Color("ffd23f")) -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

		img_a = _make_img()
		img_b = _make_img()
		img_a.modulate.a = 0.0
		img_b.modulate.a = 0.0

		if UIKit._bg_shader == null:
			UIKit._bg_shader = Shader.new()
			UIKit._bg_shader.code = UIKit.BG_SHADER
		mat = ShaderMaterial.new()
		mat.shader = UIKit._bg_shader
		rect = ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.material = mat
		add_child(rect)
		mat.set_shader_parameter("col_a", a)
		mat.set_shader_parameter("col_b", b)
		mat.set_shader_parameter("accent", accent)

		particles = CPUParticles2D.new()
		particles.position = Vector2(640, 740)
		particles.amount = 38
		particles.lifetime = 6.0
		particles.preprocess = 6.0
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.emission_rect_extents = Vector2(680, 4)
		particles.direction = Vector2(0.15, -1)
		particles.spread = 18.0
		particles.initial_velocity_min = 30.0
		particles.initial_velocity_max = 110.0
		particles.gravity = Vector2.ZERO
		particles.scale_amount_min = 2.5
		particles.scale_amount_max = 7.0
		particles.color = accent
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 0.0))
		g.add_point(0.2, Color(1, 1, 1, 0.8))
		g.set_color(1, Color(1, 1, 1, 0.0))
		particles.color_ramp = g
		add_child(particles)
		resized.connect(_on_resized)

	func _make_img() -> TextureRect:
		var t := TextureRect.new()
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.set_anchors_preset(Control.PRESET_FULL_RECT)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(t)
		return t

	func _ready() -> void:
		_on_resized()

	func _on_resized() -> void:
		mat.set_shader_parameter("rect_size", size)
		img_a.pivot_offset = size * 0.5
		img_b.pivot_offset = size * 0.5
		particles.position = Vector2(size.x * 0.5, size.y + 20.0)
		particles.emission_rect_extents = Vector2(size.x * 0.55, 4.0)

	var _pal_from: Array[Color] = []
	var _pal_to: Array[Color] = []

	func set_palette(a: Color, b: Color, accent: Color, dur: float = 0.6) -> void:
		_pal_from = [
			mat.get_shader_parameter("col_a"), mat.get_shader_parameter("col_b"), mat.get_shader_parameter("accent"),
		]
		_pal_to = [a, b, accent]
		if _pal_tw:
			_pal_tw.kill()
		if not is_inside_tree() or dur <= 0.0:
			_apply_palette(1.0)
			return
		_pal_tw = UIKit.tw(self)
		_pal_tw.tween_method(_apply_palette, 0.0, 1.0, dur)

	func _apply_palette(t: float) -> void:
		mat.set_shader_parameter("col_a", _pal_from[0].lerp(_pal_to[0], t))
		mat.set_shader_parameter("col_b", _pal_from[1].lerp(_pal_to[1], t))
		var ac: Color = _pal_from[2].lerp(_pal_to[2], t)
		mat.set_shader_parameter("accent", ac)
		particles.color = ac

	## Tampilkan gambar di belakang efek (crossfade halus + zoom pelan). overlay = 0..1 seberapa pekat efek di atasnya.
	func set_image(tex: Texture2D, overlay: float = 0.66, dur: float = 0.45) -> void:
		mat.set_shader_parameter("alpha", overlay if tex != null else 1.0)
		var incoming: TextureRect = img_b if _front_is_a else img_a
		var outgoing: TextureRect = img_a if _front_is_a else img_b
		_front_is_a = not _front_is_a
		incoming.texture = tex
		incoming.scale = Vector2.ONE * 1.0
		if not is_inside_tree():
			incoming.modulate.a = 1.0 if tex != null else 0.0
			outgoing.modulate.a = 0.0
			return
		var t := UIKit.tw(self)
		t.set_parallel(true)
		t.tween_property(incoming, "modulate:a", 1.0 if tex != null else 0.0, dur)
		t.tween_property(outgoing, "modulate:a", 0.0, dur)
		if _zoom_tw:
			_zoom_tw.kill()
		_zoom_tw = UIKit.tw(self)
		_zoom_tw.tween_property(incoming, "scale", Vector2.ONE * 1.07, 16.0).set_trans(Tween.TRANS_SINE)


# ================================================================== FancyButton
class FancyButton extends Control:
	signal activated
	signal hovered

	var text: String = ""
	var tag: String = ""
	var font_size: int = 40
	var skew: float = 20.0
	var accent: Color = UIKit.GOLD
	var disabled: bool = false
	var selected: bool = false
	## true = tombol menyorot sendiri saat kursor mouse di atasnya (geser + warna aksen + kilau + kursor tangan).
	## Dipakai tombol mandiri seperti BACK. Tombol menu yang sudah diatur layarnya (hover -> pilih) tidak perlu.
	var auto_hover: bool = false
	## Transparansi saat tombol tidak disorot (hover / fokus keyboard-controller membuatnya penuh 1.0).
	var idle_alpha: float = 1.0
	var sel: float = 0.0:
		set(v):
			sel = v
			queue_redraw()
	var flash: float = 0.0:
		set(v):
			flash = v
			queue_redraw()
	var _tw: Tween
	var _hov: bool = false

	func _init(t: String = "", sz: Vector2 = Vector2(460, 74), fsize: int = 40) -> void:
		text = t
		custom_minimum_size = sz
		size = sz
		font_size = fsize
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		pivot_offset = sz * 0.5

	func _ready() -> void:
		if auto_hover:
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)
		if idle_alpha < 1.0 and not selected:
			modulate.a = idle_alpha

	func _on_mouse_entered() -> void:
		hovered.emit()
		if auto_hover and not _hov:
			_hov = true
			if not disabled:
				Global.play_sfx("ui_hover", -9.0)
			_sync_sel()

	func _on_mouse_exited() -> void:
		if auto_hover and _hov:
			_hov = false
			_sync_sel()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			press()

	## Tombol sedang tampil menyala? (fokus keyboard / controller ATAU kursor mouse di atasnya)
	func is_lit() -> bool:
		return selected or (auto_hover and _hov and not disabled)

	func set_selected(v: bool) -> void:
		if v == selected:
			return
		selected = v
		_sync_sel()

	func _sync_sel() -> void:
		var on: bool = is_lit()
		set_process(on)
		if _tw:
			_tw.kill()
		if is_inside_tree():
			_tw = UIKit.tw(self)
			_tw.set_parallel(true)
			_tw.tween_property(self, "sel", 1.0 if on else 0.0, 0.22).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			if idle_alpha < 1.0:
				_tw.tween_property(self, "modulate:a", 1.0 if on else idle_alpha, 0.18)
		else:
			sel = 1.0 if on else 0.0
			if idle_alpha < 1.0:
				modulate.a = 1.0 if on else idle_alpha

	func press() -> void:
		if disabled:
			Global.play_sfx("ui_error", -10.0)
			if is_inside_tree():
				var t := UIKit.tw(self)
				t.tween_property(self, "position:x", position.x + 10.0, 0.04)
				t.tween_property(self, "position:x", position.x - 10.0, 0.06)
				t.tween_property(self, "position:x", position.x, 0.04)
			return
		Global.play_sfx("ui_confirm", -3.0)
		flash = 1.0
		if is_inside_tree():
			UIKit.tw(self).tween_property(self, "flash", 0.0, 0.35)
		activated.emit()

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var shift: float = sel * 30.0
		var bw: float = size.x - 34.0
		var bh: float = size.y
		var pts := UIKit.slanted(bw, bh, skew, shift, 0)
		# bayangan
		draw_colored_polygon(UIKit.slanted(bw, bh, skew, shift + 6, 7), Color(0, 0, 0, 0.45))
		var alpha: float = 0.35 if disabled else 1.0
		var base := Color(0.07, 0.07, 0.16, 0.86)
		var top := accent.lightened(0.35)
		var bot := accent.darkened(0.12)
		var c0: Color = base.lerp(top, sel)
		var c1: Color = base.lerp(bot, sel)
		draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
		# garis aksen kiri saat tidak dipilih
		if sel < 0.99:
			draw_colored_polygon(UIKit.slanted(8, bh, skew * 0.0 + 2.0, shift + 3.0, 0), Color(accent, 0.5 * (1.0 - sel)))
		draw_polyline(UIKit.closed(pts), Color(1, 1, 1, lerpf(0.16, 0.95, sel)), 2.0 + sel * 1.5, true)
		# kilau berjalan
		if is_lit():
			var ph: float = fmod(Time.get_ticks_msec() / 1000.0 * 0.7, 1.7) - 0.35
			var sx: float = shift + ph * bw
			var band := PackedVector2Array([
				Vector2(sx + skew, 0), Vector2(sx + skew + 46, 0), Vector2(sx + 46, bh), Vector2(sx, bh),
			])
			var clip := _clip_band(band, shift, bw, bh)
			if clip.size() >= 3:
				draw_colored_polygon(clip, Color(1, 1, 1, 0.28))
		# flash saat ditekan
		if flash > 0.0:
			draw_colored_polygon(pts, Color(1, 1, 1, 0.8 * flash))
		var tcol: Color = UIKit.INK if sel > 0.5 else Color(1, 1, 1, 0.88)
		tcol.a *= alpha
		var tr := Rect2(shift + skew + 22, 0, bw - skew * 2 - 30, bh)
		if sel > 0.0:
			UIKit.text_in(self, text, Rect2(tr.position + Vector2(2, 3), tr.size), font_size, Color(0, 0, 0, 0.22 * sel), HORIZONTAL_ALIGNMENT_LEFT)
		UIKit.text_in(self, text, tr, font_size, tcol, HORIZONTAL_ALIGNMENT_LEFT)
		if tag != "":
			UIKit.text_in(self, tag, Rect2(shift, 0, bw - skew - 18, bh), int(font_size * 0.5), Color(tcol, 0.7 * alpha), HORIZONTAL_ALIGNMENT_RIGHT)
		if sel > 0.01:
			var bob: float = sin(Time.get_ticks_msec() / 160.0) * 3.0 * sel
			UIKit.draw_chevron(self, Vector2(shift + skew + 6 + bob, bh * 0.5), 9.0, 1, Color(UIKit.INK, sel))

	## Potong pita kilau agar tidak keluar dari tombol (hanya clip horizontal sederhana).
	func _clip_band(band: PackedVector2Array, shift: float, bw: float, bh: float) -> PackedVector2Array:
		var shape := UIKit.slanted(bw, bh, skew, shift, 0)
		var res: Array = Geometry2D.intersect_polygons(band, shape)
		if res.is_empty():
			return PackedVector2Array()
		return res[0]


# ================================================================== SettingRow
class SettingRow extends Control:
	signal changed(value: float)

	var label_text: String = ""
	var kind: String = "slider"       # "slider" | "toggle" | "choice"
	var value: float = 0.5            # slider: 0..1, toggle: 0/1, choice: indeks pilihan di options
	var options: Array = []           # teks pilihan (khusus kind "choice"), mis. ["30", "60", "UNLIMITED"]
	var step: float = 0.1
	var selected: bool = false
	var skew: float = 18.0
	var sel: float = 0.0:
		set(v):
			sel = v
			queue_redraw()
	var nudge: float = 0.0:
		set(v):
			nudge = v
			queue_redraw()
	var _tw: Tween
	signal hovered

	func _init(t: String = "", k: String = "slider", v: float = 0.5, sz: Vector2 = Vector2(760, 70)) -> void:
		label_text = t
		kind = k
		value = v
		custom_minimum_size = sz
		size = sz
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		mouse_entered.connect(func() -> void: hovered.emit())
		set_process(true)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if kind == "toggle":
				adjust(1)
			elif kind == "choice":
				# klik separuh kiri = pilihan sebelumnya, separuh kanan = pilihan berikutnya
				var cx: float = size.x - 390.0 + 24.0 + 150.0
				adjust(-1 if event.position.x < cx else 1)
			else:
				# klik pada bar slider
				var x0: float = size.x - 390.0 + 24.0
				if event.position.x > x0 and event.position.x < x0 + 243.0:
					value = clampf((event.position.x - x0) / 243.0, 0.0, 1.0)
					value = roundf(value / step) * step
					changed.emit(value)
					queue_redraw()
					Global.play_sfx("ui_slider", -8.0)

	func set_selected(v: bool) -> void:
		if v == selected:
			return
		selected = v
		if _tw:
			_tw.kill()
		if is_inside_tree():
			_tw = UIKit.tw(self)
			_tw.tween_property(self, "sel", 1.0 if v else 0.0, 0.2).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		else:
			sel = 1.0 if v else 0.0

	func adjust(dir: int) -> void:
		var old: float = value
		if kind == "choice":
			if options.is_empty():
				return
			value = float(posmod(int(roundf(value)) + dir, options.size()))   # berputar: terakhir -> pertama
			Global.play_sfx("ui_slider", -6.0, 0.9 + (value / maxf(float(options.size() - 1), 1.0)) * 0.3)
			nudge = float(dir)
			if is_inside_tree():
				UIKit.tw(self).tween_property(self, "nudge", 0.0, 0.25)
			changed.emit(value)
			queue_redraw()
			return
		if kind == "toggle":
			value = 0.0 if value > 0.5 else 1.0
		else:
			value = clampf(roundf((value + dir * step) / step) * step, 0.0, 1.0)
		if is_equal_approx(old, value) and kind != "toggle":
			Global.play_sfx("ui_error", -14.0)
			return
		if kind == "toggle":
			Global.play_sfx("ui_toggle_on" if value > 0.5 else "ui_toggle_off", -6.0)
		else:
			Global.play_sfx("ui_slider", -6.0, 0.9 + value * 0.3)
		nudge = float(dir)
		if is_inside_tree():
			UIKit.tw(self).tween_property(self, "nudge", 0.0, 0.25)
		changed.emit(value)
		queue_redraw()

	func _draw() -> void:
		var shift: float = sel * 18.0
		var bw: float = size.x - 24.0
		var bh: float = size.y
		var pts := UIKit.slanted(bw, bh, skew, shift, 0)
		draw_colored_polygon(UIKit.slanted(bw, bh, skew, shift + 5, 6), Color(0, 0, 0, 0.4))
		var base := Color(0.07, 0.07, 0.16, 0.86)
		var hi := Color(0.2, 0.17, 0.05, 0.95)
		var c: Color = base.lerp(hi, sel)
		draw_colored_polygon(pts, c)
		draw_polyline(UIKit.closed(pts), UIKit.GOLD.lerp(Color(1, 1, 1, 0.16), 1.0 - sel), 2.0 + sel, true)
		UIKit.text_in(self, label_text, Rect2(shift + skew + 18, 0, 300, bh), 34, UIKit.GOLD.lerp(Color.WHITE, 1.0 - sel), HORIZONTAL_ALIGNMENT_LEFT)
		var x0: float = size.x - 390.0 + shift * 0.4
		if kind == "slider":
			var segs := 10
			var sw := 22.0
			var gap := 5.0
			for i in segs:
				var filled: bool = float(i) < value * segs - 0.01
				var r := Rect2(x0 + 24 + i * (sw + gap) * 0.9, bh * 0.5 - 15 + (0.0 if filled else 4.0), sw * 0.9, 30.0 if filled else 22.0)
				var col: Color = UIKit.GOLD if filled else Color(1, 1, 1, 0.16)
				draw_colored_polygon(UIKit.slanted(r.size.x, r.size.y, 5.0, r.position.x, r.position.y), col)
			UIKit.text_in(self, "%d%%" % int(round(value * 100.0)), Rect2(x0 + 24 + segs * (sw + gap) * 0.9 + 6, 0, 80, bh), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
			if sel > 0.01:
				var pul: float = 1.0 + sin(Time.get_ticks_msec() / 150.0) * 0.15
				UIKit.draw_chevron(self, Vector2(x0 + 4 - nudge * 4, bh * 0.5), 9.0 * pul, -1, Color(UIKit.GOLD, sel))
		elif kind == "choice":
			var cx: float = x0 + 24.0 + 150.0
			var idx: int = clampi(int(roundf(value)), 0, maxi(options.size() - 1, 0))
			var txt: String = String(options[idx]) if not options.is_empty() else ""
			var pulc: float = 1.0 + sin(Time.get_ticks_msec() / 150.0) * 0.15
			var ccol := Color(UIKit.GOLD, 0.35 + 0.65 * sel)
			UIKit.draw_chevron(self, Vector2(cx - 124.0 - nudge * 4.0, bh * 0.5), 9.0 * (pulc if sel > 0.01 else 1.0), -1, ccol)
			UIKit.draw_chevron(self, Vector2(cx + 124.0 - nudge * 4.0, bh * 0.5), 9.0 * (pulc if sel > 0.01 else 1.0), 1, ccol)
			UIKit.text_in(self, txt, Rect2(cx - 105.0, 0, 210, bh), 30, UIKit.GOLD.lerp(Color.WHITE, 1.0 - sel), HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var on: bool = value > 0.5
			var pill := Rect2(x0 + 40, bh * 0.5 - 20, 150, 40)
			var sb := StyleBoxFlat.new()
			sb.bg_color = UIKit.GREEN.darkened(0.2) if on else Color(0.25, 0.25, 0.3)
			sb.set_corner_radius_all(20)
			sb.border_color = Color(1, 1, 1, 0.7)
			sb.set_border_width_all(2)
			draw_style_box(sb, pill)
			var kx: float = pill.position.x + (pill.size.x - 36.0 - 4.0 if on else 4.0)
			draw_circle(Vector2(kx + 18.0, pill.position.y + 20.0), 15.0, Color.WHITE)
			UIKit.text_in(self, "ON" if on else "OFF", Rect2(pill.position.x + (12 if on else 46), pill.position.y, 90, 40), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)

	func _process(_d: float) -> void:
		if selected:
			queue_redraw()


# ================================================================== Poster
class Poster extends Control:
	var tex: Texture2D
	var color: Color = Color.WHITE
	var tag: String = ""
	var skew: float = 14.0
	var gray: float = 0.0:
		set(v):
			gray = v
			queue_redraw()
	var glow: float = 0.0:
		set(v):
			glow = v
			queue_redraw()

	func _init(t: Texture2D = null, c: Color = Color.WHITE, label_text: String = "", sz: Vector2 = Vector2(180, 220)) -> void:
		tex = t
		color = c
		tag = label_text
		custom_minimum_size = sz
		size = sz
		pivot_offset = sz * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_colored_polygon(UIKit.slanted(w, h, skew, 8, 9), Color(0, 0, 0, 0.5))
		var pts := UIKit.slanted(w, h, skew)
		var cl: Color = color.lightened(0.2).lerp(Color(0.4, 0.4, 0.45), gray)
		var cd: Color = color.darkened(0.45).lerp(Color(0.12, 0.12, 0.15), gray)
		draw_polygon(pts, PackedColorArray([cl, cl, cd, cd]))
		# pita kilau
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.55, 0), Vector2(w * 0.72, 0), Vector2(w * 0.42, h), Vector2(w * 0.25, h),
		]), Color(1, 1, 1, 0.07))
		var tag_h: float = 34.0 if tag != "" else 0.0
		var ps: float = minf(w - skew * 2.0 - 20.0, h - tag_h - 22.0)
		var prect := Rect2((w - ps) * 0.5 + 2, 12, ps, ps)
		if tex != null:
			draw_rect(Rect2(prect.position - Vector2(4, 4), prect.size + Vector2(8, 8)), Color(0, 0, 0, 0.7))
			var m: Color = Color.WHITE.lerp(Color(0.4, 0.4, 0.45, 1.0), gray)
			draw_texture_rect(tex, prect, false, m)
		if tag != "":
			UIKit.text_in(self, tag, Rect2(0, h - tag_h - 2, w, tag_h), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 6)
		var bc: Color = Color(1, 1, 1, 0.9).lerp(color.lightened(0.5), glow)
		draw_polyline(UIKit.closed(pts), bc, 3.0 + glow * 3.0, true)


# ================================================================== ScreenTransition
class ScreenTransition extends Control:
	const BARS := 9
	var progress: float = 0.0:
		set(v):
			progress = v
			visible = v > 0.001
			queue_redraw()
	var covering: bool = true
	var accent: Color = UIKit.GOLD

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		visible = false

	func cover(dur: float = 0.38) -> void:
		covering = true
		progress = 0.001
		var t := UIKit.tw(self)
		t.tween_property(self, "progress", 1.0, dur).set_trans(Tween.TRANS_LINEAR)
		await t.finished

	func reveal(dur: float = 0.42) -> void:
		covering = false
		progress = 1.0
		var t := UIKit.tw(self)
		t.tween_property(self, "progress", 0.0, dur).set_trans(Tween.TRANS_LINEAR)
		await t.finished

	func _draw() -> void:
		if progress <= 0.001:
			return
		var w: float = size.x
		var h: float = size.y
		var bw: float = w / float(BARS)
		var sk: float = 150.0
		for i in BARS + 1:
			var order: float = float(i) / float(BARS)
			var lp: float = clampf(progress * 1.7 - order * 0.7, 0.0, 1.0)
			if not covering:
				lp = clampf(progress * 1.7 - (1.0 - order) * 0.7, 0.0, 1.0)
			lp = 1.0 - pow(1.0 - lp, 3.0)
			if lp <= 0.001:
				continue
			var ya: float = 0.0
			var yb: float = h * lp
			if not covering:
				ya = h * (1.0 - lp)
				yb = h
			var x0: float = float(i) * bw - sk
			var pts := PackedVector2Array([
				Vector2(x0 + sk * ya / h, ya), Vector2(x0 + bw + 3.0 + sk * ya / h, ya),
				Vector2(x0 + bw + 3.0 + sk * yb / h, yb), Vector2(x0 + sk * yb / h, yb),
			])
			var shade: float = 0.0 if i % 2 == 0 else 0.05
			draw_colored_polygon(pts, Color(0.04 + shade, 0.04 + shade, 0.1 + shade * 1.4))
			if lp < 0.999:
				var ey: float = yb if covering else ya
				draw_line(Vector2(x0 + sk * ey / h, ey), Vector2(x0 + bw + 3.0 + sk * ey / h, ey), accent, 8.0, true)


# ================================================================== RingFx
class RingFx extends Node2D:
	var color: Color = Color.WHITE
	var radius: float = 0.0
	var alpha: float = 1.0
	var width: float = 10.0

	func play(max_r: float, dur: float) -> void:
		var t := create_tween().set_parallel(true)
		t.tween_property(self, "radius", max_r, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(self, "alpha", 0.0, dur)
		t.tween_property(self, "width", 1.0, dur)
		t.chain().tween_callback(queue_free)

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if radius > 1.0:
			draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(color, alpha), width, true)


# ================================================================== Banner
class Banner extends Control:
	var text: String = ""
	var fsize: int = 44
	var plate: Color = UIKit.GOLD
	var text_color: Color = UIKit.INK
	var skew: float = 22.0
	var pad: float = 38.0

	func _init(t: String = "", fs: int = 44, plate_color: Color = UIKit.GOLD, tcolor: Color = UIKit.INK, padding: float = 38.0) -> void:
		fsize = fs
		plate = plate_color
		text_color = tcolor
		pad = padding
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_text(t)

	func set_text(t: String) -> void:
		text = t
		size = Vector2(UIKit.text_w(t, fsize) + pad * 2.0 + skew, fsize * 1.32)
		custom_minimum_size = size
		pivot_offset = size * 0.5
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		draw_colored_polygon(UIKit.slanted(w, h, skew, 7, 8), Color(0, 0, 0, 0.5))
		var pts := UIKit.slanted(w, h, skew)
		var c0: Color = plate.lightened(0.3)
		var c1: Color = plate.darkened(0.12)
		draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
		draw_polyline(UIKit.closed(pts), Color(1, 1, 1, 0.9), 3.0, true)
		UIKit.text_in(self, text, Rect2(skew * 0.5, 0, w - skew, h), fsize, text_color)


# ================================================================== PadStatus
## Indikator perangkat input di pojok kanan atas: 4 slot P1..P4.
## Tiap slot menampilkan perangkat yang dipakai pemain itu (controller / keyboard) sesuai SETTINGS > CONTROLS SETUP,
## dan berubah SENDIRI (dengan kilatan) begitu pengaturan diubah atau controller dicolok / dicabut.
## shown = jumlah pemain yang aktif (slot di atasnya diredupkan).
class PadStatus extends Control:
	const SLOT_W := 78.0

	var shown: int = 4:
		set(v):
			shown = clampi(v, 1, 4)
			queue_redraw()
	var _last: Array[int] = [-9, -9, -9, -9]
	var _flash: Array[float] = [0.0, 0.0, 0.0, 0.0]

	func _init() -> void:
		custom_minimum_size = Vector2(350, 46)
		size = Vector2(350, 46)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Kode keadaan slot: >=100 controller (100 + device), -1 keyboard, -2 controller dipilih tapi belum tercolok.
	func _state(i: int) -> int:
		if Global.uses_pad(i):
			return 100 + Global.device_of(i)
		if int(Global.input_pref[i]) >= 0:
			return -2
		return -1

	func _process(d: float) -> void:
		var dirty := false
		for i in 4:
			var st: int = _state(i)
			if st != _last[i]:
				if _last[i] != -9:
					_flash[i] = 1.0
				_last[i] = st
				dirty = true
			if _flash[i] > 0.0:
				_flash[i] = maxf(0.0, _flash[i] - d * 2.4)
				dirty = true
		if dirty:
			queue_redraw()

	func _draw() -> void:
		var pts := UIKit.slanted(size.x, size.y, 14.0)
		draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
		draw_polyline(UIKit.closed(pts), Color(1, 1, 1, 0.14), 2.0, true)
		for i in 4:
			var st: int = _state(i)
			var active: bool = i < shown
			var col: Color = Global.PLAYER_COLORS[i]
			var a: float = 1.0 if active else 0.3
			var r := Rect2(24.0 + i * SLOT_W, 6.0, SLOT_W - 6.0, size.y - 12.0)
			var sp := UIKit.slanted(r.size.x, r.size.y, 8.0, r.position.x, r.position.y)
			draw_colored_polygon(sp, Color(col.darkened(0.55), 0.85 * a))
			var fl: float = _flash[i]
			if fl > 0.0:
				draw_colored_polygon(sp, Color(1, 1, 1, fl * 0.7))
			draw_polyline(UIKit.closed(sp), Color(col.lightened(0.2), a).lerp(Color.WHITE, fl), 2.0 + fl * 2.0, true)
			var ic := Vector2(r.position.x + 22.0, size.y * 0.5 - fl * 2.0)
			var icol := Color(col.lightened(0.35), a)
			if st >= 100:
				UIKit.draw_pad_icon(self, ic, 24.0, icol)
			else:
				UIKit.draw_keys_icon(self, ic, 24.0, Color(icol, 0.9 * a))
			UIKit.text_in(self, "P%d" % (i + 1), Rect2(r.position.x + 36.0, r.position.y, r.size.x - 40.0, r.size.y), 20, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_LEFT, 4)
			if st == -2:   # controller dipilih di setting tapi belum terhubung
				UIKit.text_in(self, "!", Rect2(r.end.x - 16.0, r.position.y - 9.0, 14.0, 18.0), 20, Color("ff6a6a"), HORIZONTAL_ALIGNMENT_CENTER, 5)


## Bar petunjuk tombol di tengah bawah layar. Mengembalikan PromptBar-nya.
static func make_prompt(parent: Control) -> PromptBar:
	var holder := CenterContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -82
	holder.offset_bottom = -20
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(holder)
	var bar := PromptBar.new()
	holder.add_child(bar)
	return bar
