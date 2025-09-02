# res://autoload/MusicManager.gd
extends Node

# ===== ตั้งค่าเพลงต่อซีน =====
const SCENE_TO_MUSIC := {
	"res://Scenes/Levels/Dungeon_Level1.tscn": "res://Assets/Sound/cave-temple-atmo-orchestral-drone-thriller-9357.mp3",
	"res://Scenes/Levels/Dungeon_Level2.tscn": "res://Assets/Sound/cave-temple-atmo-orchestral-drone-thriller-9357.mp3",
	"res://Scenes/Levels/Dungeon_Level3.tscn": "res://Assets/Sound/Adel, Baron Of Night .mp3",
	"res://Scenes/Prefabs/menu.tscn": "res://Assets/Sound/a-caverna-de-cristal-177055.mp3",
}

# ==== ภายใน ====
var _player: AudioStreamPlayer
var _fade_tween: Tween
var _last_scene_path := ""
var _last_stream_path := ""

func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music"
	add_child(_player)

	set_process(true) # เฝ้าซีน

func _process(_delta: float) -> void:
	var cs := get_tree().current_scene
	var path := cs.scene_file_path if cs else ""
	if path != _last_scene_path:
		_last_scene_path = path
		_update_for_scene(path)

func _update_for_scene(path: String) -> void:
	if not SCENE_TO_MUSIC.has(path):
		return
	
	var music_path = SCENE_TO_MUSIC[path]
	if music_path != _last_stream_path:
		_last_stream_path = music_path
		_play_bgm(music_path)

func _play_bgm(music_path: String) -> void:
	var stream: AudioStream = load(music_path)
	if not stream:
		push_warning("Music file not found: %s" % music_path)
		return

	# บังคับเปิดลูปสำหรับชนิดสตรีมที่รองรับ
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	elif stream.has_method("set_loop"):
		stream.set_loop(true)

	_kill_fade()
	_player.stream = stream
	_player.volume_db = -20.0  # เริ่มเบาๆ
	_player.play()
	_fade_to_db(-8.0, 1.0)     # เฟดเข้า

func _stop_bgm() -> void:
	if not _player.playing: return
	_kill_fade()
	_fade_to_db(-40.0, 0.8, func ():
		_player.stop()
		_last_stream_path = ""
	)

func _fade_to_db(target_db: float, dur: float, on_done: Callable = Callable()) -> void:
	_kill_fade()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_player, "volume_db", target_db, dur)
	if on_done.is_valid():
		_fade_tween.finished.connect(on_done)

func _kill_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null
