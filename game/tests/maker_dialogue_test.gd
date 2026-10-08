extends SceneTree

const MAIN = preload("res://app/main.tscn")
const MAKER := "resident.maker"
const FIRST_EVENT := "event.resident.maker.met_player"
const GIFT_EVENT := "event.resident.maker.gift.day.1.1"

var checks := 0
var failures := 0
var app: Control

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("CHECK_FAIL maker_dialogue ",label)

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
	for tick in range(35):
		await physics_frame
		await process_frame
		if app.state==app.State.WORLD and is_instance_valid(app.room) and app.room.get_space_id()==space_id and not app._transition_pending:
			return true
	return false

func enter_workshop() -> bool:
	app.room.get_player().position=Vector2(584,208)
	app.room.get_player().facing=&"east"
	app._unhandled_key_input(key(KEY_E))
	if not await wait_space("space.village"):
		return false
	app.room.get_player().position=Vector2(520,192)
	app.room.get_player().facing=&"south"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.workshop")

func face_maker() -> void:
	app.room.get_player().position=app.room.maker_resident.position+Vector2(0,20)
	app.room.get_player().facing=&"north"

func open_maker_dialogue() -> void:
	face_maker()
	app._unhandled_key_input(key(KEY_E))

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(35).timeout.connect(func(): printerr("MAKER_DIALOGUE_TIMEOUT"); quit(1))
	app=MAIN.instantiate()
	app.store.directory="user://maker_dialogue_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(app)
	current_scene=app
	app.set_application_focused(true)
	app._on_action("new_game",{})
	app.view.player_name.text="小禾"
	app._on_action("create",{})
	check(await wait_world() and app.room.get_space_id()=="space.farm","new game starts on farm")
	if app.state!=app.State.WORLD:
		finish()
		return
	check(await enter_workshop(),"farm and village doors enter the workshop")
	if app.room.get_space_id()!="space.workshop":
		finish()
		return
	app.set_process(false)
	check(app.gameplay_session.advance(180).ok,"unique game clock reaches 09:00 workshop work period")

	# Isolated interaction fixture: use the legitimate work marker. Actual
	# cross-space physical travel remains covered by resident handoff tests.
	check(app.gameplay_session.update_resident_runtime({
		"resident_id":MAKER,
		"space_id":"space.workshop",
		"world_position_px":{"x":150.0,"y":92.0},
		"facing":"south"
	}),"fixture places maker runtime at existing workshop work marker")
	app._refresh_farm_world()
	check(app.room.apply_resident_runtime(app.gameplay_session.resident_runtime.projection()),"workshop restores maker at safe marker")
	check(app.room.maker_resident.is_world_active(),"maker actor is visible and physically active in workshop")

	face_maker()
	var target: Dictionary=app.room.resolve_interaction_target()
	check(target.get("kind","")=="resident_dialogue" and target.get("interaction_id","")=="dialogue.workshop.maker","facing nearby maker resolves workshop dialogue")
	open_maker_dialogue()
	await process_frame
	check(app.locks.has_owner(&"dialogue") and app.gameplay_session.clock.is_paused(),"maker conversation locks player input and only one game clock")
	check(String(app._dialogue_context.get("dialogue_id",""))=="dialogue.maker.first_meeting","maker first meeting uses authored content")
	check(String(app._dialogue_context.get("text","")).contains("工坊忙活"),"maker introduction matches workshop occupation")
	check(String(app._dialogue_context.get("display_name",""))=="工匠","speaker is the actual resident identity")
	check(app.view.dialogue_panel!=null and app.view.dialogue_panel.visible,"world bottom dialogue panel is reused")
	app._on_action("close_dialogue",{})
	check(app.gameplay_session.fact_events.has_event(FIRST_EVENT) and app.gameplay_session.resident_runtime.knows_event(MAKER,FIRST_EVENT),"first meeting commits CORE fact and maker experience")
	check(not app.gameplay_session.resident_runtime.knows_event("resident.neighbor",FIRST_EVENT) and not app.gameplay_session.resident_runtime.knows_event("resident.grocer",FIRST_EVENT),"unrelated residents remain unaware")

	open_maker_dialogue()
	await process_frame
	check(String(app._dialogue_context.get("dialogue_id",""))=="dialogue.maker.greeting","maker revisit uses authored line")
	var before_greeting: int=int(app.gameplay_session.resident_runtime.relationship_points_for(MAKER))
	app._on_action("close_dialogue",{})
	check(app.gameplay_session.resident_runtime.relationship_points_for(MAKER)==before_greeting+1,"first daily maker greeting gains configured relationship point")
	check(app.gameplay_session.fact_events.has_event("event.resident.maker.greeting.day.1.1"),"maker greeting creates one capped FactEvent")

	check(app.gameplay_session.inventory.add("item.radish",2).ok,"fixture provides giftable harvested radish through inventory domain")
	var slot_index := -1
	for index in range(app.gameplay_session.inventory.slots.size()):
		var slot: Variant=app.gameplay_session.inventory.slots[index]
		if slot!=null and String(slot.item_id)=="item.radish":
			slot_index=index
	check(slot_index>=0,"radish has a valid inventory slot")
	if slot_index>=0:
		app._select_inventory_slot(slot_index)
		open_maker_dialogue()
		await process_frame
		check(app.view.buttons.has("gift_resident") and not (app.view.buttons["gift_resident"] as Button).disabled,"maker revisit offers selected radish gift")
		var quantity_before: int=int(app.gameplay_session.inventory.quantity_of("item.radish"))
		var relationship_before: int=int(app.gameplay_session.resident_runtime.relationship_points_for(MAKER))
		app._on_action("gift_resident",{})
		await process_frame
		check(app.gameplay_session.inventory.quantity_of("item.radish")==quantity_before-1,"maker gift spends one radish")
		check(app.gameplay_session.resident_runtime.relationship_points_for(MAKER)==relationship_before+2,"maker gift applies content-configured relationship gain")
		check(app.gameplay_session.fact_events.has_event(GIFT_EVENT) and app.gameplay_session.resident_runtime.knows_event(MAKER,GIFT_EVENT),"gift fact and maker known event settle atomically")
		check((app.view.buttons["gift_resident"] as Button).disabled,"daily gift limit disables second maker gift")
		app._on_action("close_dialogue",{})

	app.room.get_player().position=Vector2(320,320)
	app.room.get_player().facing=&"south"
	var exit_target: Dictionary=app.room.resolve_interaction_target()
	check(exit_target.get("kind","")=="door" and exit_target.get("target_space_id","")=="space.village","workshop return door remains independent of maker")
	var saved: Dictionary=app.save_progress()
	check(saved.ok,"maker facts and relationship can be saved in workshop")
	if saved.ok:
		app.set_process(true)
		app.return_to_title()
		app._on_action("read_save",{"save_id":saved.save_id})
		check(await wait_world() and app.room.get_space_id()=="space.workshop","schema-seven save restores workshop")
		app.set_process(false)
		check(app.gameplay_session.fact_events.has_event(FIRST_EVENT) and app.gameplay_session.resident_runtime.knows_event(MAKER,FIRST_EVENT),"first-meeting knowledge survives reload")
		check(app.gameplay_session.fact_events.has_event(GIFT_EVENT),"maker gift survives reload")
		check(String(app.gameplay_session.player_resident_dialogue_context(MAKER).dialogue_id)=="dialogue.maker.greeting","maker uses repeat line after reload")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("MAKER_DIALOGUE_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
