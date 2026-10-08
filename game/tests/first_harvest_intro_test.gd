extends SceneTree
## First-minute playable loop: real mature crop -> inventory -> next planting.
## No cheat rewards, no debug commands, and no repeated intro on save restore.
const MAIN = preload("res://app/main.tscn")

var checks := 0
var failures := 0
var app: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL first_harvest_intro ", label)

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

func finish_action() -> void:
	app._tick_farm_action(0.2)
	app._tick_farm_action(0.2)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(35).timeout.connect(func(): printerr("INTRO_HARVEST_TIMEOUT"); quit(1))
	app = MAIN.instantiate()
	app.store.directory = "user://intro_harvest_" + Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(app)
	current_scene = app
	app.set_application_focused(true)
	app._on_action("new_game",{})
	app.view.player_name.text = "小禾"
	app.view.dog_name.text = "阿豆"
	app._on_action("create",{})
	check(await wait_world() and app.room.get_space_id() == "space.farm","real new game starts on editable farm")
	if app.state != app.State.WORLD:
		finish()
		return
	var intro: Dictionary = app.gameplay_session.projection().entry_guidance
	check(intro.mature_plot_id == "plot.farm.003" and intro.practice_plot_id == "plot.farm.004","guide ids derive from content_version")
	var ripe: Dictionary = app.gameplay_session.farm.get_plot(String(intro.mature_plot_id))
	check(ripe.state == "mature" and ripe.crop_id == "crop.radish" and ripe.growth_days == 2,"fresh new game has one real harvestable crop")
	check(app.gameplay_session.farm.get_plot(String(intro.practice_plot_id)).state == "untilled","practice soil is still unworked")
	check(app.gameplay_session.inventory.quantity_of("item.radish") == 0,"no fake radish is deposited directly into inventory")
	check(app.view.guide_panel.visible and app.view.guide_label.text.contains("收获"),"first-screen guidance presents real harvest action")
	var source_save_id: String = app.active_save_id
	check(not source_save_id.is_empty(),"intro crop is included in the initial saved snapshot")

	app.room.get_player().position = Vector2(304,128)
	app.room.get_player().facing = &"north"
	app._unhandled_key_input(key(KEY_E))
	check(app.farm_action.is_before_contact(),"harvest uses normal E contact action")
	check(app.gameplay_session.farm.get_plot("plot.farm.003").state == "mature","pre-contact state remains unmodified")
	finish_action()
	check(app.gameplay_session.farm.get_plot("plot.farm.003").state == "tilled","contact harvest consumes the real mature plot")
	check(app.gameplay_session.inventory.quantity_of("item.radish") == 1,"harvest adds exactly one real item")
	check(app.view.guide_label.text.contains("翻土"),"next goal follows successful harvest projection")

	var saved: Dictionary = app.save_progress()
	check(saved.ok,"harvested progress saves normally")
	if saved.ok:
		app.return_to_title()
		app._on_action("read_save",{"save_id":saved.save_id})
		check(await wait_world() and app.room.get_space_id() == "space.farm","save reload returns to authored farm")
		check(app.gameplay_session.farm.get_plot("plot.farm.003").state == "tilled" and app.gameplay_session.inventory.quantity_of("item.radish") == 1,"restore does not respawn or re-award tutorial radish")

	app.room.get_player().position = Vector2(272,144)
	app.room.get_player().facing = &"north"
	app._unhandled_key_input(key(KEY_E))
	finish_action()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state == "tilled" and app.view.guide_label.text.contains("播种"),"practice bed tilling advances the real guide")
	app._unhandled_key_input(key(KEY_3))
	var seeds_before: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	app._unhandled_key_input(key(KEY_E))
	finish_action()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state == "growing" and app.gameplay_session.inventory.quantity_of("item.radish_seed") == seeds_before-1,"planting consumes seed through real transaction")
	check(app.view.guide_label.text.contains("浇水"),"growing crop prompts watering")
	app._unhandled_key_input(key(KEY_2))
	app._unhandled_key_input(key(KEY_E))
	finish_action()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").is_watered and app.view.guide_label.text.contains("明天"),"watering creates next-day anticipation through authoritative state")
	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("INTRO_HARVEST_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
