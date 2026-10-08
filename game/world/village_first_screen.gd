extends Node2D
## Editable engineering village route. Stable transition anchors and collision
## live here; final terrain/building art may replace presentation only.

const SPACE_ID := "space.village"
const INTERACT_RANGE_PX := 28.0
const INTERACT_LATERAL_PX := 10.0
const RESIDENT_ROOM = preload("res://world/components/resident_room_driver.gd")

var _forage_states: Dictionary = {}
var _active_conversation_id := ""
var _active_conversation_state := ""

@onready var player: CharacterBody2D = $FootSorted/Player
@onready var grocer_resident: CharacterBody2D = $FootSorted/GrocerResident
@onready var maker_resident: CharacterBody2D = $FootSorted/MakerResident
@onready var neighbor_resident: CharacterBody2D = $FootSorted/NeighborResident

var _resident_room: RefCounted

func _ready() -> void:
	_resident_room = RESIDENT_ROOM.new(
		SPACE_ID,
		{
			"resident.grocer":grocer_resident,
			"resident.maker":maker_resident,
			"resident.neighbor":neighbor_resident
		},
		$ResidentAnchors,
		{
			"space.shop":{
				"marker":$Anchors/ShopDoorInteract,
				"arrival_anchor_id":"DoorArrival",
				"arrival_facing":"north"
			},
			"space.workshop":{
				"marker":$Anchors/WorkshopDoorInteract,
				"arrival_anchor_id":"DoorArrival",
				"arrival_facing":"north"
			}
		},
		Callable(self,"_resident_position_is_safe")
	)

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
	for resident_id: String in ["resident.grocer","resident.maker","resident.neighbor"]:
		var node_name: String = String({
			"resident.grocer":"GrocerResident",
			"resident.maker":"MakerResident",
			"resident.neighbor":"NeighborResident"
		}[resident_id])
		var resident := get_node_or_null("FootSorted/"+node_name)
		if resident==null or not resident.has_method("set_schedule_target") or String(resident.resident_id)!=resident_id:
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

func apply_resident_projection(schedule_value: Variant, runtime_value: Variant = {}) -> bool:
	return _resident_room != null and _resident_room.apply(schedule_value,runtime_value)

func resident_visual_state(resident_id: String = "resident.neighbor") -> Dictionary:
	return _resident_room.visual_state(resident_id) if _resident_room != null else {}

func capture_resident_runtime() -> Array:
	return _resident_room.capture() if _resident_room != null else []

func apply_resident_runtime(value: Variant) -> bool:
	return _resident_room != null and _resident_room.apply_runtime_only(value)

func resident_handoff_requests() -> Array:
	return _resident_room.handoff_requests() if _resident_room != null else []

func apply_conversation_projection(value: Variant) -> bool:
	if not (value is Dictionary) or not value.has("conversations") or not (value.conversations is Array):
		return false
	_active_conversation_id = ""
	_active_conversation_state = ""
	for conversation: Variant in value.conversations:
		if not (conversation is Dictionary) or String(conversation.get("space_id",""))!=SPACE_ID:
			continue
		var participants: Variant = conversation.get("participants",[])
		if not (participants is Array) or participants.size()!=2:
			continue
		var first_id := String(participants[0])
		var second_id := String(participants[1])
		var first_actor := _resident_actor(first_id)
		var second_actor := _resident_actor(second_id)
		if first_actor==null or second_actor==null:
			continue
		var state := String(conversation.get("state",""))
		if state not in ["invited","approaching","participating"]:
			continue
		_active_conversation_id = String(conversation.get("conversation_id",""))
		_active_conversation_state = state
		if state in ["invited","approaching","participating"]:
			first_actor.set_schedule_target(
				"conversation.%s.left" % _active_conversation_id,
				$ConversationAnchors/Left.position,
				"conversation"
			)
			second_actor.set_schedule_target(
				"conversation.%s.right" % _active_conversation_id,
				$ConversationAnchors/Right.position,
				"conversation"
			)
		if state=="participating":
			first_actor.face_toward(second_actor.position)
			second_actor.face_toward(first_actor.position)
		queue_redraw()
		return true
	queue_redraw()
	return true

func conversation_participants_arrived(conversation_id: String) -> bool:
	if conversation_id.is_empty() or conversation_id != _active_conversation_id:
		return false
	var left_target := "conversation.%s.left" % conversation_id
	var right_target := "conversation.%s.right" % conversation_id
	for actor: CharacterBody2D in [grocer_resident,maker_resident,neighbor_resident]:
		var state: Dictionary = actor.projection()
		if String(state.get("anchor_id","")) in [left_target,right_target]:
			if String(state.get("movement_state",""))!="arrived":
				return false
	return (
		String(grocer_resident.projection().get("anchor_id","")) in [left_target,right_target]
		or String(maker_resident.projection().get("anchor_id","")) in [left_target,right_target]
		or String(neighbor_resident.projection().get("anchor_id","")) in [left_target,right_target]
	)

func conversation_visual_state() -> Dictionary:
	return {
		"conversation_id":_active_conversation_id,
		"state":_active_conversation_state,
		"is_visible":_active_conversation_state=="participating"
	}

func _resident_actor(resident_id: String) -> CharacterBody2D:
	match resident_id:
		"resident.grocer":
			return grocer_resident
		"resident.maker":
			return maker_resident
		"resident.neighbor":
			return neighbor_resident
	return null

func _resident_position_is_safe(local_position: Vector2) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 1
	query.transform = Transform2D(0.0,to_global(local_position))
	return get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

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
	if _active_conversation_state=="participating":
		var midpoint := ($ConversationAnchors/Left.position+$ConversationAnchors/Right.position)*0.5
		draw_circle(midpoint+Vector2(-6,-18),3.0,Color("f3eee2"))
		draw_circle(midpoint+Vector2(0,-20),3.0,Color("f3eee2"))
		draw_circle(midpoint+Vector2(6,-18),3.0,Color("f3eee2"))
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
