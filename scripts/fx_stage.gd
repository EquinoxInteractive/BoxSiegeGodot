class_name FxStage
extends Control
## Panggung preview HIDUP untuk Shop & Inventory: menampilkan skin karakter / skin senjata / aksesoris premium dengan efek
## sesungguhnya (partikel LV2, animasi LV3, finisher LV3, aksesoris beranimasi) memakai kode efek yang SAMA dengan di game.
## Diposisikan & dipotong (clip) oleh CosmeticUI di area preview panel kanan.

signal finisher_started

var world: Node2D
var t: float = 0.0
var mode: String = ""
var level: int = 1
var _key: String = ""
var _body: Sprite2D = null
var _gun: Sprite2D = null
var _wdraw: Node2D = null
var _victim: Sprite2D = null
var _fin: Finisher = null
var _fin_wait: float = 0.6
var _fin_kind: String = ""
var _fin_c1: Color = Color.WHITE
var _fin_c2: Color = Color.WHITE
var _fin_wid: String = ""
var _fin_title: String = ""
var _victim_ch: int = 3
var pop: float = 1.0                 # skala animasi muncul (diatur CosmeticUI)


class WeaponDraw extends Node2D:
	var fam: String = ""
	var c1: Color = Color.WHITE
	var c2: Color = Color.WHITE
	var lv: int = 1
	var t: float = 0.0
	var gun_w: float = 260.0
	var gun_len: float = 56.0
	var bullet: Color = Color(1, 0.8, 0.2)
	var bullet_y: float = 80.0
	var span: float = 300.0
	var show_bullet: bool = true

	func _process(d: float) -> void:
		t += d
		queue_redraw()

	func _draw() -> void:
		if lv < 2 or fam == "":
			return
		var z: float = gun_w / gun_len
		draw_set_transform(Vector2(-gun_w * 0.5, 0.0), 0.0, Vector2.ONE * z)
		FxDraw.K = 1.0
		FxDraw.weapon_fx(self, fam, c1, c2, t, gun_len)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if show_bullet:
			var p: float = fposmod(t * 0.8, 1.0)
			var bx: float = -span * 0.5 + p * span
			draw_set_transform(Vector2(bx, bullet_y), 0.0, Vector2.ONE * 2.2)
			FxDraw.K = 1.0
			FxDraw.bullet_fx(self, fam, c1, c2, t)
			draw_circle(Vector2.ZERO, 4.0, bullet.lightened(0.5))
			draw_circle(Vector2.ZERO, 7.0, Color(bullet, 0.35))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	world = Node2D.new()
	add_child(world)
	visible = false


func clear() -> void:
	_key = ""
	mode = ""
	_kill_fin()
	for c in world.get_children():
		c.queue_free()
	_body = null
	_gun = null
	_wdraw = null
	# sprite korban finisher adalah anak FxStage (bukan world), jadi harus dibuang manual supaya tidak ikut ke skin lain
	if _victim != null and is_instance_valid(_victim):
		_victim.visible = false
		_victim.queue_free()
	_victim = null
	_fin_kind = ""
	_fin_wait = 0.6
	visible = false


func _kill_fin() -> void:
	if _fin != null and is_instance_valid(_fin):
		_fin.queue_free()
	_fin = null


# ------------------------------------------------------------------ skin karakter
func setup_char(ch: int, sid: String, lv: int, lo: Dictionary, tint: Color) -> void:
	var key: String = "c|%d|%s|%d|%s|%s" % [ch, sid, lv, JSON.stringify(lo), tint.to_html()]
	visible = true
	if key == _key:
		return
	clear()
	visible = true
	_key = key
	mode = "char"
	level = lv
	_body = Sprite2D.new()
	_body.texture = Cosmetics.char_tex(ch, sid)
	_body.scale = Vector2.ONE * (176.0 / 180.0)
	_body.modulate = tint
	world.add_child(_body)
	FxRig.attach_char(_body, null, sid, lv, 1.3)
	Cosmetics.attach_accessories(_body, ch, lo, 1.3)


# ------------------------------------------------------------------ aksesoris (Shop: pratinjau di karakter; Inventory: loadout)
func setup_acc(ch: int, sid: String, lo: Dictionary, tint: Color) -> void:
	var key: String = "a|%d|%s|%s|%s" % [ch, sid, JSON.stringify(lo), tint.to_html()]
	visible = true
	if key == _key:
		return
	clear()
	visible = true
	_key = key
	mode = "acc"
	_body = Sprite2D.new()
	_body.texture = Cosmetics.char_tex(ch, sid)
	_body.scale = Vector2.ONE * (150.0 / 180.0)
	_body.modulate = tint
	world.add_child(_body)
	Cosmetics.attach_accessories(_body, ch, lo, 1.1)


