extends Node
## Autoload "UIInput": satu pintu input untuk SEMUA UI (menu, select, pause).
##
## - Semua controller yang terhubung (hot-plug) ikut menggerakkan UI.
## - Setiap tekanan dipancarkan sebagai sinyal `pressed(source, action)`.
##     source >= 0  : id joypad (device)
##     source <= -1 : keyboard layout ke-(-1 - source)  (-1 = keybind P1, -2 = keybind P2, dst.)
##     GENERIC_SOURCE : tombol keyboard umum (panah, Enter, Esc, ...) yang tidak terikat ke pemain mana pun
## - Keybind keyboard diambil dari Global.key_bindings (bisa diganti pemain di Settings).
## - Mode tangkap (begin_capture) dipakai layar CONTROLS SETUP untuk menangkap tombol baru.
## - action: left, right, up, down, accept, back, start, alt, extra, prev, next, fire
##   fire = tombol TEMBAK milik pemain (sesuai keybind / tombol controller pemain itu). Dipakai untuk READY di layar pilih karakter.
##   Semua pemain (P1-P4, keyboard maupun controller) bisa memakai tombol TEMBAK-nya untuk memilih (accept)
##   dan tombol SWITCH / KNIFE-nya untuk membatalkan (back). Ikut berubah kalau keybind diganti di Settings.
## - Stick kiri & D-pad punya auto-repeat seperti menu konsol.
## - Menyimpan jenis input terakhir (keyboard / controller) supaya glyph tombol
##   di layar otomatis berganti (PlayStation ✕ ○ □ △ atau Xbox A B X Y).

signal pressed(source: int, action: StringName)
signal kind_changed(kind: String)
signal pad_changed(device: int, connected: bool)
signal captured(code: int, device: int)     # tombol baru tertangkap (device = -1 untuk keyboard)
signal capture_cancelled

const GENERIC_SOURCE := -100
const CAPTURE_TIMEOUT := 8.0

const DEADZONE := 0.55
const REPEAT_FIRST := 0.38
const REPEAT_NEXT := 0.11

var kind: String = "key"          # "key" | "pad"
var last_pad: int = -1
var capture_mode: String = ""     # "" (tidak menangkap) | "key" | "pad"

var _capture_time: float = 0.0
var _block_until: int = 0         # sesaat setelah menangkap, input UI diabaikan (cegah echo tombol)

var _pad_state := {}              # device -> {"dir": Vector2i, "t": float}
var _trig_down := {}              # "device:axis" -> true kalau trigger analog sedang ditekan (untuk deteksi tekan baru)
var _toast_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_on_joy_changed)
	_build_toast_layer()


# ------------------------------------------------------------------ info controller
## Daftar device controller yang sedang terhubung (urut).
func pads() -> Array[int]:
	var res: Array[int] = []
	for d in Input.get_connected_joypads():
		res.append(int(d))
	res.sort()
	return res


func pad_number(device: int) -> int:
	return pads().find(device) + 1


## "ps" atau "xbox" (default: ps) berdasarkan nama controller.
func pad_style(device: int = -2) -> String:
	if device == -2:
		device = last_pad
	if device < 0:
		return "ps"
	var n: String = Input.get_joy_name(device).to_lower()
	if n.contains("xbox") or n.contains("x-box") or n.contains("xinput"):
		return "xbox"
	return "ps"


func pad_name(device: int) -> String:
	var n: String = Input.get_joy_name(device)
	if n.length() > 22:
		n = n.substr(0, 22) + "…"
	return n


func key_source(layout: int) -> int:
	return -1 - layout


func is_key_source(source: int) -> bool:
	return source < 0


func layout_of(source: int) -> int:
	return -1 - source


func is_generic(source: int) -> bool:
	return source == GENERIC_SOURCE


# ------------------------------------------------------------------ mode tangkap tombol
func begin_capture(mode: String) -> void:
	capture_mode = mode
	_capture_time = CAPTURE_TIMEOUT


func end_capture() -> void:
	if capture_mode == "":
		return
	capture_mode = ""
	_block_until = Time.get_ticks_msec() + 300


func cancel_capture() -> void:
	if capture_mode == "":
		return
	end_capture()
	capture_cancelled.emit()


func _finish_capture(code: int, device: int) -> void:
	end_capture()
	captured.emit(code, device)


func _capture_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return
		get_viewport().set_input_as_handled()
		var code: int = event.physical_keycode
		if code == KEY_NONE:
			code = event.keycode
		if code == KEY_ESCAPE:
			cancel_capture()
		elif capture_mode == "key" and code != KEY_NONE:
			_finish_capture(code, -1)
	elif event is InputEventMouseButton:
		if event.pressed:
			cancel_capture()
	elif capture_mode == "pad":
		if event is InputEventJoypadButton and event.pressed:
			get_viewport().set_input_as_handled()
			_finish_capture(event.button_index, event.device)
		elif event is InputEventJoypadMotion and event.axis_value > 0.7:
			if event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT:
				get_viewport().set_input_as_handled()
				_finish_capture(Global.PAD_AXIS_BASE + event.axis, event.device)


