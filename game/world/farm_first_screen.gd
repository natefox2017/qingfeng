extends Node2D
## Editable first-screen farm layout. This is engineering presentation, not final art.
## Plot coordinates are exported from Marker2D nodes in this scene; gameplay never
## owns a second copy of map geometry.

const TILE_SIZE := 16
const SPACE_ID := "space.farm"

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
			draw_rect(Rect2(marker.position-Vector2(7,7),Vector2(14,14)),Color("7f6542"))
