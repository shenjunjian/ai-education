extends Control

func _ready() -> void:
	$Center/VBox/QuitButton.pressed.connect(func() -> void:
		get_tree().quit()
	)
