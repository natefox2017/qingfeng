extends SceneTree

const MAIN = preload("res://app/main.tscn")

var checks := 0
var failures := 0
var app: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL three_day ", label)

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
	for tick in range(12):
		await physics_frame
		await process_frame
		if app.state == app.State.WORLD and is_instance_valid(app.room) and app.room.has_method("get_space_id") and app.room.get_space_id() == space_id and not app._transition_pending:
			return true
	return false

func finish_farm_action() -> void:
	app._tick_farm_action(0.2)
	app._tick_farm_action(0.2)

func use_plot() -> void:
	app._unhandled_key_input(key(KEY_E))
	finish_farm_action()

func enter_house() -> bool:
	app.room.get_player().position = Vector2(144,160)
	app.room.get_player().facing = &"north"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.house")

func return_farm() -> bool:
	app.room.get_player().position = Vector2(320,320)
	app.room.get_player().facing = &"south"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.farm")

func rest_in_bed() -> void:
	app.room.get_player().position = Vector2(236,160)
	app.room.get_player().facing = &"north"
	app._unhandled_key_input(key(KEY_E))

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(35).timeout.connect(func(): printerr("THREE_DAY_TIMEOUT"); quit(1))
	app = MAIN.instantiate()
	app.store.directory = "user://three_day_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(app)
	current_scene = app
	app.set_application_focused(true)

	app._on_action("new_game",{})
	app.view.player_name.text = "小禾"
	app.view.dog_name.text = "阿豆"
	app._on_action("create",{})
	check(await wait_world() and app.room.get_space_id() == "space.farm", "day one starts on farm")
	if app.state != app.State.WORLD:
		finish()
		return

	# Day 1: till, sow and water one player-owned plot through the real E path.
	app.room.get_player().position = Vector2(272,144)
	app.room.get_player().facing = &"north"
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state == "tilled", "day one E tills plot")
	app._unhandled_key_input(key(KEY_3))
	var seeds_before: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state == "growing" and app.gameplay_session.inventory.quantity_of("item.radish_seed") == seeds_before-1, "day one E sows and consumes one seed")
	app._unhandled_key_input(key(KEY_2))
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").is_watered, "day one E waters planted crop")

	# Real door + bed interaction drives the only clock to day 2.
	check(await enter_house(), "day one enters house through validated door")
	var minute_before_rest: int = app.gameplay_session.clock.game_minute
	rest_in_bed()
	check(app.gameplay_session.clock.current_day() == 2 and app.gameplay_session.clock.minute_of_day() == 360 and app.gameplay_session.clock.game_minute > minute_before_rest, "bed E advances only clock to day two start")
	var day2_plot: Dictionary = app.gameplay_session.farm.get_plot("plot.farm.004")
	check(day2_plot.growth_days == 1 and not day2_plot.is_watered and day2_plot.last_settled_day == 2, "day two settlement advances watered crop once and clears water")

	# Return to farm, water on day 2, then sleep again.
	check(await return_farm(), "day two returns to farm through house door")
	check(app.room.farm_visual_state("plot.farm.004").growth_days == 1, "farm visual refreshes settled state after interior rest")
	app.room.get_player().position = Vector2(272,144)
	app.room.get_player().facing = &"north"
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").is_watered, "day two E waters growing crop")
	check(await enter_house(), "day two re-enters house")
	rest_in_bed()
	var day3_plot: Dictionary = app.gameplay_session.farm.get_plot("plot.farm.004")
	check(app.gameplay_session.clock.current_day() == 3 and day3_plot.state == "mature" and day3_plot.growth_days == 2 and day3_plot.last_settled_day == 3, "second bed rest reaches third-day maturity exactly once")

	# Day 3 harvest, save, kill world route and reload full schema-six state.
	check(await return_farm(), "day three returns to farm")
	check(app.room.farm_visual_state("plot.farm.004").state == "mature", "mature state projects into farm world")
	app.room.get_player().position = Vector2(272,144)
	app.room.get_player().facing = &"north"
	var radish_before: int = app.gameplay_session.inventory.quantity_of("item.radish")
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state == "tilled" and app.gameplay_session.inventory.quantity_of("item.radish") == radish_before+1, "day three E harvest adds produce and keeps tilled soil")

	var saved: Dictionary = app.save_progress()
	check(saved.ok, "third-day gameplay saves after completed actions")
	if saved.ok:
		var envelope: Dictionary = app.store.read_save(saved.save_id).envelope
		check(int(envelope.schema_version) == 6 and envelope.snapshot.gameplay.clock.game_minute == app.gameplay_session.clock.game_minute, "save records schema-six day-three clock")
		app.return_to_title()
		app._on_action("read_save",{"save_id":saved.save_id})
		check(await wait_world() and app.room.get_space_id() == "space.farm", "saved day-three run restarts into farm")
		check(app.gameplay_session.clock.current_day() == 3 and app.gameplay_session.inventory.quantity_of("item.radish") == radish_before+1, "restart preserves day and harvested produce")
		check(app.gameplay_session.farm.get_plot("plot.farm.004").state == "tilled", "restart does not repeat day settlement or harvest")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("THREE_DAY_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
