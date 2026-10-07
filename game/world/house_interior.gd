extends Node2D
## Editable engineering house interior. Collision and interaction anchors live in
## this scene; final art may replace presentation without changing stable ids.

const SPACE_ID := "space.house"
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

func layout_contract_valid() -> bool:
	for anchor_name: String in ["DoorArrival","DoorInteract","BedInteract"]:
		if get_anchor_position(anchor_name) == Vector2.INF:
			return false
	return true

func resolve_interaction_target() -> Dictionary:
	if _marker_reachable($Anchors/DoorInteract):
		return {
			"kind":"door",
			"interaction_id":"door.house.farm",
			"target_space_id":"space.farm",
			"arrival_anchor_id":"HouseDoorArrival",
			"arrival_facing":"south"
		}
	return {}

func _marker_reachable(marker: Marker2D) -> bool:
	var direction := _facing_vector(player.facing)
	if direction.is_zero_approx():
		return false
	var offset: Vector2 = marker.global_position - player.global_position
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
	# Diagnostic skin only; it is not accepted final interior art.
	draw_rect(Rect2(0,0,640,360),Color("5b4a3a"))
	draw_rect(Rect2(16,16,608,328),Color("c6b58f"))
	draw_rect(Rect2(208,96,56,32),Color("8b6b58"))
	draw_rect(Rect2(392,136,64,48),Color("806a4d"))
	draw_rect(Rect2(296,336,48,8),Color("6b4d32"))
