extends CharacterBody2D

@export var speed: float = 40.0
@export var gravity: float = 30.0  # ใช้กับ delta ใน _physics_process
var sprite := "ghost"
var time_run := 0.0
var alive := true
var just_spawned := true

@onready var explosion: GPUParticles2D = $explosion
@onready var head_shape: CollisionShape2D = $HeadArea/CollisionShape2D
@onready var hit_shape: CollisionShape2D = $HitArea/CollisionShape2D
@onready var main_shape: CollisionShape2D = $CollisionShape2D
@onready var head_area: Area2D = $HeadArea
@onready var hit_area: Area2D = $HitArea
@onready var spr: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	randomize()
	alive = true
	explosion.emitting = false
	choose_random_animation()
	spr.visible = true
	spr.play(sprite)

	# สุ่มทิศทางเริ่ม
	velocity.x = (speed if randf() < 0.5 else -speed)

	# จำกัดให้ Area ตรวจ "เฉพาะ Player" เท่านั้น
	_set_area_player_only(hit_area)
	_set_area_player_only(head_area)

	# ป้องกันตายทันทีเมื่อเริ่มเกม
	just_spawned = true
	await get_tree().create_timer(0.5).timeout
	just_spawned = false

func _physics_process(delta: float) -> void:
	if not visible or not alive:
		return

	# แรงโน้มถ่วง (คูณ delta)
	if not is_on_floor():
		velocity.y += gravity * delta

	# เดินชนผนังแล้วค่อยกลับตัว หลังผ่านไปสักพัก
	if time_run > 1.0 and is_on_wall():
		velocity.x = -velocity.x
		time_run = 0.0

	if (not spr.is_playing()) or spr.animation != sprite:
		spr.play(sprite)

	spr.flip_h = velocity.x > 0.0
	time_run += delta

	move_and_slide()

# โดนลำตัวศัตรู -> ทำดาเมจผู้เล่น (เฉพาะเมื่อชน "ผู้เล่น" เท่านั้น)
func _on_hit_area_body_entered(body: Node2D) -> void:
	if not alive or just_spawned:
		return
	if not body.is_in_group("Player"):
		return
	GameManager.damage(20)  # ตัด source ออก
	# ถ้าต้องการคูลดาวน์ไม่ให้อยู่ทับแล้วหักเลือดรัว ๆ ให้ใช้ can_take_damage ของ Player ควบคุม

# เหยียบหัว -> ฆ่าศัตรู + เด้งผู้เล่น (ไม่ทำดาเมจผู้เล่น)
func _on_head_area_body_entered(body: Node2D) -> void:
	if not alive or just_spawned:
		return
	if not body.is_in_group("Player"):
		return
	if body.has_method("bounce"):
		body.bounce()
	death()

func death():
	if not alive:
		return
	alive = false
	GameManager.add_score()

	explosion.emitting = true
	spr.visible = false

	# ปิดคอลลิชันแบบ deferred กัน error ระหว่างสัญญาณ
	if is_instance_valid(hit_shape):
		hit_shape.set_deferred("disabled", true)
	if is_instance_valid(head_shape):
		head_shape.set_deferred("disabled", true)
	if is_instance_valid(main_shape):
		main_shape.set_deferred("disabled", true)
	velocity = Vector2.ZERO

	await get_tree().create_timer(1.0).timeout
	queue_free()

func choose_random_animation():
	var anim_names := spr.sprite_frames.get_animation_names()
	if anim_names.size() > 0:
		sprite = anim_names[randi() % anim_names.size()]

func _set_area_player_only(a: Area2D) -> void:
	if a == null:
		return
	# ไม่ต้องไปยุ่ง layer ก็ได้ (ปล่อยตามที่ตั้งในฉาก)
	# สำคัญคือ "mask" ให้ตรวจเฉพาะ Player (bit 1)
	for i in range(1, 33):
		a.set_collision_mask_value(i, false)
	a.set_collision_mask_value(1, true) # Player
	# เปิด monitoring เผื่อถูกปิด
	a.set_deferred("monitoring", true)
