class_name FxAccSprite
extends Sprite2D
## Sprite aksesoris BERANIMASI: transformasi (goyang / denyut / kepak) + partikel tambahan (FxDraw.acc_fx).
## Dipakai di game, Replay, dan preview Shop / Inventory.

var aid: String = ""
var t: float = 0.0
var speed: float = 1.0
var manual: bool = false
var base_pos: Vector2 = Vector2.ZERO
var _mat: ShaderMaterial = null
var k_mul: float = 1.0


func _ready() -> void:
	add_to_group("cos_fx")
	t = randf() * 20.0
	if aid == "comet_scarf":
		_mat = FxShaders.wave_material()
		material = _mat


func set_fx_speed(s: float) -> void:
	speed = s


func _process(delta: float) -> void:
	if not manual:
		t += delta * speed
	var a: Dictionary = FxDraw.acc_anim(aid, t)
	position = base_pos + (a["pos"] as Vector2)
	rotation = float(a["rot"])
	scale = a["scale"] as Vector2
	self_modulate = a["mod"] as Color
	if _mat != null:
		_mat.set_shader_parameter("fx_t", t)
	queue_redraw()


func _draw() -> void:
	FxDraw.K = k_mul
	FxDraw.acc_fx(self, aid, t)
