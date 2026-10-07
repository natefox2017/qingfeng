extends RefCounted
## Session-scoped command receipt journal for deterministic domain commands.
## It owns request identity/idempotency only; domain handlers own business state.

const PROTOCOL_VERSION := 1
const MAX_ID_LENGTH := 128

var _receipts: Dictionary = {}

static func _failure(command_id: String, code: String, retryable := false) -> Dictionary:
	return {
		"protocol_version": PROTOCOL_VERSION,
		"command_id": command_id,
		"ok": false,
		"error_code": code,
		"is_retryable": retryable,
		"has_changes": false,
		"revision": 0,
		"event_ids": []
	}

static func _valid_text_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= MAX_ID_LENGTH

static func _valid_command(command: Variant) -> bool:
	if not command is Dictionary:
		return false
	var required := ["protocol_version","command_id","session_id","actor_id","action","expected_revision","payload"]
	if command.size() != required.size():
		return false
	for key: String in required:
		if not command.has(key):
			return false
	if command.protocol_version != PROTOCOL_VERSION:
		return false
	for key: String in ["command_id","session_id","actor_id","action"]:
		if not _valid_text_id(command[key]):
			return false
	if not command.expected_revision is int or command.expected_revision < 0:
		return false
	return command.payload is Dictionary

static func _canonical(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)

static func _fingerprint(command: Dictionary) -> String:
	return _canonical({
		"protocol_version": command.protocol_version,
		"session_id": command.session_id,
		"actor_id": command.actor_id,
		"action": command.action,
		"expected_revision": command.expected_revision,
		"payload": command.payload
	}).sha256_text()

static func _valid_result(result: Variant, command_id: String) -> bool:
	if not result is Dictionary:
		return false
	var required := ["protocol_version","command_id","ok","error_code","is_retryable","has_changes","revision","event_ids"]
	if result.size() != required.size():
		return false
	for key: String in required:
		if not result.has(key):
			return false
	if result.protocol_version != PROTOCOL_VERSION or result.command_id != command_id:
		return false
	if not result.ok is bool or not result.error_code is String:
		return false
	if not result.is_retryable is bool or not result.has_changes is bool:
		return false
	if not result.revision is int or result.revision < 0:
		return false
	if not result.event_ids is Array:
		return false
	for event_id: Variant in result.event_ids:
		if not _valid_text_id(event_id):
			return false
	if result.ok:
		return result.error_code.is_empty()
	return not result.error_code.is_empty() and not result.has_changes and result.event_ids.is_empty()

func execute(command: Variant, handler: Callable) -> Dictionary:
	var command_id := ""
	if command is Dictionary and command.get("command_id") is String:
		command_id = command.command_id
	if not _valid_command(command):
		return _failure(command_id, "COMMAND_INVALID")
	var fingerprint := _fingerprint(command)
	if _receipts.has(command.command_id):
		var stored: Dictionary = _receipts[command.command_id]
		if stored.fingerprint != fingerprint:
			return _failure(command.command_id, "COMMAND_ID_CONFLICT")
		return stored.result.duplicate(true)
	if not handler.is_valid():
		return _failure(command.command_id, "COMMAND_HANDLER_INVALID")
	var result: Variant = handler.call(command.duplicate(true))
	if not _valid_result(result, command.command_id):
		return _failure(command.command_id, "COMMAND_RESULT_INVALID")
	_receipts[command.command_id] = {
		"fingerprint": fingerprint,
		"result": result.duplicate(true)
	}
	return result.duplicate(true)

func receipt_count() -> int:
	return _receipts.size()

func clear() -> void:
	_receipts.clear()
