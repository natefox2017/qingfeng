extends Node2D
## Editable engineering village route. Stable transition anchors and collision
## live here; final terrain/building art may replace presentation only.

const SPACE_ID := "space.village"
const INTERACT_RANGE_PX := 28.0
const INTERACT_LATERAL_PX := 10.0

var _forage_states: Dictionary = {}

@onready var player: CharacterBody2D = $FootSorted/Player
@onready var neighbor_resident: CharacterBody2D = $FootSorted/NeighborResident

func set_input_enabled(enabled: bool) -> void:
	player.set_input_enabled(enabled)

func get_player() -> CharacterBody2D:
	return player

func get_space_id() -> String:
	return SPACE_ID

func get_spawn_position() -> Vector2:
	return $Anchors/FarmArrival.position

func get_anchor_position(anchor_name: String) -> Vector2:
	var node := $Anchors.get_node_or_null(NodePath(anchor_name))
	return node.position if node is Marker2D else Vector2.INF

func layout_contract_valid() -> bool:
	for anchor_name: String in ["FarmArrival","FarmExitInteract","ShopDoorInteract","ShopDoorArrival","WorkshopDoorInteract","WorkshopDoorArrival"]:
		if get_anchor_position(anchor_name) == Vector2.INF:
			return false
	var resident_anchors := get_resident_anchor_definitions()
	if resident_anchors.size() != $ResidentAnchors.get_child_count() or resident_anchors.is_empty():
		return false
	var neighbor := get_node_or_null("FootSorted/NeighborResident")
	if neighbor==null or not neighbor.has_method("set_schedule_target") or String(neighbor.resident_id)!="resident.neighbor":
		return false
	var resident_ids: Dictionary = {}
	for definition: Dictionary in resident_anchors:
		if resident_ids.has(definition.anchor_id):
			return false
		resident_ids[definition.anchor_id]=true
	var definitions := get_forage_definitions()
	if definitions.size() != $ForageSpots.get_child_count() or definitions.is_empty():
		return false
	var ids: Dictionary = {}
	for definition: Dictionary in definitions:
		if ids.has(definition.spot_id):
			return false
		ids[definition.spot_id]=true
	return true

func get_resident_anchor_definitions() -> Array:
	var definitions: Array = []
	for child: Node in $ResidentAnchors.get_children():
		if child is Marker2D and child.has_meta("anchor_id"):
			definitions.append({"anchor_id":String(child.get_meta("anchor_id")),"space_id":SPACE_ID,"world_position_px":{"x":child.position.x,"y":child.position.y}})
	definitions.sort_custom(func(a:Dictionary,b:Dictionary): return a.anchor_id < b.anchor_id)
	return definitions

func apply_resident_projection(value: Variant) -> bool:
	if not (value is Dictionary) or not value.has("residents") or not (value.residents is Array):
		return false
	for resident: Variant in value.residents:
		if not (resident is Dictionary) or not resident.get("ok",false):
			continue
		if String(resident.get("resident_id",""))!="resident.neighbor":
			continue
		if String(resident.get("space_id",""))!=SPACE_ID:
			neighbor_resident.clear_schedule_target()
			neighbor_resident.visible=false
			return true
		var marker := _marker_for_resident_anchor(String(resident.get("anchor_id","")))
		if marker==null:
			return false
		neighbor_resident.visible=true
		return neighbor_resident.set_schedule_target(
			String(resident.anchor_id),
			marker.position,
			String(resident.activity_id)
		)
	return false

func resident_visual_state() -> Dictionary:
	return neighbor_resident.projection() if is_instance_valid(neighbor_resident) else {}

func capture_resident_runtime() -> Array:
	if not is_instance_valid(neighbor_resident):
		return []
	return [neighbor_resident.runtime_snapshot(SPACE_ID)]

func apply_resident_runtime(value: Variant) -> bool:
	if not (value is Dictionary) or value.size()!=1 or not value.has("residents") or not (value.residents is Array):
		return false
	for resident: Variant in value.residents:
		if not (resident is Dictionary) or String(resident.get("resident_id",""))!="resident.neighbor":
			continue
		if String(resident.get("space_id",""))!=SPACE_ID:
			neighbor_resident.clear_schedule_target()
			neighbor_resident.visible=false
			return true
		var point: Variant = resident.get("world_position_px",{})
		if not (point is Dictionary) or not point.has("x") or not point.has("y"):
			return false
		var restored_position := Vector2(float(point.x),float(point.y))
		if _resident_position_is_blocked(restored_position):
			return false
		neighbor_resident.visible=true
		return neighbor_resident.restore_runtime_position(
			restored_position,
			StringName(String(resident.get("facing","")))
		)
	return false

