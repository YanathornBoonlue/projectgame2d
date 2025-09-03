# WorldCollision.gd — ใส่กับ Node2D ชื่อ WorldCollision
extends Node2D

## === ตั้งค่าได้จาก Inspector ===
@export var tilemap_path: NodePath        # ลาก TileMap/TileMapLayer (เช่น Ground) มาใส่
@export var camera_path:  NodePath         # (ทางเลือก) ลาก Camera2D ถ้าจะยึดจาก limit
@export var thickness: float = 64.0        # ความหนากำแพง
@export var play_rect: Rect2 = Rect2(Vector2(-1024, -512), Vector2(2048, 1536))  # fallback
@export var world_layer_bit: int = 2       # World = เลเยอร์ที่ 2 (1..32)

const WALL_PREFIX := "WC_"

func _ready() -> void:
	_clear_old_walls()

	var made: bool = false

	# 1) จาก TileMap/TileMapLayer
	if tilemap_path != NodePath(""):
		var n: Node = get_node_or_null(tilemap_path)
		if n != null:
			var rect_from_tm: Rect2 = _rect_from_tilemap(n)
			if rect_from_tm.size.length() > 0.0:
				_make_bounds(rect_from_tm)
				made = true

	# 2) จาก Camera2D limit
	if not made and camera_path != NodePath(""):
		var cam_node: Node = get_node_or_null(camera_path)
		if cam_node is Camera2D:
			var cam: Camera2D = cam_node as Camera2D
			var rect_from_cam: Rect2 = _rect_from_camera(cam)
			if rect_from_cam.size.length() > 0.0:
				_make_bounds(rect_from_cam)
				made = true

	# 3) Fallback
	if not made:
		_make_bounds(play_rect)

## ---------- คำนวณกรอบจาก TileMap/TileMapLayer ----------
func _rect_from_tilemap(n: Node) -> Rect2:
	# รองรับ TileMapLayer
	if n is TileMapLayer:
		var layer: TileMapLayer = n as TileMapLayer
		var used: Rect2i = layer.used_rect
		if used.size != Vector2i.ZERO:
			var ts: TileSet = layer.tile_set
			if ts != null:
				var cs: Vector2i = ts.tile_size
				var top_left_local: Vector2 = Vector2(used.position) * Vector2(cs)
				var size_local: Vector2 = Vector2(used.size) * Vector2(cs)
				var tl_global: Vector2 = layer.to_global(top_left_local)
				var br_global: Vector2 = layer.to_global(top_left_local + size_local)
				var tl: Vector2 = to_local(tl_global)
				var br: Vector2 = to_local(br_global)
				return Rect2(tl, br - tl)
		return Rect2()

	# รองรับ TileMap
	if n is TileMap:
		var tm: TileMap = n as TileMap
		var used_tm: Rect2i = tm.get_used_rect()
		if used_tm.size != Vector2i.ZERO:
			var cs_tm: Vector2i = tm.tile_set.tile_size
			var tl_local: Vector2
			var br_local: Vector2
			if tm.has_method("map_to_local"):
				tl_local = tm.map_to_local(used_tm.position)
				br_local = tm.map_to_local(used_tm.position + used_tm.size)
			else:
				tl_local = Vector2(used_tm.position) * Vector2(cs_tm)
				br_local = Vector2(used_tm.position + used_tm.size) * Vector2(cs_tm)

			var tl_global_tm: Vector2 = tm.to_global(tl_local)
			var br_global_tm: Vector2 = tm.to_global(br_local)
			var tl_tm: Vector2 = to_local(tl_global_tm)
			var br_tm: Vector2 = to_local(br_global_tm)
			return Rect2(tl_tm, br_tm - tl_tm)

	return Rect2()

## ---------- คำนวณกรอบจาก Camera2D limit ----------
func _rect_from_camera(cam: Camera2D) -> Rect2:
	var has_limits: bool = cam.limit_right > cam.limit_left and cam.limit_bottom > cam.limit_top
	if not has_limits:
		return Rect2()
	var tl_global: Vector2 = Vector2(float(cam.limit_left), float(cam.limit_top))
	var br_global: Vector2 = Vector2(float(cam.limit_right), float(cam.limit_bottom))
	var tl: Vector2 = to_local(tl_global)
	var br: Vector2 = to_local(br_global)
	return Rect2(tl, br - tl)

## ---------- สร้างกำแพงสี่ด้าน ----------
func _make_bounds(rect: Rect2) -> void:
	var pad: float = thickness
	var tl: Vector2 = rect.position
	var br: Vector2 = rect.position + rect.size

	var top: Rect2    = Rect2(Vector2(tl.x, tl.y - pad), Vector2(rect.size.x, pad))
	var bottom: Rect2 = Rect2(Vector2(tl.x, br.y),       Vector2(rect.size.x, pad))
	var left: Rect2   = Rect2(Vector2(tl.x - pad, tl.y), Vector2(pad, rect.size.y))
	var right: Rect2  = Rect2(Vector2(br.x, tl.y),       Vector2(pad, rect.size.y))

	_make_wall_named(WALL_PREFIX + "Top", top)
	_make_wall_named(WALL_PREFIX + "Bottom", bottom)
	_make_wall_named(WALL_PREFIX + "Left", left)
	_make_wall_named(WALL_PREFIX + "Right", right)

func _make_wall_named(name_str: String, r: Rect2) -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = name_str
	add_child(body)

	# Layer = World (2) จากตัวแปร world_layer_bit
	for i in range(1, 33):
		body.set_collision_layer_value(i, false)
	body.set_collision_layer_value(world_layer_bit, true)  # ปกติ = 2

	# ✅ เปิด MASK ให้คุยกับสิ่งที่ต้องชน
	for i in range(1, 33):
		body.set_collision_mask_value(i, false)
	body.set_collision_mask_value(1, true) # Player
	body.set_collision_mask_value(7, true) # Monster
	# ถ้าต้องการให้กระสุนผู้เล่นหยุดที่กำแพงด้วย ให้เปิดอันนี้:
	# body.set_collision_mask_value(6, true) # PlayerAttack
	# ถ้าบอสต้องชนกำแพงด้วย:
	# body.set_collision_mask_value(3, true) # Boss

	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = r.size

	var cs: CollisionShape2D = CollisionShape2D.new()
	cs.shape = shape
	body.add_child(cs)

	body.position = r.position + r.size * 0.5

## ---------- ล้างกำแพงเดิม ----------
func _clear_old_walls() -> void:
	for c in get_children():
		if c is StaticBody2D and String(c.name).begins_with(WALL_PREFIX):
			c.queue_free()
