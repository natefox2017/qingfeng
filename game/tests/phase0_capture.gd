extends SceneTree
## Phase0 actual-renderer capture: new game -> playable farm at 1280 and 1920.
## Does not use the legacy collision fixture or claim art approval.
const MAIN = preload("res://app/main.tscn")
const FARM_CELL_COUNT := 6144
var output_dir := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or args.size() != 1:
		printerr("PHASE0_CAPTURE_FAIL requires graphical Godot and one output directory")
		quit(2)
		return
	output_dir = args[0]
	if not output_dir.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		printerr("PHASE0_CAPTURE_FAIL invalid output directory")
		quit(2)
		return
	run.call_deferred()

func _fail(reason: String) -> void:
	printerr("PHASE0_CAPTURE_FAIL " + reason)
	quit(1)

func run() -> void:
	create_timer(50.0).timeout.connect(func(): _fail("renderer timeout"))
	var app: Control = MAIN.instantiate()
	var isolated := "user://phase0_native_" + Crypto.new().generate_random_bytes(8).hex_encode()
	app.store.directory = isolated + "/saves"
	app.settings.path = isolated + "/settings.json"
	root.add_child(app)
	current_scene = app
	app.set_application_focused(true)
	app._on_action("new_game", {})
	if app.state != app.State.TITLE or app.view.player_name == null:
		_fail("new-game entry unavailable")
		return
	app.view.player_name.text = "小禾"
	app.view.dog_name.text = "阿豆"
	app._on_action("create", {})
	var ready := false
	for step in range(180):
		await physics_frame
		await process_frame
		if app.state == app.State.WORLD:
			ready = true
			break
		if app.state == app.State.TITLE and not String(app.last_error).is_empty():
			break
	if not ready or not is_instance_valid(app.room) or app.room.get_space_id() != "space.farm":
		_fail("new gameplay farm not ready: " + String(app.last_error))
		return
	var ground := app.room.get_node_or_null("TerrainGround") as TileMapLayer
	var player := app.room.get_player() as CharacterBody2D
	var sprite := player.get_node_or_null("Sprite2D") as Sprite2D
	if ground == null or ground.tile_set == null or ground.get_used_cells().size() != FARM_CELL_COUNT:
		_fail("missing native 6144-cell authored TileMapLayer")
		return
	if sprite == null or sprite.texture == null or sprite.texture.get_size() != Vector2(96, 128):
		_fail("missing four-direction player atlas")
		return
	if player.get_node_or_null("DiagnosticGlyph") != null:
		_fail("diagnostic square appeared in playable farm")
		return
	if app.gameplay_session.farm.get_plot("plot.farm.003").state != "mature":
		_fail("fresh gameplay must contain the real tutorial radish")
		return
	if not app.view.guide_panel.visible or not app.view.guide_label.text.contains("收获"):
		_fail("first harvest guidance is missing in native world")
		return
	# A real input-driven displacement confirms the active room, not a teleport pose.
	var starting_position: Vector2 = player.position
	Input.action_press("move_right")
	for step in range(8):
		await physics_frame
	Input.action_release("move_right")
	await physics_frame
	if player.position.x <= starting_position.x or sprite.frame_coords.y != 2:
		_fail("player did not physically walk east")
		return
	for size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		if image == null or image.get_size() != size:
			_fail("wrong native framebuffer size " + str(size))
			return
		var filename := "phase0_farm_%d.png" % size.x
		if image.save_png(output_dir.path_join(filename)) != OK:
			_fail("cannot write screenshot " + filename)
			return
		print("PHASE0_CAPTURE_IMAGE " + filename + " " + str(size))
	# A second image must prove the camera sees a different physical portion
	# of the authored farm. The real input traversal is separately tested by
	# res://tests/farm_exploration_test.gd, not simulated by this screenshot.
	root.size = Vector2i(1280,720)
	player.position = Vector2(828,668)
	for frame in range(3):
		await physics_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var camera := player.get_node("Camera2D") as Camera2D
	if camera.get_screen_center_position().x <= 640.0 or camera.get_screen_center_position().y <= 360.0:
		_fail("camera stayed on the original one-screen farm")
		return
	var expanded_image := root.get_texture().get_image()
	if expanded_image == null or expanded_image.get_size() != Vector2i(1280,720) or expanded_image.save_png(output_dir.path_join("phase0_farm_explore_1280.png")) != OK:
		_fail("expanded farm second-screen screenshot failed")
		return
	print("PHASE0_CAPTURE_IMAGE phase0_farm_explore_1280.png 1280x720")

	app.queue_free()
	await process_frame
	print("PHASE0_CAPTURE_PASS")
	quit(0)
