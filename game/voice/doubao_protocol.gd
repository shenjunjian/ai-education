class_name DoubaoProtocol
extends RefCounted

const EVENT_START_CONNECTION := 1
const EVENT_FINISH_CONNECTION := 2
const EVENT_START_SESSION := 100
const EVENT_FINISH_SESSION := 102
const EVENT_TASK_REQUEST := 200
const EVENT_CLIENT_INTERRUPT := 515
const EVENT_CONNECTION_STARTED := 50
const EVENT_CONNECTION_FAILED := 51
const EVENT_SESSION_STARTED := 150
const EVENT_SESSION_FAILED := 153
const EVENT_TTS_SENTENCE_START := 350
const EVENT_TTS_RESPONSE := 352
const EVENT_TTS_ENDED := 359
const EVENT_ASR_INFO := 450
const EVENT_ASR_RESPONSE := 451
const EVENT_ASR_ENDED := 459
const EVENT_CHAT_RESPONSE := 550
const EVENT_CHAT_ENDED := 559
const EVENT_DIALOG_ERROR := 599

const MSG_FULL_CLIENT := 0x10
const MSG_AUDIO_CLIENT := 0x20
const MSG_FULL_SERVER := 0x90
const MSG_AUDIO_SERVER := 0xB0
const MSG_ERROR := 0xF0
const FLAG_EVENT := 0x04
const SERIAL_JSON := 0x10
const SERIAL_RAW := 0x00
const COMPRESS_NONE := 0x00
const COMPRESS_GZIP := 0x01

static func encode_json_event(event: int, session_id: String, payload: Dictionary) -> PackedByteArray:
	var body := JSON.stringify(payload)
	if body.is_empty():
		body = "{}"
	return _encode(MSG_FULL_CLIENT, SERIAL_JSON, event, session_id, body.to_utf8_buffer())

static func encode_audio_event(event: int, session_id: String, pcm: PackedByteArray) -> PackedByteArray:
	return _encode(MSG_AUDIO_CLIENT, SERIAL_RAW, event, session_id, pcm)

static func _encode(msg_type: int, serial: int, event: int, session_id: String, payload: PackedByteArray) -> PackedByteArray:
	var out := PackedByteArray()
	out.append(0x11)
	out.append(msg_type | FLAG_EVENT)
	out.append(serial | COMPRESS_NONE)
	out.append(0x00)
	_append_u32_be(out, event)
	if event != 1 and event != 2 and event != 50 and event != 51 and event != 52:
		var sid := session_id.to_utf8_buffer()
		_append_u32_be(out, sid.size())
		out.append_array(sid)
	_append_u32_be(out, payload.size())
	out.append_array(payload)
	return out

static func decode(frame: PackedByteArray) -> DoubaoFrame:
	var result := DoubaoFrame.new()
	if frame.size() < 4:
		return result
	var offset := 4 * (frame[0] & 0x0f)
	if offset < 4:
		offset = 4
	result.msg_type = frame[1] & 0xf0
	var flags := frame[1] & 0x0f
	result.compression = frame[2] & 0x0f
	if result.msg_type == MSG_ERROR:
		if frame.size() < offset + 4:
			return result
		result.error_code = _read_u32_be(frame, offset)
		offset += 4
	var has_seq := (flags & 0x01) == 0x01
	if has_seq and (result.msg_type == MSG_AUDIO_CLIENT or result.msg_type == MSG_AUDIO_SERVER):
		offset += 4
	if (flags & FLAG_EVENT) == FLAG_EVENT:
		if frame.size() < offset + 4:
			return result
		result.event = _read_s32_be(frame, offset)
		offset += 4
	if result.event != 1 and result.event != 2 and result.event != 50 and result.event != 51 and result.event != 52:
		if frame.size() < offset + 4:
			return result
		var sid_len := _read_u32_be(frame, offset)
		offset += 4
		if sid_len > 0:
			if frame.size() < offset + sid_len:
				return result
			result.session_id = frame.slice(offset, offset + sid_len).get_string_from_utf8()
			offset += sid_len
	if result.event == 50 or result.event == 51 or result.event == 52:
		if frame.size() < offset + 4:
			return result
		var cid_len := _read_u32_be(frame, offset)
		offset += 4
		offset += cid_len
	if frame.size() < offset + 4:
		return result
	var plen := _read_u32_be(frame, offset)
	offset += 4
	if frame.size() < offset + plen:
		return result
	var raw := frame.slice(offset, offset + plen)
	if result.compression == COMPRESS_GZIP:
		var buf_size: int = maxi(256, raw.size() * 16)
		var dec := Compression.decompress(raw, buf_size, Compression.MODE_GZIP)
		if dec.is_empty():
			GameLog.log_line("gzip payload decompress failed")
			result.payload = PackedByteArray()
		else:
			result.payload = dec
	else:
		result.payload = raw
	return result

static func _append_u32_be(buf: PackedByteArray, value: int) -> void:
	buf.append((value >> 24) & 0xff)
	buf.append((value >> 16) & 0xff)
	buf.append((value >> 8) & 0xff)
	buf.append(value & 0xff)

static func _read_u32_be(buf: PackedByteArray, offset: int) -> int:
	return (buf[offset] << 24) | (buf[offset + 1] << 16) | (buf[offset + 2] << 8) | buf[offset + 3]

static func _read_s32_be(buf: PackedByteArray, offset: int) -> int:
	var u := _read_u32_be(buf, offset)
	if u >= 0x80000000:
		return u - 0x100000000
	return u
