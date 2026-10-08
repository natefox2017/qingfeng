extends SceneTree

const MAIN = preload("res://app/main.tscn")

var checks := 0
var failures := 0
var app: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL recovery_loop ",label)

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	return event

func wait_world() -> bool:
	for tick in range(180):
		await physics_frame
		if app.state==app.State.WORLD:
			return true
		if app.state==app.State.TITLE and not app.last_error.is_empty():
			return false
	return false

func wait_space(space_id:String) -> bool:
	for tick in range(20):
		await physics_frame
		await process_frame
		if app.state==app.State.WORLD and is_instance_valid(app.room) and app.room.has_method("get_space_id") and app.room.get_space_id()==space_id and not app._transition_pending:
			return true
	return false

func go_farm_to_village() -> bool:
	app.room.get_player().position=Vector2(584,208)
	app.room.get_player().facing=&"east"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.village")

func collect_a() -> void:
	app.room.get_player().position=Vector2(184,172)
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))

func collect_b() -> void:
	app.room.get_player().position=Vector2(280,188)
	app.room.get_player().facing=&"south"
	app._unhandled_key_input(key(KEY_E))

func village_to_shop() -> bool:
	app.room.get_player().position=Vector2(400,168)
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.shop")

func open_counter() -> void:
	app.room.get_player().position=Vector2(320,160)
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(35).timeout.connect(func(): printerr("RECOVERY_LOOP_TIMEOUT"); quit(1))
	app=MAIN.instantiate()
	app.store.directory="user://recovery_loop_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(app)
	current_scene=app
	app.set_application_focused(true)

	app._on_action("new_game",{})
	app.view.player_name.text="小禾"
	app.view.dog_name.text="阿豆"
	app._on_action("create",{})
	check(await wait_world() and app.room.get_space_id()=="space.farm","new game starts on farm with forage-enabled session")
	if app.state!=app.State.WORLD:
		finish()
		return
	app.set_process(false)

	var initial_seeds: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	check(app.gameplay_session.inventory.remove("item.radish_seed",initial_seeds).ok and app.gameplay_session.wallet.debit(app.gameplay_session.wallet.money).ok,"test fixture reaches zero money and zero seeds through domain APIs")
	check(app.gameplay_session.wallet.money==0 and app.gameplay_session.inventory.quantity_of("item.radish_seed")==0,"soft-lock fixture is truly broke and seedless")

	check(await go_farm_to_village(),"broke player can reach village normally")
	check(app.room.forage_visual_state("forage.village.001").is_available and app.room.forage_visual_state("forage.village.002").is_available,"village projects two daily recovery forage spots")
	collect_a()
	check(app.gameplay_session.inventory.quantity_of("item.wild_herb")==1 and not app.room.forage_visual_state("forage.village.001").is_available,"first world forage pickup adds item and hides only collected spot")

	var save: Dictionary = app.save_progress()
	check(save.ok,"same-day forage state saves")
	if not save.ok:
		finish()
		return
	var envelope: Dictionary = app.store.read_save(save.save_id).envelope
	check(int(envelope.schema_version)==7 and envelope.snapshot.gameplay.forage.spots[0].last_collected_day==1,"schema-seven app save records forage collection day")
	# Loading is polled by main._process(), so re-enable it only for the transition.
	app.set_process(true)
	app.return_to_title()
	app._on_action("read_save",{"save_id":save.save_id})
	var reloaded := await wait_world()
	check(reloaded and app.room.get_space_id()=="space.village","forage save restarts directly in village; error="+app.last_error)
	if app.state!=app.State.WORLD:
		finish()
		return
	app.set_process(false)
	check(not app.room.forage_visual_state("forage.village.001").is_available and app.room.forage_visual_state("forage.village.002").is_available,"reload cannot duplicate already collected daily spot")
	collect_b()
	check(app.gameplay_session.inventory.quantity_of("item.wild_herb")==2,"second stable spot completes guaranteed recovery bundle")

	check(await village_to_shop(),"seedless player reaches shop from same village route")
	check(app.gameplay_session.advance(120).ok and app.gameplay_session.projection().shop.is_open,"single clock reaches 08:00 shop window")
	open_counter()
	check(app.locks.has_owner(&"trade"),"counter opens existing authoritative trade modal")
	app._on_action("trade_sell",{"item_id":"item.wild_herb","quantity":1})
	app._on_action("trade_sell",{"item_id":"item.wild_herb","quantity":1})
	check(app.gameplay_session.inventory.quantity_of("item.wild_herb")==0 and app.gameplay_session.wallet.money==20,"two free daily herbs sell for exactly one seed budget")
	app._on_action("trade_buy",{"item_id":"item.radish_seed","quantity":1})
	check(app.gameplay_session.wallet.money==0 and app.gameplay_session.inventory.quantity_of("item.radish_seed")==1,"zero-money zero-seed state recovers to one plantable seed without restart or gift")
	app._unhandled_key_input(key(KEY_ESCAPE))
	check(not app.locks.has_owner(&"trade"),"recovery route leaves trade modal cleanly")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("RECOVERY_LOOP_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
