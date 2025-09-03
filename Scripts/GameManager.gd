# Autoload (Singleton)
extends Node2D

var score: int = 0
var hp: int = 100
var boss_hp: int = 500
var has_key: bool = false

# สำรองพาธของซีนล่าสุดที่รู้จัก
var _scene_path: String = ""

var _pending_respawn_sfx := false
var _last_respawn_frame := -1

func _ready() -> void:
	_remember_current_scene()


func _remember_current_scene() -> void:
	# บันทึกพาธของซีนปัจจุบัน ถ้ามี
	var cs := get_tree().current_scene
	if cs and cs.scene_file_path != "":
		_scene_path = cs.scene_file_path


func add_score() -> void:
	score += 1

func _play_respawn_sfx():
	AudioManager.respawn_sfx.play()

func respawn_player() -> void:
	hp = 100
	var tree := get_tree()

	# จำพาธล่าสุดก่อน
	_remember_current_scene()

	# จะให้เล่นเสียงหลังรีโหลดเสร็จเพียงครั้งเดียว
	_pending_respawn_sfx = true

	# เปลี่ยน/รีโหลดซีนแบบ deferred ให้พ้นช่วง flush
	if tree.current_scene:
		call_deferred("_reload_current_scene_safe")
	else:
		if _scene_path != "":
			call_deferred("_change_scene_to_file_safe", _scene_path)
		else:
			push_warning("Cannot respawn: no current scene and no cached scene path.")

func _reload_current_scene_safe() -> void:
	var tree := get_tree()
	if tree.current_scene:
		tree.reload_current_scene()
	# เล่นเสียงหลังจากรีโหลด (deferred อีกชั้นเพื่อให้ซีน set เสร็จ)
	call_deferred("_play_respawn_sfx_once")

func _play_respawn_sfx_once() -> void:
	if not _pending_respawn_sfx:
		return
	_pending_respawn_sfx = false

	# ป้องกัน edge case ที่ callback ถูกเรียกซ้ำในเฟรมเดียวกัน
	var cur_frame := Engine.get_frames_drawn()
	if cur_frame == _last_respawn_frame:
		return
	_last_respawn_frame = cur_frame

	if is_instance_valid(AudioManager) and AudioManager.respawn_sfx:
		AudioManager.respawn_sfx.stop()  # กัน overlap
		AudioManager.respawn_sfx.play()


func _change_scene_to_file_safe(path: String) -> void:
	if path == "":
		return
	_scene_path = path
	get_tree().change_scene_to_file(path)


func damage(dm: int) -> void:
	hp = max(hp - dm, 0)
	AudioManager.get_node("DeathSfx").play()


# ใช้ฟังก์ชันห่อเหล่านี้เมื่ออยากไปฉากถัดไป/ฉากใดๆ
func load_next_level(next_scene: PackedScene) -> void:
	# ถ้าเป็นไฟล์ในดิสก์ จะมี resource_path ให้จำไว้
	if next_scene and next_scene.resource_path != "":
		_scene_path = next_scene.resource_path
	get_tree().change_scene_to_packed(next_scene)


func go_to_scene_file(path: String) -> void:
	_change_scene_to_file_safe(path)
