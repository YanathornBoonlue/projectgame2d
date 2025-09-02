extends RigidBody2D

@export var damage: int = 20
@export var gravity_scale_override: float = 2.5
@export var anim_name: String = "Purple"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var hit_area: Area2D = null
var notifier: VisibleOnScreenNotifier2D = null

func _ready() -> void:
	if has_node("HitArea"):
		hit_area = $HitArea
	if has_node("VisibleOnScreenNotifier2D"):
		notifier = $VisibleOnScreenNotifier2D

	# Layer 4 (BossAttack), ชนเฉพาะ Player (1) → ทะลุกำแพง/ทะลุบอส
	_set_layers(1, [1])
	anim.play(anim_name)

	# ฟิสิกส์ของลูกไฟ
	gravity_scale = gravity_scale_override
	linear_damp = 0.0
	angular_damp = 0.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = true
	max_contacts_reported = 4

	if hit_area:
		_set_layers_area(hit_area, 1, [1])
		hit_area.body_entered.connect(_on_body_entered)
	else:
		body_entered.connect(_on_body_entered)

	if notifier:
		notifier.screen_exited.connect(_on_screen_exited)

func _on_body_entered(b: Node) -> void:
	if b.is_in_group("Player"):
		GameManager.damage(damage)
		queue_free()

func _on_screen_exited() -> void:
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
