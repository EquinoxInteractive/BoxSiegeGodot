class_name ReplayView
extends Control
## Pemutar replay bergaya video. Dipakai oleh layar REPLAY (replay.gd).
##   - Dunia digambar ulang oleh ReplayWorld (arena, pemain, peluru, power up, rintangan).
##   - Overlay (class Overlay) menggambar HUD, progress bar, tombol, tooltip, dll. Semua lewat satu Control
##     dengan daftar "hit rect" sendiri (immediate-mode), jadi mouse, keyboard, dan controller memakai logika yang sama.
##
## Kontrol:
##   ENTER / SPASI / A       putar - jeda          K
##   KIRI / KANAN            mundur / maju (lama lompat diatur di Replay Settings)     J / L
##   ATAS / BAWAH            kecepatan lebih cepat / lebih lambat
##   Q / E (L1 / R1)         kill sebelumnya / berikutnya
##   TAB (Y)                 tampilkan / sembunyikan kartu pemain
##   X (controller)          mulai ronde berikutnya
##   , / .                   mundur / maju satu snapshot (saat jeda)
##   HOME / END              ke awal / akhir
##   H                       bantuan
##   ESC / B                 menu jeda (panel animasi: RESUME / RESTART / pengaturan cepat / keluar)
##   Mouse: klik video = putar/jeda, klik atau seret progress bar, klik tanda kill = loncat ke kill itu.

signal closed
signal main_menu_requested          # dipilih MAIN MENU di menu jeda: replay.gd menutup pemutar lalu pindah ke menu utama

## HUD asli game (kartu pemain, timer, banner ROUND / FIGHT) dipakai ulang supaya replay tampil sama persis dengan gameplay.
const GameScript = preload("res://scripts/game.gd")

const BAR_X := 40.0
const BAR_W := 1200.0
const TRACK_Y := 636.0
const MARK_ROWS: Array = [614.0, 590.0, 566.0]
const ROUND_Y := 654.0
const CTRL_Y := 694.0
const BTN_H := 44.0
const MARK_W := 30.0

var world: ReplayWorld
var overlay: Overlay
var meta: Dictionary = {}
var data: Dictionary = {}
var events: Array = []
var rounds: Array = []
var plist: Array = []
var ev_row: Array = []
var round_final: Array = []
var duration: float = 1.0
var hz: int = 30
var wins_to_match: int = 3
var match_time_setting: int = 90

var t: float = 0.0
var playing: bool = true
var speed_idx: int = 3
var ended: bool = false
var end_focus: int = 0
var dragging: bool = false
var resume_after_drag: bool = false
var dirty: bool = true
var show_hud: bool = true
var show_help: bool = false
var exit_menu: bool = false            # menu jeda (muncul saat pemain menekan keluar: ESC / B / tombol X)
var menu_idx: int = 0
var _resume_after_menu: bool = false
var ui_lock: bool = false              # true saat animasi masuk / keluar berjalan: input ditahan, bar kontrol & ikon jeda disembunyikan
var start_hint: bool = false            # true = replay baru dibuka dalam keadaan jeda: tampilkan petunjuk "REPLAY PAUSED" sampai pemain memutar / menggeser
var hint_a: float = 0.0                # animasi muncul / hilang petunjuk jeda (0..1)
var ui_hidden: bool = false            # true = bar kontrol, lencana REPLAY, kill feed & tips disembunyikan (tombol mata / tombol U)
var speed_menu: bool = false
var idle: float = 0.0
var ui_alpha: float = 1.0
var tip_time: float = 6.0
var toast_text: String = ""
var toast_t: float = 0.0
var toast_color: Color = Color.WHITE
var mouse: Vector2 = Vector2(-100, -100)
var hover_id: String = ""
## Navigasi controller: kotak pilihan (fokus) berpindah antar tombol dengan D-pad / stick, A (Xbox) / ✕ (PS) menekan tombol terpilih.
const FOCUS_ORDER: Array = ["play", "back", "fwd", "prevk", "nextk", "ui", "speed", "hud", "help", "exit"]
var pad_nav: bool = false              # true = input terakhir dari controller -> kotak fokus ditampilkan
var focus_id: String = "play"          # tombol terpilih ("seek" = progress bar)
var _last_btn_id: String = "play"      # tombol terakhir sebelum fokus naik ke progress bar
var pressed_id: String = ""          # tombol yang sedang ditekan mouse (efek tekan)
var _hits: Array = []
var _clock: float = 0.0
var _opened: bool = false

# --- HUD asli
var hud_root: Control
var huds: Array = []
var timer_hud
var banner
var round_match_end: Array = []        # ronde ke-i menentukan pemenang match (tanpa banner WINS, sama seperti game)
var sd_starts: Array = []              # waktu mulai SUDDEN DEATH tiap ronde (-1 = tidak ada)
var _banner_key: String = ""
var _snd_prev: float = 0.0             # waktu terakhir yang sudah diperiksa untuk suara pengumuman
var _snap_pending: bool = true

# --- panel animasi (Control biasa di atas overlay): menu jeda, bantuan, layar selesai
var pause_menu: ReplayUI.PauseMenu
var help_panel: ReplayUI.HelpPanel
var end_panel: ReplayUI.EndPanel
var _hv: Dictionary = {}               # id tombol -> nilai hover halus 0..1 (animasi sorot tombol di bar kontrol)
var speed_a: float = 0.0               # animasi buka / tutup menu kecepatan
var _tip_key: String = ""
var _tip_age: float = 0.0


# ================================================================== buka / tutup
## Memuat replay. Mengembalikan false kalau data rusak.
func open(replay_data: Dictionary, replay_meta: Dictionary) -> bool:
	data = replay_data
	meta = replay_meta
	# Ukuran eksplisit 1280x720 (bukan anchor). Kalau ukuran view 0, overlay tidak pernah menerima klik / gerak mouse.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2.ZERO
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	world = ReplayWorld.new()
	add_child(world)
	if not world.build(data):
		world.queue_free()
		world = null
		return false

	var header: Dictionary = data["header"]
	events = data.get("events", [])
	rounds = data.get("rounds", [])
	plist = header["players"]
	duration = maxf(world.duration, 0.1)
	hz = int(header.get("hz", 30))
	wins_to_match = int(header.get("wins_to_match", 3))
	match_time_setting = int(header.get("match_time", 90))
	speed_idx = ReplayStore.speed_idx
	show_hud = ReplayStore.show_hud
	playing = ReplayStore.autoplay
	_compute_rows()
	_compute_final_rounds()
	_compute_sd_starts()
	_build_hud()

	overlay = Overlay.new(self)
	add_child(overlay)
	_build_panels()
	_snd_prev = -0.0001

	if ReplayStore.play_music:
		Global.play_music("game")
	else:
		Global._music.stream_paused = true
	UIInput.pressed.connect(_on_ui)
	_opened = true
	world.apply(0.0, false)
	return true


func close() -> void:
	if not _opened:
		return
	_opened = false
	if UIInput.pressed.is_connected(_on_ui):
		UIInput.pressed.disconnect(_on_ui)
	Global._music.stream_paused = false
	Global.play_music("menu")
	closed.emit()


# ------------------------------------------------------------------ animasi masuk / keluar (dipanggil replay.gd)
## Siapkan keadaan awal sebelum tirai transisi terbuka: video sedikit membesar, kartu pemain & bar kontrol tersembunyi.
func intro_prepare() -> void:
	ui_lock = true
	ui_alpha = 0.0
	pivot_offset = Vector2(640.0, 360.0)
	scale = Vector2.ONE * 1.07
	if hud_root != null:
		hud_root.modulate.a = 0.0


## Dipanggil tepat saat tirai mulai terbuka: video mengecil ke ukuran normal (zoom-out halus), kartu pemain muncul,
## lalu bar kontrol memudar masuk dan input dibuka kembali.
func intro_play() -> void:
	var tw := UIKit.tw(self)
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE, 0.95).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if hud_root != null:
		tw.tween_property(hud_root, "modulate:a", 1.0, 0.4).set_delay(0.2)
	tw.tween_callback(func() -> void:
		ui_lock = false
		idle = 0.0
		tip_time = 6.0).set_delay(0.5)


## Animasi keluar: gambar membeku, kartu pemain memudar dan video sedikit membesar sementara tirai menutup.
func outro_play(dur: float = 0.4) -> void:
	ui_lock = true
	playing = false
	dragging = false
	pivot_offset = Vector2(640.0, 360.0)
	var tw := UIKit.tw(self)
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector2.ONE * 1.06, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if hud_root != null:
		tw.tween_property(hud_root, "modulate:a", 0.0, dur * 0.7)


func _exit_tree() -> void:
	if _opened:
		_opened = false
		if UIInput.pressed.is_connected(_on_ui):
			UIInput.pressed.disconnect(_on_ui)
		Global._music.stream_paused = false


