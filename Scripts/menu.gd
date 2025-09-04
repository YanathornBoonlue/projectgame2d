extends Control

@export_file("*.ttf", "*.otf") var ui_font: String = "res://Assets/Fonts/Star Choco.ttf"
@export var title_text: String = "The Blob Adventure"
@export_file("*.tscn") var level1_path: String = "res://Scenes/Levels/Dungeon_Level1.tscn"

@onready var title_lbl: Label  = $CenterContainer/VBoxContainer/Title
@onready var start_btn: Button = $CenterContainer/VBoxContainer/StartButton
@onready var exit_btn:  Button = $CenterContainer/VBoxContainer/ExitButton
@onready var bg_any: Node      = get_node_or_null("Background")  # ถ้ามีพื้นหลังชื่อ Background

func _enter_tree() -> void:
	get_tree().paused = false

func _ready() -> void:
	# ทำพื้นหลังให้เต็มจอและไม่บังเมาส์
	if bg_any is TextureRect:
		var bg: TextureRect = bg_any as TextureRect
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif bg_any is Control:
		(bg_any as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	_center_layout()
	_style_title()
	_style_button(start_btn)
	_style_button(exit_btn)

	# เผื่อยังไม่ได้ connect ใน Editor
	if start_btn != null and not start_btn.pressed.is_connected(_on_start_button_pressed):
		start_btn.pressed.connect(_on_start_button_pressed)
	if exit_btn != null and not exit_btn.pressed.is_connected(_on_exit_button_pressed):
		exit_btn.pressed.connect(_on_exit_button_pressed)

func _on_start_button_pressed() -> void:
	if start_btn: start_btn.disabled = true
	if exit_btn:  exit_btn.disabled  = true
	_show_loading(true)                          # โชว์ “Loading…”
	await get_tree().process_frame               # ให้ UI วาดขึ้นก่อน

	var path: String = level1_path
	var err: int = ResourceLoader.load_threaded_request(path)
	if err != OK and err != ERR_BUSY:
		_show_loading(false)
		if start_btn: start_btn.disabled = false
		if exit_btn:  exit_btn.disabled  = false
		push_error("threaded_request failed: %s" % err)
		return

	var status: int = ResourceLoader.THREAD_LOAD_IN_PROGRESS
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame           # ปล่อยเฟรมให้ UI ไม่ค้าง
		status = ResourceLoader.load_threaded_get_status(path)

	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var ps: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
		_show_loading(false)
		if ps != null:
			get_tree().change_scene_to_packed(ps)
		else:
			if start_btn: start_btn.disabled = false
			if exit_btn:  exit_btn.disabled  = false
			push_error("load_threaded_get returned null for %s" % path)
	else:
		_show_loading(false)
		if start_btn: start_btn.disabled = false
		if exit_btn:  exit_btn.disabled  = false
		push_error("Failed threaded load, status=%s" % status)

func _on_exit_button_pressed() -> void:
	get_tree().quit()

# ---------- STYLE ----------
func _style_title() -> void:
	var f: FontFile = load(ui_font)
	if f != null:
		title_lbl.add_theme_font_override("font", f)
	title_lbl.add_theme_font_size_override("font_size", 96)
	title_lbl.add_theme_color_override("font_color", Color8(255, 212, 120))
	title_lbl.add_theme_color_override("font_outline_color", Color8(0,0,0,220))
	title_lbl.add_theme_constant_override("outline_size", 12)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.text = title_text

func _style_button(b: Button) -> void:
	if b == null: return
	b.disabled = false
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(360, 96)
	b.text = b.text.capitalize()

	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(0,0,0,0.55)
	normal.set_corner_radius_all(18)
	normal.set_border_width_all(2)
	normal.border_color = Color(1,1,1,0.12)
	normal.shadow_size = 8
	normal.shadow_color = Color(0,0,0,0.45)
	normal.content_margin_left = 24.0
	normal.content_margin_right = 24.0
	normal.content_margin_top = 16.0
	normal.content_margin_bottom = 16.0

	var hover: StyleBoxFlat = (normal.duplicate() as StyleBoxFlat)
	hover.bg_color = Color(0.12,0.12,0.12,0.65)
	hover.border_color = Color(1.0, 0.72, 0.25, 0.7)

	var pressed: StyleBoxFlat = (normal.duplicate() as StyleBoxFlat)
	pressed.bg_color = Color(0.06,0.06,0.06,0.8)
	pressed.shadow_size = 2
	pressed.border_color = Color(1.0, 0.5, 0.15, 0.9)

	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover",  hover)
	b.add_theme_stylebox_override("pressed", pressed)

# ---------- LAYOUT ----------
func _center_layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	title_lbl.anchor_left = 0.5
	title_lbl.anchor_right = 0.5
	title_lbl.anchor_top = 0.12
	title_lbl.anchor_bottom = 0.12
	title_lbl.position = Vector2.ZERO
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	for i in [start_btn, exit_btn]:
		if i == null: continue
		i.anchor_left = 0.5
		i.anchor_right = 0.5
		i.position.x = -i.custom_minimum_size.x * 0.5

	start_btn.anchor_top = 0.45
	start_btn.anchor_bottom = 0.45
	exit_btn.anchor_top = 0.60
	exit_btn.anchor_bottom = 0.60

# ---------- LOADING OVERLAY ----------
func _show_loading(show: bool) -> void:
	var node: Control = get_node_or_null("LoadingOverlay") as Control
	if show:
		if node == null:
			var rect: ColorRect = ColorRect.new()
			rect.name = "LoadingOverlay"
			rect.color = Color(0,0,0,0.6)
			rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var lbl: Label = Label.new()
			lbl.name = "Label"
			lbl.text = "Loading..."
			lbl.add_theme_font_size_override("font_size", 48)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

			rect.add_child(lbl)
			add_child(rect)
	else:
		if node != null:
			node.queue_free()
			
