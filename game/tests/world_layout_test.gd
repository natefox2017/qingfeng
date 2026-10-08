extends SceneTree

const FARM_SCENE = preload("res://world/farm_first_screen.tscn")
const HOUSE_SCENE = preload("res://world/house_interior.tscn")

var checks := 0
var failures := 0
var scene: Node2D

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL world ", label)

func _blocked(point: Vector2) -> bool:
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.collision_mask = 1
	query.transform = Transform2D(0.0,point)
	return not scene.get_world_2d().direct_space_state.intersect_shape(query,8).is_empty()

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(15).timeout.connect(func(): printerr("WORLD_TIMEOUT"); quit(1))
	scene = FARM_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame

	check(scene.has_method("get_plot_definitions") and scene.has_method("get_space_id"), "farm scene exposes world layout contract")
	check(scene.get_space_id() == "space.farm", "first screen uses stable farm space id")
	check(scene.layout_contract_valid(), "plot markers are unique and tile aligned")
	var plots: Array = scene.get_plot_definitions()
	check(plots.size() == 6, "first screen exposes six editable farm plots")
	var expected_ids := ["plot.farm.001","plot.farm.002","plot.farm.003","plot.farm.004","plot.farm.005","plot.farm.006"]
	var ids: Array = plots.map(func(plot): return plot.plot_id)
	check(ids == expected_ids, "plot ids remain deterministic after scene traversal")
	check(plots[0].cell_position == {"x":30,"y":20} and plots[-1].cell_position == {"x":66,"y":32}, "plot cells derive from scene marker positions")

	var spawn: Vector2 = scene.get_spawn_position()
	check(scene.get_player().position == spawn and not _blocked(spawn), "player spawn is the same editable anchor and is collision safe")
	for anchor_name: String in ["FieldApproach","BridgeWest","BridgeEast"]:
		var point: Vector2 = scene.get_anchor_position(anchor_name)
		check(point != Vector2.INF and not _blocked(point), anchor_name+" remains walkable")
	for plot: Dictionary in plots:
		var point: Vector2 = Vector2(plot.cell_position.x,plot.cell_position.y) * float(scene.TILE_SIZE)
		check(not _blocked(point), plot.plot_id+" is not covered by world collision")
	check(_blocked(Vector2(220,464)), "moved farmhouse walls block movement")
	check(_blocked(Vector2(64,48)), "orchard root has its own physical footprint")
	check(_blocked(Vector2(1408,512)) and _blocked(Vector2(1536,512)), "river banks block movement outside bridge approaches")
	check(not _blocked(Vector2(1472,432)), "bridge lane remains physically passable")
	check(not _blocked(Vector2(144,176)), "legacy save spawn remains physically recoverable")
	var orchard_columns := [Vector2(64,48),Vector2(200,48),Vector2(336,48),Vector2(472,48),
		Vector2(64,160),Vector2(200,160),Vector2(336,160),Vector2(472,160),
		Vector2(64,272),Vector2(200,272),Vector2(336,272),Vector2(472,272)]
	var orchard_matches := true
	for index in range(1, 13):
		var tree := scene.get_node("FootSorted/OrchardOak%02d" % index) as Node2D
		var root_position: Vector2 = tree.get_node("Footprint").global_position
		var sprite_position: Vector2 = tree.get_node("Sprite2D").global_position
		var sprite_offset: Vector2 = tree.get_node("Sprite2D").offset
		if root_position != orchard_columns[index - 1] or sprite_position != root_position or sprite_offset != Vector2(-48, -126):
			orchard_matches = false
	check(orchard_matches, "reusable oak sprites and collision roots form the authored orchard rows")

	scene.set_input_enabled(false)
	check(not scene.get_player().is_input_enabled, "world input can be disabled by app lifecycle")
	scene.set_input_enabled(true)
	check(scene.get_player().is_input_enabled, "world input can be re-enabled without replacing player")
	check(not _blocked(scene.get_anchor_position("HouseDoorArrival")), "farm house-door arrival is explicit and collision safe")
	check(not _blocked(scene.get_anchor_position("HouseDoorInteract")), "farm house-door interaction marker remains outside house collision")
	check(scene.get_anchor_position("VillagePathArrival") == Vector2(896,104), "north village route has a separate return arrival anchor")

	scene.queue_free()
	await process_frame
	scene = HOUSE_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	check(scene.get_space_id() == "space.house" and scene.layout_contract_valid(), "house interior exposes valid stable world contract")
	check(scene.get_spawn_position() == Vector2(320,320) and not _blocked(Vector2(320,320)), "house arrival anchor is collision safe")
	check(not _blocked(scene.get_anchor_position("DoorInteract")), "house door interaction marker is walkable")
	check(not _blocked(scene.get_anchor_position("BedInteract")), "future bed interaction marker is reachable outside bed collision")
	check(_blocked(Vector2(236,112)) and _blocked(Vector2(424,160)), "house bed and table footprints block movement")
	check(not _blocked(Vector2(320,352)), "house south door gap is physically passable")

	finish()

func finish() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
	print("WORLD_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
