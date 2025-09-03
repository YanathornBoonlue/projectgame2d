extends CharacterBody2D

@export var sprite: String = "Agis Idle"
@export var attack_interval: float = 2.5

# HP
@export var max_hp: int = 2500
var hp: int

# packed scenes
@export var skull_spell_scene: PackedScene
@export var purple_fire_ball_scene: PackedScene
@export var dead_spell_scene: PackedScene

# spell params
@export var skull_speed: float = 420.0
@export var purple_gravity_scale: float = 2.5
@export var dead_rise_distance: float = 80.0
@export var dead_rise_duration: float = 0.25

@export var purple_burst_count: int = 5
@export var purple_burst_interval: float = 0.25
@export var purple_spawn_spread_x: float = 160.0
@export var purple_track_player_each_shot: bool = true

@export var skull_burst_count_each_side: int = 6
@export var skull_burst_spacing: float = 48.0
@export var skull_burst_interval: float = 0.08
@export var skull_y_jitter: float = 8.0
@export var skull_fan_half_angle_deg: float = 28.0
@export var skull_speed_min: float = 380.0
@export var skull_speed_max: float = 520.0

@export var skull_aim_at_player: bool = true

@export var dead_spawn_radius: float = 400.0
@export var dead_charge_speed: float = 600.0

@export var purple_cast_sfx: AudioStream
@export var purple_cast_sfx_volume_db: float = 5
@export var skull_cast_sfx: AudioStream
@export var skull_cast_sfx_volume_db: float = 5
@export var dead_cast_sfx: AudioStream
@export var dead_cast_sfx_volume_db: float = 5

var alive: bool = true
var attack_timer: Timer

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	randomize()

	# ให้บอสเข้ากลุ่ม "Boss" (สำคัญสำหรับการหาเป้าหมาย)
	add_to_group("Boss")

	# ตั้งชั้นชนให้บอส: Layer = Boss(3), Mask = World(2) + Player(1)
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true) # Boss
	set_collision_mask_value(1, true)  # Player
	set_collision_mask_value(2, true)  # World

	# HP
	hp = max_hp
	GameManager.boss_hp = hp

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
		0: _cast_skull_spell()
		1: _cast_purple_fire_ball()
		2: _cast_dead_spell()

# ---------- Damage / Death ----------
func take_damage(dmg: int) -> void:
	if not alive: return
	hp = max(hp - dmg, 0)
	GameManager.boss_hp = hp
	if hp <= 0:
		_die()

func _die() -> void:
	alive = false
	if is_instance_valid(attack_timer):
		attack_timer.stop()
	for n in get_tree().get_nodes_in_group("BossProjectiles"):
		if is_instance_valid(n):
			n.queue_free()
	if anim:
		anim.visible = false

	var ui := get_node_or_null("/root/WinUI")
	if ui != null:
		ui.call_deferred("show_you_win")   # หรือส่ง next_scene ถ้าจะเปลี่ยนปลายทาง
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Prefabs/menu.tscn")

func _on_hit_by_player(dmg: int) -> void:
	take_damage(dmg)

# ---------- Casts ----------
func _cast_skull_spell() -> void:
	if skull_spell_scene == null:
		return
	_play_skull_cast_sfx(global_position)
	await _cast_skull_barrage()

func _cast_skull_barrage() -> void:
	var rings: int = max(skull_burst_count_each_side, 1)
	for i: int in range(rings):
		if not alive:
			break
		var t: float = 1.0 if rings <= 1 else float(i) / float(rings - 1)
		var spd: float = lerp(skull_speed_min, skull_speed_max, t)
		var yaw: float = deg_to_rad(lerp(0.0, skull_fan_half_angle_deg, t))
		var y_off: float = randf_range(-skull_y_jitter, skull_y_jitter)
		for side: int in [-1, 1]:
			var x_off: float = float(i + 1) * skull_burst_spacing * float(side)
			_spawn_skull_fan(side, Vector2(x_off, y_off), spd, yaw)
		if i < rings - 1:
			await get_tree().create_timer(skull_burst_interval).timeout

func _spawn_skull_fan(side: int, local_offset: Vector2, speed_value: float, yaw: float) -> void:
	var spawn_pos: Vector2 = global_position + local_offset
	var base_dir: Vector2
	if skull_aim_at_player:
		var pl: Node2D = _get_player()
		if pl != null and is_instance_valid(pl):
			base_dir = (pl.global_position - spawn_pos).normalized()
		else:
			base_dir = Vector2.RIGHT if side == 1 else Vector2.LEFT
	else:
		base_dir = Vector2.RIGHT if side == 1 else Vector2.LEFT
	if base_dir == Vector2.ZERO:
		base_dir = Vector2.RIGHT
	var dir_vec: Vector2 = base_dir.rotated(yaw * float(side)).normalized()
	var vel: Vector2 = dir_vec * speed_value

	var node: Node = skull_spell_scene.instantiate()
	node.set("velocity", vel)
	node.set("speed", speed_value)
	node.set("direction", side)
	node.add_to_group("BossProjectiles")
	get_parent().add_child(node)

	var as2d: Node2D = node as Node2D
	if as2d != null:
		as2d.global_position = spawn_pos

	var rb: RigidBody2D = node as RigidBody2D
	if rb != null:
		rb.add_collision_exception_with(self)

	var ha: Node = node.get_node_or_null("HitArea")
	if ha != null and ha is Area2D:
		_configure_area_layer_mask(ha as Area2D, 4, [1])

