extends StaticBody2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var unlock_sfx: AudioStreamPlayer2D = $UnlockSfx

var unlocked := false

func try_unlock():
	if unlocked:
		return
	if GameManager.has_key:
		unlocked = true
		GameManager.has_key = false
		unlock_sfx.play()

		# ปิดการชนแบบ deferred เพื่อเลี่ยง flushing queries
		collision.set_deferred("disabled", true)
		# กันชนทุกอย่าง (กัน edge case หากมีชนชั้น/หน้ากากอื่น)
		set_deferred("collision_layer", 0)
		set_deferred("collision_mask", 0)

		# จางหายแล้วลบออก
		var tween = create_tween()
		tween.tween_property(sprite, "modulate:a", 0.0, 0.8)
		await tween.finished
		queue_free()
