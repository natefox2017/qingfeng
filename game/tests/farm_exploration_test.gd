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
	check(tiles.get_used_cells().size()==6144 and tiles.get_used_rect()==Rect2i(0,0,96,64),
		"editable authored map extends to 1536 by 1024 world pixels")
	check(camera.limit_right==1536 and camera.limit_bottom==1024 and camera.enabled,
		"camera bounds cover the entire world rather than one screen")
	check(scene.get_spawn_position()==Vector2(144,176),"legacy save and front door spawn stay fixed")
	check(scene.layout_contract_valid(),"expanded scene retains authoritative plot and door contract")
	check(tiles.get_cell_source_id(Vector2i(92,59))==0,"distant map chunks are real editable TileMapLayer cells")
	check(tiles.get_cell_atlas_coords(Vector2i(30,40)).y==1 and tiles.get_cell_atlas_coords(Vector2i(35,43)).y==1,
		"southern bridge deck uses the existing plank atlas across the walk lane")
	check(details.get_cell_atlas_coords(Vector2i(30,40))==Vector2i(7,3)
		and details.get_cell_atlas_coords(Vector2i(35,43))==Vector2i(7,3),
		"southern bridge has visible rails at both banks")

	player.set_input_enabled(true)
	Input.action_press("move_down")
	for frame in range(310):
		await physics_frame
	Input.action_release("move_down")
	await physics_frame
	check(player.position.y>620.0 and player.position.y<710.0,
		"real movement reaches southern second-bridge approach through multiple screens")
	var before_bridge := player.position
	Input.action_press("move_right")
	for frame in range(460):
		await physics_frame
	Input.action_release("move_right")
	await physics_frame
	check(player.position.x>760.0 and player.position.distance_to(before_bridge)>520,
		"player physically crosses the railed southern bridge into the eastern meadow")
	check(camera.get_screen_center_position().x>600.0,
		"camera really tracks beyond old 640px screen boundary")
	check(player.is_input_enabled and player.velocity.is_zero_approx(),
		"actor remains controllable after crossing (no soft lock)")

	player.set_input_enabled(false)
	scene.queue_free()
	await process_frame
	print("FARM_EXPLORATION_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
