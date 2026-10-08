extends SceneTree

const MAIN = preload("res://app/main.tscn")

const FIRST_EVENT := "event.resident.neighbor.met_player"

var checks := 0
var failures := 0
var app: Control

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL player_resident_dialogue ",label)

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

func wait_space(space_id: String) -> bool:
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

func face_neighbor() -> void:
	var neighbor: CharacterBody2D = app.room.neighbor_resident
	app.room.get_player().position=neighbor.position+Vector2(0,20)
	app.room.get_player().facing=&"north"

func open_neighbor_dialogue() -> void:
	face_neighbor()
	app._unhandled_key_input(key(KEY_E))

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(35).timeout.connect(func(): printerr("PLAYER_RESIDENT_DIALOGUE_TIMEOUT"); quit(1))
	app=MAIN.instantiate()
	app.store.directory="user://player_resident_dialogue_"+Crypto.new().generate_random_bytes(8).hex_encode()
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
	check(await farm_to_village(),"player reaches village through real route")
	if app.room.get_space_id()!="space.village":
		finish()
		return
	app.set_process(false)

	face_neighbor()
	var target: Dictionary = app.room.resolve_interaction_target()
	check(target.get("kind","")=="resident_dialogue" and target.get("resident_id","")=="resident.neighbor","facing nearby neighbor resolves resident dialogue target")

	var minute_before := int(app.gameplay_session.clock.game_minute)
	open_neighbor_dialogue()
	await process_frame
	check(app.locks.has_owner(&"dialogue") and app.gameplay_session.clock.is_paused(),"opening dialogue owns input and pauses the single gameplay clock")
	check(app.gameplay_session.clock.game_minute==minute_before,"dialogue does not advance game time")
	check(app.view.dialogue_panel!=null and app.view.dialogue_panel.visible,"dialogue uses the in-world bottom panel")
	check(String(app._dialogue_context.get("display_name",""))=="邻居" and bool(app._dialogue_context.get("is_first_meeting",false)),"first interaction resolves authored first-meeting context")
	check(String(app._dialogue_context.get("text","")).contains("刚搬来吧"),"first meeting text comes from content_version")
	check(app.gameplay_session.fact_events.projection().events.is_empty(),"showing the line alone does not prematurely create a fact")

	app._on_action("close_dialogue",{})
	await process_frame
	check(not app.locks.has_owner(&"dialogue") and not app.gameplay_session.clock.is_paused(),"ending dialogue releases only its input/clock owner")
	check(app.gameplay_session.fact_events.has_event(FIRST_EVENT),"completed first meeting creates one CORE FactEvent")
	check(app.gameplay_session.resident_runtime.knows_event("resident.neighbor",FIRST_EVENT),"participating neighbor learns the first-meeting fact")
	check(not app.gameplay_session.resident_runtime.knows_event("resident.grocer",FIRST_EVENT) and not app.gameplay_session.resident_runtime.knows_event("resident.maker",FIRST_EVENT),"other residents do not become globally omniscient")

	var event: Dictionary = app.gameplay_session.fact_event(FIRST_EVENT)
	check(event.kind=="resident.met_player" and event.source_system=="dialogue.authored" and event.participant_ids==["actor.player","resident.neighbor"],"first-meeting fact keeps authored provenance and real participants")
	check(int(event.game_minute)==minute_before and String(event.payload.dialogue_id)=="dialogue.neighbor.first_meeting","fact records original game minute and dialogue id")

	var facts_after_first := app.gameplay_session.fact_events.projection().events.size()
	open_neighbor_dialogue()
	await process_frame
	check(app.locks.has_owner(&"dialogue") and not bool(app._dialogue_context.get("is_first_meeting",true)),"repeat interaction resolves revisit context")
	check(String(app._dialogue_context.get("text","")).contains("今天也来村里转转"),"repeat text comes from content_version")
	app._on_action("close_dialogue",{})
	await process_frame
	check(app.gameplay_session.fact_events.projection().events.size()==facts_after_first,"repeat greeting does not duplicate the first-meeting fact")

	var saved: Dictionary = app.save_progress()
	check(saved.ok,"dialogue knowledge can be saved after modal closes")
	if saved.ok:
		var envelope: Dictionary = app.store.read_save(saved.save_id).envelope
		check(int(envelope.schema_version)==7 and envelope.snapshot.gameplay.fact_events.events.size()==1,"schema seven persists the dialogue fact log")
		app.set_process(true)
		app.return_to_title()
		app._on_action("read_save",{"save_id":saved.save_id})
		check(await wait_world() and app.room.get_space_id()=="space.village","schema-seven dialogue save restarts in village")
		app.set_process(false)
		check(app.gameplay_session.fact_events.has_event(FIRST_EVENT) and app.gameplay_session.resident_runtime.knows_event("resident.neighbor",FIRST_EVENT),"reload restores fact and neighbor knowledge together")
		open_neighbor_dialogue()
		await process_frame
		check(not bool(app._dialogue_context.get("is_first_meeting",true)) and String(app._dialogue_context.get("dialogue_id",""))=="dialogue.neighbor.greeting","reloaded neighbor immediately uses revisit dialogue")
		app._on_action("close_dialogue",{})

	var told: Dictionary = app.gameplay_session.resident_tell_event("resident.neighbor","resident.grocer",FIRST_EVENT)
	check(told.ok and app.gameplay_session.resident_runtime.knows_event("resident.grocer",FIRST_EVENT),"explicit telling can teach the logged fact after the teller knows it")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("PLAYER_RESIDENT_DIALOGUE_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
