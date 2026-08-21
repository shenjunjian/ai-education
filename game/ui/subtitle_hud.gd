extends CanvasLayer

const MAX_VISIBLE := 8

@onready var _panel: PanelContainer = $Root/Panel
@onready var _list: VBoxContainer = $Root/Panel/Margin/Scroll/List
@onready var _live: Label = $Root/Panel/Margin/Scroll/List/LiveLabel

var _session: ConversationSession

func bind_session(session: ConversationSession) -> void:
	if _session != null and _session.turns_changed.is_connected(_on_turns):
		_session.turns_changed.disconnect(_on_turns)
	_session = session
	_session.turns_changed.connect(_on_turns)
	_on_turns(_session.get_turns())
	_apply_anchor()

func show_live(role: String, text: String) -> void:
	var prefix := "You" if role == "user" else "NPC"
	_live.text = "%s: %s" % [prefix, text]
	_live.visible = not text.strip_edges().is_empty()

func clear_live() -> void:
	_live.text = ""
	_live.visible = false

func _ready() -> void:
	add_to_group("subtitle_hud")
	_apply_anchor()

func _apply_anchor() -> void:
	var root: Control = $Root
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	if AppConfig.get_subtitle_anchor() == "bottom_center":
		_panel.anchor_left = 0.2
		_panel.anchor_right = 0.8
		_panel.anchor_top = 0.72
		_panel.anchor_bottom = 0.98
		_panel.offset_left = 0.0
		_panel.offset_top = 0.0
		_panel.offset_right = 0.0
		_panel.offset_bottom = -16.0
	else:
		_panel.anchor_left = 0.62
		_panel.anchor_right = 0.98
		_panel.anchor_top = 0.04
		_panel.anchor_bottom = 0.42
		_panel.offset_left = 0.0
		_panel.offset_top = 0.0
		_panel.offset_right = 0.0
		_panel.offset_bottom = 0.0

func _on_turns(turns: Array) -> void:
	for child in _list.get_children():
		if child != _live:
			child.queue_free()
	var start := maxi(0, turns.size() - MAX_VISIBLE)
	for i in range(start, turns.size()):
		var turn: Dictionary = turns[i]
		var lab := Label.new()
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var prefix := "You" if turn["role"] == "user" else "NPC"
		lab.text = "%s: %s" % [prefix, turn["text"]]
		_list.add_child(lab)
	_list.move_child(_live, _list.get_child_count() - 1)
