extends Area2D

@export var damage: int = 250
@export var radius: float = 220.0
@export var anim_name: String = "Impact"

# --- SFX (ตอนใช้สกิล) ---
@export var impact_sfx: AudioStream
@export var impact_sfx_volume_db: float = 0.0
@export var sfx_bus: String = "SFX"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D

var _hit_once: Dictionary = {}

func _ready() -> void:
	# เลเยอร์ 6 = PlayerAttack, ชนเฉพาะ Boss(3)
	for i: int in range(1, 33):
		set_collision_layer_value(i, false)
		set_collision_mask_value(i, false)
	set_collision_layer_value(6, true)
	set_collision_mask_value(3, true)

	monitoring = true
	monitorable = true

	# ตั้งรัศมี Area
	if shape and shape.shape is CircleShape2D:
		(shape.shape as CircleShape2D).radius = radius

	# ต่อสัญญาณชน
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# เล่นเสียงทันทีที่ร่าย
	_play_impact_sfx()

	# เล่นอนิเมชัน / one-shot
	if anim and anim.sprite_frames:
		var frames: SpriteFrames = anim.sprite_frames
		if frames.has_animation(anim_name):
			frames.set_animation_loop(anim_name, false)
			anim.play(anim_name)
		else:
			for n in frames.get_animation_names():
				frames.set_animation_loop(n, false)
			anim.play()
		if not anim.animation_finished.is_connected(_on_anim_finished):
			anim.animation_finished.connect(_on_anim_finished, Object.CONNECT_ONE_SHOT)
	else:
		get_tree().create_timer(0.6).timeout.connect(queue_free)

	# รอหนึ่งเฟรมให้ overlap คำนวนก่อนแล้วค่อยทำดาเมจสิ่งที่ทับอยู่
	await get_tree().physics_frame
	_damage_overlaps()

func _on_anim_finished() -> void:
	queue_free()

func _damage_overlaps() -> void:
	for b in get_overlapping_bodies():
		_apply_damage(b)

func _on_body_entered(b: Node) -> void:
	_apply_damage(b)

func _apply_damage(b: Node) -> void:
	if _hit_once.has(b):
		return
	if b.has_method("take_damage"):
		b.call("take_damage", damage)
		_hit_once[b] = true
	elif b.is_in_group("Boss") and b.has_method("_on_hit_by_player"):
		b.call("_on_hit_by_player", damage)
		_hit_once[b] = true

# ---------- SFX ----------
func _play_impact_sfx() -> void:
	if impact_sfx == null:
		return
	var p := AudioStreamPlayer.new()        # ❗️ไม่ใช้ 2D เพื่อตัดปัญหาเรื่องระยะทาง
	p.bus = sfx_bus
	p.stream = impact_sfx
	p.volume_db = impact_sfx_volume_db
	p.process_mode = Node.PROCESS_MODE_ALWAYS   # เล่นได้แม้ paused
	get_tree().current_scene.add_child(p)
	p.play()
	if p.has_signal("finished"):
		p.finished.connect(Callable(p, "queue_free"))
	else:
		var dur := 1.0
		if p.stream != null and p.stream.has_method("get_length"):
			dur = max(0.1, p.stream.get_length())
		get_tree().create_timer(dur + 0.1).timeout.connect(Callable(p, "queue_free"))
