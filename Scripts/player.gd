extends CharacterBody2D

# --------- VARIABLES ---------- #

@export_category("Player Properties") # You can tweak these changes according to your likings
@export var move_speed : float = 400
@export var jump_force : float = 600
@export var gravity : float = 30
@export var max_jump_count : int = 2
var jump_count : int = 2

@export_category("Toggle Functions") # Double jump feature is disable by default (Can be toggled from inspector)
@export var double_jump : = true

var is_grounded : bool = false
var is_dying: bool = false
var can_take_damage: bool = true # For damage cooldown
var fall_limit = 1440  # Adjust based on how far down your stage is

@onready var player_sprite = $AnimatedSprite2D
@onready var spawn_point = %SpawnPoint
@onready var particle_trails = $ParticleTrails
@onready var death_particles = $DeathParticles

# --------- BUILT-IN FUNCTIONS ---------- #

func _process(_delta):
	# Calling functions
	movement()
	player_animations()
	flip_player()
	
	# Check if player HP is gone
	if GameManager.hp <= 0 and not is_dying:
		GameManager.hp = 0
		death_particles.emitting = true
		death_tween()
		
	# 🔹 Check for falling out of stage
	if global_position.y > fall_limit and !is_dying:
		GameManager.hp = 0
		death_particles.emitting = true
		AudioManager.death_sfx.play()
		death_tween()
	
# --------- CUSTOM FUNCTIONS ---------- #

# <-- Player Movement Code -->
func movement():
	# Gravity
	if !is_on_floor():
		velocity.y += gravity
	elif is_on_floor():
		jump_count = max_jump_count
	
	handle_jumping()
	
	# Move Player
	var inputAxis = Input.get_axis("Left", "Right")
	velocity = Vector2(inputAxis * move_speed, velocity.y)
	move_and_slide()

# Handles jumping functionality (double jump or single jump, can be toggled from inspector)
func handle_jumping():
	if Input.is_action_just_pressed("Jump"):
		if is_on_floor() and !double_jump:
			jump()
		elif double_jump and jump_count > 0:
			jump()
			jump_count -= 1

# Player jump
func jump():
	jump_tween()
	AudioManager.jump_sfx.play()
	velocity.y = -jump_force

# Handle Player Animations
func player_animations():
	particle_trails.emitting = false
	
	if is_on_floor():
		if abs(velocity.x) > 0:
			particle_trails.emitting = true
			$Yanathorn/AnimationPlayer.play("เดิน")
		else:
			player_sprite.play("Idle")
			$Yanathorn/AnimationPlayer.play("RESET")
	else:
		$Yanathorn/AnimationPlayer.play("กระโดด")

# Flip player sprite based on X velocity
func flip_player():
	if velocity.x < 0:
		player_sprite.flip_h = true
	elif velocity.x > 0:
		player_sprite.flip_h = false

# Tween Animations
#func death_tween():
	#is_dying = true
	#var tween = create_tween()
	#tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	#await tween.finished
	#global_position = spawn_point.global_position
	#await get_tree().create_timer(0.3).timeout
	#AudioManager.respawn_sfx.play()
	#GameManager.respawn_player()
	#respawn_tween()
	#is_dying = false

func death_tween() -> void:
	if is_dying: return
	is_dying = true

	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.15)
	await tween.finished

	# 👉 เรียก Game Over UI (อย่า respawn ที่นี่)
	var ui := get_node_or_null("/root/GameOverUI")
	if ui:
		ui.call("show_you_died")
	else:
		# fallback เผื่อยังไม่ได้ Autoload ซีน
		GameManager.respawn_player()


func respawn_tween():
	var tween = create_tween()
	tween.stop(); tween.play()
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)

func jump_tween():
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.7, 1.4), 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)

# --------- SIGNALS ---------- #
# Reset the player's position to the current level spawn point if collided with any trap
func _on_collision_body_entered(body: Node) -> void:
	if is_dying:
		return

	if body.is_in_group("Traps"):
		if not can_take_damage:
			return
		can_take_damage = false

		GameManager.damage(20)              # จะถูก clamp ไม่ให้ต่ำกว่า 0 ใน GameManager
		death_particles.emitting = true

		if GameManager.hp <= 0:
			_begin_death()
		else:
			get_tree().create_timer(1.0).timeout.connect(func(): can_take_damage = true)

	elif body.is_in_group("Traps Dead"):
		# ฆ่าทันที
		GameManager.hp = 0
		_begin_death()

func _begin_death() -> void:
	if is_dying:
		return
	is_dying = true
	can_take_damage = false

	# ปิดคอลลิชัน+ฟิสิกส์ตั้งแต่เริ่มตาย
	_disable_collisions_deferred()
	set_physics_process(false)
	set_process(false)

	AudioManager.death_sfx.play()
	death_particles.emitting = true

	# ย่อแล้วซ่อนจริง ๆ
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.15)
	await tw.finished
	hide()                              # << ซ่อนตัวละครชัดเจน
	await get_tree().process_frame      # << บังคับวาดเฟรมให้สถานะซ่อนมีผลก่อน pause

	# ส่งต่อให้ UI แสดง YOU DIED และรีโหลดฉากหลังจบ
	var ui := get_node_or_null("/root/GameOverUI")
	if ui:
		ui.call("show_you_died")
	else:
		GameManager.respawn_player.call_deferred()
		
func _disable_collisions_deferred() -> void:
	# ปิดทุก CollisionShape2D ที่อยู่ใต้ player
	for n in find_children("", "CollisionShape2D", true, false):
		(n as CollisionShape2D).set_deferred("disabled", true)
	# กันชนกับทุกอย่าง
	collision_layer = 0
	collision_mask  = 0
