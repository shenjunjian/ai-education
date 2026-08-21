extends Control

func _ready() -> void:
	$Center/VBox/EnterButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://world/indoor_neutral.tscn")
	)
	$Center/VBox/HistoryButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://ui/history_list.tscn")
	)
	$Center/VBox/QuitButton.pressed.connect(func() -> void:
		get_tree().quit()
	)