# ================================================================== persiapan data
## Tentukan baris tanda kill supaya yang berdekatan tidak saling menimpa.
func _compute_rows() -> void:
	ev_row.clear()
	var last_x: Array = [-999.0, -999.0, -999.0]
	for e in events:
		var x: float = BAR_X + (float((e as Dictionary)["t"]) / duration) * BAR_W
		var row: int = 2
		for r in 3:
			if x - float(last_x[r]) >= MARK_W + 2.0:
				row = r
				break
		last_x[row] = x
		ev_row.append(row)


## Apakah ronde ke-i adalah FINAL ROUND (semua tim sudah punya kemenangan = target - 1).
func _compute_final_rounds() -> void:
	round_final.clear()
	round_match_end.clear()
	var team_wins: Dictionary = {}
	for r in rounds:
		var is_final: bool = not plist.is_empty()
		for p in plist:
			if int(team_wins.get(int((p as Dictionary)["team"]), 0)) < wins_to_match - 1:
				is_final = false
		round_final.append(is_final)
		var w: int = int((r as Dictionary)["winner"])
		var match_done: bool = false
		if w >= 0:
			team_wins[w] = int(team_wins.get(w, 0)) + 1
			match_done = int(team_wins[w]) >= wins_to_match
		round_match_end.append(match_done)


## Waktu mulai SUDDEN DEATH di tiap ronde (dibaca dari rekaman: header snapshot indeks 3).
func _compute_sd_starts() -> void:
	sd_starts.clear()
	for r in rounds:
		sd_starts.append(-1.0)
	for i in world.starts.size():
		if world.flat[world.starts[i] + 3] <= 0.5:
			continue
		var ti: float = world.times[i]
		var idx: int = -1
		for k in rounds.size():
			if float((rounds[k] as Dictionary)["start"]) <= ti + 0.001:
				idx = k
		if idx >= 0 and float(sd_starts[idx]) < 0.0:
			sd_starts[idx] = ti


## Membangun HUD asli game di atas dunia replay (di bawah overlay kontrol).
func _build_hud() -> void:
	# Ukuran diberi eksplisit 1280x720 (bukan anchor): induk ReplayView bisa berukuran 0 kalau scene replay bukan Control,
	# dan itu membuat banner (yang menghitung posisi dari size-nya) menempel di pojok kiri atas.
	hud_root = Control.new()
	hud_root.theme = Global.ui_theme
	hud_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud_root.position = Vector2.ZERO
	hud_root.size = Vector2(1280, 720)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud_root)

	timer_hud = GameScript.TimerHud.new()
	timer_hud.name = "TimerHud"
	timer_hud.wins_to_show = wins_to_match
	hud_root.add_child(timer_hud)

	var team_mode: bool = bool(world.header.get("team_mode", false))
	for i in plist.size():
		var pd: Dictionary = plist[i]
		var h = GameScript.PlayerHud.new(i, world.actors[i])
		h.wins_to_show = wins_to_match
		h.kills = 0
		h.silent = true
		if team_mode:
			h.team_id = int(pd["team"])
			h.team_level = int(pd.get("team_level", 0))
		# posisi sama persis dengan game.gd (_build_hud)
		match i:
			0, 2:
				h.position = Vector2(14, 12 + (i / 2) * 140)
			_:
				h.position = Vector2(1280 - 14 - h.size.x, 12 + (i / 2) * 140)
		hud_root.add_child(h)
		huds.append(h)

	banner = GameScript.BannerFx.new()
	banner.set_anchors_preset(Control.PRESET_TOP_LEFT)
	banner.position = Vector2.ZERO
	banner.size = Vector2(1280, 720)
	hud_root.add_child(banner)


## Perbarui HUD asli dari snapshot yang sedang ditampilkan.
func _update_hud() -> void:
	var rn: int = int(world.head(4))
	var sd: bool = world.head(3) > 0.5
	var left: float = world.head(2)
	var clock: String
	if sd:
		clock = "SD"
	elif match_time_setting == Global.TIME_INFINITE:
		clock = "INF"
	else:
		clock = Global.format_time(int(ceil(left)))
	var low: bool = sd or (clock != "INF" and left <= 10.0 and int(world.head(1)) == 1)
	timer_hud.set_state(clock, low, sd)
	timer_hud.sub_override = "ROUND %d" % rn
	for i in huds.size():
		var h = huds[i]
		var w: int = int(world.pl(i, ReplayRecorder.PL_WINS))
		if _snap_pending:
			h.snap(w)
		h.kills = int(world.pl(i, ReplayRecorder.PL_KILLS))
		h.silent = not world.sound_on
		h.visible = show_hud
		h.refresh(w)
	_snap_pending = false


## Banner besar ROUND / FINAL ROUND / FIGHT! / SUDDEN DEATH! / WINS! memakai BannerFx milik game (animasi sama).
func _update_banner() -> void:
	var text: String = ""
	var col: Color = Color.WHITE
	var fsize: int = 110
	var key: String = ""
	for i in rounds.size():
		var r: Dictionary = rounds[i]
		var rs: float = float(r["start"])
		var re: float = float(r["end"])
		var dt: float = t - rs
		var sds: float = float(sd_starts[i]) if i < sd_starts.size() else -1.0
		if dt >= 0.0 and dt < 1.8:
			if bool(round_final[i]):
				text = "FINAL ROUND"
				col = Color("ff4040")
			else:
				text = "ROUND %d" % int(r["num"])
				col = Color("ffd23f")
			key = "intro:%d" % i
		elif dt >= 1.8 and dt < 2.7:
			text = "FIGHT!"
			col = Color("ff4040")
			key = "fight:%d" % i
		if sds >= 0.0 and t >= sds:
			if t < sds + 1.8:
				text = "SUDDEN DEATH!"
				col = Color("ff4040")
				key = "sd:%d" % i
			elif t < sds + 2.7:
				text = "FIGHT!"
				col = Color("ff4040")
				key = "sdfight:%d" % i
		# menang match: tanpa banner (sama seperti game, langsung ke animasi kemenangan)
		if re >= 0.0 and t >= re and t < re + 2.6 and int(r["winner"]) != -2 and not bool(round_match_end[i]):
			if int(r["winner"]) >= 0:
				text = "%s WINS!" % String(r["winner_label"])
				col = r["winner_color"]
				fsize = 80
				key = "win:%d" % i
			else:
				text = "DRAW!"
				col = Color.WHITE
				key = "draw:%d" % i
	if key == _banner_key:
		return
	_banner_key = key
	if text == "":
		banner.clear()
	else:
		banner.show_text(text, col, fsize)


## Suara pengumuman (ROUND n / FINAL ROUND / FIGHT! / SUDDEN DEATH / pemenang ronde), persis seperti di game.
## Hanya dibunyikan saat waktu berjalan maju normal; loncat waktu / seret progress bar tidak berbunyi.
func _crossed(a: float, b: float, x: float) -> bool:
	return a < x and x <= b


func _announce_sounds(a: float, b: float) -> void:
	if b <= a or not ReplayStore.play_sfx or speed_value() > 2.0:
		return
	for i in rounds.size():
		var r: Dictionary = rounds[i]
		var rs: float = float(r["start"])
		var re: float = float(r["end"])
		if _crossed(a, b, rs):
			if bool(round_final[i]):
				Global.play_sfx("final_round")
			else:
				Global.play_round_sfx(int(r["num"]))
		if _crossed(a, b, rs + 1.8):
			Global.play_sfx("fight")
		var sds: float = float(sd_starts[i]) if i < sd_starts.size() else -1.0
		if sds >= 0.0:
			if _crossed(a, b, sds):
				Global.play_sfx("sudden_death")
				Global.play_sfx("alarm_sting", -8.0)
			if _crossed(a, b, sds + 1.8):
				Global.play_sfx("fight")
		if re >= 0.0 and _crossed(a, b, re) and int(r["winner"]) != -2 and not bool(round_match_end[i]):
			if int(r["winner"]) >= 0:
				Global.play_sfx("round_win", -3.0)
			else:
				Global.play_sfx("round_draw", -3.0)


func player_color(i: int) -> Color:
	if i < 0 or i >= plist.size():
		return Color(0.7, 0.7, 0.75)
	return (plist[i] as Dictionary)["color"]


func event_x(i: int) -> float:
	return BAR_X + (float((events[i] as Dictionary)["t"]) / duration) * BAR_W


func event_text(i: int) -> String:
	var e: Dictionary = events[i]
	var killer: int = int(e["killer"])
	var victim: int = int(e["victim"])
	if String(e["type"]) == "kill":
		return "P%d ELIMINATED P%d" % [killer + 1, victim + 1]
	return "P%d WAS ELIMINATED" % (victim + 1)


# ================================================================== waktu / seek
func speed_value() -> float:
	return float(ReplayStore.SPEED_VALUES[speed_idx])


