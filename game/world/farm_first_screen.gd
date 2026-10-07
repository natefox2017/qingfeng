extends Node2D
## Editable first-screen farm layout. This is engineering presentation, not final art.
## Plot coordinates are exported from Marker2D nodes in this scene; gameplay never
## owns a second copy of map geometry.

const TILE_SIZE := 16
const SPACE_ID := "space.farm"
const FARM_ACTION_RANGE_PX := 28.0
const FARM_ACTION_LATERAL_PX := 9.0

var _farm_states: Dictionary = {}

@onready var player: CharacterBody2D = $FootSorted/Player

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
	queue_redraw()
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

func _draw() -> void:
	# Diagnostic skin only. Accepted terrain/object art will replace these fills
	# without changing anchors, plot ids or collision nodes.
	draw_rect(Rect2(0,0,640,360),Color("7c9565"))
	draw_rect(Rect2(96,144,392,48),Color("b9a36c"))
	draw_rect(Rect2(456,192,152,32),Color("b9a36c"))
	draw_rect(Rect2(488,192,80,32),Color("9d7648"))
	for child: Node in $FarmPlots.get_children():
		if child is Marker2D:
			var marker := child as Marker2D
			var plot_id := String(marker.get_meta("plot_id",""))
			var state: Dictionary = _farm_states.get(plot_id,{})
			var plot_state := String(state.get("state","untilled"))
			var soil_color := Color("7f6542") if plot_state == "untilled" else Color("5f4935")
			draw_rect(Rect2(marker.position-Vector2(7,7),Vector2(14,14)),soil_color)
			if bool(state.get("is_watered",false)):
				draw_rect(Rect2(marker.position-Vector2(6,6),Vector2(12,12)),Color("5f7890"),false,2)
			if plot_state == "growing":
				draw_circle(marker.position,3.0,Color("4e7b47"))
			elif plot_state == "mature":
				draw_circle(marker.position,5.0,Color("8da44d"))
				draw_circle(marker.position,2.0,Color("d8c95b"))
