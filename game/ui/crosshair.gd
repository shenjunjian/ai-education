extends Control

func _process(_delta: float) -> void:
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		visible = false
		return
	visible = not players[0].is_third_person()
