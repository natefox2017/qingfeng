extends SceneTree

const MAIN = preload("res://app/main.tscn")
const CODEC = preload("res://persistence/session_codec.gd")

var checks := 0
var failures := 0
var app: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL full_economy_loop ",label)

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

func finish_action() -> void:
	app._tick_farm_action(0.2)
	app._tick_farm_action(0.2)

func use_plot() -> void:
	app._unhandled_key_input(key(KEY_E))
	finish_action()

func farm_to_shop() -> bool:
	app.room.get_player().position=app.room.get_anchor_position("VillagePathArrival")
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))
	if not await wait_space("space.village"):
		return false
	app.room.get_player().position=Vector2(400,168)
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.shop")

func shop_to_farm() -> bool:
	app.room.get_player().position=Vector2(320,320)
	app.room.get_player().facing=&"south"
	app._unhandled_key_input(key(KEY_E))
	if not await wait_space("space.village"):
		return false
	app.room.get_player().position=app.room.get_spawn_position()
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.farm")

func enter_house() -> bool:
	app.room.get_player().position=app.room.get_anchor_position("HouseDoorArrival")
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.house")

func return_farm() -> bool:
	app.room.get_player().position=Vector2(320,320)
	app.room.get_player().facing=&"south"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.farm")

func open_chest() -> void:
	app.room.get_player().position=Vector2(520,152)
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))

func rest_in_bed() -> void:
	app.room.get_player().position=Vector2(236,160)
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))

