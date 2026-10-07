extends SceneTree
## Native fixture evidence. Never a farm-art or full gameplay acceptance capture.
var app: Control
var output_directory: String

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or DisplayServer.get_name() == "headless":
		printerr("Usage: render with -- <output-directory>")
		quit(2)
		return
	output_directory = args[0]
	if DirAccess.make_dir_recursive_absolute(output_directory) != OK:
		quit(2)
		return
	root.size = Vector2i(1280, 720)
	run.call_deferred()

func frame_steps(count: int) -> void:
	for tick in range(count):
		await physics_frame

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output_directory.path_join(label + ".png")) == OK)

func move(key: Key, count: int) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = key
	press.pressed = true
	Input.parse_input_event(press)
	await frame_steps(count)
	var release := InputEventKey.new()
	release.physical_keycode = key
	release.pressed = false
	Input.parse_input_event(release)
	await frame_steps(2)

func run() -> void:
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	current_scene = app
	await frame_steps(5)
	await capture("title_1280")
	app.start_button.pressed.emit()
	for tick in range(180):
		await process_frame
		if app.state == app.State.WORLD:
			break
	assert(app.state == app.State.WORLD)
	app.set_application_focused(true)
	await frame_steps(2)
	await capture("room_1280")
	# Actual key-input route around the wall and through the opening, not teleport.
	await move(KEY_DOWN, 140)
	await move(KEY_RIGHT, 110)
	await move(KEY_UP, 100)
	await move(KEY_RIGHT, 80)
	var player: CharacterBody2D = app.room.get_player()
	assert(player.position.x > 340, "Physical arrow route did not pass the opening")
	await capture("after_route_1280")
	app.set_pause_menu(true)
	await capture("pause_1280")
	root.size = Vector2i(1920, 1080)
	await frame_steps(5)
	await capture("pause_1920")
	app.return_to_title()
	await capture("returned_title_1920")
	app.queue_free()
	await process_frame
	print("NATIVE_FOUNDATION_CAPTURE_PASS")
	quit()
