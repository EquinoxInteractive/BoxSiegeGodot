extends Control
## Menu utama bergaya game konsol (PlayStation):
##   MAIN -> PLAY / CONTROLS / SETTINGS / QUIT
##   PLAYERS (pilih 2/3/4 pemain), SETTINGS (musik, sfx, getar, shake, fullscreen, show fps, limit fps, CONTROLS SETUP),
##   CONTROLS (daftar tombol yang sedang dipakai)
##   SETTINGS > CONTROLS SETUP ("binds"): pilih Controller / Keyboard tiap pemain + ganti keybind.
## Pengaturan bersifat DRAF: perubahan langsung terlihat/terdengar (termasuk indikator P1-P4 di kanan atas),
## tetapi baru disimpan ke file setelah tombol SAVE. Keluar tanpa SAVE (BACK dua kali) = perubahan dibuang.
## Semua controller yang terhubung + keyboard bisa menavigasi menu lewat UIInput.

# Logo BoxSiege (title.png 1024x202) ditampilkan 580 x 114. Pivot di tengah logo,
# jadi posisi sub-menu (skala 0.4) sudah dihitung agar pojok kiri atas logo ada di sekitar (40, 16).
const SUB_LOGO_POS := Vector2(-134, -18)
const MAIN_LOGO_POS := Vector2(54, 140)

var bg: UIKit.FxBackground
var logo: Logo
var posters_root: Control
var prompt: UIKit.PromptBar
var status: UIKit.PadStatus

var screens := {}           # nama -> Control
var items := {}             # nama -> Array (kontrol yang bisa dipilih)
var idx := {}               # nama -> index terpilih
var current := ""
var dock: Array = []        # tombol SHOP & INVENTORY (terpisah dari daftar menu, di kanan bawah)
var dock_idx: int = -1       # -1 = fokus ada di daftar menu; 0 = SHOP; 1 = INVENTORY
var leaving := false
var rng := RandomNumberGenerator.new()

var controls_pads_label: Label
var binds: BindsEditor

const SET_SETUP := 7      # indeks item di layar settings: 0-6 baris setting, 7 CONTROLS SETUP, 8 SAVE, 9 BACK
const SET_SAVE := 8
const SET_BACK := 9
const SET_ROW_Y := 176.0  # posisi Y baris pertama di layar settings
const SET_ROW_STEP := 52.0  # jarak antar baris (baris & tombol setinggi 48)
var setting_rows: Array = []
var save_btn: UIKit.FancyButton
var unsaved_banners: Array = []
var _discard_until: int = 0


func _ready() -> void:
	rng.randomize()
	theme = Global.ui_theme
	Global.play_music("menu")

	bg = UIKit.FxBackground.new(Color("140606"), Color("45100f"), Color("ff7a2a"))
	add_child(bg)
	bg.set_image(Global.map_background("hell"), 0.74, 0.8)

	_build_posters()

	logo = Logo.new(Global.GAME_TITLE)
	logo.position = MAIN_LOGO_POS
	add_child(logo)

	_build_main()
	_build_players()
	_build_settings()
	_build_binds()
	_build_controls()

	status = UIKit.PadStatus.new()
	status.position = Vector2(1280 - 350 - 24, 16)
	add_child(status)

	prompt = UIKit.make_prompt(self)

	UIInput.pressed.connect(_on_input)
	UIInput.pad_changed.connect(_on_pad_changed)

	_show_screen("main", true)
	_play_intro()


func _exit_tree() -> void:
	Global.revert_edit()   # kalau masih ada draf yang belum di-SAVE, buang
	if UIInput.pressed.is_connected(_on_input):
		UIInput.pressed.disconnect(_on_input)
	if UIInput.pad_changed.is_connected(_on_pad_changed):
		UIInput.pad_changed.disconnect(_on_pad_changed)


# ================================================================== logo
class Logo extends Control:
	const LOGO_PATH := "res://assets/sprites/ui/title.png"
	const LOGO_SIZE := Vector2(580, 114.4)   # rasio sama dengan title.png (1024 x 202)

	var tex: Texture2D
	var title_text: String = "BOXSIEGE"
	var fsize: int = 110
	var t: float = 0.0

	func _init(title: String = "BOXSIEGE") -> void:
		title_text = title
		size = LOGO_SIZE
		pivot_offset = LOGO_SIZE * 0.5
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		# logo di-skala turun dari 1024px, jadi pakai filter halus (bukan pixel/nearest)
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if ResourceLoader.exists(LOGO_PATH):
			tex = load(LOGO_PATH)

	func _process(d: float) -> void:
		t += d
		rotation = deg_to_rad(-2.5 + sin(t * 1.3) * 0.9)
		queue_redraw()

	func _draw() -> void:
		if tex != null:
			# bayangan, lalu logo
			draw_texture_rect(tex, Rect2(Vector2(8, 10), size), false, Color(0, 0, 0, 0.55))
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
			var y: float = size.y + 10.0
			for k in 4:
				var pts := UIKit.slanted(100, 12, 8, 36.0 + k * 128.0, y)
				draw_colored_polygon(pts, Global.PLAYER_COLORS[k])
				draw_polyline(UIKit.closed(pts), Color.BLACK, 2.0, true)
			return
		# cadangan kalau title.png belum ada: tulis teks biasa
		var f: Font = UIKit.font()
		var asc: float = f.get_ascent(fsize)
		var base := Vector2(14.0, 8.0 + asc * 0.92)
		draw_string(f, base + Vector2(8, 10), title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(0, 0, 0, 0.55))
		draw_string_outline(f, base, title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, 20, Color.BLACK)
		draw_string(f, base, title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, UIKit.GOLD)