func _process(delta: float) -> void:
	if world == null:
		return
	_clock += delta
	var spd: float = speed_value()
	var fx_ok: bool = false
	if playing and not dragging and not ended:
		var prev_t: float = _snd_prev
		t += delta * spd
		if t >= duration:
			t = duration
			playing = false
			ended = true
			end_focus = 0
		fx_ok = true
		_announce_sounds(prev_t, t)
		_snd_prev = t
		world.tick_visuals(delta * spd)
		dirty = true
	if dirty:
		world.sound_on = ReplayStore.play_sfx and spd <= 2.0 and fx_ok
		world.apply(t, fx_ok)
		for p in world.actors:
			p.fx.queue_redraw()
		_update_hud()
		_update_banner()
		dirty = false
	for h in huds:
		h.visible = show_hud          # tombol PLAYER CARDS bekerja juga saat video dijeda
	world.fx_root.process_mode = Node.PROCESS_MODE_INHERIT if (playing and not ended) else Node.PROCESS_MODE_DISABLED

	_sync_panels(delta)

	# petunjuk jeda awal: hilang selamanya begitu replay diputar / digeser
	if start_hint and (playing or ended or t > 0.05):
		start_hint = false
	# Banner "REPLAY PAUSED" menempati area tengah-bawah yang sama dengan toast (CONTROLS SHOWN, SPEED, dll), bar tip, dan
	# tooltip progress bar. Supaya teks tidak pernah bertumpuk, banner ini MENYINGKIR selama salah satunya tampil.
	var bar_tip_on: bool = hover_id == "seek" or hover_id.begins_with("mark:") or hover_id.begins_with("round:")
	var hint_t: float = 1.0 if (start_hint and not ui_lock and not exit_menu and not show_help and not dragging and toast_t <= 0.0 and not bar_tip_on) else 0.0
	hint_a = lerpf(hint_a, hint_t, 1.0 - exp(-delta * 9.0))
	if hint_t == 0.0 and hint_a < 0.01:
		hint_a = 0.0

	idle += delta
	var want: float = 1.0
	if ReplayStore.autohide_ui and playing and not ended and not show_help and not speed_menu and not dragging and idle > 2.5:
		want = 0.0
	if ui_hidden or ui_lock:
		want = 0.0
	ui_alpha = move_toward(ui_alpha, want, delta * 4.0)
	if not start_hint and hint_a < 0.01:
		tip_time = maxf(tip_time - delta, 0.0)      # bar tip menunggu sampai banner jeda hilang, baru hitung mundur 6 detik
	toast_t = maxf(toast_t - delta, 0.0)


func seek(to: float, announce: String = "") -> void:
	t = clampf(to, 0.0, duration)
	if ended and t < duration - 0.05:
		ended = false
	world.clear_fx()
	_snd_prev = t - 0.0001
	_snap_pending = true
	dirty = true
	if announce != "":
		_toast(announce, Color.WHITE)


func skip(sec: float) -> void:
	seek(t + sec, "%s%d SEC" % ["+" if sec > 0.0 else "-", int(absf(sec))])
	if sec > 0.0 and ended:
		ended = false


func toggle_play() -> void:
	if ended:
		_restart()
		return
	playing = not playing
	Global.play_sfx("ui_pause" if not playing else "ui_confirm", -8.0)
	_toast("PLAY" if playing else "PAUSED", Color.WHITE)


func _restart() -> void:
	ended = false
	playing = true
	seek(0.0)


func set_speed(i: int) -> void:
	var ni: int = clampi(i, 0, ReplayStore.SPEED_VALUES.size() - 1)
	if ni == speed_idx:
		return
	speed_idx = ni
	Global.play_sfx("ui_slider", -8.0, 0.8 + float(ni) * 0.06)
	_toast("SPEED  " + String(ReplayStore.SPEED_NAMES[ni]), UIKit.GOLD)


## dir = -1 / +1: pindah ke kill sebelumnya / berikutnya (mulai beberapa detik sebelum kill, sesuai pengaturan).
func jump_event(dir: int) -> void:
	if events.is_empty():
		_toast("NO KILLS IN THIS REPLAY", Color(1, 1, 1, 0.8))
		return
	var lead: float = ReplayStore.lead_seconds()
	var target: int = -1
	if dir > 0:
		for i in events.size():
			if float((events[i] as Dictionary)["t"]) - lead > t + 0.4:
				target = i
				break
	else:
		for i in range(events.size() - 1, -1, -1):
			if float((events[i] as Dictionary)["t"]) - lead < t - 0.9:
				target = i
				break
	if target < 0:
		_toast("NO MORE KILLS", Color(1, 1, 1, 0.8))
		return
	go_event(target)


func go_event(i: int) -> void:
	var e: Dictionary = events[i]
	seek(float(e["t"]) - ReplayStore.lead_seconds())
	playing = true
	ended = false
	_toast(event_text(i), player_color(int(e["killer"]) if int(e["killer"]) >= 0 else int(e["victim"])))
	Global.play_sfx("ui_confirm", -9.0)


func jump_round(dir: int) -> void:
	if rounds.is_empty():
		return
	var idx: int = 0
	for i in rounds.size():
		if float((rounds[i] as Dictionary)["start"]) <= t + 0.01:
			idx = i
	var ni: int = clampi(idx + dir, 0, rounds.size() - 1)
	if dir > 0 and ni == idx:
		return
	seek(float((rounds[ni] as Dictionary)["start"]), "ROUND %d" % int((rounds[ni] as Dictionary)["num"]))


func _toast(text: String, col: Color) -> void:
	toast_text = text
	toast_color = col
	toast_t = 1.1


func step_frame(dir: int) -> void:
	if playing:
		return
	seek(t + float(dir) / float(maxi(hz, 1)))


# ================================================================== input
func _on_ui(_source: int, action: StringName) -> void:
	if not visible or world == null or ui_lock:
		return
	idle = 0.0
	var is_pad: bool = _source >= 0
	if is_pad:
		pad_nav = true
	if exit_menu:
		match action:
			&"up":
				_menu_move(-1)
			&"down":
				_menu_move(1)
			&"left", &"right":
				if menu_idx >= 2 and menu_idx <= 4:
					_menu_activate(menu_idx)     # tombol ON/OFF: kiri / kanan juga mengubah
			&"accept", &"start":
				_menu_activate(menu_idx)
			&"back":
				_menu_activate(0)          # B / ESC lagi = lanjutkan menonton
		return
	if ended:
		match action:
			&"left", &"right":
				end_focus = 1 - end_focus
				Global.play_sfx("ui_hover", -8.0)
			&"accept", &"start":
				if end_focus == 0:
					_restart()
				else:
					close()
			&"back":
				close()
		return
	if show_help:
		show_help = false              # tombol apa saja menutup bantuan
		Global.play_sfx("ui_back", -8.0)
		return
	if speed_menu:
		match action:
			&"up": set_speed(speed_idx + 1)
			&"down": set_speed(speed_idx - 1)
			&"accept", &"back": speed_menu = false
		return
	if is_pad and _pad_navigate(action):
		return
	match action:
		&"accept", &"start":
			toggle_play()
		&"left":
			skip(-ReplayStore.skip_seconds())
		&"right":
			skip(ReplayStore.skip_seconds())
		&"up":
			set_speed(speed_idx + 1)
		&"down":
			set_speed(speed_idx - 1)
		&"prev":
			jump_event(-1)
		&"next":
			jump_event(1)
		&"extra":
			show_hud = not show_hud
			_toast("PLAYER CARDS " + ("ON" if show_hud else "OFF"), Color.WHITE)
		&"alt":
			jump_round(1)
		&"back":
			open_exit_menu()


## Navigasi controller di bar bawah. Mengembalikan true kalau tombol sudah ditangani di sini.
func _pad_navigate(action: StringName) -> bool:
	if ui_hidden:
		# kontrol tersembunyi: D-pad atas / bawah menampilkannya lagi, tombol lain berperilaku biasa
		if action == &"up" or action == &"down":
			toggle_ui()
			return true
		return false
	match action:
		&"left":
			if focus_id == "seek":
				skip(-ReplayStore.skip_seconds())
			else:
				_focus_move(-1)
			return true
		&"right":
			if focus_id == "seek":
				skip(ReplayStore.skip_seconds())
			else:
				_focus_move(1)
			return true
		&"up":
			if focus_id == "speed":
				set_speed(speed_idx + 1)         # pada tombol kecepatan: atas / bawah = ganti kecepatan langsung
			elif focus_id != "seek":
				_last_btn_id = focus_id
				focus_id = "seek"
				Global.play_sfx("ui_hover", -8.0)
			return true
		&"down":
			if focus_id == "seek":
				focus_id = _last_btn_id
				Global.play_sfx("ui_hover", -8.0)
			elif focus_id == "speed":
				set_speed(speed_idx - 1)
			return true
		&"accept":
			_pad_activate(focus_id)
			return true
	return false


