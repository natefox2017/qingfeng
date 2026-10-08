extends SceneTree

const MAIN = preload("res://app/main.tscn")

var checks := 0
var failures := 0
var app: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL storage_ui ",label)

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event

func wait_world() -> bool:
	for tick in range(180):
		await physics_frame
		if app.state == app.State.WORLD:
			return true
		if app.state == app.State.TITLE and not app.last_error.is_empty():
			return false
	return false

func wait_space(space_id: String) -> bool:
	for tick in range(20):
		await physics_frame
		await process_frame
		if app.state == app.State.WORLD and is_instance_valid(app.room) and app.room.has_method("get_space_id") and app.room.get_space_id() == space_id and not app._transition_pending:
			return true
	return false

func enter_house() -> bool:
	app.room.get_player().position = Vector2(144,160)
	app.room.get_player().facing = &"north"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.house")

func open_chest() -> void:
	app.room.get_player().position = Vector2(520,152)
	app.room.get_player().facing = &"north"
	app._unhandled_key_input(key(KEY_E))

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(30).timeout.connect(func(): printerr("STORAGE_UI_TIMEOUT"); quit(1))
	app = MAIN.instantiate()
	app.store.directory = "user://storage_ui_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(app)
	current_scene = app
	app.set_application_focused(true)

	app._on_action("new_game",{})
	app.view.player_name.text = "小禾"
	app.view.dog_name.text = "阿豆"
	app._on_action("create",{})
	check(await wait_world() and app.room.get_space_id()=="space.farm","new game starts on farm")
	if app.state != app.State.WORLD:
		finish()
		return
	check(await enter_house(),"player enters house before using chest")

	app.room.get_player().position = Vector2(520,152)
	app.room.get_player().facing = &"north"
	var target: Dictionary = app.room.resolve_interaction_target()
	check(target.get("kind","")=="storage" and target.get("interaction_id","")=="storage.house.main","house resolves chest from real position/facing")
	open_chest()
	check(app.locks.has_owner(&"storage") and app.gameplay_session.clock.is_paused(),"E opens chest and storage owner pauses gameplay clock")
	check(app.view.title.text=="家中木箱" and app.view.buttons.has("close_storage"),"storage page is projected from live gameplay state")
	check(app.view.buttons["close_storage"].tooltip_text==app.view.buttons["close_storage"].accessibility_name,"chest close action keeps tooltip/accessibility parity")

	var seeds_before: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	app._on_action("transfer_storage",{
		"source_container_id":"container.player",
		"item_id":"item.radish_seed",
		"quantity":seeds_before
	})
	check(app.gameplay_session.inventory.quantity_of("item.radish_seed")==0 and app.gameplay_session.storage.quantity_of("item.radish_seed")==seeds_before,"storage page deposit intent moves whole stack through authoritative command")
	check(app.locks.has_owner(&"storage") and app.gameplay_session.clock.is_paused(),"transfer rerender keeps chest modal and pause token")

	var storage_revision: int = app.gameplay_session.storage.revision
	app._unhandled_key_input(key(KEY_E))
	check(app.locks.has_owner(&"storage") and app.gameplay_session.storage.revision==storage_revision and not app._transition_pending,"world E cannot click through an open chest modal")

	app._on_action("transfer_storage",{
		"source_container_id":"container.home_chest",
		"item_id":"item.radish_seed",
		"quantity":seeds_before
	})
	check(app.gameplay_session.inventory.quantity_of("item.radish_seed")==seeds_before and app.gameplay_session.storage.quantity_of("item.radish_seed")==0,"storage page withdrawal returns stack to player")

	app._on_action("transfer_storage",{
		"source_container_id":"container.player",
		"item_id":"item.hoe",
		"quantity":1
	})
	check(app.gameplay_session.inventory.quantity_of("item.hoe")==0 and app.gameplay_session.storage.quantity_of("item.hoe")==1,"tool can be stored using same transfer path")
	var save: Dictionary = app.save_progress()
	check(save.ok,"gameplay can save persisted chest state")
	if save.ok:
		app.return_to_title()
		app._on_action("read_save",{"save_id":save.save_id})
		check(await wait_world() and app.room.get_space_id()=="space.house","chest save restarts directly inside house")
		check(app.gameplay_session.storage.quantity_of("item.hoe")==1 and app.gameplay_session.inventory.quantity_of("item.hoe")==0,"schema-four reload preserves chest contents")
		open_chest()
		check(app.locks.has_owner(&"storage"),"reloaded house chest opens from world interaction")

	app._unhandled_key_input(key(KEY_ESCAPE))
	check(not app.locks.has_owner(&"storage") and not app.gameplay_session.clock.is_paused() and app.room.get_player().is_input_enabled,"Esc closes only chest and releases storage pause/input owner")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("STORAGE_UI_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
