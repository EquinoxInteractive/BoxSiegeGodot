extends Control
## ======================================================================================
##  AUTO UPDATE  (scene setelah splash, SEBELUM loading screen)
## ======================================================================================
## Urutan scene: splash -> UPDATER (scene ini) -> loading -> menu
##
##   1) MEMERIKSA   : tanya GitHub Releases apakah ada versi lebih baru (butuh internet, maks. UpdateConfig.CHECK_TIMEOUT detik)
##   2) Hasil:
##        - sudah terbaru  -> centang hijau sebentar -> loading screen
##        - tidak ada internet / GitHub tidak menjawab -> game tetap boleh dimainkan offline -> loading screen
##        - ADA UPDATE     -> kartu "UPDATE TERSEDIA" (versi lama -> baru, ukuran, catatan rilis).
##                            Pemain HARUS menekan UPDATE SEKARANG, atau menekan KELUAR (game ditutup). Tidak ada tombol lewati.
##   3) MENGUNDUH   : progress bar animatif (persen, kecepatan, sisa waktu, karakter berlari di atas bar)
##   4) MEMVERIFIKASI (SHA-256) -> MEMASANG -> game ditutup, skrip pemasang mengganti file & membuka game baru otomatis.
##
## Semua pengaturan (repo GitHub, batas waktu, mode simulasi di editor) ada di update_config.gd.
## Logika (versi, pilih file, pasang) ada di update_core.gd. File ini hanya TAMPILAN + alur.
## Tampilan digambar lewat kode & shader, jadi tidak butuh file gambar baru.

const NEXT_SCENE := "res://scenes/loading.tscn"
const FONT_PATH := "res://assets/fonts/lilita_one.ttf"
const LOGO_PATH := "res://assets/sprites/ui/title.png"

const CX := 640.0
const CY := 410.0

const C_CYAN := Color("3de0ff")
const C_GOLD := Color("ffd23f")
const C_GREEN := Color("5dffa0")
const C_RED := Color("ff5a6e")
const C_PINK := Color("ff4fa3")
const C_TEXT := Color("eef0f5")
const C_DIM := Color("8f98b3")
const C_INK := Color("0b0d1a")

const SZ_STATUS := Vector2(520.0, 262.0)
const SZ_AVAIL := Vector2(820.0, 500.0)
const SZ_DL := Vector2(820.0, 432.0)
const SZ_MSG := Vector2(660.0, 340.0)

enum Phase { BOOT, CHECKING, UPTODATE, OFFLINE, AVAILABLE, DOWNLOADING, VERIFYING, INSTALLING, DONE, MSG }

# ------------------------------------------------------------------ shader latar
const BG_SHADER := """
shader_type canvas_item;
uniform vec4 c_top : source_color = vec4(0.012, 0.012, 0.06, 1.0);
uniform vec4 c_mid : source_color = vec4(0.16, 0.045, 0.28, 1.0);
uniform vec4 accent : source_color = vec4(0.24, 0.88, 1.0, 1.0);
uniform float energy = 0.0;
uniform float flash = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float asp = 1.7778;
	float hor = 0.60;
	vec3 col;
	if (uv.y < hor) {
		float k = uv.y / hor;
		col = mix(c_top.rgb, c_mid.rgb, pow(k, 1.7));
		vec2 sp = vec2(uv.x * asp, uv.y) * 38.0;
		vec2 id = floor(sp);
		vec2 f = fract(sp) - 0.5;
		float h = hash21(id);
		vec2 off = (vec2(hash21(id + 7.1), hash21(id + 3.3)) - 0.5) * 0.5;
		float star = step(0.93, h) * smoothstep(0.18, 0.0, length(f - off));
		float tw = 0.55 + 0.45 * sin(TIME * (1.5 + h * 3.0) + h * 40.0);
		col += vec3(0.8, 0.9, 1.0) * star * tw * (1.0 - k) * 1.2;
		vec2 gp = vec2((uv.x - 0.5) * asp, (uv.y - hor) * 1.5);
		col += accent.rgb * exp(-length(gp) * 2.6) * (0.34 + 0.35 * energy);
	} else {
		float y = uv.y - hor;
		float z = 1.0 / (y + 0.012);
		vec3 floorc = mix(vec3(0.05, 0.02, 0.10), c_mid.rgb * 0.5, smoothstep(0.0, 0.4, y));
		float speed = 0.5 + energy * 1.8;
		vec2 gp = vec2((uv.x - 0.5) * asp * z * 0.55, z * 0.45 - TIME * speed);
		vec2 gf = abs(fract(gp - 0.5) - 0.5) / max(fwidth(gp), vec2(0.0001));
		float line = 1.0 - min(min(gf.x, gf.y), 1.0);
		float fade = smoothstep(0.0, 0.35, y);
		col = floorc + accent.rgb * line * (0.15 + 0.85 * fade) * (0.55 + 0.45 * energy);
		col += accent.rgb * exp(-y * 14.0) * (0.35 + 0.3 * energy);
	}
	col += accent.rgb * smoothstep(0.004, 0.0, abs(uv.y - hor)) * 0.7;
	float v = smoothstep(1.15, 0.35, length((uv - vec2(0.5, 0.52)) * vec2(1.25, 1.0)));
	col *= mix(0.55, 1.0, v);
	col += vec3(flash);
	COLOR = vec4(col, 1.0);
}
"""

# ------------------------------------------------------------------ shader progress bar
const BAR_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(772.0, 68.0);
uniform float pad = 16.0;
uniform float value = 0.0;
uniform float indet = 0.0;
uniform vec4 col_a : source_color = vec4(0.14, 0.55, 1.0, 1.0);
uniform vec4 col_b : source_color = vec4(0.25, 0.95, 1.0, 1.0);
uniform vec4 glow_col : source_color = vec4(0.25, 0.9, 1.0, 1.0);
uniform float flash = 0.0;

