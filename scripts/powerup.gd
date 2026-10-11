class_name Powerup
extends Area2D
## Power up yang muncul di arena: "heal", "jump", "speed", "shield", "invisible", "ammo_refill", "swap_position".
## Nama tipe = nama file ikon di assets/sprites/powerups/<tipe>.png

var type: String = "heal"
var life: float = 12.0
var t: float = 0.0
var spr: Sprite2D
var human_only: bool = false     # campaign: musuh tidak boleh mengambil power up


func setup(power_type: String) -> void:
	type = power_type


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4

	spr = Sprite2D.new()
	var icon_path: String = "res://assets/sprites/powerups/%s.png" % type
	if not ResourceLoader.exists(icon_path):
		push_warning("Ikon power up tidak ditemukan: " + icon_path)
		icon_path = "res://assets/sprites/powerups/heal.png"     # cadangan supaya game tidak error
	spr.texture = load(icon_path)
	spr.scale = Vector2.ONE * 0.28
	add_child(spr)

	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 28.0
	cs.shape = shape
	add_child(cs)

	body_entered.connect(_on_body_entered)

	# efek muncul
	spr.scale = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(spr, "scale", Vector2.ONE * 0.28, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	t += delta
	spr.position.y = sin(t * 4.0) * 5.0
	life -= delta
	if life < 3.0:
		spr.visible = fmod(life, 0.3) > 0.15
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body is Player:
		var p: Player = body
		if human_only and p.team == 1:
			return
		if p.alive:
			p.apply_powerup(type)
			queue_free()
