extends Area2D

@export var speed: float = 900.0
@export var damage: int = 10
@export var lifetime: float = 3.0

var _vel: Vector2 = Vector2.RIGHT

func setup(dir: Vector2, spd: float = 900.0) -> void:
	_vel = dir.normalized() * spd
	rotation = _vel.angle()

func _ready() -> void:
	add_to_group("Traps") # ให้เข้ากับระบบดาเมจเดิม
	$LifeTimer.wait_time = lifetime
	$LifeTimer.one_shot = true
	$LifeTimer.timeout.connect(_on_LifeTimer_timeout)
	$LifeTimer.start()

	body_entered.connect(_on_body_entered)
	area_entered.connect(func(_a): queue_free()) # ชนอะไรก็หาย

func _physics_process(delta: float) -> void:
	position += _vel * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("Player"):
		GameManager.damage(damage)
	queue_free()

func _on_LifeTimer_timeout() -> void:
	queue_free()
