extends Node2D
## Editable engineering shop interior. Counter service is independent of any
## future NPC actor; this scene only owns collision and interaction anchors.

const SPACE_ID := "space.shop"
const INTERACT_RANGE_PX := 28.0
const INTERACT_LATERAL_PX := 10.0
const RESIDENT_ROOM = preload("res://world/components/resident_room_driver.gd")

@onready var player: CharacterBody2D = $FootSorted/Player
@onready var grocer_resident: CharacterBody2D = $FootSorted/GrocerResident

var _resident_room: RefCounted

func _ready() -> void:
	_resident_room = RESIDENT_ROOM.new(
		SPACE_ID,
		{"resident.grocer":grocer_resident},
		$ResidentAnchors,
		{
			"space.village":{
				"marker":$Anchors/DoorInteract,
				"arrival_anchor_id":"ShopDoorArrival",
				"arrival_facing":"south"
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
	return $Anchors/DoorArrival.position

func get_anchor_position(anchor_name: String) -> Vector2:
	var node := $Anchors.get_node_or_null(NodePath(anchor_name))
	return node.position if node is Marker2D else Vector2.INF

func get_resident_anchor_definitions() -> Array:
	var definitions: Array = []
	for child: Node in $ResidentAnchors.get_children():
		if child is Marker2D and child.has_meta("anchor_id"):
			definitions.append({"anchor_id":String(child.get_meta("anchor_id")),"space_id":SPACE_ID,"world_position_px":{"x":child.position.x,"y":child.position.y}})
	definitions.sort_custom(func(a:Dictionary,b:Dictionary): return a.anchor_id < b.anchor_id)
	return definitions

func layout_contract_valid() -> bool:
	for anchor_name: String in ["DoorArrival","DoorInteract","CounterInteract"]:
		if get_anchor_position(anchor_name) == Vector2.INF:
			return false
	var resident := get_node_or_null("FootSorted/GrocerResident")
	if resident==null or not resident.has_method("set_schedule_target") or String(resident.resident_id)!="resident.grocer":
		return false
	return get_resident_anchor_definitions().size() == $ResidentAnchors.get_child_count() and not $ResidentAnchors.get_children().is_empty()

func apply_resident_projection(schedule_value: Variant, runtime_value: Variant = {}) -> bool:
	return _resident_room != null and _resident_room.apply(schedule_value,runtime_value)

func capture_resident_runtime() -> Array:
	return _resident_room.capture() if _resident_room != null else []

func apply_resident_runtime(value: Variant) -> bool:
	return _resident_room != null and _resident_room.apply_runtime_only(value)

func resident_handoff_requests() -> Array:
	return _resident_room.handoff_requests() if _resident_room != null else []

func resident_visual_state(resident_id: String = "resident.grocer") -> Dictionary:
	return _resident_room.visual_state(resident_id) if _resident_room != null else {}

func _resident_position_is_safe(local_position: Vector2) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 1
	query.transform = Transform2D(0.0,to_global(local_position))
	return get_world_2d().direct_space_state.intersect_shape(query,1).is_empty()

func resolve_interaction_target() -> Dictionary:
	if _marker_reachable($Anchors/CounterInteract):
		return {
			"kind":"trade",
			"interaction_id":"trade.shop.counter"
		}
	if _marker_reachable($Anchors/DoorInteract):
		return {
			"kind":"door",
			"interaction_id":"door.shop.village",
			"target_space_id":"space.village",
			"arrival_anchor_id":"ShopDoorArrival",
			"arrival_facing":"south"
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
	# Diagnostic skin only; not accepted shop art.
	draw_rect(Rect2(0,0,640,360),Color("5a4736"))
	draw_rect(Rect2(16,16,608,328),Color("d0bd94"))
	draw_rect(Rect2(240,96,160,32),Color("715137"))
	draw_rect(Rect2(296,336,48,8),Color("6b4d32"))
