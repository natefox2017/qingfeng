extends RefCounted
## Authoritative forage spot state. WORLD owns spot geometry/ids; this domain owns
## only collection state and content-backed rewards.

const CONTENT = preload("res://content/content_catalog.gd")

var revision: int = 0
var spots: Array = []
var configuration_error := ""
var _definitions: Dictionary = {}
var _types: Dictionary = {}

func _init(definitions: Array = [], content: Dictionary = {}) -> void:
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
	_types = source.forage.types.duplicate(true)
	var ids: Dictionary = {}
	for definition: Variant in definitions:
		if not _valid_definition(definition) or ids.has(definition.spot_id):
			configuration_error = "FORAGE_DEFINITION_INVALID"
			return
		ids[definition.spot_id] = true
		_definitions[String(definition.spot_id)] = definition.duplicate(true)
		spots.append({"spot_id":String(definition.spot_id),"last_collected_day":0})
	spots.sort_custom(func(a: Dictionary,b: Dictionary): return a.spot_id < b.spot_id)

func is_configured() -> bool:
	return configuration_error.is_empty()

func has_spots() -> bool:
	return not _definitions.is_empty()

func _valid_definition(value: Variant) -> bool:
	if not (value is Dictionary) or value.size()!=3:
		return false
	for key: String in ["spot_id","space_id","forage_id"]:
		if not value.has(key) or not (value[key] is String) or String(value[key]).is_empty():
			return false
	return String(value.space_id)=="space.village" and _types.has(value.forage_id)

func projection(current_day: int) -> Dictionary:
	var rows: Array = []
	for state: Dictionary in spots:
		var definition: Dictionary = _definitions[state.spot_id]
		var kind: Dictionary = _types[definition.forage_id]
		rows.append({
			"spot_id":state.spot_id,
			"space_id":definition.space_id,
			"forage_id":definition.forage_id,
			"item_id":String(kind.item_id),
			"quantity":int(kind.quantity),
			"last_collected_day":int(state.last_collected_day),
			"is_available":current_day-int(state.last_collected_day) >= int(kind.respawn_days)
		})
	return {"revision":revision,"spots":rows}

func candidate_collect(spot_id: String, current_day: int) -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":"FORAGE_NOT_CONFIGURED"}
	if not _definitions.has(spot_id):
		return {"ok":false,"error_code":"FORAGE_SPOT_UNKNOWN"}
	if current_day <= 0:
		return {"ok":false,"error_code":"FORAGE_DAY_INVALID"}
	var candidate: Array = spots.duplicate(true)
	for index in range(candidate.size()):
		if candidate[index].spot_id != spot_id:
			continue
		var definition: Dictionary = _definitions[spot_id]
		var kind: Dictionary = _types[definition.forage_id]
		if current_day-int(candidate[index].last_collected_day) < int(kind.respawn_days):
			return {"ok":false,"error_code":"FORAGE_ALREADY_COLLECTED"}
		candidate[index] = {"spot_id":spot_id,"last_collected_day":current_day}
		return {
			"ok":true,
			"error_code":"",
			"spots":candidate,
			"item_id":String(kind.item_id),
			"quantity":int(kind.quantity)
		}
	return {"ok":false,"error_code":"FORAGE_SPOT_UNKNOWN"}

func commit_spots(candidate: Array, expected_revision: int, current_day: int) -> bool:
	if expected_revision != revision or not _valid_spots(candidate,current_day):
		return false
	spots = candidate.duplicate(true)
	revision += 1
	return true

func restore(snapshot_value: Variant, current_day: int) -> bool:
	if not is_configured() or not (snapshot_value is Dictionary):
		return false
	if snapshot_value.size()!=2 or not snapshot_value.has("revision") or not snapshot_value.has("spots"):
		return false
	if not (snapshot_value.revision is int) or snapshot_value.revision < 0:
		return false
	if not (snapshot_value.spots is Array) or not _valid_spots(snapshot_value.spots,current_day):
		return false
	revision = int(snapshot_value.revision)
	spots = snapshot_value.spots.duplicate(true)
	return true

func _valid_spots(value: Array, current_day: int) -> bool:
	if value.size()!=_definitions.size():
		return false
	var seen: Dictionary = {}
	for entry: Variant in value:
		if not (entry is Dictionary) or entry.size()!=2:
			return false
		if not entry.has("spot_id") or not entry.has("last_collected_day"):
			return false
		if not (entry.spot_id is String) or not _definitions.has(entry.spot_id) or seen.has(entry.spot_id):
			return false
		if not (entry.last_collected_day is int) or entry.last_collected_day < 0 or entry.last_collected_day > current_day:
			return false
		seen[entry.spot_id]=true
	return seen.size()==_definitions.size()
