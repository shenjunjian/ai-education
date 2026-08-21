extends Control

var _records: Array = []

@onready var _list: ItemList = $Center/VBox/ItemList
@onready var _empty: Label = $Center/VBox/EmptyLabel

func _ready() -> void:
	$Center/VBox/BackButton.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	)
	_list.item_selected.connect(_on_item_selected)
	_load_records()

func _load_records() -> void:
	_records = ConversationStore.load_all()
	_list.clear()
	if _records.is_empty():
		_empty.visible = true
		_list.visible = false
		return
	_empty.visible = false
	_list.visible = true
	for rec in _records:
		var title := str(rec.get("title", ""))
		var ended := int(rec.get("ended_at", 0))
		var when := _format_time(ended)
		_list.add_item("%s  %s" % [title, when])

func _format_time(ms: int) -> String:
	var dt := Time.get_datetime_dict_from_unix_time(int(ms / 1000.0))
	return "%04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

func _on_item_selected(index: int) -> void:
	var rec: Dictionary = _records[index]
	HistoryDetail.pending_record = rec
	get_tree().change_scene_to_file("res://ui/history_detail.tscn")
