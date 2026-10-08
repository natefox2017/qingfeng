extends SceneTree
## Save/reload only a .tmp copy; never resave authored scene or resources.
const FARM = preload("res://world/farm_first_screen.tscn")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("MAP_EDITABILITY_FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func independent_object(node: Node) -> Node2D:
	for child: Node in node.get_children():
		if child is Node2D and not child.scene_file_path.is_empty() and not (child is CharacterBody2D):
			if not child.find_children("*", "CollisionShape2D", true, false).is_empty():
				return child
		var found := independent_object(child)
		if found != null: return found
	return null

func run() -> void:
	create_timer(20).timeout.connect(func(): printerr("MAP_EDITABILITY_TIMEOUT"); quit(1))
	var scene: Node2D = FARM.instantiate()
	root.add_child(scene)
	await physics_frame
	var ground := scene.get_node_or_null("TerrainGround") as TileMapLayer
	check(ground != null and ground.tile_set != null, "native ground layer")
	check(scene.get_node_or_null("GroundDetails") is TileMapLayer, "separate editable detail layer")
	if ground == null or ground.get_used_cells().is_empty():
		scene.queue_free()
		quit(1)
		return
	var source_cell: Vector2i = ground.get_used_cells()[0]
	var source_id := ground.get_cell_source_id(source_cell)
	var atlas := ground.get_cell_atlas_coords(source_cell)
	var alternative := ground.get_cell_alternative_tile(source_cell)
	var edited := source_cell
	ground.erase_cell(edited)
	var before: Rect2i = ground.get_used_rect()
	var expanded := Vector2i(before.end.x, before.position.y + 10)
	for x in range(4):
		for y in range(4):
			ground.set_cell(expanded + Vector2i(x,y), source_id, atlas, alternative)
	var object := independent_object(scene)
	check(object != null, "independent object scene owns collision")
	var object_path := NodePath("")
	var moved_position := Vector2.ZERO
	var collision_path := NodePath("")
	var collision_position := Vector2.ZERO
	var marker_positions: Dictionary = {}
	if object != null:
		object_path = scene.get_path_to(object)
		var shape: CollisionShape2D = object.find_children("*", "CollisionShape2D", true, false)[0]
		collision_path = scene.get_path_to(shape)
		collision_position = shape.global_position + Vector2(32,16)
		for marker: Node in object.find_children("*", "Marker2D", true, false):
			marker_positions[scene.get_path_to(marker)] = marker.global_position + Vector2(32,16)
		object.position += Vector2(32,16)
		moved_position = object.position
		await physics_frame
		check(shape.global_position == collision_position, "moving instance moves its collision by same offset")
		for marker: Node in object.find_children("*", "Marker2D", true, false):
			check(object.is_ancestor_of(marker) and marker.global_position == marker_positions[scene.get_path_to(marker)], "interaction marker moves with object")
	var tmp := ProjectSettings.globalize_path("res://../.tmp/map-qa/edited_farm.tscn")
	DirAccess.make_dir_recursive_absolute(tmp.get_base_dir())
	var packed := PackedScene.new()
	check(packed.pack(scene) == OK, "pack edited copy")
	check(ResourceSaver.save(packed, tmp) == OK, "save edited copy outside tracked world")
	scene.queue_free()
	await process_frame
	var saved := ResourceLoader.load(tmp, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	check(saved != null, "reload saved copy")
	if saved != null:
		var reloaded: Node2D = saved.instantiate()
		root.add_child(reloaded)
		await physics_frame
		var layer := reloaded.get_node("TerrainGround") as TileMapLayer
		check(layer.get_cell_source_id(edited) == -1, "single-cell edit survives runtime ready")
		check(layer.get_cell_source_id(expanded + Vector2i(3,3)) == source_id, "4x4 expansion survives save/reload")
		check(layer.get_used_rect().end.x >= before.end.x + 4, "expanded cells stay authored")
		# Cell persistence alone is not world expansion acceptance.
		if reloaded.has_method("get_world_bounds"):
			var bounds: Rect2i = reloaded.get_world_bounds()
			check(bounds.has_point(Vector2i(layer.map_to_local(expanded+Vector2i(3,3)))), "runtime bounds include expanded block")
		if object != null:
			check(reloaded.get_node(object_path).position == moved_position, "moved object persists")
			check(reloaded.get_node(collision_path).global_position == collision_position, "moved collision persists")
			for marker_path: NodePath in marker_positions:
				check(reloaded.get_node(marker_path).global_position == marker_positions[marker_path], "moved interaction marker persists")
		reloaded.queue_free()
		await process_frame
	print("MAP_EDITABILITY_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
