extends RefCounted
## Small WORLD adapter that maps authoritative resident runtime state + schedule
## targets onto resident bodies in one active Space.

var configuration_error := ""
var _space_id := ""
var _actors: Dictionary = {}
var _anchors: Dictionary = {}
var _portals: Dictionary = {}
var _travel_targets: Dictionary = {}

func _init(space_id: String, actors: Dictionary, resident_anchor_root: Node, portals: Dictionary = {}) -> void:
	_space_id = space_id
	if _space_id.is_empty() or actors.is_empty() or resident_anchor_root == null:
		configuration_error = "RESIDENT_ROOM_CONFIG_INVALID"
		return
	for resident_id: Variant in actors:
		var actor: Variant = actors[resident_id]
		if not (resident_id is String) or String(resident_id).is_empty() or not (actor is CharacterBody2D):
			configuration_error = "RESIDENT_ROOM_ACTOR_INVALID"
			return
		if not actor.has_method("set_schedule_target") or not actor.has_method("set_world_active") or String(actor.resident_id)!=String(resident_id):
			configuration_error = "RESIDENT_ROOM_ACTOR_INVALID"
			return
		_actors[String(resident_id)] = actor
		actor.set_world_active(false)
	for child: Node in resident_anchor_root.get_children():
		if child is Marker2D and child.has_meta("anchor_id"):
			_anchors[String(child.get_meta("anchor_id"))] = child
	for target_space: Variant in portals:
		var portal: Variant = portals[target_space]
		if not (target_space is String) or not (portal is Dictionary):
			configuration_error = "RESIDENT_ROOM_PORTAL_INVALID"
			return
		for key: String in ["marker","arrival_anchor_id","arrival_facing"]:
			if not portal.has(key):
				configuration_error = "RESIDENT_ROOM_PORTAL_INVALID"
				return
		if not (portal.marker is Marker2D) or not (portal.arrival_anchor_id is String) or not (portal.arrival_facing is String):
			configuration_error = "RESIDENT_ROOM_PORTAL_INVALID"
			return
		_portals[String(target_space)] = portal.duplicate()

func is_configured() -> bool:
	return configuration_error.is_empty()

func apply(schedule_value: Variant, runtime_value: Variant) -> bool:
	if not is_configured() or not _valid_projection(schedule_value) or not _valid_projection(runtime_value):
		return false
	var schedule_rows := _rows_by_id(schedule_value.residents)
	var runtime_rows := _rows_by_id(runtime_value.residents)
	_travel_targets.clear()
	for resident_id: String in _actors:
		var actor: CharacterBody2D = _actors[resident_id]
		var runtime: Dictionary = runtime_rows.get(resident_id,{})
		var schedule: Dictionary = schedule_rows.get(resident_id,{})
		if runtime.is_empty() or schedule.is_empty() or not bool(schedule.get("ok",false)):
			actor.set_world_active(false)
			continue
		if String(runtime.get("space_id","")) != _space_id:
			actor.set_world_active(false)
			continue
		actor.set_world_active(true)
		if String(schedule.get("space_id","")) == _space_id:
			var marker: Marker2D = _anchors.get(String(schedule.get("anchor_id","")),null)
			if marker == null:
				return false
			if not actor.set_schedule_target(String(schedule.anchor_id),marker.position,String(schedule.activity_id)):
				return false
			continue
		var target_space := String(schedule.get("space_id",""))
		var portal: Dictionary = _portals.get(target_space,{})
		if portal.is_empty():
			return false
		var travel_id := "portal.%s.%s" % [resident_id,target_space]
		_travel_targets[resident_id] = {
			"resident_id":resident_id,
			"target_space_id":target_space,
			"arrival_anchor_id":String(portal.arrival_anchor_id),
			"arrival_facing":String(portal.arrival_facing),
			"travel_anchor_id":travel_id
		}
		if not actor.set_schedule_target(travel_id,(portal.marker as Marker2D).position,"travel"):
			return false
	return true

func capture() -> Array:
	var rows: Array = []
	for resident_id: String in _actors:
		var actor: CharacterBody2D = _actors[resident_id]
		if actor.is_world_active():
			rows.append(actor.runtime_snapshot(_space_id))
	return rows

func handoff_requests() -> Array:
	var rows: Array = []
	for resident_id: String in _travel_targets:
		var actor: CharacterBody2D = _actors[resident_id]
		var travel: Dictionary = _travel_targets[resident_id]
		var state: Dictionary = actor.projection()
		if actor.is_world_active() and String(state.get("movement_state",""))=="arrived" and String(state.get("anchor_id",""))==String(travel.travel_anchor_id):
			rows.append({
				"resident_id":resident_id,
				"source_space_id":_space_id,
				"target_space_id":String(travel.target_space_id),
				"arrival_anchor_id":String(travel.arrival_anchor_id),
				"arrival_facing":String(travel.arrival_facing)
			})
	return rows

func visual_state(resident_id: String) -> Dictionary:
	if not _actors.has(resident_id):
		return {}
	return (_actors[resident_id] as CharacterBody2D).projection()

func apply_runtime_only(runtime_value: Variant) -> bool:
	if not is_configured() or not _valid_projection(runtime_value):
		return false
	var runtime_rows := _rows_by_id(runtime_value.residents)
	for resident_id: String in _actors:
		var actor: CharacterBody2D = _actors[resident_id]
		var runtime: Dictionary = runtime_rows.get(resident_id,{})
		if runtime.is_empty() or String(runtime.get("space_id","")) != _space_id:
			actor.set_world_active(false)
			continue
		var point: Variant = runtime.get("world_position_px",{})
		if not (point is Dictionary) or not point.has("x") or not point.has("y"):
			return false
		actor.set_world_active(true)
		if not actor.restore_runtime_position(
			Vector2(float(point.x),float(point.y)),
			StringName(String(runtime.get("facing","")))
		):
			return false
	return true

func _rows_by_id(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row: Variant in rows:
		if row is Dictionary and row.has("resident_id"):
			result[String(row.resident_id)] = row
	return result

func _valid_projection(value: Variant) -> bool:
	return value is Dictionary and value.has("residents") and value.residents is Array
