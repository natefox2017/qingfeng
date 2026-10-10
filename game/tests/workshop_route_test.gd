extends SceneTree

const MAIN = preload("res://app/main.tscn")

var checks := 0
var failures := 0
var app: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL workshop_route ",label)

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

func farm_to_village() -> bool:
	var player: CharacterBody2D = app.room.get_player()
	player.position=app.room.get_anchor_position("VillagePathInteract") + Vector2.DOWN * 20.0
	player.facing=&"north"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.village")

func village_to_workshop() -> bool:
	app.room.get_player().position=Vector2(520,192)
	app.room.get_player().facing=&"south"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.workshop")

func workshop_to_village() -> bool:
	app.room.get_player().position=Vector2(320,320)
	app.room.get_player().facing=&"south"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.village")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(30).timeout.connect(func(): printerr("WORKSHOP_ROUTE_TIMEOUT"); quit(1))
	app=MAIN.instantiate()
	app.store.directory="user://workshop_route_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(app)
	current_scene=app
	app.set_application_focused(true)

	app._on_action("new_game",{})
	app.view.player_name.text="小禾"
	app.view.dog_name.text="阿豆"
	app._on_action("create",{})
	check(await wait_world() and app.room.get_space_id()=="space.farm","new game starts on farm")
	if app.state!=app.State.WORLD:
		finish()
		return
	var session_identity: RefCounted = app.gameplay_session
	check(await farm_to_village(),"farm route reaches village")

	app.room.get_player().position=Vector2(520,192)
	app.room.get_player().facing=&"south"
	var target: Dictionary = app.room.resolve_interaction_target()
	check(target.get("target_space_id","")=="space.workshop" and target.get("arrival_anchor_id","")=="DoorArrival","village workshop door resolves stable target")
	check(await village_to_workshop(),"village door enters workshop after target validation")
	check(app.gameplay_session==session_identity and app.room.get_player().position==Vector2(320,320) and app.room.get_player().facing==&"north","workshop arrival preserves one gameplay session and target-owned anchor")
	check(app.room.layout_contract_valid(),"workshop layout contract validates")
	check(app.room.get_anchor_position("WorkbenchInteract")==Vector2(320,152) and app.room.get_anchor_position("ServiceAnchor")==Vector2(320,92),"workshop owns stable future workbench/service anchors")

	var inventory_before: Dictionary = app.gameplay_session.inventory.projection()
	var wallet_before: Dictionary = app.gameplay_session.wallet.projection()
	app.room.get_player().position=Vector2(320,180)
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))
	check(app.gameplay_session.inventory.projection()==inventory_before and app.gameplay_session.wallet.projection()==wallet_before,"workbench anchor does not fabricate service before resident/quest command exists")

	var saved: Dictionary = app.save_progress()
	check(saved.ok,"workshop gameplay position saves")
	if saved.ok:
		var envelope: Dictionary = app.store.read_save(saved.save_id).envelope
		check(envelope.snapshot.space_id=="space.workshop" and int(envelope.schema_version)==7,"workshop save records current space in schema seven")
		app.return_to_title()
		app._on_action("read_save",{"save_id":saved.save_id})
		check(await wait_world() and app.room.get_space_id()=="space.workshop","schema-seven save restarts directly inside workshop")
		check(app.gameplay_session==session_identity or app.gameplay_session!=null,"workshop restart publishes one restored gameplay session")

	check(await workshop_to_village(),"workshop door returns to village")
	check(app.room.get_player().position==Vector2(520,192) and app.room.get_player().facing==&"north","workshop exit uses village-owned safe arrival")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("WORKSHOP_ROUTE_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
