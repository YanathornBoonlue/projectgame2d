extends CharacterBody2D

# --------- MOVEMENT ---------- #
@export_category("Player Properties")
@export var move_speed: float = 400.0
@export var jump_force: float = 700.0
@export var gravity: float = 2000.0
@export var max_jump_count: int = 2
var jump_count: int = 2

@export_category("Toggle Functions")
@export var double_jump: bool = true

var is_dying: bool = false
var can_take_damage: bool = true
var fall_limit: float = 1440.0

# --------- COMBAT (SHOOT) ---------- #
@export_category("Combat")
@export var projectile_scene: PackedScene
@export var shot_cooldown: float = 0.2
@export var projectile_speed: float = 900.0
@export var projectile_damage: int = 20
var _shot_cd: float = 0.0

# Ultimate Attack
@export var ultimate_scene: PackedScene
@export var ultimate_cooldown: float = 1.0
var _ulti_cd: float = 0.0

const SHOOT_ACTION := "Shoot"
const ULT_ACTION   := "Ultimate"

# --------- NODES ---------- #
@onready var player_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var spawn_point: Node2D = %SpawnPoint
@onready var particle_trails := $ParticleTrails
@onready var death_particles  := $DeathParticles
@onready var shoot_point: Node2D = get_node_or_null("ShootPoint")

func _ready() -> void:
	add_to_group("Player")

# --------- MAIN LOOP ---------- #
func _physics_process(delta: float) -> void:
	# Movement & anim
	movement(delta)
	player_animations()
	flip_player()

	# ตายเมื่อ HP หมด
	if GameManager.hp <= 0 and not is_dying:
		GameManager.hp = 0
		death_particles.emitting = true
		death_tween()

	# ตกแมพ
	if global_position.y > fall_limit and not is_dying:
		GameManager.hp = 0
		death_particles.emitting = true
		death_tween()

	# ยิงปกติ
	_shot_cd = max(_shot_cd - delta, 0.0)
	if InputMap.has_action(SHOOT_ACTION) and Input.is_action_just_pressed(SHOOT_ACTION):
		_shoot()

	# อัลติ
	_ulti_cd = max(_ulti_cd - delta, 0.0)
	if _ulti_cd <= 0.0 and InputMap.has_action(ULT_ACTION) and Input.is_action_just_pressed(ULT_ACTION):
		_try_use_ultimate()

# --------- MOVEMENT ---------- #
func movement(delta: float) -> void:
	# Gravity with delta
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		jump_count = max_jump_count

	handle_jumping()

	# Move X
	var input_axis := Input.get_axis("Left", "Right")
	velocity.x = input_axis * move_speed

	move_and_slide()

func handle_jumping() -> void:
	if Input.is_action_just_pressed("Jump"):
		if is_on_floor() and not double_jump:
			jump()
		elif double_jump and jump_count > 0:
			jump()
			jump_count -= 1

func jump() -> void:
	jump_tween()
	if AudioManager.has_node("jump_sfx"):
		AudioManager.jump_sfx.play()
	velocity.y = -jump_force

# --------- ANIM / FLIP ---------- #
func player_animations() -> void:
	particle_trails.emitting = false

	if is_on_floor():
		if abs(velocity.x) > 0.0:
			particle_trails.emitting = true
			$Yanathorn/AnimationPlayer.play("เดิน")
		else:
			player_sprite.play("Idle")
			$Yanathorn/AnimationPlayer.play("RESET")
	else:
		$Yanathorn/AnimationPlayer.play("กระโดด")

func flip_player() -> void:
	if velocity.x < 0.0:
		player_sprite.flip_h = true
	elif velocity.x > 0.0:
		player_sprite.flip_h = false

