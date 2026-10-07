extends SceneTree

const MAIN = preload("res://app/main.tscn")

var checks := 0
var failures := 0
var app: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL farm_interaction ",label)

func wait_world() -> bool:
	for tick in range(180):
		await physics_frame
		if app.state == app.State.WORLD:
			return true
		if app.state == app.State.TITLE and not app.last_error.is_empty():
			return false
	return false

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event

func finish_action() -> void:
	app._tick_farm_action(0.2)
	app._tick_farm_action(0.2)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(25).timeout.connect(func(): printerr("FARM_INTERACTION_TIMEOUT"); quit(1))
	app = MAIN.instantiate()
	app.store.directory = "user://farm_interaction_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(app)
	current_scene = app
	app.set_application_focused(true)

	check(InputMap.event_is_action(key(KEY_E),"interact"), "E is the single world interaction binding")
	app._on_action("new_game",{})
	app.view.player_name.text = "小禾"
	app.view.dog_name.text = "阿豆"
	app._on_action("create",{})
	check(await wait_world(), "new game reaches farm first screen")
	if app.state != app.State.WORLD:
		finish()
		return

	var player: CharacterBody2D = app.room.get_player()
	player.position = Vector2(272,144)
	player.facing = &"north"
	check(app.room.resolve_plot_target() == "plot.farm.004", "world resolves nearest reachable plot in facing direction")
	check(app.gameplay_session.inventory.selected_slot_index == 0, "hoe starts selected")

	var interact := key(KEY_E)
	app._unhandled_key_input(interact)
	check(app.farm_action.is_before_contact() and app.locks.has_owner(&"farm_action"), "E begins prepare phase and locks movement")
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state == "untilled", "prepare phase does not mutate farm")
	check(app.save_progress().error_code == "SAVE_ACTION_BUSY", "save cannot capture a half-prepared action")
	app._unhandled_key_input(key(KEY_ESCAPE))
	check(not app.farm_action.is_busy() and not app.locks.has_owner(&"farm_action"), "Esc cancels topmost action before contact")
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state == "untilled", "pre-contact cancel leaves farm unchanged")

	app._unhandled_key_input(interact)
	var before_till_revision: int = app.gameplay_session.farm.revision
	app._tick_farm_action(0.2)
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state == "tilled", "contact commits till exactly once")
	var after_till_revision: int = app.gameplay_session.farm.revision
	app._tick_farm_action(0.01)
	check(after_till_revision == before_till_revision+1 and app.gameplay_session.farm.revision == after_till_revision, "recover phase cannot resubmit contact")
	check(app.room.farm_visual_state("plot.farm.004").state == "tilled", "world visual projection follows authoritative tilled state")
	app._unhandled_key_input(key(KEY_ESCAPE))
	check(not app.farm_action.is_busy() and app.gameplay_session.farm.get_plot("plot.farm.004").state == "tilled", "Esc after contact only ends presentation")

	app._unhandled_key_input(key(KEY_3))
	check(app.gameplay_session.inventory.selected_slot_index == 2, "number key selects seed slot through command")
	var seeds_before: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	app._unhandled_key_input(interact)
	finish_action()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state == "growing" and app.gameplay_session.inventory.quantity_of("item.radish_seed") == seeds_before-1, "seed action atomically plants and deducts one seed")
	check(app.room.farm_visual_state("plot.farm.004").state == "growing", "world visual shows growing projection")

	app._unhandled_key_input(key(KEY_2))
	check(app.gameplay_session.inventory.selected_slot_index == 1, "number key selects watering can")
	app._unhandled_key_input(interact)
	check(app.farm_action.is_before_contact(), "watering enters prepare before contact")
	app.set_application_focused(false)
	check(not app.farm_action.is_busy() and not app.gameplay_session.farm.get_plot("plot.farm.004").is_watered, "focus loss before contact cancels watering with zero change")
	app.set_application_focused(true)
	app._unhandled_key_input(interact)
	finish_action()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").is_watered, "watering commits at contact")

	var day2: Dictionary = app.gameplay_session.rest_to_next_day()
	app._refresh_farm_world()
	check(day2.ok and app.gameplay_session.farm.get_plot("plot.farm.004").growth_days == 1, "day two settlement grows watered crop once")
	app._unhandled_key_input(interact)
	finish_action()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").is_watered, "second-day E watering works on growing crop")
	var day3: Dictionary = app.gameplay_session.rest_to_next_day()
	app._refresh_farm_world()
	check(day3.ok and app.gameplay_session.farm.get_plot("plot.farm.004").state == "mature", "second watered settlement reaches mature state")
	check(app.room.farm_visual_state("plot.farm.004").state == "mature", "world visual follows mature projection")

	var radish_before: int = app.gameplay_session.inventory.quantity_of("item.radish")
	app._unhandled_key_input(interact)
	finish_action()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state == "tilled" and app.gameplay_session.inventory.quantity_of("item.radish") == radish_before+1, "mature plot E harvests atomically regardless of selected watering can")
	check(app.room.farm_visual_state("plot.farm.004").state == "tilled", "harvest projection returns plot visual to tilled")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("FARM_INTERACTION_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
