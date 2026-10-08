extends SceneTree

const MAIN = preload("res://app/main.tscn")

var checks := 0
var failures := 0
var app: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL door_transition ", label)

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

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(30).timeout.connect(func(): printerr("DOOR_TRANSITION_TIMEOUT"); quit(1))
	app = MAIN.instantiate()
	app.store.directory = "user://door_transition_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(app)
	current_scene = app
	app.set_application_focused(true)

	app._on_action("new_game",{})
	app.view.player_name.text = "小禾"
	app.view.dog_name.text = "阿豆"
	app._on_action("create",{})
	check(await wait_world(), "new game enters gameplay world")
	if app.state != app.State.WORLD:
		finish()
		return
	check(app.room.get_space_id() == "space.farm", "new gameplay begins on farm")
	var session_identity: RefCounted = app.gameplay_session
	var selected_before: int = app.gameplay_session.inventory.selected_slot_index

	# Begin a valid transition then cancel it before the staged target can commit.
	app.room.get_player().position = Vector2(144,160)
	app.room.get_player().facing = &"north"
	app._unhandled_key_input(key(KEY_E))
	check(app._transition_pending and app.locks.has_owner(&"transition"), "door E stages target and locks source input")
	check(app.room.get_space_id() == "space.farm" and app.room.get_player().position == Vector2(144,160), "source world remains authoritative before commit")
	check(app.save_progress().error_code == "SAVE_TRANSITION_BUSY", "save rejects a half-staged door transition")
	app._unhandled_key_input(key(KEY_ESCAPE))
	await physics_frame
	check(not app._transition_pending and app.room.get_space_id() == "space.farm", "Esc cancels staged door transition")
	check(app.room.get_player().position == Vector2(144,160), "cancel leaves player at source position")

	# Commit farm -> house.
	app.room.get_player().facing = &"north"
	app._unhandled_key_input(key(KEY_E))
	check(await wait_space("space.house"), "farm door commits into house after target validation")
	check(app.gameplay_session == session_identity, "door transition preserves one gameplay session")
	check(app.room.get_player().position == Vector2(320,320) and app.room.get_player().facing == &"north", "house arrival uses target-owned safe anchor and facing")
	check(app.active_snapshot.space_id == "space.house", "active world identity follows committed room")

	# Bad target validation must keep the already active house untouched.
	var bad_target := {
		"kind":"door",
		"interaction_id":"door.test.invalid",
		"target_space_id":"space.farm",
		"arrival_anchor_id":"MissingArrival",
		"arrival_facing":"south"
	}
	app._begin_door_transition(bad_target)
	await physics_frame
	await process_frame
	check(app.room.get_space_id() == "space.house" and not app._transition_pending, "invalid target anchor fails without replacing source room")
	check(app.room.get_player().position == Vector2(320,320), "failed target validation does not move source player")

	# Save while inside and restart through the space-aware load path.
	app._select_inventory_slot(2)
	selected_before = app.gameplay_session.inventory.selected_slot_index
	var house_save: Dictionary = app.save_progress()
	check(house_save.ok, "house gameplay save succeeds")
	if house_save.ok:
		var envelope: Dictionary = app.store.read_save(house_save.save_id).envelope
		check(envelope.snapshot.space_id == "space.house" and int(envelope.schema_version) == 5, "house save records current space in schema five")
		app.return_to_title()
		app._on_action("read_save",{"save_id":house_save.save_id})
		check(await wait_world() and app.room.get_space_id() == "space.house", "schema-five save restarts directly inside house")
		check(app.gameplay_session.inventory.selected_slot_index == selected_before, "house load restores gameplay from authoritative farm plot layout")

	# House -> farm and a repeated player-only transition loop exercise lifecycle.
	app.room.get_player().position = Vector2(320,320)
	app.room.get_player().facing = &"south"
	app._unhandled_key_input(key(KEY_E))
	check(await wait_space("space.farm"), "house door returns to farm")
	check(app.room.get_player().position == Vector2(144,160) and app.room.get_player().facing == &"south", "farm arrival uses farm-owned safe anchor")

	for cycle in range(20):
		app.room.get_player().position = Vector2(144,160)
		app.room.get_player().facing = &"north"
		app._unhandled_key_input(key(KEY_E))
		if not await wait_space("space.house"):
			check(false, "player-only farm-house transition %d" % cycle)
			break
		app.room.get_player().position = Vector2(320,320)
		app.room.get_player().facing = &"south"
		app._unhandled_key_input(key(KEY_E))
		if not await wait_space("space.farm"):
			check(false, "player-only house-farm transition %d" % cycle)
			break
	check(app.gameplay_session.inventory.selected_slot_index == selected_before, "repeated room swaps keep gameplay session state")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("DOOR_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
