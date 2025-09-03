extends RigidBody2D

@export var damage: int = 10
@export var gravity_scale_override: float = 2.5
@export var anim_name: String = "Purple"

# หายเมื่อพ้นจอด้วย VisibleOnScreenNotifier2D (แนะนำ)
@export var despawn_on_screen_exit: bool = true
# สำรอง: หายเมื่อ y เกินค่านี้ (map limit ล่าง)
@export var map_limit_bottom_y: float = 2000.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_area: Area2D = $HitArea
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

func _ready() -> void:
	add_to_group("BossProjectiles")

	# ❌ ปิดการชนของตัว RigidBody2D เองทั้งหมด
	_disable_body_collisions()

	if anim:
		anim.play(anim_name)

	# ฟิสิกส์ตกอย่างเดียว ไม่ต้องชนโลก
	gravity_scale = gravity_scale_override
	linear_damp = 0.0
	angular_damp = 0.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = false              # ไม่ต้องรายงานการชนแล้ว

	# ✅ ให้ HitArea (Area2D) เป็นตัวตรวจโดน Player เท่านั้น
	if hit_area:
		_set_area_player_only(hit_area)
		var shape: CollisionShape2D = hit_area.get_node("CollisionShape2D")
		if shape and shape.shape is CircleShape2D:
			(shape.shape as CircleShape2D).radius *= 1.8
		hit_area.body_entered.connect(_on_body_entered)
	else:
		# สำรอง (ถ้าไม่มี HitArea): ยังปิดการชนของบอดี้อยู่ดี
		pass

	if notifier and despawn_on_screen_exit:
		notifier.screen_exited.connect(_on_screen_exited)

func _disable_body_collisions() -> void:
	for i in range(1, 33):
		set_collision_layer_value(i, false)
		set_collision_mask_value(i, false)

func _set_area_player_only(a: Area2D) -> void:
	for i in range(1, 33):
		a.set_collision_layer_value(i, false)
		a.set_collision_mask_value(i, false)
	# Layer 4 = BossAttack, Mask 1 = Player (ตามที่คุณตั้งชื่อบิตไว้)
	a.set_collision_layer_value(4, true)
	a.set_collision_mask_value(1, true)

func _physics_process(_delta: float) -> void:
	# กรณีไม่มี notifier หรืออยากใช้ map limit
	if not despawn_on_screen_exit and global_position.y > map_limit_bottom_y:
		queue_free()

func _on_body_entered(b: Node) -> void:
	if b.is_in_group("Player"):
		GameManager.damage(damage)
		queue_free()

func _on_screen_exited() -> void:
	queue_free()

# ---------- helpers ----------
func _set_layers(layer: int, mask_layers: Array) -> void:
	# layer = 4 (ตั้งใน Boss ด้วย _configure_area_layer_mask); mask = [1] (Player)
	for i in range(1, 33):
		set_collision_layer_value(i, false)
	set_collision_layer_value(4, true) # Ensure on BossAttack layer
	for i in range(1, 33):
		set_collision_mask_value(i, false)
	for m in mask_layers:
		set_collision_mask_value(int(m), true)
