extends Node

const CREDENTIALS_EXAMPLE := "res://config/credentials.cfg.example"
const CREDENTIALS_USER := "user://credentials.cfg"
const SETTINGS_USER := "user://settings.cfg"
const DEFAULT_APP_KEY := "PlgvMymc7f3tQnJ6"
const DEFAULT_RESOURCE_ID := "volc.speech.dialog"
const DEFAULT_MODEL := "2.2.0.0"
const DEFAULT_CHAT_URL := "https://ark.cn-beijing.volces.com/api/v3/chat/completions"

var _credentials := ConfigFile.new()
var _settings := ConfigFile.new()

func _ready() -> void:
	_ensure_user_credentials()
	var cred_err := _credentials.load(CREDENTIALS_USER)
	if cred_err != OK:
		GameLog.log_line("credentials load failed err=%s" % cred_err)
	var set_err := _settings.load(SETTINGS_USER)
	if set_err != OK:
		_settings.set_value("voice", "interrupt_enabled", true)
		_settings.set_value("hud", "subtitle_anchor", "top_right")
		save_settings()

func credentials_user_path() -> String:
	return CREDENTIALS_USER

func has_voice_credentials() -> bool:
	return not get_voice_app_id().is_empty() and not get_voice_access_key().is_empty()

func get_voice_app_id() -> String:
	return str(_credentials.get_value("volc", "app_id", "")).strip_edges()

func get_voice_access_key() -> String:
	return str(_credentials.get_value("volc", "access_key", "")).strip_edges()

func get_voice_app_key() -> String:
	var v := str(_credentials.get_value("volc", "app_key", DEFAULT_APP_KEY)).strip_edges()
	return DEFAULT_APP_KEY if v.is_empty() else v

func get_voice_resource_id() -> String:
	var v := str(_credentials.get_value("volc", "resource_id", DEFAULT_RESOURCE_ID)).strip_edges()
	return DEFAULT_RESOURCE_ID if v.is_empty() else v

func get_realtime_model() -> String:
	var v := str(_credentials.get_value("volc", "realtime_model", DEFAULT_MODEL)).strip_edges()
	return DEFAULT_MODEL if v.is_empty() else v

func get_ark_api_key() -> String:
	return str(_credentials.get_value("ark", "api_key", "")).strip_edges()

func get_ark_model() -> String:
	return str(_credentials.get_value("ark", "model", "")).strip_edges()

func get_ark_chat_url() -> String:
	var v := str(_credentials.get_value("ark", "chat_url", DEFAULT_CHAT_URL)).strip_edges()
	return DEFAULT_CHAT_URL if v.is_empty() else v

func is_interrupt_enabled() -> bool:
	return bool(_settings.get_value("voice", "interrupt_enabled", true))

func set_interrupt_enabled(enabled: bool) -> void:
	_settings.set_value("voice", "interrupt_enabled", enabled)
	save_settings()

func get_subtitle_anchor() -> String:
	var v := str(_settings.get_value("hud", "subtitle_anchor", "top_right"))
	if v != "bottom_center":
		return "top_right"
	return v

func set_subtitle_anchor(anchor: String) -> void:
	if anchor != "bottom_center":
		anchor = "top_right"
	_settings.set_value("hud", "subtitle_anchor", anchor)
	save_settings()

func save_settings() -> void:
	var err := _settings.save(SETTINGS_USER)
	if err != OK:
		GameLog.log_line("settings save failed err=%s" % err)

func _ensure_user_credentials() -> void:
	if FileAccess.file_exists(CREDENTIALS_USER):
		return
	var src := FileAccess.open(CREDENTIALS_EXAMPLE, FileAccess.READ)
	if src == null:
		GameLog.log_line("missing credentials example")
		return
	var dst := FileAccess.open(CREDENTIALS_USER, FileAccess.WRITE)
	if dst == null:
		GameLog.log_line("cannot create user credentials err=%s" % FileAccess.get_open_error())
		src.close()
		return
	dst.store_string(src.get_as_text())
	src.close()
	dst.close()
