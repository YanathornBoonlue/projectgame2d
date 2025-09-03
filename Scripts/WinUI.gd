extends CanvasLayer

@export var duration: float = 2.5            # รอก่อนเปลี่ยนฉาก
@export var sfx_volume_db: float = -4.0
@export var next_scene: PackedScene          # จะใส่ผ่านโค้ดก็ได้

var image: TextureRect
var sfx: AudioStreamPlayer
var _showing := false

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	_ensure_nodes()

func _ensure_nodes() -> void:
	# สร้าง/อัปเดต TextureRect ชื่อ "Image"
	image = get_node_or_null("Image") as TextureRect
	if image == null:
		image = TextureRect.new()
		image.name = "Image"
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.modulate.a = 0.0
	visible = false

	# สร้าง/อัปเดต AudioStreamPlayer ชื่อ "Sfx" (ไม่ใส่เสียงก็ได้)
	sfx = get_node_or_null("Sfx") as AudioStreamPlayer
	if sfx == null:
		sfx = AudioStreamPlayer.new()
		sfx.name = "Sfx"
		add_child(sfx)
	sfx.volume_db = sfx_volume_db

# ให้เกมอื่นเรียกใส่รูปเองตามที่ต้องการ
func set_image(tex: Texture2D) -> void:
	_ensure_nodes()
	image.texture = tex

func show_you_win(new_next: PackedScene = null) -> void:
	if _showing: return
	_showing = true
	if new_next: next_scene = new_next

	visible = true
	image.modulate.a = 0.0
	if sfx and sfx.stream: sfx.stop(); sfx.play()

	var t := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(image, "modulate:a", 1.0, 0.6)   # เฟดอิน
	await t.finished

	await get_tree().create_timer(duration, true).timeout  # เดินแม้ paused

	# เปลี่ยนฉากไปเมนู
	if next_scene:
		get_tree().call_deferred("change_scene_to_packed", next_scene)
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Scenes/Prefabs/menu.tscn")

	# reset
	image.modulate.a = 0.0
	visible = false
