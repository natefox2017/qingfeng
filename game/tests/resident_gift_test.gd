extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const SESSION = preload("res://app/gameplay_session.gd")
const CODEC = preload("res://persistence/session_codec.gd")
const FARM = preload("res://world/farm_first_screen.tscn")
const VILLAGE = preload("res://world/village_first_screen.tscn")
const SHOP = preload("res://world/shop_interior.tscn")
const WORKSHOP = preload("res://world/workshop_interior.tscn")

const RESIDENT := "resident.neighbor"
const FIRST_DIALOGUE := "dialogue.neighbor.first_meeting"
const GIFT_ID := "event.resident.neighbor.gift.day.1.1"

var checks := 0
var failures := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("CHECK_FAIL resident_gift ",label)

func scene_data(scene: PackedScene, method: String) -> Array:
	var instance := scene.instantiate()
	var data: Array = instance.call(method)
	instance.free()
	return data

func new_session() -> RefCounted:
	var anchors: Array = []
	for scene: PackedScene in [VILLAGE,SHOP,WORKSHOP]:
		anchors.append_array(scene_data(scene,"get_resident_anchor_definitions"))
	return SESSION.new(
		scene_data(FARM,"get_plot_definitions"),
		{},
		scene_data(VILLAGE,"get_forage_definitions"),
		anchors
	)

func invite(session: RefCounted, id: String) -> bool:
	var invited: Dictionary = session.invite_resident_conversation(id,"actor.player",RESIDENT,"space.village")
	if not invited.ok:
		return false
	if not session.approach_resident_conversation(id).ok:
		return false
	return bool(session.begin_resident_conversation(id).ok)

