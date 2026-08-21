class_name TitleGenerator
extends Node

func generate_title(turns: Array) -> String:
	if AppConfig.get_ark_api_key().is_empty() or AppConfig.get_ark_model().is_empty():
		return fallback_title(turns)
	var http := $Http as HTTPRequest
	http.timeout = 8
	var body := JSON.stringify({
		"model": AppConfig.get_ark_model(),
		"stream": false,
		"messages": [
			{"role": "system", "content": "只输出不超过20个汉字的中文标题，不要引号和解释。"},
			{"role": "user", "content": _format_turns(turns)},
		],
	})
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % AppConfig.get_ark_api_key(),
	])
	var err := http.request(AppConfig.get_ark_chat_url(), headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		GameLog.log_line("title http request err=%s" % err)
		return fallback_title(turns)
	var completed: Array = await http.request_completed
	var result: int = completed[0]
	var code: int = completed[1]
	var response_body: PackedByteArray = completed[3]
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		GameLog.log_line("title http failed result=%s code=%s" % [result, code])
		return fallback_title(turns)
	var parsed: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return fallback_title(turns)
	var choices: Array = parsed.get("choices", [])
	if choices.is_empty():
		return fallback_title(turns)
	var content := str(choices[0].get("message", {}).get("content", "")).strip_edges()
	content = content.trim_prefix("“").trim_prefix("\"").trim_suffix("”").trim_suffix("\"")
	if content.is_empty():
		return fallback_title(turns)
	if content.length() > 20:
		content = content.substr(0, 20)
	return content

func _format_turns(turns: Array) -> String:
	var lines: PackedStringArray = []
	for turn in turns:
		lines.append("%s: %s" % [turn["role"], turn["text"]])
	return "\n".join(lines)

static func fallback_title(turns: Array) -> String:
	for turn in turns:
		if str(turn.get("role", "")) == "user":
			var t := str(turn.get("text", "")).strip_edges()
			if not t.is_empty():
				return _clip20(t)
	var dt := Time.get_datetime_dict_from_system()
	return "对话 %04d-%02d-%02d %02d:%02d" % [dt.year, dt.month, dt.day, dt.hour, dt.minute]

static func _clip20(text: String) -> String:
	if text.length() <= 20:
		return text
	return text.substr(0, 20)
