extends CharacterBody2D
@export var sprite = "Agis Idle"
var alive = true

func _ready() -> void:
	$AnimatedSprite2D.play(sprite)

func death_tween():
	alive = false
	GameManager.add_score()
	$AnimatedSprite2D.visible = false
	await get_tree().create_timer(1).timeout
	hide()
	var delay = randf_range(5,10)
	await get_tree().create_timer(delay).timeout


func _on_hit_area_body_entered(body: Node2D) -> void:
	if alive && body.is_in_group("Player"):
		death_tween()