# ------------------------------------------------------------------ event
func _set_kind(k: String, device: int = -1) -> void:
	if device >= 0:
		last_pad = device
	if k != kind:
		kind = k
		kind_changed.emit(k)


func _emit(source: int, action: StringName) -> void:
	if capture_mode != "" or Time.get_ticks_msec() < _block_until:
		return
	pressed.emit(source, action)


func _input(event: InputEvent) -> void:
	if capture_mode != "":
		_capture_input(event)
		return
	if event is InputEventJoypadButton:
		if not event.pressed:
			return
		_set_kind("pad", event.device)
		var act := StringName()
		match event.button_index:
			JOY_BUTTON_A: act = &"accept"
			JOY_BUTTON_B: act = &"back"
			JOY_BUTTON_X: act = &"alt"
			JOY_BUTTON_Y: act = &"extra"
			JOY_BUTTON_START: act = &"start"
			JOY_BUTTON_LEFT_SHOULDER: act = &"prev"
			JOY_BUTTON_RIGHT_SHOULDER: act = &"next"
		if act != StringName():
			_emit(event.device, act)
		# tombol tembak pemain pemilik controller ini -> aksi "accept" + "fire"
		# tombol switch / knife pemain ini -> "back" (kalau tombol itu belum punya fungsi menu lain: A/B/Y/dst tetap seperti biasa)
		var slot: int = Global.player_devices.find(event.device)
		if slot >= 0 and int(event.button_index) == int(Global.pad_bindings[slot]["shoot"]):
			if act == StringName():
				_emit(event.device, &"accept")
			_emit(event.device, &"fire")
		elif slot >= 0 and act == StringName() and int(event.button_index) == int(Global.pad_bindings[slot]["swap"]):
			_emit(event.device, &"back")
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > 0.6:
			_set_kind("pad", event.device)
		_check_trigger_fire(event)
	elif event is InputEventKey:
		if not event.pressed:
			return
		_handle_key(event)


## Kalau tombol tembak pemain adalah trigger analog (L2 / R2), pancarkan "fire" saat baru ditekan.
func _check_trigger_fire(event: InputEventJoypadMotion) -> void:
	if event.axis != JOY_AXIS_TRIGGER_LEFT and event.axis != JOY_AXIS_TRIGGER_RIGHT:
		return
	var key: String = "%d:%d" % [event.device, event.axis]
	if event.axis_value < 0.3:
		_trig_down.erase(key)
		return
	if event.axis_value < 0.6 or _trig_down.has(key):
		return
	_trig_down[key] = true
	var slot: int = Global.player_devices.find(event.device)
	if slot >= 0 and int(Global.pad_bindings[slot]["shoot"]) == Global.PAD_AXIS_BASE + int(event.axis):
		_set_kind("pad", event.device)
		_emit(event.device, &"accept")
		_emit(event.device, &"fire")
	elif slot >= 0 and int(Global.pad_bindings[slot]["swap"]) == Global.PAD_AXIS_BASE + int(event.axis):
		_set_kind("pad", event.device)
		_emit(event.device, &"back")


func _handle_key(event: InputEventKey) -> void:
	var code: int = event.physical_keycode
	var nav_acts := [&"left", &"right", &"up", &"down"]
	var nav_keys := ["left", "right", "up", "down"]

	# --- 1) keybind tiap pemain (Global.key_bindings): navigasi + tombol tembak = accept.
	#        Boleh echo agar menahan tombol = repeat.
	for k in 4:
		var km: Dictionary = Global.key_bindings[k]
		for j in 4:
			if code == int(km[nav_keys[j]]):
				_set_kind("key")
				_emit(key_source(k), nav_acts[j])
				return
		if event.echo:
			continue
		if code == int(km["shoot"]):
			_set_kind("key")
			_emit(key_source(k), &"accept")
			_emit(key_source(k), &"fire")
			return
		# tombol SWITCH / KNIFE milik pemain = batal / kembali (mengikuti keybind pemain itu)
		if code == int(km["swap"]):
			_set_kind("key")
			_emit(key_source(k), &"back")
			return

	# --- 2) tombol tetap (tidak bisa diganti) supaya menu selalu bisa dipakai walau keybind diubah
	var gen_nav := StringName()
	match code:
		KEY_LEFT: gen_nav = &"left"
		KEY_RIGHT: gen_nav = &"right"
		KEY_UP: gen_nav = &"up"
		KEY_DOWN: gen_nav = &"down"
	if gen_nav != StringName():
		_set_kind("key")
		_emit(GENERIC_SOURCE, gen_nav)
		return

	if event.echo:
		return
	var act := StringName()
	match code:
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: act = &"accept"
		KEY_ESCAPE, KEY_BACKSPACE: act = &"back"
		KEY_TAB: act = &"extra"
		KEY_Q: act = &"prev"
		KEY_E: act = &"next"
	if act != StringName():
		_set_kind("key")
		_emit(GENERIC_SOURCE, act)


