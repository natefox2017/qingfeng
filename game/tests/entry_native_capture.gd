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

func capture(view: Control, page: String) -> bool:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img==null or img.get_size()!=Vector2i(1280,720):
		return false
	var path := destination.path_join("entry_%s_1280.png" % page)
	if img.save_png(path)!=OK:
		return false
	print("ENTRY_NATIVE_IMAGE ",path)
	return true

func run() -> void:
	create_timer(35).timeout.connect(func(): printerr("ENTRY_CAPTURE_TIMEOUT");quit(1))
	root.size = Vector2i(1280,720)
	var view := VIEW.new()
	root.add_child(view)
	view.show_page("title",{"saves":[],"error":""})
	if not await capture(view,"title"):
		quit(1)
		return
	view.show_page("new_game",{"player_name":"小禾","dog_name":"阿豆","error":""})
	if view.player_name==null or view.dog_name==null or not await capture(view,"new_game"):
		quit(1)
		return
	view.show_page("load",{"saves":[],"error":""})
	if not await capture(view,"load"):
		quit(1)
		return
	view.queue_free()
	await process_frame
	print("ENTRY_NATIVE_CAPTURE_PASS")
	quit(0)
