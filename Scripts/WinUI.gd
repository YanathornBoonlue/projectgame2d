extends CanvasLayer

@export var duration: float = 6.0                    # แสดง WinUI นานกี่วิ
@export var sfx_stream: AudioStream                  # ใส่เสียงชนะเกม (ออปชัน)
@export var sfx_volume_db: float = -4.0
@export var next_scene: PackedScene                  # เมนู หรือฉากที่อยากไปต่อ

var image: TextureRect
var _showing: bool = false
var _oneshot: AudioStreamPlayer = null

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 999                                      # อยู่บนสุด
	_ensure_nodes()

func _ensure_nodes() -> void:
	image = get_node_or_null("Image") as TextureRect
	if image == null:
		image = TextureRect.new()
		image.name = "Image"
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.modulate = Color(1, 1, 1, 0)
	visible = false

# ให้เกมเรียกเปลี่ยนภาพเอง
func set_image(tex: Texture2D) -> void:
	_ensure_nodes()
	image.texture = tex

func show_you_win(new_next: PackedScene = null) -> void:
	if _showing:
		return
	_showing = true
	if new_next != null:
		next_scene = new_next

	# 1) หยุด BGM ของด่านทันที (พยายามเรียก MusicManager ก่อน ถ้าไม่มีค่อยลด bus)
	_stop_stage_bgm()

	# 2) เล่น SFX (one-shot object จะถูกลบทิ้งเอง)
	_play_oneshot()

	# 3) เฟดอินรูป + ค้างไว้
	visible = true
	image.modulate.a = 0.0

	var t_in: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t_in.tween_property(image, "modulate:a", 1.0, 0.6)
	await t_in.finished

	# ค้างไว้ตาม duration (แม้เกม paused ก็เดิน)
	await get_tree().create_timer(duration, true).timeout

	# 4) เฟดเอาต์
	var t_out: Tween = create_tween()
	t_out.tween_property(image, "modulate:a", 0.0, 0.4)
	await t_out.finished

	# 5) เปลี่ยนฉาก แล้วเคลียร์เสียง one-shot
	_cleanup_oneshot()
	visible = false
	_showing = false

	if next_scene != null:
		get_tree().change_scene_to_packed(next_scene)
	else:
		get_tree().change_scene_to_file("res://Scenes/Prefabs/menu.tscn")
	# หมายเหตุ: ไม่ต้องเรียก show_you_win อีกที่เมนู จะไม่เล่นซ้ำเพราะ _showing ป้องกันแล้ว
	# และเรา kill one-shot ไปแล้วจึงไม่มีเสียงค้าง/เล่นซ้ำ
	

# -------------------- audio helpers --------------------

func _play_oneshot() -> void:
	_cleanup_oneshot()  # กันกรณีคาเดิม
	if sfx_stream == null:
		return
	var p := AudioStreamPlayer.new()
	_oneshot = p
	p.bus = "SFX"
	p.stream = sfx_stream
	p.volume_db = sfx_volume_db
	add_child(p)
	p.play()

func _cleanup_oneshot() -> void:
	if _oneshot != null and is_instance_valid(_oneshot):
		_oneshot.stop()
		_oneshot.queue_free()
	_oneshot = null

func _stop_stage_bgm() -> void:
	# ถ้ามี MusicManager (autoload ก่อนหน้า) ให้สั่งเฟดและหยุด
	var mm := get_node_or_null("/root/MusicManager")
	if mm != null:
		if mm.has_method("fade_out_and_stop"):
			mm.call("fade_out_and_stop", 0.6)
			return
		if mm.has_method("_stop_bgm"):
			mm.call("_stop_bgm")
			return
	# ถ้าไม่มี MusicManager: ลด volume ที่ bus "Music" ลงชั่วคราว
	var idx: int = AudioServer.get_bus_index("Music")
	if idx >= 0:
		var from_db: float = AudioServer.get_bus_volume_db(idx)
		var tw: Tween = create_tween()
		tw.tween_method(
			func(v: float) -> void: AudioServer.set_bus_volume_db(idx, v),
			from_db, -40.0, 0.6
		)
