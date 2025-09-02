extends Area2D
@onready var pickup_sfx: AudioStreamPlayer2D = $PickupSfx
@onready var sprite: Sprite2D = $Sprite2D

func _on_body_entered(body: Node):
	if body.is_in_group("Player"):
		GameManager.has_key = true
		pickup_sfx.play()
		await pickup_sfx.finished  # wait until sound done
		# จางหายแล้วลบออก
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.1)
		await tween.finished
		
		queue_free()
