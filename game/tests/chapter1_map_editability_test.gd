extends SceneTree
## Save/reload only a .tmp copy; never resave authored scene or resources.
const FARM = preload("res://world/farm_first_screen.tscn")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	print("MAP_EDIT_CHECK ", ok, " ", label)
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

func body_contains(scene: Node2D, point: Vector2, body: StaticBody2D) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	for hit: Dictionary in scene.get_world_2d().direct_space_state.intersect_point(query, 16):
		if hit.rid == body.get_rid(): return true
	return false

func verify_bounds(scene: Node2D) -> void:
	var bounds: Rect2i = scene.get_world_bounds()
	var camera := scene.get_player().get_node("Camera2D") as Camera2D
	check(camera.limit_left == bounds.position.x and camera.limit_top == bounds.position.y and camera.limit_right == bounds.end.x and camera.limit_bottom == bounds.end.y, "camera follows authored expansion " + scene.get_space_id())
	for side: String in ["North", "South", "West", "East"]:
		var body := scene.get_node("Solids/" + side) as StaticBody2D
		var shape := body.get_node("CollisionShape2D").shape as RectangleShape2D
		var horizontal := side in ["North", "South"]
		check(shape.size == Vector2(bounds.size.x,16) if horizontal else shape.size == Vector2(16,bounds.size.y), "perimeter shape follows extent " + side)
		var expected := Vector2(bounds.get_center())
		match side:
			"North": expected.y = bounds.position.y + 8
			"South": expected.y = bounds.end.y - 8
			"West": expected.x = bounds.position.x + 8
			"East": expected.x = bounds.end.x - 8
		check(body.position == expected and body_contains(scene,expected,body), "actual perimeter collision follows extent " + side)

func verify_village_copy() -> void:
	var resource := load("res://world/village_first_screen.tscn") as PackedScene
	var village := resource.instantiate() as Node2D
	root.add_child(village)
	await physics_frame
	for layer_name: String in ["TerrainGround", "GroundPaths", "GroundDetails"]:
		check(village.get_node_or_null(layer_name) is TileMapLayer, "village authored layer " + layer_name)
	var ground := village.get_node("TerrainGround") as TileMapLayer
	var cell: Vector2i = ground.get_used_cells()[0]
	var source := ground.get_cell_source_id(cell)
	var atlas := ground.get_cell_atlas_coords(cell)
	var expanded := Vector2i(ground.get_used_rect().end.x, 10)
	ground.erase_cell(cell)
	for x in range(4):
		for y in range(4): ground.set_cell(expanded+Vector2i(x,y), source, atlas)
	village.refresh_world_layout()
	await physics_frame
	verify_bounds(village)
	var tmp := ProjectSettings.globalize_path("res://../.tmp/map-qa/edited_village.tscn")
	var packed := PackedScene.new()
	check(packed.pack(village)==OK and ResourceSaver.save(packed,tmp)==OK, "village edited copy saved")
	village.queue_free()
	await process_frame
	var saved := ResourceLoader.load(tmp, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var reloaded := saved.instantiate() as Node2D
	root.add_child(reloaded)
	await physics_frame
	var layer := reloaded.get_node("TerrainGround") as TileMapLayer
	check(layer.get_cell_source_id(cell)==-1 and layer.get_cell_source_id(expanded+Vector2i(3,3))==source, "village edited cell and extension survive runtime reload")
	verify_bounds(reloaded)
	reloaded.queue_free()
	await process_frame

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
	var object := scene.get_node_or_null("Farmhouse") as Node2D
	if object == null: object = independent_object(scene)
	check(object != null, "independent object scene owns collision")
	var object_path := NodePath("")
	var moved_position := Vector2.ZERO
	var collision_path := NodePath("")
	var collision_position := Vector2.ZERO
	var marker_positions: Dictionary = {}
	var old_left_edge := Vector2.ZERO
	if object != null:
		print("MAP_EDIT_OBJECT ", object.name, " markers=", object.find_children("*", "Marker2D", true, false).size())
		object_path = scene.get_path_to(object)
		var shape: CollisionShape2D = object.find_children("*", "CollisionShape2D", true, false)[0]
		collision_path = scene.get_path_to(shape)
		collision_position = shape.global_position + Vector2(32,16)
		var rect := shape.shape as RectangleShape2D
		old_left_edge = shape.global_position - Vector2(rect.size.x/2.0-2,0)
		for marker: Node in object.find_children("*", "Marker2D", true, false):
			marker_positions[scene.get_path_to(marker)] = marker.global_position + Vector2(32,16)
		object.position += Vector2(32,16)
		moved_position = object.position
		await physics_frame
		check(shape.global_position == collision_position, "moving instance moves its collision by same offset")
		var body := shape.get_parent() as StaticBody2D
		check(body_contains(scene,collision_position,body) and not body_contains(scene,old_left_edge,body), "physics collider moves and vacates old footprint edge")
		for marker: Node in object.find_children("*", "Marker2D", true, false):
			check(object.is_ancestor_of(marker) and marker.global_position == marker_positions[scene.get_path_to(marker)], "interaction marker moves with object")
	var had_object := object != null
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
			verify_bounds(reloaded)
			var player: CharacterBody2D = reloaded.get_player()
			# Isolated physics fixture only: place at old edge, then walk into extension.
			player.position = Vector2(before.end.x*16-28, expanded.y*16+24)
			reloaded.set_input_enabled(true)
			Input.action_press("move_right")
			for tick in range(40): await physics_frame
			Input.action_release("move_right")
			await physics_frame
			check(player.position.x > before.end.x*16+16, "physics movement crosses former perimeter into new block")
		if had_object:
			check(reloaded.get_node(object_path).position == moved_position, "moved object persists")
			check(reloaded.get_node(collision_path).global_position == collision_position, "moved collision persists")
			var house_marker := reloaded.get_node_or_null("Farmhouse/HouseDoorInteract") as Marker2D
			if house_marker != null:
				reloaded.get_player().position = house_marker.global_position + Vector2(0,20)
				reloaded.get_player().facing = &"north"
				check(reloaded.resolve_interaction_target().get("interaction_id", "") == "door.farm.house", "moved house marker resolves real door after reload")
			for marker_path: NodePath in marker_positions:
				check(reloaded.get_node(marker_path).global_position == marker_positions[marker_path], "moved interaction marker persists")
		reloaded.queue_free()
		await process_frame
	await verify_village_copy()
	print("MAP_EDITABILITY_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