# ================================================================== kartu jumlah pemain
class CountCard extends Control:
	signal activated
	signal hovered

	const SKEW := 34.0      # kemiringan sisi kartu (px)

	var count: int = 2
	var selected: bool = false
	var sel: float = 0.0:
		set(v):
			sel = v
			queue_redraw()
	var _tw: Tween
	var portraits: Array[Texture2D] = []
	var t: float = 0.0

	func _init(n: int = 2) -> void:
		count = n
		size = Vector2(340, 420)
		custom_minimum_size = size
		pivot_offset = size * 0.5
		mouse_filter = Control.MOUSE_FILTER_STOP
		for i in n:
			portraits.append(Global.character_texture(i, i * 4))

	func _ready() -> void:
		mouse_entered.connect(func() -> void: hovered.emit())
		UIInput.pad_changed.connect(func(_d: int, _c: bool) -> void: queue_redraw())

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			press()

	func set_selected(v: bool) -> void:
		if v == selected:
			return
		selected = v
		if _tw:
			_tw.kill()
		if is_inside_tree():
			_tw = UIKit.tw(self)
			_tw.set_parallel(true)
			_tw.tween_property(self, "sel", 1.0 if v else 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_tw.tween_property(self, "scale", Vector2.ONE * (1.07 if v else 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			sel = 1.0 if v else 0.0

	func press() -> void:
		Global.play_sfx("ui_confirm", -3.0)
		UIKit.burst(get_parent(), position + size * 0.5, UIKit.GOLD, 28, 340.0)
		activated.emit()

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	## Titik tengah horizontal kartu (yang miring) pada ketinggian y.
	func _cx(y: float) -> float:
		return size.x * 0.5 + SKEW * 0.5 - SKEW * y / size.y

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var lift: float = -sel * 10.0
		draw_set_transform(Vector2(0, lift))
		draw_colored_polygon(UIKit.slanted(w, h, SKEW, 10, 12), Color(0, 0, 0, 0.5))
		var pts := UIKit.slanted(w, h, SKEW)
		var base0 := Color(0.09, 0.09, 0.2, 0.94)
		var base1 := Color(0.04, 0.04, 0.1, 0.94)
		var c0: Color = base0.lerp(UIKit.GOLD.lightened(0.25), sel * 0.9)
		var c1: Color = base1.lerp(UIKit.GOLD.darkened(0.25), sel * 0.9)
		draw_polygon(pts, PackedColorArray([c0, c0, c1, c1]))
		draw_polyline(UIKit.closed(pts), Color(1, 1, 1, lerpf(0.2, 1.0, sel)), 3.0 + sel * 2.0, true)
		var ink: Color = Color.WHITE.lerp(UIKit.INK, sel)
		# Kartu berbentuk jajar genjang miring, jadi garis tengahnya bergeser tiap ketinggian (lihat _cx).
		# Setiap elemen dipusatkan di garis tengah itu pada tinggi elemennya sendiri -> angka, tulisan, potret, dan teks bawah sejajar & simetris.
		# angka besar
		UIKit.text_in(self, str(count), Rect2(_cx(89.0) - 150.0, 4, 300, 170), 170, ink, HORIZONTAL_ALIGNMENT_CENTER, 0)
		UIKit.text_in(self, "PLAYERS", Rect2(_cx(178.0) - 150.0, 150, 300, 56), 46, ink, HORIZONTAL_ALIGNMENT_CENTER)
		# potret pemain
		var ps := 54.0
		var gap := 10.0
		var total: float = count * ps + (count - 1) * gap
		var x0: float = _cx(232.0 + ps * 0.5) - total * 0.5
		var pads: Array[int] = UIInput.pads()
		for i in count:
			var bob: float = sin(t * 3.0 + i * 0.9) * 4.0 * (0.4 + sel * 0.6)
			var r := Rect2(x0 + i * (ps + gap), 232 + bob, ps, ps)
			draw_rect(Rect2(r.position - Vector2(3, 3), r.size + Vector2(6, 6)), Global.PLAYER_COLORS[i])
			draw_texture_rect(portraits[i], r, false)
			# ikon perangkat input di bawah potret
			var ic := Vector2(r.position.x + ps * 0.5, 322)
			var icol: Color = Global.PLAYER_COLORS[i]
			if Global.uses_pad(i):
				UIKit.draw_pad_icon(self, ic, 34.0, icol)
			else:
				UIKit.draw_keys_icon(self, ic, 34.0, Color(icol, 0.8))
		var hint := "%d CONTROLLER%s CONNECTED" % [pads.size(), "" if pads.size() == 1 else "S"]
		UIKit.text_in(self, hint, Rect2(_cx(h - 44.0) - 160.0, h - 62, 320, 36), 20, Color(ink, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
		draw_set_transform(Vector2.ZERO)


# ================================================================== layar-layar
func _make_screen(name_id: String) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	add_child(c)
	screens[name_id] = c
	items[name_id] = []
	idx[name_id] = 0
	return c


func _build_main() -> void:
	var s := _make_screen("main")
	var labels := ["CAMPAIGN", "VERSUS", "CONTROLS", "SETTINGS", "QUIT"]
	var tags := ["1 PLAYER", "2 - 4 PLAYERS", "", "", ""]
	for i in labels.size():
		var b := UIKit.FancyButton.new(labels[i], Vector2(470, 62), 36)
		b.tag = tags[i]
		b.position = Vector2(54, 296 + i * 70)
		s.add_child(b)
		items["main"].append(b)
		b.hovered.connect(_hover.bind("main", i))
		b.activated.connect(_on_main_activated.bind(i))
	# ---- SHOP & INVENTORY: sengaja dipisah dari daftar menu (kanan bawah, di bawah poster) supaya mudah dilihat
	dock.clear()
	for k in 2:
		var d := CosmeticUI.DockButton.new("shop" if k == 0 else "inventory")
		d.position = Vector2(716.0 + float(k) * 276.0, 530.0)
		s.add_child(d)
		dock.append(d)
		d.hovered.connect(_dock_hover.bind(k))
		d.activated.connect(_dock_open.bind(k))


func _build_players() -> void:
	var s := _make_screen("players")
	var banner := UIKit.Banner.new("HOW MANY PLAYERS?", 52)
	banner.position = Vector2(658.0 - banner.size.x / 2.0, 140)
	s.add_child(banner)
	s.set_meta("banner", banner)
	for i in 3:
		var card := CountCard.new(i + 2)
		card.position = Vector2(112 + i * 376, 214)
		s.add_child(card)
		items["players"].append(card)
		card.hovered.connect(_hover.bind("players", i))
		card.activated.connect(_on_pick_players.bind(i + 2))
	idx["players"] = 0


func _build_settings() -> void:
	var s := _make_screen("settings")
	var banner := UIKit.Banner.new("SETTINGS", 52)
	banner.position = Vector2(290, 104)
	s.add_child(banner)
	_add_unsaved_banner(s, Vector2(banner.position.x + banner.size.x + 24.0, 118))

	var defs := [
		["MUSIC", "slider", Global.music_volume],
		["SOUND FX", "slider", Global.sfx_volume],
		["VIBRATION", "toggle", 1.0 if Global.vibration else 0.0],
		["SCREEN SHAKE", "toggle", 1.0 if Global.screen_shake else 0.0],
		["FULLSCREEN", "toggle", 1.0 if Global.fullscreen else 0.0],
		["SHOW FPS", "toggle", 1.0 if Global.show_fps else 0.0],
		["FPS LIMIT", "choice", float(Global.fps_index())],
	]
	setting_rows.clear()
	for i in defs.size():
		var d: Array = defs[i]
		var row := UIKit.SettingRow.new(d[0], d[1], float(d[2]), Vector2(740, 48))
		if String(d[1]) == "choice":
			row.options = Global.fps_option_names()
		row.position = Vector2(270, SET_ROW_Y + i * SET_ROW_STEP)
		s.add_child(row)
		items["settings"].append(row)
		setting_rows.append(row)
		row.hovered.connect(_hover.bind("settings", i))
		row.changed.connect(_on_setting_changed.bind(i))
	# tombol menuju pengaturan kontrol (controller / keyboard + keybind)
	var setup_btn := UIKit.FancyButton.new("CONTROLS SETUP", Vector2(470, 48), 30)
	setup_btn.tag = "KEYBOARD / CONTROLLER"
	setup_btn.position = Vector2(270, SET_ROW_Y + defs.size() * SET_ROW_STEP + 4)
	s.add_child(setup_btn)
	items["settings"].append(setup_btn)
	setup_btn.hovered.connect(_hover.bind("settings", SET_SETUP))
	setup_btn.activated.connect(_open_binds)
	# SAVE + BACK (sebaris)
	var y: float = SET_ROW_Y + (defs.size() + 1) * SET_ROW_STEP + 6
	save_btn = UIKit.FancyButton.new("SAVE", Vector2(350, 48), 32)
	save_btn.accent = UIKit.GREEN
	save_btn.position = Vector2(270, y)
	s.add_child(save_btn)
	items["settings"].append(save_btn)
	save_btn.hovered.connect(_hover.bind("settings", SET_SAVE))
	save_btn.activated.connect(_save_changes)
	var back := UIKit.FancyButton.new("BACK", Vector2(350, 48), 32)
	back.position = Vector2(640, y)
	s.add_child(back)
	items["settings"].append(back)
	back.hovered.connect(_hover.bind("settings", SET_BACK))
	back.activated.connect(_go_back)
	_refresh_save_state()


## Label "UNSAVED" yang muncul di samping judul saat ada perubahan yang belum disimpan.
func _add_unsaved_banner(parent: Control, pos: Vector2) -> void:
	var b := UIKit.Banner.new("UNSAVED", 28, Color("ff5a3a"), Color.WHITE, 22.0)
	b.position = pos
	b.visible = false
	parent.add_child(b)
	unsaved_banners.append(b)


func _on_setting_changed(v: float, i: int) -> void:
	match i:
		0:
			Global.set_music_volume(v)
		1:
			Global.set_sfx_volume(v)
		2:
			Global.vibration = v > 0.5
			if Global.vibration:
				for d in UIInput.pads():
					UIInput.rumble(d, 0.6, 0.6, 0.25)
		3:
			Global.screen_shake = v > 0.5
		4:
			Global.fullscreen = v > 0.5
			Global.apply_fullscreen()
		5:
			Global.set_show_fps(v > 0.5)
		6:
			var oi: int = clampi(int(roundf(v)), 0, Global.FPS_OPTIONS.size() - 1)
			Global.fps_limit = int(Global.FPS_OPTIONS[oi])
			Global.apply_fps_limit()
	_refresh_save_state()


## Samakan tampilan baris setting dengan nilai di Global (dipanggil saat layar dibuka).
func _sync_setting_rows() -> void:
	var vals := [
		Global.music_volume, Global.sfx_volume,
		1.0 if Global.vibration else 0.0,
		1.0 if Global.screen_shake else 0.0,
		1.0 if Global.fullscreen else 0.0,
		1.0 if Global.show_fps else 0.0,
		float(Global.fps_index()),
	]
	for i in setting_rows.size():
		var row: UIKit.SettingRow = setting_rows[i]
		row.value = float(vals[i])
		row.queue_redraw()


## Perbarui tombol SAVE, label UNSAVED, dan tombol SAVE di CONTROLS SETUP sesuai ada / tidaknya perubahan.
func _refresh_save_state() -> void:
	var dirty: bool = Global.has_unsaved()
	_discard_until = 0
	if save_btn != null:
		save_btn.disabled = not dirty
		save_btn.tag = "UNSAVED CHANGES" if dirty else "NO CHANGES"
		save_btn.queue_redraw()
	if binds != null:
		binds.dirty = dirty
	for b in unsaved_banners:
		var ban: Control = b
		if dirty and not ban.visible:
			ban.visible = true
			ban.scale = Vector2.ONE * 0.4
			UIKit.tw(ban).tween_property(ban, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		elif not dirty:
			ban.visible = false


## Tombol SAVE: tulis semua perubahan ke file.
func _save_changes() -> void:
	if not Global.has_unsaved():
		Global.play_sfx("hit", -14.0)
		UIInput.toast("NOTHING TO SAVE", "No changes were made", Color(1, 1, 1, 0.8))
		return
	Global.commit_edit()
	Global.play_sfx("pu_heal", -4.0)
	UIInput.toast("SETTINGS SAVED", "Your changes have been saved", UIKit.GREEN)
	for d in UIInput.pads():
		UIInput.rumble(d, 0.2, 0.5, 0.15)
	if current == "settings" and save_btn != null:
		UIKit.burst(self, save_btn.position + Vector2(170, 28), UIKit.GREEN, 26, 320.0)
	_refresh_save_state()


func _build_binds() -> void:
	var s := _make_screen("binds")
	var banner := UIKit.Banner.new("CONTROLS SETUP", 52)
	banner.position = Vector2(290, 104)
	s.add_child(banner)
	binds = BindsEditor.new()
	binds.position = Vector2(60, 176)
	s.add_child(binds)
	binds.back_requested.connect(_go_back)
	binds.save_requested.connect(_save_changes)
	binds.edited.connect(_refresh_save_state)
	binds.capture_changed.connect(_update_prompts)
	_add_unsaved_banner(s, Vector2(banner.position.x + banner.size.x + 24.0, 118))
	_refresh_save_state()


func _open_binds() -> void:
	binds.reset_focus()
	Global.play_sfx("ui_panel", -5.0)
	_show_screen("binds")


func _build_controls() -> void:
	var s := _make_screen("controls")
	var banner := UIKit.Banner.new("CONTROLS", 52)
	banner.position = Vector2(300, 104)
	s.add_child(banner)
	var sheet := ControlsSheet.new()
	sheet.position = Vector2(60, 184)
	s.add_child(sheet)
	s.set_meta("sheet", sheet)


# ------------------------------------------------------------------ editor CONTROLS SETUP
## Layar pengaturan kontrol (di dalam SETTINGS):
##   baris PLAYER  : pilih pemain 1-4 (kiri/kanan atau Q/E)
##   baris INPUT   : pilih perangkat pemain itu -> AUTO / KEYBOARD / CONTROLLER 1..n (sesuai jumlah controller)
##   6 baris aksi  : kolom kiri = keyboard, kolom kanan = controller. ACCEPT / klik = ganti tombol,
##                   lalu tekan tombol baru (ESC = batal). Tombol yang sudah dipakai akan saling bertukar.
##   baris bawah   : RESET pemain ini / RESET semua / BACK
class BindsEditor extends Control:
	signal back_requested
	signal capture_changed
	signal save_requested
	signal edited                       # ada perubahan (device / keybind / reset) -> menu memperbarui status SAVE

	const W := 1160.0
	const ROWS := 9                       # 0 PLAYER, 1 INPUT, 2..7 aksi, 8 reset/back
	const ROW_RESET := 8
	const COL_X := [0.0, 600.0]
	const COL_W := 560.0

	var player: int = 0
	var row: int = 0
	var col: int = 0
	var capturing: bool = false
	var cap_row: int = 2
	var cap_col: int = 0
	var t: float = 0.0
	var flash := {}
	var _hit: Array = []
	var _click_block: int = 0
	var dirty: bool = false             # diisi menu: ada perubahan yang belum di-SAVE

	func _init() -> void:
		size = Vector2(W, 456)
		custom_minimum_size = size
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _ready() -> void:
		UIInput.captured.connect(_on_captured)
		UIInput.capture_cancelled.connect(_on_cancelled)
		UIInput.pad_changed.connect(_on_pad_changed)

	func _exit_tree() -> void:
		UIInput.end_capture()
		if UIInput.captured.is_connected(_on_captured):
			UIInput.captured.disconnect(_on_captured)
		if UIInput.capture_cancelled.is_connected(_on_cancelled):
			UIInput.capture_cancelled.disconnect(_on_cancelled)
		if UIInput.pad_changed.is_connected(_on_pad_changed):
			UIInput.pad_changed.disconnect(_on_pad_changed)

	func _on_pad_changed(_d: int, _c: bool) -> void:
		queue_redraw()

	func _process(d: float) -> void:
		t += d
		for k in flash.keys():
			flash[k] = float(flash[k]) - d * 2.5
			if float(flash[k]) <= 0.0:
				flash.erase(k)
		if is_visible_in_tree():
			queue_redraw()

	## Dipanggil saat layar ini dibuka.
	func reset_focus() -> void:
		row = 0
		col = 0
		if capturing:
			UIInput.cancel_capture()

	# ---------------------------------------------------------------- input (controller / keyboard)
	func handle(action: StringName) -> void:
		if capturing:
			return
		match action:
			&"up": _move_row(-1)
			&"down": _move_row(1)
			&"left": _horizontal(-1)
			&"right": _horizontal(1)
			&"prev": _set_player(player - 1)
			&"next": _set_player(player + 1)
			&"accept": _activate()
			&"extra": _reset_current()
			&"back": back_requested.emit()

	func _move_row(dir: int) -> void:
		row = posmod(row + dir, ROWS)
		col = clampi(col, 0, 3 if row == ROW_RESET else 1)
		Global.play_sfx("ui_move", -10.0)

	func _horizontal(dir: int) -> void:
		if row == 0:
			_set_player(player + dir)
		elif row == 1:
			_cycle_device(dir)
		elif row == ROW_RESET:
			_set_col(col + dir, 3)
		else:
			_set_col(col + dir, 1)

	func _set_col(c: int, max_c: int) -> void:
		var nc: int = clampi(c, 0, max_c)
		if nc != col:
			col = nc
			Global.play_sfx("ui_move", -10.0)

	func _set_player(p: int) -> void:
		player = posmod(p, 4)
		Global.play_sfx("ui_marimba", -9.0)

	func _cycle_device(dir: int) -> void:
		Global.cycle_input_pref(player, dir)
		edited.emit()
		Global.play_sfx("ui_marimba", -9.0)
		var dev: int = Global.device_of(player)
		if dev >= 0:
			UIInput.rumble(dev, 0.4, 0.4, 0.15)

	func _activate() -> void:
		if row == 0:
			_set_player(player + 1)
		elif row == 1:
			_cycle_device(1)
		elif row == ROW_RESET:
			match col:
				0: _reset_player()
				1: _reset_all()
				2: save_requested.emit()
				3: back_requested.emit()
		else:
			_begin_capture(row, col)

	# ---------------------------------------------------------------- tangkap tombol baru
	func _begin_capture(r: int, c: int) -> void:
		capturing = true
		cap_row = r
		cap_col = c
		UIInput.begin_capture("key" if c == 0 else "pad")
		Global.play_sfx("ui_ready", -6.0)
		capture_changed.emit()

	func _on_captured(code: int, _device: int) -> void:
		if not capturing:
			return
		var action: String = Global.ACTIONS[cap_row - 2]
		var swapped := []
		if cap_col == 0:
			if Global.is_key_reserved(code):
				UIInput.toast("KEY RESERVED", "Pick another key", Color("ff7a7a"))
				UIInput.begin_capture("key")
				return
			swapped = Global.set_key_binding(player, action, code)
		else:
			if Global.is_pad_reserved(code):
				UIInput.toast("BUTTON RESERVED", "START / HOME is used for pause", Color("ff7a7a"))
				UIInput.begin_capture("pad")
				return
			swapped = Global.set_pad_binding(player, action, code)
		_after_bind(cap_col, action, swapped)

	func _on_cancelled() -> void:
		if not capturing:
			return
		capturing = false
		_click_block = Time.get_ticks_msec() + 200
		Global.play_sfx("hit", -14.0)
		capture_changed.emit()

	func _after_bind(c: int, action: String, swapped: Array) -> void:
		capturing = false
		flash["%d:%s" % [c, action]] = 1.0
		if not swapped.is_empty():
			var sp: int = int(swapped[0])
			var sa: String = String(swapped[1])
			if sp == player or c == 0:
				flash["%d:%s" % [c, sa]] = 1.0
			var who: String = "P%d %s" % [sp + 1, Global.ACTION_LABELS[sa]] if c == 0 else String(Global.ACTION_LABELS[sa])
			UIInput.toast("SWAPPED WITH %s" % who, "That button was already in use", Color("ffd23f"))
		edited.emit()
		Global.play_sfx("pu_heal", -6.0)
		capture_changed.emit()

	# ---------------------------------------------------------------- reset
	func _reset_current() -> void:
		if row == 1:
			Global.set_input_pref(player, Global.PREF_AUTO)
			edited.emit()
			Global.play_sfx("click", -6.0)
		elif row >= 2 and row < ROW_RESET:
			var action: String = Global.ACTIONS[row - 2]
			if col == 0:
				Global.reset_key_action(player, action)
			else:
				Global.reset_pad_action(player, action)
			flash["%d:%s" % [col, action]] = 1.0
			edited.emit()
			Global.play_sfx("click", -6.0)

	func _reset_player() -> void:
		Global.reset_bindings(player)
		Global.set_input_pref(player, Global.PREF_AUTO)
		edited.emit()
		for a in Global.ACTIONS:
			flash["0:%s" % a] = 1.0
			flash["1:%s" % a] = 1.0
		Global.play_sfx("pu_heal", -6.0)
		UIInput.toast("P%d RESET" % (player + 1), "Controls back to default", Color("4be3a0"))

	func _reset_all() -> void:
		Global.reset_bindings()
		Global.reset_input_prefs()
		edited.emit()
		for a in Global.ACTIONS:
			flash["0:%s" % a] = 1.0
			flash["1:%s" % a] = 1.0
		Global.play_sfx("pu_heal", -6.0)
		UIInput.toast("ALL CONTROLS RESET", "Back to default", Color("4be3a0"))

	# ---------------------------------------------------------------- mouse
	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			return
		if capturing or Time.get_ticks_msec() < _click_block:
			return
		for h in _hit:
			var r: Rect2 = h["rect"]
			if not r.has_point(event.position):
				continue
			row = int(h["row"])
			col = int(h["col"])
			match String(h["kind"]):
				"tab":
					player = int(h["arg"])
					Global.play_sfx("click", -8.0)
				"dev":
					_cycle_device(int(h["arg"]))
				_:
					_activate()
			return

	# ---------------------------------------------------------------- gambar
	func _pad_style() -> String:
		var d: int = Global.device_of(player)
		return UIInput.pad_style(d if d >= 0 else -2)

	func _panel(r: Rect2, active: bool, fill: Color = Color(0.06, 0.06, 0.14, 0.9)) -> void:
		var pts := UIKit.slanted(r.size.x, r.size.y, 14.0, r.position.x, r.position.y)
		draw_colored_polygon(pts, fill)
		draw_polyline(UIKit.closed(pts), UIKit.GOLD if active else Color(1, 1, 1, 0.16), 3.0 if active else 2.0, true)

	func _cap(right: float, y: float, s: String, round_cap: bool, a: float) -> void:
		var fs := 22
		var w: float = maxf(64.0, UIKit.text_w(s, fs) + 28.0)
		var r := Rect2(right - w, y + 3.0, w, 36.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.93, 0.93, 0.97, a)
		sb.set_corner_radius_all(18 if round_cap else 7)
		sb.border_color = Color(0.5, 0.52, 0.68, a)
		sb.border_width_bottom = 4
		draw_style_box(sb, r)
		UIKit.text_in(self, s, Rect2(r.position.x, r.position.y - 2.0, w, 36.0), fs, Color(UIKit.INK, a))

	func _draw() -> void:
		_hit.clear()
		var pc: Color = Global.PLAYER_COLORS[player]
		var on_pad: bool = Global.uses_pad(player)
		var dev: int = Global.device_of(player)
		var pulse: float = 0.5 + 0.5 * sin(t * 7.0)

		# ---- baris 0: PLAYER
		_panel(Rect2(0, 0, W, 48), row == 0)
		UIKit.text_in(self, "PLAYER", Rect2(40, 0, 220, 48), 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		for i in 4:
			var tr := Rect2(300 + i * 170, 6, 150, 36)
			var on: bool = i == player
			var tp := UIKit.slanted(tr.size.x, tr.size.y, 10.0, tr.position.x, tr.position.y)
			var tc: Color = Global.PLAYER_COLORS[i] if on else Color(0.14, 0.14, 0.24, 0.9)
			draw_colored_polygon(tp, tc)
			draw_polyline(UIKit.closed(tp), Color.BLACK if on else Color(1, 1, 1, 0.2), 2.0, true)
			UIKit.text_in(self, "P%d" % (i + 1), tr, 28, Color.WHITE if on else Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER, 5 if on else 0)
			_hit.append({"rect": tr, "row": 0, "col": 0, "kind": "tab", "arg": i})
		UIKit.text_in(self, "Q / E", Rect2(W - 130, 0, 100, 48), 18, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_RIGHT)

		# ---- baris 1: INPUT (perangkat)
		_panel(Rect2(0, 54, W, 48), row == 1)
		UIKit.text_in(self, "INPUT", Rect2(40, 54, 220, 48), 30, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		var act1: bool = row == 1
		var chc: Color = UIKit.GOLD if act1 else Color(1, 1, 1, 0.4)
		var cs: float = 11.0 * (1.0 + (pulse * 0.25 if act1 else 0.0))
		UIKit.draw_chevron(self, Vector2(322, 78), cs, -1, chc)
		UIKit.draw_chevron(self, Vector2(832, 78), cs, 1, chc)
		_hit.append({"rect": Rect2(300, 54, 60, 48), "row": 1, "col": 0, "kind": "dev", "arg": -1})
		_hit.append({"rect": Rect2(800, 54, 60, 48), "row": 1, "col": 0, "kind": "dev", "arg": 1})
		_hit.append({"rect": Rect2(360, 54, 440, 48), "row": 1, "col": 0, "kind": "dev", "arg": 1})
		var pref: int = Global.input_pref[player]
		var txt: String = Global.pref_label(pref)
		var warn := false
		if pref == Global.PREF_AUTO:
			txt += "  >  " + ("PAD %d" % UIInput.pad_number(dev) if on_pad else "KEYBOARD")
		elif pref >= 0 and not on_pad:
			txt += "  (NOT FOUND)"
			warn = true
		if on_pad:
			UIKit.draw_pad_icon(self, Vector2(384, 78), 30.0, pc.lightened(0.2))
		else:
			UIKit.draw_keys_icon(self, Vector2(384, 78), 30.0, pc.lightened(0.2))
		UIKit.text_in(self, txt, Rect2(414, 54, 380, 48), 27, Color(1, 0.55, 0.45) if warn else Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		var npads: int = UIInput.pads().size()
		UIKit.text_in(self, "%d CONTROLLER%s CONNECTED" % [npads, "" if npads == 1 else "S"], Rect2(870, 54, 270, 48), 19, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_RIGHT)

		# ---- header kolom
		var heads := ["KEYBOARD", "CONTROLLER"]
		for c in 2:
			var unused: bool = (c == 0 and on_pad) or (c == 1 and not on_pad)
			var hc: Color = Color(UIKit.GOLD, 0.45 if unused else 1.0)
			UIKit.text_in(self, heads[c], Rect2(COL_X[c] + 26.0, 106, 300, 30), 26, hc, HORIZONTAL_ALIGNMENT_LEFT)
			if unused:
				UIKit.text_in(self, "NOT IN USE", Rect2(COL_X[c] + COL_W - 224.0, 106, 200, 30), 18, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_RIGHT)
			elif c == 1:
				UIKit.text_in(self, "STICK ALWAYS WORKS", Rect2(COL_X[c] + COL_W - 244.0, 106, 220, 30), 17, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_RIGHT)

		# ---- 6 baris aksi x 2 kolom
		var style: String = _pad_style()
		for k in Global.ACTIONS.size():
			var action: String = Global.ACTIONS[k]
			var r_idx: int = 2 + k
			var y: float = 136.0 + k * 44.0
			for c in 2:
				var rect := Rect2(COL_X[c], y, COL_W, 42)
				var active: bool = row == r_idx and col == c
				var is_cap: bool = capturing and cap_row == r_idx and cap_col == c
				var unused: bool = (c == 0 and on_pad) or (c == 1 and not on_pad)
				var a: float = 0.55 if unused and not active else 1.0
				var pts := UIKit.slanted(rect.size.x, rect.size.y, 12.0, rect.position.x, rect.position.y)
				var bg: Color = Color(0.2, 0.17, 0.05, 0.95) if active else Color(0.06, 0.06, 0.14, 0.9)
				if is_cap:
					bg = bg.lerp(pc.darkened(0.35), 0.45 + pulse * 0.3)
				draw_colored_polygon(pts, bg)
				var fl: float = float(flash.get("%d:%s" % [c, action], 0.0))
				if fl > 0.0:
					draw_colored_polygon(pts, Color(UIKit.GREEN, fl * 0.55))
				var oc: Color = Color(1, 1, 1, 0.16)
				if is_cap:
					oc = pc.lightened(0.3)
				elif active:
					oc = UIKit.GOLD
				draw_polyline(UIKit.closed(pts), oc, 3.0 if (active or is_cap) else 2.0, true)
				UIKit.text_in(self, Global.ACTION_LABELS[action], Rect2(rect.position.x + 34, y, 220, 42), 28, Color(UIKit.GOLD if active else Color.WHITE, a), HORIZONTAL_ALIGNMENT_LEFT)
				var right: float = rect.end.x - 28.0
				if is_cap:
					var msg: String = "PRESS A KEY..." if c == 0 else "PRESS A BUTTON..."
					UIKit.text_in(self, msg, Rect2(rect.position.x + 200, y, rect.size.x - 230, 42), 24, Color(1, 1, 1, 0.55 + pulse * 0.45), HORIZONTAL_ALIGNMENT_RIGHT)
				elif c == 0:
					_cap(right, y, Global.key_name(int(Global.key_bindings[player][action])), false, a)
				else:
					_cap(right, y, Global.pad_button_name(int(Global.pad_bindings[player][action]), style), true, a)
				_hit.append({"rect": rect, "row": r_idx, "col": c, "kind": "bind"})

		# ---- baris bawah: RESET / RESET ALL / SAVE / BACK
		var labels := ["RESET P%d" % (player + 1), "RESET ALL", "SAVE", "BACK"]
		var rects := [Rect2(0, 404, 272, 46), Rect2(296, 404, 272, 46), Rect2(592, 404, 272, 46), Rect2(888, 404, 272, 46)]
		for b in 4:
			var br: Rect2 = rects[b]
			var bact: bool = row == ROW_RESET and col == b
			var fill: Color = Color(0.06, 0.06, 0.14, 0.9)
			var lc: Color = Color.WHITE if bact else Color(1, 0.55, 0.55)
			if b < 2:
				fill = Color(0.2, 0.08, 0.08, 0.92) if bact else Color(0.12, 0.06, 0.08, 0.9)
				lc = Color.WHITE if bact else Color(1, 0.62, 0.55)
			elif b == 2:
				if dirty:
					fill = Color(0.1, 0.36, 0.22, 0.96) if bact else Color(0.06, 0.24, 0.15, 0.92).lerp(Color(0.1, 0.4, 0.25, 0.95), pulse * 0.5)
					lc = Color.WHITE if bact else UIKit.GREEN
				else:
					lc = Color(1, 1, 1, 0.35)
			elif bact:
				fill = Color(0.2, 0.17, 0.05, 0.95)
			_panel(br, bact, fill)
			UIKit.text_in(self, labels[b], br, 28, lc, HORIZONTAL_ALIGNMENT_CENTER)
			_hit.append({"rect": br, "row": ROW_RESET, "col": b, "kind": "btn"})


# ------------------------------------------------------------------ halaman kontrol
class ControlsSheet extends Control:
	func _init() -> void:
		size = Vector2(1160, 440)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		UIInput.pad_changed.connect(func(_d: int, _c: bool) -> void: queue_redraw())

	func _key_name(code: int) -> String:
		return UIKit.key_label(code)

	## Lebar keycap: dipakai juga untuk menghitung tata letak kolom, jadi harus sama persis dengan yang digambar.
	func _cap_w(s: String, fs: int) -> float:
		return maxf(34.0, UIKit.text_w(s, fs) + (20.0 if fs >= 20 else 14.0))

	func _cap(pos: Vector2, s: String, fs: int = 22) -> float:
		var w: float = _cap_w(s, fs)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.93, 0.93, 0.97)
		sb.set_corner_radius_all(7)
		sb.border_color = Color(0.5, 0.52, 0.68)
		sb.border_width_bottom = 4
		draw_style_box(sb, Rect2(pos, Vector2(w, 38)))
		UIKit.text_in(self, s, Rect2(pos.x, pos.y - 2, w, 38), fs, UIKit.INK)
		return w

	func _draw() -> void:
		# ---- panel keyboard
		var pw := 640.0
		draw_colored_polygon(UIKit.slanted(pw, 420, 20, 0, 0), Color(0.05, 0.05, 0.12, 0.88))
		draw_polyline(UIKit.closed(UIKit.slanted(pw, 420, 20, 0, 0)), Color(1, 1, 1, 0.18), 2.0, true)
		UIKit.text_in(self, "KEYBOARD", Rect2(40, 8, 300, 50), 34, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		var heads := ["MOVE", "JUMP", "DROP", "SHOOT", "KNIFE"]
		# nama tombol tiap pemain; kolom dihitung dari keycap terlebar supaya tombol TIDAK PERNAH saling tumpang tindih
		var names: Array = []
		for i in 4:
			var kb: Dictionary = Global.key_bindings[i]
			names.append([_key_name(int(kb["left"])), _key_name(int(kb["right"])), _key_name(int(kb["up"])),
				_key_name(int(kb["down"])), _key_name(int(kb["shoot"])), _key_name(int(kb["swap"]))])
		var x0: float = 130.0
		var avail: float = pw - x0 - 34.0       # sisa lebar di panel (sisi kanan miring)
		var col_gap: float = 14.0
		var fs: int = 22
		var col_w: Array[float] = []
		while true:
			col_w = []
			for k in 5:
				var mw: float = UIKit.text_w(heads[k], 18)    # kolom tidak boleh lebih sempit dari judulnya
				for i in 4:
					var nm: Array = names[i]
					var w: float = _cap_w(nm[0], fs) + 6.0 + _cap_w(nm[1], fs) if k == 0 else _cap_w(nm[k + 1], fs)
					mw = maxf(mw, w)
				col_w.append(mw)
			var total: float = col_gap * 4.0
			for cw in col_w:
				total += cw
			if total <= avail or fs <= 12:
				break
			fs -= 1                                     # terlalu lebar: kecilkan huruf sampai muat
		var hx: Array[float] = []
		var cx0: float = x0
		for k in 5:
			hx.append(cx0)
			cx0 += col_w[k] + col_gap
		for k in 5:
			UIKit.text_in(self, heads[k], Rect2(hx[k], 52, col_w[k] + col_gap, 26), 18, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
		for i in 4:
			var y: float = 86.0 + i * 82.0
			var pts := UIKit.slanted(98, 50, 10, 34, y)
			draw_colored_polygon(pts, Global.PLAYER_COLORS[i])
			draw_polyline(UIKit.closed(pts), Color.BLACK, 2.0, true)
			UIKit.text_in(self, "P%d" % (i + 1), Rect2(34, y, 98, 50), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 5)
			var nm: Array = names[i]
			var x: float = hx[0]
			x += _cap(Vector2(x, y + 6), nm[0], fs) + 6.0
			_cap(Vector2(x, y + 6), nm[1], fs)
			for k in range(1, 5):
				_cap(Vector2(hx[k], y + 6), nm[k + 1], fs)

		# ---- panel controller
		var ox := 668.0
		var ow := 492.0
		draw_colored_polygon(UIKit.slanted(ow, 420, 20, ox, 0), Color(0.05, 0.05, 0.12, 0.88))
		draw_polyline(UIKit.closed(UIKit.slanted(ow, 420, 20, ox, 0)), Color(1, 1, 1, 0.18), 2.0, true)
		UIKit.text_in(self, "CONTROLLER", Rect2(ox + 40, 8, 300, 50), 34, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
		var pb: Dictionary = Global.pad_bindings[0]
		var st: String = UIInput.pad_style()
		var rows := [
			["MOVE", "STICK / %s %s" % [Global.pad_button_name(int(pb["left"]), st), Global.pad_button_name(int(pb["right"]), st)]],
			["JUMP", "STICK UP / %s" % Global.pad_button_name(int(pb["up"]), st)],
			["DROP", "STICK DOWN / %s" % Global.pad_button_name(int(pb["down"]), st)],
			["SHOOT", Global.pad_button_name(int(pb["shoot"]), st)],
			["KNIFE", Global.pad_button_name(int(pb["swap"]), st)],
			["PAUSE", "OPTIONS (START)"],
		]
		for r in rows.size():
			var y: float = 62.0 + r * 42.0
			UIKit.text_in(self, rows[r][0], Rect2(ox + 44, y, 110, 40), 26, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
			UIKit.text_in(self, rows[r][1], Rect2(ox + 168, y, 320, 40), 21, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
		UIKit.text_in(self, "SHOWING P1 BUTTONS", Rect2(ox + 44, 318, 400, 24), 16, Color(1, 1, 1, 0.4), HORIZONTAL_ALIGNMENT_LEFT)
		# perangkat tiap pemain (sesuai CONTROLS SETUP)
		UIKit.text_in(self, "INPUT", Rect2(ox + 44, 344, 200, 28), 20, Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_LEFT)
		for i in 4:
			var cx: float = ox + 62 + i * 110
			if Global.uses_pad(i):
				UIKit.draw_pad_icon(self, Vector2(cx, 392), 30.0, Global.PLAYER_COLORS[i])
			else:
				UIKit.draw_keys_icon(self, Vector2(cx, 392), 30.0, Color(Global.PLAYER_COLORS[i], 0.8))
			UIKit.text_in(self, "P%d" % (i + 1), Rect2(cx + 24, 374, 60, 36), 22, Global.PLAYER_COLORS[i], HORIZONTAL_ALIGNMENT_LEFT, 4)


# ================================================================== posters hiasan
func _build_posters() -> void:
	posters_root = Control.new()
	posters_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	posters_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(posters_root)
	var ys := [150, 236, 168, 252]
	var rots := [-7.0, 4.0, -3.5, 6.0]
	for i in 4:
		var holder := Control.new()
		holder.position = Vector2(692 + i * 140, ys[i])
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		posters_root.add_child(holder)
		var ci: int = rng.randi_range(0, 3)
		var p := UIKit.Poster.new(Global.character_texture(i, i * 4 + ci), Global.PLAYER_COLORS[i], "P%d" % (i + 1), Vector2(156, 232))
		p.rotation = deg_to_rad(rots[i])
		holder.add_child(p)
		var gun := TextureRect.new()
		gun.texture = Global.weapon_texture(i, "pistol")
		gun.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		gun.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gun.size = Vector2(88, 62)
		gun.position = Vector2(62, 100)
		gun.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(gun)
		holder.set_meta("poster", p)
		holder.set_meta("rot", rots[i])


func _play_intro() -> void:
	# logo "membanting" masuk
	logo.modulate.a = 0.0
	logo.scale = Vector2.ONE * 2.4
	var t := UIKit.tw(logo)
	t.set_parallel(true)
	t.tween_property(logo, "modulate:a", 1.0, 0.25)
	t.tween_property(logo, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_callback(func() -> void:
		UIKit.ring(self, logo.position + logo.size * 0.5, UIKit.GOLD, 260.0, 0.6)
		Global.play_sfx("hit", -6.0))

	# poster meluncur dari kanan
	var i := 0
	for holder in posters_root.get_children():
		var p: UIKit.Poster = holder.get_meta("poster")
		var target_x: float = holder.position.x
		holder.position.x += 520.0
		holder.modulate.a = 0.0
		var delay: float = 0.35 + i * 0.1
		var tt := UIKit.tw(holder)
		tt.set_parallel(true)
		tt.tween_property(holder, "position:x", target_x, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		tt.tween_property(holder, "modulate:a", 1.0, 0.25).set_delay(delay)
		# idle: melayang naik-turun
		var bob := UIKit.tw(p)
		bob.set_loops()
		bob.tween_property(p, "position:y", -9.0, 1.1 + i * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(p, "position:y", 0.0, 1.1 + i * 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		i += 1


# ================================================================== navigasi
func _show_screen(name_id: String, instant: bool = false) -> void:
	var old_name: String = current
	var is_sub: bool = name_id != "main"
	if old_name != "" and screens.has(old_name):
		var oc: Control = screens[old_name]
		if instant:
			oc.visible = false
		else:
			var to := UIKit.tw(oc)
			to.set_parallel(true)
			to.tween_property(oc, "modulate:a", 0.0, 0.16)
			to.tween_property(oc, "position:x", -70.0, 0.16).set_trans(Tween.TRANS_QUAD)
			to.chain().tween_callback(func() -> void:
				if current != old_name:
					oc.visible = false)
	current = name_id
	if name_id == "controls":
		screens["controls"].get_meta("sheet").queue_redraw()   # tampilkan keybind terbaru
	var nc: Control = screens[name_id]
	nc.visible = true
	nc.modulate.a = 0.0
	nc.position.x = 0.0
	var ti := UIKit.tw(nc)
	ti.tween_property(nc, "modulate:a", 1.0, 0.2)

	# item masuk satu per satu
	var list: Array = items[name_id]
	for k in list.size():
		var it: Control = list[k]
		var base: Vector2 = it.position
		if not it.has_meta("base"):
			it.set_meta("base", base)
		base = it.get_meta("base")
		it.position = base + Vector2(-80, 0)
		it.modulate.a = 0.0
		var delay: float = 0.04 * k + (0.75 if instant else 0.0)
		var ts := UIKit.tw(it)
		ts.set_parallel(true)
		ts.tween_property(it, "position", base, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		ts.tween_property(it, "modulate:a", 1.0, 0.2).set_delay(delay)
	_select(name_id, int(idx[name_id]) if name_id != "players" else 0, false)

	# logo & poster menyesuaikan
	var lt := UIKit.tw(logo)
	lt.set_parallel(true)
	lt.tween_property(logo, "position", SUB_LOGO_POS if is_sub else MAIN_LOGO_POS, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var target_scale: Vector2 = Vector2.ONE * (0.4 if is_sub else 1.0)
	if not instant:
		lt.tween_property(logo, "scale", target_scale, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var pt := UIKit.tw(posters_root)
	pt.set_parallel(true)
	pt.tween_property(posters_root, "modulate:a", 0.0 if is_sub else 1.0, 0.3)
	pt.tween_property(posters_root, "position:x", 140.0 if is_sub else 0.0, 0.35).set_trans(Tween.TRANS_QUART)
	if name_id == "settings" or name_id == "binds":
		_refresh_save_state()
	_update_prompts()


func _update_prompts() -> void:
	match current:
		"main":
			prompt.set_prompts([[&"dpad_ud", "NAVIGATE"], [&"accept", "SELECT"]])
		"players":
			prompt.set_prompts([[&"dpad_lr", "CHOOSE"], [&"accept", "CONFIRM"], [&"back", "BACK"]])
		"settings":
			prompt.set_prompts([[&"dpad_ud", "NAVIGATE"], [&"dpad_lr", "ADJUST"], [&"accept", "SELECT"], [&"extra", "SAVE"], [&"back", "BACK"]])
		"binds":
			if binds != null and binds.capturing:
				prompt.set_prompts([[&"back", "CANCEL", {"force": "key"}]])
			else:
				prompt.set_prompts([[&"dpad_ud", "NAVIGATE"], [&"dpad_lr", "CHANGE"], [&"accept", "REBIND"], [&"extra", "DEFAULT"], [&"back", "BACK"]])
		"controls":
			prompt.set_prompts([[&"back", "BACK"]])


func _select(name_id: String, i: int, sound: bool = true) -> void:
	var list: Array = items[name_id]
	if list.is_empty():
		return
	i = clampi(i, 0, list.size() - 1)
	var changed: bool = i != int(idx[name_id])
	for k in list.size():
		list[k].set_selected(k == i)
	idx[name_id] = i
	if sound and changed:
		Global.play_sfx("ui_hover", -8.0)


func _hover(name_id: String, i: int) -> void:
	if name_id == current and not leaving:
		if name_id == "main" and dock_idx >= 0:
			_dock_set(-1, false)
		_select(name_id, i)


## Fokus dock: -1 = kembali ke daftar menu. Navigasi: KANAN dari daftar menu masuk ke dock, KIRI/ATAS/BAWAH keluar.
func _dock_set(i: int, sound: bool = true) -> void:
	dock_idx = i
	for k in dock.size():
		(dock[k] as CosmeticUI.DockButton).set_selected(k == i)
	var list: Array = items["main"]
	for k in list.size():
		list[k].set_selected(i < 0 and k == int(idx["main"]))
	if sound:
		Global.play_sfx("ui_hover", -8.0)


func _dock_hover(k: int) -> void:
	if current == "main" and not leaving and dock_idx != k:
		_dock_set(k)


func _dock_open(k: int) -> void:
	if leaving or current != "main":
		return
	leaving = true
	Global.goto("shop" if k == 0 else "inventory")


## Mengembalikan true kalau input sudah dipakai oleh dock.
func _dock_input(action: StringName) -> bool:
	match action:
		&"right":
			if dock_idx < 0:
				_dock_set(0)
			elif dock_idx == 0:
				_dock_set(1)
			return true
		&"left":
			if dock_idx == 1:
				_dock_set(0)
				return true
			if dock_idx == 0:
				_dock_set(-1)
				return true
		&"up", &"down":
			if dock_idx >= 0:
				_dock_set(-1)
				return true
		&"accept":
			if dock_idx >= 0:
				(dock[dock_idx] as CosmeticUI.DockButton).press()
				return true
	return false


func _move(dir: int) -> void:
	var list: Array = items[current]
	if list.is_empty():
		return
	if current == "settings":
		_select(current, _settings_step(int(idx[current]), dir))
		return
	_select(current, posmod(int(idx[current]) + dir, list.size()))


## Urutan fokus di layar SETTINGS: baris 0-6 -> CONTROLS SETUP -> SAVE (BACK sebaris dengan SAVE, pindah pakai kiri/kanan).
func _settings_step(i: int, dir: int) -> int:
	if dir > 0:
		if i < SET_SETUP:
			return i + 1
		if i == SET_SETUP:
			return SET_SAVE
		return 0
	if i == 0:
		return SET_SAVE
	if i == SET_SAVE or i == SET_BACK:
		return SET_SETUP
	return i - 1


func _activate() -> void:
	var list: Array = items[current]
	if list.is_empty():
		_go_back()
		return
	var it: Control = list[int(idx[current])]
	if it is UIKit.FancyButton:
		(it as UIKit.FancyButton).press()
	elif it is CountCard:
		(it as CountCard).press()
	elif it is UIKit.SettingRow:
		var row := it as UIKit.SettingRow
		if row.kind == "toggle" or row.kind == "choice":
			row.adjust(1)


func _go_back() -> void:
	if current == "main":
		return
	if current == "binds":
		Global.play_sfx("ui_back", -5.0)
		_show_screen("settings")      # CONTROLS SETUP ada di dalam SETTINGS; draf perubahan tetap dibawa
		return
	if current == "settings":
		if Global.has_unsaved():
			# BACK pertama = peringatan, BACK kedua (dalam 3 detik) = buang perubahan
			if Time.get_ticks_msec() > _discard_until:
				_discard_until = Time.get_ticks_msec() + 3000
				Global.play_sfx("ui_error", -8.0)
				UIInput.toast("UNSAVED CHANGES", "Press SAVE, or BACK again to discard", UIKit.GOLD)
				return
			Global.revert_edit()
			UIInput.toast("CHANGES DISCARDED", "Settings were not saved", Color("ff7a7a"))
		Global.end_edit()
	Global.play_sfx("ui_back", -5.0)
	_show_screen("main")


func _on_input(_source: int, action: StringName) -> void:
	if leaving:
		return
	if current == "binds":
		binds.handle(action)     # editor kontrol punya navigasi sendiri
		return
	if current == "main" and _dock_input(action):
		return
	match action:
		&"up":
			if current != "players":
				_move(-1)
		&"down":
			if current != "players":
				_move(1)
		&"left":
			if current == "players":
				_move(-1)
			elif current == "settings":
				_adjust(-1)
		&"right":
			if current == "players":
				_move(1)
			elif current == "settings":
				_adjust(1)
		&"accept":
			_activate()
		&"extra":
			if current == "settings":
				_save_changes()
		&"back":
			_go_back()
		&"start":
			if current == "main":
				_select("main", 0)
				_activate()


func _adjust(dir: int) -> void:
	var i: int = int(idx[current])
	if current == "settings" and (i == SET_SAVE or i == SET_BACK):
		_select(current, SET_BACK if dir > 0 else SET_SAVE)    # SAVE <-> BACK
		return
	var it: Control = items[current][i]
	if it is UIKit.SettingRow:
		(it as UIKit.SettingRow).adjust(dir)


func _on_main_activated(i: int) -> void:
	match i:
		0:
			# CAMPAIGN (single player): pertama kali pilih fighter dulu; setelah itu langsung ke peta level
			# (fighter & senjata bisa diganti lewat tombol CHANGE FIGHTER di peta level)
			leaving = true
			Global.campaign_mode = true
			Global.player_count = 1
			var saved: Dictionary = CampaignData.saved_fighter()
			if saved.is_empty():
				Global.selections = []
				Global.assign_devices()
				Global.goto("select")
			else:
				Global.selections = [saved]
				Global.assign_devices()
				Global.goto("campaign_hub")
		1:
			Global.campaign_mode = false
			_show_screen("players")
		2:
			_show_screen("controls")
		3:
			Global.begin_edit()           # mulai draf: perubahan baru tersimpan setelah SAVE
			_sync_setting_rows()
			idx["settings"] = 0
			_show_screen("settings")
		4:
			leaving = true
			get_tree().quit()


func _on_pick_players(n: int) -> void:
	if leaving:
		return
	leaving = true
	Global.campaign_mode = false
	Global.player_count = n
	Global.selections = []
	Global.assign_devices()
	Global.goto("select")


func _on_pad_changed(_device: int, _connected: bool) -> void:
	if screens.has("controls"):
		screens["controls"].get_meta("sheet").queue_redraw()
