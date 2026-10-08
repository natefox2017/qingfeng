extends SceneTree
## P0 actual input walk across multiple screens (not a teleport screenshot).
## This test must fail if the scene is the old 640×360 one-screen room.

const FARM = preload("res://world/farm_first_screen.tscn")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("CHECK_FAIL farm_exploration ", label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(40.0).timeout.connect(func(): printerr("FARM_EXPLORATION_TIMEOUT");quit(1))
	var scene := FARM.instantiate() as Node2D
	root.add_child(scene)
	current_scene = scene
	await physics_frame
	var player := scene.get_player() as CharacterBody2D
	var camera := player.get_node("Camera2D") as Camera2D
	var tiles := scene.get_node("TerrainGround") as TileMapLayer
	var details := scene.get_node("GroundDetails") as TileMapLayer
	check(tiles.get_used_cells().size()==7168 and tiles.get_used_rect()==Rect2i(0,0,112,64),
		"editable authored map extends to 1792 by 1024 world pixels")
	check(camera.limit_right==1792 and camera.limit_bottom==1024 and camera.enabled,
		"camera bounds cover the entire world rather than one screen")
	check(scene.get_spawn_position()==Vector2(320,560),"new player spawn is in the farmhouse courtyard")
	check(scene.layout_contract_valid(),"expanded scene retains authoritative plot and door contract")
	check(tiles.get_cell_source_id(Vector2i(108,60))==0,"distant map chunks are real editable TileMapLayer cells")
	var water := scene.get_node("RiverWater") as TileMapLayer
	check(water.get_used_cells().size()==480 and water.get_cell_source_id(Vector2i(92,40))==0,
		"east river is an editable native TileMapLayer")
	check(scene.get_node("FootSorted/RiverBridgeSouth") is Node2D and scene.get_node("FootSorted/SouthEastDock") is Node2D,
		"bridge and downstream dock are independent editable objects")
	check(scene.get_anchor_position("BridgeWest")==Vector2(1392,432)
		and scene.get_anchor_position("BridgeEast")==Vector2(1552,432),
		"bridge interaction anchors follow the moved crossing")

	player.set_input_enabled(true)
	# The expanded courtyard keeps the spawn but its authored south gate is
	# centered at x272. Leave through that visible opening, not through rails.
	Input.action_press("move_left")
	for frame in range(30):
		await physics_frame
	Input.action_release("move_left")
	await physics_frame
	check(absf(player.position.x-272.0)<4.0, "real movement aligns with the authored courtyard gate")
	Input.action_press("move_down")
	for frame in range(135):
		await physics_frame
	Input.action_release("move_down")
	await physics_frame
	check(player.position.y>740.0 and player.position.y<800.0,
		"real movement reaches the lower bridge approach through multiple screens")
	var before_bridge := player.position
	Input.action_press("move_right")
	for frame in range(820):
		await physics_frame
	Input.action_release("move_right")
	await physics_frame
	check(player.position.x>1552.0 and player.position.distance_to(before_bridge)>1200,
		"player physically crosses the railed bridge to the eastern forest bank")
	check(camera.get_screen_center_position().x>600.0,
		"camera really tracks beyond old 640px screen boundary")
	check(player.is_input_enabled and player.velocity.is_zero_approx(),
		"actor remains controllable after crossing (no soft lock)")

	player.set_input_enabled(false)
	scene.queue_free()
	await process_frame
	print("FARM_EXPLORATION_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
