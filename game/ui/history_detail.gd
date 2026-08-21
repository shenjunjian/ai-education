class_name HistoryDetail
extends Control

static var pending_record: Dictionary = {}

func _ready() -> void:
	$BackButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://ui/history_list.tscn")
	)
	$Margin/VBox/TitleLabel.text = str(pending_record.get("title", ""))
	var body := ""
	for turn in pending_record.get("turns", []):
		var prefix := "You" if turn["role"] == "user" else "NPC"
		body += "%s: %s\n\n" % [prefix, turn["text"]]
	$Margin/VBox/Scroll/Text.text = body
