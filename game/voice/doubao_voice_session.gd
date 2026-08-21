class_name DoubaoVoiceSession
extends VoiceSession

const WS_URL := "wss://openspeech.bytedance.com/api/v3/realtime/dialogue"

var _peer: WebSocketPeer
var _session_id := ""
var _active_persona: PersonaResource
var _interrupt_enabled := true
var _talking := false
var _want_run := false
var _handshake_stage := 0

func set_interrupt_enabled(enabled: bool) -> void:
	_interrupt_enabled = enabled

func start(persona: PersonaResource) -> void:
	_handshake_stage = 0
	stop()
	_last_persona = persona
	_active_persona = persona
	if not AppConfig.has_voice_credentials():
		connection_state_changed.emit("no_credentials")
		return
	_want_run = true
	_session_id = _make_id()
	_peer = WebSocketPeer.new()
	_peer.handshake_headers = PackedStringArray([
		"X-Api-App-ID: %s" % AppConfig.get_voice_app_id(),
		"X-Api-Access-Key: %s" % AppConfig.get_voice_access_key(),
		"X-Api-Resource-Id: %s" % AppConfig.get_voice_resource_id(),
		"X-Api-App-Key: %s" % AppConfig.get_voice_app_key(),
		"X-Api-Connect-Id: %s" % _make_id(),
	])
	connection_state_changed.emit("connecting")
	var err := _peer.connect_to_url(WS_URL)
	if err != OK:
		GameLog.log_line("ws connect err=%s" % err)
		connection_state_changed.emit("disconnected")
		_want_run = false

func stop() -> void:
	_want_run = false
	_stop_mic()
	_clear_playback()
	_talking = false
	talk_state_changed.emit(false)
	listen_state_changed.emit(false)
	if _peer != null:
		if _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
			_peer.put_packet(DoubaoProtocol.encode_json_event(DoubaoProtocol.EVENT_FINISH_SESSION, _session_id, {}))
			_peer.put_packet(DoubaoProtocol.encode_json_event(DoubaoProtocol.EVENT_FINISH_CONNECTION, "", {}))
		_peer.close()
	_peer = null

func retry() -> void:
	if _last_persona != null:
		start(_last_persona)

func _process(_delta: float) -> void:
	if _peer == null:
		return
	_peer.poll()
	var state := _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if _handshake_stage == 0:
			_peer.put_packet(DoubaoProtocol.encode_json_event(DoubaoProtocol.EVENT_START_CONNECTION, "", {}))
			_handshake_stage = 1
		while _peer.get_available_packet_count() > 0:
			_handle_frame(_peer.get_packet())
	elif state == WebSocketPeer.STATE_CLOSED and _want_run:
		_want_run = false
		_stop_mic()
		_clear_playback()
		connection_state_changed.emit("disconnected")
		GameLog.log_line("ws closed code=%s" % _peer.get_close_code())

func _handle_frame(bytes: PackedByteArray) -> void:
	var frame := DoubaoProtocol.decode(bytes)
	if frame.msg_type == DoubaoProtocol.MSG_ERROR:
		GameLog.log_line("ws error code=%s body=%s" % [frame.error_code, frame.payload_text()])
		_want_run = false
		connection_state_changed.emit("disconnected")
		_stop_mic()
		_clear_playback()
		return
	match frame.event:
		DoubaoProtocol.EVENT_CONNECTION_STARTED:
			var payload := _start_session_payload()
			_peer.put_packet(DoubaoProtocol.encode_json_event(DoubaoProtocol.EVENT_START_SESSION, _session_id, payload))
		DoubaoProtocol.EVENT_SESSION_STARTED:
			connection_state_changed.emit("connected")
			_start_mic()
		DoubaoProtocol.EVENT_CONNECTION_FAILED, DoubaoProtocol.EVENT_SESSION_FAILED, DoubaoProtocol.EVENT_DIALOG_ERROR:
			GameLog.log_line("dialog error event=%s body=%s code=%s" % [frame.event, frame.payload_text(), frame.error_code])
			_want_run = false
			connection_state_changed.emit("disconnected")
			_stop_mic()
			_clear_playback()
		_:
			_handle_media_event(frame)

func _start_session_payload() -> Dictionary:
	return {
		"asr": {
			"audio_info": {"format": "pcm", "sample_rate": 16000, "channel": 1},
			"extra": {"end_smooth_window_ms": 1500},
		},
		"tts": {
			"speaker": _active_persona.voice_id,
			"audio_config": {"format": "pcm_s16le", "sample_rate": 24000, "channel": 1, "bits": 16},
		},
		"dialog": {
			"character_manifest": _active_persona.character_manifest,
			"extra": {"model": AppConfig.get_realtime_model()},
		},
	}

func _handle_media_event(_frame: DoubaoFrame) -> void:
	pass

func _start_mic() -> void:
	pass

func _stop_mic() -> void:
	pass

func _push_pcm(_pcm: PackedByteArray) -> void:
	pass

func _clear_playback() -> void:
	pass

func _make_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()
