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

func _ready() -> void:
	refresh_world_layout()

func refresh_world_layout() -> void:
	var bounds := _get_used_cell_bounds()
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return
	var pixel_left := bounds.position.x * TILE_SIZE
	var pixel_top := bounds.position.y * TILE_SIZE
	var pixel_right := bounds.end.x * TILE_SIZE
	var pixel_bottom := bounds.end.y * TILE_SIZE
	var width := pixel_right - pixel_left
	var height := pixel_bottom - pixel_top
	var camera := $FootSorted/Player/Camera2D as Camera2D
	camera.limit_left = pixel_left
	camera.limit_top = pixel_top
	camera.limit_right = pixel_right
	camera.limit_bottom = pixel_bottom
	_set_boundary("North", Vector2(pixel_left + width * 0.5, pixel_top + 8), Vector2(width, 16))
	_set_boundary("South", Vector2(pixel_left + width * 0.5, pixel_bottom - 8), Vector2(width, 16))
	_set_boundary("West", Vector2(pixel_left + 8, pixel_top + height * 0.5), Vector2(16, height))
	_set_boundary("East", Vector2(pixel_right - 8, pixel_top + height * 0.5), Vector2(16, height))

func _get_used_cell_bounds() -> Rect2i:
	var bounds := Rect2i()
	var has_bounds := false
	for child: Node in get_children():
		if child is TileMapLayer and child.name != "PlotStates":
			var layer_bounds := (child as TileMapLayer).get_used_rect()
			if layer_bounds.size.x <= 0 or layer_bounds.size.y <= 0:
				continue
			bounds = layer_bounds if not has_bounds else bounds.merge(layer_bounds)
			has_bounds = true
	return bounds if has_bounds else Rect2i()

func _set_boundary(node_name: String, world_position: Vector2, size: Vector2) -> void:
	var body := get_node("Solids/" + node_name) as StaticBody2D
	body.position = world_position
	var shape := body.get_node("CollisionShape2D").shape as RectangleShape2D
	shape.size = size

func set_input_enabled(enabled: bool) -> void:
	player.set_input_enabled(enabled)

func get_player() -> CharacterBody2D:
	return player

func get_space_id() -> String:
	return SPACE_ID

func get_world_bounds() -> Rect2i:
	var cell_bounds := _get_used_cell_bounds()
	return Rect2i(cell_bounds.position * TILE_SIZE, cell_bounds.size * TILE_SIZE)

func get_spawn_position() -> Vector2:
	return $Anchors/PlayerSpawn.position

func get_anchor_position(anchor_name: String) -> Vector2:
	var node := _anchor(anchor_name)
	return node.global_position if node is Marker2D else Vector2.INF

func _anchor(anchor_name: String) -> Marker2D:
	var node := $Anchors.get_node_or_null(NodePath(anchor_name)) as Marker2D
	if node == null:
		node = $Farmhouse.get_node_or_null(NodePath(anchor_name)) as Marker2D
	return node

func resolve_interaction_target() -> Dictionary:
	if _marker_reachable(_anchor("HouseDoorInteract")):
		return {
			"kind":"door",
			"interaction_id":"door.farm.house",
			"target_space_id":"space.house",
			"arrival_anchor_id":"DoorArrival",
			"arrival_facing":"north"
		}
	if _marker_reachable(_anchor("VillagePathInteract")):
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
		var source_id := 1
		var atlas := Vector2i(1,0)
		match state:
			"tilled":
				atlas = Vector2i(3,0) if bool(row.get("is_watered",false)) else Vector2i(2,0)
			"growing":
				source_id = 3
				atlas = Vector2i(3,2)
			"mature":
				source_id = 3
				atlas = Vector2i(4,2)
		var cell := Vector2i(int(round(marker.position.x/TILE_SIZE)),int(round(marker.position.y/TILE_SIZE)))
		plot_tiles.set_cell(cell,source_id,atlas,0)
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
	refresh_world_layout()
	var definitions := get_plot_definitions()
	if $TerrainGround.tile_set == null or $PlotStates.tile_set != $TerrainGround.tile_set:
		return false
	var world_bounds := get_world_bounds()
	if world_bounds.size.x <= 0 or world_bounds.size.y <= 0:
		return false
	var camera := get_node_or_null("FootSorted/Player/Camera2D") as Camera2D
	if camera == null or camera.limit_left != world_bounds.position.x or camera.limit_top != world_bounds.position.y or camera.limit_right != world_bounds.end.x or camera.limit_bottom != world_bounds.end.y:
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
