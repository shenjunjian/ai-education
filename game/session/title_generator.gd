class_name TitleGenerator
extends Node

func generate_title(turns: Array) -> String:
	await get_tree().process_frame
	return fallback_title(turns)

static func fallback_title(turns: Array) -> String:
	for turn in turns:
		if str(turn.get("role", "")) == "user":
			var t := str(turn.get("text", "")).strip_edges()
			if not t.is_empty():
				return _clip20(t)
	var dt := Time.get_datetime_dict_from_system()
	return "对话 %04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

static func _clip20(text: String) -> String:
	if text.length() <= 20:
		return text
	return text.substr(0, 20)
