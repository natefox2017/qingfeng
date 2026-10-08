extends Node2D
## Editable engineering workshop interior. Stable anchors are reserved for the
## future resident/service layer; this scene owns only layout/collision/doors.

const SPACE_ID := "space.workshop"
const INTERACT_RANGE_PX := 28.0
const INTERACT_LATERAL_PX := 10.0

@onready var player: CharacterBody2D = $FootSorted/Player

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
			definitions.append({"anchor_id":String(child.get_meta("anchor_id")),"space_id":SPACE_ID})
	definitions.sort_custom(func(a:Dictionary,b:Dictionary): return a.anchor_id < b.anchor_id)
	return definitions

func layout_contract_valid() -> bool:
	for anchor_name: String in ["DoorArrival","DoorInteract","WorkbenchInteract","ServiceAnchor"]:
		if get_anchor_position(anchor_name) == Vector2.INF:
			return false
	return get_resident_anchor_definitions().size() == $ResidentAnchors.get_child_count() and not $ResidentAnchors.get_children().is_empty()

func resolve_interaction_target() -> Dictionary:
	if _marker_reachable($Anchors/DoorInteract):
		return {
			"kind":"door",
			"interaction_id":"door.workshop.village",
			"target_space_id":"space.village",
			"arrival_anchor_id":"WorkshopDoorArrival",
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
	# Diagnostic skin only; not accepted workshop art.
	draw_rect(Rect2(0,0,640,360),Color("51483c"))
	draw_rect(Rect2(16,16,608,328),Color("b9aa8d"))
	draw_rect(Rect2(168,104,304,40),Color("745c43"))
	draw_rect(Rect2(280,240,80,36),Color("69513d"))
