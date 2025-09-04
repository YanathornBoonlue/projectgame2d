extends CanvasLayer

@export var duration: float = 3.0
@export var text: String = "YOU DIED"
@export var text_color: Color = Color(0.85, 0.1, 0.1, 1.0)
@export var outline_color: Color = Color(0, 0, 0, 0.85)
@export var outline_size: int = 10
@export var darkness: float = 0.65
@export var desaturate: float = 0.35
@export var vignette_strength: float = 0.9
@export var vignette_softness: float = 0.35
@export var font_size: int = 120

@export var sfx_path: String = "res://Assets/Sound/FX/dark-souls-you-died-sound-effect_hm5sYFG.mp3"
@export var sfx_volume_db: float = 5

var rect: ColorRect
var label: Label
var _playing: bool = false
var _t_in: Tween
var _t_out: Tween
var _sfx: AudioStreamPlayer

func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	# ฟังการเปลี่ยนซีนผ่าน root: จะยิงทุกครั้งที่ซีนใหม่ถูกเพิ่มเข้า /root
	var root := get_tree().root
	if not root.child_entered_tree.is_connected(_on_root_child_entered):
		root.child_entered_tree.connect(_on_root_child_entered)

func _on_root_child_entered(_node: Node) -> void:
	# ดีเลย์ 1 เฟรมให้ SceneTree เซ็ต current_scene ให้เสร็จ
	call_deferred("_on_scene_switched")

func _on_scene_switched() -> void:
	_cancel_effects()
	_reset_ui()
	_playing = false

func _ready() -> void:
	rect = $ColorRect
	var cc := $CenterContainer
	label = cc.get_node("Label") as Label

	# เต็มจอ + จัดกลาง
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cc.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_font_size_override("font_size", font_size)
	label.text = text

	# Shader
	if rect.material == null or not (rect.material is ShaderMaterial):
		var sh := Shader.new(); sh.code = _shader_code()
		var sm := ShaderMaterial.new(); sm.shader = sh
		rect.material = sm

	_reset_ui()
	 # ---------- SFX: YOU DIED ----------
	_sfx = get_node_or_null("Sfx") as AudioStreamPlayer
	if _sfx == null:
		_sfx = AudioStreamPlayer.new()
		_sfx.bus = "Sfx"      # ถ้าไม่มีบัสชื่อ UI จะเล่นผ่าน Master อัตโนมัติ
		add_child(_sfx)
	_sfx.volume_db = sfx_volume_db
	_sfx.stream = load(sfx_path)

func show_you_died() -> void:
	if _playing:
		return
	_playing = true

	_cancel_effects()
	_update_shader_params(0.0)

	rect.visible = true
	label.text = text
	label.modulate.a = 0.0
	label.scale = Vector2(1.15, 1.15)
	
# ---------- เล่นเสียง YOU DIED ----------
	if _sfx and _sfx.stream:
		_sfx.stop()
		_sfx.play()

# Fade in
	_t_in = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_t_in.tween_method(_set_fade, 0.0, 1.0, 0.6)
	_t_in.parallel().tween_property(label, "modulate:a", 1.0, 0.7)
	_t_in.parallel().tween_property(label, "scale", Vector2.ONE, 0.7)
	await _t_in.finished

	# Pause โลกชั่วคราว แต่ timer เดินต่อ
	var was_paused := get_tree().paused
	get_tree().paused = true
	await get_tree().create_timer(max(duration, 0.0), true).timeout

	# Fade out
	_cancel_effects()
	_t_out = create_tween()
	_t_out.tween_method(_set_fade, 1.0, 0.0, 0.5)
	_t_out.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	await _t_out.finished

	get_tree().paused = was_paused
	rect.visible = false
	_playing = false

	# รีโหลดฉากแบบปลอดภัย
	GameManager.respawn_player.call_deferred()

func _reset_ui() -> void:
	rect.visible = false
	label.modulate.a = 0.0
	label.scale = Vector2.ONE
	_update_shader_params(0.0)

func _cancel_effects() -> void:
	if is_instance_valid(_t_in):  _t_in.kill()
	if is_instance_valid(_t_out): _t_out.kill()

func _update_shader_params(fade: float) -> void:
	var mat := rect.material as ShaderMaterial
	mat.set_shader_parameter("fade", fade)
	mat.set_shader_parameter("darkness", darkness)
	mat.set_shader_parameter("desaturate", desaturate)
	mat.set_shader_parameter("vignette_strength", vignette_strength)
	mat.set_shader_parameter("vignette_softness", vignette_softness)

func _set_fade(v: float) -> void:
	(rect.material as ShaderMaterial).set_shader_parameter("fade", v)

func _shader_code() -> String:
	return """
shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float fade : hint_range(0.0, 1.0) = 0.0;
uniform float darkness : hint_range(0.0, 1.0) = 0.65;
uniform float desaturate : hint_range(0.0, 1.0) = 0.35;
uniform float vignette_strength : hint_range(0.0, 1.5) = 0.9;
uniform float vignette_softness : hint_range(0.05, 1.0) = 0.35;

void fragment() {
	vec4 col = texture(SCREEN_TEXTURE, SCREEN_UV);
	float g = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(col.rgb, vec3(g), desaturate * fade);
	col.rgb *= mix(1.0, 1.0 - darkness, fade);
	float r = length(SCREEN_UV - vec2(0.5)) * 1.414;
	float vig = smoothstep(vignette_strength,
						   max(0.0, vignette_strength - vignette_softness), r);
	col.rgb *= mix(1.0, vig, fade);
	COLOR = vec4(col.rgb, 1.0);
}
"""
