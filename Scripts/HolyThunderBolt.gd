extends Area2D

@export var speed: float = 900.0
@export var damage: int = 20
@export var life_time: float = 1.8
@export var align_rotation: bool = true
var direction: int = 1

var _exploding := false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var colshape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("PlayerProjectiles")

	# เปิดชนและกำหนดเลเยอร์: 6=PlayerAttack ยิงชน Boss(3) + World(2)
	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	for i in range(1, 33):
		set_collision_layer_value(i, false)
		set_collision_mask_value(i, false)
	set_collision_layer_value(6, true)
	set_collision_mask_value(3, true)
	set_collision_mask_value(2, true)

	# เล่นอนิเมชันบิน
	if anim:
		anim.play("Bolt")                # Bolt = loop on
		anim.flip_h = (direction < 0)

	# อายุสูงสุด/หลุดจอ
	get_tree().create_timer(life_time).timeout.connect(queue_free)
	if notifier and not notifier.screen_exited.is_connected(_on_screen_exited):
		notifier.screen_exited.connect(_on_screen_exited)

func _physics_process(delta: float) -> void:
	if _exploding:
		return
	var vel := Vector2(speed * direction, 0.0)
	position += vel * delta
	if align_rotation and vel != Vector2.ZERO:
		rotation = vel.angle()

func _on_body_entered(b: Node) -> void:
	if _exploding:
		return

	# ทำดาเมจบอส
	if b.has_method("take_damage"):
		b.call("take_damage", damage)
	elif b.is_in_group("Boss") and b.has_method("_on_hit_by_player"):
		b.call("_on_hit_by_player", damage)

	# เล่นเอฟเฟ็กต์ชน แล้วลบ
	_play_impact_and_free()

func _on_screen_exited() -> void:
	queue_free()

# ---------- impact ----------
func _play_impact_and_free() -> void:
	_exploding = true

	# ปิดชน ป้องกันชนซ้ำ
	monitoring = false
	if colshape:
		colshape.disabled = true
	for i in range(1, 33):
		set_collision_layer_value(i, false)
		set_collision_mask_value(i, false)

	# สลับไปเล่นอนิเมชัน Impact (ต้องตั้ง loop = Off)
	if anim and anim.sprite_frames and anim.sprite_frames.has_animation("Impact"):
		anim.play("Impact")
		await anim.animation_finished

	queue_free()