func _focus_move(dir: int) -> void:
	var idx: int = FOCUS_ORDER.find(focus_id)
	if idx < 0:
		idx = FOCUS_ORDER.find(_last_btn_id)
	var ni: int = clampi(idx + dir, 0, FOCUS_ORDER.size() - 1)
	if ni != idx or focus_id == "seek":
		Global.play_sfx("ui_hover", -8.0)
	focus_id = String(FOCUS_ORDER[ni])
	_last_btn_id = focus_id


## Tekan tombol yang sedang terpilih (A / ✕).
func _pad_activate(id: String) -> void:
	match id:
		"play", "seek": toggle_play()
		"back": skip(-ReplayStore.skip_seconds())
		"fwd": skip(ReplayStore.skip_seconds())
		"prevk": jump_event(-1)
		"nextk": jump_event(1)
		"ui": toggle_ui()
		"speed":
			speed_menu = true
			Global.play_sfx("ui_hover", -8.0)
		"hud":
			show_hud = not show_hud
			_toast("PLAYER CARDS " + ("ON" if show_hud else "OFF"), Color.WHITE)
		"help": show_help = true
		"exit": open_exit_menu()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or world == null or ui_lock or not (event is InputEventKey):
		return
	var k: InputEventKey = event
	if not k.pressed or k.echo or ended or exit_menu:
		return
	match k.physical_keycode:
		KEY_K:
			toggle_play()
		KEY_J:
			skip(-ReplayStore.skip_seconds())
		KEY_L:
			skip(ReplayStore.skip_seconds())
		KEY_COMMA:
			step_frame(-1)
		KEY_PERIOD:
			step_frame(1)
		KEY_HOME:
			seek(0.0, "START")
		KEY_END:
			seek(duration - 0.1, "END")
		KEY_H:
			show_help = not show_help
		KEY_U:
			toggle_ui()
		KEY_M:
			show_hud = not show_hud
	idle = 0.0


func _overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		idle = 0.0
		if (event as InputEventMouseMotion).relative.length() > 0.5:
			pad_nav = false
		mouse = event.position
		hover_id = _hit(mouse)
		_update_cursor()
		if dragging:
			_drag_to(mouse.x)
	elif event is InputEventMouseButton:
		idle = 0.0
		mouse = event.position
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				pad_nav = false
				pressed_id = _hit(mb.position)
				_press(mb.position)
			else:
				pressed_id = ""
				if dragging:
					_end_drag()
		elif mb.pressed and not exit_menu and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var up: bool = mb.button_index == MOUSE_BUTTON_WHEEL_UP
			if hover_id == "speed" or hover_id.begins_with("spd:"):
				set_speed(speed_idx + (1 if up else -1))
			else:
				skip(5.0 if up else -5.0)


## Kursor berubah jadi tangan saat di atas tombol / progress bar / tanda kill.
func _update_cursor() -> void:
	if overlay == null:
		return
	overlay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (hover_id != "" and (ui_alpha > 0.05 or hover_id == "ui")) else Control.CURSOR_ARROW


func _hit(pos: Vector2) -> String:
	for i in range(_hits.size() - 1, -1, -1):
		var h: Dictionary = _hits[i]
		if exit_menu or ended:
			continue
		if (h["rect"] as Rect2).has_point(pos):
			return String(h["id"])
	return ""


func _press(pos: Vector2) -> void:
	var id: String = _hit(pos)
	if exit_menu or ended:
		return                         # menu jeda & layar selesai adalah panel sendiri (ReplayUI)
	if show_help:
		show_help = false
		return
	if speed_menu and not id.begins_with("spd:") and id != "speed":
		speed_menu = false
		return
	if id.begins_with("spd:"):
		set_speed(int(id.substr(4)))
		speed_menu = false
		return
	if id.begins_with("mark:"):
		go_event(int(id.substr(5)))
		return
	if id.begins_with("round:"):
		var ri: int = int(id.substr(6))
		seek(float((rounds[ri] as Dictionary)["start"]), "ROUND %d" % int((rounds[ri] as Dictionary)["num"]))
		return
	match id:
		"seek":
			dragging = true
			resume_after_drag = playing
			_drag_to(pos.x)
		"play": toggle_play()
		"back": skip(-ReplayStore.skip_seconds())
		"fwd": skip(ReplayStore.skip_seconds())
		"prevk": jump_event(-1)
		"nextk": jump_event(1)
		"speed":
			speed_menu = not speed_menu
			Global.play_sfx("ui_hover", -8.0)
		"hud":
			show_hud = not show_hud
			_toast("PLAYER CARDS " + ("ON" if show_hud else "OFF"), Color.WHITE)
		"ui": toggle_ui()
		"help": show_help = true
		"exit": open_exit_menu()
		_:
			toggle_play()          # klik di area video = putar / jeda


func _drag_to(x: float) -> void:
	var f: float = clampf((x - BAR_X) / BAR_W, 0.0, 1.0)
	seek(f * duration)


func _end_drag() -> void:
	dragging = false
	playing = resume_after_drag and t < duration - 0.05
	if t >= duration - 0.05 and resume_after_drag:
		ended = true


# ================================================================== gambar overlay
class Overlay extends Control:
	var v: ReplayView

	func _init(view: ReplayView) -> void:
		v = view
		set_anchors_preset(Control.PRESET_TOP_LEFT)
		position = Vector2.ZERO
		size = Vector2(1280, 720)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _process(_d: float) -> void:
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		v._overlay_input(event)

	func _draw() -> void:
		v._draw_overlay(self)


func _add_hit(id: String, r: Rect2) -> void:
	_hits.append({"id": id, "rect": r})


func _draw_overlay(ci: CanvasItem) -> void:
	_hits.clear()
	var a: float = ui_alpha
	# ---- bayangan bawah supaya tombol & progress bar terbaca di atas arena apa pun
	#      (bagian atas sengaja tanpa bayangan: tampilan HUD harus sama dengan gameplay asli)
	if a > 0.01:
		ci.draw_polygon(PackedVector2Array([Vector2(0, 500), Vector2(1280, 500), Vector2(1280, 720), Vector2(0, 720)]),
			PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.82 * a), Color(0, 0, 0, 0.82 * a)]))

	if not ui_hidden:
		_draw_replay_badge(ci)
		_draw_kill_feed(ci)
	_draw_status(ci)
	if a > 0.01:
		_draw_bar(ci, a)
		_draw_controls(ci, a)
	if ui_hidden and not ended and not show_help:
		_draw_unhide_button(ci)
	if tip_time > 0.0 and not ended and not ui_hidden and not start_hint and hint_a < 0.01 and hover_id == "" and toast_t <= 0.0:
		var ta: float = clampf(tip_time, 0.0, 1.0)
		var tip: String = "SPACE  PAUSE     < >  SKIP %d SEC     ^ v  SPEED     Q E  JUMP KILLS     H  HELP     ESC  MENU" % int(ReplayStore.skip_seconds())
		var tw: float = UIKit.text_w(tip, 20) + 50.0
		var tp := UIKit.slanted(tw, 38.0, 12.0, 640.0 - tw * 0.5, 506.0)
		ci.draw_colored_polygon(tp, Color(0, 0, 0, 0.6 * ta))
		UIKit.text_in(ci, tip, Rect2(640.0 - tw * 0.5, 506.0, tw, 38.0), 20, Color(1, 1, 1, 0.9 * ta), HORIZONTAL_ALIGNMENT_CENTER)
	if speed_a > 0.01:
		_draw_speed_menu(ci)
	if a > 0.3 and not speed_menu and speed_a < 0.05:
		_draw_tooltip(ci)


# ------------------------------------------------------------------ lencana REPLAY
## Kartu pemain, timer, dan banner ROUND/FIGHT sekarang memakai HUD asli game (lihat _build_hud).
## Di sini hanya lencana REPLAY (titik merah berdenyut) di bawah timer.
func _draw_replay_badge(ci: CanvasItem) -> void:
	var rx: float = 640.0 - 70.0
	var py: float = 106.0
	ci.draw_colored_polygon(UIKit.slanted(140.0, 28.0, 10.0, rx, py), Color(0, 0, 0, 0.55))
	var pulse: float = 0.55 + 0.45 * sin(_clock * 4.0)
	ci.draw_circle(Vector2(rx + 26.0, py + 14.0), 6.0, Color(1.0, 0.2, 0.2, pulse))
	UIKit.text_in(ci, "REPLAY  %s" % String(ReplayStore.SPEED_NAMES[speed_idx]), Rect2(rx + 38.0, py, 98.0, 28.0), 17, Color(1, 1, 1, 0.9), HORIZONTAL_ALIGNMENT_LEFT, 4)


