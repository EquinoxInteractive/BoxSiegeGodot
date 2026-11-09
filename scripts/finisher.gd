class_name Finisher
extends Node2D
## FINISHER kill terakhir (skin senjata LV3) - mirip finisher Valorant: layar menggelap, bar sinematik, kamera mendekat,
## lalu korban terakhir dihabisi dengan animasi khas skin (lubang hitam, petir, abu, glitch, es pecah, naik ke langit, kelopak,
## supernova, lumer racun, hujan emas, tebasan prisma) + banner nama finisher.
##
## Seluruh animasi dihitung dari waktu `t` (bukan state), jadi aman dipakai di game, Replay (ikut jeda / slow-mo lewat
## grup "cos_fx") dan preview Shop / Inventory (loop).

signal finished

const D := 3.6                    # durasi total (detik)
const CAM_ZOOM := 0.45            # tambahan zoom kamera ke korban (1.0 + 0.45 = 1.45x)
const CAM_FOCUS := 0.75           # 0 = kamera tetap di tengah, 1 = korban tepat di tengah layar

var kind: String = "shatter"
var c1: Color = Color.WHITE
var c2: Color = Color.WHITE
var weapon: String = "smith"      # jenis senjata -> tambahan kecil di awal (tracer / lingkaran suara / tebasan / api)
var title: String = ""            # nama skin senjata (banner)
var victim_tex: Texture2D
var vpos: Vector2 = Vector2.ZERO
var kpos: Vector2 = Vector2.ZERO  # posisi pembunuh (arah tracer)
var usize: float = 60.0           # ukuran korban (px)
var bounds: Rect2 = Rect2(0, 0, 1280, 720)
var cam: Camera2D = null          # kalau diisi: kamera mendekat ke korban
var view: Node2D = null           # kalau diisi (Replay): dunia di-zoom lewat transform node ini, hasilnya sama dengan kamera game
var show_text: bool = true        # false = tanpa banner nama finisher (dipakai ingame supaya layar bersih)
var t: float = 0.0
var speed: float = 1.0
var active: bool = true
var loop: bool = false            # preview: ulang terus
var manual: bool = false
var sfx_on: bool = true           # false = tanpa suara (Replay dengan efek suara dimatikan / kecepatan tinggi / sedang digeser)

var _u: float = 1.0
var _sc: float = 1.0
var _vsp: Sprite2D
var _mat: ShaderMaterial
var _front: Node2D
var _cam_pos0: Vector2 = Vector2.ZERO
var _cam_zoom0: Vector2 = Vector2.ONE
var _cam_saved: bool = false
var _ov_z: float = 1.0               # zoom kamera saat ini (overlay layar dibuat anti-zoom)
var _ov_tl: Vector2 = Vector2.ZERO   # pojok kiri-atas layar dalam koordinat dunia
var _snd: AudioStreamPlayer = null   # suara finisher (satu suara per JENIS finisher, lihat finisher_synth.gd)
var _snd_on: bool = false            # true = suara sedang berjalan
var _snd_prev_t: float = 0.0         # nilai t pada pengecekan suara sebelumnya (deteksi ulang / loncat mundur)


class FrontLayer extends Node2D:
	var f: Finisher
	func _draw() -> void:
		if f != null:
			f._draw_front(self)


func _ready() -> void:
	add_to_group("cos_fx")
	z_index = 300
	z_as_relative = false
	_u = usize / 60.0
	_sc = bounds.size.y / 720.0
	_vsp = Sprite2D.new()
	_vsp.texture = victim_tex
	_mat = FxShaders.victim_material()
	_vsp.material = _mat
	_vsp.position = vpos
	if victim_tex != null:
		_vsp.scale = Vector2.ONE * (usize / float(victim_tex.get_width()))
	add_child(_vsp)
	_front = FrontLayer.new()
	(_front as FrontLayer).f = self
	add_child(_front)
	if cam != null:
		_cam_pos0 = cam.position
		_cam_zoom0 = cam.zoom
		_cam_saved = true
	elif view != null:
		# transform dasar dunia disimpan SEKALI di node itu sendiri (aman bila beberapa finisher bergantian saat seek)
		if not view.has_meta("fin_base_pos"):
			view.set_meta("fin_base_pos", view.position)
			view.set_meta("fin_base_scale", view.scale)
		_cam_pos0 = Vector2.ZERO
		_cam_zoom0 = Vector2.ONE
		_cam_saved = true
	_update_victim()
	_update_cam()
	_make_audio()


func set_fx_speed(s: float) -> void:
	speed = s
	_sync_audio()


## Dipakai Replay: waktu `t` diatur dari luar (manual = true); gambar ulang saat dijeda / digeser.
func refresh() -> void:
	if _vsp == null:
		return
	_update_victim()
	_update_cam()
	queue_redraw()
	_front.queue_redraw()
	_sync_audio()


func restart() -> void:
	t = 0.0
	active = true


func _exit_tree() -> void:
	_restore_cam()


func _restore_cam() -> void:
	if not _cam_saved:
		return
	if cam != null and is_instance_valid(cam):
		cam.zoom = _cam_zoom0
		cam.position = _cam_pos0
	elif view != null and is_instance_valid(view) and view.has_meta("fin_base_pos"):
		view.position = view.get_meta("fin_base_pos")
		view.scale = view.get_meta("fin_base_scale")
	_cam_saved = false


func _process(delta: float) -> void:
	if not active:
		return
	if not manual:
		t += delta * speed
	if t >= D:
		if loop:
			t = 0.0
		else:
			active = false
			_restore_cam()
			finished.emit()
			queue_free()
			return
	_update_victim()
	_update_cam()
	queue_redraw()
	_front.queue_redraw()
	_sync_audio()


# ================================================================== suara
## Suara finisher: satu suara untuk setiap JENIS finisher (finisher yang sama = suara yang sama), dibuat lewat kode di
## finisher_synth.gd dan disusun persis mengikuti waktu animasi (t = 0 benturan kill ... t = D selesai).
func _make_audio() -> void:
	var st: AudioStreamWAV = Global.get_synth("fin_" + kind)
	if st == null:
		return
	_snd = AudioStreamPlayer.new()
	_snd.stream = st
	_snd.bus = FinisherSynth.bus_of(kind)
	_snd.volume_db = FinisherSynth.gain_of(kind)
	add_child(_snd)
	_sync_audio()


## Menjaga suara tetap selaras dengan animasi.
##   Game / preview Shop : suara dimulai bersama animasi dan berjalan sendiri; kalau animasi mengulang (loop / restart) suara ikut.
##   Replay (manual)     : waktu diatur dari luar -> jeda = suara berhenti, kecepatan = nada ikut, loncat / geser waktu = posisi
##                         suara dipindah ke waktu yang sama (tidak berbunyi saat dijeda / digeser, sama seperti suara ronde).
func _sync_audio() -> void:
	if _snd == null:
		return
	var go: bool = sfx_on and active and t < D - 0.02 and is_visible_in_tree()
	if manual:
		go = go and speed > 0.01
	if not go:
		if _snd_on:
			_snd.stop()
			_snd_on = false
		_snd_prev_t = t
		return
	if manual:
		_snd.pitch_scale = clampf(speed, 0.25, 4.0)
	var start: float = clampf(t, 0.0, D - 0.05)
	if not _snd_on:
		_snd.play(start)
		_snd_on = true
	elif t < _snd_prev_t - 0.05:
		_snd.play(start)
	elif manual:
		var pos: float = _snd.get_playback_position() + AudioServer.get_time_since_last_mix()
		if absf(pos - t) > 0.25:
			_snd.play(start)
	_snd_prev_t = t


# ================================================================== kamera
func _update_cam() -> void:
	if not _cam_saved:
		return
	var use_cam: bool = cam != null and is_instance_valid(cam)
	var use_view: bool = (not use_cam) and view != null and is_instance_valid(view) and view.has_meta("fin_base_pos")
	if not use_cam and not use_view:
		return
	# k = 0 -> kamera normal, k = 1 -> zoom penuh ke korban. Masuk cepat (0.45 dtk), keluar halus di akhir finisher.
	var k: float = smoothstep(0.0, 0.45, t) * (1.0 - smoothstep(D - 0.8, D, t))
	var z: float = 1.0 + CAM_ZOOM * k
	_ov_z = z
	# Ukuran & pusat tampilan normal (setara kamera FIXED_TOP_LEFT: position = pojok kiri-atas dunia yang terlihat)
	var base_size: Vector2 = bounds.size / _cam_zoom0.x
	var base_center: Vector2 = _cam_pos0 + base_size * 0.5
	# pusat tampilan bergeser ke arah korban supaya korban terlihat jelas, tapi tidak keluar dari area arena
	var center: Vector2 = base_center.lerp(vpos, CAM_FOCUS * k)
	var view_size: Vector2 = base_size / z
	var tl: Vector2 = center - view_size * 0.5
	tl.x = clampf(tl.x, _cam_pos0.x, _cam_pos0.x + base_size.x - view_size.x)
	tl.y = clampf(tl.y, _cam_pos0.y, _cam_pos0.y + base_size.y - view_size.y)
	tl += _shake_off()
	_ov_tl = tl
	if use_cam:
		cam.zoom = _cam_zoom0 * z
		cam.position = tl
	else:
		# Replay: tidak ada Camera2D, jadi dunia digeser + diskala (hasil di layar identik dengan kamera di game)
		var bp: Vector2 = view.get_meta("fin_base_pos")
		var bs: Vector2 = view.get_meta("fin_base_scale")
		view.scale = bs * z
		view.position = bp - tl * bs * z


# ================================================================== korban (sprite dengan shader)
func _set_v(pos: Vector2, rot: float, scl: Vector2, alpha: float, tint: Color, mode: int, amount: float, edge: Color) -> void:
	_vsp.position = pos
	_vsp.rotation = rot
	var base: float = (usize / float(victim_tex.get_width())) if victim_tex != null else 1.0
	_vsp.scale = scl * base
	_vsp.modulate = Color(1, 1, 1, alpha)
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("mode", mode)
	_mat.set_shader_parameter("amount", amount)
	_mat.set_shader_parameter("edge_col", edge)
	_mat.set_shader_parameter("fx_t", t)


func _update_victim() -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var W := Color(1, 1, 1, 1)
	_vsp.visible = true
	match kind:
		"blackhole":
			var e: float = pow(clampf((t - 0.9) / 1.3, 0.0, 1.0), 2.0)
			var wob := Vector2(sin(t * 40.0), cos(t * 33.0)) * 1.2 * u * smoothstep(0.5, 1.0, t) * (1.0 - e)
			_set_v(V + wob, e * TAU * 3.0, Vector2.ONE * (1.0 - e * 0.97), 1.0 - e * 0.3, W.lerp(Color(0.5, 0.35, 0.9), smoothstep(0.7, 1.5, t) * 0.6), 0, 0.0, c1)
			_vsp.visible = t < 2.3
		"lightning":
			var hit: float = t - 0.55
			var tint: Color = W
			var pos: Vector2 = V
			var alpha: float = 1.0
			if hit > 0.0 and hit < 0.7:
				var fl: float = 1.0 if int(t * 28.0) % 2 == 0 else 0.0
				tint = Color(2.4, 2.4, 2.8, 1.0) if fl > 0.5 else Color(0.08, 0.1, 0.2, 1.0)
				pos += Vector2(sin(t * 90.0), cos(t * 77.0)) * 3.0 * u
			elif hit >= 0.7:
				var k: float = clampf((hit - 0.7) / 0.9, 0.0, 1.0)
				tint = Color(0.12, 0.12, 0.14, 1.0)
				alpha = 1.0 - k
			_set_v(pos, 0.0, Vector2.ONE, alpha, tint, 0, 0.0, c1)
		"inferno":
			var k2: float = clampf((t - 0.6) / 1.6, 0.0, 1.0)
			var dark: float = lerpf(1.0, 0.18, smoothstep(0.2, 1.2, t))
			_set_v(V, 0.0, Vector2.ONE, 1.0, Color(dark + 0.5 * (1.0 - dark) * 0.0, dark * 0.8, dark * 0.7, 1.0), 1, k2, c2)
			_vsp.visible = t < 2.4
		"glitch":
			var am: float = clampf((t - 0.1) / 0.8, 0.0, 1.0)
			var jump := Vector2.ZERO
			if t > 0.1 and t < 2.0 and FxDraw.h(floorf(t * 12.0), 3.0) > 0.55:
				jump = Vector2((FxDraw.h(floorf(t * 12.0), 4.0) - 0.5) * 12.0 * u, 0.0)
			var scl := Vector2.ONE
			var alpha2: float = 1.0
			if t > 2.0:
				var k3: float = clampf((t - 2.0) / 0.5, 0.0, 1.0)
				var k4: float = clampf((t - 2.35) / 0.2, 0.0, 1.0)
				scl = Vector2(1.0 - k4, lerpf(1.0, 0.03, smoothstep(0.0, 1.0, k3)))
				alpha2 = 1.0 - k4
			_set_v(V + jump, 0.0, scl, alpha2, W, 2, am, c1)
			_vsp.visible = t < 2.56
		"shatter":
			var fr: float = smoothstep(0.1, 0.9, t)
			var tint2: Color = W.lerp(Color(0.55, 0.88, 1.0), fr)
			_set_v(V, 0.0, Vector2.ONE, 1.0, tint2, 0, 0.0, c1)
			_vsp.visible = t < 1.3
		"ascend":
			var rise: float = pow(clampf((t - 0.9) / 1.5, 0.0, 1.0), 1.6)
			var alpha3: float = 1.0 - smoothstep(1.9, 2.7, t)
			var glow: float = smoothstep(0.3, 1.4, t)
			_set_v(V + Vector2(0, -rise * 150.0 * u), 0.0, Vector2.ONE * (1.0 + rise * 0.1), alpha3, W.lerp(Color(1.5, 1.3, 0.8, 1.0), glow), 0, 0.0, c1)
		"petals":
			var k5: float = clampf((t - 0.5) / 1.3, 0.0, 1.0)
			_set_v(V + Vector2(0, -k5 * 18.0 * u), k5 * 1.2, Vector2.ONE * (1.0 + k5 * 0.12), 1.0, W.lerp(Color(1.4, 1.0, 1.2), smoothstep(0.1, 0.6, t)), 1, k5, c1)
			_vsp.visible = t < 1.9
		"cosmic":
			var k6: float = smoothstep(0.7, 1.6, t)
			_set_v(V, 0.0, Vector2.ONE, 1.0 - k6, W.lerp(Color(0.3, 0.35, 1.0), smoothstep(0.1, 0.7, t) * 0.8), 0, 0.0, c1)
			_vsp.visible = t < 1.7
		"toxic":
			var m: float = smoothstep(0.5, 2.1, t)
			var sx: float = lerpf(1.0, 1.55, m)
			var sy: float = lerpf(1.0, 0.1, m)
			var ground: Vector2 = V + Vector2(0, usize * 0.5)
			var a4: float = 1.0 - smoothstep(2.3, 2.9, t)
			_set_v(ground + Vector2(0, -usize * sy * 0.5), 0.0, Vector2(sx, sy), a4, W.lerp(Color(0.5, 1.0, 0.35), smoothstep(0.05, 0.6, t)), 0, 0.0, c1)
		"jackpot":
			var gold: float = smoothstep(0.1, 0.7, t)
			var fl2: float = 0.5 + 0.5 * sin(t * 24.0)
			_set_v(V, 0.0, Vector2.ONE, 1.0, W.lerp(Color(1.5 + 0.3 * fl2, 1.15 + 0.2 * fl2, 0.4, 1.0), gold), 0, 0.0, c1)
			_vsp.visible = t < 1.7
		"slice":
			_set_v(V, 0.0, Vector2.ONE, 1.0, W, 0, 0.0, c1)
			_vsp.visible = t < 0.95
		"meteor": _v_meteor()
		"tsunami": _v_tsunami()
		"reaper": _v_reaper()
		"portal": _v_portal()
		"sands": _v_sands()
		"firework": _v_firework()
		"orbital": _v_orbital()
		"hex": _v_hex()
		"balloon": _v_balloon()
		"ufo": _v_ufo()
		_:
			_set_v(V, 0.0, Vector2.ONE, 1.0, W, 0, 0.0, c1)


# ================================================================== lapisan layar + efek belakang (di bawah sprite korban)
func _vig() -> float:
	return smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(D - 0.6, D, t))


func _draw() -> void:
	# redup layar
	var vg: float = _vig()
	var dark: Color = Color(0, 0, 0, 0.62 * vg)
	if kind == "cosmic":
		dark = Color(0.02, 0.0, 0.1, 0.72 * vg)
	elif kind == "lightning":
		dark = Color(0.0, 0.0, 0.05, 0.7 * vg)
	elif kind == "tsunami":
		dark = Color(0.0, 0.03, 0.1, 0.66 * vg)
	elif kind == "firework" or kind == "ufo":
		dark = Color(0.0, 0.0, 0.07, 0.72 * vg)
	elif kind == "reaper" or kind == "hex":
		dark = Color(0.02, 0.0, 0.05, 0.7 * vg)
	draw_rect(bounds, dark)
	_twist_back(self)
	match kind:
		"blackhole": _back_blackhole(self)
		"lightning": _back_lightning(self)
		"inferno": _back_inferno(self)
		"glitch": _back_glitch(self)
		"shatter": _back_shatter(self)
		"ascend": _back_ascend(self)
		"petals": _back_petals(self)
		"cosmic": _back_cosmic(self)
		"toxic": _back_toxic(self)
		"jackpot": _back_jackpot(self)
		"slice": _back_slice(self)
		"meteor": _back_meteor(self)
		"tsunami": _back_tsunami(self)
		"reaper": _back_reaper(self)
		"portal": _back_portal(self)
		"sands": _back_sands(self)
		"firework": _back_firework(self)
		"orbital": _back_orbital(self)
		"hex": _back_hex(self)
		"balloon": _back_balloon(self)
		"ufo": _back_ufo(self)


