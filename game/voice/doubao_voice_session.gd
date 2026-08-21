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
var _last_audio_ms := 0

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
		_peer.close()
		_peer = null
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
		_peer = null
	if _talking and Time.get_ticks_msec() - _last_audio_ms > 2000:
		playback_stalled.emit()
		_talking = false
		talk_state_changed.emit(false)

func _handle_frame(bytes: PackedByteArray) -> void:
	var frame := DoubaoProtocol.decode(bytes)
	if frame.msg_type == DoubaoProtocol.MSG_ERROR:
		GameLog.log_line("ws error code=%s body=%s" % [frame.error_code, frame.payload_text()])
		_want_run = false
		connection_state_changed.emit("disconnected")
		_stop_mic()
		_clear_playback()
		if _peer != null:
			_peer.close()
		_peer = null
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
			if _peer != null:
				_peer.close()
			_peer = null
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

func _handle_media_event(frame: DoubaoFrame) -> void:
	match frame.event:
		DoubaoProtocol.EVENT_ASR_INFO:
			listen_state_changed.emit(true)
			if _interrupt_enabled and _talking:
				$PcmPlayer.stop_and_clear()
				_talking = false
				talk_state_changed.emit(false)
				_peer.put_packet(DoubaoProtocol.encode_json_event(DoubaoProtocol.EVENT_CLIENT_INTERRUPT, _session_id, {}))
		DoubaoProtocol.EVENT_ASR_RESPONSE:
			var parsed: Variant = JSON.parse_string(frame.payload_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				var results: Array = parsed.get("results", [])
				if not results.is_empty():
					var text := str(results[0].get("text", ""))
					var interim := bool(results[0].get("is_interim", true))
					transcript.emit("user", text, not interim)
		DoubaoProtocol.EVENT_ASR_ENDED:
			listen_state_changed.emit(false)
		DoubaoProtocol.EVENT_CHAT_RESPONSE:
			var parsed2: Variant = JSON.parse_string(frame.payload_text())
			var npc_text := ""
			if typeof(parsed2) == TYPE_DICTIONARY:
				npc_text = str(parsed2.get("content", parsed2.get("text", "")))
			transcript.emit("npc", npc_text, false)
		DoubaoProtocol.EVENT_CHAT_ENDED:
			var parsed3: Variant = JSON.parse_string(frame.payload_text())
			var final_text := ""
			if typeof(parsed3) == TYPE_DICTIONARY:
				final_text = str(parsed3.get("content", parsed3.get("text", "")))
			if not final_text.strip_edges().is_empty():
				transcript.emit("npc", final_text, true)
		DoubaoProtocol.EVENT_TTS_RESPONSE:
			_talking = true
			talk_state_changed.emit(true)
			$PcmPlayer.play_pcm_s16le(frame.payload)
			_last_audio_ms = Time.get_ticks_msec()
		DoubaoProtocol.EVENT_TTS_ENDED:
			_talking = false
			talk_state_changed.emit(false)
		_:
			pass

func _start_mic() -> void:
	if not $MicCapture.start():
		connection_state_changed.emit("no_microphone")
		return
	if not $MicCapture.pcm_ready.is_connected(_on_mic_pcm):
		$MicCapture.pcm_ready.connect(_on_mic_pcm)

func _on_mic_pcm(pcm: PackedByteArray) -> void:
	if _peer == null or _peer.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	if not _interrupt_enabled and _talking:
		return
	_peer.put_packet(DoubaoProtocol.encode_audio_event(DoubaoProtocol.EVENT_TASK_REQUEST, _session_id, pcm))

func _stop_mic() -> void:
	if has_node("MicCapture"):
		$MicCapture.stop()

func _clear_playback() -> void:
	if has_node("PcmPlayer"):
		$PcmPlayer.stop_and_clear()

func _make_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()
