extends "res://tests/farm_interaction_test.gd"
## Movement uses real Input actions/CharacterBody2D physics, never teleports.
## Economy/chest three-day coverage remains in full_economy_loop_test.gd.

func walk(target: Vector2) -> bool:
	var player: CharacterBody2D = app.room.get_player()
	for axis in [0, 1]:
		var action: String = ""
		for tick in range(1200):
			var delta: float = target[axis] - player.position[axis]
			if absf(delta) <= 2.0:
				break
			var next: String = ("move_right" if delta > 0 else "move_left") if axis == 0 else ("move_down" if delta > 0 else "move_up")
			if action != next:
				if not action.is_empty(): Input.action_release(action)
				action = next
				Input.action_press(action)
			await physics_frame
		if not action.is_empty(): Input.action_release(action)
		await physics_frame
	var reached := player.position.distance_to(target) <= 4.0
	check(reached, "physics walk %s reached %s" % [target, player.position])
	return reached

func door(anchor: String, facing: StringName, expected: String) -> bool:
	var direction: Vector2 = {&"north":Vector2.UP,&"south":Vector2.DOWN,&"east":Vector2.RIGHT,&"west":Vector2.LEFT}[facing]
	var point: Vector2 = app.room.get_anchor_position(anchor) - direction * 20.0
	if not await walk(point): return false
	app.room.get_player().facing = facing
	var target: Dictionary = app.room.resolve_interaction_target()
	check(target.get("target_space_id", "") == expected, "door resolver " + anchor)
	app._unhandled_key_input(key(KEY_E))
	for tick in range(180):
		await physics_frame
		if app.room.get_space_id() == expected and not app._transition_pending:
			check(true, "door commit " + expected)
			return true
	check(false, "door commit " + expected)
	return false

func run() -> void:
	create_timer(180).timeout.connect(func(): printerr("MAP_PLAYABILITY_TIMEOUT"); quit(1))
	app = MAIN.instantiate()
	var isolated := "user://chapter1_map_" + Crypto.new().generate_random_bytes(8).hex_encode()
	app.store.directory = isolated + "/saves"
	app.settings.path = isolated + "/settings.json"
	root.add_child(app)
	current_scene = app
	app.set_application_focused(true)
	app._on_action("new_game", {})
	app.view.player_name.text = "小禾"
	app.view.dog_name.text = "阿豆"
	app._on_action("create", {})
	check(await wait_world(), "fresh farm starts")
	if app.state != app.State.WORLD:
		await finish()
		return
	app.set_process(false)
	if not await walk(Vector2(304,176)) or not await walk(Vector2(304,128)):
		await finish()
		return
	app.room.get_player().facing = &"north"
	check(app.room.resolve_plot_target() == "plot.farm.003", "walking reaches mature tutorial plot")
	use_plot()
	check(app.gameplay_session.inventory.quantity_of("item.radish") == 1 and app.gameplay_session.farm.get_plot("plot.farm.003").state == "tilled", "003 harvest gives exactly one radish")
	if not await walk(Vector2(272,144)):
		await finish()
		return
	app.room.get_player().facing = &"north"
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state == "tilled", "004 till at walked contact")
	app._unhandled_key_input(key(KEY_3))
	var seeds: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	use_plot()
	check(app.gameplay_session.inventory.quantity_of("item.radish_seed") == seeds-1, "004 plant consumes one seed")
	app._unhandled_key_input(key(KEY_2))
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").is_watered, "004 water")
	if not await walk(Vector2(272,176)) or not await door("HouseDoorInteract", &"north", "space.house") or not await door("DoorInteract", &"south", "space.farm"):
		await finish()
		return
	if not await walk(Vector2(144,208)) or not await walk(app.room.get_anchor_position("BridgeWest")) or not await walk(app.room.get_anchor_position("BridgeEast")):
		await finish()
		return
	check(app.room.get_player().position.x > 528, "physically crosses river at bridge")
	if not await walk(Vector2(584,96)):
		await finish()
		return
	Input.action_press("move_left")
	for tick in range(75): await physics_frame
	Input.action_release("move_left")
	await physics_frame
	check(app.room.get_player().position.x > 540, "river blocks west movement away from bridge")
	if not await walk(Vector2(584,208)):
		await finish()
		return
	var player: CharacterBody2D = app.room.get_player()
	var start: Vector2 = player.position
	Input.action_press("move_left")
	for tick in range(45): await physics_frame
	Input.action_release("move_left")
	await physics_frame
	check(player.position.x < start.x, "bridge allows westbound movement")
	if not await door("VillagePathInteract", &"east", "space.village") or not await door("ShopDoorInteract", &"north", "space.shop") or not await door("DoorInteract", &"south", "space.village") or not await door("WorkshopDoorInteract", &"south", "space.workshop") or not await door("DoorInteract", &"south", "space.village") or not await walk(Vector2(48,180)) or not await door("FarmExitInteract", &"west", "space.farm"):
		await finish()
		return
	var saved: Dictionary = app.save_progress()
	check(saved.ok, "save walked route")
	if saved.ok:
		app.set_process(true)
		app.return_to_title()
		app._on_action("read_save", {"save_id":saved.save_id})
		var loaded := await wait_world()
		check(loaded, "reload walked route error=" + app.last_error)
		if loaded:
			check(app.gameplay_session.inventory.quantity_of("item.radish")==1 and app.gameplay_session.farm.get_plot("plot.farm.004").is_watered, "reload preserves harvested item and watered practice plot")
	await finish()

func use_plot() -> void:
	app._unhandled_key_input(key(KEY_E))
	finish_action()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("MAP_PLAYABILITY_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
