extends Area2D

signal collected

func _ready():
	connect("body_entered", _on_body_entered)

func _on_body_entered(body: Area2D) -> void:
	print("Body entered:", body.name)
	if body.name == "Player":
		collected.emit()
		queue_free()