func _process(delta: float) -> void:
	if capture_mode != "":
		_capture_time -= delta
		if _capture_time <= 0.0:
			cancel_capture()
		return
	for d in pads():
		_poll_pad(d, delta)


func _poll_pad(d: int, delta: float) -> void:
	var v := Vector2i.ZERO
	var ax: float = Input.get_joy_axis(d, JOY_AXIS_LEFT_X)
	var ay: float = Input.get_joy_axis(d, JOY_AXIS_LEFT_Y)
	if absf(ax) > DEADZONE and absf(ax) >= absf(ay):
		v.x = 1 if ax > 0.0 else -1
	elif absf(ay) > DEADZONE:
		v.y = 1 if ay > 0.0 else -1
	if Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_LEFT):
		v = Vector2i(-1, 0)
	elif Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_RIGHT):
		v = Vector2i(1, 0)
	elif Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP):
		v = Vector2i(0, -1)
	elif Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN):
		v = Vector2i(0, 1)

	var st: Dictionary = _pad_state.get(d, {"dir": Vector2i.ZERO, "t": 0.0})
	var prev: Vector2i = st["dir"]
	var fire := false
	if v != prev:
		st["dir"] = v
		st["t"] = REPEAT_FIRST
		fire = v != Vector2i.ZERO
	elif v != Vector2i.ZERO:
		st["t"] = float(st["t"]) - delta
		if float(st["t"]) <= 0.0:
			st["t"] = REPEAT_NEXT
			fire = true
	_pad_state[d] = st
	if fire:
		_set_kind("pad", d)
		var act := &"right"
		if v.x < 0: act = &"left"
		elif v.y < 0: act = &"up"
		elif v.y > 0: act = &"down"
		_emit(d, act)


func _on_joy_changed(device: int, connected: bool) -> void:
	_pad_state.erase(device)
	if connected:
		toast("CONTROLLER CONNECTED", pad_name(device), Color("4be3a0"))
	else:
		toast("CONTROLLER DISCONNECTED", "Device %d" % device, Color("ff5a5a"))
	pad_changed.emit(device, connected)
	if connected:
		_set_kind("pad", device)


# ------------------------------------------------------------------ getar
func rumble(device: int, weak: float, strong: float, duration: float) -> void:
	if device < 0 or not Global.vibration:
		return
	Input.start_joy_vibration(device, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)


# ------------------------------------------------------------------ toast
func _build_toast_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_toast_box.offset_right = -18
	_toast_box.offset_top = 16
	_toast_box.add_theme_constant_override("separation", 8)
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_toast_box)


## Notifikasi kecil di pojok kanan atas (seperti notifikasi PlayStation).
func toast(title: String, subtitle: String = "", color: Color = Color("ffd23f")) -> void:
	if _toast_box == null:
		return
	# notifikasi yang sama tidak ditumpuk: yang lama diganti oleh yang baru (timer-nya mulai ulang)
	var key: String = title + "|" + subtitle
	for old in _toast_box.get_children():
		if old.has_meta("toast_key") and String(old.get_meta("toast_key")) == key:
			_toast_box.remove_child(old)
			old.queue_free()
	var holder := Control.new()
	holder.set_meta("toast_key", key)
	holder.custom_minimum_size = Vector2(340, 64)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_box.add_child(holder)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", Global.make_box(Color(0.05, 0.05, 0.12, 0.94), color, 3, 12, 12))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(col)
	col.add_child(Global.make_label(title, 22, color, 4))
	if subtitle != "":
		col.add_child(Global.make_label(subtitle, 16, Color(1, 1, 1, 0.75), 3))

	panel.pivot_offset = Vector2(340, 32)
	panel.position.x = 380.0
	panel.modulate.a = 0.0
	var t := UIKit.tw(holder)
	t.set_parallel(true)
	t.tween_property(panel, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(panel, "modulate:a", 1.0, 0.2)
	t.chain().tween_interval(2.6)
	t.chain().tween_property(panel, "modulate:a", 0.0, 0.35)
	t.chain().tween_callback(holder.queue_free)
	Global.play_sfx("ui_panel", -8.0)
