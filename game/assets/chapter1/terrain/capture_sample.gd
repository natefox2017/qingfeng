extends SceneTree
## Real renderer evidence for the isolated art sample, not gameplay acceptance.
func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Graphical renderer required")
		quit(2)
		return
	run.call_deferred()

func run() -> void:
	# Art capture has no audio interaction; release the autoload's MP3 before exit.
	root.get_node("AudioManager").shutdown_audio()
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 1 and args[0].is_absolute_path())
	var sample: Node2D = load("res://assets/chapter1/terrain/terrain_sample.tscn").instantiate()
	root.add_child(sample)
	assert(sample.get_node("TerrainGround").get_used_cells().size() == 920)
	for size: Vector2i in [Vector2i(640, 360), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		assert(image != null and image.get_size() == size)
		var path: String = args[0].path_join("godot_terrain_%d.png" % size.x)
		assert(image.save_png(path) == OK)
		print("TERRAIN_CAPTURE ", path, " ", size)
	sample.queue_free()
	await process_frame
	print("TERRAIN_CAPTURE_PASS renderer=", DisplayServer.get_name(), " version=", Engine.get_version_info().string)
	quit(0)
