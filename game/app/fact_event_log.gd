extends RefCounted
## CORE-owned append-only fact log. Producers own kind-specific payload schemas;
## this domain owns the strict common envelope, uniqueness and persistence.

const MAX_EVENTS := 512
const MAX_EVENT_ID := 128
const MAX_KIND := 128
const MAX_ACTOR_ID := 128
const MAX_PARTICIPANTS := 32
const MAX_PAYLOAD_DEPTH := 4
const MAX_PAYLOAD_KEYS := 32
const MAX_PAYLOAD_ITEMS := 64
const MAX_PAYLOAD_STRING := 512

var revision := 0
var _events: Array[Dictionary] = []
var _by_id: Dictionary = {}

func append(value: Variant) -> Dictionary:
	if not _valid_fact(value):
		return _failure("FACT_EVENT_INVALID")
	var event: Dictionary = value.duplicate(true)
	var event_id := String(event.event_id)
	if _by_id.has(event_id):
		if _by_id[event_id] == event:
			return {"ok":true,"error_code":"","has_changes":false,"revision":revision,"event_id":event_id}
		return _failure("FACT_EVENT_ID_CONFLICT")
	if _events.size() >= MAX_EVENTS:
		return _failure("FACT_EVENT_LOG_FULL")
	_events.append(event)
	_by_id[event_id] = event
	revision += 1
	return {"ok":true,"error_code":"","has_changes":true,"revision":revision,"event_id":event_id}

func has_event(event_id: String) -> bool:
	return _by_id.has(event_id)

func get_event(event_id: String) -> Dictionary:
	if not _by_id.has(event_id):
		return {}
	return _by_id[event_id].duplicate(true)

func projection() -> Dictionary:
	return snapshot()

func snapshot() -> Dictionary:
	var rows: Array = []
	for event: Dictionary in _events:
		rows.append(event.duplicate(true))
	return {"revision":revision,"events":rows}

func restore(value: Variant) -> bool:
	if not (value is Dictionary) or value.size()!=2 or not value.has("revision") or not value.has("events"):
		return false
	if not (value.revision is int) or value.revision<0 or not (value.events is Array) or value.events.size()>MAX_EVENTS:
		return false
	if value.revision != value.events.size():
		return false
	var next_events: Array[Dictionary] = []
	var next_by_id: Dictionary = {}
	for row: Variant in value.events:
		if not _valid_fact(row):
			return false
		var event: Dictionary = row.duplicate(true)
		var event_id := String(event.event_id)
		if next_by_id.has(event_id):
			return false
		next_events.append(event)
		next_by_id[event_id]=event
	_events = next_events
	_by_id = next_by_id
	revision = int(value.revision)
	return true

func known_ids_exist(event_ids: Array) -> bool:
	for event_id: Variant in event_ids:
		if not (event_id is String) or not _by_id.has(event_id):
			return false
	return true

func _valid_fact(value: Variant) -> bool:
	if not (value is Dictionary) or value.size()!=8:
		return false
	for key: String in ["event_id","source_command_id","source_system","kind","space_id","game_minute","participant_ids","payload"]:
		if not value.has(key):
			return false
	if not (value.event_id is String) or value.event_id.is_empty() or value.event_id.length()>MAX_EVENT_ID:
		return false
	if not (value.kind is String) or value.kind.is_empty() or value.kind.length()>MAX_KIND:
		return false
	if not (value.space_id is String) or not String(value.space_id).begins_with("space.") or value.space_id.length()>128:
		return false
	if not (value.game_minute is int) or value.game_minute<0:
		return false
	var has_command := value.source_command_id is String and not String(value.source_command_id).is_empty() and String(value.source_command_id).length()<=128
	var has_system := value.source_system is String and not String(value.source_system).is_empty() and String(value.source_system).length()<=128
	if has_command == has_system:
		return false
	if value.source_command_id != null and not has_command:
		return false
	if value.source_system != null and not has_system:
		return false
	if not (value.participant_ids is Array) or value.participant_ids.size()>MAX_PARTICIPANTS:
		return false
	var participants: Dictionary = {}
	for actor_id: Variant in value.participant_ids:
		if not (actor_id is String) or actor_id.is_empty() or actor_id.length()>MAX_ACTOR_ID or participants.has(actor_id):
			return false
		participants[actor_id]=true
	return value.payload is Dictionary and _valid_payload(value.payload,0)

func _valid_payload(value: Variant, depth: int) -> bool:
	if depth>MAX_PAYLOAD_DEPTH:
		return false
	if value==null or value is bool or value is int:
		return true
	if value is float:
		return is_finite(value)
	if value is String:
		return value.length()<=MAX_PAYLOAD_STRING
	if value is Array:
		if value.size()>MAX_PAYLOAD_ITEMS:
			return false
		for item: Variant in value:
			if not _valid_payload(item,depth+1):
				return false
		return true
	if value is Dictionary:
		if value.size()>MAX_PAYLOAD_KEYS:
			return false
		for key: Variant in value:
			if not (key is String) or key.is_empty() or key.length()>128 or not _valid_payload(value[key],depth+1):
				return false
		return true
	return false

func _failure(code: String) -> Dictionary:
	return {"ok":false,"error_code":code,"has_changes":false,"revision":revision,"event_id":""}
