extends CharacterBody2D

@export var speed = 40
@export var gravity : float = 30

var sprite = "ghost"
var time_run = 0
var alive = true
var just_spawned = true

@onready var explosion: GPUParticles2D = $explosion
@onready var head_shape: CollisionShape2D = $HeadArea/CollisionShape2D
@onready var hit_shape: CollisionShape2D = $HitArea/CollisionShape2D
@onready var main_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	randomize()
	alive = true
	explosion.emitting = false
	choose_random_animation()
	$AnimatedSprite2D.visible = true
	$AnimatedSprite2D.play(sprite)

	velocity.x = speed if randf() < 0.5 else -speed

	# ป้องกันตายทันทีเมื่อเริ่มเกม
	just_spawned = true
	await get_tree().create_timer(0.5).timeout
	just_spawned = false

func _process(delta: float) -> void:
	if !visible or !alive:
		return

	if !is_on_floor():
		velocity.y += gravity

	if time_run > 1 and is_on_wall():
		velocity.x = -velocity.x
		time_run = 0

	if !$AnimatedSprite2D.is_playing() or $AnimatedSprite2D.animation != sprite:
		$AnimatedSprite2D.play(sprite)

	$AnimatedSprite2D.flip_h = velocity.x > 0.0
	time_run += delta

	move_and_slide()

func _on_hit_area_body_entered(body: Node2D) -> void:
	if alive and !just_spawned:
		GameManager.damage(20)
		#death()

func _on_head_area_body_entered(body: Node2D) -> void:
	if alive and !just_spawned and body.is_in_group("Player"):
		GameManager.damage(20)
		#death()
		if body.has_method("bounce"):
			body.bounce()

func death():
	if !alive:
		return

	alive = false
	GameManager.add_score()

	explosion.emitting = true
	$AnimatedSprite2D.visible = false

	hit_shape.disabled = true
	head_shape.disabled = true
	main_shape.disabled = true
	velocity = Vector2.ZERO

	await get_tree().create_timer(1).timeout
	queue_free()  # ลบ node ออกจาก scene ถาวร

func choose_random_animation():
	var anim_names = $AnimatedSprite2D.sprite_frames.get_animation_names()
	if anim_names.size() > 0:
		sprite = anim_names[randi() % anim_names.size()]
