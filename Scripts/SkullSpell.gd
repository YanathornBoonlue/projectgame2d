extends RigidBody2D

@export var speed: float = 420.0
@export var direction: int = 1
@export var velocity: Vector2 = Vector2.ZERO
@export var damage: int = 5
@export var anim_name: String = "Skull"
@export var hit_radius: float = 10.0   # รัศมีฮิตบ็อกซ์ ถ้าไม่มี HitArea จะใช้ค่านี้สร้างให้

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var hit_area: Area2D = null
var _area_created_runtime: bool = false

func _ready() -> void:
	# ปิดคอลลิชันของตัวบอดี้เอง (ไม่ให้ชนโลก) ใช้แต่ Area2D ตรวจโดนผู้เล่น
	for i: int in range(1, 33):
		set_collision_layer_value(i, false)
		set_collision_mask_value(i, false)

	add_to_group("BossProjectiles")

	if anim:
		anim.play(anim_name)

	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	contact_monitor = false

	# ความเร็วจากบอส (ถ้าไม่ส่งมา ค่อย fallback เป็นแนวนอน)
	if velocity != Vector2.ZERO:
		linear_velocity = velocity
	else:
		linear_velocity = Vector2(speed * direction, 0.0)

	_ensure_hit_area()
	_configure_hit_area()
	_connect_hit_area()

# ---------- internal helpers ----------

func _ensure_hit_area() -> void:
	# ถ้ามีโหนดชื่อ HitArea อยู่แล้วก็ใช้เลย
	if has_node("HitArea"):
		hit_area = get_node("HitArea") as Area2D
		return

	# ไม่มีก็สร้างใหม่ runtime
	hit_area = Area2D.new()
	hit_area.name = "HitArea"
	add_child(hit_area)
	_area_created_runtime = true

	var cs: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = hit_radius
	cs.shape = circle
	hit_area.add_child(cs)

func _configure_hit_area() -> void:
	if hit_area == null:
		return

	# เปิด monitoring/monitorable แบบ deferred กัน error ช่วง flush
	hit_area.set_deferred("monitoring", true)
	hit_area.set_deferred("monitorable", true)

	# Layer/Mask ให้ชนเฉพาะ Player (Mask=1) และตัวเองอยู่ Layer=4 (BossAttack)
	for i: int in range(1, 33):
		hit_area.set_collision_layer_value(i, false)
		hit_area.set_collision_mask_value(i, false)
	hit_area.set_collision_layer_value(4, true) # BossAttack
	hit_area.set_collision_mask_value(1, true)  # Player

	# เผื่อมีคนเผลอปิด shape ไว้
	var cs: CollisionShape2D = hit_area.get_node_or_null("CollisionShape2D")
	if cs:
		cs.set_deferred("disabled", false)

func _connect_hit_area() -> void:
	if hit_area == null:
		return
	if not hit_area.body_entered.is_connected(_on_hitarea_body_entered):
		hit_area.body_entered.connect(_on_hitarea_body_entered)

func _on_hitarea_body_entered(b: Node) -> void:
	# ตรวจกลุ่ม Player (อย่าลืมให้ Player อยู่ใน Group "Player" และ Layer บิต 1)
	if b.is_in_group("Player"):
		GameManager.damage(damage)
		queue_free()
