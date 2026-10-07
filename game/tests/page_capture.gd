extends SceneTree
## Actual renderer capture; no generated art. Directory explicitly supplied.
var app: Control
var output: String
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or DisplayServer.get_name()=="headless":quit(2);return
	output=args[0];DirAccess.make_dir_recursive_absolute(output)
	run.call_deferred()
func capture(name:String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK)
func run() -> void:
	app=load("res://app/main.tscn").instantiate()
	var isolated := "user://capture_"+Crypto.new().generate_random_bytes(8).hex_encode()
	app.store.directory=isolated+"/saves";app.settings.path=isolated+"/settings.json"
	root.add_child(app);current_scene=app;app.set_application_focused(true)
	for size:Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size
		app.return_to_title();await capture("title_%d"%size.x)
		app.view.buttons["new_game"].pressed.emit();app.view.player_name.text="小禾";app.view.dog_name.text="阿豆";await capture("new_game_%d"%size.x)
		app.view.buttons["create"].pressed.emit();await capture("loading_%d"%size.x)
		for tick in 180:
			await physics_frame
			if app.state==app.State.WORLD:break
		assert(app.state==app.State.WORLD,app.last_error)
		await capture("world_%d"%size.x)
		app.set_pause_menu(true);await capture("pause_%d"%size.x)
		app.view.buttons["settings"].pressed.emit();await capture("settings_%d"%size.x)
		app._on_action("back",{});app._on_action("save_return",{});app._on_action("load",{});await capture("saves_%d"%size.x)
		var saved:Dictionary=app.store.list_saves()[0]
		app._on_action("preview_import",{"path":app.store.directory.path_join(saved.save_id+".qfsave")});await capture("import_review_%d"%size.x)
		app._on_action("cancel_import",{})
	app.queue_free();await process_frame;print("PAGE_NATIVE_CAPTURE_PASS");quit()
