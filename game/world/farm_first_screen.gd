extends Node2D
## Editable Phase0 farm scene with authored TileMapLayer terrain and object art.
## Plot coordinates are exported from Marker2D nodes in this scene; gameplay never
## owns a second copy of map geometry.

const TILE_SIZE := 16
const SPACE_ID := "space.farm"
const FARM_ACTION_RANGE_PX := 28.0
const FARM_ACTION_LATERAL_PX := 9.0

var _farm_states: Dictionary = {}

@onready var player: CharacterBody2D = $FootSorted/Player
@onready var plot_tiles: TileMapLayer = $PlotStates

func set_input_enabled(enabled: bool) -> void:
	player.set_input_enabled(enabled)

func get_player() -> CharacterBody2D:
	return player

func get_space_id() -> String:
	return SPACE_ID

func get_spawn_position() -> Vector2:
	return $Anchors/PlayerSpawn.position

func get_anchor_position(anchor_name: String) -> Vector2:
	var node := $Anchors.get_node_or_null(NodePath(anchor_name))
	return node.position if node is Marker2D else Vector2.INF

func resolve_interaction_target() -> Dictionary:
	if _marker_reachable($Anchors/HouseDoorInteract):
		return {
			"kind":"door",
			"interaction_id":"door.farm.house",
			"target_space_id":"space.house",
			"arrival_anchor_id":"DoorArrival",
			"arrival_facing":"north"
		}
	if _marker_reachable($Anchors/VillagePathInteract):
		return {
			"kind":"door",
			"interaction_id":"door.farm.village",
			"target_space_id":"space.village",
			"arrival_anchor_id":"FarmArrival",
			"arrival_facing":"east"
		}
	return {}

func _marker_reachable(marker: Marker2D) -> bool:
	var direction := _facing_vector(player.facing)
	if direction.is_zero_approx():
		return false
	var offset: Vector2 = marker.global_position - player.global_position
	var forward := offset.dot(direction)
	var lateral := absf(offset.dot(Vector2(-direction.y,direction.x)))
	if forward <= 2.0 or forward > FARM_ACTION_RANGE_PX or lateral > FARM_ACTION_LATERAL_PX:
		return false
	var ray := PhysicsRayQueryParameters2D.create(player.global_position,marker.global_position,1)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func resolve_plot_target() -> String:
	var direction := _facing_vector(player.facing)
	if direction.is_zero_approx():
		return ""
	var best_id := ""
	var best_distance := INF
	for child: Node in $FarmPlots.get_children():
		if not (child is Marker2D) or not child.has_meta("plot_id"):
			continue
		var marker := child as Marker2D
		var offset: Vector2 = marker.global_position - player.global_position
		var forward := offset.dot(direction)
		var lateral := absf(offset.dot(Vector2(-direction.y,direction.x)))
		if forward <= 2.0 or forward > FARM_ACTION_RANGE_PX or lateral > FARM_ACTION_LATERAL_PX:
			continue
		var ray := PhysicsRayQueryParameters2D.create(player.global_position,marker.global_position,1)
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var distance := offset.length_squared()
		if distance < best_distance:
			best_distance = distance
			best_id = String(marker.get_meta("plot_id"))
	return best_id

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

func apply_farm_projection(value: Variant) -> bool:
	if not (value is Dictionary) or not value.has("plots") or not (value.plots is Array):
		return false
	var next: Dictionary = {}
	for plot: Variant in value.plots:
		if not (plot is Dictionary) or not plot.has("plot_id") or _marker_for_plot(String(plot.plot_id)) == null:
			return false
		next[String(plot.plot_id)] = plot.duplicate(true)
	_farm_states = next
	plot_tiles.clear()
	for plot_id: String in _farm_states:
		var marker: Marker2D = _marker_for_plot(plot_id)
		var row: Dictionary = _farm_states[plot_id]
		var state: String = String(row.get("state","untilled"))
		var atlas := Vector2i(0,2)
		match state:
			"tilled":
				atlas = Vector2i(2,2) if bool(row.get("is_watered",false)) else Vector2i(1,2)
			"growing":
				atlas = Vector2i(3,2)
			"mature":
				atlas = Vector2i(4,2)
		var cell := Vector2i(int(round(marker.position.x/TILE_SIZE)),int(round(marker.position.y/TILE_SIZE)))
		plot_tiles.set_cell(cell,0,atlas,0)
	return true

func farm_visual_state(plot_id: String) -> Dictionary:
	return _farm_states.get(plot_id,{}).duplicate(true)

func get_plot_definitions() -> Array:
	var definitions: Array = []
	for child: Node in $FarmPlots.get_children():
		if not (child is Marker2D) or not child.has_meta("plot_id"):
			continue
		var marker := child as Marker2D
		definitions.append({
			"plot_id":String(marker.get_meta("plot_id")),
			"space_id":SPACE_ID,
			"cell_position":{
				"x":int(round(marker.position.x / TILE_SIZE)),
				"y":int(round(marker.position.y / TILE_SIZE))
			}
		})
	definitions.sort_custom(func(a: Dictionary, b: Dictionary): return a.plot_id < b.plot_id)
	return definitions

func layout_contract_valid() -> bool:
	var definitions := get_plot_definitions()
	if $TerrainGround.tile_set == null or $PlotStates.tile_set == null or $TerrainGround.get_used_cells().size() != 920:
		return false
	for anchor_name: String in ["PlayerSpawn","FieldApproach","BridgeWest","BridgeEast","HouseDoorInteract","HouseDoorArrival","VillagePathInteract"]:
		if get_anchor_position(anchor_name) == Vector2.INF:
			return false
	if definitions.size() != $FarmPlots.get_child_count() or definitions.is_empty():
		return false
	var ids: Dictionary = {}
	for definition: Dictionary in definitions:
		if ids.has(definition.plot_id):
			return false
		ids[definition.plot_id] = true
		var marker := _marker_for_plot(definition.plot_id)
		if marker == null:
			return false
		if not is_equal_approx(fmod(marker.position.x,TILE_SIZE),0.0) or not is_equal_approx(fmod(marker.position.y,TILE_SIZE),0.0):
			return false
	return true

func _marker_for_plot(plot_id: String) -> Marker2D:
	for child: Node in $FarmPlots.get_children():
		if child is Marker2D and String(child.get_meta("plot_id","")) == plot_id:
			return child as Marker2D
	return null

