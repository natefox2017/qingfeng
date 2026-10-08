extends RefCounted
## Authoritative persisted resident runtime state. Schedule targets stay derived
## from content + clock; this domain stores only actual resident state.

const MAX_WORLD_COORDINATE := 1000000.0
const MAX_KNOWN_EVENTS := 256

var configuration_error := ""
var _content: Dictionary = {}
var _anchors: Dictionary = {}
var _spaces: Dictionary = {}
var _states: Dictionary = {}

func _init(anchor_definitions: Array = [], content: Dictionary = {}) -> void:
	_content = content.duplicate(true)
	if anchor_definitions.is_empty():
		return
	if not _content.has("residents") or not (_content.residents is Dictionary) or not (_content.residents.definitions is Dictionary):
		configuration_error = "RESIDENT_RUNTIME_CONTENT_INVALID"
		return
	for definition: Variant in anchor_definitions:
		if not _valid_anchor_definition(definition) or _anchors.has(definition.anchor_id):
			configuration_error = "RESIDENT_RUNTIME_ANCHOR_INVALID"
			return
		var row: Dictionary = definition.duplicate(true)
		_anchors[String(row.anchor_id)] = row
		_spaces[String(row.space_id)] = true
	for resident_id: Variant in _content.residents.definitions:
		var resident: Dictionary = _content.residents.definitions[resident_id]
		var home_id := String(resident.home_anchor_id)
		if not _anchors.has(home_id):
			configuration_error = "RESIDENT_RUNTIME_HOME_MISSING"
			return
		var home: Dictionary = _anchors[home_id]
		_states[String(resident_id)] = {
			"resident_id":String(resident_id),
			"space_id":String(home.space_id),
			"world_position_px":home.world_position_px.duplicate(true),
			"facing":"south",
			"relationship_points":0,
			"known_event_ids":[]
		}

func is_configured() -> bool:
	return configuration_error.is_empty()

func has_states() -> bool:
	return not _states.is_empty()

func projection() -> Dictionary:
	var rows: Array = []
	var ids: Array = _states.keys()
	ids.sort()
	for resident_id: Variant in ids:
		rows.append(_states[resident_id].duplicate(true))
	return {"residents":rows}

func snapshot() -> Dictionary:
	return projection()

func update_runtime(value: Variant) -> bool:
	if not is_configured() or not has_states() or not _valid_runtime_update(value):
		return false
	var resident_id := String(value.resident_id)
	if not _states.has(resident_id):
		return false
	var next: Dictionary = _states[resident_id].duplicate(true)
	next.space_id = String(value.space_id)
	next.world_position_px = value.world_position_px.duplicate(true)
	next.facing = String(value.facing)
	_states[resident_id] = next
	return true

func relationship_points_for(resident_id: String) -> int:
	if not _states.has(resident_id):
		return 0
	return int(_states[resident_id].relationship_points)

func adjust_relationship(resident_id: String, delta: int) -> Dictionary:
	if not is_configured() or not _states.has(resident_id):
		return {"ok":false,"error_code":"RESIDENT_RUNTIME_UNKNOWN_RESIDENT","has_changes":false}
	if delta==0:
		return {"ok":true,"error_code":"","has_changes":false}
	var current := int(_states[resident_id].relationship_points)
	var next_value := current+delta
	if next_value < -1000000 or next_value > 1000000:
		return {"ok":false,"error_code":"RESIDENT_RELATIONSHIP_RANGE","has_changes":false}
	var next: Dictionary = _states[resident_id].duplicate(true)
	next.relationship_points=next_value
	_states[resident_id]=next
	return {"ok":true,"error_code":"","has_changes":true}

func knows_event(resident_id: String, event_id: String) -> bool:
	if not _states.has(resident_id) or event_id.is_empty():
		return false
	return event_id in _states[resident_id].known_event_ids

func known_events_for(resident_id: String) -> Array:
	if not _states.has(resident_id):
		return []
	return _states[resident_id].known_event_ids.duplicate()

