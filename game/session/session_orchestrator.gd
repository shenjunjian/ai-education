class_name SessionOrchestrator
extends Node

signal save_finished(ok: bool)

@export var scene_id: String = "indoor_neutral"

@onready var _lock: TargetLock = get_parent().get_node("TargetLock")
@onready var _session: ConversationSession = get_parent().get_node("ConversationSession")
@onready var _titles: TitleGenerator = get_parent().get_node("TitleGenerator")
@onready var _voice: VoiceSession = get_parent().get_node("VoiceSession")
@onready var _hud: Node = get_parent().get_node("SubtitleHud")
@onready var _pause: Node = get_parent().get_node("PauseMenu")
@onready var _banner: Node = get_parent().get_node("StatusBanner")

var _ending := false
var _listening := false
var _last_failed_record: Dictionary = {}
var _pending_exit_to_menu := false
var _pending_quit := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("session_orchestrator")
	_hud.bind_session(_session)
	_lock.target_changed.connect(_on_target_changed)
	_pause.resume_pressed.connect(func() -> void:
		_clear_pending_exit()
		_pause.hide_pause()
		get_tree().paused = false
	)
	_pause.exit_scene_pressed.connect(_exit_to_menu)
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	_banner.get_retry_button().pressed.connect(_retry_save_or_voice)
	_voice.transcript.connect(func(role: String, text: String, is_final: bool) -> void:
		if is_final:
			_session.append_turn(role, text)
			_hud.clear_live()
		else:
			_hud.show_live(role, text)
	)
	_voice.listen_state_changed.connect(func(on: bool) -> void:
		_listening = on
		var npc := _lock.get_current()
		if npc == null:
			return
		npc.set_voice_phase("listen" if on else "idle")
	)
	_voice.talk_state_changed.connect(func(on: bool) -> void:
		var npc := _lock.get_current()
		if npc == null:
			return
		if on:
			npc.set_voice_phase("talk")
		else:
			npc.set_voice_phase("listen" if _listening else "idle")
	)
	_voice.playback_stalled.connect(func() -> void:
		var npc := _lock.get_current()
		if npc != null:
			npc.set_voice_phase("idle")
	)
	_voice.connection_state_changed.connect(func(state: String) -> void:
		match state:
			"no_credentials":
				_banner.show_message("请在本机配置中填写火山引擎凭证（user://credentials.cfg）", false)
			"no_microphone":
				_banner.show_message("需要麦克风权限或可用的麦克风设备", false)
			"disconnected":
				_banner.show_message("连接断开", true)
			"connected", "connecting":
				if _last_failed_record.is_empty():
					_banner.hide_banner()
	)
	if _lock.get_current() != null:
		_start_for(_lock.get_current())

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_menu"):
		if _pause.visible:
			_clear_pending_exit()
			_pause.hide_pause()
			get_tree().paused = false
		else:
			get_tree().paused = true
			_pause.show_pause()
		get_viewport().set_input_as_handled()

func end_current_and_save() -> bool:
	if _ending:
		return await save_finished
	get_tree().paused = false
	_ending = true
	_voice.stop()
	var ok := true
	if _session.has_non_empty_turns():
		var title: String = await _titles.generate_title(_session.get_turns())
		var rec := {
			"id": _uuid(),
			"title": title,
			"started_at": _session.get_started_at(),
			"ended_at": int(Time.get_unix_time_from_system() * 1000.0),
			"scene_id": _session.get_scene_id(),
			"persona_id": _session.get_persona_id(),
			"turns": _session.get_turns(),
		}
		var path := ConversationStore.save_record(rec)
		if path.is_empty():
			_last_failed_record = rec
			_banner.show_message("未保存", true)
			ok = false
		else:
			_last_failed_record = {}
	if ok:
		_session.clear()
		_hud.clear_live()
	save_finished.emit(ok)
	_ending = false
	return ok

func request_pending_quit() -> void:
	_pending_quit = true

func retry_save() -> void:
	if _last_failed_record.is_empty():
		return
	var path := ConversationStore.save_record(_last_failed_record)
	if path.is_empty():
		_banner.show_message("未保存", true)
	else:
		_last_failed_record = {}
		_banner.hide_banner()
		_session.clear()
		_hud.clear_live()
		_on_save_retry_success()

func _on_save_retry_success() -> void:
	if _pending_exit_to_menu:
		_pending_exit_to_menu = false
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
		return
	if _pending_quit:
		_pending_quit = false
		get_tree().quit()
		return
	var current := _lock.get_current()
	if current != null:
		_start_for(current)

func _clear_pending_exit() -> void:
	_pending_exit_to_menu = false
	_pending_quit = false

func _on_target_changed(previous: NpcActor, current: NpcActor) -> void:
	if previous != null:
		var ok: bool = await end_current_and_save()
		if not ok:
			return
	if current != null:
		_start_for(current)

func _start_for(npc: NpcActor) -> void:
	var persona := npc.get_persona()
	var pid := ""
	if persona != null and persona.is_valid():
		pid = persona.id
	_session.begin(scene_id, pid)
	_hud.bind_session(_session)
	if persona == null or not persona.is_valid():
		GameLog.log_line("persona invalid; not starting voice")
		return
	_voice.set_interrupt_enabled(AppConfig.is_interrupt_enabled())
	_voice.start(persona)

func _exit_to_menu() -> void:
	get_tree().paused = false
	var ok: bool = await end_current_and_save()
	if ok:
		get_tree().change_scene_to_file("res://ui/main_menu.tscn")
	else:
		_pending_exit_to_menu = true
		get_tree().paused = true
		_pause.show_pause()

func _retry_save_or_voice() -> void:
	if not _last_failed_record.is_empty():
		retry_save()
		return
	_voice.retry()

func _exit_tree() -> void:
	_voice.stop()
	if _session.has_non_empty_turns():
		var rec := {
			"id": _uuid(),
			"title": TitleGenerator.fallback_title(_session.get_turns()),
			"started_at": _session.get_started_at(),
			"ended_at": int(Time.get_unix_time_from_system() * 1000.0),
			"scene_id": _session.get_scene_id(),
			"persona_id": _session.get_persona_id(),
			"turns": _session.get_turns(),
		}
		ConversationStore.save_record(rec)
		_session.clear()

func _uuid() -> String:
	var c := Crypto.new()
	var b := c.generate_random_bytes(16)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	var hex := b.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