# ------------------------------------------------------------------ kill feed
func _draw_kill_feed(ci: CanvasItem) -> void:
	var y: float = 12.0 + float((plist.size() - 1) / 2 + 1) * 140.0 + 2.0     # tepat di bawah baris kartu terakhir
	var shown: int = 0
	for i in range(events.size() - 1, -1, -1):
		var e: Dictionary = events[i]
		var age: float = t - float(e["t"])
		if age < 0.0 or age > 4.5:
			continue
		if shown >= 4:
			break
		var fade: float = minf(clampf((4.5 - age) / 1.0, 0.0, 1.0), clampf(age / 0.12, 0.0, 1.0))
		var killer: int = int(e["killer"])
		var victim: int = int(e["victim"])
		var txt: String = event_text(i)
		var w: float = UIKit.text_w(txt, 20) + 52.0
		var x: float = 1280.0 - 14.0 - w + (1.0 - ReplayUI.ease_out_cubic(clampf(age / 0.3, 0.0, 1.0))) * 90.0
		var rect_y: float = y + float(shown) * 34.0
		ci.draw_colored_polygon(UIKit.slanted(w, 30.0, 8.0, x, rect_y), Color(0, 0, 0, 0.6 * fade))
		var kc: Color = player_color(killer if killer >= 0 and killer != victim else victim)
		ci.draw_colored_polygon(UIKit.slanted(8.0, 30.0, 3.0, x + 6.0, rect_y), Color(kc, fade))
		UIKit.text_in(ci, txt, Rect2(x + 24.0, rect_y, w - 28.0, 30.0), 20, Color(1, 1, 1, fade), HORIZONTAL_ALIGNMENT_LEFT, 4)
		shown += 1


## Notifikasi singkat di tengah (lompat 10 detik, kecepatan, dll) + tanda JEDA.
func _draw_status(ci: CanvasItem) -> void:
	if toast_t > 0.0:
		var enter: float = clampf((1.1 - toast_t) / 0.16, 0.0, 1.0)
		var a: float = minf(clampf(toast_t / 0.35, 0.0, 1.0), enter) * clampf(1.0 - hint_a * 3.0, 0.0, 1.0)
		var w: float = UIKit.text_w(toast_text, 34) + 70.0
		var r := Rect2(640.0 - w * 0.5, 414.0 + (1.0 - ReplayUI.ease_out_cubic(enter)) * 18.0, w, 58.0)
		ci.draw_colored_polygon(UIKit.slanted(r.size.x, r.size.y, 14.0, r.position.x, r.position.y), Color(0, 0, 0, 0.65 * a))
		ci.draw_polyline(UIKit.closed(UIKit.slanted(r.size.x, r.size.y, 14.0, r.position.x, r.position.y)), Color(toast_color, 0.9 * a), 2.5, true)
		UIKit.text_in(ci, toast_text, r, 34, Color(toast_color, a), HORIZONTAL_ALIGNMENT_CENTER, 6, Color(0, 0, 0, a))
	# ikon jeda tepat di tengah layar (360); disembunyikan selama banner ROUND / FIGHT tampil supaya tidak bertumpuk
	var banner_on: bool = banner != null and bool(banner.shown)
	if not playing and not ended and not dragging and not banner_on and not ui_lock:
		var c := Vector2(640.0, 360.0)
		ci.draw_circle(c, 44.0, Color(0, 0, 0, 0.5))
		ci.draw_arc(c, 44.0, 0.0, TAU, 40, Color(1, 1, 1, 0.8), 3.0, true)
		ci.draw_rect(Rect2(c.x - 14.0, c.y - 18.0, 10.0, 36.0), Color.WHITE)
		ci.draw_rect(Rect2(c.x + 4.0, c.y - 18.0, 10.0, 36.0), Color.WHITE)
	# petunjuk saat replay baru dibuka (jeda): papan kecil di bawah ikon jeda
	if hint_a > 0.01 and not ended:
		var he: float = ReplayUI.ease_out_cubic(hint_a)
		var pulse: float = 0.5 + 0.5 * sin(_clock * 3.5)
		var l1: String = "REPLAY PAUSED"
		var l2: String = "PRESS SPACE, CLICK OR A TO PLAY"
		var hw: float = maxf(UIKit.text_w(l2, 21), UIKit.text_w(l1, 32)) + 96.0
		var hx: float = 640.0 - hw * 0.5
		var hy: float = 440.0 + (1.0 - he) * 24.0
		ci.draw_colored_polygon(UIKit.slanted(hw, 84.0, 16.0, hx + 5.0, hy + 6.0), Color(0, 0, 0, 0.4 * hint_a))
		var hp: PackedVector2Array = UIKit.slanted(hw, 84.0, 16.0, hx, hy)
		ci.draw_colored_polygon(hp, Color(0.04, 0.04, 0.1, 0.8 * hint_a))
		ci.draw_polyline(UIKit.closed(hp), Color(UIKit.GOLD, (0.5 + 0.4 * pulse) * hint_a), 2.5, true)
		ci.draw_colored_polygon(UIKit.slanted(7.0, 84.0, 16.0, hx, hy), Color(UIKit.GOLD, hint_a))
		UIKit.text_in(ci, l1, Rect2(hx, hy + 6.0, hw, 40.0), 32, Color(UIKit.GOLD, hint_a), HORIZONTAL_ALIGNMENT_CENTER, 6, Color(0, 0, 0, hint_a))
		UIKit.text_in(ci, l2, Rect2(hx, hy + 46.0, hw, 30.0), 21, Color(1, 1, 1, (0.7 + 0.25 * pulse) * hint_a), HORIZONTAL_ALIGNMENT_CENTER, 4, Color(0, 0, 0, hint_a))


# ------------------------------------------------------------------ progress bar
func _draw_bar(ci: CanvasItem, a: float) -> void:
	var hov: bool = hover_id == "seek" or dragging or hover_id.begins_with("mark:")
	var th: float = 18.0 if hov else 12.0
	var ty: float = TRACK_Y + 6.0 - th * 0.5
	var track := Rect2(BAR_X, ty, BAR_W, th)
	_add_hit("seek", Rect2(BAR_X - 10.0, TRACK_Y - 14.0, BAR_W + 20.0, 32.0))

	# dasar + segmen ronde berwarna pemenang
	ci.draw_rect(track, Color(1, 1, 1, 0.16 * a))
	for i in rounds.size():
		var r: Dictionary = rounds[i]
		var rs: float = float(r["start"])
		var re: float = float(r["end"]) if float(r["end"]) >= 0.0 else duration
		var x0: float = BAR_X + rs / duration * BAR_W
		var x1: float = BAR_X + minf(re, duration) / duration * BAR_W
		var wc: Color = Color(0.7, 0.7, 0.75)
		if int(r["winner"]) >= 0:
			wc = r["winner_color"]
		ci.draw_rect(Rect2(x0, ty, maxf(x1 - x0, 2.0), th), Color(wc, 0.38 * a))
		if i > 0:
			ci.draw_rect(Rect2(x0 - 1.0, ty - 3.0, 2.0, th + 6.0), Color(1, 1, 1, 0.75 * a))
		# label ronde di bawah bar (bisa diklik)
		var lw: float = maxf(minf(x1 - x0, 90.0), 34.0)
		var lr := Rect2(x0 + 2.0, ROUND_Y - 4.0, lw, 20.0)
		_add_hit("round:%d" % i, lr)
		var lcol: Color = Color(1, 1, 1, 0.7 * a)
		if hover_id == "round:%d" % i:
			lcol = Color(UIKit.GOLD, a)
		UIKit.text_in(ci, "R%d" % int(r["num"]), lr, 16, lcol, HORIZONTAL_ALIGNMENT_LEFT, 3)

	# bagian yang sudah ditonton
	var px: float = BAR_X + t / duration * BAR_W
	ci.draw_rect(Rect2(BAR_X, ty, maxf(px - BAR_X, 0.0), th), Color(UIKit.GOLD, 0.95 * a))
	ci.draw_rect(Rect2(BAR_X, ty, BAR_W, th), Color(0, 0, 0, 0.7 * a), false, 2.0)

	# tanda kill
	if ReplayStore.show_markers:
		for i in events.size():
			var e: Dictionary = events[i]
			var x: float = event_x(i)
			var row: int = int(ev_row[i])
			var cy: float = float(MARK_ROWS[row])
			var is_kill: bool = String(e["type"]) == "kill"
			var killer: int = int(e["killer"])
			var col: Color = player_color(killer) if is_kill else Color(0.62, 0.64, 0.7)
			var rect := Rect2(x - MARK_W * 0.5, cy - 11.0, MARK_W, 22.0)
			_add_hit("mark:%d" % i, rect.grow(2.0))
			var hv: bool = hover_id == "mark:%d" % i
			if hv:
				rect = rect.grow(3.0)
			# tiang kecil ke track
			ci.draw_line(Vector2(x, rect.end.y), Vector2(x, ty), Color(col, 0.75 * a), 2.0)
			var pts: PackedVector2Array = UIKit.slanted(rect.size.x, rect.size.y, 6.0, rect.position.x, rect.position.y)
			ci.draw_colored_polygon(pts, Color(col.darkened(0.35), 0.95 * a))
			ci.draw_polyline(UIKit.closed(pts), Color(col.lightened(0.35), a).lerp(Color.WHITE, 0.6 if hv else 0.0), 2.0, true)
			var label: String = "P%d" % (killer + 1) if is_kill else "X"
			UIKit.text_in(ci, label, rect, 15, Color(1, 1, 1, a), HORIZONTAL_ALIGNMENT_CENTER, 4)

	# kotak pilihan controller di progress bar (D-pad kiri / kanan = geser waktu)
	if pad_nav and focus_id == "seek":
		var fr := Rect2(BAR_X - 8.0, ty - 7.0, BAR_W + 16.0, th + 14.0)
		ci.draw_rect(fr, Color(UIKit.GOLD, (0.7 + 0.3 * sin(_clock * 7.0)) * a), false, 3.0)
		hov = true

	# kepala (thumb)
	ci.draw_circle(Vector2(px, TRACK_Y + 6.0), 10.0 if hov else 8.0, Color(0, 0, 0, 0.8 * a))
	ci.draw_circle(Vector2(px, TRACK_Y + 6.0), 7.0 if hov else 5.5, Color(1, 1, 1, a))


