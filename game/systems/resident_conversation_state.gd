extends RefCounted
## Transient resident conversation occupancy and lifecycle.
## No inventory, relationship, memory, UI, AI, or persistence ownership here.

const CONTENT = preload("res://content/content_catalog.gd")

var revision := 0
var configuration_error := ""
var _actors: Dictionary = {}
var _conversations: Dictionary = {}
var _occupancy: Dictionary = {}

func _init(content: Dictionary = {}) -> void:
	var source := content
	if source.is_empty():
		var result: Dictionary = CONTENT.load_current()
		if not result.ok:
			configuration_error = result.error_code
			return
		source = result.data
	if not CONTENT.validate(source):
		configuration_error = "CONTENT_INVALID"
		return
	_actors["actor.player"] = true
	for resident_id: Variant in source.residents.definitions:
		_actors[String(resident_id)] = true

func is_configured() -> bool:
	return configuration_error.is_empty()

func projection() -> Dictionary:
	var rows: Array = []
	var ids: Array = _conversations.keys()
	ids.sort()
	for conversation_id: Variant in ids:
		rows.append((_conversations[conversation_id] as Dictionary).duplicate(true))
	return {"revision":revision,"conversations":rows}

func conversation_for_actor(actor_id: String) -> Dictionary:
	if not _occupancy.has(actor_id):
		return {}
	var conversation_id := String(_occupancy[actor_id])
	return (_conversations.get(conversation_id,{}) as Dictionary).duplicate(true)

func invite(conversation_id: String, inviter_id: String, invitee_id: String, space_id: String) -> Dictionary:
	if not is_configured():
		return _failure("CONVERSATION_NOT_CONFIGURED")
	if not _valid_conversation_id(conversation_id) or _conversations.has(conversation_id):
		return _failure("CONVERSATION_ID_CONFLICT")
	if not _valid_actor(inviter_id) or not _valid_actor(invitee_id) or inviter_id == invitee_id:
		return _failure("CONVERSATION_PARTICIPANT_INVALID")
	if not space_id.begins_with("space."):
		return _failure("CONVERSATION_SPACE_INVALID")
	if _occupancy.has(inviter_id) or _occupancy.has(invitee_id):
		return _failure("CONVERSATION_PARTICIPANT_BUSY")
	var row := {
		"conversation_id":conversation_id,
		"state":"invited",
		"space_id":space_id,
		"participants":[inviter_id,invitee_id],
		"initiator_id":inviter_id
	}
	_conversations[conversation_id] = row
	_occupancy[inviter_id] = conversation_id
	_occupancy[invitee_id] = conversation_id
	revision += 1
	return _success(row)

func mark_approaching(conversation_id: String) -> Dictionary:
	return _transition(conversation_id,"invited","approaching")

func begin_participation(conversation_id: String) -> Dictionary:
	return _transition(conversation_id,"approaching","participating")

func end(conversation_id: String) -> Dictionary:
	if not _conversations.has(conversation_id):
		return _failure("CONVERSATION_UNKNOWN")
	var row: Dictionary = _conversations[conversation_id]
	if String(row.state) != "participating":
		return _failure("CONVERSATION_STATE_INVALID")
	var result := row.duplicate(true)
	result.state = "ended"
	_release(conversation_id)
	return _success(result)

func cancel(conversation_id: String) -> Dictionary:
	if not _conversations.has(conversation_id):
		return _failure("CONVERSATION_UNKNOWN")
	var result: Dictionary = _conversations[conversation_id].duplicate(true)
	result.state = "cancelled"
	_release(conversation_id)
	return _success(result)

func release_actor(actor_id: String) -> Array:
	if not _occupancy.has(actor_id):
		return []
	var conversation_id := String(_occupancy[actor_id])
	_release(conversation_id)
	return [conversation_id]

func release_space(space_id: String) -> Array:
	var ids: Array = []
	for conversation_id: Variant in _conversations.keys():
		if String(_conversations[conversation_id].space_id) == space_id:
			ids.append(String(conversation_id))
	ids.sort()
	for conversation_id: String in ids:
		_release(conversation_id)
	return ids

func clear_all() -> int:
	var count := _conversations.size()
	if count > 0:
		_conversations.clear()
		_occupancy.clear()
		revision += 1
	return count

func _transition(conversation_id: String, expected_state: String, next_state: String) -> Dictionary:
	if not _conversations.has(conversation_id):
		return _failure("CONVERSATION_UNKNOWN")
	var row: Dictionary = _conversations[conversation_id]
	if String(row.state) != expected_state:
		return _failure("CONVERSATION_STATE_INVALID")
	var next := row.duplicate(true)
	next.state = next_state
	_conversations[conversation_id] = next
	revision += 1
	return _success(next)

func _release(conversation_id: String) -> void:
	var row: Dictionary = _conversations.get(conversation_id,{})
	if row.is_empty():
		return
	for actor_id: Variant in row.participants:
		if String(_occupancy.get(actor_id,"")) == conversation_id:
			_occupancy.erase(actor_id)
	_conversations.erase(conversation_id)
	revision += 1

func _valid_actor(actor_id: String) -> bool:
	return _actors.has(actor_id)

func _valid_conversation_id(value: String) -> bool:
	return not value.is_empty() and value.length() <= 128

func _success(row: Dictionary) -> Dictionary:
	return {"ok":true,"error_code":"","conversation":row.duplicate(true),"revision":revision}

func _failure(code: String) -> Dictionary:
	return {"ok":false,"error_code":code,"conversation":{},"revision":revision}
