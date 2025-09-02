extends Area2D

@export var amplitude: float = 4.0
@export var frequency: float = 5.0
@export var anim_name: String = "Effect"

var t: float = 0.0
var start_pos := Vector2.ZERO

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	start_pos = position

	# ให้แน่ใจว่า Area2D ตรวจชนได้
	monitoring = true
	monitorable = true

	# เล่นแอนิเมชัน ถ้ามีชื่อ anim_name
	if anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation(anim_name):
			anim.play(anim_name)
		else:
			anim.play()  # fallback: ใช้ค่า default ใน Inspector

	# ต่อสัญญาณ body_entered แบบปลอดภัย (Godot 4)
	var cb := Callable(self, "_on_body_entered")
	if not body_entered.is_connected(cb):
		body_entered.connect(cb)

func _process(delta: float) -> void:
	t += delta
	position.y = start_pos.y + amplitude * sin(frequency * t)

func _on_body_entered(body: Node) -> void:
	# print("Item hit by:", body.name, " groups=", body.get_groups())
	if body.is_in_group("Player"):
		# ถ้ามีเสียง: AudioManager.light_potion_pickup_sfx.play()
		GameManager.add_score()   # +1 ตาม GameManager
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ZERO, 0.1)
		await tw.finished
		queue_free()
