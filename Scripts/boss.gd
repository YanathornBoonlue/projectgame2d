extends CharacterBody2D

@export var sprite := "Agis Idle"
@export var attack_interval: float = 1.0
@export var skull_spell_scene: PackedScene
@export var purple_fire_ball_scene: PackedScene
@export var dead_spell_scene: PackedScene

@export var skull_speed: float = 420.0
@export var purple_gravity_scale: float = 2.5
@export var dead_rise_distance: float = 80.0
@export var dead_rise_duration: float = 0.25

var alive := true
var attack_timer: Timer

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
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

func _cast_skull_spell() -> void:
	if skull_spell_scene == null: return
	var spell := skull_spell_scene.instantiate()
	# สุ่มทิศ: -1 ซ้าย, 1 ขวา
	var dir: int = 1 if (randi() % 2 == 0) else -1
	# spawn ด้านซ้ายหรือขวาของบอสเล็กน้อย
	var offset := Vector2(80 * dir, -10)
	get_parent().add_child(spell)
	spell.global_position = global_position + offset
	# กำหนดทิศและความเร็ว
	spell.set("direction", dir)
	spell.set("speed", skull_speed)

func _cast_purple_fire_ball() -> void:
	if purple_fire_ball_scene == null: return
	var spell := purple_fire_ball_scene.instantiate()
	get_parent().add_child(spell)

	# ตำแหน่งตก: เลือก x ใกล้ผู้เล่น (หรือสุ่มบนจอ)
	var player := _get_player()
	var spawn_x := player.global_position.x if player else global_position.x + randf_range(-200, 200)
	# ให้ตกจากเหนือหัวกล้อง/หน้าจอขึ้นไปหน่อย
	var top_y := _get_viewport_top_world_y() - 64.0
	spell.global_position = Vector2(spawn_x, top_y)

	# ปรับแรงโน้มถ่วง
	spell.set("gravity_scale_override", purple_gravity_scale)

func _cast_dead_spell() -> void:
	if dead_spell_scene == null: return
	var spell := dead_spell_scene.instantiate()
	get_parent().add_child(spell)

	# สุ่มจุดที่พื้นใกล้ผู้เล่น
	var player := _get_player()
	var spawn_x := player.global_position.x if player else global_position.x
	var ground_y := _get_ground_y(Vector2(spawn_x, global_position.y - 10.0))
	spell.global_position = Vector2(spawn_x, ground_y)

	# ส่งพารามิเตอร์การพุ่งขึ้น
	spell.set("rise_distance", dead_rise_distance)
	spell.set("rise_duration", dead_rise_duration)

func _get_player() -> Node2D:
	for n in get_tree().get_nodes_in_group("Player"):
		if n is Node2D:
			return n
	return null

func _get_viewport_top_world_y() -> float:
	var cam := get_viewport().get_camera_2d()
	if cam:
		var rect := cam.get_screen_center_position() - get_viewport_rect().size * 0.5
		return rect.y
	return global_position.y - 200.0

func _get_ground_y(from_pos: Vector2) -> float:
	# ยิง Ray ลงหาพื้น (TileMap/StaticBody)
	var space := get_world_2d().direct_space_state
	var to := from_pos + Vector2(0, 2000)
	var q := PhysicsRayQueryParameters2D.create(from_pos, to)
	var hit := space.intersect_ray(q)
	if hit and hit.has("position"):
		return float(hit.position.y)
	# fallback: ถ้าไม่เจอ ให้ใช้ y ของบอสเป็นพื้น
	return global_position.y

func death_tween():
	alive = false
	GameManager.add_score()
	anim.visible = false
	await get_tree().create_timer(1).timeout
	hide()
	var delay = randf_range(5, 10)
	await get_tree().create_timer(delay).timeout
