extends Node

# พิมพ์ชนิด Dictionary ให้ชัดเจน
const SCENE_TO_MUSIC: Dictionary[String, String] = {
	"res://Scenes/Levels/Dungeon_Level1.tscn": "res://Assets/Sound/cave-temple-atmo-orchestral-drone-thriller-9357.mp3",
	"res://Scenes/Levels/Dungeon_Level2.tscn": "res://Assets/Sound/cave-temple-atmo-orchestral-drone-thriller-9357.mp3",
	"res://Scenes/Levels/Dungeon_Level3.tscn": "res://Assets/Sound/Adel, Baron Of Night - Elden Ring Nightreign OST Official Soundtrack Original Score.mp3",
	"res://Scenes/Prefabs/menu.tscn": "res://Assets/Sound/a-caverna-de-cristal-177055.mp3",
}

var _player: AudioStreamPlayer
var _fade_tween: Tween = null
var _last_scene_path: String = ""
var _last_stream_path: String = ""

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	add_child(_player)
	set_process(true)

func _process(_delta: float) -> void:
	var cs: Node = get_tree().current_scene
	if cs == null:
		return
	var path: String = cs.scene_file_path
	if path == "":
		return

	if path != _last_scene_path:
		_last_scene_path = path
		_update_for_scene(path)
	else:
		# ดึงค่าจาก dict แบบ typed (default เป็น "" แทน null)
		var desired: String = SCENE_TO_MUSIC.get(path, "")
		if desired != "" and _last_stream_path == desired and not _player.playing:
			_player.play()

func _update_for_scene(path: String) -> void:
	var music_path: String = SCENE_TO_MUSIC.get(path, "")
	if music_path == "":
		_stop_bgm()
		return

	if music_path != _last_stream_path:
		_last_stream_path = music_path
		_play_bgm(music_path)
	elif not _player.playing:
		_player.play()

func _play_bgm(music_path: String) -> void:
	var stream: AudioStream = load(music_path)
	if stream == null:
		push_warning("Music file not found: %s" % music_path)
		return
	if stream.has_method("set_loop"):
		stream.set_loop(true)

	_kill_fade()
	_player.stream = stream
	_player.volume_db = -20.0
	_player.play()
	_fade_to_db(-8.0, 1.0)

func _stop_bgm() -> void:
	if not _player.playing:
		return
	_kill_fade()
	_fade_to_db(-40.0, 0.8, func ():
		_player.stop()
	)

func _fade_to_db(target_db: float, dur: float, on_done: Callable = Callable()) -> void:
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", target_db, dur)
	if on_done.is_valid():
		_fade_tween.finished.connect(on_done)

func _kill_fade() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null
