extends Area2D

@export var damage: int = 250
@export var radius: float = 220.0
@export var anim_name: String = "Impact"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var shape: CollisionShape2D = $CollisionShape2D

var _hit_once := {}

func _ready() -> void:
	# เลเยอร์ 6 = PlayerAttack, ชนเฉพาะ Boss(3)
	for i in range(1, 33):
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

	# -------- ปิด loop + เล่นจบแล้วลบทิ้ง --------
	var loop_set := false
	if anim and anim.sprite_frames:
		var frames := anim.sprite_frames
		# ปิด loop ของคลิป Impact (ถ้ามี)
		if frames.has_animation(anim_name):
			frames.set_animation_loop(anim_name, false)
			loop_set = true
			anim.play(anim_name)
		else:
			# ไม่มีชื่อที่ระบุ → เล่นอันปัจจุบันและปิด loop ให้หมดไว้ก่อน
			for n in frames.get_animation_names():
				frames.set_animation_loop(n, false)
			anim.play()  # ใช้ค่า default ใน Inspector
		# เล่นจบแล้วลบ (one-shot กันเรียกซ้ำ)
		if not anim.animation_finished.is_connected(_on_anim_finished):
			anim.animation_finished.connect(_on_anim_finished, Object.CONNECT_ONE_SHOT)
	else:
		# ไม่มีสไปรท์เฟรม → ลบตัวเองภายใน 0.6s
		get_tree().create_timer(0.6).timeout.connect(queue_free)

	# ดาเมจทันทีสำหรับสิ่งที่ทับอยู่แล้ว (รอ 1 เฟรมให้ overlap คำนวนก่อน)
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