# ------------------------------------------------------------------ tombol
func _icon_btn(ci: CanvasItem, id: String, r: Rect2, a: float) -> bool:
	_add_hit(id, r)
	var fc: bool = pad_nav and focus_id == id
	var h: float = float(_hv.get(id, 0.0))
	var pr: bool = pressed_id == id and hover_id == id
	if fc:
		# kotak pilihan controller: isi gelap + garis emas berdenyut, seperti tombol yang sedang "di kursor"
		var fp: PackedVector2Array = UIKit.slanted(r.size.x + 4.0, r.size.y + 4.0, 8.0, r.position.x - 2.0, r.position.y - 2.0)
		ci.draw_colored_polygon(fp, Color(0.0, 0.0, 0.0, 0.55 * a))
		ci.draw_colored_polygon(fp, Color(1, 1, 1, 0.12 * a))
		ci.draw_polyline(UIKit.closed(fp), Color(UIKit.GOLD, (0.75 + 0.25 * sin(_clock * 7.0)) * a), 3.0, true)
		return true
	if h > 0.01:
		# sorotan halus: tombol sedikit membesar & naik saat hover, mengecil saat ditekan
		var rr: Rect2 = r.grow(h * 2.0 - (3.0 if pr else 0.0))
		rr.position.y -= h * 2.0
		var pts: PackedVector2Array = UIKit.slanted(rr.size.x, rr.size.y, 8.0, rr.position.x, rr.position.y)
		ci.draw_colored_polygon(pts, Color(UIKit.GOLD, 0.38 * a) if pr else Color(1, 1, 1, 0.16 * a * h))
		ci.draw_polyline(UIKit.closed(pts), Color(UIKit.GOLD, 0.9 * a * h), 2.0, true)
	return hover_id == id

func _draw_controls(ci: CanvasItem, a: float) -> void:
	var cy: float = CTRL_Y
	var white: Color = Color(1, 1, 1, a)

	# putar / jeda
	var pr := Rect2(40.0, cy - 22.0, 52.0, BTN_H)
	_icon_btn(ci, "play", pr, a)
	var pc: Vector2 = pr.get_center()
	if playing and not ended:
		ci.draw_rect(Rect2(pc.x - 11.0, pc.y - 13.0, 8.0, 26.0), white)
		ci.draw_rect(Rect2(pc.x + 3.0, pc.y - 13.0, 8.0, 26.0), white)
	elif ended:
		ci.draw_arc(pc, 12.0, 0.6, TAU - 0.4, 20, white, 4.0, true)
		ci.draw_colored_polygon(PackedVector2Array([pc + Vector2(8, -16), pc + Vector2(16, -4), pc + Vector2(2, -4)]), white)
	else:
		ci.draw_colored_polygon(PackedVector2Array([pc + Vector2(-9, -15), pc + Vector2(-9, 15), pc + Vector2(15, 0)]), white)

	# mundur / maju (lama lompat sesuai pengaturan)
	var sk: int = int(ReplayStore.skip_seconds())
	var br := Rect2(100.0, cy - 22.0, 52.0, BTN_H)
	_icon_btn(ci, "back", br, a)
	_draw_skip_icon(ci, br.get_center(), -1, sk, a)
	var fr := Rect2(156.0, cy - 22.0, 52.0, BTN_H)
	_icon_btn(ci, "fwd", fr, a)
	_draw_skip_icon(ci, fr.get_center(), 1, sk, a)

	# kill sebelumnya / berikutnya
	var kr := Rect2(224.0, cy - 22.0, 52.0, BTN_H)
	_icon_btn(ci, "prevk", kr, a)
	_draw_kill_icon(ci, kr.get_center(), -1, a)
	var nr := Rect2(280.0, cy - 22.0, 52.0, BTN_H)
	_icon_btn(ci, "nextk", nr, a)
	_draw_kill_icon(ci, nr.get_center(), 1, a)

	# waktu
	var tt: String = "%s / %s" % [ReplayStore.format_clock(t), ReplayStore.format_clock(duration)]
	UIKit.text_in(ci, tt, Rect2(350.0, cy - 22.0, 220.0, BTN_H), 28, white, HORIZONTAL_ALIGNMENT_LEFT, 5)

	# kanan: keluar, bantuan, kartu pemain, kecepatan
	var er := Rect2(1240.0 - 52.0, cy - 22.0, 52.0, BTN_H)
	var hv_e: bool = _icon_btn(ci, "exit", er, a)
	var ec: Vector2 = er.get_center()
	var ecol: Color = Color(1.0, 0.45, 0.45, a) if hv_e else white
	ci.draw_line(ec + Vector2(-9, -9), ec + Vector2(9, 9), ecol, 4.0, true)
	ci.draw_line(ec + Vector2(9, -9), ec + Vector2(-9, 9), ecol, 4.0, true)

	var hr := Rect2(er.position.x - 56.0, cy - 22.0, 52.0, BTN_H)
	_icon_btn(ci, "help", hr, a)
	UIKit.text_in(ci, "?", hr, 34, white, HORIZONTAL_ALIGNMENT_CENTER, 5)

	var ur := Rect2(hr.position.x - 56.0, cy - 22.0, 52.0, BTN_H)
	_icon_btn(ci, "hud", ur, a)
	var uc: Vector2 = ur.get_center()
	var ucol: Color = Color(UIKit.GOLD, a) if show_hud else Color(1, 1, 1, 0.45 * a)
	ci.draw_rect(Rect2(uc.x - 13.0, uc.y - 10.0, 26.0, 20.0), ucol, false, 3.0)
	ci.draw_rect(Rect2(uc.x - 8.0, uc.y - 5.0, 9.0, 10.0), ucol)

	var sr := Rect2(ur.position.x - 108.0, cy - 22.0, 98.0, BTN_H)
	var yr := Rect2(sr.position.x - 56.0, cy - 22.0, 52.0, BTN_H)
	_icon_btn(ci, "ui", yr, a)
	_draw_eye_icon(ci, yr.get_center(), white, false)
	_add_hit("speed", sr)
	var sv: bool = hover_id == "speed" or speed_menu
	var sp: PackedVector2Array = UIKit.slanted(sr.size.x, sr.size.y, 10.0, sr.position.x, sr.position.y)
	ci.draw_colored_polygon(sp, Color(UIKit.GOLD, 0.95 * a) if sv else Color(0, 0, 0, 0.55 * a))
	ci.draw_polyline(UIKit.closed(sp), Color(UIKit.GOLD, a), 2.0, true)
	if pad_nav and focus_id == "speed":
		var sfp: PackedVector2Array = UIKit.slanted(sr.size.x + 10.0, sr.size.y + 10.0, 10.0, sr.position.x - 5.0, sr.position.y - 5.0)
		ci.draw_polyline(UIKit.closed(sfp), Color(1, 1, 1, (0.7 + 0.3 * sin(_clock * 7.0)) * a), 3.0, true)
	UIKit.text_in(ci, String(ReplayStore.SPEED_NAMES[speed_idx]), sr, 28, Color(UIKit.INK, a) if sv else Color(UIKit.GOLD, a), HORIZONTAL_ALIGNMENT_CENTER)


