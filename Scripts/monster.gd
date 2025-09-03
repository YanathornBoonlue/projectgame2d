extends CharacterBody2D

@export var speed: float = 40.0
@export var gravity: float = 30.0
var sprite := "ghost"
var time_run := 0.0
var alive := true
var just_spawned := true

@onready var explosion: GPUParticles2D = $explosion
@onready var head_shape: CollisionShape2D = $HeadArea/CollisionShape2D
@onready var hit_shape: CollisionShape2D  = $HitArea/CollisionShape2D
@onready var main_shape: CollisionShape2D = $CollisionShape2D
@onready var head_area: Area2D = $HeadArea
@onready var hit_area: Area2D  = $HitArea
@onready var spr: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	randomize()
	alive = true
	explosion.emitting = false
	choose_random_animation()
	spr.visible = true
	spr.play(sprite)

	add_to_group("Monster")

	# สุ่มทิศเริ่ม
	velocity.x = (speed if randf() < 0.5 else -speed)

	# ✅ มีคอลลิชันบอดี้จริง และไม่ disabled
	_ensure_main_shape()

	# ✅ กันทะลุกำแพง: Layer/Mask ให้ตรง (Monster(7) ชน World(2))
	_set_body_layer_and_mask()

	# Area ตรวจเฉพาะ Player
	_set_area_player_only(hit_area)
	_set_area_player_only(head_area)

	# กันตายทันทีตอนเกิด
	just_spawned = true
	await get_tree().create_timer(0.5).timeout
	just_spawned = false

func _physics_process(delta: float) -> void:
	if not visible or not alive:
		return

	# แรงโน้มถ่วง (คูณ delta)
	if not is_on_floor():
		velocity.y += gravity * delta

	# ชนผนังแล้วเด้งกลับ (หน่วงเวลานิดเพื่อกันเด้งถี่)
	if time_run > 1.0 and is_on_wall():
		velocity.x = -velocity.x
		time_run = 0.0

	if (not spr.is_playing()) or spr.animation != sprite:
		spr.play(sprite)

	spr.flip_h = velocity.x > 0.0
	time_run += delta

	move_and_slide()

# ===== ยิงแล้วตายทันที =====
func take_damage(_amount: int) -> void:
	if not alive or just_spawned:
		return
	death()

func _on_hit_area_body_entered(body: Node2D) -> void:
	if not alive or just_spawned: return
	if not body.is_in_group("Player"): return
	GameManager.damage(20)

func _on_head_area_body_entered(body: Node2D) -> void:
	if not alive or just_spawned: return
	if not body.is_in_group("Player"): return
	if body.has_method("bounce"): body.bounce()
	death()

func death():
	if not alive: return
	alive = false
	GameManager.add_score()
	explosion.emitting = true
	spr.visible = false
	if is_instance_valid(hit_shape):  hit_shape.set_deferred("disabled", true)
	if is_instance_valid(head_shape): head_shape.set_deferred("disabled", true)
	if is_instance_valid(main_shape): main_shape.set_deferred("disabled", true)
	velocity = Vector2.ZERO
	await get_tree().create_timer(1.0).timeout
	queue_free()

func choose_random_animation():
	var anim_names := spr.sprite_frames.get_animation_names()
	if anim_names.size() > 0:
		sprite = anim_names[randi() % anim_names.size()]

func _set_area_player_only(a: Area2D) -> void:
	if a == null: return
	for i in range(1, 33):
		a.set_collision_mask_value(i, false)
	a.set_collision_mask_value(1, true) # Player
	a.set_deferred("monitoring", true)

# ========== กันทะลุกำแพง ==========
func _set_body_layer_and_mask() -> void:
	# เคลียร์ก่อนให้ชัวร์
	collision_layer = 0
	collision_mask  = 0
	for i in range(1, 33):
		set_collision_layer_value(i, false)
		set_collision_mask_value(i, false)

	# Layer ของมอนสเตอร์ (ปรับเลข 7 ให้ตรงโปรเจกต์คุณ ถ้าใช้เลขอื่น)
	set_collision_layer_value(7, true)   # Monster

	# ต้อง "มองเห็น" World(2) เพื่อชนกำแพง/พื้น
	set_collision_mask_value(2, true)    # World

	# ✅ ตามที่ขอ: ให้มอนสเตอร์มีคอลลิชันกับ Player (ถ้าต้องการชนตัวกัน)
	set_collision_mask_value(1, true)    # Player

# ถ้าไม่มี CollisionShape2D หรือถูกปิด/ไม่มี shape → สร้างให้
func _ensure_main_shape() -> void:
	if main_shape == null:
		main_shape = CollisionShape2D.new()
		add_child(main_shape)
	if main_shape.shape == null:
		var rect := RectangleShape2D.new()
		# ขนาดคร่าว ๆ; ปรับตาม sprite/ศัตรูจริงได้
		rect.size = Vector2(16, 16)
		main_shape.shape = rect
	main_shape.set_deferred("disabled", false)
