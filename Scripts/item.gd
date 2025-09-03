extends Area2D

@export var amplitude: float = 4.0
@export var frequency: float = 5.0
@export var anim_name: String = "Effect"
@export var charges_granted: int = 1     # ได้กี่ครั้งต่อขวด

var t: float = 0.0
var start_pos := Vector2.ZERO
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	start_pos = position
	monitoring = true
	monitorable = true

	if anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation(anim_name): anim.play(anim_name)
		else: anim.play()

	var cb := Callable(self, "_on_body_entered")
	if not body_entered.is_connected(cb):
		body_entered.connect(cb)

func _process(delta: float) -> void:
	t += delta
	position.y = start_pos.y + amplitude * sin(frequency * t)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		# เก็บเป็น “จำนวนครั้งใช้สกิล”
		GameManager.add_ultimate_charge(charges_granted)
		# (ถ้าจะมีเสียง pickup)
		# AudioManager.light_potion_pickup_sfx.play()
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ZERO, 0.1)
		await tw.finished
		queue_free()
