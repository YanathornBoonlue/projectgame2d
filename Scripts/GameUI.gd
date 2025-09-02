extends Control

@onready var score_texture = %Score/ScoreTexture
@onready var score_label = %Score/ScoreLabel
@onready var hp_label: Label = %Score/HPLabel
@onready var boss_hp_bar: TextureProgressBar = %BossHPBar   # Link to the Boss HP Bar

#func _process(_delta):
	# Set the score label text to the score variable in game maanger script
	#score_label.text = "x %d" % GameManager.score
	#hp_label.text = "HP %d" % GameManager.hp
	#boss_hp_bar.value = GameManager.boss_hp
