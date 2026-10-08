extends SceneTree

const MAIN = preload("res://app/main.tscn")
const GROCER := "resident.grocer"
const FIRST_EVENT := "event.resident.grocer.met_player"

var checks := 0
var failures := 0
var app: Control

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("CHECK_FAIL grocer_dialogue ",label)

func key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.pressed=true
	return event

func wait_world() -> bool:
	for frame in range(180):
		await physics_frame
		if app.state==app.State.WORLD:
			return true
		if app.state==app.State.TITLE and not app.last_error.is_empty():
			return false
	return false

func wait_space(space_id: String) -> bool:
	for frame in range(35):
		await physics_frame
		await process_frame
		if app.state==app.State.WORLD and is_instance_valid(app.room) and app.room.get_space_id()==space_id and not app._transition_pending:
			return true
	return false

func go_to_shop() -> bool:
	app.room.get_player().position=app.room.get_anchor_position("VillagePathInteract") + Vector2.DOWN * 20.0
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))
	if not await wait_space("space.village"):
		return false
	app.room.get_player().position=Vector2(400,168)
	app.room.get_player().facing=&"north"
	app._unhandled_key_input(key(KEY_E))
	return await wait_space("space.shop")

func face_grocer() -> void:
	app.room.get_player().position=app.room.grocer_resident.position+Vector2(0,20)
	app.room.get_player().facing=&"north"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	create_timer(35).timeout.connect(func(): printerr("GROCER_DIALOGUE_TIMEOUT"); quit(1))
	app=MAIN.instantiate()
	app.store.directory="user://grocer_dialogue_"+Crypto.new().generate_random_bytes(8).hex_encode()
	root.add_child(app)
	current_scene=app
	app.set_application_focused(true)
	app._on_action("new_game",{})
	app.view.player_name.text="小禾"
	app._on_action("create",{})
	check(await wait_world() and app.room.get_space_id()=="space.farm","new game starts at the farm")
	if app.state!=app.State.WORLD:
		finish()
		return
	check(await go_to_shop(),"player enters shop via farm and village doors")
	if app.room.get_space_id()!="space.shop":
		finish()
		return
	app.set_process(false)
	check(app.gameplay_session.advance(120).ok,"single game clock reaches shop work window")

	# Test fixture only: the separate handoff regression proves physical travel.
	# Here we restore an explicitly legal shop work-marker runtime position to
	# isolate the player interaction and transaction boundary.
	check(app.gameplay_session.update_resident_runtime({
		"resident_id":GROCER,
		"space_id":"space.shop",
		"world_position_px":{"x":220.0,"y":144.0},
		"facing":"south"
	}),"fixture updates grocer runtime into the real shop space")
	app._refresh_farm_world()
	check(app.room.apply_resident_runtime(app.gameplay_session.resident_runtime.projection()),"shop restores grocer at a valid work marker")
	check(app.room.grocer_resident.is_world_active(),"grocer actor is present in shop WORLD")
	face_grocer()
	var conversation_target: Dictionary=app.room.resolve_interaction_target()
	check(conversation_target.get("kind","")=="resident_dialogue" and conversation_target.get("resident_id","")==GROCER,"facing nearby shopkeeper resolves grocer interaction")
	app._unhandled_key_input(key(KEY_E))
	await process_frame
	check(app.locks.has_owner(&"dialogue") and app.gameplay_session.clock.is_paused(),"grocer dialogue holds the single pause/input lock")
	check(app._dialogue_context.get("dialogue_id","")=="dialogue.grocer.first_meeting","first grocer line is authored content")
	check(String(app._dialogue_context.get("text","")).contains("缺种子"),"shopkeeper dialogue explains the real seed economy")
	check(String(app._dialogue_context.get("display_name",""))=="店主","dialogue speaker resolves actual resident display name")
	app._on_action("close_dialogue",{})
	check(app.gameplay_session.fact_events.has_event(FIRST_EVENT) and app.gameplay_session.resident_runtime.knows_event(GROCER,FIRST_EVENT),"first conversation atomically logs and teaches one fact")
	check(not app.gameplay_session.resident_runtime.knows_event("resident.neighbor",FIRST_EVENT),"neighbor does not automatically learn grocer's fact")

	face_grocer()
	app._unhandled_key_input(key(KEY_E))
	await process_frame
	check(app._dialogue_context.get("dialogue_id","")=="dialogue.grocer.greeting","repeat grocer line uses authored revisit content")
	var relationship_before: int=int(app.gameplay_session.resident_runtime.relationship_points_for(GROCER))
	app._on_action("close_dialogue",{})
	check(app.gameplay_session.resident_runtime.relationship_points_for(GROCER)==relationship_before+1,"first daily grocer greeting grants content-configured relationship reward")

	check(app.gameplay_session.inventory.add("item.wild_herb",2).ok,"fixture obtains giftable forage from inventory domain")
	var index := -1
	for slot_index in range(app.gameplay_session.inventory.slots.size()):
		var slot: Variant=app.gameplay_session.inventory.slots[slot_index]
		if slot!=null and String(slot.item_id)=="item.wild_herb":
			index=slot_index
	check(index>=0,"wild herb has a selectable backpack slot")
	if index>=0:
		app._select_inventory_slot(index)
		face_grocer()
		app._unhandled_key_input(key(KEY_E))
		await process_frame
		check(app.view.buttons.has("gift_resident") and not (app.view.buttons["gift_resident"] as Button).disabled,"grocer repeat dialog offers selected valid gift")
		var before_quantity: int=int(app.gameplay_session.inventory.quantity_of("item.wild_herb"))
		var before_points: int=int(app.gameplay_session.resident_runtime.relationship_points_for(GROCER))
		app._on_action("gift_resident",{})
		await process_frame
		check(app.gameplay_session.inventory.quantity_of("item.wild_herb")==before_quantity-1,"gift consumes exactly one wild herb")
		check(app.gameplay_session.resident_runtime.relationship_points_for(GROCER)==before_points+2,"gift increases grocer relationship by configured amount")
		check(app.gameplay_session.fact_events.has_event("event.resident.grocer.gift.day.1.1"),"grocer gift records one command-sourced FactEvent")
		check((app.view.buttons["gift_resident"] as Button).disabled,"second same-day grocer gift is disabled")
		app._on_action("close_dialogue",{})

	app.room.get_player().position=Vector2(320,160)
	app.room.get_player().facing=&"north"
	var counter: Dictionary=app.room.resolve_interaction_target()
	check(counter.get("kind","")=="trade" and counter.get("interaction_id","")=="trade.shop.counter","shop counter remains independent from grocer dialogue")
	app._unhandled_key_input(key(KEY_E))
	check(app.locks.has_owner(&"trade") and not app.locks.has_owner(&"dialogue"),"counter still opens actual economy transaction page")
	app._unhandled_key_input(key(KEY_ESCAPE))

	var saved: Dictionary=app.save_progress()
	check(saved.ok,"shop dialogue and gift state saves")
	if saved.ok:
		app.set_process(true)
		app.return_to_title()
		app._on_action("read_save",{"save_id":saved.save_id})
		check(await wait_world() and app.room.get_space_id()=="space.shop","shop reload retains real current space")
		app.set_process(false)
		check(app.gameplay_session.fact_events.has_event(FIRST_EVENT) and app.gameplay_session.resident_runtime.knows_event(GROCER,FIRST_EVENT),"schema-seven restore keeps grocer facts and knowledge")
		check(app.gameplay_session.fact_events.has_event("event.resident.grocer.gift.day.1.1"),"gift fact survives reload")

	finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	print("GROCER_DIALOGUE_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
