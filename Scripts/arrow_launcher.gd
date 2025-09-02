extends Node2D

@export var direction: Vector2 = Vector2.LEFT   # RIGHT/LEFT/UP/DOWN
@export var fire_rate: float = 1.5               # วิ/นัด
@export var arrow_speed: float = 900.0
@export var start_delay: float = 0.0
@export var only_when_player_in_range: bool = false

const ARROW_SCENE := preload("res://Scenes/Prefabs/Arrow.tscn")

@onready var _spawn: Marker2D = $Spawn
@onready var _timer: Timer = $FireTimer
@onready var _trigger: Area2D = null

func _ready() -> void:
	if has_node("TriggerArea"):
		_trigger = $TriggerArea

	rotation = direction.angle()

	_timer.one_shot = false
	_timer.wait_time = fire_rate
	_timer.timeout.connect(_fire)

	if only_when_player_in_range and _trigger:
		_trigger.body_entered.connect(_on_trigger_entered)
		_trigger.body_exited.connect(_on_trigger_exited)
	else:
		if start_delay > 0.0:
			get_tree().create_timer(start_delay).timeout.connect(func(): _timer.start())
		else:
			_timer.start()

func _on_trigger_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		if start_delay > 0.0:
			get_tree().create_timer(start_delay).timeout.connect(func(): _timer.start())
		else:
			_timer.start()

func _on_trigger_exited(body: Node) -> void:
	if body.is_in_group("Player"):
		_timer.stop()

func _fire() -> void:
	var arrow := ARROW_SCENE.instantiate() as Area2D
	arrow.global_position = _spawn.global_position
	get_tree().current_scene.add_child(arrow)
	arrow.call("setup", direction, arrow_speed)
