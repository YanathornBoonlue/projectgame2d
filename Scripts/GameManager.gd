# This script is an autoload, that can be accessed from any other script!

extends Node2D

var score : int = 0
var hp :int = 100
var boss_hp: int = 500  # Boss HP starts at 500

# Adds 1 to score variable
func add_score():
	score += 1

# Call this function from anywhere when the player needs to respawn
func respawn_player():
	# Reset the HP to its maximum value
	hp = 100

	# Reload the current scene to restart the level
	get_tree().reload_current_scene()

	# If you don't want to reload the whole scene, you would instead
	# reset the player's position and other states here.

func damage(dm):
	hp -= dm
	#player.death_particles.emitting = true
	AudioManager.get_node("DeathSfx").play()

# Loads next level
func load_next_level(next_scene : PackedScene):
	get_tree().change_scene_to_packed(next_scene)