float rr(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 px = UV * rect_size;
	vec2 c = rect_size * 0.5;
	vec2 hb = c - vec2(pad);
	float d = rr(px - c, hb, hb.y);
	float glow = exp(-max(d, 0.0) / 9.0) * (0.22 + 0.5 * value + flash);
	vec4 outc = vec4(glow_col.rgb, glow * step(0.0, d));
	if (d <= 1.0) {
		float a = 1.0 - smoothstep(-1.0, 1.0, d);
		float ty = clamp((px.y - (c.y - hb.y)) / (2.0 * hb.y), 0.0, 1.0);
		vec3 col = mix(vec3(0.10, 0.11, 0.22), vec3(0.03, 0.035, 0.08), ty);
		col = mix(col, glow_col.rgb * 0.8, smoothstep(-3.5, -2.0, d) * 0.55);
		float inner = 5.0;
		float x0 = c.x - hb.x + inner;
		float x1 = c.x + hb.x - inner;
		float s = x0;
		float e = mix(x0, x1, clamp(value, 0.0, 1.0));
		if (indet > 0.5) {
			float w = (x1 - x0) * 0.32;
			float p = fract(TIME * 0.65) * ((x1 - x0) + w) - w;
			s = clamp(x0 + p, x0, x1);
			e = clamp(x0 + p + w, x0, x1);
		}
		float fw = e - s;
		if (fw > 0.5) {
			float fr = hb.y - inner;
			vec2 fc = vec2((s + e) * 0.5, c.y);
			float df = rr(px - fc, vec2(fw * 0.5, fr), min(fr, fw * 0.5));
			float fa = 1.0 - smoothstep(-0.8, 0.8, df);
			float u = (px.x - x0) / (x1 - x0);
			vec3 fcol = mix(col_a.rgb, col_b.rgb, clamp(u, 0.0, 1.0));
			float vy = clamp((px.y - (c.y - fr)) / (2.0 * fr), 0.0, 1.0);
			fcol *= 0.85 + 0.35 * smoothstep(1.0, 0.0, vy);
			fcol += vec3(0.30) * smoothstep(0.42, 0.0, vy) * 0.55;
			float st = step(0.5, fract((px.x - px.y - TIME * 55.0) / 24.0));
			fcol *= 1.0 + 0.13 * st;
			float un = (px.x - s) / max(fw, 1.0);
			float bc = fract(TIME * 0.45) * 1.6 - 0.3;
			fcol += vec3(1.0) * exp(-pow((un - bc) * 7.0, 2.0)) * 0.38;
			fcol += col_b.rgb * exp(-abs(px.x - e) / 8.0) * 0.6 * step(0.5, 1.0 - indet);
			fcol += vec3(flash);
			col = mix(col, fcol, fa);
		}
		outc = vec4(col, a);
	}
	COLOR = outc;
}
"""

# ------------------------------------------------------------------ keadaan
var _font: Font
var _plat: String = ""
var _sim: String = ""
var _api: String = ""
var _cur_ver: String = ""
var _just_updated: String = ""
var _phase: int = Phase.BOOT
var _phase_t: float = 0.0
var _t: float = 0.0
var _leaving: bool = false

var _accent: Color = C_CYAN
var _accent_to: Color = C_CYAN
var _energy: float = 0.0
var _energy_to: float = 0.0

# hasil pengecekan
var _pending_kind: String = ""
var _pending_data: Dictionary = {}
var _release: Dictionary = {}
var _asset: Dictionary = {}

# unduhan
var _http: HTTPRequest
var _dl: HTTPRequest
var _dl_path: String = ""
var _dl_bytes: float = 0.0
var _dl_total: float = 0.0
var _dl_prog: float = 0.0            # nilai target 0..1
var _dl_shown: float = 0.0           # nilai yang digambar (halus)
var _dl_speed: float = 0.0           # byte/detik (diratakan)
var _dl_last_bytes: float = 0.0
var _dl_sample_t: float = 0.0
var _dl_stall: float = 0.0
var _dl_done_flag: bool = false
var _dl_fail: String = ""
var _sim_bytes: float = 0.0
var _sim_err_used: bool = false
var _thread: Thread
var _staged: String = ""
var _last_pct: int = -1
var _pct_pop: float = 0.0
var _flash: float = 0.0

# node
var _bg: ColorRect
var _bg_mat: ShaderMaterial
var _parts: Particles
var _logo: TextureRect
var _card: Panel
var _card_sb: StyleBoxFlat
var _fade: ColorRect
var _hint: Label
var _footer: Label

var _g_status: Control
var _icon: StatusIcon
var _st_title: Label
var _st_dots: Label
var _st_sub: Label

var _g_avail: Control
var _pill: Pill
var _av_old: Label
var _av_new: Label
var _av_chev: Chevrons
var _av_meta: Label
var _av_notes_box: Panel
var _av_notes_title: Label
var _av_notes: RichTextLabel
var _av_notice: Label
var _b_update: NeonButton
var _b_quit_a: NeonButton

var _g_dl: Control
var _dl_title: Label
var _dl_sub: Label
var _dl_bar_fx: ColorRect
var _dl_bar_mat: ShaderMaterial
var _dl_runners: RunnerLayer
var _dl_pct: Label
var _dl_stat1: Label
var _dl_stat2: Label
var _dl_status: Label
var _b_quit_dl: NeonButton

var _g_msg: Control
var _msg_icon: StatusIcon
var _msg_title: Label
var _msg_text: Label
var _b_msg1: NeonButton
var _b_msg2: NeonButton
var _msg_actions: Array = []

var _btns: Array = []
var _sel: int = 0
var _hint_t: float = 0.0
var _autopress: bool = false            # hanya untuk pengujian (build debug / editor): menekan tombol pertama otomatis


# ================================================================== siklus hidup
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	_font = load(FONT_PATH) as Font
	_plat = UpdateCore.platform_key()
	_cur_ver = UpdateCore.current_version()
	_read_flags()

	if not _should_run():
		call_deferred("_go_next_now")
		return

	UpdateCore.cleanup_leftovers()
	_just_updated = UpdateCore.consume_updated_flag()
	_build_ui()
	if UIInput != null and not UIInput.pressed.is_connected(_on_ui_pressed):
		UIInput.pressed.connect(_on_ui_pressed)
	_intro()
	_start_check()


## Mode uji hanya berlaku di editor / build debug (di build rilis diabaikan sepenuhnya).
func _read_flags() -> void:
	if not (OS.has_feature("editor") or OS.is_debug_build()):
		return
	_sim = UpdateConfig.EDITOR_SIMULATE
	for a in OS.get_cmdline_user_args():
		var s: String = String(a)
		if s.begins_with("--updater-sim="):
			_sim = s.trim_prefix("--updater-sim=")
		elif s.begins_with("--updater-api="):
			_api = s.trim_prefix("--updater-api=")
		elif s == "--updater-autopress":
			_autopress = true


func _should_run() -> bool:
	if not UpdateConfig.ENABLED:
		return false
	if _sim != "":
		return true
	if OS.has_feature("editor") and _api == "":
		print("[Updater] Godot Editor: cek update dilewati (lihat UpdateConfig.EDITOR_SIMULATE untuk melihat tampilannya).")
		return false
	if not UpdateConfig.is_configured():
		push_warning("[Updater] GITHUB_OWNER / GITHUB_REPO di scripts/update_config.gd belum diisi, cek update dilewati.")
		return false
	if _plat == "":
		return false
	return true


func _go_next_now() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()


# ================================================================== membangun tampilan
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BG_SHADER
	_bg_mat = ShaderMaterial.new()
	_bg_mat.shader = sh
	_bg.material = _bg_mat
	add_child(_bg)

	_parts = Particles.new()
	add_child(_parts)

	_logo = TextureRect.new()
	if ResourceLoader.exists(LOGO_PATH):
		_logo.texture = load(LOGO_PATH) as Texture2D
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo.size = Vector2(430.0, 85.0)
	_logo.position = Vector2(CX - 215.0, 26.0)
	_logo.pivot_offset = _logo.size * 0.5
	add_child(_logo)

	_card = Panel.new()
	_card_sb = StyleBoxFlat.new()
	_card_sb.bg_color = Color(0.04, 0.045, 0.10, 0.93)
	_card_sb.set_corner_radius_all(24)
	_card_sb.set_border_width_all(3)
	_card_sb.border_color = _accent
	_card_sb.shadow_size = 30
	_card_sb.shadow_color = Color(_accent, 0.3)
	_card_sb.anti_aliasing = true
	_card.add_theme_stylebox_override("panel", _card_sb)
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.size = SZ_STATUS
	_card.position = Vector2(CX, CY) - SZ_STATUS * 0.5
	_card.pivot_offset = SZ_STATUS * 0.5
	add_child(_card)

	_build_status()
	_build_avail()
	_build_dl()
	_build_msg()

	_footer = _lbl(self, "BOXSIEGE  v%s  -  %s" % [_cur_ver, UpdateCore.platform_label()], 15, Color(C_DIM, 0.75), Vector2(28.0, 686.0), 600.0, HORIZONTAL_ALIGNMENT_LEFT, 4)
	_hint = _lbl(self, "", 15, Color(C_DIM, 0.85), Vector2(CX, 686.0), 600.0, HORIZONTAL_ALIGNMENT_RIGHT, 3)
	_hint.position.x = 1280.0 - 28.0 - 600.0
	_hint.modulate.a = 0.0

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 1.0
	add_child(_fade)

	_g_status.visible = false
	_g_avail.visible = false
	_g_dl.visible = false
	_g_msg.visible = false


func _lbl(parent: Node, text: String, fs: int, col: Color, pos: Vector2, w: float, align: int = HORIZONTAL_ALIGNMENT_CENTER, track: int = 0, outline: int = 0) -> Label:
	var fv := FontVariation.new()
	fv.base_font = _font
	fv.spacing_glyph = track
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", fv)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.07, 0.92))
	l.horizontal_alignment = align as HorizontalAlignment
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.position = pos
	l.size = Vector2(w, float(fs) * 1.35)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _group() -> Control:
	var g := Control.new()
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(g)
	return g


func _btn(parent: Node, text: String, pos: Vector2, sz: Vector2, primary: bool, accent: Color, fs: int = 28) -> NeonButton:
	var b := NeonButton.new()
	b.font = _font
	b.text = text
	b.primary = primary
	b.accent = accent
	b.fsize = fs
	b.position = pos
	b.size = sz
	b.pivot_offset = sz * 0.5
	parent.add_child(b)
	b.hovered.connect(_on_btn_hover.bind(b))
	return b


func _build_status() -> void:
	_g_status = _group()
	_icon = StatusIcon.new()
	_icon.position = Vector2((SZ_STATUS.x - 120.0) * 0.5, 24.0)
	_g_status.add_child(_icon)
	_st_title = _lbl(_g_status, "MEMERIKSA PEMBARUAN", 30, C_TEXT, Vector2(0.0, 152.0), SZ_STATUS.x, HORIZONTAL_ALIGNMENT_CENTER, 3, 5)
	_st_dots = _lbl(_g_status, "", 30, C_TEXT, Vector2(0.0, 152.0), 60.0, HORIZONTAL_ALIGNMENT_LEFT, 0, 5)
	_st_sub = _lbl(_g_status, "Menghubungi server...", 18, C_DIM, Vector2(0.0, 200.0), SZ_STATUS.x, HORIZONTAL_ALIGNMENT_CENTER, 1)


func _build_avail() -> void:
	_g_avail = _group()
	_pill = Pill.new()
	_pill.font = _font
	_pill.text = "UPDATE TERSEDIA"
	_pill.size = Vector2(310.0, 40.0)
	_pill.position = Vector2((SZ_AVAIL.x - 310.0) * 0.5, 26.0)
	_g_avail.add_child(_pill)

	_av_old = _lbl(_g_avail, "v0", 38, C_DIM, Vector2(30.0, 80.0), 300.0, HORIZONTAL_ALIGNMENT_RIGHT, 2, 4)
	_av_chev = Chevrons.new()
	_av_chev.position = Vector2(345.0, 84.0)
	_g_avail.add_child(_av_chev)
	_av_new = _lbl(_g_avail, "v0", 62, C_GOLD, Vector2(500.0, 66.0), 300.0, HORIZONTAL_ALIGNMENT_LEFT, 2, 6)
	_av_meta = _lbl(_g_avail, "", 18, C_DIM, Vector2(0.0, 150.0), SZ_AVAIL.x, HORIZONTAL_ALIGNMENT_CENTER, 1)

	_av_notes_box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.025, 0.07, 0.85)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.10)
	sb.anti_aliasing = true
	_av_notes_box.add_theme_stylebox_override("panel", sb)
	_av_notes_box.position = Vector2(40.0, 188.0)
	_av_notes_box.size = Vector2(740.0, 170.0)
	_av_notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_g_avail.add_child(_av_notes_box)
	_av_notes_title = _lbl(_av_notes_box, "APA YANG BARU", 15, C_GOLD, Vector2(18.0, 8.0), 400.0, HORIZONTAL_ALIGNMENT_LEFT, 4)
	_av_notes = RichTextLabel.new()
	_av_notes.bbcode_enabled = true
	_av_notes.scroll_active = true
	_av_notes.fit_content = false
	_av_notes.add_theme_font_override("normal_font", _font)
	_av_notes.add_theme_font_override("bold_font", _font)
	_av_notes.add_theme_font_size_override("normal_font_size", 18)
	_av_notes.add_theme_color_override("default_color", Color(C_TEXT, 0.92))
	_av_notes.position = Vector2(18.0, 36.0)
	_av_notes.size = Vector2(704.0, 126.0)
	_av_notes_box.add_child(_av_notes)

	_av_notice = _lbl(_g_avail, "Update ini wajib dipasang sebelum kamu bisa bermain.", 18, Color(C_GOLD, 0.9), Vector2(0.0, 368.0), SZ_AVAIL.x, HORIZONTAL_ALIGNMENT_CENTER, 1)
	_b_update = _btn(_g_avail, "UPDATE SEKARANG", Vector2(50.0, 420.0), Vector2(470.0, 64.0), true, C_GOLD, 30)
	_b_quit_a = _btn(_g_avail, "KELUAR", Vector2(550.0, 420.0), Vector2(220.0, 64.0), false, C_RED, 26)
	_b_update.activated.connect(_on_update_pressed)
	_b_quit_a.activated.connect(_quit_game)


func _build_dl() -> void:
	_g_dl = _group()
	_dl_title = _lbl(_g_dl, "MENGUNDUH PEMBARUAN", 32, C_TEXT, Vector2(0.0, 22.0), SZ_DL.x, HORIZONTAL_ALIGNMENT_CENTER, 3, 5)
	_dl_sub = _lbl(_g_dl, "", 18, C_DIM, Vector2(0.0, 66.0), SZ_DL.x, HORIZONTAL_ALIGNMENT_CENTER, 1)

	var view := Control.new()
	view.position = Vector2(24.0, 98.0)
	view.size = Vector2(772.0, 176.0)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_g_dl.add_child(view)
	_dl_bar_fx = ColorRect.new()
	_dl_bar_fx.position = Vector2(0.0, 106.0)
	_dl_bar_fx.size = Vector2(772.0, 68.0)
	_dl_bar_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bsh := Shader.new()
	bsh.code = BAR_SHADER
	_dl_bar_mat = ShaderMaterial.new()
	_dl_bar_mat.shader = bsh
	_dl_bar_fx.material = _dl_bar_mat
	view.add_child(_dl_bar_fx)
	_dl_runners = RunnerLayer.new()
	view.add_child(_dl_runners)

	_dl_pct = _lbl(_g_dl, "0%", 80, C_GOLD, Vector2(40.0, 284.0), 300.0, HORIZONTAL_ALIGNMENT_LEFT, 0, 8)
	_dl_pct.size.y = 100.0
	_dl_pct.pivot_offset = Vector2(60.0, 50.0)
	_dl_stat1 = _lbl(_g_dl, "", 26, C_TEXT, Vector2(380.0, 292.0), 400.0, HORIZONTAL_ALIGNMENT_RIGHT, 0, 4)
	_dl_stat2 = _lbl(_g_dl, "", 20, C_CYAN, Vector2(380.0, 330.0), 400.0, HORIZONTAL_ALIGNMENT_RIGHT, 1, 3)
	_dl_status = _lbl(_g_dl, "", 20, C_DIM, Vector2(40.0, 380.0), 520.0, HORIZONTAL_ALIGNMENT_LEFT, 1)
	_b_quit_dl = _btn(_g_dl, "KELUAR", Vector2(620.0, 372.0), Vector2(160.0, 44.0), false, C_RED, 20)
	_b_quit_dl.activated.connect(_quit_game)


func _build_msg() -> void:
	_g_msg = _group()
	_msg_icon = StatusIcon.new()
	_msg_icon.size = Vector2(100.0, 100.0)
	_msg_icon.position = Vector2((SZ_MSG.x - 100.0) * 0.5, 22.0)
	_g_msg.add_child(_msg_icon)
	_msg_title = _lbl(_g_msg, "", 32, C_TEXT, Vector2(0.0, 126.0), SZ_MSG.x, HORIZONTAL_ALIGNMENT_CENTER, 2, 5)
	_msg_text = _lbl(_g_msg, "", 18, C_DIM, Vector2(50.0, 172.0), SZ_MSG.x - 100.0, HORIZONTAL_ALIGNMENT_CENTER, 0)
	_msg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_msg_text.size.y = 100.0
	_b_msg1 = _btn(_g_msg, "", Vector2(60.0, 270.0), Vector2(250.0, 56.0), true, C_GOLD, 24)
	_b_msg2 = _btn(_g_msg, "", Vector2(350.0, 270.0), Vector2(250.0, 56.0), false, C_RED, 24)
	_b_msg1.activated.connect(_on_msg_action.bind(0))
	_b_msg2.activated.connect(_on_msg_action.bind(1))


# ================================================================== animasi masuk
func _intro() -> void:
	_card.modulate.a = 0.0
	_card.scale = Vector2(0.86, 0.86)
	_logo.modulate.a = 0.0
	_logo.position.y = -30.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_fade, "modulate:a", 0.0, 0.55)
	tw.tween_property(_card, "modulate:a", 1.0, 0.45).set_delay(0.15)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.6).set_delay(0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_logo, "modulate:a", 1.0, 0.5).set_delay(0.2)
	tw.tween_property(_logo, "position:y", 26.0, 0.7).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Global.play_sfx("ui_whoosh", -8.0)


func _set_accent(c: Color, energy: float) -> void:
	_accent_to = c
	_energy_to = energy


## Tampilkan grup `g`, ubah ukuran kartu, sembunyikan grup lain.
func _switch_group(g: Control, sz: Vector2) -> void:
	for o in [_g_status, _g_avail, _g_dl, _g_msg]:
		var oc: Control = o
		_kill_tw(oc)
		if oc != g and oc.visible:
			var t1 := create_tween()
			t1.tween_property(oc, "modulate:a", 0.0, 0.14)
			t1.tween_callback(oc.hide)
			oc.set_meta("tw", t1)
	var tl: Vector2 = Vector2(CX, CY) - sz * 0.5
	var was_visible: bool = g.visible and g.modulate.a > 0.5
	g.visible = true
	if not was_visible:
		g.modulate.a = 0.0
		g.position = tl + Vector2(0.0, 14.0)
	var tw := create_tween().set_parallel(true)
	g.set_meta("tw", tw)
	tw.tween_property(_card, "position", tl, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "size", sz, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "pivot_offset", sz * 0.5, 0.5)
	tw.tween_property(g, "modulate:a", 1.0, 0.3).set_delay(0.16)
	tw.tween_property(g, "position", tl, 0.38).set_delay(0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _kill_tw(g: Control) -> void:
	if g.has_meta("tw"):
		var t: Tween = g.get_meta("tw")
		if t != null and t.is_valid():
			t.kill()
		g.remove_meta("tw")


func _set_buttons(arr: Array, sel: int = 0) -> void:
	_btns = arr
	_sel = clampi(sel, 0, maxi(arr.size() - 1, 0))
	for b in [_b_update, _b_quit_a, _b_quit_dl, _b_msg1, _b_msg2]:
		var nb: NeonButton = b
		nb.enabled = arr.has(nb)
		nb.want_sel = false
	if not arr.is_empty():
		(arr[_sel] as NeonButton).want_sel = true
	_hint.modulate.a = 0.0 if arr.is_empty() else 1.0


# ================================================================== alur: cek update
func _set_phase(p: int) -> void:
	_phase = p
	_phase_t = 0.0


func _start_check() -> void:
	_set_phase(Phase.CHECKING)
	_icon.set_kind("spin")
	_icon.color = C_CYAN
	_st_title.text = "MEMERIKSA PEMBARUAN"
	_st_sub.text = "Menghubungi server..."
	_set_accent(C_CYAN, 0.0)
	_set_buttons([])
	_switch_group(_g_status, SZ_STATUS)
	if _sim != "":
		var kinds := {"update": "newer", "uptodate": "current", "offline": "offline", "error": "newer", "blocked": "newer"}
		var k: String = String(kinds.get(_sim, "current"))
		var data: Dictionary = {}
		if k == "newer":
			data = UpdateCore.fake_release()
		_queue_result(k, data)
		return
	await get_tree().create_timer(0.5).timeout
	if _leaving:
		return
	_http = HTTPRequest.new()
	_http.timeout = UpdateConfig.CHECK_TIMEOUT
	add_child(_http)
	_http.request_completed.connect(_on_check_completed)
	var err: int = _http.request(UpdateCore.releases_url(_api), UpdateCore.api_headers())
	if err != OK:
		_queue_result("offline", {})


func _queue_result(kind: String, data: Dictionary) -> void:
	_pending_kind = kind
	_pending_data = data


func _on_check_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_queue_result("offline", {})
		return
	if code == 404:
		_queue_result("current", {})                      # repo belum punya rilis sama sekali
		return
	if code != 200:
		_queue_result("offline", {})                      # rate limit / server error: jangan kunci pemain
		return
	var rel: Dictionary = UpdateCore.pick_latest_release(body.get_string_from_utf8())
	if rel.is_empty() or not UpdateCore.is_newer(String(rel["version"]), _cur_ver):
		_queue_result("current", {})
		return
	var asset: Dictionary = UpdateCore.pick_asset(rel["assets"], _plat)
	if asset.is_empty():
		_queue_result("noasset", rel)
		return
	rel["asset"] = asset
	_queue_result("newer", rel)


func _resolve_check() -> void:
	var kind: String = _pending_kind
	_pending_kind = ""
	match kind:
		"current":
			_show_uptodate()
		"offline":
			_show_offline()
		"noasset":
			_release = _pending_data
			_show_msg("warn", "UPDATE BELUM SIAP",
				"Versi baru (v%s) sudah dirilis, tetapi file untuk %s belum diunggah.\nKamu tetap bisa bermain dengan versi ini." % [String(_release.get("version", "?")), UpdateCore.platform_label()],
				[{"text": "LANJUT BERMAIN", "act": "next", "primary": true}])
		"newer":
			_release = _pending_data
			_asset = _release["asset"]
			_show_available()


func _show_uptodate() -> void:
	_set_phase(Phase.UPTODATE)
	_icon.set_kind("check")
	_icon.color = C_GREEN
	if _just_updated != "":
		_st_title.text = "UPDATE BERHASIL!"
		_st_sub.text = "BoxSiege sekarang versi %s" % _cur_ver
	else:
		_st_title.text = "GAME SUDAH TERBARU"
		_st_sub.text = "BoxSiege v%s" % _cur_ver
	_st_dots.text = ""
	_set_accent(C_GREEN, 0.25)
	Global.play_sfx("ui_ready", -4.0)


func _show_offline() -> void:
	_set_phase(Phase.OFFLINE)
	_show_msg("wifi", "TIDAK ADA KONEKSI",
		"Tidak bisa memeriksa update, jadi game dibuka dengan versi yang ada.\nGame ini bisa dimainkan tanpa internet.",
		[{"text": "LANJUT BERMAIN", "act": "next", "primary": true}], false)
	_phase = Phase.OFFLINE


func _show_available() -> void:
	var blocker: String = ""
	if _sim == "blocked":
		blocker = "Folder game tidak bisa ditulis, jadi update tidak bisa dipasang di sini.\n\nPindahkan game ke folder biasa (misalnya Documents atau Desktop), lalu buka lagi dari sana."
	elif _sim == "":
		blocker = UpdateCore.install_blocker(_plat)
	if blocker != "":
		_show_msg("warn", "UPDATE TIDAK BISA DIPASANG", blocker, [{"text": "KELUAR", "act": "quit", "primary": false}])
		return
	_set_phase(Phase.AVAILABLE)
	_av_old.text = "v" + _cur_ver
	_av_new.text = "v" + String(_release["version"])
	var date: String = UpdateCore.fmt_date(String(_release.get("published", "")))
	var meta: String = "Ukuran unduhan  %s" % UpdateCore.fmt_bytes(float(_asset.get("size", 0)))
	if date != "":
		meta += "      -      Dirilis  %s" % date
	_av_meta.text = meta
	_av_notes.text = UpdateCore.notes_to_bbcode(String(_release.get("body", "")))
	_av_notes.scroll_to_line(0)
	_set_accent(C_GOLD, 0.35)
	_set_buttons([_b_update, _b_quit_a], 0)
	_switch_group(_g_avail, SZ_AVAIL)
	Global.play_sfx("ui_start", -4.0)


## btns: [{text, act, primary}]; act = "next" | "quit" | "retry"
func _show_msg(icon: String, title: String, text: String, btns: Array, wait_for_user: bool = true) -> void:
	_set_phase(Phase.MSG)
	_msg_icon.set_kind(icon)
	var col: Color = C_RED if icon == "cross" else C_GOLD
	if icon == "wifi":
		col = C_CYAN
	_msg_icon.color = col
	_msg_title.text = title
	_msg_text.text = text
	_msg_actions = btns
	var arr: Array = []
	var bs: Array = [_b_msg1, _b_msg2]
	for i in 2:
		var b: NeonButton = bs[i]
		if i < btns.size():
			b.text = String(btns[i]["text"])
			b.primary = bool(btns[i].get("primary", false))
			b.accent = C_GOLD if b.primary else C_RED
			arr.append(b)
	if btns.size() == 1:
		_b_msg1.position = Vector2((SZ_MSG.x - 300.0) * 0.5, 270.0)
		_b_msg1.size = Vector2(300.0, 56.0)
	else:
		_b_msg1.position = Vector2(60.0, 270.0)
		_b_msg1.size = Vector2(250.0, 56.0)
	_b_msg1.pivot_offset = _b_msg1.size * 0.5
	_set_accent(col, 0.1)
	_set_buttons(arr, 0)
	_switch_group(_g_msg, SZ_MSG)
	if icon == "cross" or icon == "warn":
		Global.play_sfx("ui_error", -2.0)
	if not wait_for_user:
		_phase = Phase.OFFLINE


func _on_msg_action(idx: int) -> void:
	if idx >= _msg_actions.size() or _leaving:
		return
	Global.play_sfx("ui_confirm", -2.0)
	match String(_msg_actions[idx]["act"]):
		"next":
			_go_next()
		"quit":
			_quit_game()
		"retry":
			_begin_download()


# ================================================================== alur: unduh & pasang
func _on_update_pressed() -> void:
	if _phase != Phase.AVAILABLE or _leaving:
		return
	Global.play_sfx("ui_confirm", -2.0)
	_begin_download()


func _begin_download() -> void:
	_set_phase(Phase.DOWNLOADING)
	_dl_bytes = 0.0
	_dl_prog = 0.0
	_dl_shown = 0.0
	_dl_speed = 0.0
	_dl_last_bytes = 0.0
	_dl_sample_t = 0.0
	_dl_stall = 0.0
	_dl_done_flag = false
	_dl_fail = ""
	_sim_bytes = 0.0
	_last_pct = -1
	_flash = 0.0
	_dl_total = float(_asset.get("size", 0))
	_dl_title.text = "MENGUNDUH PEMBARUAN"
	_dl_sub.text = "BoxSiege   v%s   >   v%s" % [_cur_ver, String(_release["version"])]
	_dl_status.text = "Mengunduh file update..."
	_dl_pct.text = "0%"
	_dl_stat1.text = "0 B / %s" % UpdateCore.fmt_bytes(_dl_total)
	_dl_stat2.text = "Menghubungkan..."
	_dl_runners.running = true
	_dl_runners.celebrate = 0.0
	_dl_bar_mat.set_shader_parameter("indet", 0.0)
	_dl_bar_mat.set_shader_parameter("flash", 0.0)
	_set_accent(C_CYAN, 0.6)
	_set_buttons([_b_quit_dl], 0)
	_b_quit_dl.want_sel = false
	_switch_group(_g_dl, SZ_DL)

	if _sim != "":
		return
	_dl_path = UpdateCore.download_path(_plat)
	if FileAccess.file_exists(_dl_path):
		DirAccess.remove_absolute(_dl_path)
	if _dl != null:
		_dl.queue_free()
	_dl = HTTPRequest.new()
	_dl.download_file = _dl_path
	_dl.use_threads = true
	_dl.accept_gzip = false
	_dl.max_redirects = 8
	_dl.download_chunk_size = 262144
	add_child(_dl)
	_dl.request_completed.connect(_on_dl_completed)
	var err: int = _dl.request(String(_asset["url"]), UpdateCore.download_headers())
	if err != OK:
		_dl_fail = "Tidak bisa memulai unduhan (kode %d)." % err


func _on_dl_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		match result:
			HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN, HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
				_dl_fail = "File update tidak bisa ditulis ke disk. Periksa ruang penyimpanan kosong."
			_:
				_dl_fail = "Koneksi terputus atau tidak stabil saat mengunduh."
		return
	if code != 200:
		_dl_fail = "Server GitHub menjawab dengan kode %d." % code
		return
	_dl_done_flag = true


func _update_download(d: float) -> void:
	if _sim != "":
		_sim_step(d)
	else:
		if _dl != null and _dl_fail == "" and not _dl_done_flag:
			_dl_bytes = float(_dl.get_downloaded_bytes())
			var bs: int = _dl.get_body_size()
			if bs > 0:
				_dl_total = float(bs)
			if _dl_bytes <= _dl_last_bytes + 0.5:
				_dl_stall += d
				if _dl_stall > UpdateConfig.STALL_TIMEOUT:
					_dl.cancel_request()
					_dl_fail = "Unduhan berhenti (tidak ada data masuk). Periksa koneksi internet."
			else:
				_dl_stall = 0.0
		elif _dl_done_flag:
			_dl_bytes = maxf(_dl_bytes, _dl_total)
	if _dl_fail != "":
		_download_failed(_dl_fail)
		return

	_dl_sample_t += d
	if _dl_sample_t >= 0.5:
		var inst: float = (_dl_bytes - _dl_last_bytes) / _dl_sample_t
		_dl_speed = inst if _dl_speed <= 0.0 else lerpf(_dl_speed, inst, 0.4)
		_dl_last_bytes = _dl_bytes
		_dl_sample_t = 0.0

	_dl_prog = clampf(_dl_bytes / maxf(_dl_total, 1.0), 0.0, 1.0)
	_dl_shown = lerpf(_dl_shown, _dl_prog, minf(1.0, d * 8.0))
	var pct: int = int(floor(_dl_shown * 100.0 + 0.001))
	if pct != _last_pct:
		if _last_pct >= 0 and pct % 10 == 0 and pct > 0:
			_pct_pop = 1.0
			Global.play_sfx("ui_move", -10.0, 1.0 + float(pct) / 160.0)
		_last_pct = pct
		_dl_pct.text = "%d%%" % pct
	_dl_stat1.text = "%s / %s" % [UpdateCore.fmt_bytes(_dl_bytes), UpdateCore.fmt_bytes(_dl_total)]
	var eta: float = -1.0
	if _dl_speed > 1.0:
		eta = (_dl_total - _dl_bytes) / _dl_speed
	_dl_stat2.text = "%s/s     ETA %s" % [UpdateCore.fmt_bytes(_dl_speed), UpdateCore.fmt_eta(eta)]

	var finished: bool = (_sim != "" and _sim_bytes >= _dl_total) or (_sim == "" and _dl_done_flag)
	if finished and _dl_shown > 0.995:
		_dl_shown = 1.0
		_begin_verify()


func _sim_step(d: float) -> void:
	var rate: float = (5.0 + 4.0 * sin(_phase_t * 1.3) + 2.0 * sin(_phase_t * 3.7)) * 1048576.0
	_sim_bytes = minf(_sim_bytes + maxf(rate, 0.8 * 1048576.0) * d, _dl_total)
	_dl_bytes = _sim_bytes
	if _sim == "error" and not _sim_err_used and _dl_bytes / _dl_total > 0.38:
		_dl_fail = "Koneksi terputus atau tidak stabil saat mengunduh."


func _download_failed(msg: String) -> void:
	if _dl != null:
		_dl.cancel_request()
	if _dl_path != "" and FileAccess.file_exists(_dl_path):
		DirAccess.remove_absolute(_dl_path)
	_dl_fail = ""
	_dl_runners.running = false
	_sim_err_used = true                                  # simulasi error hanya sekali; "Coba lagi" lanjut normal
	_show_msg("cross", "UNDUHAN GAGAL", msg,
		[{"text": "COBA LAGI", "act": "retry", "primary": true}, {"text": "KELUAR", "act": "quit", "primary": false}])


func _begin_verify() -> void:
	_set_phase(Phase.VERIFYING)
	_dl_title.text = "MEMVERIFIKASI FILE"
	_dl_status.text = "Memeriksa keutuhan file update..."
	_dl_bar_mat.set_shader_parameter("indet", 1.0)
	_dl_runners.running = false
	_set_buttons([])
	_b_quit_dl.enabled = false
	_dl_stat2.text = "Hampir selesai..."
	if _sim == "":
		_thread = Thread.new()
		_thread.start(UpdateCore.finalize.bind(_dl_path, _plat, String(_asset["name"]), String(_asset.get("digest", ""))))


func _update_verify() -> void:
	var ok: bool = _phase_t >= 0.9
	if _sim == "":
		if _thread == null:
			return
		if _thread.is_alive() or not ok:
			return
		var res: Dictionary = _thread.wait_to_finish()
		_thread = null
		if not bool(res.get("ok", false)):
			_dl_runners.running = false
			_show_msg("cross", "FILE UPDATE BERMASALAH", String(res.get("error", "Terjadi kesalahan.")),
				[{"text": "COBA LAGI", "act": "retry", "primary": true}, {"text": "KELUAR", "act": "quit", "primary": false}])
			return
		_staged = String(res["staged"])
	elif not ok:
		return
	_begin_install()


func _begin_install() -> void:
	_set_phase(Phase.INSTALLING)
	_dl_title.text = "MEMASANG PEMBARUAN"
	_dl_status.text = "Menyiapkan pemasangan..."
	_dl_stat1.text = "100%"
	_dl_stat2.text = ""
	_dl_bar_mat.set_shader_parameter("indet", 0.0)
	_dl_shown = 1.0
	_flash = 1.0
	_pct_pop = 1.0
	_dl_pct.text = "100%"
	_dl_runners.celebrate = 1.0
	Global.play_sfx("ui_ready", -2.0)


func _finish_install() -> void:
	var ver: String = String(_release["version"])
	var dry: bool = _sim != "" or OS.has_feature("editor")
	if not dry:
		UpdateCore.mark_updated(ver)
		var r: Dictionary = UpdateCore.launch_installer(_plat, _staged)
		if not bool(r.get("ok", false)):
			if _staged != "" and FileAccess.file_exists(_staged):
				DirAccess.remove_absolute(_staged)
			_show_msg("cross", "PEMASANGAN GAGAL", String(r.get("error", "Terjadi kesalahan.")),
				[{"text": "COBA LAGI", "act": "retry", "primary": true}, {"text": "KELUAR", "act": "quit", "primary": false}])
			return
	_set_phase(Phase.DONE)
	_set_accent(C_GREEN, 1.0)
	_dl_title.text = "UPDATE SELESAI!"
	_dl_title.add_theme_color_override("font_color", C_GREEN)
	_dl_status.text = "Mode uji: pemasangan dilewati." if dry else "Game akan ditutup lalu dibuka ulang otomatis..."
	_dl_stat1.text = "v%s" % ver
	_flash = 1.0
	Global.play_sfx("level_clear", -2.0)


# ================================================================== keluar / lanjut
func _quit_game() -> void:
	if _leaving or _phase == Phase.VERIFYING or _phase == Phase.INSTALLING or _phase == Phase.DONE:
		return
	_leaving = true
	Global.play_sfx("ui_back", -2.0)
	if _dl != null:
		_dl.cancel_request()
	if _dl_path != "" and FileAccess.file_exists(_dl_path):
		DirAccess.remove_absolute(_dl_path)
	_set_buttons([])
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.35)
	tw.tween_callback(get_tree().quit)


func _go_next() -> void:
	if _leaving:
		return
	_leaving = true
	_set_buttons([])
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", 1.0, 0.4)
	tw.tween_callback(_go_next_now)


# ================================================================== input
func _on_ui_pressed(_source: int, action: StringName) -> void:
	if _leaving or _btns.is_empty():
		return
	match String(action):
		"left", "up", "prev":
			_move_sel(-1)
		"right", "down", "next":
			_move_sel(1)
		"accept":
			var b: NeonButton = _btns[_sel]
			if b.enabled:
				b.press = 1.0
				b.activated.emit()
		"back":
			for i in _btns.size():
				if (_btns[i] as NeonButton).accent == C_RED and i != _sel:
					_select(i)
					break


func _move_sel(dir: int) -> void:
	if _btns.size() < 2:
		return
	_select(posmod(_sel + dir, _btns.size()))


func _select(i: int) -> void:
	if i == _sel or i < 0 or i >= _btns.size():
		return
	(_btns[_sel] as NeonButton).want_sel = false
	_sel = i
	(_btns[_sel] as NeonButton).want_sel = true
	Global.play_sfx("ui_move", -6.0)


func _on_btn_hover(b: NeonButton) -> void:
	var i: int = _btns.find(b)
	if i >= 0:
		_select(i)


# ================================================================== per frame
func _process(d: float) -> void:
	_t += d
	_phase_t += d
	if _bg == null:
		return
	_accent = _accent.lerp(_accent_to, minf(1.0, d * 4.0))
	_energy = lerpf(_energy, _energy_to, minf(1.0, d * 3.0))
	_flash = maxf(_flash - d * 1.6, 0.0)
	_apply_theme(d)

	match _phase:
		Phase.CHECKING:
			var k: int = int(_t * 3.0) % 4
			_st_dots.text = ".".repeat(k)
			_st_dots.position.x = SZ_STATUS.x * 0.5 + _font.get_string_size(_st_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x * 0.5 + 8.0
			if _pending_kind != "" and _phase_t >= UpdateConfig.MIN_CHECK_SHOW:
				_resolve_check()
		Phase.UPTODATE:
			_st_dots.text = ""
			var wait: float = UpdateConfig.UPTODATE_SHOW + (0.7 if _just_updated != "" else 0.0)
			if _phase_t >= wait + 0.55:
				_go_next()
		Phase.OFFLINE:
			if _phase_t >= 3.4:
				_go_next()
		Phase.DOWNLOADING:
			_update_download(d)
		Phase.VERIFYING:
			_dl_shown = 1.0
			_update_verify()
		Phase.INSTALLING:
			if _phase_t >= 1.1:
				_finish_install()
		Phase.DONE:
			if _phase_t >= 1.9:
				if _sim != "" or OS.has_feature("editor"):
					_go_next()
				else:
					_leaving = true
					get_tree().quit()
	if _autopress and not _leaving and not _btns.is_empty() and _phase_t > 2.0 and (_phase == Phase.AVAILABLE or _phase == Phase.MSG):
		(_btns[0] as NeonButton).activated.emit()
		_phase_t = 0.0
	_hint_t += d
	if _hint_t > 0.4:
		_hint_t = 0.0
		_hint.text = "D-PAD: PILIH      A / X: KONFIRMASI" if UIInput.kind == "pad" else "PANAH: PILIH      ENTER: KONFIRMASI"


func _apply_theme(d: float) -> void:
	_bg_mat.set_shader_parameter("accent", _accent)
	_bg_mat.set_shader_parameter("energy", _energy)
	_bg_mat.set_shader_parameter("flash", _flash * 0.18)
	_parts.color = _accent
	_parts.speed = 1.0 + _energy * 2.0
	_card_sb.border_color = _accent.lerp(Color.WHITE, 0.12)
	_card_sb.shadow_color = Color(_accent, 0.26 + 0.10 * sin(_t * 2.2))
	_card_sb.shadow_size = int(26.0 + 8.0 * sin(_t * 2.2))
	if not _leaving:
		_logo.scale = Vector2.ONE * (1.0 + 0.012 * sin(_t * 1.6))
	_icon.color = _icon.color if _phase != Phase.CHECKING else _accent
	_pill.accent = _accent
	_av_chev.color = _accent
	_av_notes_box.get_theme_stylebox("panel").set("border_color", Color(_accent, 0.35))
	_av_new.add_theme_color_override("font_color", C_GOLD.lerp(Color.WHITE, 0.25 + 0.2 * sin(_t * 3.0)))

	if _g_dl.visible:
		_dl_bar_mat.set_shader_parameter("value", _dl_shown)
		_dl_bar_mat.set_shader_parameter("flash", _flash * 0.5)
		var ca: Color = Color(0.10, 0.45, 1.0)
		var cb: Color = _accent.lerp(Color.WHITE, 0.15)
		if _phase == Phase.DONE or _phase == Phase.INSTALLING:
			ca = Color(0.1, 0.7, 0.35)
			cb = C_GREEN
		_dl_bar_mat.set_shader_parameter("col_a", ca)
		_dl_bar_mat.set_shader_parameter("col_b", cb)
		_dl_bar_mat.set_shader_parameter("glow_col", cb)
		_dl_runners.value = _dl_shown
		_dl_runners.accent = cb
		_pct_pop = maxf(_pct_pop - d * 3.5, 0.0)
		_dl_pct.scale = Vector2.ONE * (1.0 + 0.16 * _pct_pop * _pct_pop)
		_dl_pct.add_theme_color_override("font_color", cb.lerp(C_GOLD, 0.0 if _phase == Phase.DONE else 0.55))


# ================================================================== helper tampilan: tombol neon
class NeonButton extends Control:
	signal activated
	signal hovered

	var text: String = ""
	var font: Font
	var fsize: int = 28
	var primary: bool = false
	var accent: Color = Color("ffd23f")
	var enabled: bool = true
	var want_sel: bool = false
	var sel: float = 0.0
	var press: float = 0.0
	var t: float = 0.0
	var _sb := StyleBoxFlat.new()
	var _gl := StyleBoxFlat.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_sb.set_corner_radius_all(16)
		_sb.anti_aliasing = true
		_gl.set_corner_radius_all(14)
		_gl.anti_aliasing = true
		mouse_entered.connect(func() -> void:
			if enabled and is_visible_in_tree():
				hovered.emit())

	func _process(d: float) -> void:
		if not is_visible_in_tree():
			return
		t += d
		sel = lerpf(sel, 1.0 if (want_sel and enabled) else 0.0, minf(1.0, d * 14.0))
		press = maxf(press - d * 5.0, 0.0)
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if not enabled:
			return
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			press = 1.0
			activated.emit()
			accept_event()

	func _draw() -> void:
		if not enabled:
			return
		var s: float = 1.0 + 0.045 * sel - 0.05 * press * press
		draw_set_transform(size * 0.5, 0.0, Vector2(s, s))
		var r := Rect2(-size * 0.5, size)
		var base: Color = accent
		if primary:
			_sb.bg_color = base.darkened(0.12).lerp(base, 0.35 + 0.65 * sel)
			_sb.border_color = base.lightened(0.45)
			_sb.set_border_width_all(3)
		else:
			_sb.bg_color = Color(0.08, 0.09, 0.18, 0.95).lerp(base.darkened(0.55), sel)
			_sb.border_color = Color(base, 0.45 + 0.55 * sel)
			_sb.set_border_width_all(3)
		_sb.shadow_color = Color(base, (0.18 + 0.45 * sel) * (1.0 if primary else 0.8))
		_sb.shadow_size = int(6.0 + 20.0 * sel + (4.0 * sin(t * 4.0) * sel))
		draw_style_box(_sb, r)
		# kilau atas
		_gl.bg_color = Color(1, 1, 1, 0.12 if primary else 0.05)
		draw_style_box(_gl, Rect2(r.position + Vector2(5.0, 4.0), Vector2(r.size.x - 10.0, r.size.y * 0.42)))
		# sapuan cahaya
		if primary:
			var span: float = size.x + 120.0
			var x0: float = fposmod(t * 0.55, 1.6) / 1.6 * span - 60.0 - size.x * 0.5
			var sk: float = 22.0
			var y0: float = -size.y * 0.5 + 4.0
			var y1: float = size.y * 0.5 - 4.0
			var lo: float = -size.x * 0.5 + 8.0
			var hi: float = size.x * 0.5 - 8.0
			var pts := PackedVector2Array([
				Vector2(clampf(x0, lo, hi), y0), Vector2(clampf(x0 + 36.0, lo, hi), y0),
				Vector2(clampf(x0 + 36.0 - sk, lo, hi), y1), Vector2(clampf(x0 - sk, lo, hi), y1)])
			if absf(pts[0].x - pts[1].x) > 0.5 or absf(pts[2].x - pts[3].x) > 0.5:
				draw_colored_polygon(pts, Color(1, 1, 1, 0.26))
		# teks
		var fs: int = fsize
		var tw: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var asc: float = font.get_ascent(fs)
		var dsc: float = font.get_descent(fs)
		var pos := Vector2(-tw.x * 0.5, (asc - dsc) * 0.5)
		var tcol: Color = Color("14161f") if primary else Color(0.93, 0.95, 1.0).lerp(base.lightened(0.4), 0.0)
		if primary:
			draw_string(font, pos + Vector2(0, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.25))
		else:
			draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, tcol)
		# penanda pilihan
		if sel > 0.02:
			var bob: float = sin(t * 7.0) * 3.0
			var cc: Color = Color("14161f") if primary else base
			cc.a = sel
			var lx: float = -tw.x * 0.5 - 26.0 + bob
			var rx: float = tw.x * 0.5 + 26.0 - bob
			var h: float = float(fs) * 0.30
			draw_colored_polygon(PackedVector2Array([Vector2(lx - 7, 0), Vector2(lx + 4, -h), Vector2(lx + 4, h)]), cc)
			draw_colored_polygon(PackedVector2Array([Vector2(rx + 7, 0), Vector2(rx - 4, -h), Vector2(rx - 4, h)]), cc)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ================================================================== helper tampilan: lencana "UPDATE TERSEDIA"
class Pill extends Control:
	var text: String = ""
	var font: Font
	var accent: Color = Color("ffd23f")
	var t: float = 0.0
	var _fv: FontVariation
	var _sb := StyleBoxFlat.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sb.set_corner_radius_all(20)
		_sb.set_border_width_all(2)
		_sb.anti_aliasing = true

	func _process(d: float) -> void:
		if is_visible_in_tree():
			t += d
			queue_redraw()

	func _draw() -> void:
		var pulse: float = 0.5 + 0.5 * sin(t * 4.0)
		_sb.bg_color = Color(accent, 0.12 + 0.08 * pulse)
		_sb.border_color = Color(accent, 0.7 + 0.3 * pulse)
		_sb.shadow_color = Color(accent, 0.25 * pulse)
		_sb.shadow_size = 10
		draw_style_box(_sb, Rect2(Vector2.ZERO, size))
		var fs: int = 20
		if _fv == null or _fv.base_font != font:
			_fv = FontVariation.new()
			_fv.base_font = font
			_fv.spacing_glyph = 4
		var fv: FontVariation = _fv
		var tw: Vector2 = fv.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var total: float = tw.x + 30.0
		var x: float = (size.x - total) * 0.5
		draw_circle(Vector2(x + 7.0, size.y * 0.5), 5.0 + 1.5 * pulse, accent)
		draw_circle(Vector2(x + 7.0, size.y * 0.5), 9.0 + 5.0 * pulse, Color(accent, 0.25 * (1.0 - pulse)))
		var asc: float = fv.get_ascent(fs)
		var dsc: float = fv.get_descent(fs)
		draw_string(fv, Vector2(x + 30.0, size.y * 0.5 + (asc - dsc) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, accent.lerp(Color.WHITE, 0.35))


# ================================================================== helper tampilan: panah ">>>" antar versi
class Chevrons extends Control:
	var color: Color = Color("ffd23f")
	var t: float = 0.0

	func _init() -> void:
		size = Vector2(130.0, 50.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(d: float) -> void:
		if is_visible_in_tree():
			t += d
			queue_redraw()

	func _draw() -> void:
		for i in 3:
			var a: float = 0.18 + 0.82 * maxf(0.0, sin(t * 6.0 - float(i) * 1.0))
			var x: float = 16.0 + float(i) * 38.0
			var pts := PackedVector2Array([Vector2(x, 8.0), Vector2(x + 20.0, 25.0), Vector2(x, 42.0)])
			draw_polyline(pts, Color(color, a), 7.0, true)


# ================================================================== helper tampilan: ikon status animatif
class StatusIcon extends Control:
	var kind: String = "spin"
	var color: Color = Color("3de0ff")
	var t: float = 0.0
	var age: float = 0.0

	func _init() -> void:
		size = Vector2(120.0, 120.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_kind(k: String) -> void:
		if k != kind:
			kind = k
			age = 0.0

	func _process(d: float) -> void:
		if is_visible_in_tree():
			t += d
			age += d
			queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 10.0
		match kind:
			"spin":
				_spin(c, r)
			"check":
				_check(c, r)
			"warn":
				_warn(c, r)
			"cross":
				_cross(c, r)
			"wifi":
				_wifi(c, r)

	func _spin(c: Vector2, r: float) -> void:
		draw_arc(c, r, 0.0, TAU, 56, Color(color, 0.12), 8.0, true)
		var a: float = t * 3.2
		draw_arc(c, r, a, a + PI * 1.15, 40, color, 8.0, true)
		draw_arc(c, r, a + PI, a + PI + PI * 0.5, 24, Color(color, 0.45), 8.0, true)
		var b: float = -t * 4.6
		draw_arc(c, r * 0.66, b, b + PI * 0.9, 32, color.lerp(Color.WHITE, 0.3), 5.0, true)
		var s: float = r * 0.22 * (1.0 + 0.18 * sin(t * 6.0))
		draw_set_transform(c, t * 2.0, Vector2.ONE)
		draw_rect(Rect2(-s, -s, s * 2.0, s * 2.0), color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 3:
			var ang: float = t * 2.2 + float(i) * TAU / 3.0
			draw_circle(c + Vector2(cos(ang), sin(ang)) * (r + 11.0), 3.5, Color(color, 0.85))

	func _check(c: Vector2, r: float) -> void:
		var p: float = clampf(age / 0.55, 0.0, 1.0)
		var e: float = 1.0 - pow(1.0 - p, 3.0)
		draw_circle(c, r, Color(color, 0.10 * e))
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * e, 64, color, 8.0, true)
		var q: float = clampf((age - 0.35) / 0.4, 0.0, 1.0)
		if q > 0.0:
			var p0: Vector2 = c + Vector2(-r * 0.42, r * 0.02)
			var p1: Vector2 = c + Vector2(-r * 0.10, r * 0.34)
			var p2: Vector2 = c + Vector2(r * 0.46, -r * 0.30)
			var l1: float = clampf(q * 2.0, 0.0, 1.0)
			var l2: float = clampf(q * 2.0 - 1.0, 0.0, 1.0)
			var pts := PackedVector2Array([p0, p0.lerp(p1, l1)])
			if l2 > 0.0:
				pts.append(p1.lerp(p2, l2))
			draw_polyline(pts, color.lerp(Color.WHITE, 0.25), 10.0, true)
		var bt: float = clampf((age - 0.5) / 0.7, 0.0, 1.0)
		if bt > 0.0 and bt < 1.0:
			draw_arc(c, r * (1.0 + 0.7 * bt), 0.0, TAU, 64, Color(color, 0.55 * (1.0 - bt)), 4.0, true)
			for i in 8:
				var ang: float = float(i) * TAU / 8.0 + 0.3
				var from: Vector2 = c + Vector2(cos(ang), sin(ang)) * (r * (1.2 + 0.2 * bt))
				var to: Vector2 = c + Vector2(cos(ang), sin(ang)) * (r * (1.35 + 0.7 * bt))
				draw_line(from, to, Color(color, 0.7 * (1.0 - bt)), 3.0, true)

	func _warn(c: Vector2, r: float) -> void:
		var wob: float = sin(age * 16.0) * exp(-age * 3.5) * 0.22
		draw_set_transform(c, wob, Vector2.ONE)
		var tri := PackedVector2Array([Vector2(0, -r * 0.98), Vector2(r * 1.05, r * 0.78), Vector2(-r * 1.05, r * 0.78)])
		draw_colored_polygon(tri, Color(color, 0.10))
		var closed := PackedVector2Array([tri[0], tri[1], tri[2], tri[0]])
		draw_polyline(closed, color, 7.0, true)
		draw_line(Vector2(0, -r * 0.36), Vector2(0, r * 0.18), color.lerp(Color.WHITE, 0.2), 9.0, true)
		draw_circle(Vector2(0, r * 0.48), 5.5, color.lerp(Color.WHITE, 0.2))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _cross(c: Vector2, r: float) -> void:
		var p: float = clampf(age / 0.4, 0.0, 1.0)
		var e: float = 1.0 - pow(1.0 - p, 3.0)
		var wob: float = sin(age * 18.0) * exp(-age * 4.0) * 0.18
		draw_set_transform(c, wob, Vector2.ONE)
		draw_circle(Vector2.ZERO, r, Color(color, 0.10 * e))
		draw_arc(Vector2.ZERO, r, -PI * 0.5, -PI * 0.5 + TAU * e, 64, color, 8.0, true)
		var q: float = clampf((age - 0.25) / 0.3, 0.0, 1.0)
		var k: float = r * 0.38
		draw_line(Vector2(-k, -k), Vector2(-k, -k).lerp(Vector2(k, k), q), color.lerp(Color.WHITE, 0.2), 10.0, true)
		draw_line(Vector2(k, -k), Vector2(k, -k).lerp(Vector2(-k, k), q), color.lerp(Color.WHITE, 0.2), 10.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _wifi(c: Vector2, r: float) -> void:
		var p: float = clampf(age / 0.5, 0.0, 1.0)
		var base: Vector2 = c + Vector2(0.0, r * 0.52)
		for i in 3:
			var rad: float = r * (0.45 + 0.42 * float(i))
			var a: float = clampf(p * 3.0 - float(i) * 0.6, 0.0, 1.0)
			var flick: float = 0.65 + 0.35 * sin(t * 3.0 - float(i) * 0.9)
			draw_arc(base, rad, deg_to_rad(-135.0), deg_to_rad(-45.0), 24, Color(color, a * flick), 8.0, true)
		draw_circle(base, 6.0, color)
		var q: float = clampf((age - 0.3) / 0.3, 0.0, 1.0)
		var s0 := Vector2(c.x - r * 0.8, c.y - r * 0.8)
		var s1 := Vector2(c.x + r * 0.8, c.y + r * 0.8)
		draw_line(s0, s0.lerp(s1, q), Color("ff5a6e"), 8.0, true)


# ================================================================== helper tampilan: partikel latar
class Particles extends Control:
	var color: Color = Color("3de0ff")
	var speed: float = 1.0
	var t: float = 0.0
	var items: Array = []

	func _init() -> void:
		size = Vector2(1280.0, 720.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for i in 46:
			items.append({
				"x": rng.randf() * 1280.0, "y": rng.randf() * 720.0, "s": rng.randf_range(3.0, 10.0),
				"v": rng.randf_range(14.0, 48.0), "ph": rng.randf() * TAU, "rot": rng.randf() * TAU,
				"rs": rng.randf_range(-1.0, 1.0)})

	func _process(d: float) -> void:
		t += d
		for it in items:
			it["y"] = float(it["y"]) - float(it["v"]) * d * speed
			if float(it["y"]) < -20.0:
				it["y"] = 740.0
				it["x"] = randf() * 1280.0
		queue_redraw()

	func _draw() -> void:
		for it in items:
			var a: float = 0.10 + 0.22 * (0.5 + 0.5 * sin(t * 1.3 + float(it["ph"])))
			var s: float = float(it["s"])
			draw_set_transform(Vector2(float(it["x"]) + sin(t * 0.6 + float(it["ph"])) * 14.0, float(it["y"])), float(it["rot"]) + t * float(it["rs"]), Vector2.ONE)
			draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s), Color(color, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ================================================================== helper tampilan: karakter berlari di atas progress bar
class RunnerLayer extends Control:
	const SZ := 52.0
	const SP := 46.0
	var tex: Array = []
	var value: float = 0.0
	var celebrate: float = 0.0
	var running: bool = true
	var accent: Color = Color("3de0ff")
	var x0: float = 16.0
	var x1: float = 756.0
	var base_y: float = 120.0
	var t: float = 0.0
	var sparks: Array = []
	var _spawn: float = 0.0

	func _init() -> void:
		size = Vector2(772.0, 176.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		for folder in ["p1", "p2", "p3", "p4"]:
			var pool: Array[int] = []
			for i in Global.CHARACTERS.size():
				if String(Global.CHARACTERS[i][0]) == folder:
					pool.append(i)
			if not pool.is_empty():
				var tx: Texture2D = Global.character_texture(0, pool[rng.randi() % pool.size()])
				if tx != null:
					tex.append(tx)

	func _head() -> float:
		return x0 + 8.0 + value * (x1 - x0 - 8.0)

	func _process(d: float) -> void:
		if not is_visible_in_tree():
			return
		t += d
		if running or celebrate > 0.5:
			_spawn -= d
			while _spawn <= 0.0:
				_spawn += 0.028 if running else 0.05
				var hy: float = base_y + 20.0 + randf_range(-9.0, 9.0)
				sparks.append({"p": Vector2(_head(), hy), "v": Vector2(-randf_range(40.0, 140.0), randf_range(-110.0, 30.0)),
					"life": 0.0, "max": randf_range(0.45, 0.9), "s": randf_range(3.0, 7.0)})
		var i: int = sparks.size() - 1
		while i >= 0:
			var sp: Dictionary = sparks[i]
			sp["life"] = float(sp["life"]) + d
			sp["p"] = (sp["p"] as Vector2) + (sp["v"] as Vector2) * d
			sp["v"] = (sp["v"] as Vector2) + Vector2(0.0, 160.0) * d
			if float(sp["life"]) >= float(sp["max"]):
				sparks.remove_at(i)
			i -= 1
		queue_redraw()

	func _draw() -> void:
		for sp in sparks:
			var k: float = 1.0 - float(sp["life"]) / float(sp["max"])
			var pp: Vector2 = sp["p"]
			var s: float = float(sp["s"]) * (0.4 + 0.6 * k)
			draw_rect(Rect2(pp - Vector2(s, s) * 0.5, Vector2(s, s)), Color(accent.lerp(Color.WHITE, 0.4), k))
		var head: float = _head()
		for i in range(tex.size() - 1, -1, -1):
			var x: float = head - float(i) * SP
			if x < x0 - 10.0:
				continue
			var ph: float = t * (7.5 if running else 5.0) + float(i) * 0.9
			var hop: float = absf(sin(ph))
			var lift: float = hop * (10.0 + 34.0 * celebrate)
			var sx: float = lerpf(1.10, 0.94, hop)
			var sy: float = lerpf(0.90, 1.07, hop)
			var sw: float = 22.0 * (1.0 - 0.45 * hop)
			var sh := PackedVector2Array()
			for j in 14:
				var a: float = TAU * float(j) / 14.0
				sh.append(Vector2(x + cos(a) * sw, base_y + 3.0 + sin(a) * 3.5))
			draw_colored_polygon(sh, Color(0, 0, 0, 0.45 * (1.0 - 0.6 * hop)))
			draw_set_transform(Vector2(x, base_y - lift), 0.08 + 0.06 * sin(ph * 0.5), Vector2(sx, sy))
			var rc := Rect2(-SZ * 0.5, -SZ, SZ, SZ)
			draw_rect(rc.grow(3.0), Color(0, 0, 0, 0.92))
			draw_texture_rect(tex[i], rc, false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
