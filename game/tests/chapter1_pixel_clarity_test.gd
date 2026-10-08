extends SceneTree
## Graphical-only pixel clarity recorder. Drive the visible game window with
## keyboard input while it samples the actual player and Camera2D positions.
const MAIN := preload("res://app/main.tscn")

var output_dir := ""
var duration_seconds := 40.0
var require_motion := true

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" or args.size() < 1 or args.size() > 3:
		printerr("PIXEL_CLARITY_FAIL requires graphical Godot, output directory, optional duration and capture_only flag")
		quit(2)
		return
	output_dir = args[0]
	if args.size() == 2:
		duration_seconds = maxf(float(args[1]), 1.0)
	elif args.size() == 3:
		duration_seconds = maxf(float(args[1]), 1.0)
		require_motion = args[2] != "capture_only"
	if not output_dir.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		printerr("PIXEL_CLARITY_FAIL invalid output directory")
		quit(2)
		return
	record.call_deferred()

func record() -> void:
	var app: Control = MAIN.instantiate()
	var isolated_dir := "user://pixel_clarity_" + str(Time.get_ticks_usec())
	app.store.directory = isolated_dir + "/saves"
	app.settings.path = isolated_dir + "/settings.json"
	root.add_child(app)
	current_scene = app
	app.set_application_focused(true)
	app._on_action("new_game", {})
	if app.state != app.State.TITLE or app.view.player_name == null:
		_fail("new-game setup did not initialize")
		return
	app.view.player_name.text = "清晰度测试"
	app.view.dog_name.text = "阿豆"
	app._on_action("create", {})
	var ready := false
	for _frame in range(300):
		await physics_frame
		await process_frame
		if app.state == app.State.WORLD and is_instance_valid(app.room):
			ready = true
			break
	if not ready or app.room.get_space_id() != "space.farm":
		_fail("isolated farm session did not reach the world: " + String(app.last_error))
		return
	await RenderingServer.frame_post_draw
	var player := app.room.get_player() as CharacterBody2D
	var camera := player.get_node("Camera2D") as Camera2D
	var sprite := player.get_node("Sprite2D") as Sprite2D
	var ground := app.room.get_node("TerrainGround") as TileMapLayer
	var root_window := root as Window
	var started_ms := Time.get_ticks_msec()
	var samples: Array[Dictionary] = []
	print("PIXEL_CLARITY_READY window=%s viewport=%s mode=%s aspect=%s scale_mode=%s duration_s=%.1f" % [
		str(DisplayServer.window_get_size()), str(root_window.size),
		str(ProjectSettings.get_setting("display/window/stretch/mode", "unset")),
		str(ProjectSettings.get_setting("display/window/stretch/aspect", "unset")),
		str(ProjectSettings.get_setting("display/window/stretch/scale_mode", "unset")),
		duration_seconds,
	])
	print("PIXEL_CLARITY_INPUTS nearest_enum=%d linear_enum=%d tile_filter=%d player_filter=%d default_filter=%s snap_transforms=%s snap_vertices=%s camera_zoom=%s camera_smoothing=%s" % [
		CanvasItem.TEXTURE_FILTER_NEAREST, CanvasItem.TEXTURE_FILTER_LINEAR,
		ground.texture_filter, sprite.texture_filter,
		str(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", "unset")),
		str(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false)),
		str(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel", false)),
		str(camera.zoom), str(camera.position_smoothing_enabled),
	])
	print("PIXEL_CLARITY_SAVE_DIR " + isolated_dir)
	while float(Time.get_ticks_msec() - started_ms) / 1000.0 < duration_seconds:
		samples.append({
			"t_seconds": snappedf(float(Time.get_ticks_msec() - started_ms) / 1000.0, 0.01),
			"player_global": _vec(player.global_position),
			"camera_center": _vec(camera.get_screen_center_position()),
			"camera_offset": _vec(camera.offset),
		})
		await create_timer(0.25).timeout
	var player_points: Array[Vector2] = []
	var camera_points: Array[Vector2] = []
	for sample: Dictionary in samples:
		player_points.append(Vector2(sample.player_global[0], sample.player_global[1]))
		camera_points.append(Vector2(sample.camera_center[0], sample.camera_center[1]))
	var player_range := _range(player_points)
	var camera_range := _range(camera_points)
	var report := {
		"engine": Engine.get_version_info(),
		"window_size": [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y],
		"root_viewport_size": [root_window.size.x, root_window.size.y],
		"content_scale_mode": root_window.content_scale_mode,
		"content_scale_aspect": root_window.content_scale_aspect,
		"content_scale_size": [root_window.content_scale_size.x, root_window.content_scale_size.y],
		"content_scale_factor": root_window.content_scale_factor,
		"stretch_mode": ProjectSettings.get_setting("display/window/stretch/mode", "unset"),
		"stretch_aspect": ProjectSettings.get_setting("display/window/stretch/aspect", "unset"),
		"stretch_scale_mode": ProjectSettings.get_setting("display/window/stretch/scale_mode", "unset"),
		"texture_filter_nearest_enum": CanvasItem.TEXTURE_FILTER_NEAREST,
		"texture_filter_linear_enum": CanvasItem.TEXTURE_FILTER_LINEAR,
		"terrain_texture_filter": ground.texture_filter,
		"player_texture_filter": sprite.texture_filter,
		"default_texture_filter": ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", "unset"),
		"snap_2d_transforms_to_pixel": ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel", false),
		"snap_2d_vertices_to_pixel": ProjectSettings.get_setting("rendering/2d/snap/snap_2d_vertices_to_pixel", false),
		"camera_zoom": [camera.zoom.x, camera.zoom.y],
		"camera_smoothing_enabled": camera.position_smoothing_enabled,
		"duration_seconds": float(Time.get_ticks_msec() - started_ms) / 1000.0,
		"motion_required": require_motion,
		"sample_count": samples.size(),
		"player_x_range": player_range.x,
		"player_y_range": player_range.y,
		"camera_x_range": camera_range.x,
		"camera_y_range": camera_range.y,
		"samples": samples,
	}
	var file := FileAccess.open(output_dir.path_join("runtime.json"), FileAccess.WRITE)
	if file == null:
		_fail("cannot write runtime.json")
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if require_motion and player_range.x < 32.0 and player_range.y < 32.0:
		_fail("visible keyboard walk did not move the player: " + str(player_range))
		return
	if require_motion and camera_range.x < 16.0 and camera_range.y < 16.0:
		_fail("Camera2D did not scroll during visible keyboard input: " + str(camera_range))
		return
	print("PIXEL_CLARITY_PASS duration_s=%.2f samples=%d player_range=%s camera_range=%s report=%s" % [
		report.duration_seconds, samples.size(), str(player_range), str(camera_range), output_dir.path_join("runtime.json")
	])
	quit(0)

func _vec(value: Vector2) -> Array[float]:
	return [snappedf(value.x, 0.01), snappedf(value.y, 0.01)]

func _range(points: Array[Vector2]) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	var minimum := points[0]
	var maximum := points[0]
	for point: Vector2 in points:
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	return maximum - minimum

func _fail(reason: String) -> void:
	printerr("PIXEL_CLARITY_FAIL " + reason)
	quit(1)
