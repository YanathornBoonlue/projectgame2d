extends Node2D

@export var heal_scene: PackedScene
@export var spawn_interval: float = 10.0
@export var per_wave: int = 2
@export var camera_margin: float = 48.0

func _ready() -> void:
	randomize()

	# สปอนรอบแรก: เลื่อนไปหลังเฟรมนี้
	call_deferred("_spawn_wave")

	# ตั้ง Timer ให้สปอนทุก ๆ spawn_interval
	var t := Timer.new()
	t.wait_time = spawn_interval
	t.one_shot = false
	add_child(t)
	t.timeout.connect(_spawn_wave)
	t.start()

func _spawn_wave() -> void:
	if heal_scene == null:
		return

	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return  # กันพลาดถ้ากล้องยังไม่พร้อม

	var vps := get_viewport_rect().size
	var half := vps * 0.5
	var center := cam.get_screen_center_position()
	var left  := center.x - half.x + camera_margin
	var right := center.x + half.x - camera_margin
	var top   := center.y - half.y + camera_margin

	for i in range(per_wave):
		var x := randf_range(left, right)
		var y := top + 16.0

		var heal := heal_scene.instantiate() as Node2D
		heal.global_position = Vector2(x, y)

		# ❗ เพิ่มแบบ deferred ไปที่ root ของเลเวล (ปลอดภัยสุด)
		get_tree().current_scene.call_deferred("add_child", heal)
