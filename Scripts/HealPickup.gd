# res://Scripts/HealPickup.gd
extends Area2D

@export var heal_amount: int = 20         # เพิ่ม HP
@export var life_time: float = 5.0        # อยู่กี่วิถ้าไม่เก็บแล้วหาย
@export var fall_time: float = 0.35       # เวลาตกลงถึงพื้น (tween)
@export var hover_amp: float = 6.0        # ระยะเด้ง ๆ บนพื้น
@export var hover_freq: float = 3.0       # ความถี่เด้ง
@export var ground_snap_margin: float = 6.0  # เว้นจากพื้นเล็กน้อย

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _t: float = 0.0
var _base_y: float = 0.0
var _alive: bool = true

func _ready() -> void:
	randomize()
	add_to_group("Pickups")

	# ตั้ง Mask ให้ตรวจเฉพาะ Player (บิต 1)
	for i: int in range(1, 33):
		set_collision_layer_value(i, false)
		set_collision_mask_value(i, false)
	set_collision_mask_value(1, true) # Player

	# เปิดตรวจชน
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	# ให้แน่ใจว่ามี CollisionShape2D
	_ensure_shape()

	# สุ่มเล่นแอนิเมชันจากคลิปที่มีอยู่ (เช่น "HealA", "HealB")
	_play_random_anim()

	# ตกลงสู่พื้น
	await _drop_to_ground()

	# เริ่ม hover
	_base_y = position.y
	set_process(true)

	# ตั้งหมดอายุ (ถ้าไม่เก็บ)
	get_tree().create_timer(life_time).timeout.connect(_expire_and_free)

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * TAU * hover_freq) * hover_amp

func _on_body_entered(b: Node) -> void:
	if not _alive:
		return
	if b.is_in_group("Player"):
		_alive = false
		# เพิ่ม HP (คาปไว้ที่ 100)
		GameManager.hp = min(GameManager.hp + heal_amount, 100)
		# เล่นเสียง (ใช้ coin_pickup ถ้ามี)
		if Engine.has_singleton("AudioServer"):
			if "AudioManager" in ProjectSettings.get_setting("autoloads", {}):
				if AudioManager.has_node("CoinPickup"):
					AudioManager.coin_pickup_sfx.play()
		# เอฟเฟกต์เล็กน้อยแล้วหาย
		var tw: Tween = create_tween()
		tw.tween_property(self, "scale", Vector2(0.0, 0.0), 0.15)
		await tw.finished
		queue_free()

func _expire_and_free() -> void:
	if not _alive:
		return
	_alive = false
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.2)
	await tw.finished
	queue_free()

# ---------- helpers ----------
func _ensure_shape() -> void:
	var cs: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if cs == null:
		cs = CollisionShape2D.new()
		add_child(cs)
	if cs.shape == null:
		var c := CircleShape2D.new()
		c.radius = 12.0
		cs.shape = c
	cs.set_deferred("disabled", false)

func _play_random_anim() -> void:
	if anim == null:
		return
	var frames: SpriteFrames = anim.sprite_frames
	if frames == null:
		return
	var names := frames.get_animation_names()
	if names.size() == 0:
		return
	# ถ้าคุณตั้งชื่อไว้สองคลิป เช่น HealA/HealB โค้ดนี้จะสุ่มจากทั้งหมดที่มี
	var name := names[randi() % names.size()]
	anim.play(name)

func _drop_to_ground() -> void:
	var from: Vector2 = global_position
	var to: Vector2 = from + Vector2(0, 2000)
	var space := get_world_2d().direct_space_state
	var p := PhysicsRayQueryParameters2D.create(from, to)
	var hit := space.intersect_ray(p)
	var ground_y: float = (hit.position.y if hit.has("position") else (from.y + 64.0))
	var target_y: float = ground_y - ground_snap_margin

	var tw: Tween = create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position:y", target_y, fall_time)

	await tw.finished   # ← รอ tween เสร็จ แล้ว “ไม่ต้อง return”
