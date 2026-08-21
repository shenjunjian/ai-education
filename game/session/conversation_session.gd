class_name ConversationSession
extends Node

signal turns_changed(turns: Array)

var _scene_id := ""
var _persona_id := ""
var _started_at := 0
var _turns: Array = []

func begin(scene_id: String, persona_id: String) -> void:
	_scene_id = scene_id
	_persona_id = persona_id
	_started_at = int(Time.get_unix_time_from_system() * 1000.0)
	_turns = []
	turns_changed.emit(_turns)

func append_turn(role: String, text: String) -> void:
	if role != "user" and role != "npc":
		return
	var cleaned := text.strip_edges()
	if cleaned.is_empty():
		return
	_turns.append({
		"role": role,
		"text": cleaned,
		"at": int(Time.get_unix_time_from_system() * 1000.0),
	})
	turns_changed.emit(_turns)

func get_turns() -> Array:
	return _turns.duplicate(true)

func has_non_empty_turns() -> bool:
	return not _turns.is_empty()

func clear() -> void:
	_turns = []
	_scene_id = ""
	_persona_id = ""
	_started_at = 0
	turns_changed.emit(_turns)

func get_scene_id() -> String:
	return _scene_id

func get_persona_id() -> String:
	return _persona_id

func get_started_at() -> int:
	return _started_at
