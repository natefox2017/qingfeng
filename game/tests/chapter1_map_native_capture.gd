extends SceneTree
## Renderer evidence, not interactive acceptance. No simulated screenshot/art.
const FARM = preload("res://world/farm_first_screen.tscn")
const VILLAGE = preload("res://world/village_first_screen.tscn")
var output_dir := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].is_absolute_path() or DisplayServer.get_name() == "headless":
		printerr("MAP_NATIVE_CAPTURE requires native renderer and absolute output directory")
		quit(2)
		return
	output_dir = args[0]
	DirAccess.make_dir_recursive_absolute(output_dir)
	run.call_deferred()

func capture(scene: Node2D, region: String, size: Vector2i) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	var pixels := root.get_texture().get_image()
	var window_size := DisplayServer.window_get_size()
	var image_size := pixels.get_size() if pixels != null else Vector2i.ZERO
	var integer_letterbox: bool = size == Vector2i(1366, 768) \
		and ProjectSettings.get_setting("display/window/stretch/scale_mode", "fractional") == "integer" \
		and image_size == Vector2i(1280, 720)
	if pixels == null or window_size != size or (image_size not in [size, size - Vector2i(1, 0)] and not integer_letterbox):
		printerr("MAP_NATIVE_CAPTURE_SIZE_MISMATCH requested=%s window=%s image=%s" % [str(size),str(window_size),str(image_size)])
		return false
	var suffix := "%dx%d" % [size.x,size.y]
	if integer_letterbox:
		suffix += "_content_%dx%d" % [image_size.x,image_size.y]
	elif image_size != size:
		suffix += "_render_%dx%d" % [image_size.x,image_size.y]
	var name := "%s_%s_%s.png" % [scene.get_space_id().replace(".","_"),region,suffix]
	if pixels.save_png(output_dir.path_join(name)) != OK:
		printerr("MAP_NATIVE_CAPTURE_FAIL ", name)
		return false
	print("MAP_NATIVE_CAPTURE_IMAGE ",name)
	return true

func run() -> void:
	root.get_node("AudioManager").shutdown_audio()
	await process_frame
	create_timer(30).timeout.connect(func(): printerr("MAP_NATIVE_CAPTURE_TIMEOUT"); quit(1))
	for resource: PackedScene in [FARM,VILLAGE]:
		var scene: Node2D = resource.instantiate()
		root.add_child(scene)
		current_scene = scene
		await physics_frame
		scene.set_input_enabled(false)
		var camera := scene.get_node("FootSorted/Player/Camera2D") as Camera2D
		camera.position_smoothing_enabled = false
		var arrival_position: Vector2 = camera.global_position
		var focus_position: Vector2 = Vector2(960, 624) if scene.get_space_id() == "space.farm" else Vector2(640, 328)
		for size in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1366,768)]:
			root.size = size
			camera.global_position = arrival_position
			camera.force_update_scroll()
			if not await capture(scene,"arrival",size):
				quit(1)
				return
			camera.global_position = focus_position
			camera.force_update_scroll()
			if not await capture(scene,"focus",size):
				quit(1)
				return
		scene.queue_free()
		await process_frame
	root.get_node("AudioManager").shutdown_audio()
	await process_frame
	print("MAP_NATIVE_CAPTURE_RESULT rendered_only=true")
	quit(0)
