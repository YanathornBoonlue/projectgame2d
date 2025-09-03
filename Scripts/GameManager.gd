# Autoload (Singleton)
extends Node2D

signal ultimate_charges_changed(new_value: int)

var score: int = 0
var hp: int = 100
var boss_hp: int = 500
var has_key: bool = false

# ==== UltimateHolyImpact ====
var ultimate_charges: int = 0
var ultimate_max_charges: int = 9
var ultimate_damage: int = 250
var ultimate_radius: float = 220.0

# สำรองพาธของซีนล่าสุดที่รู้จัก
var _scene_path: String = ""

var _pending_respawn_sfx: bool = false
var _last_respawn_frame: int = -1

func _ready() -> void:
	_remember_current_scene()

func _remember_current_scene() -> void:
	# บันทึกพาธของซีนปัจจุบัน ถ้ามี
	var cs: Node = get_tree().current_scene
	if cs and cs.scene_file_path != "":
		_scene_path = cs.scene_file_path

func add_score() -> void:
	score += 1

# ==== Ultimate helpers ====
func add_ultimate_charge(amount: int = 1) -> void:
	var before: int = ultimate_charges
	ultimate_charges = clamp(ultimate_charges + amount, 0, ultimate_max_charges)
	if ultimate_charges != before:
		emit_signal("ultimate_charges_changed", ultimate_charges)

func consume_ultimate() -> bool:
	if ultimate_charges <= 0:
		return false
	ultimate_charges -= 1
	emit_signal("ultimate_charges_changed", ultimate_charges)
	return true

func set_ultimate_charges(n: int) -> void:
	var v: int = clamp(n, 0, ultimate_max_charges)
	if v != ultimate_charges:
		ultimate_charges = v
		emit_signal("ultimate_charges_changed", ultimate_charges)
# ==========================

func _play_respawn_sfx() -> void:
	AudioManager.respawn_sfx.play()

func respawn_player() -> void:
	hp = 100
	var tree: SceneTree = get_tree()

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
	var tree: SceneTree = get_tree()
	if tree.current_scene:
		tree.reload_current_scene()
	# เล่นเสียงหลังจากรีโหลด (deferred อีกชั้นเพื่อให้ซีน set เสร็จ)
	call_deferred("_play_respawn_sfx_once")

func _play_respawn_sfx_once() -> void:
	if not _pending_respawn_sfx:
		return
	_pending_respawn_sfx = false

	# ป้องกัน edge case ที่ callback ถูกเรียกซ้ำในเฟรมเดียวกัน
	var cur_frame: int = Engine.get_frames_drawn()
	if cur_frame == _last_respawn_frame:
		return
	_last_respawn_frame = cur_frame

	if is_instance_valid(AudioManager) and AudioManager.respawn_sfx:
		AudioManager.respawn_sfx.stop()
		AudioManager.respawn_sfx.play()

func _change_scene_to_file_safe(path: String) -> void:
	if path == "":
		return
	_scene_path = path
	get_tree().change_scene_to_file(path)

func damage(dm: int) -> void:
	hp = max(hp - dm, 0)
	AudioManager.get_node("DeathSfx").play()

func load_next_level(next_scene: PackedScene) -> void:
	# ถ้าเป็นไฟล์ในดิสก์ จะมี resource_path ให้จำไว้
	if next_scene and next_scene.resource_path != "":
		_scene_path = next_scene.resource_path
	get_tree().change_scene_to_packed(next_scene)

func go_to_scene_file(path: String) -> void:
	_change_scene_to_file_safe(path)
