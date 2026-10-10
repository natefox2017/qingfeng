extends SceneTree
## Graphical captures of live editable entry pages. Save-list picture is an
## empty real-local-storage state, not the mockup's fabricated sample numbers.
const VIEW = preload("res://ui/pages/menu_view.gd")
var destination := ""
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if DisplayServer.get_name()=="headless" or args.size()!=1:
		printerr("ENTRY_CAPTURE_FAIL requires a graphical renderer and destination")
		quit(2)
		return
	destination = args[0]
	if not destination.is_absolute_path() or DirAccess.make_dir_recursive_absolute(destination)!=OK:
		printerr("ENTRY_CAPTURE_FAIL cannot make output directory")
		quit(2)
		return
	run.call_deferred()

func capture(view: Control, page: String, size: Vector2i) -> bool:
	root.size = size
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var window_size := DisplayServer.window_get_size()
	var image_size := img.get_size() if img != null else Vector2i.ZERO
	var integer_letterbox: bool = size == Vector2i(1366, 768) \
		and ProjectSettings.get_setting("display/window/stretch/scale_mode", "fractional") == "integer" \
		and image_size == Vector2i(1280, 720)
	if img == null or window_size != size or (image_size not in [size, size - Vector2i(1, 0)] and not integer_letterbox):
		print("ENTRY_NATIVE_CAPTURE_SIZE_MISMATCH requested=%s root=%s window=%s image=%s" % [str(size),str(root.size),str(window_size),str(image_size)])
		return false
	var suffix := "%dx%d" % [size.x,size.y]
	if integer_letterbox:
		suffix += "_content_%dx%d" % [image_size.x,image_size.y]
	elif image_size != size:
		suffix += "_render_%dx%d" % [image_size.x,image_size.y]
	var path := destination.path_join("entry_%s_%s.png" % [page,suffix])
	if img.save_png(path)!=OK:
		return false
	print("ENTRY_NATIVE_IMAGE ",path)
	return true

func run() -> void:
	root.get_node("AudioManager").shutdown_audio()
	await process_frame
	create_timer(35).timeout.connect(func(): printerr("ENTRY_CAPTURE_TIMEOUT");quit(1))
	var view := VIEW.new()
	root.add_child(view)
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1366,768)]:
		view.show_page("title",{"saves":[],"error":""})
		if not await capture(view,"title",size):
			quit(1)
			return
		view.show_page("new_game",{"player_name":"小禾","dog_name":"阿豆","error":""})
		if view.player_name==null or view.dog_name==null or not await capture(view,"new_game",size):
			quit(1)
			return
		view.show_page("load",{"saves":[],"error":""})
		if not await capture(view,"load",size):
			quit(1)
			return
	view.queue_free()
	await process_frame
	print("ENTRY_NATIVE_CAPTURE_PASS")
	quit(0)
