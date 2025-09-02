extends Area2D

@export var rise_distance: float = 80.0
@export var rise_duration: float = 0.25
@export var alive_duration_after_rise: float = 0.15
@export var damage: int = 25
@export var anim_name := "Dead"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _start_pos: Vector2

func _ready() -> void:
	monitoring = true
	monitorable = true
	_start_pos = global_position

	if anim:
		anim.play(anim_name)

	# พุ่งขึ้นด้วย Tween แล้วหน่วงสั้น ๆ จากนั้นลบ
	var tw := create_tween()
	tw.tween_property(self, "global_position", _start_pos - Vector2(0, rise_distance), rise_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	await get_tree().create_timer(alive_duration_after_rise).timeout
	queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		GameManager.damage(damage)
