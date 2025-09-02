extends Area2D

@export var rise_distance: float = 80.0
@export var rise_duration: float = 0.25
@export var alive_duration_after_rise: float = 0.15
@export var damage: int = 25
@export var anim_name: String = "Dead"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _start_pos: Vector2

func _ready() -> void:
	# ให้ Area นี้อยู่ Layer 4 (BossAttack) และชนเฉพาะ Player (1)
	_set_layers(1, [1])
	monitoring = true
	monitorable = true

	_start_pos = global_position
	if anim:
		anim.play(anim_name)

	# พุ่งขึ้นจากพื้น
	var tw := create_tween()
	tw.tween_property(self, "global_position", _start_pos - Vector2(0.0, rise_distance), rise_duration)
	await tw.finished
	await get_tree().create_timer(alive_duration_after_rise).timeout
	queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		GameManager.damage(damage)

# ---------- helpers ----------
func _set_layers(layer: int, mask_layers: Array) -> void:
	for i in range(1, 33):
		set_collision_layer_value(i, false)
	set_collision_layer_value(layer, true)
	for i in range(1, 33):
		set_collision_mask_value(i, false)
	for m in mask_layers:
		set_collision_mask_value(int(m), true)
