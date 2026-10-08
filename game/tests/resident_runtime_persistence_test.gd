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
		print("CHECK_FAIL resident_persistence ",label)

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
	for tick in range(30):
		await physics_frame
		await process_frame
		if app.state==app.State.WORLD and is_instance_valid(app.room) and app.room.has_method("get_space_id") and app.room.get_space_id()==space_id and not app._transition_pending:
			return true
	return false

func farm_to_village() -> bool:
	app.room.get_player().position=Vector2(584,208)
	app.room.get_player().facing=&"east"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.village")

func village_to_farm() -> bool:
	app.room.get_player().position=Vector2(48,180)
	app.room.get_player().facing=&"west"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.farm")

func resident_row(snapshot: Dictionary, resident_id:String) -> Dictionary:
	for row: Variant in snapshot.residents:
		if String(row.get("resident_id",""))==resident_id:
			return row
	return {}

func point(row: Dictionary) -> Vector2:
	return Vector2(float(row.world_position_px.x),float(row.world_position_px.y))

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(40).timeout.connect(func(): printerr("RESIDENT_PERSISTENCE_TIMEOUT"); quit(1))
	app=MAIN.instantiate()
	app.store.directory="user://resident_persistence_"+Crypto.new().generate_random_bytes(8).hex_encode()
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
	var initial_read: Dictionary = app.store.read_save(app.active_save_id)
	check(initial_read.ok and int(initial_read.envelope.schema_version)==6,"new gameplay save writes schema six")
	check(initial_read.envelope.snapshot.gameplay.residents.residents.size()==3,"schema six persists all three resident runtime rows")

	app.set_process(false)
	check(await farm_to_village(),"normal route reaches village")
	if app.room.get_space_id()!="space.village":
		finish()
		return
	var neighbor: CharacterBody2D = app.room.neighbor_resident
	neighbor.speed_px_per_sec=120.0
	check(app.gameplay_session.advance(120).ok and app.gameplay_session.clock.minute_of_day()==480,"clock reaches work period")
	app._refresh_farm_world()
	for tick in range(12):
		await physics_frame
	var mid_route := neighbor.position
	check(mid_route.distance_to(Vector2(112,240))>8.0 and mid_route.distance_to(Vector2(208,208))>8.0,"neighbor is genuinely mid-route before save")
	var saved_facing := str(neighbor.facing)

	var saved: Dictionary = app.save_progress()
	check(saved.ok,"mid-route resident state saves")
	if not saved.ok:
		finish()
		return
	var envelope: Dictionary = app.store.read_save(saved.save_id).envelope
	var persisted: Dictionary = resident_row(envelope.snapshot.gameplay.residents,"resident.neighbor")
	check(int(envelope.schema_version)==6 and not persisted.is_empty(),"mid-route save uses schema six resident state")
	check(point(persisted).distance_to(mid_route)<0.01 and String(persisted.facing)==saved_facing,"save captures actual resident position and facing, not schedule target")

	app.set_process(true)
	app.return_to_title()
	app._on_action("read_save",{"save_id":saved.save_id})
	check(await wait_world() and app.room.get_space_id()=="space.village","schema-six save restarts directly in village")
	app.set_process(false)
	var restored_neighbor: CharacterBody2D = app.room.neighbor_resident
	var restored_position := restored_neighbor.position
	check(restored_position.distance_to(mid_route)<6.0 and restored_position.distance_to(Vector2(112,240))>8.0,"restart restores resident near saved mid-route position instead of home")

	# Leaving the village samples the current body before the room is destroyed.
	var before_exit := restored_neighbor.position
	check(await village_to_farm(),"village exit succeeds after resident runtime capture")
	check(await farm_to_village(),"return route recreates village")
	app.set_process(false)
	var returned_neighbor: CharacterBody2D = app.room.neighbor_resident
	check(returned_neighbor.position.distance_to(before_exit)<8.0 and returned_neighbor.position.distance_to(Vector2(112,240))>8.0,"leave and re-enter restores last captured resident position instead of scene default")

	# A schema-five snapshot has no resident runtime state. Loading it explicitly
	# initializes residents from real home anchors, then future saves upgrade to v6.
	var legacy_gameplay: Dictionary = app.gameplay_session.snapshot()
	legacy_gameplay.erase("residents")
	var identity: Dictionary = app.active_snapshot.duplicate(true)
	identity.erase("gameplay")
	identity.space_id="space.village"
	identity.world_position_px={"x":48.0,"y":180.0}
	identity.facing="east"
	var legacy_full: Dictionary = CODEC.compose_gameplay_snapshot(identity,legacy_gameplay)
	var legacy_write: Dictionary = app.store.write_new(legacy_full)
	check(legacy_write.ok,"legacy resident-less gameplay snapshot remains writable")
	if legacy_write.ok:
		var legacy_read: Dictionary = app.store.read_save(legacy_write.save_id)
		check(legacy_read.ok and int(legacy_read.envelope.schema_version)==5,"resident-less compatibility save remains schema five")
		app.set_process(true)
		app.return_to_title()
		app._on_action("read_save",{"save_id":legacy_write.save_id})
		check(await wait_world() and app.room.get_space_id()=="space.village","schema-five save remains readable")
		app.set_process(false)
		check(app.room.neighbor_resident.position.distance_to(Vector2(112,240))<8.0,"schema-five migration initializes neighbor from WORLD home anchor")
		var upgraded: Dictionary = app.save_progress()
		check(upgraded.ok and int(app.store.read_save(upgraded.save_id).envelope.schema_version)==6,"next save after schema-five restore upgrades to schema six")

	var bad: Dictionary = app.gameplay_session.snapshot()
	var bad_neighbor: Dictionary = resident_row(bad.residents,"resident.neighbor")
	bad_neighbor.space_id="space.unknown"
	for index in range(bad.residents.residents.size()):
		if String(bad.residents.residents[index].resident_id)=="resident.neighbor":
			bad.residents.residents[index]=bad_neighbor
	var before_bad: Dictionary = app.gameplay_session.snapshot()
	check(not app.gameplay_session.restore(bad) and app.gameplay_session.snapshot()==before_bad,"invalid resident space cannot partially restore gameplay state")

	var blocked_runtime: Dictionary = app.gameplay_session.resident_runtime.projection()
	var blocked_neighbor: Dictionary = resident_row(blocked_runtime,"resident.neighbor")
	blocked_neighbor.space_id="space.village"
	blocked_neighbor.world_position_px={"x":400.0,"y":80.0}
	for index in range(blocked_runtime.residents.size()):
		if String(blocked_runtime.residents[index].resident_id)=="resident.neighbor":
			blocked_runtime.residents[index]=blocked_neighbor
	var before_blocked := app.room.neighbor_resident.position
	check(not app.room.apply_resident_runtime(blocked_runtime) and app.room.neighbor_resident.position==before_blocked,"WORLD rejects resident restore inside a solid footprint without moving the actor")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("RESIDENT_PERSISTENCE_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
