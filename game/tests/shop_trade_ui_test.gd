extends SceneTree

const MAIN = preload("res://app/main.tscn")

var checks := 0
var failures := 0
var app: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL shop_trade_ui ",label)

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

func go_to_shop() -> bool:
	var player: CharacterBody2D = app.room.get_player()
	player.position = app.room.get_anchor_position("VillagePathInteract") + Vector2.DOWN * 20.0
	player.facing = &"north"
	app._unhandled_key_input(key(KEY_E))
	if not await wait_space("space.village"):
		return false
	app.room.get_player().position = Vector2(400,168)
	app.room.get_player().facing = &"north"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.shop")

func open_counter() -> void:
	app.room.get_player().position = Vector2(320,160)
	app.room.get_player().facing = &"north"
	app._unhandled_key_input(key(KEY_E))

func find_button_with_prefix(root_node: Node, prefix: String) -> Button:
	for child: Node in root_node.get_children():
		if child is Button and String((child as Button).text).begins_with(prefix):
			return child as Button
		var nested := find_button_with_prefix(child,prefix)
		if nested != null:
			return nested
	return null

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(35).timeout.connect(func(): printerr("SHOP_TRADE_UI_TIMEOUT"); quit(1))
	app = MAIN.instantiate()
	app.store.directory = "user://shop_trade_ui_"+Crypto.new().generate_random_bytes(8).hex_encode()
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
	check(await go_to_shop(),"player reaches shop through real farm-village route")
	check(app.gameplay_session.advance(120).ok and app.gameplay_session.clock.minute_of_day()==480,"test advances the one clock to shop opening time")
	check(app.gameplay_session.inventory.add("item.radish",1).ok,"test fixture adds one sellable harvested radish through inventory domain")

	var target: Dictionary
	app.room.get_player().position = Vector2(320,160)
	app.room.get_player().facing = &"north"
	target = app.room.resolve_interaction_target()
	check(target.get("kind","")=="trade" and target.get("interaction_id","")=="trade.shop.counter","counter resolves dedicated trade interaction")
	open_counter()
	check(app.locks.has_owner(&"trade") and app.gameplay_session.clock.is_paused(),"E opens trade modal and owns game-clock pause")
	check(app.view.title.text=="杂货铺柜台" and app.view.subtitle.text.contains("购买种子与出售收成"),"trade page renders live counter state")
	var buy_button: Button = find_button_with_prefix(app.view.body,"买 1")
	check(buy_button!=null and not buy_button.disabled and buy_button.tooltip_text==buy_button.accessibility_name,"open shop exposes accessible buy button")

	var seeds_before: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	var money_before: int = app.gameplay_session.wallet.money
	if buy_button != null:
		buy_button.emit_signal("pressed")
	check(app.gameplay_session.inventory.quantity_of("item.radish_seed")==seeds_before+1 and app.gameplay_session.wallet.money==money_before-20,"buy button routes through economy.buy and updates authoritative money/items")
	check(app.locks.has_owner(&"trade") and app.gameplay_session.clock.is_paused(),"trade rerender keeps modal pause owner")

	var sell_button: Button = find_button_with_prefix(app.view.body,"卖 1")
	check(sell_button!=null and not sell_button.disabled,"sellable produce appears in live trade projection")
	var money_before_sell: int = app.gameplay_session.wallet.money
	if sell_button != null:
		sell_button.emit_signal("pressed")
	check(app.gameplay_session.inventory.quantity_of("item.radish")==0 and app.gameplay_session.wallet.money==money_before_sell+35,"sell button routes through economy.sell and credits configured price")

	var selected_before: int = app.gameplay_session.inventory.selected_slot_index
	app._unhandled_key_input(key(KEY_1))
	app._unhandled_key_input(key(KEY_B))
	app._unhandled_key_input(key(KEY_E))
	check(app.gameplay_session.inventory.selected_slot_index==selected_before and app.locks.has_owner(&"trade") and not app.locks.has_owner(&"inventory") and not app._transition_pending,"trade modal blocks number/B/E click-through to world and inventory")

	app._unhandled_key_input(key(KEY_ESCAPE))
	check(not app.locks.has_owner(&"trade") and not app.gameplay_session.clock.is_paused() and app.room.get_player().is_input_enabled,"Esc closes only trade modal and releases its pause/input token")

	var saved: Dictionary = app.save_progress()
	check(saved.ok,"shop trade progress saves after modal closes")
	var expected_money: int = app.gameplay_session.wallet.money
	var expected_seeds: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	if saved.ok:
		app.return_to_title()
		app._on_action("read_save",{"save_id":saved.save_id})
		check(await wait_world() and app.room.get_space_id()=="space.shop","trade save restarts directly inside shop")
		check(app.gameplay_session.wallet.money==expected_money and app.gameplay_session.inventory.quantity_of("item.radish_seed")==expected_seeds,"schema-four restart preserves completed trade results")

	check(app.gameplay_session.advance(720).ok and app.gameplay_session.clock.minute_of_day()==1200,"test advances one clock to exclusive shop close time")
	open_counter()
	var closed_buy: Button = find_button_with_prefix(app.view.body,"买 1")
	check(closed_buy!=null and closed_buy.disabled and closed_buy.tooltip_text.contains("已打烊"),"closed shop projects disabled buy action with textual reason")
	var closed_inventory_before: Dictionary = app.gameplay_session.inventory.projection()
	var closed_wallet_before: Dictionary = app.gameplay_session.wallet.projection()
	app._on_action("trade_buy",{"item_id":"item.radish_seed","quantity":1})
	check(app.last_error.contains("SHOP_CLOSED") and app.gameplay_session.inventory.projection()==closed_inventory_before and app.gameplay_session.wallet.projection()==closed_wallet_before,"domain still rejects direct buy intent while closed without mutation")
	app._unhandled_key_input(key(KEY_ESCAPE))

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("SHOP_TRADE_UI_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
