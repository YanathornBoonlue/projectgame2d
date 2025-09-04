extends Area2D

@export var heal_amount: int = 20
@export var life_time: float = 5.0
@export var fall_time: float = 0.35
@export var hover_amp: float = 6.0
@export var hover_freq: float = 3.0
@export var ground_snap_margin: float = 6.0

# ★ เพิ่ม: ตั้งเสียง Pickup.wav ที่นี่
@export var pickup_sfx: AudioStream
@export var pickup_sfx_volume_db: float = -6.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var _t: float = 0.0
var _base_y: float = 0.0
var _alive: bool = true

func _ready() -> void:
	randomize()
	add_to_group("Pickups")
	for i: int in range(1, 33):
		set_collision_layer_value(i, false)
		set_collision_mask_value(i, false)
	set_collision_mask_value(1, true) # Player

	monitoring = true
	monitorable = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_ensure_shape()
	_play_random_anim()

	await _drop_to_ground()
	_base_y = position.y
	set_process(true)
	get_tree().create_timer(life_time).timeout.connect(_expire_and_free)

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * TAU * hover_freq) * hover_amp

func _on_body_entered(b: Node) -> void:
	if not _alive: return
	if b.is_in_group("Player"):
		_alive = false
		GameManager.hp = min(GameManager.hp + heal_amount, 100)

		# ★ เล่นเสียง Pickup.wav
		_play_pickup_sfx()

		var tw: Tween = create_tween()
		tw.tween_property(self, "scale", Vector2(0.0, 0.0), 0.15)
		await tw.finished
		queue_free()

func _expire_and_free() -> void:
	if not _alive: return
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
	if anim == null: return
	var frames: SpriteFrames = anim.sprite_frames
	if frames == null: return
	var names := frames.get_animation_names()
	if names.size() == 0: return
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
	await tw.finished

# ★ one-shot pickup sound
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
