extends SceneTree

const MAIN = preload("res://app/main.tscn")

var checks := 0
var failures := 0
var app: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL village_shop ", label)

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

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(30).timeout.connect(func(): printerr("VILLAGE_SHOP_TIMEOUT"); quit(1))
	app = MAIN.instantiate()
	app.store.directory = "user://village_shop_"+Crypto.new().generate_random_bytes(8).hex_encode()
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
	var session_identity: RefCounted = app.gameplay_session

	app.room.get_player().position = Vector2(584,208)
	app.room.get_player().facing = &"east"
	var farm_target: Dictionary = app.room.resolve_interaction_target()
	check(farm_target.get("target_space_id","")=="space.village","farm bridge exit resolves village route")
	app._unhandled_key_input(key(KEY_E))
	check(await wait_space("space.village"),"farm route commits into village")
	check(app.gameplay_session==session_identity and app.room.get_player().position==Vector2(48,180) and app.room.get_player().facing==&"east","village arrival preserves gameplay session and target-owned anchor")
	check(app.room.layout_contract_valid(),"village editable route contract validates")

	app.room.get_player().position = Vector2(400,168)
	app.room.get_player().facing = &"north"
	var shop_target: Dictionary = app.room.resolve_interaction_target()
	check(shop_target.get("target_space_id","")=="space.shop","village shop door resolves shop interior")
	app._unhandled_key_input(key(KEY_E))
	check(await wait_space("space.shop"),"village shop door commits into shop")
	check(app.gameplay_session==session_identity and app.room.get_player().position==Vector2(320,320),"shop arrival preserves the one gameplay session")
	check(app.room.layout_contract_valid() and app.room.get_anchor_position("CounterInteract")==Vector2(320,144),"shop owns stable counter interaction anchor")

	var wallet_before: Dictionary = app.gameplay_session.wallet.projection()
	var inventory_before: Dictionary = app.gameplay_session.inventory.projection()
	app.room.get_player().position = Vector2(320,160)
	app.room.get_player().facing = &"north"
	app._unhandled_key_input(key(KEY_E))
	check(app.gameplay_session.wallet.projection()==wallet_before and app.gameplay_session.inventory.projection()==inventory_before,"counter anchor does not fabricate trading before trade UI slice")

	var saved: Dictionary = app.save_progress()
	check(saved.ok,"shop gameplay position saves")
	if saved.ok:
		var envelope: Dictionary = app.store.read_save(saved.save_id).envelope
		check(envelope.snapshot.space_id=="space.shop" and int(envelope.schema_version)==4,"shop save records current space in schema four")
		app.return_to_title()
		app._on_action("read_save",{"save_id":saved.save_id})
		check(await wait_world() and app.room.get_space_id()=="space.shop","shop save restarts directly in shop")
		check(app.gameplay_session.wallet.projection()==wallet_before and app.gameplay_session.inventory.projection()==inventory_before,"shop restart restores gameplay while farm plot layout remains authoritative")

	app.room.get_player().position = Vector2(320,320)
	app.room.get_player().facing = &"south"
	app._unhandled_key_input(key(KEY_E))
	check(await wait_space("space.village"),"shop door returns to village")
	check(app.room.get_player().position==Vector2(400,168) and app.room.get_player().facing==&"south","shop exit uses village-owned safe arrival")

	app.room.get_player().position = Vector2(48,180)
	app.room.get_player().facing = &"west"
	app._unhandled_key_input(key(KEY_E))
	check(await wait_space("space.farm"),"village west route returns to farm")
	check(app.room.get_player().position==Vector2(592,208) and app.room.get_player().facing==&"west","farm bridge arrival is safe and target-owned")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("VILLAGE_SHOP_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
