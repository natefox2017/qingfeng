extends Node2D
## Editable engineering village route. Stable transition anchors and collision
## live here; final terrain/building art may replace presentation only.

const SPACE_ID := "space.village"
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
	return $Anchors/FarmArrival.position

func get_anchor_position(anchor_name: String) -> Vector2:
	var node := $Anchors.get_node_or_null(NodePath(anchor_name))
	return node.position if node is Marker2D else Vector2.INF

func layout_contract_valid() -> bool:
	for anchor_name: String in ["FarmArrival","FarmExitInteract","ShopDoorInteract","ShopDoorArrival"]:
		if get_anchor_position(anchor_name) == Vector2.INF:
			return false
	return true

func resolve_interaction_target() -> Dictionary:
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