# ------------------------------------------------------------------ skin senjata
func setup_weapon(w: String, sid: String, lv: int, tint: Color, victim_ch: int) -> void:
	var key: String = "w|%s|%s|%d|%s|%d" % [w, sid, lv, tint.to_html(), victim_ch]
	visible = true
	if key == _key:
		return
	clear()
	visible = true
	_key = key
	mode = "weapon"
	level = lv
	_victim_ch = victim_ch
	var fin: String = Cosmetics.wskin_finisher(w, sid)
	var info: Dictionary = FxCatalog.weapon_info(sid)
	var tex: Texture2D = Cosmetics.weapon_tex(w, sid, 0)
	var is_fin: bool = lv >= 3 and fin != "" and not info.is_empty()
	_gun = Sprite2D.new()
	_gun.texture = tex
	_gun.modulate = tint
	var gw: float = 250.0 if not is_fin else 120.0
	if tex != null:
		_gun.scale = Vector2.ONE * (gw / float(tex.get_width()))
	world.add_child(_gun)
	_wdraw = WeaponDraw.new()
	var wd: WeaponDraw = _wdraw as WeaponDraw
	if not info.is_empty():
		wd.fam = String(info["fam"])
		wd.c1 = info["c1"]
		wd.c2 = info["c2"]
	wd.lv = lv
	wd.gun_w = gw
	wd.gun_len = float(Global.WEAPONS[w].get("hold_len", 56.0))
	wd.bullet = Cosmetics.bullet_color(w, sid) if Cosmetics.bullet_color(w, sid).a > 0.0 else Color(1, 0.8, 0.2)
	wd.show_bullet = not is_fin
	world.add_child(_wdraw)
	if is_fin:
		_fin_kind = fin
		_fin_c1 = info["c1"]
		_fin_c2 = info["c2"]
		_fin_wid = w
		var wi: Array = Cosmetics.weapon_skin_info(w, sid)
		_fin_title = String(wi[1]) if wi.size() > 1 else ""
		_victim = Sprite2D.new()
		_victim.texture = Cosmetics.char_tex(victim_ch, "", true)
		_victim.scale = Vector2.ONE * (84.0 / 180.0)
		add_child(_victim)
		_fin_wait = 0.7
	else:
		_fin_kind = ""


func replay_finisher() -> void:
	if _fin_kind == "":
		return
	_kill_fin()
	_fin_wait = 0.0


func _start_fin() -> void:
	_kill_fin()
	var f := Finisher.new()
	f.kind = _fin_kind
	f.c1 = _fin_c1
	f.c2 = _fin_c2
	f.weapon = _fin_wid
	f.title = _fin_title
	f.victim_tex = Cosmetics.char_tex(_victim_ch, "", true)
	f.vpos = size * 0.5 + Vector2(20.0, 16.0)
	f.kpos = Vector2(40.0, size.y * 0.72)
	f.usize = 84.0
	f.bounds = Rect2(Vector2.ZERO, size)
	f.show_text = false          # sama seperti gameplay: tanpa banner nama finisher (hanya animasi + suara)
	add_child(f)
	_fin = f
	if _victim != null:
		_victim.visible = false
	finisher_started.emit()


func _process(d: float) -> void:
	if not visible:
		return
	d = minf(d, 1.0 / 30.0)
	t += d
	world.position = size * 0.5 + Vector2(0.0, sin(t * 2.0) * 5.0 if mode != "weapon" or _fin_kind == "" else 0.0)
	world.scale = Vector2.ONE * pop
	if mode == "weapon" and _fin_kind != "":
		# senjata kecil di kiri-bawah, korban di tengah
		world.position = Vector2(size.x * 0.24, size.y * 0.74)
		if _victim != null:
			_victim.position = size * 0.5 + Vector2(20.0, 16.0)
		if _fin == null or not is_instance_valid(_fin):
			_fin = null
			if _victim != null:
				_victim.visible = true
			_fin_wait -= d
			if _fin_wait <= 0.0:
				_start_fin()
				_fin_wait = 1.4
