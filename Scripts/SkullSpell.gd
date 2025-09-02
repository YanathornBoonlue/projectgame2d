extends RigidBody2D

@export var speed: float = 420.0
@export var direction: int = 1        # 1 = ขวา, -1 = ซ้าย
@export var damage: int = 15

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var hit_area := $HitArea if has_node("HitArea") else null

func _ready() -> void:
	# ปิดแรงโน้มถ่วงเพื่อให้วิ่งแนวนอนล้วน ๆ
	gravity_scale = 0.0
	linear_damp = 0.0
	angular_damp = 0.0
	freeze = false
	contact_monitor = true
	max_contacts_reported = 4

	# ตั้งความเร็วเริ่ม (แนวนอน)
	linear_velocity = Vector2(speed * direction, 0)
	if anim:
		anim.play("Skull") # ชื่อแอนิเมชันตามที่ตั้งไว้

	if notifier:
		notifier.screen_exited.connect(queue_free)

	# รับชนผ่าน Area ลูก (แนะนำ)
	if hit_area:
		hit_area.body_entered.connect(_on_body_entered)
	else:
		# สำรอง: ใช้สัญญาณของตัว RigidBody เอง
		body_entered.connect(_on_body_entered)

func _on_body_entered(b: Node) -> void:
	if b.is_in_group("Player"):
		GameManager.damage(damage)
		queue_free()