func command(id: String, revision: int, item_id: String, quantity := 1) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":id,
		"session_id":"session.gift.check",
		"actor_id":"actor.player",
		"action":"resident.gift",
		"expected_revision":revision,
		"payload":{"resident_id":RESIDENT,"item_id":item_id,"quantity":quantity}
	}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var loaded: Dictionary = CONTENT.load_current()
	check(loaded.ok,"current gift content loads")
	if not loaded.ok:
		finish()
		return
	check(loaded.data.residents.gift_item_ids==["item.radish","item.wild_herb"] and int(loaded.data.residents.gift_relationship_points)==2,"gift eligibility and gain come from content")

	var session: RefCounted = new_session()
	check(session.is_configured(),"full gameplay session configures")
	if not session.is_configured():
		finish()
		return
	var missing_conversation: Dictionary = session.execute(command("gift.no.conversation",session.inventory.revision,"item.wild_herb"))
	check(not missing_conversation.ok and missing_conversation.error_code=="RESIDENT_GIFT_CONVERSATION_REQUIRED","gift cannot bypass active conversation")

	check(invite(session,"conversation.gift.day1"),"player and neighbor occupy one live participating conversation")
	var no_first_meeting: Dictionary = session.execute(command("gift.before.meeting",session.inventory.revision,"item.wild_herb"))
	check(not no_first_meeting.ok and no_first_meeting.error_code=="RESIDENT_GIFT_FIRST_MEETING_REQUIRED","first acquaintance must finish before gift")
	check(session.complete_player_resident_dialogue(RESIDENT,FIRST_DIALOGUE).ok,"first meeting logs and teaches its own fact")

	var before_tool: Dictionary = session.inventory.projection()
	var bad_tool: Dictionary = session.execute(command("gift.tool",session.inventory.revision,"item.hoe"))
	check(not bad_tool.ok and bad_tool.error_code=="RESIDENT_GIFT_ITEM_NOT_ALLOWED" and session.inventory.projection()==before_tool,"tools cannot be gifted or removed")

	check(session.inventory.add("item.wild_herb",3).ok,"test obtains three forage items via inventory domain")
	var slot_index := -1
	for index in range(session.inventory.slots.size()):
		var slot: Variant = session.inventory.slots[index]
		if slot!=null and String(slot.item_id)=="item.wild_herb":
			slot_index=index
	check(slot_index>=0,"forage item has a real backpack slot")
	if slot_index<0:
		finish()
		return
	var select_result: Dictionary = session.execute({
		"protocol_version":1,"command_id":"gift.select","session_id":"session.gift.check",
		"actor_id":"actor.player","action":"inventory.select",
		"expected_revision":int(session.inventory.revision),"payload":{"slot_index":slot_index}
	})
	check(select_result.ok,"gift source is selected through inventory.select")
	var offer: Dictionary = session.resident_gift_offer(RESIDENT)
	check(offer.can_gift and offer.item_id=="item.wild_herb" and int(offer.relationship_points)==2,"dialogue gift offer reflects selected item and real content")

	var stale: Dictionary = session.execute(command("gift.stale",session.inventory.revision-1,"item.wild_herb"))
	check(not stale.ok and stale.error_code=="STALE_REVISION" and stale.is_retryable,"stale inventory revision fails without mutation")
	var wrong_quantity: Dictionary = session.execute(command("gift.two",session.inventory.revision,"item.wild_herb",2))
	check(not wrong_quantity.ok and wrong_quantity.error_code=="RESIDENT_GIFT_PAYLOAD_INVALID","one gift transfers one item only")
	var wrong_selection: Dictionary = session.execute(command("gift.unselected",session.inventory.revision,"item.radish"))
	check(not wrong_selection.ok and wrong_selection.error_code=="RESIDENT_GIFT_SELECTED_MISMATCH","gift command cannot bypass the selected slot")

	var revision: int = int(session.inventory.revision)
	var before_relationship: int = int(session.resident_runtime.relationship_points_for(RESIDENT))
	var first_command := command("gift.day1",revision,"item.wild_herb")
	var first: Dictionary = session.execute(first_command)
	check(first.ok and first.has_changes and first.event_ids==[GIFT_ID],"first gift returns one authoritative event")
	check(session.inventory.quantity_of("item.wild_herb")==2 and int(session.inventory.revision)==revision+1,"gift removes exactly one item in one revision")
	check(session.resident_runtime.relationship_points_for(RESIDENT)==before_relationship+2,"gift increases relationship by configured amount")
	var gift_fact: Dictionary = session.fact_event(GIFT_ID)
	check(gift_fact.kind=="resident.gift" and gift_fact.source_command_id=="gift.day1" and gift_fact.source_system==null,"gift fact is command-sourced")
	check(gift_fact.participant_ids==["actor.player",RESIDENT] and gift_fact.payload.item_id=="item.wild_herb" and int(gift_fact.payload.quantity)==1,"gift fact records participants and consumed item")
	check(session.resident_runtime.knows_event(RESIDENT,GIFT_ID),"recipient learns only the committed gift fact")

	var after_gift: Dictionary = session.snapshot()
	var replay: Dictionary = session.execute(first_command)
	check(replay==first and session.snapshot()==after_gift,"same id and same request replays without double-spending")
	var conflict: Dictionary = session.execute(command("gift.day1",revision,"item.radish"))
	check(not conflict.ok and conflict.error_code=="COMMAND_ID_CONFLICT","same id and a different gift conflicts")
	var same_day: Dictionary = session.execute(command("gift.again",session.inventory.revision,"item.wild_herb"))
	check(not same_day.ok and same_day.error_code=="RESIDENT_GIFT_DAILY_LIMIT","same-day new command reaches the daily cap")
	check(session.inventory.projection()==after_gift.inventory and session.resident_runtime.snapshot()==after_gift.residents and session.fact_events.snapshot()==after_gift.fact_events,"same-day rejection leaves inventory, relationship and facts unchanged")

	var identity: Dictionary = CODEC.new_snapshot("小禾","阿豆")
	identity.space_id="space.village"
	identity.world_position_px={"x":48.0,"y":180.0}
	var combined: Dictionary = CODEC.compose_gameplay_snapshot(identity,session.snapshot())
	var encoded: String = CODEC.encode(combined,"0123456789abcdef0123456789abcdef")
	var decoded: Dictionary = CODEC.decode(encoded)
	check(decoded.ok and int(decoded.envelope.schema_version)==7,"gift facts and receipts fit schema-seven save")
	var restored: RefCounted = new_session()
	check(restored.restore(decoded.envelope.snapshot.gameplay),"gift state restores with known fact and receipt")
	check(restored.inventory.quantity_of("item.wild_herb")==2 and restored.resident_runtime.relationship_points_for(RESIDENT)==before_relationship+2 and restored.fact_events.has_event(GIFT_ID),"gift inventory, relationship and fact survive reload")
	var replay_loaded: Dictionary = restored.execute(first_command)
	check(replay_loaded==first and restored.inventory.quantity_of("item.wild_herb")==2,"gift command receipt replays after reload without double spending")

	check(restored.advance(1440).ok and restored.clock.current_day()==2,"clock advances into day two without a second clock")
	check(invite(restored,"conversation.gift.day2"),"day-two player conversation is re-established after reload")
	var next_day: Dictionary = restored.execute(command("gift.day2",restored.inventory.revision,"item.wild_herb"))
	check(next_day.ok and next_day.event_ids==["event.resident.neighbor.gift.day.2.1"],"day-two gift resets daily quota")
	check(restored.inventory.quantity_of("item.wild_herb")==1 and restored.resident_runtime.relationship_points_for(RESIDENT)==before_relationship+4,"next day spends one more item and grants one more relationship gain")

	check(restored.end_resident_conversation("conversation.gift.day2").ok,"day-two conversation ends cleanly")
	check(restored.advance(1440).ok and restored.clock.current_day()==3,"clock reaches the next gift quota")
	check(invite(restored,"conversation.gift.day3"),"day-three conversation starts")
	var capped_runtime: Dictionary = restored.resident_runtime.snapshot()
	for row: Variant in capped_runtime.residents:
		if String(row.resident_id)==RESIDENT:
			row.relationship_points=1000000
	check(restored.resident_runtime.restore(capped_runtime),"test sets valid relationship cap through runtime restore")
	var before_failure_inventory: Dictionary = restored.inventory.projection()
	var before_failure_runtime: Dictionary = restored.resident_runtime.snapshot()
	var before_failure_facts: Dictionary = restored.fact_events.snapshot()
	var overflow: Dictionary = restored.execute(command("gift.relationship.cap",restored.inventory.revision,"item.wild_herb"))
	check(not overflow.ok and overflow.error_code=="RESIDENT_RELATIONSHIP_RANGE","relationship limit rejects otherwise eligible gift")
	check(restored.inventory.projection()==before_failure_inventory and restored.resident_runtime.snapshot()==before_failure_runtime and restored.fact_events.snapshot()==before_failure_facts,"failed gift rolls back all three authoritative domains")

	finish()

func finish() -> void:
	print("RESIDENT_GIFT_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
