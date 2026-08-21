extends CanvasLayer

const MSG_NO_CREDENTIALS := "请在本机配置中填写火山引擎凭证（user://credentials.cfg）"
const MSG_DISCONNECTED := "连接断开"
const MSG_NO_MICROPHONE := "需要麦克风权限或可用的麦克风设备"
const MSG_UNSAVED := "未保存"

@onready var _label: Label = $Root/HBox/Message
@onready var _retry: Button = $Root/HBox/RetryButton

func _ready() -> void:
	add_to_group("status_banner")
	visible = false
	_retry.text = "重试"
	_retry.visible = false

func show_message(text: String, show_retry: bool = false) -> void:
	_label.text = text
	_retry.visible = show_retry
	visible = not text.is_empty()

func hide_banner() -> void:
	visible = false
	_label.text = ""
	_retry.visible = false

func get_retry_button() -> Button:
	return _retry
