extends CharacterBody2D

@export var sprite: String = "Agis Idle"
@export var attack_interval: float = 2.0

# packed scenes ของสกิล
@export var skull_spell_scene: PackedScene
@export var purple_fire_ball_scene: PackedScene
@export var dead_spell_scene: PackedScene

# ค่าพารามิเตอร์ของแต่ละท่า
@export var skull_speed: float = 420.0
@export var purple_gravity_scale: float = 2.5
@export var dead_rise_distance: float = 80.0
@export var dead_rise_duration: float = 0.25

var alive: bool = true
var attack_timer: Timer

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	randomize()
	if anim:
		anim.play(sprite)

	attack_timer = Timer.new()
	attack_timer.wait_time = attack_interval
	attack_timer.autostart = true
	attack_timer.one_shot = false
	add_child(attack_timer)
	attack_timer.timeout.connect(_on_attack_timeout)

func _on_attack_timeout() -> void:
	if not alive:
		return
	var roll := randi() % 3
	match roll:
		0:
			_cast_skull_spell()
		1:
			_cast_purple_fire_ball()
		2:
			_cast_dead_spell()

# ---------- Casts ----------

func _cast_skull_spell() -> void:
	if skull_spell_scene == null:
		return
	var spell := skull_spell_scene.instantiate()
	# -1 ซ้าย / 1 ขวา
	var dir: int = 1 if (randi() % 2 == 0) else -1
	# เว้นออกจากตัวบอสกันติด
	var offset := Vector2(96.0 * dir, -10.0)

	get_parent().add_child(spell)
	spell.global_position = global_position + offset

	# กันชนกับบอสเอง
	if spell is RigidBody2D:
		spell.add_collision_exception_with(self)

	# ตั้งค่าให้สเปลล์
	spell.set("direction", dir)
	spell.set("speed", skull_speed)

	# ตั้ง HitArea (ถ้ามี) ให้ชนเฉพาะ Player
	var ha := spell.get_node_or_null("HitArea")
	if ha and ha is Area2D:
		_configure_area_layer_mask(ha, 4, [1])

func _cast_purple_fire_ball() -> void:
	if purple_fire_ball_scene == null:
		return
	var spell := purple_fire_ball_scene.instantiate()
	get_parent().add_child(spell)

	# จุดตก: ใช้ x ของผู้เล่น ถ้าไม่มีให้สุ่มใกล้บอส
	var player := _get_player()
	var spawn_x: float = player.global_position.x if (player != null) else (global_position.x + randf_range(-200.0, 200.0))
	var top_y: float = _get_viewport_top_world_y() - 64.0
	spell.global_position = Vector2(spawn_x, top_y)

	# กันชนกับบอส
	if spell is RigidBody2D:
		spell.add_collision_exception_with(self)

	# ปรับแรงโน้มถ่วงของลูกไฟ
	spell.set("gravity_scale_override", purple_gravity_scale)

	# ตั้ง HitArea (ถ้ามี) ให้ชนเฉพาะ Player
	var ha := spell.get_node_or_null("HitArea")
	if ha and ha is Area2D:
		_configure_area_layer_mask(ha, 4, [1])

func _cast_dead_spell() -> void:
	if dead_spell_scene == null:
		return
	var spell := dead_spell_scene.instantiate()
	get_parent().add_child(spell)

	var player := _get_player()
	var spawn_x: float = player.global_position.x if (player != null) else global_position.x
	var ground_y: float = _get_ground_y(Vector2(spawn_x, global_position.y - 10.0))
	spell.global_position = Vector2(spawn_x, ground_y)

	spell.set("rise_distance", dead_rise_distance)
	spell.set("rise_duration", dead_rise_duration)

# ---------- Helpers ----------

func _get_player() -> Node2D:
	for n in get_tree().get_nodes_in_group("Player"):
		if n is Node2D:
			return n
	return null

func _get_viewport_top_world_y() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam:
		var half := get_viewport_rect().size * 0.5
		var top_left := cam.get_screen_center_position() - half
		return top_left.y
	return global_position.y - 200.0

func _get_ground_y(from_pos: Vector2) -> float:
	var space := get_world_2d().direct_space_state
	var to := from_pos + Vector2(0, 2000.0)
	var p := PhysicsRayQueryParameters2D.create(from_pos, to)
	var hit := space.intersect_ray(p)
	if hit.has("position"):
		return float(hit.position.y)
	return global_position.y

func _configure_area_layer_mask(a: Area2D, layer: int, masks: Array) -> void:
	for i in range(1, 33):
		a.set_collision_layer_value(i, false)
		a.set_collision_mask_value(i, false)
	a.set_collision_layer_value(layer, true)
	for m in masks:
		a.set_collision_mask_value(int(m), true)

func death_tween() -> void:
	alive = false
	GameManager.add_score()
	if anim:
		anim.visible = false
	await get_tree().create_timer(1.0).timeout
	hide()
	var delay := randf_range(5.0, 10.0)
	await get_tree().create_timer(delay).timeout
