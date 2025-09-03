extends Control

@onready var score_texture = %Score/ScoreTexture
@onready var score_label   = %Score/ScoreLabel
@onready var hp_label: Label = %Score/HPLabel
@onready var boss_hp_bar: TextureProgressBar = null

var _boss: Node = null
var _hp_tween: Tween = null
var _last_boss_hp: int = -1

func _ready() -> void:
	# หา BossHPBar แบบปลอดภัย (ไม่มี ?:)
	if has_node("%BossHPBar"):
		boss_hp_bar = %BossHPBar
		boss_hp_bar.visible = false
	_find_boss_and_setup()

func _process(_delta: float) -> void:
	score_label.text = "x %d" % GameManager.score
	hp_label.text    = "HP %d" % GameManager.hp

	if not boss_hp_bar:
		return

	if not is_instance_valid(_boss):
		_find_boss_and_setup()

	var current: int = GameManager.boss_hp
	if current != _last_boss_hp:
		_last_boss_hp = current
		_update_boss_bar(current)

# ================= helpers =================

func _find_boss_and_setup() -> void:
	_boss = null
	for n in get_tree().get_nodes_in_group("Boss"):
		_boss = n
		break

	if boss_hp_bar:
		var maxv: int = 0
		if is_instance_valid(_boss):
			var maybe_max = _boss.get("max_hp")
			if typeof(maybe_max) == TYPE_INT or typeof(maybe_max) == TYPE_FLOAT:
				maxv = int(maybe_max)
		if maxv <= 0:
			maxv = max(GameManager.boss_hp, 1)

		boss_hp_bar.min_value = 0
		boss_hp_bar.max_value = maxv

	_last_boss_hp = GameManager.boss_hp
	_update_boss_bar(_last_boss_hp)

func _update_boss_bar(value: int) -> void:
	if not boss_hp_bar:
		return

	var show := value > 0 and boss_hp_bar.max_value > 0
	boss_hp_bar.visible = show
	if not show:
		return

	if is_instance_valid(_hp_tween):
		_hp_tween.kill()
	_hp_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hp_tween.tween_property(boss_hp_bar, "value", clamp(value, 0, int(boss_hp_bar.max_value)), 0.15)