## tambahan kecil menurut jenis senjata (di awal)
func _twist_back(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	match weapon:
		"flamer":
			for k in 3:
				var tt: float = t - 0.05 - float(k) * 0.12
				if tt > 0.0 and tt < 0.5:
					var f: float = tt / 0.5
					ci.draw_arc(V + Vector2(0, usize * 0.45), (14.0 + f * 80.0) * u, 0.0, TAU, 40, FxDraw.ca(c2, (1.0 - f) * 0.7), 5.0 * u * (1.0 - f) + 1.0, true)
		"scream":
			for k in 4:
				var tt2: float = t - float(k) * 0.1
				if tt2 > 0.0 and tt2 < 0.6:
					var f2: float = tt2 / 0.6
					ci.draw_arc(V, (10.0 + f2 * 120.0) * u, 0.0, TAU, 48, FxDraw.ca(c1, (1.0 - f2) * 0.8), 4.0 * u * (1.0 - f2) + 1.0, true)


func _back_blackhole(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var grow: float = smoothstep(0.1, 0.9, t)
	var col: float = 1.0 - smoothstep(2.1, 2.45, t)
	var R: float = 44.0 * u * grow * col
	if R < 0.5:
		return
	# lensa gravitasi (cincin redup)
	for k in 4:
		ci.draw_circle(V, R * (2.3 - float(k) * 0.35), Color(0.35, 0.1, 0.6, 0.06 * grow * col))
	# cakram akresi (belakang)
	for i in 46:
		var a: float = float(i) * TAU / 46.0 + t * (2.0 + 1.6 * float(i % 3))
		if sin(a) <= 0.0:
			var rr: float = R * (1.25 + 0.7 * FxDraw.h(float(i)))
			var pos: Vector2 = V + Vector2(cos(a) * rr, sin(a) * rr * 0.28)
			FxDraw.glow_dot(ci, pos, 2.2 * u, FxDraw.ca(c1.lerp(c2, FxDraw.h(float(i), 2.0)), 0.8 * col))
	ci.draw_circle(V, R * 1.05, Color(c1.r, c1.g, c1.b, 0.35 * col))
	ci.draw_circle(V, R, Color(0.01, 0.0, 0.03, 1.0))


func _back_lightning(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	# awan petir menggelap di atas
	var cl: float = smoothstep(0.0, 0.5, t) * (1.0 - smoothstep(2.6, 3.3, t))
	for k in 9:
		var cx: float = bounds.position.x + bounds.size.x * (float(k) / 8.0)
		ci.draw_circle(Vector2(cx, bounds.position.y + 14.0 * _sc), 130.0 * _sc, Color(0.05, 0.07, 0.15, 0.55 * cl))
	# garis pengisi sebelum menyambar
	if t > 0.15 and t < 0.55:
		var f: float = (t - 0.15) / 0.4
		for k in 3:
			var sd: float = floorf(t * 30.0) + float(k) * 11.0
			var top := Vector2(V.x + (FxDraw.h(sd) - 0.5) * 80.0 * u, V.y - 200.0 * u * f)
			FxDraw.bolt(ci, top, top + Vector2((FxDraw.h(sd, 1.0) - 0.5) * 30.0, 60.0 * u), sd, FxDraw.ca(c1, 0.6 * f), 1.6, 5, 6.0 * u)
	# bekas hangus di tanah
	if t > 0.6:
		var sc2: float = smoothstep(0.6, 0.9, t) * (1.0 - smoothstep(3.0, 3.5, t))
		ci.draw_circle(V + Vector2(0, usize * 0.5), 26.0 * u * sc2, Color(0, 0, 0, 0.5 * sc2))


func _back_inferno(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var g: float = smoothstep(0.1, 0.9, t) * (1.0 - smoothstep(2.4, 3.2, t))
	if g <= 0.01:
		return
	var base_y: float = V.y + usize * 0.5
	# kolom api (belakang)
	for k in 12:
		var x: float = V.x + (float(k) - 5.5) * 7.5 * u
		var hh: float = (95.0 + 60.0 * FxDraw.h(float(k))) * u * g * (0.8 + 0.25 * sin(t * 9.0 + float(k) * 1.9))
		var sw: float = sin(t * 6.0 + float(k)) * 8.0 * u
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 8.0 * u, base_y), Vector2(x + sw, base_y - hh), Vector2(x + 8.0 * u, base_y)]), FxDraw.ca(c2, 0.55))
	ci.draw_circle(V, 70.0 * u * g, FxDraw.ca(c1, 0.10))


func _back_glitch(ci: CanvasItem) -> void:
	var vg: float = _vig()
	# garis scan di seluruh layar
	var step_: float = maxf(6.0 * _sc, 2.0)
	var y: float = bounds.position.y
	while y < bounds.end.y:
		ci.draw_rect(Rect2(bounds.position.x, y, bounds.size.x, maxf(1.0, step_ * 0.3)), Color(0, 0, 0, 0.18 * vg))
		y += step_
	var by: float = bounds.position.y + fposmod(t * 340.0 * _sc, bounds.size.y)
	ci.draw_rect(Rect2(bounds.position.x, by, bounds.size.x, 18.0 * _sc), FxDraw.ca(c1, 0.10 * vg))
	# potongan layar bergeser
	for k in 6:
		var sd: float = floorf(t * 10.0) + float(k) * 7.0
		if FxDraw.h(sd, 2.0) > 0.5:
			var yy: float = bounds.position.y + FxDraw.h(sd, 3.0) * bounds.size.y
			ci.draw_rect(Rect2(bounds.position.x, yy, bounds.size.x, 3.0 + FxDraw.h(sd, 4.0) * 8.0 * _sc), FxDraw.ca(c1 if k % 2 == 0 else c2, 0.14 * vg))


func _back_shatter(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var g: float = smoothstep(0.1, 0.9, t)
	if t < 1.3:
		for k in 9:
			var a: float = float(k) * TAU / 9.0 + 0.3
			var ln: float = (34.0 + 26.0 * FxDraw.h(float(k))) * u * g
			var d := Vector2(cos(a), sin(a))
			FxDraw.diamond(ci, V + d * ln * 0.55, 7.0 * u * g, ln * 0.55, FxDraw.ca(c1, 0.8), a + PI * 0.5)
		ci.draw_circle(V, 60.0 * u * g, FxDraw.ca(c1, 0.12))
	# kabut dingin di lantai
	var fog: float = smoothstep(0.1, 1.2, t) * (1.0 - smoothstep(2.8, 3.5, t))
	ci.draw_circle(V + Vector2(0, usize * 0.5), 60.0 * u, Color(0.6, 0.9, 1.0, 0.10 * fog))


func _back_ascend(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var g: float = smoothstep(0.15, 0.7, t) * (1.0 - smoothstep(2.5, 3.2, t))
	if g <= 0.01:
		return
	var w: float = 54.0 * u * g
	var top: float = bounds.position.y
	var bot: float = V.y + usize * 0.55
	var pts := PackedVector2Array([Vector2(V.x - w, top), Vector2(V.x + w, top), Vector2(V.x + w * 0.8, bot), Vector2(V.x - w * 0.8, bot)])
	var cols := PackedColorArray([FxDraw.ca(c1, 0.0), FxDraw.ca(c1, 0.0), FxDraw.ca(c1, 0.55 * g), FxDraw.ca(c1, 0.55 * g)])
	ci.draw_polygon(pts, cols)
	var w2: float = w * 0.45
	ci.draw_polygon(PackedVector2Array([Vector2(V.x - w2, top), Vector2(V.x + w2, top), Vector2(V.x + w2 * 0.8, bot), Vector2(V.x - w2 * 0.8, bot)]),
		PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.0), Color(1, 1, 0.9, 0.5 * g), Color(1, 1, 0.9, 0.5 * g)]))
	# cincin cahaya di lantai
	for k in 3:
		var f: float = fposmod(t * 0.9 + float(k) / 3.0, 1.0)
		ci.draw_arc(Vector2(V.x, bot), (16.0 + f * 70.0) * u, 0.0, TAU, 36, FxDraw.ca(c1, (1.0 - f) * 0.6 * g), 3.0 * u, true)
	# sayap di belakang korban
	var wg: float = smoothstep(0.8, 1.5, t) * (1.0 - smoothstep(2.2, 2.8, t))
	if wg > 0.01:
		var rise: float = pow(clampf((t - 0.9) / 1.5, 0.0, 1.0), 1.6)
		var cen: Vector2 = V + Vector2(0, -rise * 150.0 * u)
		var flap: float = sin(t * 7.0) * 0.14
		for s in 2:
			var sx: float = 1.0 if s == 0 else -1.0
			for k in 5:
				var th: float = 0.2 + float(k) * 0.3 + flap
				var ln: float = (70.0 - float(k) * 6.0) * u * wg
				var base: Vector2 = cen + Vector2(sx * 16.0 * u, -4.0 * u)
				var tip: Vector2 = base + Vector2(sx * cos(th), -sin(th)) * ln
				var nrm: Vector2 = (tip - base).orthogonal().normalized() * 9.0 * u * wg
				ci.draw_colored_polygon(PackedVector2Array([base, base + (tip - base) * 0.5 + nrm, tip, base + (tip - base) * 0.5 - nrm]), Color(1, 1, 1, 0.85 * wg))


