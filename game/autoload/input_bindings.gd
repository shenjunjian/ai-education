extends Node

func _ready() -> void:
	_ensure_key("move_forward", KEY_W)
	_ensure_key("move_back", KEY_S)
	_ensure_key("move_left", KEY_A)
	_ensure_key("move_right", KEY_D)
	_ensure_key("toggle_camera", KEY_V)
	_ensure_key("pause_menu", KEY_ESCAPE)
	_ensure_key("release_mouse", KEY_ALT)
	if not InputMap.has_action("interact_click"):
		InputMap.add_action("interact_click")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("interact_click", mouse)

func _ensure_key(action: String, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
