extends Node

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		var orch := get_tree().get_first_node_in_group("session_orchestrator")
		if orch != null:
			await orch.end_current_and_save()
		get_tree().quit()
