extends CharacterBody2D

@export var sprite: String = "Agis Idle"
@export var attack_interval: float = 2.0

# HP
@export var max_hp: int = 500
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

@export var purple_burst_count: int = 5          # ยิงกี่ลูกต่อ 1 ครั้งกดสกิล
@export var purple_burst_interval: float = 0.25  # เวลาห่างระหว่างลูก (วินาที)
@export var purple_spawn_spread_x: float = 160.0 # สุ่ม X ซ้ายขวาจากจุดเป้าหมาย
@export var purple_track_player_each_shot: bool = true # ให้ล็อก X ผู้เล่นใหม่ทุกรอบไหม

@export var skull_burst_count_each_side: int = 6      # จำนวนวง/ชั้น ต่อข้าง
@export var skull_burst_spacing: float = 48.0         # ระยะห่างตำแหน่งเกิดแต่ละวง
@export var skull_burst_interval: float = 0.08        # หน่วงเวลาระหว่างวง
@export var skull_y_jitter: float = 8.0               # แกว่งแกน Y เล็กน้อยที่จุดเกิด
@export var skull_fan_half_angle_deg: float = 28.0    # ครึ่งมุมพัดต่อข้าง (องศา)
@export var skull_speed_min: float = 380.0            # ความเร็วใกล้ตัว
@export var skull_speed_max: float = 520.0            # ความเร็วชั้นนอก

@export var skull_aim_at_player: bool = true

@export var dead_spawn_radius: float = 400.0   # ระยะจากผู้เล่นที่สปอน
@export var dead_charge_speed: float = 600.0   # ความเร็วผีวิ่งเข้า


var alive: bool = true
var attack_timer: Timer

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	randomize()

	# ตั้งชั้นชนให้บอส: Layer = Boss(3), Mask = World(2) + Player(1) (ถ้าต้องให้ชนทั้งคู่)
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_layer_value(3, true) # Boss
	set_collision_mask_value(1, true)  # ชน Player ได้ (ถ้าต้อง)
	set_collision_mask_value(2, true)  # ชน World

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
	GameManager.boss_hp = hp         # อัปเดตแถบ HP
	if hp <= 0:
		_die()

func _die() -> void:
	alive = false
	# หยุดยิง
	if is_instance_valid(attack_timer):
		attack_timer.stop()

	# ล้างโปรเจกไทล์บอสที่ค้างในซีน (BossAttack layer = 4)
	for n in get_tree().get_nodes_in_group("BossProjectiles"):
		if is_instance_valid(n):
			n.queue_free()

	# เอฟเฟกต์ตาย + เพิ่มสกอร์
	GameManager.add_score()
	if anim: anim.visible = false
	await get_tree().create_timer(1.0).timeout
	hide()

# เรียกจากอาวุธ/สกิลผู้เล่นถ้าโดน
func _on_hit_by_player(dmg: int) -> void:
	take_damage(dmg)

# ---------- Casts ----------
func _cast_skull_spell() -> void:
	if skull_spell_scene == null:
		return
	await _cast_skull_barrage()
	
func _cast_skull_barrage() -> void:
	var rings: int = max(skull_burst_count_each_side, 1)
	for i: int in range(rings):
		if not alive:
			break

		var t: float = 1.0 if rings <= 1 else float(i) / float(rings - 1)
		var spd: float = lerp(skull_speed_min, skull_speed_max, t)
		var yaw: float = deg_to_rad(lerp(0.0, skull_fan_half_angle_deg, t)) # กว้างขึ้นเรื่อย ๆ
		var y_off: float = randf_range(-skull_y_jitter, skull_y_jitter)

		var sides: Array[int] = [-1, 1]  # ซ้าย, ขวา
		for side: int in sides:
			var x_off: float = float(i + 1) * skull_burst_spacing * float(side)
			_spawn_skull_fan(side, Vector2(x_off, y_off), spd, yaw)

		if i < rings - 1:
			var timer: SceneTreeTimer = get_tree().create_timer(skull_burst_interval)
			await timer.timeout
			
