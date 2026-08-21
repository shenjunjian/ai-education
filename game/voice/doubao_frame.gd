class_name DoubaoFrame
extends RefCounted

var event: int = -1
var session_id: String = ""
var payload: PackedByteArray = PackedByteArray()
var msg_type: int = 0
var error_code: int = 0
var compression: int = 0

func payload_text() -> String:
	return payload.get_string_from_utf8()
