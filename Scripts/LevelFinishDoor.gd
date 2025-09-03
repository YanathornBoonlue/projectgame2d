# LevelFinishDoor.gd
extends Area2D

@export var next_scene: PackedScene
@export var transition_delay: float = 0.4

var _triggered := false

func _on_body_entered(body: Node) -> void:
	if _triggered or not body.is_in_group("Player"):
		return
	_triggered = true

	# ❗ ห้ามแก้ monitoring ตรง ๆ ในสัญญาณ ใช้ set_deferred แทน
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	# ปิดคอลลิชันของ CollisionShape2D แบบ deferred ด้วย (กันชนซ้ำระหว่างหน่วงเวลา)
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape:
		shape.set_deferred("disabled", true)

	# ทำเอฟเฟกต์เข้า door แบบเบา ๆ และเปลี่ยนฉาก
	call_deferred("_finish_level", body)

func _finish_level(player: Node) -> void:
	# หยุดฟิสิกส์ผู้เล่นชั่วคราว
	if player is CharacterBody2D:
		(player as CharacterBody2D).velocity = Vector2.ZERO
	player.set_physics_process(false)
	player.set_process(false)

	AudioManager.level_complete_sfx.play()

	# เอฟเฟกต์เล็ก ๆ (ไม่ใช่ death)
	var tw := create_tween()
	tw.tween_property(player, "scale", Vector2(0.9, 1.1), 0.12)
	tw.tween_property(player, "modulate:a", 0.0, 0.18)
	await tw.finished

	await get_tree().create_timer(transition_delay).timeout

	# ใช้ SceneTransition ถ้ามี ไม่งั้นเปลี่ยนฉากตรง ๆ
	if Engine.has_singleton("SceneTransition") or (typeof(SceneTransition) != TYPE_NIL and SceneTransition.has_method("load_scene")):
		SceneTransition.load_scene(next_scene)
	else:
		get_tree().change_scene_to_packed(next_scene)