func _spawn_skull_fan(side: int, local_offset: Vector2, speed_value: float, yaw: float) -> void:
	var spawn_pos: Vector2 = global_position + local_offset

	# ทิศฐาน: เล็งผู้เล่นถ้าเปิดใช้, ไม่งั้นซ้าย/ขวา
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

	# หมุนเป็นพัด (mirror ตาม side)
	var dir_vec: Vector2 = base_dir.rotated(yaw * float(side)).normalized()
	var vel: Vector2 = dir_vec * speed_value

	# ตั้งค่าก่อน add_child() เพื่อให้ _ready() ของกระสุนอ่านค่าใหม่ทันที
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
	# จุดยอดจอด้านบน
	var top_y: float = _get_viewport_top_world_y() - 64.0

	# ตำแหน่งเป้าหมายเริ่มต้น: X ผู้เล่น (ถ้ามี) ไม่มีก็สุ่มแถวบอส
	var player: Node2D = _get_player()
	var base_x: float = player.global_position.x if (player != null) else (global_position.x + randf_range(-200.0, 200.0))

	# loop ทยอยสปอนหลายลูก
	for i in range(purple_burst_count):
		if not alive:
			break

		# อัปเดต X เป้าหมายแต่ละนัด (ถ้าให้ติดตามผู้เล่นทุกช็อต)
		var target_x: float = base_x
		if purple_track_player_each_shot and player != null and is_instance_valid(player):
			target_x = player.global_position.x

		# สุ่มกระจายซ้าย/ขวา
		var spawn_x: float = target_x + randf_range(-purple_spawn_spread_x, purple_spawn_spread_x)

		_spawn_single_purple_fireball(spawn_x, top_y)

		# หน่วงก่อนลูกถัดไป
		if i < purple_burst_count - 1:
			var t: SceneTreeTimer = get_tree().create_timer(purple_burst_interval)
			await t.timeout

func _cast_dead_spell() -> void:
	if dead_spell_scene == null:
		return

	var pl: Node2D = _get_player()
	var center: Vector2 = (pl.global_position if (pl != null and is_instance_valid(pl)) else global_position)

	var angles_deg: Array[float] = [45.0, 135.0, 225.0, 315.0]
	for ang: float in angles_deg:
		var start_pos: Vector2 = center + Vector2.RIGHT.rotated(deg_to_rad(ang)) * dead_spawn_radius

		var ghost: Node = dead_spell_scene.instantiate()
		# ← ตั้งค่าก่อน add_child() เพื่อให้ _ready() ใน DeadSpell เห็นครบ
		if ghost.has_method("setup"):
			ghost.call("setup", start_pos, center, dead_charge_speed, pl)
		ghost.add_to_group("BossProjectiles")

		get_parent().add_child(ghost)

func _spawn_single_purple_fireball(spawn_x: float, top_y: float) -> void:
	if purple_fire_ball_scene == null:
		return
	# อินสแตนซ์และตั้งค่าพื้นฐาน
	var spell: Node2D = purple_fire_ball_scene.instantiate() as Node2D
	get_parent().add_child(spell)
	spell.global_position = Vector2(spawn_x, top_y)

	# ถ้าเป็น RigidBody2D ให้กันชนกับบอสเอง
	if spell is RigidBody2D:
		(spell as RigidBody2D).add_collision_exception_with(self)

	# ส่งพารามิเตอร์ฟิสิกส์/แรงโน้มถ่วงให้ลูกไฟ
	spell.set("gravity_scale_override", purple_gravity_scale)

	# เข้ากลุ่มเพื่อล้างตอนบอสตาย
	spell.add_to_group("BossProjectiles")

	# ตั้ง HitArea (ถ้ามี) ให้ชัดเจน Layer=4(BossAttack) Mask=1(Player)
	var ha: Node = spell.get_node_or_null("HitArea")
	if ha != null and ha is Area2D:
		_configure_area_layer_mask(ha as Area2D, 4, [1])


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
