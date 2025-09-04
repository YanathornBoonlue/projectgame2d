extends Area2D

@export var amplitude: float = 4.0
@export var frequency: float = 5.0
@export var anim_name: String = "Effect"
@export var charges_granted: int = 1
@export var score_reward: int = 1

# ★ เพิ่ม: ตั้งเสียงเก็บทาง Inspector
@export var pickup_sfx: AudioStream
@export var pickup_sfx_volume_db: float = -6.0

var t: float = 0.0
var start_pos: Vector2 = Vector2.ZERO
var _consumed: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	start_pos = position
	monitoring = true
	monitorable = true
	for i in range(1, 33):
		set_collision_mask_value(i, false)
	set_collision_mask_value(1, true) # Player

	if anim and anim.sprite_frames:
		if anim.sprite_frames.has_animation(anim_name):
			anim.play(anim_name)
		else:
			anim.play()

	var cb := Callable(self, "_on_body_entered")
	if not body_entered.is_connected(cb):
		body_entered.connect(cb)

func _process(delta: float) -> void:
	t += delta
	position.y = start_pos.y + amplitude * sin(frequency * t)

func _on_body_entered(body: Node) -> void:
	if _consumed: return
	if not body.is_in_group("Player"): return

	_consumed = true
	set_deferred("monitoring", false)
	set_deferred("collision_mask", 0)
	var shp := get_node_or_null("CollisionShape2D")
	if shp is CollisionShape2D:
		(shp as CollisionShape2D).set_deferred("disabled", true)

	if charges_granted > 0:
		GameManager.add_ultimate_charge(charges_granted)

	if score_reward > 0:
		for i in range(score_reward):
			GameManager.add_score()

	# ★ เล่นเสียงเก็บ
	_play_pickup_sfx()

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ZERO, 0.1)
	await tw.finished
	queue_free()

# ★ ฟังก์ชันเล่นเสียงแบบ one-shot (อยู่ได้นอกตัวไอเท็ม)
func _play_pickup_sfx() -> void:
	if pickup_sfx == null: return
	var p := AudioStreamPlayer2D.new()
	p.stream = pickup_sfx
	p.volume_db = pickup_sfx_volume_db
	var bus := "SFX"
	if AudioServer.get_bus_index(bus) < 0:
		bus = "Master"
	p.bus = bus
	p.global_position = global_position
	get_tree().current_scene.add_child(p)
	p.play()

	var dur := 1.0
	if pickup_sfx.has_method("get_length"):
		dur = max(0.1, pickup_sfx.get_length())
	get_tree().create_timer(dur + 0.1).timeout.connect(Callable(p, "queue_free"))
