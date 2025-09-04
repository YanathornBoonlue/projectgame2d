extends Control

@onready var label: Label = $Label
@onready var bg_tex: TextureRect = $BG if has_node("BG") else null

var _path: String = ""
var _dots: int = 0

func _ready() -> void:
	# เต็มจอ
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if bg_tex:
		bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	# อ่าน path จาก GameManager
	_path = GameManager.pending_scene_path
	if _path == "":
		label.text = "No target scene."
		return

	# ให้ UI วาดขึ้นก่อน (สำคัญมากบนเว็บ)
	label.text = "Loading..."
	await get_tree().process_frame
	await get_tree().process_frame

	# ขอโหลดแบบ threaded (บนเว็บจะ emulate แต่ UI ได้วาด)
	var err: int = ResourceLoader.load_threaded_request(_path)
	if err != OK and err != ERR_BUSY:
		label.text = "Load request failed: %s" % err
		return

	# วนรอ โดยอัปเดตข้อความทุกเฟรม
	var status: int = ResourceLoader.THREAD_LOAD_IN_PROGRESS
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		_dots = (_dots + 1) % 4
		label.text = "Loading" + ".".repeat(_dots)
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(_path)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var ps: PackedScene = ResourceLoader.load_threaded_get(_path) as PackedScene
		if ps:
			GameManager.pending_scene_path = ""
			get_tree().change_scene_to_packed(ps)
		else:
			label.text = "Loaded scene is null."
	else:
		label.text = "Load failed. status=%s" % status
