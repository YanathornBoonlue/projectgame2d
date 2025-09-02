extends RigidBody2D

@export var speed: float = 420.0
@export var direction: int = 1   # 1=ขวา, -1=ซ้าย
@export var damage: int = 15
@export var anim_name: String = "Skull"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var hit_area: Area2D = null

func _ready() -> void:
	# เก็บ HitArea ถ้ามี
	if has_node("HitArea"):
		hit_area = $HitArea

	# ให้กระสุนอยู่ Layer 4 (BossAttack) และชนได้เฉพาะ Player (1)
	_set_layers(1, [1])
	anim.play(anim_name)

	# ฟิสิกส์ของลูกกระสุน
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4

	# ความเร็วแนวนอน
	linear_velocity = Vector2(speed * direction, 0.0)

	# เชื่อมสัญญาณชน
	if hit_area:
		_set_layers_area(hit_area, 1, [1])
		hit_area.body_entered.connect(_on_body_entered)
	else:
		body_entered.connect(_on_body_entered)

func _on_body_entered(b: Node) -> void:
	if b.is_in_group("Player"):
		GameManager.damage(damage)
		queue_free()

# ---------- helpers ----------
func _set_layers(layer: int, mask_layers: Array) -> void:
	for i in range(1, 33):
		set_collision_layer_value(i, false)
	set_collision_layer_value(layer, true)
	for i in range(1, 33):
		set_collision_mask_value(i, false)
	for m in mask_layers:
		set_collision_mask_value(int(m), true)

func _set_layers_area(a: Area2D, layer: int, mask_layers: Array) -> void:
	for i in range(1, 33):
		a.set_collision_layer_value(i, false)
	a.set_collision_layer_value(layer, true)
	for i in range(1, 33):
		a.set_collision_mask_value(i, false)
	for m in mask_layers:
		a.set_collision_mask_value(int(m), true)