func _resident_position_is_blocked(local_position: Vector2) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 1
	query.transform = Transform2D(0.0,to_global(local_position))
	return not get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func _marker_for_resident_anchor(anchor_id:String) -> Marker2D:
	for child: Node in $ResidentAnchors.get_children():
		if child is Marker2D and String(child.get_meta("anchor_id",""))==anchor_id:
			return child as Marker2D
	return null

func get_forage_definitions() -> Array:
	var definitions: Array = []
	for child: Node in $ForageSpots.get_children():
		if not (child is Marker2D) or not child.has_meta("spot_id") or not child.has_meta("forage_id"):
			continue
		definitions.append({
			"spot_id":String(child.get_meta("spot_id")),
			"space_id":SPACE_ID,
			"forage_id":String(child.get_meta("forage_id"))
		})
	definitions.sort_custom(func(a:Dictionary,b:Dictionary): return a.spot_id < b.spot_id)
	return definitions

func apply_forage_projection(value: Variant) -> bool:
	if not (value is Dictionary) or not value.has("spots") or not (value.spots is Array):
		return false
	var next: Dictionary = {}
	for spot: Variant in value.spots:
		if not (spot is Dictionary) or not spot.has("spot_id") or _marker_for_spot(String(spot.spot_id)) == null:
			return false
		next[String(spot.spot_id)] = spot.duplicate(true)
	_forage_states = next
	queue_redraw()
	return true

func forage_visual_state(spot_id:String) -> Dictionary:
	return _forage_states.get(spot_id,{}).duplicate(true)

func _marker_for_spot(spot_id:String) -> Marker2D:
	for child: Node in $ForageSpots.get_children():
		if child is Marker2D and String(child.get_meta("spot_id","")) == spot_id:
			return child as Marker2D
	return null

func resolve_interaction_target() -> Dictionary:
	for child: Node in $ForageSpots.get_children():
		if child is Marker2D:
			var spot_id := String(child.get_meta("spot_id",""))
			var state: Dictionary = _forage_states.get(spot_id,{})
			if bool(state.get("is_available",false)) and _marker_reachable(child as Marker2D):
				return {
					"kind":"forage",
					"interaction_id":"forage.village.pickup",
					"spot_id":spot_id
				}
	if _marker_reachable($Anchors/FarmExitInteract):
		return {
			"kind":"door",
			"interaction_id":"door.village.farm",
			"target_space_id":"space.farm",
			"arrival_anchor_id":"BridgeEast",
			"arrival_facing":"west"
		}
	if _marker_reachable($Anchors/ShopDoorInteract):
		return {
			"kind":"door",
			"interaction_id":"door.village.shop",
			"target_space_id":"space.shop",
			"arrival_anchor_id":"DoorArrival",
			"arrival_facing":"north"
		}
	if _marker_reachable($Anchors/WorkshopDoorInteract):
		return {
			"kind":"door",
			"interaction_id":"door.village.workshop",
			"target_space_id":"space.workshop",
			"arrival_anchor_id":"DoorArrival",
			"arrival_facing":"north"
		}
	return {}

func _marker_reachable(marker: Marker2D) -> bool:
	var direction := _facing_vector(player.facing)
	if direction.is_zero_approx():
		return false
	var offset: Vector2 = marker.global_position-player.global_position
	var forward := offset.dot(direction)
	var lateral := absf(offset.dot(Vector2(-direction.y,direction.x)))
	if forward <= 2.0 or forward > INTERACT_RANGE_PX or lateral > INTERACT_LATERAL_PX:
		return false
	var ray := PhysicsRayQueryParameters2D.create(player.global_position,marker.global_position,1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _facing_vector(facing: StringName) -> Vector2:
	match facing:
		&"north":
			return Vector2.UP
		&"south":
			return Vector2.DOWN
		&"west":
			return Vector2.LEFT
		&"east":
			return Vector2.RIGHT
	return Vector2.ZERO

func _draw() -> void:
	# Diagnostic skin only; not accepted village art.
	draw_rect(Rect2(0,0,640,360),Color("82966b"))
	draw_rect(Rect2(16,160,608,40),Color("bba574"))
	draw_rect(Rect2(384,128,32,72),Color("bba574"))
	draw_rect(Rect2(496,160,48,56),Color("bba574"))
	for child: Node in $ForageSpots.get_children():
		if child is Marker2D:
			var marker := child as Marker2D
			var state: Dictionary = _forage_states.get(String(marker.get_meta("spot_id","")),{})
			if bool(state.get("is_available",false)):
				draw_circle(marker.position,5.0,Color("486b3d"))
				draw_circle(marker.position+Vector2(3,-2),3.0,Color("6f914e"))
