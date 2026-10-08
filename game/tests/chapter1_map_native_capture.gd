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
		for size in [Vector2i(640,360),Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size = size
			await process_frame
			await RenderingServer.frame_post_draw
			var pixels := root.get_texture().get_image()
			var name := "%s_%d.png" % [scene.get_space_id().replace(".","_"), size.x]
			if pixels == null or pixels.get_size() != size or pixels.save_png(output_dir.path_join(name)) != OK:
				printerr("MAP_NATIVE_CAPTURE_FAIL ", name)
				quit(1)
				return
			print("MAP_NATIVE_CAPTURE_IMAGE ",name)
		scene.queue_free()
		await process_frame
	root.get_node("AudioManager").shutdown_audio()
	await process_frame
	print("MAP_NATIVE_CAPTURE_RESULT rendered_only=true")
	quit(0)
