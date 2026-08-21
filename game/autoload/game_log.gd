extends Node

const LOG_PATH := "user://logs/game.log"

func log_line(message: String) -> void:
	var stamp := Time.get_datetime_string_from_system(false, true)
	var line := "%s %s\n" % [stamp, message]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://logs"))
	var f := FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("GameLog open failed: %s" % FileAccess.get_open_error())
		return
	f.seek_end()
	f.store_string(line)
	f.close()
	print(line.strip_edges())