func open_counter() -> void:
	app.room.get_player().position=Vector2(320,160)
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(45).timeout.connect(func(): printerr("FULL_ECONOMY_LOOP_TIMEOUT"); quit(1))
	app=MAIN.instantiate()
	app.store.directory="user://full_economy_loop_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(app)
	current_scene=app
	app.set_application_focused(true)

	app._on_action("new_game",{})
	app.view.player_name.text="小禾"
	app.view.dog_name.text="阿豆"
	app._on_action("create",{})
	check(await wait_world() and app.room.get_space_id()=="space.farm","day one starts on farm")
	if app.state!=app.State.WORLD:
		finish()
		return
	app.set_process(false)

	# Day 1: natural time to opening, buy one seed at the real counter.
	app._process(84.001)
	check(app.gameplay_session.clock.current_day()==1 and app.gameplay_session.clock.minute_of_day()>=480 and app.gameplay_session.projection().shop.is_open,"day one active world time naturally reaches 08:00")
	check(await farm_to_shop(),"day one reaches shop through farm-village route")
	open_counter()
	check(app.locks.has_owner(&"trade"),"day one opens real trade modal")
	var money_before_buy: int = app.gameplay_session.wallet.money
	var seed_before_buy: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	app._on_action("trade_buy",{"item_id":"item.radish_seed","quantity":1})
	check(app.gameplay_session.wallet.money==money_before_buy-20 and app.gameplay_session.inventory.quantity_of("item.radish_seed")==seed_before_buy+1,"day one buys one seed through economy command")
	app._unhandled_key_input(key(KEY_ESCAPE))
	check(await shop_to_farm(),"day one returns from shop to farm")

	# Till, plant, water through the real E/contact path.
	app.room.get_player().position=app.room.get_node("FarmPlots/Plot004").position + Vector2(0,16)
	app.room.get_player().facing=&"north"
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state=="tilled","day one tills player plot")
	app._unhandled_key_input(key(KEY_3))
	var seeds_before_plant: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state=="growing" and app.gameplay_session.inventory.quantity_of("item.radish_seed")==seeds_before_plant-1,"day one plants and consumes one seed")
	app._unhandled_key_input(key(KEY_2))
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").is_watered,"day one waters crop")

	# Store every remaining seed in the real home chest, then sleep.
	check(await enter_house(),"day one enters house")
	open_chest()
	check(app.locks.has_owner(&"storage"),"day one opens real chest modal")
	var seeds_to_store: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	app._on_action("transfer_storage",{"source_container_id":"container.player","item_id":"item.radish_seed","quantity":seeds_to_store})
	check(app.gameplay_session.inventory.quantity_of("item.radish_seed")==0 and app.gameplay_session.storage.quantity_of("item.radish_seed")==seeds_to_store,"remaining seeds move atomically into chest")
	app._unhandled_key_input(key(KEY_ESCAPE))
	rest_in_bed()
	check(app.gameplay_session.clock.current_day()==2 and app.gameplay_session.farm.get_plot("plot.farm.004").growth_days==1,"bed settles watered crop into day two")

	# Day 2: return, water, sleep again.
	check(await return_farm(),"day two returns to farm")
	app.room.get_player().position=app.room.get_node("FarmPlots/Plot004").position + Vector2(0,16)
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_2))
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").is_watered,"day two waters growing crop")
	check(await enter_house(),"day two returns home")
	rest_in_bed()
	check(app.gameplay_session.clock.current_day()==3 and app.gameplay_session.farm.get_plot("plot.farm.004").state=="mature","second sleep reaches day-three maturity")

	# Day 3: harvest, sell produce, buy replacement seed.
	check(await return_farm(),"day three returns to farm")
	app.room.get_player().position=app.room.get_node("FarmPlots/Plot004").position + Vector2(0,16)
	app.room.get_player().facing=&"north"
	var radish_before: int = app.gameplay_session.inventory.quantity_of("item.radish")
	use_plot()
	check(app.gameplay_session.inventory.quantity_of("item.radish")==radish_before+1 and app.gameplay_session.farm.get_plot("plot.farm.004").state=="tilled","day three harvest yields produce and keeps tilled soil")

	app._process(84.001)
	check(app.gameplay_session.projection().shop.is_open,"day three naturally reaches shop opening")
	check(await farm_to_shop(),"day three reaches shop through live route")
	open_counter()
	var money_before_sell: int = app.gameplay_session.wallet.money
	app._on_action("trade_sell",{"item_id":"item.radish","quantity":1})
	check(app.gameplay_session.inventory.quantity_of("item.radish")==radish_before and app.gameplay_session.wallet.money==money_before_sell+35,"day three sells harvested crop at configured price")
	var money_before_rebuy: int = app.gameplay_session.wallet.money
	app._on_action("trade_buy",{"item_id":"item.radish_seed","quantity":1})
	check(app.gameplay_session.wallet.money==money_before_rebuy-20 and app.gameplay_session.inventory.quantity_of("item.radish_seed")==1,"day three buys replacement seed without touching chest reserve")
	app._unhandled_key_input(key(KEY_ESCAPE))
	check(await shop_to_farm(),"day three returns to farm for replanting")

	# Replant purchased seed and water to prove the loop can continue.
	app.room.get_player().position=app.room.get_node("FarmPlots/Plot004").position + Vector2(0,16)
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_3))
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").state=="growing" and app.gameplay_session.inventory.quantity_of("item.radish_seed")==0,"day three replants purchased seed into existing tilled soil")
	app._unhandled_key_input(key(KEY_2))
	use_plot()
	check(app.gameplay_session.farm.get_plot("plot.farm.004").is_watered,"replacement crop is watered for the next cycle")
	check(app.gameplay_session.storage.quantity_of("item.radish_seed")==seeds_to_store,"chest reserve remains untouched through sell and replant")
	check(app.gameplay_session.wallet.money==195,"three-day buy/sell/rebuy loop leaves deterministic configured money")
	var precision_snapshot: Dictionary = app.active_snapshot.duplicate(true)
	precision_snapshot.gameplay.residents.residents[2].world_position_px.x=114.66665649414063
	var precision_save: Dictionary = app.store.write_new(precision_snapshot)
	check(precision_save.ok,"fractional resident position saves with a stable checksum")
	if precision_save.ok:
		var precision_read: Dictionary = app.store.read_save(precision_save.save_id)
		check(precision_read.ok and CODEC.canonical(precision_read.envelope.snapshot)==CODEC.canonical(precision_snapshot),"fractional resident position survives save read")

	# Save/restart full cross-system state at the end of the loop.
	var save: Dictionary = app.save_progress()
	check(save.ok,"completed economy loop saves; error="+save.get("error_code",""))
	if save.ok:
		var envelope: Dictionary = app.store.read_save(save.save_id).envelope
		check(int(envelope.schema_version)==7,"completed loop writes current schema-seven gameplay save")
		app.set_process(true)
		app.return_to_title()
		app._on_action("read_save",{"save_id":save.save_id})
		var reloaded := await wait_world()
		check(reloaded and app.room.get_space_id()=="space.farm","completed loop restarts into farm; error="+app.last_error)
		if reloaded:
			app.set_process(false)
			check(app.gameplay_session.clock.current_day()==3 and app.gameplay_session.wallet.money==195,"restart preserves day and economy result")
			check(app.gameplay_session.storage.quantity_of("item.radish_seed")==seeds_to_store and app.gameplay_session.farm.get_plot("plot.farm.004").state=="growing" and app.gameplay_session.farm.get_plot("plot.farm.004").is_watered,"restart preserves chest reserve and replanted watered crop")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("FULL_ECONOMY_LOOP_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
