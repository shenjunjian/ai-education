class_name PcmPlayer
extends Node

@export var player_path: NodePath

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _active := false

func _ready() -> void:
	_player = get_node(player_path) as AudioStreamPlayer
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 24000
	gen.buffer_length = 0.3
	_player.stream = gen

func play_pcm_s16le(pcm: PackedByteArray) -> void:
	if not _player.playing:
		_player.play()
		_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback
	_active = true
	var frames := PackedVector2Array()
	var i := 0
	while i + 1 < pcm.size():
		var lo := pcm[i]
		var hi := pcm[i + 1]
		var u := lo | (hi << 8)
		if u >= 32768:
			u -= 65536
		var f := float(u) / 32768.0
		frames.append(Vector2(f, f))
		i += 2
	if _playback != null:
		_playback.push_buffer(frames)

func stop_and_clear() -> void:
	_active = false
	if _playback != null:
		_playback.clear_buffer()
	if _player != null:
		_player.stop()

func is_playing_voice() -> bool:
	return _active and _player != null and _player.playing