func _back_petals(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var g: float = smoothstep(0.1, 0.8, t) * (1.0 - smoothstep(2.6, 3.3, t))
	ci.draw_circle(V, 70.0 * u * g, FxDraw.ca(c1, 0.10))
	for i in 50:
		var lay: float = float(i % 3)
		var a: float = float(i) * 2.399 + t * (2.2 + lay * 0.8)
		if sin(a) <= 0.0:
			_petal_at(ci, V, i, a, g, 0.7)


func _petal_at(ci: CanvasItem, V: Vector2, i: int, a: float, g: float, al: float) -> void:
	var u: float = _u
	var f: float = fposmod(float(i) * 0.137 + t * 0.35, 1.0)
	var spread: float = smoothstep(1.7, 3.0, t)
	var r: float = (18.0 + 52.0 * f) * u * (1.0 + spread * 2.2)
	var pos: Vector2 = V + Vector2(cos(a) * r, sin(a) * r * 0.45 - f * 70.0 * u + spread * f * 60.0 * u)
	var alpha: float = g * al * (1.0 - smoothstep(3.0, 3.5, t))
	FxDraw.petal(ci, pos, (5.0 + 3.0 * FxDraw.h(float(i))) * u, a * 2.0, FxDraw.ca(c1.lerp(c2, FxDraw.h(float(i), 3.0) * 0.6), alpha))


func _back_cosmic(ci: CanvasItem) -> void:
	var vg: float = _vig()
	for i in 70:
		var pos := Vector2(bounds.position.x + FxDraw.h(float(i), 1.0) * bounds.size.x, bounds.position.y + FxDraw.h(float(i), 2.0) * bounds.size.y)
		var tw: float = 0.5 + 0.5 * sin(t * (2.0 + 4.0 * FxDraw.h(float(i), 3.0)) + float(i))
		ci.draw_circle(pos, (0.8 + 1.8 * FxDraw.h(float(i), 4.0)) * _sc, Color(1, 1, 1, 0.8 * tw * vg))
	var V: Vector2 = vpos
	var nb: float = smoothstep(1.5, 2.2, t) * (1.0 - smoothstep(2.8, 3.5, t))
	ci.draw_circle(V, 130.0 * _u * nb, FxDraw.ca(c2, 0.08))
	ci.draw_circle(V, 80.0 * _u * nb, FxDraw.ca(c1, 0.10))


func _back_toxic(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var m: float = smoothstep(0.5, 2.1, t)
	var fade: float = 1.0 - smoothstep(2.9, 3.5, t)
	var gy: float = V.y + usize * 0.5
	var pw: float = (16.0 + 56.0 * m) * u
	ci.draw_colored_polygon(_ellipse_pts(Vector2(V.x, gy), pw, 8.0 * u * (0.3 + m), 24), FxDraw.ca(c1.darkened(0.25), 0.9 * fade))
	ci.draw_colored_polygon(_ellipse_pts(Vector2(V.x, gy - 1.0 * u), pw * 0.85, 5.5 * u * (0.3 + m), 24), FxDraw.ca(c1.lightened(0.15), 0.8 * fade))


func _back_jackpot(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var g: float = smoothstep(0.2, 0.9, t) * (1.0 - smoothstep(2.6, 3.3, t))
	ci.draw_set_transform(V, 0.0, Vector2.ONE)
	for k in 14:
		FxDraw.ray_tri(ci, t * 0.6 + float(k) * TAU / 14.0, 260.0 * _u * g, 0.09, FxDraw.ca(c1, 0.22 * g))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_circle(V, 80.0 * _u * g, FxDraw.ca(c1, 0.12))


func _back_slice(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var g: float = _vig()
	ci.draw_circle(V, 90.0 * _u, FxDraw.ca(Color.WHITE, 0.05 * g))


func _ellipse_pts(c: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a: float = float(k) / float(n) * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


# ================================================================== lapisan DEPAN (di atas korban) + overlay layar
func _draw_front(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	_twist_front(ci)
	match kind:
		"blackhole": _front_blackhole(ci)
		"lightning": _front_lightning(ci)
		"inferno": _front_inferno(ci)
		"glitch": _front_glitch(ci)
		"shatter": _front_shatter(ci)
		"ascend": _front_ascend(ci)
		"petals": _front_petals(ci)
		"cosmic": _front_cosmic(ci)
		"toxic": _front_toxic(ci)
		"jackpot": _front_jackpot(ci)
		"slice": _front_slice(ci)
		"meteor": _front_meteor(ci)
		"tsunami": _front_tsunami(ci)
		"reaper": _front_reaper(ci)
		"portal": _front_portal(ci)
		"sands": _front_sands(ci)
		"firework": _front_firework(ci)
		"orbital": _front_orbital(ci)
		"hex": _front_hex(ci)
		"balloon": _front_balloon(ci)
		"ufo": _front_ufo(ci)
	_overlay(ci)


func _twist_front(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	match weapon:
		"smith", "kurval", "pistol":
			if t < 0.3:
				var dir: Vector2 = (V - kpos)
				if dir.length() < 1.0:
					dir = Vector2.RIGHT
				dir = dir.normalized()
				var nrm: Vector2 = dir.orthogonal()
				for k in 4:
					var f: float = clampf(t / 0.12 - float(k) * 0.12, 0.0, 1.0)
					var off: Vector2 = nrm * (float(k) - 1.5) * 5.0 * u
					var a: Vector2 = V - dir * 300.0 * u * (1.0 - f) + off
					var b: Vector2 = a - dir * 90.0 * u
					ci.draw_line(b, a, FxDraw.ca(c1.lerp(Color.WHITE, 0.4), (1.0 - t / 0.3)), 2.2 * u)
		"knife":
			if t > 0.03 and t < 0.38:
				var f2: float = (t - 0.03) / 0.35
				var al: float = 1.0 - f2
				var l: float = 70.0 * u * minf(1.0, f2 * 5.0)
				ci.draw_line(V + Vector2(-l, -l * 0.8), V + Vector2(l, l * 0.8), Color(1, 1, 1, al), 3.0 * u * al + 1.0)
				ci.draw_line(V + Vector2(l, -l * 0.8), V + Vector2(-l, l * 0.8), FxDraw.ca(c1.lerp(Color.WHITE, 0.5), al), 3.0 * u * al + 1.0)


func _front_blackhole(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var grow: float = smoothstep(0.1, 0.9, t)
	var col: float = 1.0 - smoothstep(2.1, 2.45, t)
	var R: float = 44.0 * u * grow * col
	if R > 0.5:
		for i in 46:
			var a: float = float(i) * TAU / 46.0 + t * (2.0 + 1.6 * float(i % 3))
			if sin(a) > 0.0:
				var rr: float = R * (1.25 + 0.7 * FxDraw.h(float(i)))
				var pos: Vector2 = V + Vector2(cos(a) * rr, sin(a) * rr * 0.28)
				FxDraw.glow_dot(ci, pos, 2.4 * u, FxDraw.ca(c1.lerp(c2, FxDraw.h(float(i), 2.0)), 0.95 * col))
		ci.draw_arc(V, R * 1.02, 0.0, TAU, 48, FxDraw.ca(c2, 0.9 * col), 3.0 * u, true)
		ci.draw_arc(V, R * 1.35, t * 2.0, t * 2.0 + PI * 1.2, 24, FxDraw.ca(c1, 0.8 * col), 2.5 * u, true)
		# partikel terhisap
		for i in 26:
			var p: Vector2 = FxDraw.ph(t, i, 26, 0.9)
			var a2: float = FxDraw.rnd(i, p.y, 1.0) * TAU + p.x * 4.0
			var r2: float = (110.0 * (1.0 - p.x) + 6.0) * u
			FxDraw.glow_dot(ci, V + Vector2(cos(a2), sin(a2)) * r2, 1.8 * u * (1.0 - p.x) + 0.5, FxDraw.ca(c1.lerp(c2, p.x), minf(1.0, p.x * 3.0) * grow))
	# keruntuhan: gelombang kejut
	if t > 2.25:
		var f: float = clampf((t - 2.25) / 0.8, 0.0, 1.0)
		ci.draw_arc(V, (12.0 + 190.0 * f) * u, 0.0, TAU, 56, FxDraw.ca(c2, (1.0 - f)), 7.0 * u * (1.0 - f) + 1.0, true)
		ci.draw_arc(V, (6.0 + 130.0 * f) * u, 0.0, TAU, 48, Color(1, 1, 1, (1.0 - f) * 0.9), 3.0 * u, true)
		if t < 2.45:
			ci.draw_circle(V, 40.0 * u * (1.0 - (t - 2.25) / 0.2), Color(1, 1, 1, 0.9))


func _front_lightning(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var hit: float = t - 0.55
	if hit > 0.0 and hit < 0.5:
		var f: float = hit / 0.5
		var sd: float = floorf(hit * 22.0)
		var top := Vector2(V.x + (FxDraw.h(sd) - 0.5) * 50.0 * u, bounds.position.y - 10.0)
		var col: Color = FxDraw.ca(c1, 1.0 - f * 0.6)
		FxDraw.bolt(ci, top, V + Vector2(0, -usize * 0.35), sd, col, 9.0 * u, 12, 22.0 * u)
		for k in 4:
			var s2: float = sd * 3.0 + float(k)
			var sp: Vector2 = top.lerp(V, 0.25 + 0.15 * float(k))
			FxDraw.bolt(ci, sp, sp + Vector2((FxDraw.h(s2) - 0.5) * 190.0 * u, 60.0 * u), s2, FxDraw.ca(c1, 0.7 * (1.0 - f)), 3.0 * u, 6, 10.0 * u)
	if hit > 0.0 and hit < 0.4:
		var f2: float = hit / 0.4
		for k in 3:
			var s3: float = floorf(hit * 20.0) * 5.0 + float(k)
			var a: float = FxDraw.h(s3) * TAU
			var ground := Vector2(V.x, V.y + usize * 0.45)
			FxDraw.bolt(ci, ground, ground + Vector2(cos(a) * 90.0 * u, -absf(sin(a)) * 24.0 * u), s3, FxDraw.ca(c2, 1.0 - f2), 2.4 * u, 6, 8.0 * u)
	# percikan
	if hit > 0.0:
		for i in 30:
			var a2: float = FxDraw.h(float(i), 5.0) * TAU
			var sp2: float = 60.0 + 190.0 * FxDraw.h(float(i), 6.0)
			var tt: float = hit
			var pos: Vector2 = V + Vector2(cos(a2) * sp2 * tt, sin(a2) * sp2 * tt + 260.0 * tt * tt) * u
			var al: float = clampf(1.0 - tt / 1.3, 0.0, 1.0)
			ci.draw_line(pos, pos - Vector2(cos(a2), sin(a2)) * 8.0 * u, FxDraw.ca(c2, al), 2.2 * u)
		# asap dari korban hangus
		if hit > 0.7:
			for i in 14:
				var p: Vector2 = FxDraw.ph(t, i, 14, 1.4)
				var pos2: Vector2 = V + Vector2((FxDraw.rnd(i, p.y, 1.0) - 0.5) * 30.0 * u + sin(p.x * 6.0) * 6.0 * u, -p.x * 90.0 * u)
				ci.draw_circle(pos2, (4.0 + 7.0 * p.x) * u, Color(0.2, 0.2, 0.24, 0.35 * (1.0 - p.x)))


func _front_inferno(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var g: float = smoothstep(0.1, 0.9, t) * (1.0 - smoothstep(2.4, 3.2, t))
	var base_y: float = V.y + usize * 0.5
	for k in 10:
		var x: float = V.x + (float(k) - 4.5) * 8.5 * u
		var hh: float = (70.0 + 50.0 * FxDraw.h(float(k), 2.0)) * u * g * (0.8 + 0.3 * sin(t * 11.0 + float(k) * 1.3))
		var sw: float = sin(t * 7.0 + float(k) * 2.0) * 7.0 * u
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 7.0 * u, base_y), Vector2(x + sw, base_y - hh), Vector2(x + 7.0 * u, base_y)]), FxDraw.ca(c1, 0.6))
		ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 3.5 * u, base_y), Vector2(x + sw * 0.6, base_y - hh * 0.6), Vector2(x + 3.5 * u, base_y)]), Color(1, 0.95, 0.7, 0.7))
	# serpihan abu + bara
	if t > 0.5:
		for i in 44:
			var p: Vector2 = FxDraw.ph(t - 0.5, i, 44, 1.8)
			var pos: Vector2 = V + Vector2((FxDraw.rnd(i, p.y, 1.0) - 0.5) * 60.0 * u + sin(p.x * 5.0 + float(i)) * 12.0 * u, 20.0 * u - p.x * 190.0 * u)
			var fl: float = 1.0 - smoothstep(0.55, 1.0, p.x)
			if i % 3 == 0:
				FxDraw.glow_dot(ci, pos, (1.4 + 1.6 * FxDraw.rnd(i, p.y, 2.0)) * u, FxDraw.ca(c1.lerp(c2, p.x), fl * g))
			else:
				ci.draw_rect(Rect2(pos, Vector2(3.0, 2.2) * u * (1.0 + FxDraw.rnd(i, p.y, 3.0))), Color(0.18, 0.16, 0.16, 0.85 * fl))
	# gelombang api awal
	if t < 0.7:
		var f: float = t / 0.7
		ci.draw_arc(V + Vector2(0, usize * 0.45), (10.0 + f * 100.0) * u, 0.0, TAU, 40, FxDraw.ca(c1, (1.0 - f)), 6.0 * u * (1.0 - f) + 1.0, true)
	# tumpukan abu di tanah
	var ash: float = smoothstep(1.4, 2.4, t) * (1.0 - smoothstep(3.0, 3.6, t))
	ci.draw_colored_polygon(_ellipse_pts(Vector2(V.x, base_y), 24.0 * u, 5.0 * u, 18), Color(0.12, 0.11, 0.11, 0.95 * ash))


func _front_glitch(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var g: float = clampf((t - 0.1) / 0.5, 0.0, 1.0)
	for k in 16:
		var sd: float = floorf(t * 11.0) + float(k) * 3.0
		if FxDraw.h(sd, 9.0) > 0.35:
			var pos: Vector2 = V + Vector2((FxDraw.h(sd, 1.0) - 0.5) * 120.0, (FxDraw.h(sd, 2.0) - 0.5) * 110.0) * u
			var sz := Vector2(4.0 + 16.0 * FxDraw.h(sd, 3.0), 3.0 + 8.0 * FxDraw.h(sd, 4.0)) * u
			var cc: Color = c1 if FxDraw.h(sd, 5.0) > 0.5 else c2
			ci.draw_rect(Rect2(pos, sz), FxDraw.ca(cc, 0.85 * g * (1.0 - smoothstep(2.4, 2.8, t))))
	if t > 0.3 and t < 2.4:
		var txt: String = "SYSTEM ERROR" if int(t * 6.0) % 2 == 0 else "FATAL 0xDEAD"
		var fs: int = maxi(int(26.0 * _sc), 10)
		var off := Vector2(FxDraw.h(floorf(t * 14.0)) * 6.0 * _sc, 0.0)
		var pos2: Vector2 = V + Vector2(-usize * 0.9, -usize * 0.75) + off
		ci.draw_string(Global.font_ui, pos2 + Vector2(2.0, 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, FxDraw.ca(c2, 0.8))
		ci.draw_string(Global.font_ui, pos2, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, FxDraw.ca(c1, 0.95))
	# TV-off
	if t > 2.3 and t < 2.9:
		var f: float = (t - 2.3) / 0.6
		var w: float = usize * 1.3 * (1.0 - smoothstep(0.0, 0.4, f))
		ci.draw_rect(Rect2(V.x - w * 0.5, V.y - 1.5 * u, w, 3.0 * u), Color(1, 1, 1, 1.0 - f))
		for i in 18:
			var p: float = f
			var a: float = FxDraw.h(float(i), 1.0) * TAU
			var pos3: Vector2 = V + Vector2(cos(a), sin(a)) * 90.0 * p * u * (0.4 + FxDraw.h(float(i), 2.0))
			ci.draw_rect(Rect2(pos3, Vector2(5.0, 5.0) * u), FxDraw.ca(c1 if i % 2 == 0 else c2, 1.0 - p))


func _front_shatter(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	# retakan
	if t > 0.85 and t < 1.3:
		var f: float = (t - 0.85) / 0.45
		for k in 9:
			var a: float = float(k) * TAU / 9.0 + FxDraw.h(float(k)) * 0.6
			var ln: float = (22.0 + 24.0 * FxDraw.h(float(k), 2.0)) * u * minf(1.0, f * 1.6)
			ci.draw_line(V, V + Vector2(cos(a), sin(a)) * ln, Color(1, 1, 1, 0.9), 1.6 * u)
	# pecahan
	if t >= 1.3 and victim_tex != null:
		var tt: float = t - 1.3
		var n: int = 6
		var cw: float = float(victim_tex.get_width()) / float(n)
		var ch: float = float(victim_tex.get_height()) / float(n)
		var dw: float = usize / float(n)
		var dh: float = usize / float(n)
		var fade: float = 1.0 - smoothstep(1.2, 2.2, tt)
		for gy in n:
			for gx in n:
				var idx: int = gy * n + gx
				var cen := Vector2((float(gx) + 0.5 - float(n) * 0.5) * dw, (float(gy) + 0.5 - float(n) * 0.5) * dh)
				var dir: Vector2 = cen.normalized() if cen.length() > 0.1 else Vector2.UP
				var spd: float = (90.0 + 160.0 * FxDraw.h(float(idx), 1.0)) * u
				var vel: Vector2 = dir * spd + Vector2(0, -90.0 * u * FxDraw.h(float(idx), 2.0))
				var pos: Vector2 = V + cen + vel * tt + Vector2(0, 420.0 * u * tt * tt)
				var rot: float = (FxDraw.h(float(idx), 3.0) - 0.5) * 10.0 * tt
				ci.draw_set_transform(pos, rot, Vector2.ONE)
				var tint: Color = Color(0.7, 0.92, 1.0, fade)
				ci.draw_texture_rect_region(victim_tex, Rect2(-dw * 0.5, -dh * 0.5, dw, dh), Rect2(float(gx) * cw, float(gy) * ch, cw, ch), tint)
				ci.draw_rect(Rect2(-dw * 0.5, -dh * 0.5, dw, dh), FxDraw.ca(c1, 0.22 * fade), false, 1.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# kilatan + gelombang
		if tt < 0.5:
			var f2: float = tt / 0.5
			ci.draw_circle(V, 50.0 * u * (1.0 - f2), Color(1, 1, 1, 0.9 * (1.0 - f2)))
			ci.draw_arc(V, (10.0 + 150.0 * f2) * u, 0.0, TAU, 48, FxDraw.ca(c1, 1.0 - f2), 6.0 * u * (1.0 - f2) + 1.0, true)
		for i in 26:
			var p: Vector2 = FxDraw.ph(tt, i, 26, 1.6)
			var a: float = FxDraw.rnd(i, p.y, 1.0) * TAU
			var pos2: Vector2 = V + Vector2(cos(a) * (30.0 + 120.0 * p.x), sin(a) * (30.0 + 120.0 * p.x) * 0.8) * u
			FxDraw.star4(ci, pos2, (3.0 + 4.0 * FxDraw.rnd(i, p.y, 2.0)) * u * (1.0 - p.x), FxDraw.ca(c2, 1.0 - p.x))
	# salju
	for i in 24:
		var p: Vector2 = FxDraw.ph(t, i, 24, 2.4)
		var pos3: Vector2 = V + Vector2((FxDraw.rnd(i, p.y, 7.0) - 0.5) * 220.0 * u + sin(p.x * 6.0) * 8.0 * u, -100.0 * u + p.x * 190.0 * u)
		ci.draw_circle(pos3, 1.8 * u, Color(0.85, 0.96, 1.0, 0.8 * sin(p.x * PI) * smoothstep(0.2, 0.8, t)))


func _front_ascend(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var rise: float = pow(clampf((t - 0.9) / 1.5, 0.0, 1.0), 1.6)
	var cen: Vector2 = V + Vector2(0, -rise * 150.0 * u)
	# halo
	var hg: float = smoothstep(0.6, 1.1, t) * (1.0 - smoothstep(2.3, 2.8, t))
	if hg > 0.01:
		var hp: Vector2 = cen + Vector2(0, -usize * 0.62)
		ci.draw_arc(hp, usize * 0.34, 0.0, TAU, 32, FxDraw.ca(c1.lerp(Color.WHITE, 0.3), 0.35 * hg), 7.0 * u, true)
		ci.draw_arc(hp, usize * 0.34, 0.0, TAU, 32, FxDraw.ca(c1, hg), 3.5 * u, true)
	# bulu & kilau
	for i in 26:
		var p: Vector2 = FxDraw.ph(t, i, 26, 2.2)
		var pos: Vector2 = V + Vector2((FxDraw.rnd(i, p.y, 1.0) - 0.5) * 120.0 * u + sin(p.x * 7.0 + float(i)) * 10.0 * u, 30.0 * u - p.x * 240.0 * u)
		var al: float = sin(p.x * PI) * smoothstep(0.3, 0.9, t)
		if i % 2 == 0:
			FxDraw.petal(ci, pos, 4.4 * u, p.x * 5.0 + float(i), Color(1, 1, 1, al * 0.9))
		else:
			FxDraw.star4(ci, pos, 4.5 * u * al, FxDraw.ca(c1, 1.0))
	# ledakan cahaya di akhir
	if t > 2.4:
		var f: float = clampf((t - 2.4) / 0.9, 0.0, 1.0)
		ci.draw_set_transform(cen, 0.0, Vector2.ONE)
		for k in 12:
			FxDraw.ray_tri(ci, float(k) * TAU / 12.0 + t, 150.0 * u * (1.0 - f * 0.4), 0.06, Color(1, 1, 0.9, 0.55 * (1.0 - f)))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		ci.draw_arc(cen, (10.0 + 170.0 * f) * u, 0.0, TAU, 48, FxDraw.ca(c1, 1.0 - f), 5.0 * u, true)


func _front_petals(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var g: float = smoothstep(0.1, 0.8, t) * (1.0 - smoothstep(2.6, 3.3, t))
	for i in 50:
		var a: float = float(i) * 2.399 + t * (2.2 + float(i % 3) * 0.8)
		if sin(a) > 0.0:
			_petal_at(ci, V, i, a, g, 1.0)
	# mekar di tanah
	if t > 1.5:
		var f: float = clampf((t - 1.5) / 0.9, 0.0, 1.0)
		for k in 10:
			var a2: float = float(k) * TAU / 10.0
			var r: float = (14.0 + 60.0 * f) * u
			var pos: Vector2 = Vector2(V.x + cos(a2) * r, V.y + usize * 0.45 + sin(a2) * r * 0.25)
			FxDraw.petal(ci, pos, 6.0 * u, a2, FxDraw.ca(c1, (1.0 - smoothstep(0.6, 1.0, f)) * 0.9))
		ci.draw_circle(V, 70.0 * u * (1.0 - f), FxDraw.ca(c2, 0.3 * (1.0 - f)))


func _front_cosmic(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var nn: int = 14
	var pts: Array[Vector2] = []
	var burst: float = clampf((t - 1.7) / 1.3, 0.0, 1.0)
	for i in nn:
		var base := Vector2((FxDraw.h(float(i), 1.0) - 0.5) * 0.8, (FxDraw.h(float(i), 2.0) - 0.5) * 0.95) * usize
		var dir: Vector2 = base.normalized() if base.length() > 0.1 else Vector2.UP
		pts.append(V + base + dir * burst * (80.0 + 120.0 * FxDraw.h(float(i), 3.0)) * u)
	var lines: float = smoothstep(0.55, 1.3, t) * (1.0 - smoothstep(1.7, 2.1, t))
	if lines > 0.01:
		for i in nn - 1:
			ci.draw_line(pts[i], pts[i + 1], FxDraw.ca(c1.lerp(Color.WHITE, 0.5), 0.8 * lines), 1.6 * u)
		ci.draw_line(pts[nn - 1], pts[0], FxDraw.ca(c1.lerp(Color.WHITE, 0.5), 0.5 * lines), 1.4 * u)
	var sg: float = smoothstep(0.5, 1.0, t) * (1.0 - smoothstep(2.6, 3.4, t))
	for i in nn:
		var tw: float = 0.7 + 0.3 * sin(t * 8.0 + float(i))
		FxDraw.star4(ci, pts[i], (5.0 + 3.0 * FxDraw.h(float(i), 4.0)) * u * tw * (1.0 + burst), FxDraw.ca(Color.WHITE, sg))
		FxDraw.glow_dot(ci, pts[i], 1.8 * u, FxDraw.ca(c1, sg))
	# supernova
	if t > 1.7:
		var f: float = burst
		if t < 1.95:
			ci.draw_circle(V, 70.0 * u * (1.0 - (t - 1.7) / 0.25), Color(1, 1, 1, 0.95))
		for k in 3:
			var ff: float = clampf(f * (1.0 + float(k) * 0.12) - float(k) * 0.05, 0.0, 1.0)
			var cc: Color = [c1, c2, Color.WHITE][k]
			ci.draw_arc(V, (10.0 + 210.0 * ff) * u, 0.0, TAU, 56, FxDraw.ca(cc, (1.0 - ff)), (8.0 - float(k) * 2.0) * u * (1.0 - ff) + 1.0, true)
		ci.draw_set_transform(V, 0.0, Vector2.ONE)
		for k in 20:
			var a: float = float(k) * TAU / 20.0
			var ln: float = (50.0 + 170.0 * FxDraw.h(float(k), 6.0)) * u * f
			ci.draw_line(Vector2(cos(a), sin(a)) * 16.0 * u, Vector2(cos(a), sin(a)) * ln, FxDraw.ca(Color.WHITE, (1.0 - f)), 2.0 * u)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _front_toxic(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var m: float = smoothstep(0.5, 2.1, t)
	var fade: float = 1.0 - smoothstep(2.9, 3.5, t)
	var gy: float = V.y + usize * 0.5
	# tetesan
	for i in 8:
		var p: Vector2 = FxDraw.ph(t, i, 8, 0.8)
		var x: float = V.x + (FxDraw.rnd(i, p.y, 1.0) - 0.5) * usize * 0.8
		ci.draw_circle(Vector2(x, V.y - usize * 0.1 + p.x * p.x * usize * 0.6), 2.2 * u * (1.0 - p.x * 0.4), FxDraw.ca(c1, smoothstep(0.1, 0.5, t) * fade))
	# gelembung
	for i in 14:
		var p: Vector2 = FxDraw.ph(t, i, 14, 1.5)
		var pos: Vector2 = Vector2(V.x + (FxDraw.rnd(i, p.y, 2.0) - 0.5) * (30.0 + 70.0 * m) * u, gy - p.x * 80.0 * u)
		var r: float = (3.0 + 5.0 * FxDraw.rnd(i, p.y, 3.0)) * u * (0.6 + p.x * 0.6)
		ci.draw_arc(pos, r, 0.0, TAU, 14, FxDraw.ca(c1.lightened(0.3), (1.0 - p.x * p.x) * m * fade), 1.8 * u, true)
		ci.draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.22, Color(1, 1, 1, 0.7 * (1.0 - p.x) * m * fade))
	# gas beracun
	for i in 8:
		var p: Vector2 = FxDraw.ph(t, i, 8, 2.2)
		var pos2: Vector2 = Vector2(V.x + (FxDraw.rnd(i, p.y, 5.0) - 0.5) * 70.0 * u + sin(p.x * 4.0 + float(i)) * 14.0 * u, gy - 8.0 * u - p.x * 110.0 * u)
		ci.draw_circle(pos2, (14.0 + 34.0 * p.x) * u, FxDraw.ca(c1, 0.13 * sin(p.x * PI) * m * fade))


func _front_jackpot(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	# kilatan emas saat korban meledak
	if t >= 1.65 and t < 2.0:
		var f: float = (t - 1.65) / 0.35
		ci.draw_circle(V, 80.0 * u * (1.0 - f * 0.5), FxDraw.ca(c2, 1.0 - f))
	# koin
	var n: int = 56
	for i in n:
		var t0: float = 0.9 + 0.8 * FxDraw.h(float(i), 1.0) * (0.0 if i % 2 == 0 else 1.0)
		if i % 2 == 0:
			t0 = 1.65
		var tt: float = t - t0
		if tt <= 0.0:
			continue
		var a: float = -PI * 0.5 + (FxDraw.h(float(i), 2.0) - 0.5) * (1.2 if i % 2 == 1 else 3.6)
		var spd: float = (150.0 + 260.0 * FxDraw.h(float(i), 3.0)) * u
		var pos: Vector2 = V + Vector2(cos(a) * spd * tt, sin(a) * spd * tt + 520.0 * u * tt * tt)
		var al: float = 1.0 - smoothstep(1.2, 1.9, tt)
		var sx: float = absf(cos(tt * 9.0 + float(i))) * 6.0 * u + 0.8
		var sy: float = 6.2 * u
		ci.draw_colored_polygon(_ellipse_pts(pos, sx, sy, 12), FxDraw.ca(c1, al))
		ci.draw_colored_polygon(_ellipse_pts(pos, sx * 0.6, sy * 0.7, 12), FxDraw.ca(c2, al))
	# confetti emas
	for i in 30:
		var p: Vector2 = FxDraw.ph(t, i, 30, 1.8)
		var pos2: Vector2 = V + Vector2((FxDraw.rnd(i, p.y, 1.0) - 0.5) * 260.0 * u, -120.0 * u + p.x * 260.0 * u)
		ci.draw_rect(Rect2(pos2, Vector2(4.0, 7.0) * u), FxDraw.ca([c1, c2, Color.WHITE][i % 3], sin(p.x * PI) * smoothstep(1.0, 1.7, t)))


func _front_slice(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var hue0: float = 0.0
	# dua tebasan
	var cuts: Array = [[0.3, Vector2(-1, -1)], [0.55, Vector2(1, -1)]]
	for c in cuts:
		var ts: float = float(c[0])
		var d: Vector2 = c[1]
		var tt: float = t - ts
		if tt > 0.0 and tt < 0.7:
			var f: float = tt / 0.7
			var reach: float = minf(1.0, tt / 0.07)
			var a: Vector2 = V - d * 110.0 * u
			var b: Vector2 = a + d * 220.0 * u * reach
			var wd: float = 12.0 * u * (1.0 - f) + 1.0
			var cc: Color = FxDraw.hue(t * 0.8, 1.0 - f, 0.7, 1.0) if weapon == "knife" and c1.r > 0.9 and c1.b > 0.7 else FxDraw.ca(c1, 1.0 - f)
			ci.draw_line(a, b, FxDraw.ca(cc, (1.0 - f) * 0.4), wd * 2.4)
			ci.draw_line(a, b, cc, wd)
			ci.draw_line(a, b, Color(1, 1, 1, 1.0 - f), wd * 0.4)
	hue0 = 0.0
	# potongan korban (4 segitiga) terpisah
	if t >= 0.9 and victim_tex != null:
		var tt2: float = t - 0.9
		var s: float = usize * 0.5
		var tw: float = float(victim_tex.get_width())
		var corners: Array[Vector2] = [Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)]
		var fade: float = 1.0 - smoothstep(1.4, 2.3, tt2)
		for k in 4:
			var ca_: Vector2 = corners[k]
			var cb: Vector2 = corners[(k + 1) % 4]
			var mid: Vector2 = (ca_ + cb) * 0.5
			var dir: Vector2 = mid.normalized()
			var vel: Vector2 = dir * (90.0 + 30.0 * float(k)) * u
			var pos: Vector2 = V + vel * tt2 + Vector2(0, 360.0 * u * tt2 * tt2 * 0.6)
			var rot: float = (float(k) - 1.5) * 0.9 * tt2
			var pts := PackedVector2Array([Vector2.ZERO, ca_, cb])
			var uvs := PackedVector2Array()
			for q in pts:
				uvs.append(Vector2((q.x / usize + 0.5) * tw, (q.y / usize + 0.5) * tw))
			ci.draw_set_transform(pos, rot, Vector2.ONE)
			var cols := PackedColorArray([Color(1, 1, 1, fade), Color(1, 1, 1, fade), Color(1, 1, 1, fade)])
			ci.draw_polygon(pts, cols, uvs, victim_tex)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 26:
			var p: Vector2 = FxDraw.ph(tt2, i, 26, 1.2)
			var a: float = FxDraw.rnd(i, p.y, 1.0) * TAU
			var pos2: Vector2 = V + Vector2(cos(a), sin(a)) * (20.0 + 130.0 * p.x) * u
			FxDraw.star4(ci, pos2, 4.0 * u * (1.0 - p.x), FxDraw.hue(float(i) / 26.0 + t * 0.5, 1.0 - p.x, 0.6, 1.0))


# ================================================================== alat bantu finisher gelombang 2
func _ell(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, n: int = 28) -> void:
	if rx < 0.8 or ry < 0.4 or col.a <= 0.003:
		return
	ci.draw_colored_polygon(_ellipse_pts(c, rx, ry, n), col)


func _ring(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, w: float) -> void:
	if rx < 0.8 or ry < 0.3 or col.a <= 0.003:
		return
	var pts: PackedVector2Array = _ellipse_pts(c, rx, ry, 40)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, maxf(w, 1.0), true)


func _ell_arc(ci: CanvasItem, c: Vector2, rx: float, ry: float, a0: float, a1: float, col: Color, w: float) -> void:
	if rx < 0.8 or col.a <= 0.003:
		return
	var pts := PackedVector2Array()
	var n: int = 24
	for k in n + 1:
		var a: float = lerpf(a0, a1, float(k) / float(n))
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	ci.draw_polyline(pts, col, maxf(w, 1.0), true)


## Tebasan melengkung: dari a ke b, melengkung sebesar `bulge`, lebar maksimum `wd` (meruncing di kedua ujung).
func _slash(ci: CanvasItem, a: Vector2, b: Vector2, bulge: float, wd: float, col: Color) -> void:
	if col.a <= 0.003 or wd < 0.5:
		return
	var d: Vector2 = b - a
	if d.length() < 8.0:
		return
	var nrm: Vector2 = d.orthogonal().normalized()
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var n: int = 14
	for k in n + 1:
		var s: float = float(k) / float(n)
		var cen: Vector2 = a + d * s + nrm * sin(s * PI) * bulge
		var w: float = sin(s * PI) * wd * 0.5
		left.append(cen + nrm * w)
		right.append(cen - nrm * w)
	right.reverse()
	left.append_array(right)
	ci.draw_colored_polygon(left, col)


## Offset getaran kamera (hanya untuk finisher yang benturannya keras).
func _shake_off() -> Vector2:
	var a: float = 0.0
	match kind:
		"meteor":
			a = smoothstep(0.93, 0.97, t) * (1.0 - smoothstep(0.97, 1.9, t)) * 9.0
		"orbital":
			a = smoothstep(1.28, 1.34, t) * (1.0 - smoothstep(1.9, 2.5, t)) * 6.0
		"tsunami":
			a = smoothstep(1.0, 1.25, t) * (1.0 - smoothstep(1.4, 2.2, t)) * 5.0
		"portal":
			a = smoothstep(2.28, 2.32, t) * (1.0 - smoothstep(2.32, 2.9, t)) * 6.0
	if a <= 0.001:
		return Vector2.ZERO
	return Vector2(sin(t * 83.0), cos(t * 71.0)) * a * _sc


# ================================================================== 12. METEOR STRIKE (meteor)
## 0.12-0.95 meteor menukik dari langit (bayangan merah membesar di tanah) | 0.95 BENTURAN: korban gepeng, kawah, cincin kejut,
## retakan lava, batu terlempar, kamera bergetar | 1.3-2.4 korban hangus lalu jadi bara | sisa: asap & batu membara mendingin
func _v_meteor() -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var imp: float = t - 0.95
	if imp < 0.0:
		var heat: float = smoothstep(0.3, 0.95, t)
		var tr := Vector2(sin(t * 60.0), cos(t * 47.0)) * 1.2 * u * heat
		_set_v(V + tr, 0.0, Vector2.ONE, 1.0, Color(1, 1, 1, 1).lerp(Color(1.5, 0.95, 0.6, 1.0), heat * 0.65), 0, 0.0, c1)
	else:
		var sq: float = smoothstep(0.0, 0.1, imp)
		var sx: float = lerpf(1.0, 1.75, sq)
		var sy: float = lerpf(1.0, 0.1, sq)
		var burn: float = smoothstep(0.35, 1.5, imp)
		var gr: Vector2 = V + Vector2(0, usize * 0.5)
		_set_v(gr + Vector2(0, -usize * sy * 0.5), 0.0, Vector2(sx, sy), 1.0, Color(0.32, 0.2, 0.16, 1.0).lerp(Color(0.1, 0.07, 0.06, 1.0), burn), 1, burn, c1)
		_vsp.visible = imp < 1.7


func _back_meteor(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var gy: float = V.y + usize * 0.5
	var wf: float = smoothstep(0.1, 0.95, t) * (1.0 - smoothstep(0.95, 1.1, t))
	if wf > 0.01:
		var rr: float = (22.0 + 52.0 * smoothstep(0.1, 0.95, t)) * u
		_ell(ci, Vector2(V.x, gy), rr, rr * 0.26, FxDraw.ca(c1, 0.32 * wf))
		_ring(ci, Vector2(V.x, gy), rr, rr * 0.26, FxDraw.ca(c2, 0.8 * wf), 2.0 * u)
	if t >= 0.95:
		var tt: float = t - 0.95
		var cg: float = smoothstep(0.0, 0.18, tt)
		var fade: float = 1.0 - smoothstep(2.2, 2.65, tt)
		var G := Vector2(V.x, gy + 1.0 * u)
		_ell(ci, G, 62.0 * u * cg, 15.0 * u * cg, Color(0.04, 0.025, 0.02, 0.92 * fade))
		var glow: float = (1.0 - smoothstep(0.2, 1.9, tt)) * fade
		_ell(ci, G, 44.0 * u * cg, 9.0 * u * cg, FxDraw.ca(c1, 0.85 * glow))
		_ell(ci, G, 26.0 * u * cg, 5.0 * u * cg, FxDraw.ca(c2, 0.9 * glow))


func _front_meteor(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var gy: float = V.y + usize * 0.5
	var tgt := Vector2(V.x, V.y - usize * 0.15)
	var start: Vector2 = V + Vector2(-330.0, -680.0) * u
	var dir: Vector2 = (tgt - start).normalized()
	if t > 0.12 and t < 0.97:
		var f: float = clampf((t - 0.12) / 0.83, 0.0, 1.0)
		var mp: Vector2 = start.lerp(tgt, pow(f, 1.8))
		for i in 26:
			var q: float = float(i) / 26.0
			var pp: Vector2 = mp - dir * q * 330.0 * u * (0.35 + 0.65 * minf(1.0, f * 2.0))
			pp += Vector2(sin(t * 30.0 + float(i) * 1.7), cos(t * 26.0 + float(i) * 2.3)) * 5.0 * u * q
			FxDraw.glow_dot(ci, pp, (13.0 * (1.0 - q) + 3.0) * u, FxDraw.ca(c1.lerp(c2, 1.0 - q), (1.0 - q) * 0.6))
		ci.draw_circle(mp, 50.0 * u, FxDraw.ca(c1, 0.2))
		ci.draw_circle(mp, 37.0 * u, FxDraw.ca(c2, 0.32))
		var rock := PackedVector2Array()
		for k in 10:
			var a: float = float(k) / 10.0 * TAU + t * 3.0
			var rr: float = (22.0 + 8.0 * FxDraw.h(float(k), 3.0)) * u
			rock.append(mp + Vector2(cos(a), sin(a)) * rr)
		ci.draw_colored_polygon(rock, Color(0.13, 0.08, 0.06, 1.0))
		var rk2: PackedVector2Array = rock.duplicate()
		rk2.append(rock[0])
		ci.draw_polyline(rk2, FxDraw.ca(c2, 0.9), 2.5 * u, true)
		for k in 4:
			var a2: float = float(k) * 1.7 + t * 3.0
			FxDraw.glow_dot(ci, mp + Vector2(cos(a2), sin(a2)) * 10.0 * u, 3.2 * u, FxDraw.ca(c1, 0.9))
	if t >= 0.95:
		var tt: float = t - 0.95
		var G := Vector2(V.x, gy)
		if tt < 0.3:
			var ff: float = tt / 0.3
			ci.draw_circle(G + Vector2(0, -usize * 0.3), 120.0 * u * (1.0 - ff * 0.4), Color(1, 0.95, 0.8, 0.9 * (1.0 - ff)))
		for k in 3:
			var f2: float = clampf((tt - float(k) * 0.1) / 0.9, 0.0, 1.0)
			if f2 > 0.0 and f2 < 1.0:
				var rr2: float = (14.0 + 240.0 * f2) * u
				_ring(ci, G, rr2, rr2 * 0.26, FxDraw.ca(c2.lerp(Color.WHITE, 0.4), (1.0 - f2) * 0.9), (7.0 - float(k) * 2.0) * u * (1.0 - f2) + 1.0)
		var cr: float = smoothstep(0.0, 0.3, tt)
		var crf: float = 1.0 - smoothstep(1.2, 2.3, tt)
		for k in 9:
			var a3: float = float(k) / 9.0 * TAU + FxDraw.h(float(k), 1.0) * 0.5
			var ln: float = (50.0 + 80.0 * FxDraw.h(float(k), 2.0)) * u * cr
			var d3 := Vector2(cos(a3), sin(a3) * 0.26)
			ci.draw_line(G + d3 * 12.0 * u, G + d3 * ln, FxDraw.ca(c1, crf), 3.0 * u * crf + 1.0)
			ci.draw_line(G + d3 * 12.0 * u, G + d3 * ln * 0.8, FxDraw.ca(c2, crf), 1.2 * u)
		for i in 16:
			var a4: float = -PI * 0.5 + (FxDraw.h(float(i), 4.0) - 0.5) * 2.6
			var spd: float = (160.0 + 300.0 * FxDraw.h(float(i), 5.0)) * u
			var pos: Vector2 = G + Vector2(cos(a4) * spd * tt, sin(a4) * spd * tt + 620.0 * u * tt * tt)
			if pos.y > gy + 6.0 * u:
				pos.y = gy + 6.0 * u
			var al4: float = 1.0 - smoothstep(1.4, 2.4, tt)
			var rs: float = (3.0 + 4.0 * FxDraw.h(float(i), 6.0)) * u
			var rot: float = tt * (4.0 + 6.0 * FxDraw.h(float(i), 7.0))
			ci.draw_set_transform(pos, rot, Vector2.ONE)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-rs, -rs * 0.7), Vector2(rs, -rs), Vector2(rs * 0.8, rs), Vector2(-rs * 0.9, rs * 0.6)]), Color(0.16, 0.1, 0.08, al4))
			ci.draw_polyline(PackedVector2Array([Vector2(-rs, -rs * 0.7), Vector2(rs, -rs), Vector2(rs * 0.8, rs)]), FxDraw.ca(c1, al4 * (1.0 - smoothstep(0.2, 1.0, tt))), 1.4, false)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 12:
			var p: Vector2 = FxDraw.ph(tt, i, 12, 2.0)
			var pos2 := Vector2(G.x + (FxDraw.rnd(i, p.y, 1.0) - 0.5) * 70.0 * u + sin(p.x * 5.0 + float(i)) * 9.0 * u, gy - p.x * 150.0 * u)
			ci.draw_circle(pos2, (10.0 + 26.0 * p.x) * u, Color(0.16, 0.15, 0.16, 0.38 * sin(p.x * PI) * (1.0 - smoothstep(2.3, 2.7, tt))))
		for i in 30:
			var p2: Vector2 = FxDraw.ph(tt, i, 30, 1.3)
			var pos3 := Vector2(G.x + (FxDraw.rnd(i, p2.y, 3.0) - 0.5) * 120.0 * u * (0.4 + p2.x), gy - p2.x * (60.0 + 140.0 * FxDraw.rnd(i, p2.y, 4.0)) * u)
			FxDraw.glow_dot(ci, pos3, (1.2 + 1.2 * FxDraw.rnd(i, p2.y, 5.0)) * u * (1.0 - p2.x), FxDraw.ca(c1.lerp(c2, p2.x), (1.0 - p2.x) * (1.0 - smoothstep(1.8, 2.5, tt))))
		var rkf: float = 1.0 - smoothstep(2.0, 2.6, tt)
		var cool: float = smoothstep(0.2, 2.0, tt)
		var dome := PackedVector2Array()
		for k in 13:
			var a5: float = PI + float(k) / 12.0 * PI
			dome.append(G + Vector2(cos(a5) * 24.0 * u, sin(a5) * 20.0 * u * (0.8 + 0.2 * FxDraw.h(float(k), 8.0)) + 3.0 * u))
		ci.draw_colored_polygon(dome, Color(0.14, 0.08, 0.06, rkf))
		ci.draw_polyline(dome, FxDraw.ca(c1.lerp(Color(0.4, 0.1, 0.05), cool), (1.0 - cool * 0.6) * rkf), 2.5 * u, true)


# ================================================================== 13. TIDAL CRASH (tsunami)
## 0.4-1.95 ombak raksasa menyapu arena dari kiri ke kanan | ~1.2 menghantam korban, korban terbawa & berputar di dalam ombak |
## ombak runtuh jadi banjir yang surut, percikan & hujan tetes
func _wave_x() -> float:
	return vpos.x + lerpf(-640.0, 640.0, smoothstep(0.4, 1.95, t)) * _u


func _wave_hgt() -> float:
	return 250.0 * _u * smoothstep(0.25, 0.9, t) * (1.0 - 0.92 * smoothstep(1.85, 2.6, t))


func _wave_poly(xf: float, gy: float, hgt: float, tail: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = 16
	pts.append(Vector2(xf - tail, gy + 40.0 * _u))
	for i in n + 1:
		var s: float = float(i) / float(n)
		pts.append(Vector2(xf - tail * (1.0 - s), gy - hgt * pow(s, 2.2)))
	var r: float = hgt * 0.3
	var cc := Vector2(xf, gy - hgt + r)
	for j in range(1, 13):
		var a: float = -PI * 0.5 + float(j) / 12.0 * PI
		pts.append(cc + Vector2(cos(a), sin(a)) * r)
	pts.append(Vector2(xf + 36.0 * _u, gy))
	pts.append(Vector2(xf + 36.0 * _u, gy + 40.0 * _u))
	return pts


func _v_tsunami() -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var wx: float = _wave_x()
	var carried: float = maxf(0.0, wx - 80.0 * u - V.x)
	var hitk: float = clampf(carried / (60.0 * u), 0.0, 1.0)
	var since: float = maxf(0.0, t - 1.2)
	var trem: float = smoothstep(0.5, 1.1, t) * (1.0 - hitk)
	var bob := Vector2(carried + sin(t * 70.0) * 1.4 * u * trem, -(26.0 * u) * hitk * (0.5 + 0.5 * sin(since * 5.0)) - 12.0 * u * hitk)
	var fw: float = 1.0 - smoothstep(1.95, 2.5, t)
	_set_v(V + bob, since * 6.0 * hitk, Vector2.ONE * (1.0 - 0.25 * hitk), fw, Color(1, 1, 1, 1).lerp(Color(0.55, 0.85, 1.25, 1.0), hitk * 0.8), 0, 0.0, c1)
	_vsp.visible = t < 2.55


func _back_tsunami(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var gy: float = V.y + usize * 0.5
	var hg: float = _wave_hgt()
	if hg < 4.0:
		return
	var wx: float = _wave_x()
	var back_poly: PackedVector2Array = _wave_poly(wx - 150.0 * u, gy, hg * 0.78, 520.0 * u)
	ci.draw_colored_polygon(back_poly, FxDraw.ca(c1.darkened(0.55), 0.7))
	var edge := PackedVector2Array()
	for i in range(1, 18):
		edge.append(back_poly[i])
	ci.draw_polyline(edge, FxDraw.ca(c2, 0.4), 3.0 * u, true)


func _front_tsunami(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var gy: float = V.y + usize * 0.5
	var hg: float = _wave_hgt()
	var wx: float = _wave_x()
	if hg > 4.0:
		var poly: PackedVector2Array = _wave_poly(wx, gy, hg, 560.0 * u)
		ci.draw_colored_polygon(poly, FxDraw.ca(c1.darkened(0.15), 0.82))
		var inner: PackedVector2Array = _wave_poly(wx - 6.0 * u, gy, hg * 0.86, 520.0 * u)
		ci.draw_colored_polygon(inner, FxDraw.ca(c1.lightened(0.25), 0.28))
		for k in 9:
			var sx: float = wx - (30.0 + 56.0 * float(k)) * u + sin(t * 3.0 + float(k)) * 8.0 * u
			var s: float = clampf(1.0 - (wx - sx) / (560.0 * u), 0.0, 1.0)
			var top: float = gy - hg * pow(s, 2.2)
			ci.draw_line(Vector2(sx, top + 12.0 * u), Vector2(sx - 14.0 * u, gy + 6.0 * u), FxDraw.ca(c2, 0.16), 3.0 * u)
		var prof := PackedVector2Array()
		for i in range(1, 18):
			prof.append(poly[i])
		ci.draw_polyline(prof, FxDraw.ca(c2, 0.95), 6.0 * u, true)
		ci.draw_polyline(prof, FxDraw.ca(Color.WHITE, 0.9), 2.2 * u, true)
		var r: float = hg * 0.3
		var cc := Vector2(wx, gy - hg + r)
		ci.draw_arc(cc, r * 0.68, -PI * 0.35, PI * 0.5, 14, FxDraw.ca(c1.darkened(0.6), 0.55), r * 0.5, true)
		ci.draw_arc(cc, r, -PI * 0.5, PI * 0.5, 16, FxDraw.ca(c2, 0.9), 4.0 * u, true)
		for i in 34:
			var p: Vector2 = FxDraw.ph(t, i, 34, 0.9)
			var ang: float = -PI * 0.5 + FxDraw.rnd(i, p.y, 1.0) * PI * 0.9
			var pos: Vector2 = cc + Vector2(cos(ang) * (r + p.x * 60.0 * u), sin(ang) * (r + p.x * 40.0 * u) + p.x * p.x * 50.0 * u)
			FxDraw.glow_dot(ci, pos, (1.4 + 1.4 * FxDraw.rnd(i, p.y, 2.0)) * u * (1.0 - p.x * 0.5), FxDraw.ca(Color.WHITE.lerp(c2, 0.4), (1.0 - p.x) * 0.9 * smoothstep(0.3, 0.7, t) * (1.0 - smoothstep(1.9, 2.4, t))))
	var fl: float = smoothstep(1.2, 1.8, t) * (1.0 - smoothstep(2.4, 3.4, t))
	if fl > 0.01:
		var lvl: float = 24.0 * u * fl
		var x0: float = V.x - 900.0 * u
		var x1: float = minf(V.x + 900.0 * u, wx - 560.0 * u * (1.0 - smoothstep(1.9, 2.5, t)) + 900.0 * u)
		var wp := PackedVector2Array()
		wp.append(Vector2(x0, gy + 60.0 * u))
		var nn: int = 24
		for i in nn + 1:
			var xx: float = lerpf(x0, V.x + 900.0 * u, float(i) / float(nn))
			wp.append(Vector2(xx, gy - lvl + sin(xx * 0.04 / u + t * 5.0) * 3.0 * u * fl))
		wp.append(Vector2(V.x + 900.0 * u, gy + 60.0 * u))
		ci.draw_colored_polygon(wp, FxDraw.ca(c1, 0.38 * fl))
		var ln := PackedVector2Array()
		for i in range(1, nn + 1):
			ln.append(wp[i])
		ci.draw_polyline(ln, FxDraw.ca(c2, 0.8 * fl), 2.5 * u, true)
		x1 = x1 + 0.0
	for i in 30:
		var t0: float = 1.0 + 0.8 * FxDraw.h(float(i), 1.0)
		var tt: float = t - t0
		if tt <= 0.0 or tt > 1.4:
			continue
		var x: float = V.x + (FxDraw.h(float(i), 2.0) - 0.45) * 380.0 * u
		var y0: float = gy - (150.0 + 130.0 * FxDraw.h(float(i), 3.0)) * u
		var pos2 := Vector2(x + 30.0 * u * tt, y0 + 460.0 * u * tt * tt)
		if pos2.y > gy:
			continue
		ci.draw_line(pos2, pos2 - Vector2(3.0, 9.0) * u, FxDraw.ca(c2, 0.85 * (1.0 - tt / 1.4)), 2.0 * u)
	for i in 12:
		var p3: Vector2 = FxDraw.ph(t, i, 12, 1.6)
		var bx: float = V.x + (FxDraw.rnd(i, p3.y, 4.0) - 0.5) * 300.0 * u
		var by: float = gy - p3.x * 70.0 * u
		ci.draw_arc(Vector2(bx, by), (2.5 + 3.0 * FxDraw.rnd(i, p3.y, 5.0)) * u, 0.0, TAU, 12, FxDraw.ca(c2, 0.8 * sin(p3.x * PI) * fl), 1.6 * u, true)


# ================================================================== 14. SOUL HARVEST (reaper)
## 0.1-0.55 kabut hijau + malaikat maut muncul di belakang | 0.5-0.72 sabit diayunkan, 0.65 TEBAS | 0.72-2.6 jiwa korban keluar,
## melayang dan diserap sang malaikat maut | 1.5-2.5 tubuh jadi abu | 2.3-3.5 nisan muncul di tempat korban
func _reaper_feet() -> Vector2:
	return Vector2(vpos.x + usize * 0.95, vpos.y + usize * 0.5)


func _reaper_head() -> Vector2:
	return _reaper_feet() + Vector2(0, -usize * 2.05 + sin(t * 2.4) * 4.0 * _u)


func _reaper_scythe() -> Array:
	var S: float = usize
	var H: Vector2 = _reaper_head()
	var P: Vector2 = H + Vector2(-0.3, 0.7) * S
	var a: float = lerpf(-0.95 - 0.15 * sin(t * 6.0) * (1.0 - smoothstep(0.4, 0.5, t)), -3.55, smoothstep(0.5, 0.72, t))
	var dir := Vector2(cos(a), sin(a))
	return [P, dir, P + dir * 1.9 * S]


func _v_reaper() -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var hit: float = smoothstep(0.64, 0.7, t)
	var grey: float = smoothstep(0.7, 1.0, t)
	var tint := Color(1, 1, 1, 1).lerp(Color(0.5, 0.58, 0.62, 1.0), grey)
	var jolt: float = (1.0 - smoothstep(0.65, 0.95, t)) * hit
	var pos: Vector2 = V + Vector2(sin(t * 80.0) * 2.5 * u * jolt, 0.0)
	var cr: float = smoothstep(1.5, 2.4, t)
	_set_v(pos, 0.0, Vector2.ONE, 1.0, tint.lerp(Color(0.25, 0.28, 0.3, 1.0), cr), 1, cr, c1)
	_vsp.visible = t < 2.5


func _back_reaper(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var S: float = usize
	var gy: float = V.y + usize * 0.5
	var g: float = smoothstep(0.1, 0.55, t) * (1.0 - smoothstep(2.7, 3.2, t))
	if g <= 0.01:
		return
	for k in 7:
		var fx: float = V.x + (FxDraw.h(float(k), 1.0) - 0.5) * 360.0 * u + sin(t * 0.8 + float(k)) * 30.0 * u
		ci.draw_circle(Vector2(fx, gy - 6.0 * u), (40.0 + 30.0 * FxDraw.h(float(k), 2.0)) * u, FxDraw.ca(c1, 0.10 * g))
	var H: Vector2 = _reaper_head()
	var cloak := PackedVector2Array([H + Vector2(-0.42, 0.18) * S, H + Vector2(-0.34, -0.26) * S, H + Vector2(0.0, -0.5) * S, H + Vector2(0.34, -0.26) * S,
		H + Vector2(0.42, 0.18) * S, H + Vector2(0.72, 1.25) * S])
	for k in 7:
		var s: float = float(k) / 6.0
		cloak.append(H + Vector2(lerpf(0.72, -0.72, s), 1.95 + 0.12 * sin(t * 5.0 + float(k) * 1.9)) * S)
	cloak.append(H + Vector2(-0.72, 1.25) * S)
	ci.draw_colored_polygon(cloak, Color(0.02, 0.04, 0.05, 0.94 * g))
	var cl2: PackedVector2Array = cloak.duplicate()
	cl2.append(cloak[0])
	ci.draw_polyline(cl2, FxDraw.ca(c1, 0.4 * g), 2.0 * u, true)
	_ell(ci, H + Vector2(0, 0.02) * S, 0.22 * S, 0.27 * S, Color(0, 0, 0, g))
	var blink: float = 0.75 + 0.25 * sin(t * 9.0)
	var eye: float = g * blink * (1.0 + 1.6 * (1.0 - smoothstep(0.64, 0.9, t)) * smoothstep(0.6, 0.66, t))
	FxDraw.glow_dot(ci, H + Vector2(-0.09, 0.0) * S, 0.05 * S, FxDraw.ca(c2.lerp(Color.WHITE, 0.4), eye))
	FxDraw.glow_dot(ci, H + Vector2(0.09, 0.0) * S, 0.05 * S, FxDraw.ca(c2.lerp(Color.WHITE, 0.4), eye))
	var sc: Array = _reaper_scythe()
	var P: Vector2 = sc[0]
	var dir: Vector2 = sc[1]
	var E: Vector2 = sc[2]
	ci.draw_line(P - dir * 0.4 * S, E, Color(0.22, 0.16, 0.12, g), 5.0 * u)
	ci.draw_line(P - dir * 0.4 * S, E, FxDraw.ca(c1, 0.25 * g), 9.0 * u)
	var nrm: Vector2 = dir.orthogonal()
	var C: Vector2 = E + nrm * 0.5 * S
	var a0: float = (E - C).angle()
	ci.draw_arc(C, 0.5 * S, a0, a0 + 2.0, 20, FxDraw.ca(c1, 0.35 * g), 14.0 * u, true)
	ci.draw_arc(C, 0.5 * S, a0, a0 + 2.0, 20, Color(0.78, 0.86, 0.9, g), 6.0 * u, true)
	ci.draw_arc(C, 0.5 * S + 2.0 * u, a0, a0 + 2.0, 20, FxDraw.ca(c2, g), 2.0 * u, true)
	var swing: float = smoothstep(0.5, 0.6, t) * (1.0 - smoothstep(0.68, 0.85, t))
	if swing > 0.01:
		ci.draw_arc(C, 0.5 * S, a0, a0 + 2.0, 20, FxDraw.ca(Color.WHITE, 0.8 * swing), 10.0 * u, true)


func _front_reaper(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var S: float = usize
	var gy: float = V.y + usize * 0.5
	var H: Vector2 = _reaper_head()
	var sl: float = t - 0.62
	if sl > 0.0 and sl < 0.35:
		var f: float = sl / 0.35
		var reach: float = minf(1.0, sl / 0.06)
		var a: Vector2 = V + Vector2(0.95, -0.95) * S
		var b: Vector2 = a.lerp(V + Vector2(-0.95, 0.75) * S, reach)
		_slash(ci, a, b, 0.22 * S, 20.0 * u * (1.0 - f) + 2.0, FxDraw.ca(c1, 0.55 * (1.0 - f)))
		_slash(ci, a, b, 0.22 * S, 9.0 * u * (1.0 - f) + 1.0, FxDraw.ca(Color.WHITE, 1.0 - f))
		if sl < 0.18:
			ci.draw_circle(V, 60.0 * u * (1.0 - sl / 0.18), FxDraw.ca(c2, 0.85 * (1.0 - sl / 0.18)))
	if t > 0.7 and t < 1.7:
		for i in 14:
			var p: Vector2 = FxDraw.ph(t, i, 14, 0.8)
			var pos := Vector2(V.x + (FxDraw.rnd(i, p.y, 1.0) - 0.5) * usize * 0.7, V.y + usize * 0.4 - p.x * usize * 1.2)
			var w: float = 4.0 * u * (1.0 - p.x)
			if w < 0.8:
				continue
			ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-w, 0), pos + Vector2(sin(t * 12.0 + float(i)) * 3.0 * u, -w * 3.4), pos + Vector2(w, 0)]), FxDraw.ca(c1, 0.7 * (1.0 - p.x)))
	var st: float = t - 0.72
	if st > 0.0 and st < 1.92 and victim_tex != null:
		var s: float = smoothstep(0.0, 1.9, st)
		var mid: Vector2 = V + Vector2(0.0, -1.6 * S)
		var pos2: Vector2 = V * (1.0 - s) * (1.0 - s) + mid * 2.0 * (1.0 - s) * s + H * s * s
		pos2.x += sin(st * 4.0) * 8.0 * u * (1.0 - s)
		var sc2: float = 1.0 - 0.7 * s * s
		var al: float = smoothstep(0.0, 0.3, st) * (1.0 - smoothstep(0.82, 1.0, s))
		for k in 4:
			var off := Vector2(sin(st * 5.0 + float(k)) * 4.0 * u, float(k) * 12.0 * u * s)
			var sz := Vector2(S * sc2 * (1.0 - 0.1 * s), S * sc2 * (1.0 + 0.5 * s))
			var ak: float = al * (0.62 if k == 0 else 0.2 / float(k))
			ci.draw_texture_rect(victim_tex, Rect2(pos2 + off - sz * 0.5, sz), false, Color(c2.r * 0.8 + 0.2, c2.g * 0.8 + 0.2, c2.b * 0.8 + 0.2, ak))
		FxDraw.glow_dot(ci, pos2, 18.0 * u * sc2, FxDraw.ca(c1, 0.5 * al))
		for k in 3:
			var oa: float = st * 5.0 + float(k) * TAU / 3.0
			FxDraw.glow_dot(ci, pos2 + Vector2(cos(oa), sin(oa) * 0.6) * 22.0 * u * sc2, 2.2 * u, FxDraw.ca(c2, al))
		if s > 0.98:
			var ab: float = clampf((st - 1.86) / 0.06, 0.0, 1.0)
			ci.draw_circle(H, 40.0 * u * ab, FxDraw.ca(c2, 0.7 * ab))
	if t > 2.45 and t < 2.85:
		var f3: float = (t - 2.45) / 0.4
		ci.draw_circle(H, 50.0 * u * (1.0 - f3), FxDraw.ca(c2, 0.8 * (1.0 - f3)))
		_ring(ci, H, (20.0 + 130.0 * f3) * u, (20.0 + 130.0 * f3) * u, FxDraw.ca(c1, 1.0 - f3), 4.0 * u * (1.0 - f3) + 1.0)
	if t > 1.5 and t < 2.6:
		for i in 30:
			var p2: Vector2 = FxDraw.ph(t - 1.5, i, 30, 1.1)
			var pos3 := Vector2(V.x + (FxDraw.rnd(i, p2.y, 1.0) - 0.5) * usize * 0.8 + p2.x * 70.0 * u, V.y - usize * 0.4 + FxDraw.rnd(i, p2.y, 2.0) * usize * 0.9 + p2.x * 40.0 * u)
			ci.draw_rect(Rect2(pos3, Vector2(2.6, 2.6) * u), Color(0.5, 0.52, 0.54, 0.85 * (1.0 - p2.x)))
	var gk: float = smoothstep(2.3, 2.7, t) * (1.0 - smoothstep(3.2, 3.55, t))
	if gk > 0.2:
		var gw: float = 0.8 * S
		var gh: float = 1.1 * S * smoothstep(2.3, 2.7, t)
		var base := Vector2(V.x, gy)
		var pts := PackedVector2Array()
		pts.append(base + Vector2(-gw * 0.5, 0))
		pts.append(base + Vector2(-gw * 0.5, -gh * 0.7))
		for k in range(1, 8):
			var a2: float = PI + float(k) / 8.0 * PI
			pts.append(base + Vector2(cos(a2) * gw * 0.5, -gh * 0.7 + sin(a2) * gh * 0.3))
		pts.append(base + Vector2(gw * 0.5, -gh * 0.7))
		pts.append(base + Vector2(gw * 0.5, 0))
		ci.draw_colored_polygon(pts, Color(0.42, 0.45, 0.48, gk))
		var pl: PackedVector2Array = pts.duplicate()
		pl.append(pts[0])
		ci.draw_polyline(pl, Color(0.12, 0.14, 0.16, gk), 2.5 * u, true)
		ci.draw_line(base + Vector2(0, -gh * 0.85), base + Vector2(0, -gh * 0.4), Color(0.14, 0.16, 0.18, gk), 3.0 * u)
		ci.draw_line(base + Vector2(-gw * 0.2, -gh * 0.7), base + Vector2(gw * 0.2, -gh * 0.7), Color(0.14, 0.16, 0.18, gk), 3.0 * u)
		FxDraw.glow_dot(ci, base + Vector2(gw * 0.7, -gh * 0.2 + sin(t * 9.0) * 1.5 * u), 4.0 * u, FxDraw.ca(c1, gk))
		_ell(ci, base + Vector2(0, 1.0 * u), gw * 0.7, gw * 0.14, Color(0.0, 0.0, 0.0, 0.4 * gk))


# ================================================================== 15. DIMENSION RIFT (portal)
## 0.1-0.8 portal terbuka di bawah kaki | 0.85-1.75 korban tenggelam berputar | 2.0-2.3 portal menyusut lalu meledak (bintang + kejut)
func _portal_open() -> float:
	return smoothstep(0.1, 0.8, t) * (1.0 - smoothstep(2.0, 2.3, t))


func _v_portal() -> void:
	var V: Vector2 = vpos
	var s_k: float = smoothstep(0.85, 1.75, t)
	var pre: float = smoothstep(0.3, 0.85, t) * (1.0 - s_k)
	var gp: Vector2 = V + Vector2(0, usize * 0.5)
	var sy: float = maxf(lerpf(1.0, 0.0, s_k * s_k), 0.03)
	var sx: float = lerpf(1.0, 0.35, s_k)
	var lift: float = -usize * 0.12 * pre
	var tint: Color = Color(1, 1, 1, 1).lerp(Color(0.7, 0.55, 1.2, 1.0), smoothstep(0.4, 1.4, t) * 0.7)
	_set_v(gp + Vector2(0, -usize * sy * 0.5 + lift), sin(t * 14.0) * 0.06 * pre + s_k * 0.6, Vector2(sx, sy), 1.0, tint, 0, 0.0, c1)
	_vsp.visible = t < 1.78


func _back_portal(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var op: float = _portal_open()
	if op <= 0.01:
		return
	var P := Vector2(V.x, V.y + usize * 0.5)
	var rx: float = 66.0 * u * op
	var ry: float = rx * 0.27
	_ell(ci, P, rx * 1.35, ry * 1.5, FxDraw.ca(c1, 0.16 * op), 32)
	_ell(ci, P, rx, ry, Color(0.01, 0.0, 0.04, 0.96))
	for arm in 3:
		var pts := PackedVector2Array()
		for k in 22:
			var s: float = float(k) / 21.0
			var a: float = float(arm) * TAU / 3.0 + s * 5.0 - t * 3.5
			pts.append(P + Vector2(cos(a) * rx * s * 0.95, sin(a) * ry * s * 0.95))
		ci.draw_polyline(pts, FxDraw.ca(c2, 0.7 * op), 2.0 * u, true)
	_ell_arc(ci, P, rx, ry, PI, TAU, FxDraw.ca(c1, 0.95), 6.0 * u)
	_ell_arc(ci, P, rx * 0.93, ry * 0.93, PI, TAU, FxDraw.ca(c2, 0.9), 2.5 * u)
	var pil: float = smoothstep(0.6, 1.0, t) * (1.0 - smoothstep(1.9, 2.1, t))
	if pil > 0.01:
		var hh: float = 230.0 * u
		ci.draw_polygon(PackedVector2Array([P + Vector2(-rx * 0.6, 0), P + Vector2(rx * 0.6, 0), P + Vector2(rx * 0.4, -hh), P + Vector2(-rx * 0.4, -hh)]),
			PackedColorArray([FxDraw.ca(c1, 0.4 * pil), FxDraw.ca(c1, 0.4 * pil), FxDraw.ca(c1, 0.0), FxDraw.ca(c1, 0.0)]))


func _front_portal(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var op: float = _portal_open()
	var P := Vector2(V.x, V.y + usize * 0.5)
	if op > 0.01:
		var rx: float = 66.0 * u * op
		var ry: float = rx * 0.27
		_ell_arc(ci, P, rx, ry, 0.0, PI, FxDraw.ca(c1, 0.25), 14.0 * u)
		_ell_arc(ci, P, rx, ry, 0.0, PI, FxDraw.ca(c1, 1.0), 6.0 * u)
		_ell_arc(ci, P, rx * 0.93, ry * 0.93, 0.0, PI, FxDraw.ca(c2, 0.95), 2.5 * u)
		for k in 6:
			var sd: float = floorf(t * 14.0) + float(k) * 5.0
			var a: float = FxDraw.h(sd, 1.0) * TAU
			var A := P + Vector2(cos(a) * rx, sin(a) * ry)
			FxDraw.bolt(ci, A, A + Vector2(cos(a) * 24.0 * u, -30.0 * u - 30.0 * u * FxDraw.h(sd, 2.0)), sd, FxDraw.ca(c2, 0.85 * op), 1.8 * u, 5, 6.0 * u)
		for i in 34:
			var p: Vector2 = FxDraw.ph(t, i, 34, 1.0)
			var a2: float = FxDraw.rnd(i, p.y, 1.0) * TAU + p.x * 6.0
			var rr: float = (1.0 - p.x) * 120.0 * u + rx * 0.2
			FxDraw.glow_dot(ci, P + Vector2(cos(a2) * rr, sin(a2) * rr * 0.27 - 8.0 * u * (1.0 - p.x)), 1.8 * u * (1.0 - p.x) + 0.5, FxDraw.ca(c1.lerp(c2, p.x), minf(1.0, p.x * 3.0) * op))
	if t > 2.0 and t < 2.3:
		var f: float = (t - 2.0) / 0.3
		_ring(ci, P, 66.0 * u * (1.0 - f), 18.0 * u * (1.0 - f), Color(1, 1, 1, f), 5.0 * u)
	if t >= 2.3:
		var tt: float = t - 2.3
		if tt < 0.15:
			ci.draw_circle(P + Vector2(0, -10.0 * u), 70.0 * u * (1.0 - tt / 0.15), Color(1, 1, 1, 0.95))
		var f2: float = clampf(tt / 0.9, 0.0, 1.0)
		for k in 2:
			var ff: float = clampf(f2 * (1.0 + 0.2 * float(k)), 0.0, 1.0)
			_ring(ci, P, (10.0 + 220.0 * ff) * u, (10.0 + 220.0 * ff) * u * 0.27, FxDraw.ca(c1 if k == 0 else c2, 1.0 - ff), 6.0 * u * (1.0 - ff) + 1.0)
		for i in 30:
			var a3: float = FxDraw.h(float(i), 3.0) * PI + PI
			var spd: float = (80.0 + 220.0 * FxDraw.h(float(i), 4.0)) * u
			var pos: Vector2 = P + Vector2(cos(a3) * spd * tt, sin(a3) * spd * tt + 300.0 * u * tt * tt)
			if tt < 1.1:
				FxDraw.star4(ci, pos, (3.0 + 3.5 * FxDraw.h(float(i), 5.0)) * u * (1.0 - tt / 1.3), FxDraw.ca(c1 if i % 2 == 0 else c2, 1.0 - tt / 1.3))
		var sc: float = 1.0 - smoothstep(0.2, 1.3, tt)
		_ring(ci, P, 60.0 * u, 16.0 * u, FxDraw.ca(c1, 0.5 * sc), 3.0 * u)
		_ell(ci, P, 50.0 * u, 12.0 * u, Color(0.05, 0.0, 0.08, 0.5 * sc))


# ================================================================== 16. SANDS OF TIME (sands)
## 0.2-0.5 jam pasir raksasa muncul, 0.5-0.9 berputar 180 derajat, lalu pasir mengalir | 1.1-2.4 korban berubah emas & jadi pasir
## yang tertiup angin | cincin jam berdetak mundur | gundukan pasir di tanah
func _v_sands() -> void:
	var V: Vector2 = vpos
	var gold: float = smoothstep(0.4, 1.1, t)
	var am: float = smoothstep(1.1, 2.4, t)
	var tint: Color = Color(1, 1, 1, 1).lerp(Color(1.3, 1.05, 0.55, 1.0), gold * 0.8)
	_set_v(V, 0.0, Vector2.ONE, 1.0, tint, 1, am, c1)
	_vsp.visible = t < 2.5


func _back_sands(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var S: float = usize
	var g: float = smoothstep(0.2, 0.5, t) * (1.0 - smoothstep(2.6, 3.2, t))
	if g <= 0.01:
		return
	var C: Vector2 = V + Vector2(0, -0.1 * S)
	var H: float = 1.25 * S
	var W: float = 0.7 * S
	var flip: float = smoothstep(0.5, 0.9, t)
	var flow: float = clampf((t - 0.9) / 1.9, 0.0, 1.0)
	var fb: float = 1.0
	var ft: float = 0.0
	if t > 0.9:
		fb = 1.0 - flow
		ft = flow
	ci.draw_set_transform(C, PI * flip, Vector2.ONE)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-W, -H), Vector2(W, -H), Vector2(W * 0.1, 0), Vector2(-W * 0.1, 0)]), FxDraw.ca(c2, 0.14 * g))
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-W * 0.1, 0), Vector2(W * 0.1, 0), Vector2(W, H), Vector2(-W, H)]), FxDraw.ca(c2, 0.14 * g))
	if ft > 0.02:
		var yt: float = -H * ft
		var wt: float = lerpf(0.1, 1.0, -yt / H) * W * 0.92
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-wt, yt), Vector2(wt, yt), Vector2(W * 0.09, 0), Vector2(-W * 0.09, 0)]), FxDraw.ca(c1, 0.92 * g))
	if fb > 0.02:
		var yb: float = H * (1.0 - fb)
		var wb: float = lerpf(0.1, 1.0, yb / H) * W * 0.92
		ci.draw_colored_polygon(PackedVector2Array([Vector2(-wb, yb), Vector2(wb, yb), Vector2(W * 0.92, H * 0.97), Vector2(-W * 0.92, H * 0.97)]), FxDraw.ca(c1, 0.92 * g))
	if t > 0.9 and t < 2.85:
		ci.draw_line(Vector2(0, 0), Vector2(0, -H * 0.96 * (1.0 - flow * 0.5)), FxDraw.ca(c1.lightened(0.3), 0.9 * g), 3.0 * u)
	var edge: Color = FxDraw.ca(c1.lightened(0.25), 0.95 * g)
	ci.draw_polyline(PackedVector2Array([Vector2(-W, -H), Vector2(W * 0.1, 0), Vector2(-W, H)]), edge, 3.0 * u, true)
	ci.draw_polyline(PackedVector2Array([Vector2(W, -H), Vector2(-W * 0.1, 0), Vector2(W, H)]), edge, 3.0 * u, true)
	ci.draw_rect(Rect2(-W * 1.15, -H - 7.0 * u, W * 2.3, 9.0 * u), FxDraw.ca(c1.darkened(0.2), g))
	ci.draw_rect(Rect2(-W * 1.15, H - 2.0 * u, W * 2.3, 9.0 * u), FxDraw.ca(c1.darkened(0.2), g))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var cg: float = smoothstep(0.4, 0.8, t) * (1.0 - smoothstep(2.3, 2.7, t))
	if cg > 0.01:
		var R: float = 1.3 * S
		ci.draw_arc(V, R, 0.0, TAU, 48, FxDraw.ca(c2, 0.7 * cg), 3.0 * u, true)
		ci.draw_arc(V, R * 0.92, 0.0, TAU, 48, FxDraw.ca(c2, 0.25 * cg), 1.5 * u, true)
		for k in 12:
			var a: float = float(k) / 12.0 * TAU
			var d := Vector2(cos(a), sin(a))
			ci.draw_line(V + d * R * 0.9, V + d * R * 1.04, FxDraw.ca(c2, 0.9 * cg), 2.5 * u)
		var ha: float = -t * 8.0
		var ma: float = -t * 34.0
		ci.draw_line(V, V + Vector2(cos(ha), sin(ha)) * R * 0.5, FxDraw.ca(c2, 0.9 * cg), 4.0 * u)
		ci.draw_line(V, V + Vector2(cos(ma), sin(ma)) * R * 0.8, FxDraw.ca(c1, 0.9 * cg), 2.5 * u)