## Ikon mata. slashed = true -> dicoret (kontrol sedang disembunyikan).
func _draw_eye_icon(ci: CanvasItem, c: Vector2, col: Color, slashed: bool) -> void:
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for k in range(0, 13):
		var fx: float = -1.0 + float(k) / 6.0
		var hy: float = 9.0 * (1.0 - fx * fx)
		top.append(c + Vector2(fx * 15.0, -hy))
		bot.append(c + Vector2(fx * 15.0, hy))
	ci.draw_polyline(top, col, 2.5, true)
	ci.draw_polyline(bot, col, 2.5, true)
	ci.draw_circle(c, 4.5, col)
	if slashed:
		ci.draw_line(c + Vector2(-13, 12), c + Vector2(13, -12), Color(0, 0, 0, col.a), 6.0, true)
		ci.draw_line(c + Vector2(-13, 12), c + Vector2(13, -12), col, 3.0, true)


## Tombol kecil di pojok kanan bawah saat kontrol disembunyikan, untuk menampilkannya lagi.
func _draw_unhide_button(ci: CanvasItem) -> void:
	var r := Rect2(1240.0 - 52.0, CTRL_Y - 22.0, 52.0, BTN_H)
	_add_hit("ui", r)
	var hv: bool = hover_id == "ui"
	var al: float = 1.0 if hv else 0.45
	var pts: PackedVector2Array = UIKit.slanted(r.size.x, r.size.y, 8.0, r.position.x, r.position.y)
	ci.draw_colored_polygon(pts, Color(0, 0, 0, 0.55 * al))
	ci.draw_polyline(UIKit.closed(pts), Color(UIKit.GOLD if hv else Color.WHITE, 0.8 * al), 2.0, true)
	_draw_eye_icon(ci, r.get_center(), Color(1, 1, 1, al), true)


func toggle_ui() -> void:
	ui_hidden = not ui_hidden
	speed_menu = false
	hover_id = ""
	if ui_hidden:
		_toast("CONTROLS HIDDEN  (PRESS U OR CLICK THE EYE)", Color.WHITE)
	else:
		idle = 0.0
		_toast("CONTROLS SHOWN", Color.WHITE)


func _draw_skip_icon(ci: CanvasItem, c: Vector2, dir: int, secs: int, a: float) -> void:
	var col: Color = Color(1, 1, 1, a)
	var start: float = -PI * 0.5 + 0.7 * float(dir)
	var sweep: float = TAU * 0.78 * float(dir)
	ci.draw_arc(c, 14.0, start, start + sweep, 24, col, 3.0, true)
	var ang: float = start + sweep
	var tip: Vector2 = c + Vector2(cos(ang), sin(ang)) * 14.0
	var tdir: Vector2 = Vector2(-sin(ang), cos(ang)) * float(dir)
	var side: Vector2 = Vector2(-tdir.y, tdir.x)
	ci.draw_colored_polygon(PackedVector2Array([tip + tdir * 7.0, tip + side * 6.0, tip - side * 6.0]), col)
	UIKit.text_in(ci, str(secs), Rect2(c.x - 14.0, c.y - 9.0, 28.0, 18.0), 14, col, HORIZONTAL_ALIGNMENT_CENTER, 3)


func _draw_kill_icon(ci: CanvasItem, c: Vector2, dir: int, a: float) -> void:
	var col: Color = Color(1, 0.55, 0.55, a)
	ci.draw_arc(c, 10.0, 0.0, TAU, 20, col, 2.5, true)
	ci.draw_line(c + Vector2(-15, 0), c + Vector2(-6, 0), col, 2.5)
	ci.draw_line(c + Vector2(6, 0), c + Vector2(15, 0), col, 2.5)
	ci.draw_line(c + Vector2(0, -15), c + Vector2(0, -6), col, 2.5)
	ci.draw_line(c + Vector2(0, 6), c + Vector2(0, 15), col, 2.5)
	ci.draw_circle(c, 2.5, col)
	# panah kecil arah lompat
	var ax: float = float(dir) * 20.0
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(ax, -16), c + Vector2(ax, -8), c + Vector2(ax + 7.0 * float(dir), -12)]), Color(1, 1, 1, a))


func _draw_speed_menu(ci: CanvasItem) -> void:
	var n: int = ReplayStore.SPEED_VALUES.size()
	var item_h: float = 34.0
	# letak menu = tepat di atas tombol kecepatan (posisi tombol dihitung sama dengan _draw_controls)
	var er_x: float = 1240.0 - 52.0
	var hr_x: float = er_x - 56.0
	var ur_x: float = hr_x - 56.0
	var x: float = ur_x - 108.0
	var total: float = item_h * float(n) + 12.0
	var y0: float = CTRL_Y - 22.0 - total - 6.0
	var e: float = clampf(ReplayUI.ease_out_back(speed_a), 0.0, 1.08)
	var al: float = clampf(speed_a * 1.8, 0.0, 1.0)
	# tumbuh dari tombol kecepatan (titik tumpu di bawah-tengah menu)
	var pv := Vector2(x + 49.0, y0 + total)
	ci.draw_set_transform(pv * (1.0 - e), 0.0, Vector2(e, e))
	var frame: PackedVector2Array = UIKit.slanted(98.0, total, 10.0, x, y0)
	ci.draw_colored_polygon(UIKit.slanted(98.0, total, 10.0, x + 4.0, y0 + 5.0), Color(0, 0, 0, 0.5 * al))
	ci.draw_colored_polygon(frame, Color(0.05, 0.05, 0.12, 0.96 * al))
	ci.draw_polyline(UIKit.closed(frame), Color(UIKit.GOLD, 0.9 * al), 2.0, true)
	for i in n:
		var vi: int = n - 1 - i                         # kecepatan tertinggi di atas
		var r := Rect2(x + 8.0, y0 + 6.0 + float(i) * item_h, 82.0, item_h - 2.0)
		if speed_menu:
			_add_hit("spd:%d" % vi, r)
		var cur: bool = vi == speed_idx
		var hv: bool = hover_id == "spd:%d" % vi
		if cur:
			ci.draw_colored_polygon(UIKit.slanted(r.size.x, r.size.y, 6.0, r.position.x, r.position.y), Color(UIKit.GOLD, al))
		elif hv:
			ci.draw_colored_polygon(UIKit.slanted(r.size.x, r.size.y, 6.0, r.position.x, r.position.y), Color(1, 1, 1, 0.18 * al))
		UIKit.text_in(ci, String(ReplayStore.SPEED_NAMES[vi]), r, 22, Color(UIKit.INK, al) if cur else Color(1, 1, 1, al), HORIZONTAL_ALIGNMENT_CENTER)
	ci.draw_set_transform(Vector2.ZERO)
	if speed_menu:
		_add_hit("speed", Rect2(x, CTRL_Y - 22.0, 98.0, BTN_H))

func _draw_tooltip(ci: CanvasItem) -> void:
	var text: String = ""
	var sub: String = ""
	var anchor_x: float = 0.0
	var col: Color = Color.WHITE
	if hover_id.begins_with("mark:") and ReplayStore.show_markers:
		var i: int = int(hover_id.substr(5))
		var e: Dictionary = events[i]
		text = event_text(i)
		sub = "ROUND %d   %s   (CLICK TO WATCH)" % [int(e["round"]), ReplayStore.format_clock(float(e["t"]))]
		anchor_x = event_x(i)
		var kk: int = int(e["killer"])
		col = player_color(kk if kk >= 0 else int(e["victim"]))
	elif hover_id == "seek" or dragging:
		var f: float = clampf((mouse.x - BAR_X) / BAR_W, 0.0, 1.0)
		text = ReplayStore.format_clock(f * duration)
		var tm: float = f * duration
		for r in rounds:
			if tm >= float((r as Dictionary)["start"]):
				sub = "ROUND %d" % int((r as Dictionary)["num"])
		anchor_x = clampf(mouse.x, BAR_X, BAR_X + BAR_W)
	else:
		var tips := {"play": "PLAY / PAUSE   (SPACE)", "back": "BACK %d SEC   (LEFT)" % int(ReplayStore.skip_seconds()),
			"fwd": "FORWARD %d SEC   (RIGHT)" % int(ReplayStore.skip_seconds()), "prevk": "PREVIOUS KILL   (Q)",
			"nextk": "NEXT KILL   (E)", "speed": "PLAYBACK SPEED   (UP / DOWN)", "hud": "PLAYER CARDS   (TAB)",
			"help": "HELP   (H)", "exit": "PAUSE MENU   (ESC)", "ui": "HIDE CONTROLS   (U)"}
		if tips.has(hover_id):
			text = String(tips[hover_id])
			var hr: Rect2 = Rect2()
			for h in _hits:
				if String((h as Dictionary)["id"]) == hover_id:
					hr = (h as Dictionary)["rect"]
			anchor_x = hr.get_center().x
		elif hover_id.begins_with("round:"):
			var ri: int = int(hover_id.substr(6))
			var rr: Dictionary = rounds[ri]
			text = "JUMP TO ROUND %d" % int(rr["num"])
			if int(rr["winner"]) >= 0:
				sub = "WON BY %s" % String(rr["winner_label"])
				col = rr["winner_color"]
			anchor_x = clampf(mouse.x, BAR_X, BAR_X + BAR_W)
	if text == "":
		_tip_key = ""
		return
	var tkey: String = text + "|" + sub
	if tkey != _tip_key:
		_tip_key = tkey
		_tip_age = 0.0
	_tip_age += get_process_delta_time()
	var ta: float = clampf(_tip_age / 0.14, 0.0, 1.0)
	var w: float = maxf(UIKit.text_w(text, 22), UIKit.text_w(sub, 17)) + 40.0
	var h2: float = 40.0 if sub == "" else 62.0
	var x: float = clampf(anchor_x - w * 0.5, 8.0, 1272.0 - w)
	var y: float = 480.0 if (hover_id.begins_with("mark:") or hover_id == "seek" or dragging or hover_id.begins_with("round:")) else CTRL_Y - 22.0 - h2 - 10.0
	if hover_id.begins_with("mark:"):
		y = float(MARK_ROWS[2]) - 22.0 - h2 - 8.0
	elif hover_id == "seek" or dragging or hover_id.begins_with("round:"):
		y = float(MARK_ROWS[2]) - 22.0 - h2 - 8.0
	y += (1.0 - ReplayUI.ease_out_cubic(ta)) * 8.0
	var pts: PackedVector2Array = UIKit.slanted(w, h2, 10.0, x, y)
	ci.draw_colored_polygon(UIKit.slanted(w, h2, 10.0, x + 3.0, y + 4.0), Color(0, 0, 0, 0.5 * ta))
	ci.draw_colored_polygon(pts, Color(0.05, 0.05, 0.12, 0.96 * ta))
	ci.draw_polyline(UIKit.closed(pts), Color(col, 0.9 * ta), 2.0, true)
	UIKit.text_in(ci, text, Rect2(x, y + 2.0, w, 36.0), 22, Color(1, 1, 1, ta), HORIZONTAL_ALIGNMENT_CENTER, 4, Color(0, 0, 0, ta))
	if sub != "":
		UIKit.text_in(ci, sub, Rect2(x, y + 33.0, w, 24.0), 17, Color(col.lightened(0.3), 0.95 * ta), HORIZONTAL_ALIGNMENT_CENTER, 3, Color(0, 0, 0, ta))


