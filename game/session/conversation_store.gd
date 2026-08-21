class_name ConversationStore
extends RefCounted

const DIR := "user://conversations"

static func save_record(record: Dictionary) -> String:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var id := str(record.get("id", ""))
	if id.is_empty():
		GameLog.log_line("save_record missing id")
		return ""
	var path := "%s/%s.json" % [DIR, id]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		GameLog.log_line("conversation write failed err=%s" % FileAccess.get_open_error())
		return ""
	f.store_string(JSON.stringify(record, "\t"))
	f.close()
	return path

static func load_all() -> Array:
	var out: Array = []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".json"):
			var rec := load_by_id(name.get_basename())
			if not rec.is_empty():
				out.append(rec)
		name = dir.get_next()
	out.sort_custom(func(a, b) -> bool:
		return int(a.get("ended_at", 0)) > int(b.get("ended_at", 0))
	)
	return out

static func load_by_id(id: String) -> Dictionary:
	var path := "%s/%s.json" % [DIR, id]
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