func add_known_events(resident_id: String, event_ids: Array) -> Dictionary:
	if not is_configured() or not _states.has(resident_id):
		return {"ok":false,"error_code":"RESIDENT_RUNTIME_UNKNOWN_RESIDENT","has_changes":false}
	if event_ids.is_empty():
		return {"ok":false,"error_code":"RESIDENT_RUNTIME_EVENT_IDS_EMPTY","has_changes":false}
	var seen: Dictionary = {}
	var additions: Array[String] = []
	var current: Array = _states[resident_id].known_event_ids
	for event_id: Variant in event_ids:
		if not (event_id is String) or event_id.is_empty() or event_id.length()>128 or seen.has(event_id):
			return {"ok":false,"error_code":"RESIDENT_RUNTIME_EVENT_ID_INVALID","has_changes":false}
		seen[event_id]=true
		if event_id not in current:
			additions.append(event_id)
	if current.size()+additions.size()>MAX_KNOWN_EVENTS:
		return {"ok":false,"error_code":"RESIDENT_RUNTIME_KNOWN_EVENTS_FULL","has_changes":false}
	if additions.is_empty():
		return {"ok":true,"error_code":"","has_changes":false}
	var next: Dictionary = _states[resident_id].duplicate(true)
	for event_id: String in additions:
		next.known_event_ids.append(event_id)
	_states[resident_id]=next
	return {"ok":true,"error_code":"","has_changes":true}

func restore(value: Variant) -> bool:
	if not is_configured() or not has_states() or not (value is Dictionary) or value.size()!=1 or not value.has("residents") or not (value.residents is Array):
		return false
	if value.residents.size()!=_states.size():
		return false
	var next: Dictionary = {}
	for row: Variant in value.residents:
		if not _valid_state(row) or next.has(row.resident_id) or not _states.has(row.resident_id):
			return false
		next[String(row.resident_id)] = row.duplicate(true)
	if next.size()!=_states.size():
		return false
	_states = next
	return true

func _valid_runtime_update(value: Variant) -> bool:
	if not (value is Dictionary) or value.size()!=4:
		return false
	for key: String in ["resident_id","space_id","world_position_px","facing"]:
		if not value.has(key):
			return false
	return (
		value.resident_id is String
		and _states.has(value.resident_id)
		and value.space_id is String
		and _spaces.has(value.space_id)
		and _valid_point(value.world_position_px)
		and value.facing in ["north","south","east","west"]
	)

func _valid_state(value: Variant) -> bool:
	if not (value is Dictionary) or value.size()!=6:
		return false
	for key: String in ["resident_id","space_id","world_position_px","facing","relationship_points","known_event_ids"]:
		if not value.has(key):
			return false
	if not (value.resident_id is String) or not _states.has(value.resident_id):
		return false
	if not (value.space_id is String) or not _spaces.has(value.space_id):
		return false
	if not _valid_point(value.world_position_px) or value.facing not in ["north","south","east","west"]:
		return false
	if not (value.relationship_points is int):
		return false
	if not (value.known_event_ids is Array) or value.known_event_ids.size()>MAX_KNOWN_EVENTS:
		return false
	var seen: Dictionary = {}
	for event_id: Variant in value.known_event_ids:
		if not (event_id is String) or event_id.is_empty() or event_id.length()>128 or seen.has(event_id):
			return false
		seen[event_id]=true
	return true

func _valid_anchor_definition(value: Variant) -> bool:
	return (
		value is Dictionary
		and value.size()==3
		and value.has("anchor_id")
		and value.has("space_id")
		and value.has("world_position_px")
		and value.anchor_id is String
		and not value.anchor_id.is_empty()
		and value.space_id is String
		and String(value.space_id).begins_with("space.")
		and _valid_point(value.world_position_px)
	)

func _valid_point(value: Variant) -> bool:
	if not (value is Dictionary) or value.size()!=2 or not value.has("x") or not value.has("y"):
		return false
	for axis: String in ["x","y"]:
		if not (value[axis] is int or value[axis] is float) or not is_finite(float(value[axis])) or absf(float(value[axis]))>MAX_WORLD_COORDINATE:
			return false
	return true
