class_name MicCapture
extends Node

signal pcm_ready(pcm: PackedByteArray)

const TARGET_RATE := 16000
const PACKET_SAMPLES := 320

@export var mic_player_path: NodePath

var _capture: AudioEffectCapture
var _player: AudioStreamPlayer
var _accum := PackedByteArray()
var _running := false

func start() -> bool:
	if AudioServer.get_input_device_list().is_empty():
		return false
	var bus := AudioServer.get_bus_index("Mic")
	_capture = AudioServer.get_bus_effect(bus, 0)
	_player = get_node(mic_player_path) as AudioStreamPlayer
	_player.stream = AudioStreamMicrophone.new()
	_player.bus = "Mic"
	_player.playing = true
	_capture.clear_buffer()
	_accum = PackedByteArray()
	_running = true
	return true

func stop() -> void:
	_running = false
	if _player != null:
		_player.playing = false

func _process(_delta: float) -> void:
	if not _running or _capture == null:
		return
	var frames := _capture.get_frames_available()
	if frames <= 0:
		return
	var buf: PackedVector2Array = _capture.get_buffer(frames)
	var src_rate := int(AudioServer.get_mix_rate())
	_accum.append_array(_resample_to_s16le(buf, src_rate))
	while _accum.size() >= PACKET_SAMPLES * 2:
		var packet := _accum.slice(0, PACKET_SAMPLES * 2)
		_accum = _accum.slice(PACKET_SAMPLES * 2)
		pcm_ready.emit(packet)

func _resample_to_s16le(frames: PackedVector2Array, src_rate: int) -> PackedByteArray:
	var out := PackedByteArray()
	if frames.is_empty():
		return out
	var step := float(src_rate) / float(TARGET_RATE)
	var i := 0.0
	while i < frames.size():
		var idx := int(i)
		if idx >= frames.size():
			idx = frames.size() - 1
		var s: float = (frames[idx].x + frames[idx].y) * 0.5
		var v := int(clampf(s, -1.0, 1.0) * 32767.0)
		out.append(v & 0xff)
		out.append((v >> 8) & 0xff)
		i += step
	return out
