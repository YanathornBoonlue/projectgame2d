# Autoload (Singleton)
extends Node2D

signal ultimate_charges_changed(new_value: int)

# ===== Core stats =====
var score: int = 0
var hp: int = 100
var boss_hp: int = 500
var has_key: bool = false

# ===== UltimateHolyImpact (persist across scenes) =====
var ultimate_charges: int = 0
var ultimate_max_charges: int = 9
var ultimate_damage: int = 250
var ultimate_radius: float = 220.0

# ===== Scene mgmt helpers =====
var _scene_path: String = ""
var _pending_respawn_sfx: bool = false
var _last_respawn_frame: int = -1

# ===== Debug =====
const DEBUG_ULT: bool = false

func _ready() -> void:
	_remember_current_scene()

func _remember_current_scene() -> void:
	var cs: Node = get_tree().current_scene
	if cs != null:
		var path: String = cs.scene_file_path
		if path != "":
			_scene_path = path

func add_score() -> void:
	score += 1

# ===== Ultimate: add / consume / set =====
func add_ultimate_charge(amount: int = 1) -> void:
	var before: int = ultimate_charges
	var new_val: int = clamp(ultimate_charges + amount, 0, ultimate_max_charges)
	if new_val != before:
		ultimate_charges = new_val
		if DEBUG_ULT:
			var cs: Node = get_tree().current_scene
			var cname: String = String(cs.name) if cs != null else "<no-scene>"
			print("[ULT] +", amount, " : ", before, "→", ultimate_charges, " @", cname)
		emit_signal("ultimate_charges_changed", ultimate_charges)

func consume_ultimate() -> bool:
	if ultimate_charges <= 0:
		if DEBUG_ULT:
			print("[ULT] consume FAIL (no charges)")
		return false
	ultimate_charges -= 1
	if DEBUG_ULT:
		var cs: Node = get_tree().current_scene
		var cname: String = String(cs.name) if cs != null else "<no-scene>"
		print("[ULT] -1 -> ", ultimate_charges, " @", cname)
	emit_signal("ultimate_charges_changed", ultimate_charges)
	return true

func set_ultimate_charges(n: int) -> void:
	var v: int = clamp(n, 0, ultimate_max_charges)
	if v != ultimate_charges:
		ultimate_charges = v
		emit_signal("ultimate_charges_changed", ultimate_charges)

# ===== Damage / Respawn / Scene change =====
func damage(dm: int) -> void:
	hp = max(hp - dm, 0)
	AudioManager.get_node("DeathSfx").play()

func _play_respawn_sfx() -> void:
	AudioManager.respawn_sfx.play()

func respawn_player() -> void:
	hp = 100
	_remember_current_scene()
	_pending_respawn_sfx = true
	var tree: SceneTree = get_tree()
	if tree.current_scene != null:
		call_deferred("_reload_current_scene_safe")
	else:
		if _scene_path != "":
			call_deferred("_change_scene_to_file_safe", _scene_path)
		else:
			push_warning("Cannot respawn: no current scene and no cached scene path.")

func _reload_current_scene_safe() -> void:
	var tree: SceneTree = get_tree()
	if tree.current_scene != null:
		tree.reload_current_scene()
	call_deferred("_play_respawn_sfx_once")

func _play_respawn_sfx_once() -> void:
	if not _pending_respawn_sfx:
		return
	_pending_respawn_sfx = false

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

func load_next_level(next_scene: PackedScene) -> void:
	if next_scene and next_scene.resource_path != "":
		_scene_path = next_scene.resource_path
	get_tree().change_scene_to_packed(next_scene)

func go_to_scene_file(path: String) -> void:
	_change_scene_to_file_safe(path)