# --------- SHOOT ---------- #
func _shoot() -> void:
	if projectile_scene == null or _shot_cd > 0.0 or is_dying:
		return

	var bolt := projectile_scene.instantiate() as Node2D
	get_parent().add_child(bolt)

	# ตำแหน่งเกิด
	var spawn_pos := global_position
	if is_instance_valid(shoot_point):
		spawn_pos = shoot_point.global_position
	bolt.global_position = spawn_pos

	# ทิศตามการหัน
	var dir := -1 if player_sprite.flip_h else 1

	# ส่งค่ากระสุน
	bolt.set("direction", dir)
	bolt.set("damage", projectile_damage)
	bolt.set("speed", projectile_speed)

	_shot_cd = shot_cooldown

# --------- ULTIMATE (ใช้ได้แม้ไม่มีบอส) ---------- #
func _try_use_ultimate() -> void:
	if is_dying or _ulti_cd > 0.0 or ultimate_scene == null:
		return

	# ✅ หักจำนวนก่อน (จะได้ลดเสมอถ้ามีของ)
	if not GameManager.consume_ultimate():
		return

	# เลือกตำแหน่งจะเกิดสกิล: ถ้ามีบอส → บนตัวบอส, ถ้าไม่มี → บนตัวผู้เล่น
	var spawn_pos: Vector2 = global_position
	var target := _get_nearest_boss()
	if target != null:
		spawn_pos = target.global_position

	# สร้างเอฟเฟ็กต์
	var fx := ultimate_scene.instantiate() as Node2D
	get_parent().add_child(fx)
	fx.global_position = spawn_pos

	# ส่งพารามิเตอร์ (ถ้าซีน Ultimate รองรับ)
	if "ultimate_damage" in GameManager:
		fx.set("damage", GameManager.ultimate_damage)
	if "ultimate_radius" in GameManager:
		fx.set("radius", GameManager.ultimate_radius)

	# คูลดาวน์
	_ulti_cd = ultimate_cooldown

func _get_nearest_boss() -> Node2D:
	var nearest: Node2D = null
	var best: float = 1e20
	for n in get_tree().get_nodes_in_group("Boss"):
		if n is Node2D:
			if "alive" in n and not n.alive:
				continue
			var pos: Vector2 = (n as Node2D).global_position
			var d: float = (pos - global_position).length()
			if d < best:
				best = d
				nearest = n as Node2D
	return nearest

# --------- DEATH / RESPAWN (เวอร์ชัน UI) ---------- #
func death_tween() -> void:
	if is_dying: return
	is_dying = true

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	await tween.finished

	# เรียก Game Over UI (อย่า respawn ตรงนี้)
	var ui := get_node_or_null("/root/GameOverUI")
	if ui:
		ui.call("show_you_died")
	else:
		GameManager.respawn_player()

func respawn_tween() -> void:
	var tween := create_tween()
	tween.stop(); tween.play()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)

func jump_tween() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 1.4), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)

# --------- SIGNALS (DAMAGE) ---------- #
func _on_collision_body_entered(body: Node) -> void:
	if is_dying:
		return

	if body.is_in_group("Traps"):
		if not can_take_damage:
			return
		can_take_damage = false

		GameManager.damage(20)
		death_particles.emitting = true

		if GameManager.hp <= 0:
			_begin_death()
		else:
			get_tree().create_timer(1.0).timeout.connect(func(): can_take_damage = true)

	elif body.is_in_group("Traps Dead"):
		GameManager.hp = 0
		_begin_death()

func _begin_death() -> void:
	if is_dying:
		return
	is_dying = true
	can_take_damage = false

	_disable_collisions_deferred()
	set_physics_process(false)
	set_process(false)

	if AudioManager.has_node("death_sfx"):
		AudioManager.death_sfx.play()
	death_particles.emitting = true

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.15)
	await tw.finished
	hide()
	await get_tree().process_frame

	var ui := get_node_or_null("/root/GameOverUI")
	if ui:
		ui.call("show_you_died")
	else:
		GameManager.respawn_player.call_deferred()

func _disable_collisions_deferred() -> void:
	for n in find_children("", "CollisionShape2D", true, false):
		(n as CollisionShape2D).set_deferred("disabled", true)
	collision_layer = 0
	collision_mask  = 0
