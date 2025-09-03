extends Node2D

# ========== CONFIG ==========
@export_enum("Right", "Left", "Up", "Down", "Custom")
var dir_mode: String = "Right"           # เลือกทิศจากเมนู
@export var custom_direction := Vector2.RIGHT  # ใช้เมื่อ dir_mode = Custom

@export var travel_distance: float = 200.0     # ระยะที่เคลื่อนที่ (พิกเซล)
@export var speed: float = 240.0               # ความเร็ว (พิกเซล/วินาที)
@export var ping_pong: bool = true             # ไป-กลับวนลูป
@export var start_delay: float = 0.0           # หน่วงก่อนเริ่มเคลื่อนที่ (วินาที)

@export var play_animation_name := "new_animation"  # ชื่อแอนิเมชันใน AnimationPlayer
@export var randomize_sprite_animation: bool = true # สุ่มแอนิเมชันของ AnimatedSprite2D

# ========== INTERNAL ==========
var _start_pos: Vector2
var _tween: Tween

func _ready() -> void:
	_start_pos = global_position
	# ให้กับดักอยู่ในกลุ่ม "Traps" เพื่อให้ Player ของคุณตรวจชนแล้วใส่ดาเมจได้
	add_to_group("Traps")

	# 1) เล่นแอนิเมชันของ AnimationPlayer (หมุน/เอฟเฟกต์)
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play(play_animation_name)
	else:
		push_warning("AnimationPlayer not found")

	# 2) สุ่มแอนิเมชันของ AnimatedSprite2D (ถ้ามี)
	if randomize_sprite_animation:
		_randomize_sprite_anim("StaticBody2D/CollisionShape2D/AnimatedSprite2D")

	# 3) เริ่มการเคลื่อนที่
	if start_delay > 0.0:
		get_tree().create_timer(start_delay).timeout.connect(_start_motion)
	else:
		_start_motion()

func _start_motion() -> void:
	var dir: Vector2 = _get_dir().normalized()
	if dir == Vector2.ZERO:
		push_warning("Direction is ZERO, trap will not move")
		return

	var a: Vector2 = _start_pos
	var b: Vector2 = _start_pos + dir * travel_distance
	var duration: float = max(0.01, travel_distance / max(1.0, speed))

	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if ping_pong:
		_tween.set_loops()
		_tween.tween_property(self, "global_position", b, duration)
		_tween.tween_property(self, "global_position", a, duration)
	else:
		_tween.tween_property(self, "global_position", b, duration)

func _get_dir() -> Vector2:
	match dir_mode:
		"Right":
			return Vector2.RIGHT
		"Left":
			return Vector2.LEFT
		"Up":
			return Vector2.UP
		"Down":
			return Vector2.DOWN
		_:
			return custom_direction  # Custom

func _randomize_sprite_anim(path: String) -> void:
	if not has_node(path):
		push_warning("AnimatedSprite2D not found at %s" % path)
		return
	var animated_sprite: AnimatedSprite2D = get_node(path)
	if animated_sprite.sprite_frames:
		var names := animated_sprite.sprite_frames.get_animation_names()
		if names.size() > 0:
			var name := names[randi() % names.size()]
			animated_sprite.set_animation(name)
			animated_sprite.play()

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
		_tween = null
