extends RigidBody2D

@export var damage: int = 10
@export var gravity_scale_override: float = 2.5

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var hit_area: Area2D = $HitArea if has_node("HitArea") else null

func _ready() -> void:
	gravity_scale = gravity_scale_override
	linear_damp = 0.0
	angular_damp = 0.0
	freeze = false
	contact_monitor = true
	max_contacts_reported = 4

	if anim:
		anim.play("Purple")  # ชื่อแอนิเมชันตามที่ตั้งไว้

	if notifier:
		notifier.screen_exited.connect(queue_free)

	if hit_area:
		hit_area.body_entered.connect(_on_body_entered)
	else:
		body_entered.connect(_on_body_entered)

func _on_body_entered(b: Node) -> void:
	if b.is_in_group("Player"):
		GameManager.damage(damage)
		queue_free()
