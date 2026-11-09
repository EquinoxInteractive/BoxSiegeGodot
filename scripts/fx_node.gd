class_name FxNode
extends Node2D
## Node efek kosmetik (partikel skin karakter / partikel senjata). Digambar lewat FxDraw dari waktu `t`.
##  - CHAR_BACK / CHAR_FRONT : anak dari body_sprite (kotak karakter 180x180, ikut squash badan).
##  - WEAPON                 : anak dari Player, mengikuti sprite senjata yang sedang dipegang (hanya aktif kalau skinnya LV2+).
## Waktu berjalan sendiri, tapi dikontrol grup "cos_fx" -> set_fx_speed(s) (Replay: 0 saat dijeda, 0.5 saat slow-mo, dst).

enum Kind { CHAR_BACK, CHAR_FRONT, WEAPON }

var kind: int = Kind.CHAR_FRONT
var skin: String = ""
var level: int = 2
var t: float = 0.0
var speed: float = 1.0
var manual: bool = false          # true: t diatur dari luar (preview), tidak jalan sendiri
var player: Node = null           # Player (khusus WEAPON / sinkron visibilitas)
var fam: String = ""
var c1: Color = Color.WHITE
var c2: Color = Color.WHITE
var length: float = 56.0
var _skin_mat: ShaderMaterial = null
var k_mul: float = 1.0          # pengali ukuran partikel (game 2.1, preview 1.0)


static func make(k: int, skin_id: String, lv: int) -> FxNode:
	var n := FxNode.new()
	n.kind = k
	n.skin = skin_id
	n.level = lv
	return n


func _ready() -> void:
	add_to_group("cos_fx")
	t = randf() * 20.0
	var additive: bool = true
	if kind != Kind.WEAPON:
		additive = bool(FxCatalog.char_info(skin).get("add", true))
	if additive:
		material = FxShaders.add_material()
	if kind == Kind.CHAR_BACK:
		show_behind_parent = true
	if kind == Kind.WEAPON:
		visible = false


func set_fx_speed(s: float) -> void:
	speed = s


## Skin LV3: pasang shader animasi ke sprite badan (dipanggil oleh FxRig, hanya pada node CHAR_FRONT).
func bind_body(body: Sprite2D) -> void:
	if level >= 3:
		_skin_mat = FxShaders.skin_material(String(FxCatalog.char_info(skin).get("a", "holo")))
		body.material = _skin_mat


func _process(delta: float) -> void:
	if not manual:
		t += delta * speed
	if _skin_mat != null:
		_skin_mat.set_shader_parameter("fx_t", t)
	if kind == Kind.WEAPON:
		_follow_weapon()
	elif player != null and is_instance_valid(player):
		var p: Player = player as Player
		if p != null:
			visible = p.alive and p.body_sprite.visible
	queue_redraw()


func _follow_weapon() -> void:
	var p: Player = player as Player
	if p == null or not is_instance_valid(p):
		visible = false
		return
	var wid: String = p.current_weapon()
	var sid: String = String(p.wskins.get(wid, ""))
	var lv: int = int(p.wskin_lv.get(wid, 1))
	var info: Dictionary = FxCatalog.weapon_info(sid) if lv >= 2 else {}
	if info.is_empty() or not p.alive or not p.gun_sprite.visible:
		visible = false
		return
	visible = true
	fam = String(info["fam"])
	c1 = info["c1"]
	c2 = info["c2"]
	length = p.gun_len * p.size_mult
	var g: Sprite2D = p.gun_sprite
	position = g.position
	rotation = g.rotation
	scale = Vector2(float(p.facing), 1.0)


func _draw() -> void:
	FxDraw.K = k_mul
	match kind:
		Kind.CHAR_BACK:
			FxDraw.char_fx(self, skin, level, t, false)
		Kind.CHAR_FRONT:
			FxDraw.char_fx(self, skin, level, t, true)
		Kind.WEAPON:
			if fam != "":
				draw_set_transform(Vector2(-length * 0.5, 0.0), 0.0, Vector2.ONE)
				FxDraw.K = 1.0
				FxDraw.weapon_fx(self, fam, c1, c2, t, length)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