# ------------------------------------------------------------------ bantuan & akhir
# ------------------------------------------------------------------ panel animasi (menu jeda, bantuan, layar selesai)
func _build_panels() -> void:
	pause_menu = ReplayUI.PauseMenu.new(_pause_defs())
	pause_menu.activated.connect(_on_menu_click)
	pause_menu.hovered.connect(_on_menu_hover)
	add_child(pause_menu)
	help_panel = ReplayUI.HelpPanel.new()
	help_panel.dismissed.connect(_on_help_dismissed)
	add_child(help_panel)
	end_panel = ReplayUI.EndPanel.new()
	end_panel.setup(meta, rounds.size(), duration)
	end_panel.again.connect(_restart)
	end_panel.list.connect(close)
	end_panel.hovered.connect(_on_end_hover)
	add_child(end_panel)


func _on_help_dismissed() -> void:
	show_help = false
	Global.play_sfx("ui_back", -8.0)


func _on_end_hover(i: int) -> void:
	if ended and end_focus != i:
		end_focus = i
		Global.play_sfx("ui_hover", -8.0)


func _on_menu_hover(i: int) -> void:
	if exit_menu and menu_idx != i:
		menu_idx = i
		Global.play_sfx("ui_hover", -8.0)


func _on_menu_click(i: int) -> void:
	if exit_menu:
		menu_idx = i
		_menu_activate(i)


## Samakan panel dengan keadaan pemutar tiap frame (sehingga semua jalur yang membuka / menutup menu otomatis beranimasi).
func _sync_panels(delta: float) -> void:
	if pause_menu == null:
		return
	for id in FOCUS_ORDER:
		var tgt: float = 1.0 if (hover_id == id or (pad_nav and focus_id == id)) else 0.0
		_hv[id] = lerpf(float(_hv.get(id, 0.0)), tgt, 1.0 - exp(-delta * 16.0))
	speed_a = lerpf(speed_a, 1.0 if speed_menu else 0.0, 1.0 - exp(-delta * 16.0))
	if absf(speed_a - (1.0 if speed_menu else 0.0)) < 0.01:
		speed_a = 1.0 if speed_menu else 0.0
	if exit_menu:
		if not pause_menu.is_open:
			pause_menu.open(_pause_info(), _menu_states(), menu_idx)
		pause_menu.select(menu_idx)
		pause_menu.set_states(_menu_states())
	elif pause_menu.is_open:
		pause_menu.close()
	if show_help and not exit_menu:
		help_panel.open()
	else:
		help_panel.close()
	if ended and not exit_menu:
		end_panel.open()
		end_panel.set_focus(end_focus)
	else:
		end_panel.close()


func _menu_states() -> Array:
	return [show_hud, ReplayStore.play_sfx, ReplayStore.play_music]


func _pause_defs() -> Array:
	return [
		{"label": "RESUME", "icon": "play"},
		{"label": "RESTART REPLAY", "icon": "restart"},
		{"label": "PLAYER CARDS", "icon": "cards", "kind": "toggle", "gap": 12.0},
		{"label": "SOUND FX", "icon": "sound", "kind": "toggle"},
		{"label": "MUSIC", "icon": "music", "kind": "toggle"},
		{"label": "CONTROLS HELP", "icon": "help", "gap": 12.0},
		{"label": "REPLAY LIST", "icon": "list", "danger": true, "gap": 12.0},
		{"label": "MAIN MENU", "icon": "home", "danger": true},
	]


## Data untuk kartu info di menu jeda (keadaan replay pada waktu sekarang).
func _pause_info() -> Dictionary:
	var rl: Array = []
	for r in rounds:
		var rd: Dictionary = r
		rl.append({"start": float(rd["start"]), "end": float(rd["end"]), "color": rd["winner_color"] if int(rd["winner"]) >= 0 else Color(0.7, 0.7, 0.75)})
	var pl: Array = []
	for i in plist.size():
		var pd: Dictionary = plist[i]
		pl.append({"char": int(pd["char"]), "color": pd["color"], "name": String(pd.get("name", "P%d" % (i + 1))),
			"wins": int(world.pl(i, ReplayRecorder.PL_WINS)), "kills": int(world.pl(i, ReplayRecorder.PL_KILLS))})
	return {
		"map_id": String(meta.get("map_id", world.header.get("map_id", "earth"))),
		"map_name": String(meta.get("map_name", world.header.get("map_name", "ARENA"))),
		"t": t, "duration": duration, "round": maxi(int(world.head(4)), 1),
		"rounds": rl, "players": pl, "wins_to_match": wins_to_match,
	}


# ------------------------------------------------------------------ menu jeda (saat keluar)
## Dipanggil setiap kali pemain menekan keluar (ESC / B / tombol X): video dijeda dulu dan menu muncul.
func open_exit_menu() -> void:
	if exit_menu or not _opened:
		return
	exit_menu = true
	menu_idx = 0
	_resume_after_menu = playing
	playing = false
	dragging = false
	speed_menu = false
	show_help = false
	hover_id = ""
	Global.play_sfx("ui_pause", -8.0)


func _menu_move(dir: int) -> void:
	var n: int = _pause_defs().size()
	menu_idx = (menu_idx + dir + n) % n
	Global.play_sfx("ui_hover", -8.0)


func _menu_activate(i: int) -> void:
	if pause_menu != null:
		pause_menu.pop(i)
	match i:
		0:    # RESUME
			exit_menu = false
			playing = _resume_after_menu and not ended
			idle = 0.0
			Global.play_sfx("ui_resume", -6.0)
		1:    # RESTART
			exit_menu = false
			_restart()
			Global.play_sfx("ui_confirm", -8.0)
		2:    # PLAYER CARDS
			show_hud = not show_hud
			Global.play_sfx("ui_toggle_on" if show_hud else "ui_toggle_off", -6.0)
		3:    # SOUND FX
			ReplayStore.play_sfx = not ReplayStore.play_sfx
			ReplayStore.save_settings()
			Global.play_sfx("ui_toggle_on" if ReplayStore.play_sfx else "ui_toggle_off", -6.0)
		4:    # MUSIC
			ReplayStore.play_music = not ReplayStore.play_music
			ReplayStore.save_settings()
			if ReplayStore.play_music:
				Global._music.stream_paused = false
				Global.play_music("game")
			else:
				Global._music.stream_paused = true
			Global.play_sfx("ui_toggle_on" if ReplayStore.play_music else "ui_toggle_off", -6.0)
		5:    # HELP (video tetap dijeda)
			exit_menu = false
			show_help = true
			Global.play_sfx("ui_confirm", -8.0)
		6:    # BACK TO REPLAY LIST
			exit_menu = false
			close()
		7:    # MAIN MENU
			exit_menu = false
			close()
			main_menu_requested.emit()
