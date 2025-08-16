extends StaticBody2D


func _ready() -> void:
	var b = randf_range(2,8)
	await get_tree().create_timer(b).timeout
	$AnimationPlayer.play("push")
