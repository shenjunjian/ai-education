class_name VoiceSession
extends Node

signal transcript(role: String, text: String, is_final: bool)
signal listen_state_changed(is_listening: bool)
signal talk_state_changed(is_talking: bool)
signal connection_state_changed(state: String)
signal playback_stalled()

var _last_persona: PersonaResource

func start(persona: PersonaResource) -> void:
	_last_persona = persona

func stop() -> void:
	pass

func retry() -> void:
	if _last_persona != null:
		start(_last_persona)

func set_interrupt_enabled(_enabled: bool) -> void:
	pass
