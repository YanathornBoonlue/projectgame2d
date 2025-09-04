extends Area2D

@export var speed: float = 900.0
@export var damage: int = 80
@export var life_time: float = 1.8
@export var align_rotation: bool = true
var direction: int = 1

# --- SFX (ยิง) ---
@export var launch_sfx: AudioStream
@export var launch_sfx_volume_db: float = 0.0
@export var sfx_bus: String = "SFX"

var _exploding: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var colshape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("PlayerProjectiles")

	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	#for i: int in range(1, 33):

	# เคลียร์ก่อน
	for i in range(1, 33):
		set_collision_layer_value(i, false)
		set_collision_mask_value(i, false)

	# Layer = PlayerAttack(6)
	set_collision_layer_value(6, true)

	# Mask ชน: World(2) + Boss(3) + Monster(7)
	# (ถ้าโปรเจกต์คุณใช้เลขอื่นแทน Monster ให้แก้ 7 ให้ตรง)
	set_collision_mask_value(2, true)
	set_collision_mask_value(3, true)
	set_collision_mask_value(7, true)

	# เล่นอนิเมชันบิน
	if anim:
		anim.play("Bolt")
		anim.flip_h = (direction < 0)

	# เล่นเสียงยิง (one-shot)
	_play_launch_sfx()

	# อายุสูงสุด/หลุดจอ
	get_tree().create_timer(life_time).timeout.connect(queue_free)
	if notifier and not notifier.screen_exited.is_connected(Callable(self, "_on_screen_exited")):
		notifier.screen_exited.connect(Callable(self, "_on_screen_exited"))

func _physics_process(delta: float) -> void:
	if _exploding:
		return
	var vel: Vector2 = Vector2(speed * direction, 0.0)
	position += vel * delta
	if align_rotation and vel != Vector2.ZERO:
		rotation = vel.angle()

func _on_body_entered(b: Node) -> void:
	if _exploding:
		return

	# ยิงใส่สิ่งที่มี take_damage() (มอนสเตอร์/บอส)
	if b.has_method("take_damage"):
		b.call("take_damage", damage)
	elif b.is_in_group("Boss") and b.has_method("_on_hit_by_player"):
		b.call("_on_hit_by_player", damage)

	_exploding = true
	call_deferred("_play_impact_and_free")

func _play_impact_and_free() -> void:
	# ปิดชนแบบ deferred กัน flush error
	set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if colshape:
		colshape.set_deferred("disabled", true)

	for c in get_children():
		if c is Area2D:
			c.set_deferred("monitoring", false)
			var cs: CollisionShape2D = (c as Area2D).get_node_or_null("CollisionShape2D") as CollisionShape2D
			if cs:
				cs.set_deferred("disabled", true)

	# เล่น Impact แล้วค่อยลบ
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("Impact"):
		anim.play("Impact")
		await anim.animation_finished
	queue_free()

func _on_screen_exited() -> void:
	queue_free()

# ---------- SFX helpers ----------
func _play_launch_sfx() -> void:
	if launch_sfx == null:
		return
	var p: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	p.bus = sfx_bus
	p.stream = launch_sfx
	p.volume_db = launch_sfx_volume_db
	p.global_position = global_position
	get_tree().current_scene.add_child(p)
	p.play()
	if p.has_signal("finished"):
		p.finished.connect(Callable(p, "queue_free"))
	else:
		var dur: float = 1.0
		if p.stream != null and p.stream.has_method("get_length"):
			dur = max(0.1, p.stream.get_length())
		get_tree().create_timer(dur + 0.1).timeout.connect(Callable(p, "queue_free"))
