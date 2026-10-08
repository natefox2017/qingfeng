extends RefCounted
## Pure deterministic resident schedule resolver.
## It does not move actors or call AI. Content owns time/activity choices; WORLD
## owns anchor ids and spaces. The runtime movement layer will consume this target.

const CONTENT = preload("res://content/content_catalog.gd")

var configuration_error := ""
var _residents: Dictionary = {}
var _anchors: Dictionary = {}
var _minutes_per_day := 0

func _init(anchor_definitions: Array = [], content: Dictionary = {}) -> void:
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
	_minutes_per_day = int(source.clock.minutes_per_day)
	_residents = source.residents.definitions.duplicate(true)
	for definition: Variant in anchor_definitions:
		if not _valid_anchor_definition(definition) or _anchors.has(definition.anchor_id):
			configuration_error = "RESIDENT_ANCHOR_DEFINITION_INVALID"
			return
		_anchors[String(definition.anchor_id)] = definition.duplicate(true)
	if anchor_definitions.is_empty():
		return
	for resident_id: Variant in _residents:
		var resident: Dictionary = _residents[resident_id]
		for anchor_field: String in ["home_anchor_id","work_anchor_id","social_anchor_id","rain_anchor_id"]:
			if not _anchors.has(resident[anchor_field]):
				configuration_error = "RESIDENT_ANCHOR_MISSING"
				return
		for schedule_key: String in ["schedule","rain_schedule"]:
			for entry: Variant in resident[schedule_key]:
				if not _anchors.has(entry.anchor_id):
					configuration_error = "RESIDENT_SCHEDULE_ANCHOR_MISSING"
					return

func is_configured() -> bool:
	return configuration_error.is_empty()

func has_world_anchors() -> bool:
	return not _anchors.is_empty()

func resident_count() -> int:
	return _residents.size()

func resolve(resident_id: String, game_minute: int, is_raining := false) -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":configuration_error}
	if not _residents.has(resident_id):
		return {"ok":false,"error_code":"RESIDENT_UNKNOWN"}
	if game_minute < 0 or _minutes_per_day <= 0:
		return {"ok":false,"error_code":"RESIDENT_TIME_INVALID"}
	var minute_of_day := game_minute % _minutes_per_day
	var resident: Dictionary = _residents[resident_id]
	var schedule: Array = resident.rain_schedule if is_raining else resident.schedule
	var entry: Dictionary = _entry_for_minute(schedule,minute_of_day)
	if entry.is_empty():
		return {"ok":false,"error_code":"RESIDENT_SCHEDULE_INVALID"}
	if has_world_anchors() and not _anchors.has(entry.anchor_id):
		return {"ok":false,"error_code":"RESIDENT_SCHEDULE_ANCHOR_MISSING"}
	var anchor: Dictionary = _anchors.get(entry.anchor_id,{"anchor_id":entry.anchor_id,"space_id":""})
	return {
		"ok":true,
		"error_code":"",
		"resident_id":resident_id,
		"display_name":String(resident.display_name),
		"occupation_id":String(resident.occupation_id),
		"activity_id":String(entry.activity_id),
		"anchor_id":String(entry.anchor_id),
		"space_id":String(anchor.space_id),
		"minute_of_day":minute_of_day,
		"is_raining":is_raining
	}

func projection(game_minute: int, is_raining := false) -> Dictionary:
	var rows: Array = []
	var ids: Array = _residents.keys()
	ids.sort()
	for resident_id: Variant in ids:
		rows.append(resolve(String(resident_id),game_minute,is_raining))
	return {"residents":rows,"is_raining":is_raining}

func _entry_for_minute(schedule: Array, minute_of_day: int) -> Dictionary:
	if schedule.is_empty():
		return {}
	var chosen: Dictionary = schedule[-1]
	for entry: Variant in schedule:
		if int(entry.start_minute) <= minute_of_day:
			chosen = entry
		else:
			break
	return chosen.duplicate(true)

func _valid_anchor_definition(value: Variant) -> bool:
	if not (value is Dictionary) or value.size()!=2:
		return false
	if not value.has("anchor_id") or not value.has("space_id"):
		return false
	return (
		value.anchor_id is String
		and not value.anchor_id.is_empty()
		and value.space_id is String
		and String(value.space_id).begins_with("space.")
	)