func _cast_purple_fire_ball() -> void:
	if purple_fire_ball_scene == null:
		return
	var top_y: float = _get_viewport_top_world_y() - 64.0
	var player: Node2D = _get_player()
	var base_x: float = player.global_position.x if (player != null) else (global_position.x + randf_range(-200.0, 200.0))
	for i in range(purple_burst_count):
		if not alive: break
		var target_x: float = base_x
		if purple_track_player_each_shot and player != null and is_instance_valid(player):
			target_x = player.global_position.x
		var spawn_x: float = target_x + randf_range(-purple_spawn_spread_x, purple_spawn_spread_x)
		_spawn_single_purple_fireball(spawn_x, top_y)
		if i < purple_burst_count - 1:
			await get_tree().create_timer(purple_burst_interval).timeout

func _cast_dead_spell() -> void:
	if dead_spell_scene == null:
		return
	var pl: Node2D = _get_player()
	var center: Vector2 = (pl.global_position if (pl != null and is_instance_valid(pl)) else global_position)
	_play_dead_cast_sfx(center)
	for ang: float in [45.0, 135.0, 225.0, 315.0]:
		var start_pos: Vector2 = center + Vector2.RIGHT.rotated(deg_to_rad(ang)) * dead_spawn_radius
		var ghost: Node = dead_spell_scene.instantiate()
		if ghost.has_method("setup"):
			ghost.call("setup", start_pos, center, dead_charge_speed, pl)
		ghost.add_to_group("BossProjectiles")
		get_parent().add_child(ghost)

func _spawn_single_purple_fireball(spawn_x: float, top_y: float) -> void:
	if purple_fire_ball_scene == null:
		return
	var spawn_pos: Vector2 = Vector2(spawn_x, top_y)
	_play_purple_cast_sfx(spawn_pos)
	var spell: Node2D = purple_fire_ball_scene.instantiate() as Node2D
	get_parent().add_child(spell)
	spell.global_position = spawn_pos
	if spell is RigidBody2D:
		(spell as RigidBody2D).add_collision_exception_with(self)
	spell.set("gravity_scale_override", purple_gravity_scale)
	spell.add_to_group("BossProjectiles")
	var ha: Node = spell.get_node_or_null("HitArea")
	if ha != null and ha is Area2D:
		_configure_area_layer_mask(ha as Area2D, 4, [1])

# ---------- SFX ----------
func _play_skull_cast_sfx(at_pos: Vector2) -> void:
	if skull_cast_sfx == null: return
	var p := AudioStreamPlayer2D.new()
	p.stream = skull_cast_sfx
	p.volume_db = skull_cast_sfx_volume_db
	p.bus = "SFX"
	p.global_position = at_pos
	get_tree().current_scene.add_child(p)
	p.play()
	if p.has_signal("finished"):
		p.finished.connect(Callable(p, "queue_free"))
	else:
		var dur := 1.0
		if p.stream != null and p.stream.has_method("get_length"):
			dur = max(0.1, p.stream.get_length())
		get_tree().create_timer(dur + 0.1).timeout.connect(Callable(p, "queue_free"))

func _play_purple_cast_sfx(at_pos: Vector2) -> void:
	if purple_cast_sfx == null: return
	var p := AudioStreamPlayer2D.new()
	p.stream = purple_cast_sfx
	p.volume_db = purple_cast_sfx_volume_db
	p.bus = "SFX"
	p.global_position = at_pos
	get_tree().current_scene.add_child(p)
	p.play()
	if p.has_signal("finished"):
		p.finished.connect(Callable(p, "queue_free"))
	else:
		var dur := 1.0
		if p.stream != null and p.stream.has_method("get_length"):
			dur = max(0.1, p.stream.get_length())
		get_tree().create_timer(dur + 0.1).timeout.connect(Callable(p, "queue_free"))

func _play_dead_cast_sfx(at_pos: Vector2) -> void:
	if dead_cast_sfx == null: return
	var p := AudioStreamPlayer2D.new()
	p.stream = dead_cast_sfx
	p.volume_db = dead_cast_sfx_volume_db
	p.bus = "SFX"
	p.global_position = at_pos
	get_tree().current_scene.add_child(p)
	if p.stream != null:
		if p.stream.has_method("set_loop"):
			p.stream.call("set_loop", false)
		elif p.stream.has_method("set_loop_mode"):
			p.stream.call("set_loop_mode", 0)
	p.play()
	if p.has_signal("finished"):
		p.finished.connect(Callable(p, "queue_free"))
	else:
		var dur := 1.2
		if p.stream != null and p.stream.has_method("get_length"):
			dur = max(0.1, p.stream.get_length())
		get_tree().create_timer(dur + 0.1).timeout.connect(Callable(p, "queue_free"))

# ---------- Helpers ----------
func _get_player() -> Node2D:
	for n in get_tree().get_nodes_in_group("Player"):
		if n is Node2D: return n
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
	var p := PhysicsRayQueryParameters2D.create(from_pos, from_pos + Vector2(0, 2000.0))
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