func _front_sands(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var gy: float = V.y + usize * 0.5
	for i in 80:
		var tr: float = 1.1 + 1.3 * FxDraw.h(float(i), 1.0)
		var tt: float = t - tr
		if tt <= 0.0:
			continue
		var base := Vector2(V.x + (FxDraw.h(float(i), 2.0) - 0.5) * usize * 0.8, V.y + (FxDraw.h(float(i), 3.0) - 0.5) * usize * 0.9)
		var wind: float = (70.0 + 170.0 * FxDraw.h(float(i), 4.0)) * u
		var pos: Vector2 = base + Vector2(wind * tt, -20.0 * u * sin(tt * 3.0 + float(i)) + 60.0 * u * tt * tt)
		var al: float = 1.0 - smoothstep(0.9, 1.6, tt)
		var cc: Color = c1.lerp(Color.WHITE, FxDraw.h(float(i), 5.0) * 0.35)
		ci.draw_rect(Rect2(pos, Vector2(2.4, 2.4) * u), FxDraw.ca(cc, al))
		if i % 4 == 0:
			ci.draw_line(pos, pos - Vector2(wind * 0.06, 0), FxDraw.ca(cc, al * 0.5), 1.4 * u)
	if t > 1.3 and t < 3.0:
		for i in 14:
			var p: Vector2 = FxDraw.ph(t, i, 14, 1.4)
			var a: float = p.x * 9.0 + float(i)
			var rr: float = (20.0 + 90.0 * p.x) * u
			FxDraw.glow_dot(ci, V + Vector2(cos(a) * rr, sin(a) * rr * 0.5 - 10.0 * u), 1.6 * u, FxDraw.ca(c2, sin(p.x * PI) * 0.8))
	var pk: float = smoothstep(1.4, 2.8, t) * (1.0 - smoothstep(3.1, 3.5, t))
	if pk > 0.01:
		var pts := PackedVector2Array()
		for k in 15:
			var s: float = float(k) / 14.0
			var x: float = (s - 0.5) * 2.0 * 34.0 * u
			var y: float = -pow(1.0 - absf(s - 0.5) * 2.0, 1.5) * 20.0 * u * pk
			pts.append(Vector2(V.x + x, gy + y))
		ci.draw_colored_polygon(pts, FxDraw.ca(c1.darkened(0.1), pk))
		ci.draw_polyline(pts, FxDraw.ca(c1.lightened(0.3), pk), 2.0 * u, true)
	if t > 0.85 and t < 1.0:
		var f: float = (t - 0.85) / 0.15
		ci.draw_circle(V + Vector2(0, -0.1 * usize), 70.0 * u * (1.0 - f), FxDraw.ca(c2, 0.5 * (1.0 - f)))


# ================================================================== 17. GRAND FINALE (firework)
## 0.15-0.7 sumbu menyala, korban bergetar | 0.7-1.6 meluncur seperti roket | 1.6 LEDAKAN kembang api besar | 1.9 & 2.2 ledakan susulan | glitter jatuh
const FW_RISE := 190.0


func _v_firework() -> void:
	var V: Vector2 = vpos
	var u: float = _u
	if t < 0.7:
		var sh: float = smoothstep(0.15, 0.7, t)
		_set_v(V + Vector2(sin(t * 70.0) * 2.0 * u * sh, 0.0), 0.0, Vector2.ONE * (1.0 + 0.06 * sh), 1.0, Color(1, 1, 1, 1).lerp(Color(1.4, 1.15, 0.7, 1.0), sh * 0.7), 0, 0.0, c1)
	else:
		var fl: float = clampf((t - 0.7) / 0.9, 0.0, 1.0)
		var h2: float = FW_RISE * u * pow(fl, 1.6)
		var sway: float = sin(fl * PI * 3.0) * 7.0 * u * fl
		_set_v(V + Vector2(sway, -h2), fl * 14.0, Vector2.ONE * (1.0 - 0.35 * fl), 1.0, Color(1.4, 1.15, 0.7, 1.0), 0, 0.0, c1)
	_vsp.visible = t < 1.6


func _fw_burst(ci: CanvasItem, cen: Vector2, t0: float, radius: float, n: int, rainbow: bool, seed_: float) -> void:
	var tt: float = t - t0
	if tt < 0.0:
		return
	var u: float = _u
	if tt < 0.16:
		ci.draw_circle(cen, 70.0 * u * (1.0 - tt / 0.16) * (radius / 150.0), Color(1, 1, 0.9, 0.95 * (1.0 - tt / 0.16)))
	var ease_: float = 1.0 - pow(1.0 - clampf(tt / 0.9, 0.0, 1.0), 3.0)
	var fade: float = 1.0 - smoothstep(0.8, 1.7, tt)
	if fade <= 0.0:
		return
	for k in n:
		var a: float = float(k) * TAU / float(n) + FxDraw.h(float(k), seed_) * 0.25
		var dir := Vector2(cos(a), sin(a))
		var rr: float = radius * u * (0.7 + 0.3 * FxDraw.h(float(k), seed_ + 1.0))
		var cc: Color = FxDraw.hue(float(k) / float(n) + seed_ * 0.1, 1.0, 0.65, 1.0) if rainbow else (c1 if k % 2 == 0 else c2)
		var head: Vector2 = cen + dir * rr * ease_ + Vector2(0, 90.0 * u * tt * tt)
		for j in 5:
			var back: float = float(j) * 0.045
			var e2: float = 1.0 - pow(1.0 - clampf((tt - back) / 0.9, 0.0, 1.0), 3.0)
			var pp: Vector2 = cen + dir * rr * e2 + Vector2(0, 90.0 * u * maxf(tt - back, 0.0) * maxf(tt - back, 0.0))
			FxDraw.glow_dot(ci, pp, (2.2 - float(j) * 0.35) * u, FxDraw.ca(cc, fade * (1.0 - float(j) * 0.18)))
		FxDraw.star4(ci, head, 5.0 * u * (0.6 + 0.4 * sin(tt * 20.0 + float(k))), FxDraw.ca(Color.WHITE, fade))
	for i in 26:
		var p: Vector2 = FxDraw.ph(tt, i, 26, 1.3)
		var a2: float = FxDraw.rnd(i, p.y, seed_) * TAU
		var rr2: float = radius * u * (0.3 + 0.7 * FxDraw.rnd(i, p.y, seed_ + 2.0)) * ease_
		var pos: Vector2 = cen + Vector2(cos(a2) * rr2, sin(a2) * rr2 + 80.0 * u * p.x * p.x)
		if FxDraw.h(float(i), 7.0 + seed_) > 0.5:
			FxDraw.glow_dot(ci, pos, 1.3 * u, FxDraw.ca(Color.WHITE, fade * (0.5 + 0.5 * sin(tt * 40.0 + float(i)))))


func _back_firework(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var B: Vector2 = V + Vector2(0, -FW_RISE * u)
	for i in 40:
		var pos := Vector2(bounds.position.x + FxDraw.h(float(i), 1.0) * bounds.size.x, bounds.position.y + FxDraw.h(float(i), 2.0) * bounds.size.y * 0.8)
		ci.draw_circle(pos, (0.8 + 1.2 * FxDraw.h(float(i), 3.0)) * _sc, Color(1, 1, 1, 0.6 * (0.5 + 0.5 * sin(t * 3.0 + float(i))) * _vig()))
	if t >= 1.6:
		var gl: float = (1.0 - smoothstep(1.6, 3.0, t))
		ci.draw_circle(B, 170.0 * u, FxDraw.ca(c1, 0.12 * gl))
	if t > 0.7 and t < 1.6:
		var fl: float = clampf((t - 0.7) / 0.9, 0.0, 1.0)
		for i in 10:
			var p: Vector2 = FxDraw.ph(t, i, 10, 0.9)
			ci.draw_circle(Vector2(V.x + (FxDraw.rnd(i, p.y, 1.0) - 0.5) * 50.0 * u, V.y + usize * 0.5 - p.x * 40.0 * u), (10.0 + 24.0 * p.x) * u, Color(0.8, 0.8, 0.85, 0.28 * (1.0 - p.x) * (1.0 - fl * 0.6)))


func _front_firework(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var B: Vector2 = V + Vector2(0, -FW_RISE * u)
	if t > 0.1 and t < 0.7:
		var top := Vector2(V.x, V.y - usize * 0.55)
		var f: float = (t - 0.1) / 0.6
		var fuse: Vector2 = top + Vector2(0, -usize * 0.3 * (1.0 - f))
		ci.draw_line(top, fuse, Color(0.9, 0.75, 0.5, 0.9), 2.0 * u)
		FxDraw.glow_dot(ci, fuse, 3.0 * u, Color(1, 0.9, 0.5, 1))
		for i in 10:
			var a: float = FxDraw.h(float(i) + floorf(t * 30.0), 1.0) * TAU
			ci.draw_line(fuse, fuse + Vector2(cos(a), sin(a)) * (6.0 + 14.0 * FxDraw.h(float(i), 2.0)) * u, FxDraw.ca(c2, 0.9), 1.6 * u)
	if t >= 0.7 and t < 1.7:
		var fl: float = clampf((t - 0.7) / 0.9, 0.0, 1.0)
		var cur: Vector2 = V + Vector2(sin(fl * PI * 3.0) * 7.0 * u * fl, -FW_RISE * u * pow(fl, 1.6))
		for i in 34:
			var q: float = float(i) / 34.0
			var fl2: float = maxf(fl - q * 0.25, 0.0)
			var pp: Vector2 = V + Vector2(sin(fl2 * PI * 3.0) * 7.0 * u * fl2, -FW_RISE * u * pow(fl2, 1.6) + usize * 0.3) + Vector2(sin(float(i) * 7.0) * 4.0 * u * q, 0.0)
			FxDraw.glow_dot(ci, pp, (4.5 * (1.0 - q) + 0.8) * u, FxDraw.ca(c1.lerp(c2, q), (1.0 - q) * 0.9 * (1.0 - smoothstep(1.55, 1.7, t))))
		if t < 1.6:
			FxDraw.star4(ci, cur + Vector2(0, usize * 0.5), 9.0 * u, FxDraw.ca(Color.WHITE, 0.9))
	_fw_burst(ci, B, 1.6, 150.0, 28, false, 1.0)
	_fw_burst(ci, B + Vector2(-110.0, 30.0) * u, 1.9, 85.0, 18, true, 2.0)
	_fw_burst(ci, B + Vector2(120.0, 10.0) * u, 2.2, 95.0, 20, true, 3.0)
	if t >= 1.6:
		var tt: float = t - 1.6
		for i in 70:
			var a: float = -PI * 0.5 + (FxDraw.h(float(i), 8.0) - 0.5) * 3.4
			var spd: float = (60.0 + 220.0 * FxDraw.h(float(i), 9.0)) * u
			var pos: Vector2 = B + Vector2(cos(a) * spd * tt + sin(tt * 6.0 + float(i)) * 6.0 * u, sin(a) * spd * tt + 150.0 * u * tt * tt)
			var al: float = 1.0 - smoothstep(1.0, 1.9, tt)
			var wd: float = absf(cos(tt * 9.0 + float(i))) * 5.0 * u + 0.8
			ci.draw_rect(Rect2(pos, Vector2(wd, 7.0 * u)), FxDraw.ca(FxDraw.hue(FxDraw.h(float(i), 10.0), 1.0, 0.6, 1.0), al))


# ================================================================== 18. ORBITAL STRIKE (orbital)
## 0.2-1.0 reticle mengunci korban | 1.0-1.3 pengisian daya | 1.3 SINAR dari satelit menguapkan korban, kamera bergetar | 2.4 sinar padam,
## titik panas mendingin, asap naik
func _v_orbital() -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var lock: float = smoothstep(0.2, 1.0, t)
	var blink: float = 0.5 + 0.5 * sin(t * 22.0)
	if t < 1.3:
		_set_v(V, 0.0, Vector2.ONE, 1.0, Color(1, 1, 1, 1).lerp(Color(1.4, 0.55 + 0.3 * blink, 0.5, 1.0), lock * 0.6), 0, 0.0, c1)
	else:
		var am: float = smoothstep(1.3, 1.9, t)
		_set_v(V + Vector2(sin(t * 90.0), cos(t * 77.0)) * 2.0 * u * (1.0 - am), 0.0, Vector2.ONE, 1.0, Color(2.6, 2.4, 2.2, 1.0), 1, am, c2)
	_vsp.visible = t < 1.95


func _back_orbital(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var gy: float = V.y + usize * 0.5
	var lk: float = smoothstep(0.2, 0.5, t) * (1.0 - smoothstep(2.4, 2.9, t))
	if lk > 0.01:
		var rr: float = (60.0 - 16.0 * smoothstep(0.2, 1.0, t)) * u
		_ell(ci, Vector2(V.x, gy), rr, rr * 0.26, FxDraw.ca(c1, 0.16 * lk))
		_ring(ci, Vector2(V.x, gy), rr, rr * 0.26, FxDraw.ca(c1, 0.85 * lk), 2.0 * u)
	if t >= 1.3 and t < 2.6:
		var tt: float = t - 1.3
		var cg: float = smoothstep(0.0, 0.15, tt)
		var fade: float = 1.0 - smoothstep(0.9, 1.3, tt)
		var G := Vector2(V.x, gy + 1.0 * u)
		_ell(ci, G, 70.0 * u * cg, 17.0 * u * cg, Color(0.02, 0.01, 0.01, 0.8 * (1.0 - smoothstep(1.0, 1.3, tt))))
		var hot: float = (1.0 - smoothstep(0.4, 1.3, tt))
		_ell(ci, G, 44.0 * u * cg, 11.0 * u * cg, FxDraw.ca(c1, 0.9 * hot * (0.7 + 0.3 * fade)))
		_ell(ci, G, 22.0 * u * cg, 5.0 * u * cg, Color(1, 0.95, 0.85, hot))


func _front_orbital(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var gy: float = V.y + usize * 0.5
	var C := Vector2(V.x, V.y - usize * 0.1)
	var lk: float = smoothstep(0.2, 0.45, t) * (1.0 - smoothstep(1.3, 1.45, t))
	if lk > 0.01:
		var lockf: float = smoothstep(0.2, 1.0, t)
		var R: float = (150.0 - 100.0 * lockf) * u
		var lc: Color = c1.lerp(Color.WHITE, 0.2 * (0.5 + 0.5 * sin(t * 24.0)))
		ci.draw_arc(C, R, 0.0, TAU, 48, FxDraw.ca(lc, 0.9 * lk), 2.5 * u, true)
		ci.draw_arc(C, R * 0.6, 0.0, TAU, 40, FxDraw.ca(lc, 0.5 * lk), 1.5 * u, true)
		for k in 4:
			var a: float = float(k) * PI * 0.5 + t * (1.2 - lockf)
			ci.draw_arc(C, R * 1.12, a - 0.22, a + 0.22, 8, FxDraw.ca(lc, lk), 5.0 * u, true)
		ci.draw_line(C + Vector2(-R * 1.4, 0), C + Vector2(-R * 0.35, 0), FxDraw.ca(lc, 0.9 * lk), 2.0 * u)
		ci.draw_line(C + Vector2(R * 0.35, 0), C + Vector2(R * 1.4, 0), FxDraw.ca(lc, 0.9 * lk), 2.0 * u)
		ci.draw_line(C + Vector2(0, -R * 1.4), C + Vector2(0, -R * 0.35), FxDraw.ca(lc, 0.9 * lk), 2.0 * u)
		ci.draw_line(C + Vector2(0, R * 0.35), C + Vector2(0, R * 1.4), FxDraw.ca(lc, 0.9 * lk), 2.0 * u)
		var sy: float = V.y - usize * 0.6 + fposmod(t * 1.8, 1.0) * usize * 1.2
		ci.draw_line(Vector2(V.x - usize * 0.7, sy), Vector2(V.x + usize * 0.7, sy), FxDraw.ca(c1, 0.6 * lk), 2.0 * u)
		if Global.font_ui != null and (int(t * 8.0) % 2 == 0 or lockf > 0.95):
			var fs: int = maxi(int(20.0 * _sc), 8)
			var txt: String = "TARGET LOCKED" if lockf > 0.95 else "LOCKING..."
			ci.draw_string(Global.font_ui, C + Vector2(-R * 0.9, -R * 1.25), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, FxDraw.ca(lc, lk))
	var topy: float = V.y - 900.0 * u
	if t > 1.0 and t < 1.3:
		var f: float = (t - 1.0) / 0.3
		ci.draw_line(Vector2(V.x, topy), C, FxDraw.ca(c1, 0.3 + 0.5 * f), (1.5 + 2.5 * f) * u)
		FxDraw.glow_dot(ci, C + Vector2(0, -usize * 0.8) * (1.0 - f), (6.0 + 10.0 * f) * u, FxDraw.ca(c2, f))
	if t >= 1.3 and t < 2.7:
		var tt: float = t - 1.3
		var wgrow: float = smoothstep(0.0, 0.1, tt)
		var wend: float = 1.0 - smoothstep(0.9, 1.3, tt)
		var fl: float = 0.85 + 0.15 * sin(t * 60.0)
		var w: float = 58.0 * u * wgrow * wend * fl
		if w > 0.5:
			var gp := Vector2(V.x, gy)
			ci.draw_polygon(PackedVector2Array([Vector2(V.x - w * 1.5, topy), Vector2(V.x + w * 1.5, topy), Vector2(V.x + w * 1.5, gp.y), Vector2(V.x - w * 1.5, gp.y)]), PackedColorArray([FxDraw.ca(c1, 0.0), FxDraw.ca(c1, 0.0), FxDraw.ca(c1, 0.35), FxDraw.ca(c1, 0.35)]))
			ci.draw_rect(Rect2(V.x - w, topy, w * 2.0, gp.y - topy), FxDraw.ca(c1, 0.7))
			ci.draw_rect(Rect2(V.x - w * 0.55, topy, w * 1.1, gp.y - topy), FxDraw.ca(c2, 0.95))
			ci.draw_rect(Rect2(V.x - w * 0.25, topy, w * 0.5, gp.y - topy), Color(1, 1, 1, 1))
			for k in 3:
				var yy: float = fposmod(t * 3.0 + float(k) / 3.0, 1.0)
				ci.draw_rect(Rect2(V.x - w * 1.3, topy + (gp.y - topy) * yy, w * 2.6, 3.0 * u), FxDraw.ca(Color.WHITE, 0.6))
		if tt < 0.35:
			var f2: float = tt / 0.35
			ci.draw_circle(Vector2(V.x, gy), 90.0 * u * (1.0 - f2 * 0.5), Color(1, 0.95, 0.85, 0.9 * (1.0 - f2)))
		for k in 3:
			var f3: float = clampf((tt - float(k) * 0.12) / 0.8, 0.0, 1.0)
			if f3 > 0.0 and f3 < 1.0:
				var rr: float = (12.0 + 200.0 * f3) * u
				_ring(ci, Vector2(V.x, gy), rr, rr * 0.26, FxDraw.ca(c1.lerp(Color.WHITE, 0.4), (1.0 - f3)), (6.0 - float(k)) * u * (1.0 - f3) + 1.0)
		for i in 36:
			var p: Vector2 = FxDraw.ph(tt, i, 36, 1.0)
			var a2: float = -PI * 0.5 + (FxDraw.rnd(i, p.y, 1.0) - 0.5) * 2.4
			var sp: float = (80.0 + 260.0 * FxDraw.rnd(i, p.y, 2.0)) * u
			var pos := Vector2(V.x + cos(a2) * sp * p.x, gy + sin(a2) * sp * p.x + 420.0 * u * p.x * p.x)
			FxDraw.glow_dot(ci, pos, 1.8 * u * (1.0 - p.x) + 0.5, FxDraw.ca(c2.lerp(c1, p.x), (1.0 - p.x) * wend))
	if t > 1.9:
		for i in 10:
			var p2: Vector2 = FxDraw.ph(t - 1.9, i, 10, 1.6)
			ci.draw_circle(Vector2(V.x + (FxDraw.rnd(i, p2.y, 1.0) - 0.5) * 50.0 * u + sin(p2.x * 5.0 + float(i)) * 8.0 * u, gy - p2.x * 130.0 * u), (9.0 + 24.0 * p2.x) * u, Color(0.18, 0.16, 0.16, 0.36 * sin(p2.x * PI) * (1.0 - smoothstep(3.0, 3.5, t))))


# ================================================================== 19. CURSED SEAL (hex)
## 0.1-0.7 lingkaran segel terbentuk di tanah | 0.55-1.4 rantai menyembur & melilit korban | 1.0-1.75 korban terangkat dan diremas |
## 1.97 korban jadi sigil melayang | 2.6 sigil pecah jadi serpihan rune
func _hex_g() -> float:
	return smoothstep(0.1, 0.7, t) * (1.0 - smoothstep(2.1, 2.6, t))


func _v_hex() -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var sq: float = smoothstep(1.0, 1.75, t)
	var fin: float = smoothstep(1.7, 1.97, t)
	var tint: Color = Color(1, 1, 1, 1).lerp(Color(0.75, 0.45, 1.0, 1.0), smoothstep(0.5, 1.2, t) * 0.8)
	var lift: float = -usize * 0.18 * smoothstep(0.7, 1.4, t)
	var sc := Vector2(maxf(lerpf(1.0, 0.6, sq) * (1.0 - fin), 0.03), maxf(lerpf(1.0, 0.85, sq) * (1.0 - fin), 0.03))
	_set_v(V + Vector2(sin(t * 60.0) * 1.0 * u * sq, lift), fin * 3.0, sc, 1.0, tint, 0, 0.0, c1)
	_vsp.visible = t < 1.97


func _draw_sigil(ci: CanvasItem, R: float, rot: float, col: Color, col2: Color, w: float) -> void:
	ci.draw_arc(Vector2.ZERO, R, 0.0, TAU, 40, col, w, true)
	ci.draw_arc(Vector2.ZERO, R * 0.78, 0.0, TAU, 36, col2, w * 0.7, true)
	var pts := PackedVector2Array()
	for i in 6:
		var a: float = rot - PI * 0.5 + float(i) * 4.0 * PI / 5.0
		pts.append(Vector2(cos(a), sin(a)) * R * 0.78)
	ci.draw_polyline(pts, col2, w * 0.8, true)
	for k in 12:
		var a2: float = rot * -1.0 + float(k) * TAU / 12.0
		var d := Vector2(cos(a2), sin(a2))
		ci.draw_line(d * R * 0.86, d * R * 0.97, col, w * 0.9)


func _back_hex(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var g: float = _hex_g()
	if g <= 0.01:
		return
	var P := Vector2(V.x, V.y + usize * 0.5)
	ci.draw_set_transform(P, 0.0, Vector2(1.0, 0.28))
	ci.draw_circle(Vector2.ZERO, 84.0 * u * g, FxDraw.ca(c1, 0.14 * g))
	_draw_sigil(ci, 78.0 * u * g, t * 0.8, FxDraw.ca(c1, 0.95 * g), FxDraw.ca(c2, 0.9 * g), 3.0 * u)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var pil: float = smoothstep(0.5, 1.0, t) * g
	for k in 8:
		var a: float = float(k) * TAU / 8.0 + t * 0.4
		var bx: float = P.x + cos(a) * 78.0 * u
		var by: float = P.y + sin(a) * 78.0 * u * 0.28
		var hh: float = (110.0 + 40.0 * sin(t * 4.0 + float(k))) * u * pil
		ci.draw_polygon(PackedVector2Array([Vector2(bx - 4.0 * u, by), Vector2(bx + 4.0 * u, by), Vector2(bx + 2.0 * u, by - hh), Vector2(bx - 2.0 * u, by - hh)]),
			PackedColorArray([FxDraw.ca(c1, 0.5 * pil), FxDraw.ca(c1, 0.5 * pil), FxDraw.ca(c1, 0.0), FxDraw.ca(c1, 0.0)]))


func _front_hex(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var P := Vector2(V.x, V.y + usize * 0.5)
	var tight: float = smoothstep(1.3, 1.8, t)
	var fade: float = 1.0 - smoothstep(1.85, 1.97, t)
	for k in 5:
		var gk: float = smoothstep(0.55 + float(k) * 0.06, 1.0 + float(k) * 0.06, t)
		if gk <= 0.01 or fade <= 0.01:
			continue
		var a: float = float(k) * TAU / 5.0 + 0.4
		var B := Vector2(P.x + cos(a) * 78.0 * u, P.y + sin(a) * 78.0 * u * 0.28)
		var T := Vector2(V.x + cos(a * 2.0) * usize * 0.42, V.y - usize * 0.4 + float(k) * usize * 0.2)
		T = T.lerp(V, tight * 0.6)
		var Cp: Vector2 = (B + T) * 0.5 + Vector2(sin(a) * 40.0 * u, -50.0 * u)
		var n: int = 16
		var prev: Vector2 = B
		for j in range(1, n + 1):
			var s: float = float(j) / float(n) * gk
			var pt: Vector2 = B * (1.0 - s) * (1.0 - s) + Cp * 2.0 * (1.0 - s) * s + T * s * s
			ci.draw_line(prev, pt, FxDraw.ca(Color(0.18, 0.12, 0.2), fade), (4.2 if j % 2 == 0 else 2.4) * u)
			ci.draw_line(prev, pt, FxDraw.ca(c2, 0.9 * fade), (2.2 if j % 2 == 0 else 1.0) * u)
			prev = pt
		FxDraw.glow_dot(ci, prev, 3.0 * u, FxDraw.ca(c1, fade))
	var sg: float = smoothstep(1.97, 2.1, t) * (1.0 - smoothstep(2.55, 2.62, t))
	if sg > 0.01:
		var SP := Vector2(V.x, V.y - usize * 0.25 - 18.0 * u * smoothstep(1.97, 2.6, t) + sin(t * 4.0) * 3.0 * u)
		ci.draw_circle(SP, 60.0 * u * sg, FxDraw.ca(c1, 0.16 * sg))
		ci.draw_set_transform(SP, 0.0, Vector2.ONE)
		_draw_sigil(ci, 42.0 * u * (0.7 + 0.3 * sg), t * 2.0, FxDraw.ca(c1, sg), FxDraw.ca(c2, sg), 3.0 * u)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if t > 1.9 and t < 2.12:
		var f: float = (t - 1.9) / 0.22
		ci.draw_circle(V, 80.0 * u * (1.0 - f), Color(1, 1, 1, 0.85 * (1.0 - f)))
		_ring(ci, V, (10.0 + 120.0 * f) * u, (10.0 + 120.0 * f) * u, FxDraw.ca(c1, 1.0 - f), 5.0 * u * (1.0 - f) + 1.0)
	if t >= 2.6:
		var tt: float = t - 2.6
		var SP2 := Vector2(V.x, V.y - usize * 0.25 - 18.0 * u)
		if tt < 0.15:
			ci.draw_circle(SP2, 70.0 * u * (1.0 - tt / 0.15), Color(1, 1, 1, 0.9 * (1.0 - tt / 0.15)))
		for i in 24:
			var a2: float = float(i) * TAU / 24.0
			var spd: float = (60.0 + 150.0 * FxDraw.h(float(i), 2.0)) * u
			var pos: Vector2 = SP2 + Vector2(cos(a2), sin(a2)) * 42.0 * u + Vector2(cos(a2), sin(a2)) * spd * tt + Vector2(0, 90.0 * u * tt * tt)
			var al: float = 1.0 - smoothstep(0.3, 1.0, tt)
			ci.draw_set_transform(pos, a2 + tt * 6.0 * (FxDraw.h(float(i), 3.0) - 0.5), Vector2.ONE)
			ci.draw_line(Vector2(-5.0, 0) * u, Vector2(5.0, 0) * u, FxDraw.ca(c1 if i % 2 == 0 else c2, al), 2.6 * u)
			ci.draw_line(Vector2(0, -3.0) * u, Vector2(0, 3.0) * u, FxDraw.ca(c2, al), 1.6 * u)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 14:
			var p: Vector2 = FxDraw.ph(tt, i, 14, 1.0)
			var wx: float = SP2.x + (FxDraw.rnd(i, p.y, 1.0) - 0.5) * 100.0 * u
			FxDraw.glow_dot(ci, Vector2(wx, SP2.y - p.x * 90.0 * u), 2.4 * u * (1.0 - p.x), FxDraw.ca(c1, (1.0 - p.x) * (1.0 - smoothstep(0.6, 0.9, tt))))


# ================================================================== 20. POP! (balloon)
## 0.1-1.8 korban menggembung seperti balon, terbang naik dengan tali | 1.6-1.95 bergetar | 1.95 POP: serpihan karet + konfeti + teks "POP!"
func _balloon_inf() -> float:
	return smoothstep(0.1, 1.8, t)


func _balloon_scale() -> float:
	var wob: float = 1.0 + 0.04 * sin(t * 18.0) * _balloon_inf() + 0.08 * sin(t * 60.0) * smoothstep(1.5, 1.95, t)
	return (1.0 + 1.25 * _balloon_inf()) * wob


func _balloon_pos() -> Vector2:
	var fl: float = smoothstep(0.7, 1.9, t)
	var sc: float = _balloon_scale()
	return vpos + Vector2(sin(t * 3.0) * 6.0 * _u * fl, -(sc - 1.0) * usize * 0.3 - fl * usize * 1.3)


func _v_balloon() -> void:
	var fl: float = smoothstep(0.7, 1.9, t)
	var sc: float = _balloon_scale()
	var inf: float = _balloon_inf()
	_set_v(_balloon_pos(), sin(t * 3.0) * 0.12 * fl, Vector2.ONE * sc, 1.0, Color(1, 1, 1, 1).lerp(c1.lightened(0.25), inf * 0.75), 0, 0.0, c1)
	_vsp.visible = t < 1.95


func _back_balloon(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var g: float = smoothstep(0.1, 0.8, t) * (1.0 - smoothstep(2.8, 3.4, t))
	ci.draw_circle(_balloon_pos(), 130.0 * u * g, FxDraw.ca(c1, 0.10 * g))
	for k in 7:
		var bx: float = V.x + (FxDraw.h(float(k), 1.0) - 0.5) * 420.0 * u
		var by: float = V.y + 150.0 * u - fposmod(t * (30.0 + 25.0 * FxDraw.h(float(k), 2.0)) + FxDraw.h(float(k), 3.0) * 300.0, 460.0) * u
		var cc: Color = c1.lerp(c2, FxDraw.h(float(k), 4.0))
		var r: float = (10.0 + 8.0 * FxDraw.h(float(k), 5.0)) * u
		ci.draw_line(Vector2(bx, by + r), Vector2(bx + sin(t * 3.0 + float(k)) * 4.0 * u, by + r + 30.0 * u), FxDraw.ca(Color.WHITE, 0.4 * g), 1.2 * u)
		_ell(ci, Vector2(bx, by), r * 0.85, r, FxDraw.ca(cc, 0.55 * g), 14)


func _front_balloon(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var inf: float = _balloon_inf()
	var B: Vector2 = _balloon_pos()
	var sc: float = _balloon_scale()
	if t < 1.95:
		var K := B + Vector2(0, usize * 0.5 * sc + 3.0 * u)
		ci.draw_colored_polygon(PackedVector2Array([K, K + Vector2(-5.0, 8.0) * u, K + Vector2(5.0, 8.0) * u]), FxDraw.ca(c1.darkened(0.2), 0.95))
		var pts := PackedVector2Array()
		for j in 15:
			var s: float = float(j) / 14.0
			pts.append(K + Vector2(0, 7.0 * u) + Vector2(sin(s * 7.0 + t * 4.0) * 6.0 * u * s, s * 80.0 * u))
		ci.draw_polyline(pts, Color(1, 1, 1, 0.85), 1.6 * u, true)
		var gc: Vector2 = B + Vector2(-0.24, -0.27) * usize * sc
		ci.draw_colored_polygon(_ellipse_pts(gc, 0.1 * usize * sc, 0.17 * usize * sc, 14), Color(1, 1, 1, 0.5 * inf))
		ci.draw_circle(gc + Vector2(0.13, 0.17) * usize * sc, 0.03 * usize * sc, Color(1, 1, 1, 0.45 * inf))
		for k in 12:
			var a: float = float(k) * TAU / 12.0 + t * 0.5
			var r0: float = usize * 0.5 * sc * 1.1
			var r1: float = r0 + (6.0 + 8.0 * sin(t * 14.0 + float(k))) * u
			ci.draw_line(B + Vector2(cos(a), sin(a)) * r0, B + Vector2(cos(a), sin(a)) * r1, FxDraw.ca(c2, 0.55 * inf * smoothstep(0.3, 0.8, t)), 1.6 * u)
	if t >= 1.95:
		var tt: float = t - 1.95
		if tt < 0.2:
			ci.draw_circle(B, 150.0 * u * (1.0 - tt / 0.2), Color(1, 1, 1, 0.9 * (1.0 - tt / 0.2)))
		if tt < 0.75:
			var f: float = tt / 0.75
			var pop: float = smoothstep(0.0, 0.15, tt)
			var spikes := PackedVector2Array()
			for k in 32:
				var rr: float = (96.0 if k % 2 == 0 else 62.0) * u * (0.6 + 0.5 * pop)
				var a2: float = float(k) / 32.0 * TAU
				spikes.append(B + Vector2(cos(a2), sin(a2)) * rr)
			ci.draw_colored_polygon(spikes, FxDraw.ca(c2, 0.95 * (1.0 - f * f)))
			var sp2 := PackedVector2Array()
			for k in 32:
				var rr2: float = (84.0 if k % 2 == 0 else 52.0) * u * (0.6 + 0.5 * pop)
				var a3: float = float(k) / 32.0 * TAU
				sp2.append(B + Vector2(cos(a3), sin(a3)) * rr2)
			ci.draw_colored_polygon(sp2, FxDraw.ca(c1, 0.95 * (1.0 - f * f)))
			if Global.font_ui != null:
				var fs: int = maxi(int(60.0 * _sc * (0.6 + 0.5 * pop)), 12)
				var txt := "POP!"
				var tp: Vector2 = B + Vector2(-fs * 1.1, fs * 0.32)
				ci.draw_string_outline(Global.font_ui, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, fs * 2.2, fs, maxi(int(8.0 * _sc), 2), Color(0, 0, 0, 1.0 - f * f))
				ci.draw_string(Global.font_ui, tp, txt, HORIZONTAL_ALIGNMENT_LEFT, fs * 2.2, fs, Color(1, 1, 1, 1.0 - f * f))
		for i in 16:
			var a4: float = FxDraw.h(float(i), 6.0) * TAU
			var spd: float = (120.0 + 260.0 * FxDraw.h(float(i), 7.0)) * u
			var pos: Vector2 = B + Vector2(cos(a4) * spd * tt, sin(a4) * spd * tt + 260.0 * u * tt * tt)
			var rs: float = (6.0 + 6.0 * FxDraw.h(float(i), 8.0)) * u
			ci.draw_set_transform(pos, tt * 8.0 * (FxDraw.h(float(i), 9.0) - 0.5) + a4, Vector2.ONE)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-rs, -rs * 0.6), Vector2(rs, 0), Vector2(-rs * 0.4, rs * 0.7)]), FxDraw.ca(c1, 1.0 - smoothstep(0.5, 1.2, tt)))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in 90:
			var a5: float = -PI * 0.5 + (FxDraw.h(float(i), 1.0) - 0.5) * 3.6
			var sp: float = (100.0 + 300.0 * FxDraw.h(float(i), 2.0)) * u
			var pos2: Vector2 = B + Vector2(cos(a5) * sp * tt + sin(tt * 8.0 + float(i)) * 8.0 * u, sin(a5) * sp * tt + 330.0 * u * tt * tt)
			var al: float = 1.0 - smoothstep(1.2, 1.6, tt)
			var wd: float = absf(cos(tt * 10.0 + float(i))) * 6.0 * u + 1.0
			ci.draw_set_transform(pos2, tt * 6.0 + float(i), Vector2.ONE)
			ci.draw_rect(Rect2(Vector2(-wd * 0.5, -4.0 * u), Vector2(wd, 8.0 * u)), FxDraw.ca(FxDraw.hue(FxDraw.h(float(i), 3.0), 1.0, 0.65, 1.0), al))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ================================================================== 21. ABDUCTION (ufo)
## 0.05-0.7 UFO turun dari langit | 0.55 sinar tarik menyala | 0.85-2.3 korban melayang naik berputar | 2.3-2.5 masuk UFO, kilatan |
## 2.5-3.2 UFO melesat pergi, lingkaran bekas mendarat memudar
func _ufo_pos() -> Vector2:
	var enter: float = 1.0 - pow(1.0 - clampf((t - 0.05) / 0.65, 0.0, 1.0), 3.0)
	var ex: float = clampf((t - 2.5) / 0.7, 0.0, 1.0)
	var wob := Vector2(sin(t * 2.2) * 5.0 * _u, sin(t * 3.1) * 3.0 * _u)
	return vpos + Vector2(0, -usize * 2.6) + Vector2(380.0, -330.0) * _u * (1.0 - enter) + wob + Vector2(700.0, -520.0) * _u * ex * ex


func _ufo_beam() -> float:
	return smoothstep(0.55, 0.8, t) * (1.0 - smoothstep(2.35, 2.5, t))


func _v_ufo() -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var lev: float = smoothstep(0.85, 2.3, t)
	var sc: float = maxf(1.0 - 0.9 * smoothstep(2.1, 2.4, t), 0.03)
	var pos: Vector2 = V + Vector2(sin(t * 2.5) * 5.0 * u * lev, -lev * usize * 2.3)
	_set_v(pos, sin(t * 2.0) * 0.4 * lev + smoothstep(1.9, 2.4, t) * 5.0, Vector2.ONE * sc, 1.0, Color(1, 1, 1, 1).lerp(Color(0.8, 1.4, 0.85, 1.0), smoothstep(0.7, 1.4, t) * 0.6), 0, 0.0, c1)
	_vsp.visible = t < 2.42


func _back_ufo(ci: CanvasItem) -> void:
	var V: Vector2 = vpos
	var u: float = _u
	var gy: float = V.y + usize * 0.5
	for i in 40:
		var pos := Vector2(bounds.position.x + FxDraw.h(float(i), 1.0) * bounds.size.x, bounds.position.y + FxDraw.h(float(i), 2.0) * bounds.size.y * 0.7)
		ci.draw_circle(pos, (0.8 + 1.0 * FxDraw.h(float(i), 3.0)) * _sc, Color(1, 1, 1, 0.5 * (0.5 + 0.5 * sin(t * 3.0 + float(i))) * _vig()))
	var bn: float = _ufo_beam()
	if bn > 0.01:
		var S: Vector2 = _ufo_pos() + Vector2(0, 14.0 * u)
		var fl: float = 0.85 + 0.15 * sin(t * 30.0)
		var G := Vector2(V.x, gy)
		ci.draw_polygon(PackedVector2Array([S + Vector2(-24.0 * u, 0), S + Vector2(24.0 * u, 0), G + Vector2(66.0 * u, 0), G + Vector2(-66.0 * u, 0)]),
			PackedColorArray([FxDraw.ca(c1, 0.55 * bn * fl), FxDraw.ca(c1, 0.55 * bn * fl), FxDraw.ca(c1, 0.2 * bn * fl), FxDraw.ca(c1, 0.2 * bn * fl)]))
		ci.draw_polygon(PackedVector2Array([S + Vector2(-10.0 * u, 0), S + Vector2(10.0 * u, 0), G + Vector2(30.0 * u, 0), G + Vector2(-30.0 * u, 0)]),
			PackedColorArray([FxDraw.ca(c2, 0.5 * bn), FxDraw.ca(c2, 0.5 * bn), FxDraw.ca(c2, 0.12 * bn), FxDraw.ca(c2, 0.12 * bn)]))
		_ell(ci, G, 70.0 * u, 17.0 * u, FxDraw.ca(c1, 0.4 * bn))
		_ell(ci, G, 36.0 * u, 9.0 * u, FxDraw.ca(c2, 0.5 * bn))
		for k in 3:
			var f: float = fposmod(t * 0.9 + float(k) / 3.0, 1.0)
			_ring(ci, G, (16.0 + 80.0 * f) * u, (16.0 + 80.0 * f) * u * 0.26, FxDraw.ca(c2, (1.0 - f) * 0.7 * bn), 2.5 * u)
		for i in 26:
			var p: Vector2 = FxDraw.ph(t, i, 26, 1.2)
			var py: float = lerpf(G.y, S.y, p.x)
			var hw: float = lerpf(60.0, 22.0, p.x) * u
			FxDraw.glow_dot(ci, Vector2(V.x + (FxDraw.rnd(i, p.y, 1.0) - 0.5) * hw * 1.6, py), 1.6 * u, FxDraw.ca(c2, sin(p.x * PI) * 0.9 * bn))
	if t > 2.5:
		var sg: float = smoothstep(2.5, 2.7, t) * (1.0 - smoothstep(3.0, 3.5, t))
		var G2 := Vector2(V.x, gy)
		_ring(ci, G2, 64.0 * u, 16.0 * u, FxDraw.ca(c1, 0.6 * sg), 3.0 * u)
		_ring(ci, G2, 38.0 * u, 9.5 * u, FxDraw.ca(c1, 0.6 * sg), 2.0 * u)
		for k in 8:
			var a: float = float(k) * TAU / 8.0
			ci.draw_line(G2 + Vector2(cos(a) * 38.0, sin(a) * 9.5) * u, G2 + Vector2(cos(a) * 64.0, sin(a) * 16.0) * u, FxDraw.ca(c1, 0.6 * sg), 2.0 * u)


func _front_ufo(ci: CanvasItem) -> void:
	var u: float = _u
	var S: Vector2 = _ufo_pos()
	var ex: float = clampf((t - 2.5) / 0.7, 0.0, 1.0)
	if ex > 0.0:
		var dir := Vector2(700.0, -520.0).normalized()
		for k in 8:
			var q: float = float(k) / 8.0
			ci.draw_line(S - dir * (30.0 + q * 160.0) * u * ex + Vector2(0, (q - 0.5) * 8.0 * u), S - dir * (10.0 + q * 220.0) * u * ex + Vector2(0, (q - 0.5) * 8.0 * u), FxDraw.ca(c1, 0.6 * (1.0 - q) * (1.0 - ex * 0.5)), 3.0 * u)
	var rot: float = sin(t * 2.0) * 0.05 - ex * 0.35
	ci.draw_set_transform(S, rot, Vector2.ONE)
	ci.draw_circle(Vector2(0, 6.0 * u), 78.0 * u, FxDraw.ca(c1, 0.05))
	var dome := PackedVector2Array()
	for k in 15:
		var a: float = PI + float(k) / 14.0 * PI
		dome.append(Vector2(cos(a) * 30.0 * u, -8.0 * u + sin(a) * 28.0 * u))
	ci.draw_colored_polygon(dome, FxDraw.ca(c2, 0.45))
	ci.draw_polyline(dome, FxDraw.ca(Color.WHITE, 0.8), 2.0 * u, true)
	ci.draw_circle(Vector2(0, -14.0 * u), 8.0 * u, FxDraw.ca(c1.darkened(0.1), 0.95))
	ci.draw_circle(Vector2(-3.0 * u, -15.0 * u), 1.8 * u, Color(0.02, 0.05, 0.02, 1.0))
	ci.draw_circle(Vector2(3.0 * u, -15.0 * u), 1.8 * u, Color(0.02, 0.05, 0.02, 1.0))
	ci.draw_colored_polygon(_ellipse_pts(Vector2(0, 2.0 * u), 70.0 * u, 16.0 * u, 28), Color(0.62, 0.68, 0.74, 1.0))
	ci.draw_colored_polygon(_ellipse_pts(Vector2(0, 7.0 * u), 56.0 * u, 11.0 * u, 24), Color(0.3, 0.34, 0.4, 1.0))
	ci.draw_arc(Vector2(0, 2.0 * u), 70.0 * u, PI * 1.05, PI * 1.95, 20, Color(0.92, 0.96, 1.0, 0.9), 2.5 * u, true)
	for k in 7:
		var lx: float = (float(k) - 3.0) * 20.0 * u
		var on: float = 0.5 + 0.5 * sin(t * 8.0 + float(k) * 1.1)
		var lc: Color = [c1, c2, Color(1, 0.9, 0.3, 1)][k % 3]
		FxDraw.glow_dot(ci, Vector2(lx, 3.0 * u + 7.0 * u * (1.0 - absf(float(k) - 3.0) / 3.5) * 0.0), 2.6 * u, FxDraw.ca(lc, 0.45 + 0.55 * on))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if t > 2.28 and t < 2.62:
		var f: float = (t - 2.28) / 0.34
		ci.draw_circle(S + Vector2(0, 12.0 * u), 70.0 * u * (1.0 - f), FxDraw.ca(c2, 0.9 * (1.0 - f)))
		_ring(ci, S + Vector2(0, 10.0 * u), (20.0 + 140.0 * f) * u, (20.0 + 140.0 * f) * u * 0.3, FxDraw.ca(c1, 1.0 - f), 4.0 * u * (1.0 - f) + 1.0)
		for i in 14:
			var a2: float = FxDraw.h(float(i), 4.0) * TAU
			if f < 0.85:
				FxDraw.star4(ci, S + Vector2(cos(a2), sin(a2) * 0.6) * (20.0 + 90.0 * f) * u, 4.0 * u * (1.0 - f), FxDraw.ca(c2, 1.0 - f))


# ================================================================== overlay layar: kilatan, bar sinematik, banner
func _overlay(ci: CanvasItem) -> void:
	var vg: float = _vig()
	var ob := Rect2(_ov_tl, bounds.size / _ov_z)
	var scl: float = _sc / _ov_z
	var bh: float = ob.size.y * 0.09 * vg
	ci.draw_rect(Rect2(ob.position.x, ob.position.y, ob.size.x, bh), Color(0, 0, 0, 1))
	ci.draw_rect(Rect2(ob.position.x, ob.end.y - bh, ob.size.x, bh), Color(0, 0, 0, 1))
	# kilatan awal (benturan kill)
	if t < 0.16:
		ci.draw_rect(ob, Color(1, 1, 1, 0.85 * (1.0 - t / 0.16)))
	# banner
	var ba: float = smoothstep(0.55, 0.85, t) * (1.0 - smoothstep(D - 0.7, D - 0.2, t))
	if show_text and ba > 0.01 and Global.font_ui != null:
		var info: Dictionary = FxCatalog.FIN.get(_fin_key(), {})
		var name_: String = String(info.get("name", "FINISHER"))
		var cx: float = ob.position.x + ob.size.x * 0.5
		var by: float = ob.end.y - bh - ob.size.y * 0.13
		var slide: float = (1.0 - ba) * 60.0 * scl
		var fs1: int = maxi(int(58.0 * scl), 12)
		var fs2: int = maxi(int(24.0 * scl), 8)
		var w: float = ob.size.x
		var x0: float = ob.position.x
		# pita warna
		ci.draw_rect(Rect2(x0, by - fs1 * 0.95, w, fs1 * 1.5), FxDraw.ca(Color.BLACK, 0.45 * ba))
		ci.draw_rect(Rect2(x0, by - fs1 * 0.95, w, 3.0 * scl + 1.0), FxDraw.ca(c1, 0.9 * ba))
		ci.draw_rect(Rect2(x0, by + fs1 * 0.55, w, 3.0 * scl + 1.0), FxDraw.ca(c1, 0.9 * ba))
		ci.draw_string_outline(Global.font_ui, Vector2(x0 + slide, by), name_, HORIZONTAL_ALIGNMENT_CENTER, w, fs1, maxi(int(8.0 * scl), 2), FxDraw.ca(Color.BLACK, ba))
		ci.draw_string(Global.font_ui, Vector2(x0 + slide, by), name_, HORIZONTAL_ALIGNMENT_CENTER, w, fs1, FxDraw.ca(Color.WHITE.lerp(c1, 0.35), ba))
		var sub: String = title if title != "" else "FINISHER"
		ci.draw_string_outline(Global.font_ui, Vector2(x0 - slide, by - fs1 * 1.0 - 4.0 * scl), "- %s -" % sub, HORIZONTAL_ALIGNMENT_CENTER, w, fs2, maxi(int(5.0 * scl), 2), FxDraw.ca(Color.BLACK, ba))
		ci.draw_string(Global.font_ui, Vector2(x0 - slide, by - fs1 * 1.0 - 4.0 * scl), "- %s -" % sub, HORIZONTAL_ALIGNMENT_CENTER, w, fs2, FxDraw.ca(c1.lerp(Color.WHITE, 0.4), ba))


func _fin_key() -> String:
	return kind
