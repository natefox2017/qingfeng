extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const CLOCK = preload("res://app/game_clock.gd")
const SESSION = preload("res://app/gameplay_session.gd")
const MAIN = preload("res://app/main.tscn")

var checks := 0
var failures := 0
var app: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL world_clock ",label)

func command(id: String, action: String, revision: int, payload: Dictionary) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":id,
		"session_id":"session.clock",
		"actor_id":"actor.player",
		"action":action,
		"expected_revision":revision,
		"payload":payload
	}

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

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(30).timeout.connect(func(): printerr("WORLD_CLOCK_TIMEOUT"); quit(1))
	var loaded: Dictionary = CONTENT.load_current()
	check(loaded.ok,"content loads for world clock")
	if not loaded.ok:
		finish()
		return
	var content: Dictionary = loaded.data
	check(is_equal_approx(float(content.clock.real_seconds_per_game_minute),0.7),"first-playable rate is centralized at 0.7 real seconds per game minute")

	var clock = CLOCK.new(content)
	check(clock.is_configured() and clock.minute_of_day()==360,"clock starts at configured 06:00")
	var partial: Dictionary = clock.advance_real_seconds(0.69)
	check(partial.ok and partial.advanced_minutes==0 and clock.minute_of_day()==360,"sub-minute real time is accumulated without premature game-minute mutation")
	var one_minute: Dictionary = clock.advance_real_seconds(0.011)
	check(one_minute.ok and one_minute.advanced_minutes==1 and clock.minute_of_day()==361,"crossing configured real-time threshold advances exactly one game minute")

	check(clock.acquire_pause(&"menu"),"pause owner acquired")
	var paused: Dictionary = clock.advance_real_seconds(70.0)
	check(paused.ok and paused.advanced_minutes==0 and clock.minute_of_day()==361,"paused real time neither advances nor accumulates")
	check(clock.release_pause(&"menu"),"pause owner releases only itself")
	var resumed: Dictionary = clock.advance_real_seconds(0.7)
	check(resumed.ok and resumed.advanced_minutes==1 and clock.minute_of_day()==362,"world time resumes from same single clock")

	clock.advance_real_seconds(0.35)
	var slept: Dictionary = clock.rest_to_next_day_start()
	check(slept.ok and clock.current_day()==2 and clock.minute_of_day()==360,"bed rest still snaps the one clock to next 06:00")
	var after_sleep_partial: Dictionary = clock.advance_real_seconds(0.35)
	check(after_sleep_partial.advanced_minutes==0 and clock.minute_of_day()==360,"bed rest clears pre-sleep sub-minute carry")
	var after_sleep_tick: Dictionary = clock.advance_real_seconds(0.36)
	check(after_sleep_tick.advanced_minutes==1 and clock.minute_of_day()==361,"new day accumulates real time independently")

	var plots := [{"plot_id":"plot.clock.001","space_id":"space.farm","cell_position":{"x":17,"y":7}}]
	var session = SESSION.new(plots,content)
	check(session.is_configured(),"gameplay session configures for natural day settlement")
	check(session.execute(command("clock-till","farm.till",session.farm.revision,{"plot_id":"plot.clock.001"})).ok,"clock fixture tills plot")
	check(session.execute(command("clock-plant","farm.plant",session.farm.revision,{"plot_id":"plot.clock.001","crop_id":"crop.radish","inventory_revision":session.inventory.revision})).ok,"clock fixture plants plot")
	check(session.execute(command("clock-water","farm.water",session.farm.revision,{"plot_id":"plot.clock.001"})).ok,"clock fixture waters plot")
	var natural_day: Dictionary = session.advance_real_seconds(1008.001)
	var plot: Dictionary = session.farm.get_plot("plot.clock.001")
	check(natural_day.ok and natural_day.crossed_days==[2] and session.clock.current_day()==2,"real-time session flow crosses the day boundary through the only clock")
	check(plot.growth_days==1 and plot.last_settled_day==2 and not plot.is_watered,"natural day boundary drives the same ordered farm settlement path")

	app = MAIN.instantiate()
	app.store.directory = "user://world_clock_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(app)
	current_scene = app
	app.set_application_focused(true)
	app._on_action("new_game",{})
	app.view.player_name.text = "小禾"
	app.view.dog_name.text = "阿豆"
	app._on_action("create",{})
	check(await wait_world() and app.gameplay_session.clock.minute_of_day()==360,"app gameplay begins at 06:00")
	if app.state != app.State.WORLD:
		finish()
		return
	app.set_process(false)

	app._unhandled_key_input(key(KEY_B))
	check(app.locks.has_owner(&"inventory") and app.gameplay_session.clock.is_paused(),"inventory owns pause before simulated elapsed time")
	var before_menu_time: int = app.gameplay_session.clock.game_minute
	app._process(84.0)
	check(app.gameplay_session.clock.game_minute==before_menu_time,"84 real seconds inside inventory do not advance game time")
	app._unhandled_key_input(key(KEY_ESCAPE))
	check(not app.gameplay_session.clock.is_paused(),"closing inventory releases its clock token")

	app._process(84.001)
	check(app.gameplay_session.clock.minute_of_day()>=480 and app.gameplay_session.projection().shop.is_open,"active world runtime naturally reaches the 08:00 shop window")
	var hud_time_text := ""
	for label_node: Node in app.view.hud.find_children("*","Label",true,false):
		hud_time_text += (label_node as Label).text+"\n"
	check(hud_time_text.contains("08:") and app.view.wallet_label != null and app.view.wallet_label.text.contains("金币"),"HUD clock and money refresh from authoritative projections")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("WORLD_CLOCK_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
