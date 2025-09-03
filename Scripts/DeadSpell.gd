extends Area2D

@export var damage: int = 20
@export var charge_speed: float = 520.0
@export var life_time: float = 2.0
@export var hit_radius: float = 18.0
@export var anim_emerge: String = "Emerge"   # ถ้าไม่มีคลิปนี้จะ fallback
@export var anim_charge: String = "Dead"     # ← คุณบอกว่าชื่อคลิปคือ "Dead"
@export var emerge_offset: float = 24.0
@export var emerge_time: float = 0.25
@export var windup_time: float = 0.15
@export var lock_player_on_charge: bool = true

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _spawn_pos: Vector2 = Vector2.ZERO
var _aim_hint: Vector2 = Vector2.ZERO
var _player_ref: Node2D = null
var _velocity: Vector2 = Vector2.ZERO
var _has_hit: bool = false

func setup(start_pos: Vector2, target_pos: Vector2, speed_value: float, player: Node2D = null) -> void:
	_spawn_pos = start_pos
	_aim_hint = target_pos
	_player_ref = player
	charge_speed = speed_value

func _ready() -> void:
	add_to_group("BossProjectiles")

	for i: int in range(1, 33):
		set_collision_layer_value(i, false)
		set_collision_mask_value(i, false)
	set_collision_layer_value(4, true) # BossAttack
	set_collision_mask_value(1, true)  # Player

	_ensure_shape()

	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

	if _spawn_pos == Vector2.ZERO:
		_spawn_pos = global_position
	global_position = _spawn_pos + Vector2(0.0, emerge_offset)

	# เล่นคลิปโผล่ ถ้าไม่มีให้ลองเล่นคลิปชาร์จ ("Dead")
	if _has_anim(anim, anim_emerge):
		anim.play(anim_emerge)
	elif _has_anim(anim, anim_charge):
		anim.play(anim_charge)

	var tw: Tween = create_tween()
	tw.tween_property(self, "global_position", _spawn_pos, emerge_time)
	await tw.finished

	await get_tree().create_timer(windup_time).timeout

	var target: Vector2 = _aim_hint
	if lock_player_on_charge and _player_ref != null and is_instance_valid(_player_ref):
		target = (_player_ref as Node2D).global_position
	if target == global_position:
		target = global_position + Vector2.RIGHT

	var dir: Vector2 = (target - global_position).normalized()
	_velocity = dir * charge_speed

	# เล่นคลิปตอนพุ่ง (Dead)
	if _has_anim(anim, anim_charge):
		anim.play(anim_charge)

	get_tree().create_timer(life_time).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	position += _velocity * delta
	if _velocity != Vector2.ZERO and anim:
		rotation = _velocity.angle()

func _on_body_entered(b: Node) -> void:
	if _has_hit:
		return
	if b.is_in_group("Player"):
		_has_hit = true
		GameManager.damage(damage)
		queue_free()

func _on_area_entered(a: Area2D) -> void:
	if _has_hit:
		return
	if a.is_in_group("Player"):
		_has_hit = true
		GameManager.damage(damage)
		queue_free()

# ---------- helpers ----------
func _ensure_shape() -> void:
	var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if cs == null:
		cs = CollisionShape2D.new()
		var circle: CircleShape2D = CircleShape2D.new()
		circle.radius = hit_radius
		cs.shape = circle
		add_child(cs)
	cs.set_deferred("disabled", false)

func _has_anim(s: AnimatedSprite2D, name: String) -> bool:
	if s == null:
		return false
	var frames: SpriteFrames = s.sprite_frames
	return frames != null and frames.has_animation(name)
