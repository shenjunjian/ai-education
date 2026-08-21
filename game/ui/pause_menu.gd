extends CanvasLayer

signal resume_pressed
signal exit_scene_pressed

@onready var _interrupt: CheckBox = $Center/Panel/VBox/InterruptCheck
@onready var _anchor: OptionButton = $Center/Panel/VBox/AnchorOption

func _ready() -> void:
	visible = false
	_interrupt.text = "允许打断 NPC 说话"
	_interrupt.button_pressed = AppConfig.is_interrupt_enabled()
	_interrupt.toggled.connect(func(v: bool) -> void:
		AppConfig.set_interrupt_enabled(v)
	)
	_anchor.clear()
	_anchor.add_item("字幕：右上角", 0)
	_anchor.add_item("字幕：底部居中", 1)
	_anchor.select(0 if AppConfig.get_subtitle_anchor() == "top_right" else 1)
	_anchor.item_selected.connect(func(index: int) -> void:
		AppConfig.set_subtitle_anchor("top_right" if index == 0 else "bottom_center")
		var hud := get_tree().get_first_node_in_group("subtitle_hud")
		if hud != null and hud.has_method("_apply_anchor"):
			hud._apply_anchor()
	)
	$Center/Panel/VBox/ResumeButton.pressed.connect(func() -> void:
		resume_pressed.emit()
	)
	$Center/Panel/VBox/ExitButton.pressed.connect(func() -> void:
		exit_scene_pressed.emit()
	)

func show_pause() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func hide_pause() -> void:
	visible = false
