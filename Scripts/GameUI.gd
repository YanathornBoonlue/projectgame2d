extends Control

@onready var score_texture = %Score/ScoreTexture
@onready var score_label = %Score/ScoreLabel
@onready var hp_label: Label = %Score/HPLabel
@onready var boss_hp_bar: TextureProgressBar = %BossHPBar if has_node("%BossHPBar") else null # Link to the Boss HP Bar

<<<<<<< HEAD
#func _process(_delta):
	# Set the score label text to the score variable in game maanger script
	#score_label.text = "x %d" % GameManager.score
	#hp_label.text = "HP %d" % GameManager.hp
	#boss_hp_bar.value = GameManager.boss_hp
=======
func _process(_delta):
	## Set the score label text to the score variable in game maanger script
	score_label.text = "x %d" % GameManager.score
	hp_label.text = "HP %d" % GameManager.hp
	if boss_hp_bar:
		boss_hp_bar.value = GameManager.boss_hp
>>>>>>> f016b834d900c63bb5641c398eed055676ea004b
