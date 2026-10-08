extends RefCounted
## Single in-memory gameplay session. It composes domain owners and provides the
## only command/projection surface that app/UI should consume.

const CONTENT = preload("res://content/content_catalog.gd")
const JOURNAL = preload("res://app/command_journal.gd")
const FACT_EVENTS = preload("res://app/fact_event_log.gd")
const CLOCK = preload("res://app/game_clock.gd")
const INVENTORY = preload("res://systems/inventory_domain.gd")
const WALLET = preload("res://systems/wallet_domain.gd")
const FARM = preload("res://systems/farm_domain.gd")
const FARMING = preload("res://systems/farming_coordinator.gd")
const STORAGE = preload("res://systems/storage_domain.gd")
const STORAGE_TRANSFER = preload("res://systems/storage_transfer.gd")
const ECONOMY = preload("res://systems/economy_coordinator.gd")
const FORAGE = preload("res://systems/forage_domain.gd")
const FORAGING = preload("res://systems/forage_coordinator.gd")
const RESIDENT_SCHEDULE = preload("res://systems/resident_schedule.gd")
const RESIDENT_RUNTIME = preload("res://systems/resident_runtime_state.gd")
const RESIDENT_CONVERSATIONS = preload("res://systems/resident_conversation_state.gd")
const RESIDENT_KNOWLEDGE = preload("res://systems/resident_knowledge_state.gd")

var configuration_error := ""
var content: Dictionary = {}
var journal: RefCounted
var fact_events: RefCounted
var clock: RefCounted
var inventory: RefCounted
var wallet: RefCounted
var farm: RefCounted
var farming: RefCounted
var storage: RefCounted
var storage_transfer: RefCounted
var economy: RefCounted
var forage: RefCounted
var foraging: RefCounted
var resident_schedule: RefCounted
var resident_runtime: RefCounted
var resident_conversations: RefCounted
var resident_knowledge: RefCounted
var _plot_definitions: Array = []
var _forage_definitions: Array = []
var _resident_anchor_definitions: Array = []

func _init(plot_definitions: Array = [], content_override: Dictionary = {}, forage_definitions: Array = [], resident_anchor_definitions: Array = []) -> void:
	var source := content_override
	if source.is_empty():
		var result: Dictionary = CONTENT.load_current()
		if not result.ok:
			configuration_error = result.error_code
			return
		source = result.data
	if not CONTENT.validate(source):
		configuration_error = "CONTENT_INVALID"
		return
	content = source.duplicate(true)
	_plot_definitions = plot_definitions.duplicate(true)
	_forage_definitions = forage_definitions.duplicate(true)
	_resident_anchor_definitions = resident_anchor_definitions.duplicate(true)
	journal = JOURNAL.new()
	fact_events = FACT_EVENTS.new()
	clock = CLOCK.new(content)
	inventory = INVENTORY.new(content)
	wallet = WALLET.new(content)
	farm = FARM.new(plot_definitions,content)
	farming = FARMING.new(inventory,farm,content)
	storage = STORAGE.new(content)
	storage_transfer = STORAGE_TRANSFER.new(inventory,storage)
	economy = ECONOMY.new(inventory,wallet,clock,content)
	forage = FORAGE.new(forage_definitions,content)
	foraging = FORAGING.new(inventory,forage,clock)
	resident_schedule = RESIDENT_SCHEDULE.new(resident_anchor_definitions,content)
	resident_runtime = RESIDENT_RUNTIME.new(resident_anchor_definitions,content)
	resident_conversations = RESIDENT_CONVERSATIONS.new(content)
	resident_knowledge = RESIDENT_KNOWLEDGE.new(resident_runtime,fact_events)
	if not fact_events.is_configured() or not clock.is_configured() or not inventory.is_configured() or not wallet.is_configured() or not farm.is_configured() or not farming.is_configured() or not storage.is_configured() or not storage_transfer.is_configured() or not economy.is_configured() or not forage.is_configured() or not foraging.is_configured() or not resident_schedule.is_configured() or not resident_runtime.is_configured() or not resident_conversations.is_configured() or not resident_knowledge.is_configured():
		configuration_error = "GAMEPLAY_SESSION_DOMAIN_INVALID"

func is_configured() -> bool:
	return configuration_error.is_empty() and journal != null

func execute(command: Dictionary) -> Dictionary:
	if not is_configured():
		return _failure(str(command.get("command_id","")),"GAMEPLAY_SESSION_NOT_CONFIGURED")
	var action := String(command.get("action",""))
	if action == "inventory.select":
		return journal.execute(command,inventory.handle_select)
	if action == "storage.transfer":
		return journal.execute(command,storage_transfer.handle)
	if action.begins_with("economy."):
		return journal.execute(command,economy.handle)
	if action == "forage.collect":
		return journal.execute(command,foraging.handle)
	if action == "resident.gift":
		return journal.execute(command,Callable(self,"_handle_resident_gift"))
	if action.begins_with("farm."):
		return journal.execute(command,farming.handle)
	return journal.execute(command,Callable(self,"_unsupported_command"))

func _unsupported_command(command: Dictionary) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":str(command.get("command_id","")),
		"ok":false,
		"error_code":"GAMEPLAY_ACTION_UNSUPPORTED",
		"is_retryable":false,
		"has_changes":false,
		"revision":0,
		"event_ids":[]
	}

func prepare_farm_action(plot_id: String) -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":"GAMEPLAY_SESSION_NOT_CONFIGURED","plot_id":plot_id}
	var plot: Dictionary = farm.get_plot(plot_id)
	if plot.is_empty():
		return {"ok":false,"error_code":"FARM_PLOT_UNKNOWN","plot_id":plot_id}
	var inventory_state: Dictionary = inventory.projection()
	var selected_index: int = int(inventory_state.selected_slot_index)
	var selected_slot: Variant = inventory_state.slots[selected_index]

	# Mature crops are harvested regardless of the currently held tool. Capacity
	# and inventory revision are still revalidated atomically at contact.
	if plot.state == "mature":
		return {
			"ok":true,
			"error_code":"",
			"plot_id":plot_id,
			"action":"farm.harvest",
			"expected_revision":farm.revision,
			"payload":{"plot_id":plot_id,"inventory_revision":inventory.revision}
		}
	if selected_slot == null:
		return {"ok":false,"error_code":"FARM_SELECTED_ITEM_REQUIRED","plot_id":plot_id}
	var item_id := String(selected_slot.item_id)
	if plot.state == "untilled" and item_id == "item.hoe":
		return {
			"ok":true,"error_code":"","plot_id":plot_id,
			"action":"farm.till","expected_revision":farm.revision,
			"payload":{"plot_id":plot_id}
		}
	if plot.state in ["tilled","growing"] and item_id == "item.watering_can":
		return {
			"ok":true,"error_code":"","plot_id":plot_id,
			"action":"farm.water","expected_revision":farm.revision,
			"payload":{"plot_id":plot_id}
		}
	if plot.state == "tilled":
		var crop_id := _crop_for_seed(item_id)
		if not crop_id.is_empty():
			return {
				"ok":true,"error_code":"","plot_id":plot_id,
				"action":"farm.plant","expected_revision":farm.revision,
				"payload":{"plot_id":plot_id,"crop_id":crop_id,"inventory_revision":inventory.revision}
			}
	return {"ok":false,"error_code":"FARM_SELECTED_ITEM_INVALID","plot_id":plot_id}

func _crop_for_seed(item_id: String) -> String:
	for crop_id: Variant in content.crops:
		if String(content.crops[crop_id].seed_item_id) == item_id:
			return String(crop_id)
	return ""

func acquire_pause(owner: StringName) -> bool:
	return is_configured() and clock.acquire_pause(owner)

func release_pause(owner: StringName) -> bool:
	return is_configured() and clock.release_pause(owner)

func advance_real_seconds(seconds: float) -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":"GAMEPLAY_SESSION_NOT_CONFIGURED","advanced_minutes":0,"crossed_days":[]}
	var clock_result: Dictionary = clock.advance_real_seconds(seconds)
	if not clock_result.ok:
		return clock_result
	var settlement: Dictionary = _settle_crossed_days(clock_result.crossed_days)
	if not settlement.ok:
		return {"ok":false,"error_code":settlement.error_code,"advanced_minutes":int(clock_result.advanced_minutes),"crossed_days":clock_result.crossed_days}
	return {
		"ok":true,
		"error_code":"",
		"advanced_minutes":int(clock_result.advanced_minutes),
		"crossed_days":clock_result.crossed_days
	}

func advance(minutes: int) -> Dictionary:
	if not is_configured():
		return _failure("","GAMEPLAY_SESSION_NOT_CONFIGURED")
	var clock_result: Dictionary = clock.advance(minutes)
	if not clock_result.ok:
		return clock_result
	var settlement := _settle_crossed_days(clock_result.crossed_days)
	if not settlement.ok:
		return settlement
	return {"ok":true,"error_code":"","crossed_days":clock_result.crossed_days}

func rest_to_next_day() -> Dictionary:
	if not is_configured():
		return _failure("","GAMEPLAY_SESSION_NOT_CONFIGURED")
	var clock_result: Dictionary = clock.rest_to_next_day_start()
	if not clock_result.ok:
		return clock_result
	var settlement := _settle_crossed_days(clock_result.crossed_days)
	if not settlement.ok:
		return settlement
	return {"ok":true,"error_code":"","crossed_days":clock_result.crossed_days}

func _settle_crossed_days(days: Array) -> Dictionary:
	for day: Variant in days:
		if not (day is int) or day <= 1:
			return {"ok":false,"error_code":"GAMEPLAY_DAY_INVALID"}
		var result: Dictionary = farm.settle_day(day)
		if not result.ok:
			return result
	return {"ok":true,"error_code":""}

func projection() -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":configuration_error}
	return {
		"ok":true,
		"error_code":"",
		"content_version":String(content.content_version),
		"clock":{
			"game_minute":clock.game_minute,
			"day":clock.current_day(),
			"minute_of_day":clock.minute_of_day(),
			"is_paused":clock.is_paused()
		},
		"inventory":inventory.projection(),
		"items":_item_projection(),
		"wallet":wallet.projection(),
		"shop":economy.projection(),
		"storage":storage.projection(),
		"forage":forage.projection(clock.current_day()),
		"residents":resident_schedule.projection(clock.game_minute,false),
		"resident_runtime":resident_runtime.projection(),
		"resident_knowledge":resident_knowledge.projection(),
		"fact_events":fact_events.projection(),
		"conversations":resident_conversations.projection(),
		"farm":farm.projection()
	}

func _item_projection() -> Dictionary:
	var result: Dictionary = {}
	for item_id: Variant in content.items:
		var item: Dictionary = content.items[item_id]
		result[String(item_id)] = {
			"display_name":String(item.display_name),
			"buy_price":int(item.buy_price),
			"sell_price":int(item.sell_price)
		}
	return result

func snapshot() -> Dictionary:
	if not is_configured():
		return {}
	var result := {
		"content_version":String(content.content_version),
		"clock":clock.snapshot(),
		"inventory":inventory.projection(),
		"wallet":wallet.projection(),
		"storage":storage.projection(),
		"farm":farm.projection(),
		"command_journal":journal.snapshot()
	}
	if forage.has_spots():
		result["forage"] = {
			"revision":forage.revision,
			"spots":forage.spots.duplicate(true)
		}
	if resident_runtime.has_states():
		result["residents"] = resident_runtime.snapshot()
		result["fact_events"] = fact_events.snapshot()
	return result

func restore(snapshot_value: Variant) -> bool:
	if not is_configured() or not (snapshot_value is Dictionary):
		return false
	var base_required := ["content_version","clock","inventory","wallet","farm"]
	var has_journal: bool = snapshot_value.has("command_journal")
	var has_storage: bool = snapshot_value.has("storage")
	var has_forage: bool = snapshot_value.has("forage")
	var has_residents: bool = snapshot_value.has("residents")
	var has_fact_events: bool = snapshot_value.has("fact_events")
	var expected_size := base_required.size() + (1 if has_journal else 0) + (1 if has_storage else 0) + (1 if has_forage else 0) + (1 if has_residents else 0) + (1 if has_fact_events else 0)
	if snapshot_value.size() != expected_size:
		return false
	for key: String in base_required:
		if not snapshot_value.has(key):
			return false
	if snapshot_value.content_version != content.content_version:
		return false
	var next_clock: RefCounted = CLOCK.new(content)
	var next_inventory: RefCounted = INVENTORY.new(content)
	var next_wallet: RefCounted = WALLET.new(content)
	var next_farm: RefCounted = FARM.new(_plot_definitions,content)
	var next_storage: RefCounted = STORAGE.new(content)
	var next_forage: RefCounted = FORAGE.new(_forage_definitions,content)
	var next_journal: RefCounted = JOURNAL.new()
	var next_fact_events: RefCounted = FACT_EVENTS.new()
	var next_resident_schedule: RefCounted = RESIDENT_SCHEDULE.new(_resident_anchor_definitions,content)
	var next_resident_runtime: RefCounted = RESIDENT_RUNTIME.new(_resident_anchor_definitions,content)
	var next_resident_conversations: RefCounted = RESIDENT_CONVERSATIONS.new(content)
	var next_resident_knowledge: RefCounted = RESIDENT_KNOWLEDGE.new(next_resident_runtime,next_fact_events)
	if not next_fact_events.is_configured() or not next_clock.is_configured() or not next_inventory.is_configured() or not next_wallet.is_configured() or not next_farm.is_configured() or not next_storage.is_configured() or not next_forage.is_configured() or not next_resident_schedule.is_configured() or not next_resident_runtime.is_configured() or not next_resident_conversations.is_configured() or not next_resident_knowledge.is_configured():
		return false
	if not next_clock.restore(snapshot_value.clock):
		return false
	if not next_inventory.restore(snapshot_value.inventory):
		return false
	if not next_wallet.restore(snapshot_value.wallet):
		return false
	if not next_farm.restore(snapshot_value.farm):
		return false
	if has_storage and not next_storage.restore(snapshot_value.storage):
		return false
	if has_forage and not next_forage.restore(snapshot_value.forage,next_clock.current_day()):
		return false
	if has_residents and not next_resident_runtime.restore(snapshot_value.residents):
		return false
	if has_fact_events and not next_fact_events.restore(snapshot_value.fact_events):
		return false
	if has_residents:
		for resident: Variant in next_resident_runtime.projection().residents:
			if not next_fact_events.known_ids_exist(resident.known_event_ids):
				return false
	if has_journal and not next_journal.restore(snapshot_value.command_journal):
		return false
	var next_farming: RefCounted = FARMING.new(next_inventory,next_farm,content)
	var next_storage_transfer: RefCounted = STORAGE_TRANSFER.new(next_inventory,next_storage)
	var next_economy: RefCounted = ECONOMY.new(next_inventory,next_wallet,next_clock,content)
	var next_foraging: RefCounted = FORAGING.new(next_inventory,next_forage,next_clock)
	if not next_farming.is_configured() or not next_storage_transfer.is_configured() or not next_economy.is_configured() or not next_foraging.is_configured():
		return false
	clock = next_clock
	inventory = next_inventory
	wallet = next_wallet
	farm = next_farm
	farming = next_farming
	storage = next_storage
	storage_transfer = next_storage_transfer
	economy = next_economy
	forage = next_forage
	foraging = next_foraging
	resident_schedule = next_resident_schedule
	resident_runtime = next_resident_runtime
	resident_conversations = next_resident_conversations
	resident_knowledge = next_resident_knowledge
	fact_events = next_fact_events
	journal = next_journal
	return true

func update_resident_runtime(value: Variant) -> bool:
	return resident_runtime != null and resident_runtime.update_runtime(value)

func player_resident_dialogue_context(resident_id: String) -> Dictionary:
	if not is_configured() or not content.has("dialogues") or not content.dialogues.player_resident.has(resident_id):
		return {"ok":false,"error_code":"DIALOGUE_RESIDENT_UNAVAILABLE"}
	var definition: Dictionary = content.dialogues.player_resident[resident_id]
	var runtime_row: Dictionary = {}
	for row: Variant in resident_runtime.projection().residents:
		if row is Dictionary and String(row.get("resident_id",""))==resident_id:
			runtime_row=row
			break
	if runtime_row.is_empty() or String(runtime_row.space_id)!=String(definition.space_id):
		return {"ok":false,"error_code":"DIALOGUE_RESIDENT_NOT_HERE"}
	var first: Dictionary = definition.first_meeting
	var first_event_id := String(first.event_id)
	var knows_first: bool = bool(resident_runtime.knows_event(resident_id,first_event_id))
	var fact_exists: bool = bool(fact_events.has_event(first_event_id))
	if fact_exists and not knows_first:
		return {"ok":false,"error_code":"DIALOGUE_KNOWLEDGE_INCONSISTENT"}
	var chosen: Dictionary = definition.repeat if knows_first else first
	return {
		"ok":true,
		"error_code":"",
		"resident_id":resident_id,
		"display_name":String(content.residents.definitions[resident_id].display_name),
		"space_id":String(definition.space_id),
		"dialogue_id":String(chosen.dialogue_id),
		"text":String(chosen.text),
		"is_first_meeting":not knows_first,
		"event_id":first_event_id if not knows_first else "",
		"event_kind":String(first.event_kind) if not knows_first else ""
	}

func complete_player_resident_dialogue(resident_id: String, dialogue_id: String) -> Dictionary:
	var context: Dictionary = player_resident_dialogue_context(resident_id)
	if not context.ok:
		return {"ok":false,"error_code":String(context.error_code),"has_changes":false,"event_ids":[]}
	if String(context.dialogue_id)!=dialogue_id:
		return {"ok":false,"error_code":"DIALOGUE_CONTEXT_STALE","has_changes":false,"event_ids":[]}
	if not bool(context.is_first_meeting):
		return _settle_daily_greeting(resident_id,context)
	var before_facts: Dictionary = fact_events.snapshot()
	var before_runtime: Dictionary = resident_runtime.snapshot()
	var fact := {
		"event_id":String(context.event_id),
		"source_command_id":null,
		"source_system":"dialogue.authored",
		"kind":String(context.event_kind),
		"space_id":String(context.space_id),
		"game_minute":int(clock.game_minute),
		"participant_ids":["actor.player",resident_id],
		"payload":{"dialogue_id":dialogue_id}
	}
	var appended: Dictionary = fact_events.append(fact)
	if not appended.ok:
		return {"ok":false,"error_code":String(appended.error_code),"has_changes":false,"event_ids":[]}
	var learned: Dictionary = resident_knowledge.learn_event(resident_id,String(context.event_id),"experienced")
	if not learned.ok:
		fact_events.restore(before_facts)
		resident_runtime.restore(before_runtime)
		return {"ok":false,"error_code":String(learned.error_code),"has_changes":false,"event_ids":[]}
	return {
		"ok":true,
		"error_code":"",
		"has_changes":bool(appended.has_changes) or bool(learned.has_changes),
		"event_ids":[String(context.event_id)]
	}

func _settle_daily_greeting(resident_id: String, context: Dictionary) -> Dictionary:
	var day: int = int(clock.current_day())
	var limit: int = int(content.residents.daily_greeting_limit)
	var settled_count: int = _daily_resident_fact_count("resident.greeting",resident_id,day)
	if settled_count >= limit:
		return {"ok":true,"error_code":"","has_changes":false,"event_ids":[]}
	var relationship_delta: int = int(content.residents.greeting_relationship_points)
	var event_id := "event.%s.greeting.day.%d.%d" % [resident_id,day,settled_count+1]
	var before_facts: Dictionary = fact_events.snapshot()
	var before_runtime: Dictionary = resident_runtime.snapshot()
	var fact := {
		"event_id":event_id,
		"source_command_id":null,
		"source_system":"dialogue.authored",
		"kind":"resident.greeting",
		"space_id":String(context.space_id),
		"game_minute":int(clock.game_minute),
		"participant_ids":["actor.player",resident_id],
		"payload":{
			"dialogue_id":String(context.dialogue_id),
			"relationship_delta":relationship_delta
		}
	}
	var appended: Dictionary = fact_events.append(fact)
	if not appended.ok:
		return {"ok":false,"error_code":String(appended.error_code),"has_changes":false,"event_ids":[]}
	var relationship: Dictionary = resident_runtime.adjust_relationship(resident_id,relationship_delta)
	if not relationship.ok:
		fact_events.restore(before_facts)
		resident_runtime.restore(before_runtime)
		return {"ok":false,"error_code":String(relationship.error_code),"has_changes":false,"event_ids":[]}
	var learned: Dictionary = resident_knowledge.learn_event(resident_id,event_id,"experienced")
	if not learned.ok:
		fact_events.restore(before_facts)
		resident_runtime.restore(before_runtime)
		return {"ok":false,"error_code":String(learned.error_code),"has_changes":false,"event_ids":[]}
	return {
		"ok":true,
		"error_code":"",
		"has_changes":true,
		"event_ids":[event_id]
	}

func resident_gift_offer(resident_id: String) -> Dictionary:
	var offer := {"can_gift":false,"reason":"","item_id":"","item_name":"","quantity":0,"relationship_points":0}
	if not is_configured() or not content.residents.definitions.has(resident_id):
		offer.reason = "RESIDENT_GIFT_RESIDENT_INVALID"
		return offer
	var conversation: Dictionary = resident_conversations.conversation_for_actor("actor.player")
	if conversation.is_empty() or String(conversation.get("state",""))!="participating" or resident_id not in conversation.get("participants",[]):
		offer.reason = "RESIDENT_GIFT_CONVERSATION_REQUIRED"
		return offer
	var dialogue: Dictionary = player_resident_dialogue_context(resident_id)
	if not dialogue.get("ok",false) or bool(dialogue.is_first_meeting):
		offer.reason = "RESIDENT_GIFT_FIRST_MEETING_REQUIRED"
		return offer
	if String(conversation.space_id)!=String(dialogue.space_id):
		offer.reason = "RESIDENT_GIFT_SPACE_INVALID"
		return offer
	if _daily_resident_fact_count("resident.gift",resident_id,int(clock.current_day()))>=int(content.residents.daily_gift_limit):
		offer.reason = "RESIDENT_GIFT_DAILY_LIMIT"
		return offer
	var selected_index: int = int(inventory.selected_slot_index)
	var slot: Variant = inventory.slots[selected_index]
	if slot==null:
		offer.reason = "RESIDENT_GIFT_SELECTED_EMPTY"
		return offer
	var item_id := String(slot.item_id)
	offer.item_id=item_id
	offer.item_name=String(content.items[item_id].display_name)
	offer.quantity=int(slot.quantity)
	if item_id not in content.residents.gift_item_ids:
		offer.reason = "RESIDENT_GIFT_ITEM_NOT_ALLOWED"
		return offer
	offer.can_gift=true
	offer.relationship_points=int(content.residents.gift_relationship_points)
	return offer

func _handle_resident_gift(command: Dictionary) -> Dictionary:
	var command_id := String(command.get("command_id",""))
	if String(command.get("actor_id",""))!="actor.player":
		return _gift_result(command_id,false,"RESIDENT_GIFT_ACTOR_INVALID",false)
	if command.get("expected_revision")!=inventory.revision:
		return _gift_result(command_id,false,"STALE_REVISION",true)
	var payload: Variant = command.get("payload")
	if not (payload is Dictionary) or payload.size()!=3 or not payload.has("resident_id") or not payload.has("item_id") or not payload.has("quantity"):
		return _gift_result(command_id,false,"RESIDENT_GIFT_PAYLOAD_INVALID",false)
	if not (payload.resident_id is String) or not (payload.item_id is String) or not (payload.quantity is int) or int(payload.quantity)!=1:
		return _gift_result(command_id,false,"RESIDENT_GIFT_PAYLOAD_INVALID",false)
	var resident_id := String(payload.resident_id)
	var item_id := String(payload.item_id)
	var offer: Dictionary = resident_gift_offer(resident_id)
	if not bool(offer.can_gift):
		return _gift_result(command_id,false,String(offer.reason),false)
	if String(offer.item_id)!=item_id:
		return _gift_result(command_id,false,"RESIDENT_GIFT_SELECTED_MISMATCH",false)
	var candidate: Dictionary = inventory.candidate_after_remove(item_id,1)
	if not candidate.ok:
		return _gift_result(command_id,false,String(candidate.error_code),false)

	var before_inventory: Dictionary = inventory.projection()
	var before_runtime: Dictionary = resident_runtime.snapshot()
	var before_events: Dictionary = fact_events.snapshot()
	var day: int = int(clock.current_day())
	var sequence: int = _daily_resident_fact_count("resident.gift",resident_id,day)+1
	var event_id := "event.%s.gift.day.%d.%d" % [resident_id,day,sequence]
	var fact := {
		"event_id":event_id,
		"source_command_id":command_id,
		"source_system":null,
		"kind":"resident.gift",
		"space_id":String(resident_conversations.conversation_for_actor("actor.player").space_id),
		"game_minute":int(clock.game_minute),
		"participant_ids":["actor.player",resident_id],
		"payload":{"item_id":item_id,"quantity":1,"relationship_delta":int(offer.relationship_points)}
	}
	if not inventory.commit_slots(candidate.slots,int(command.expected_revision)):
		return _gift_result(command_id,false,"STALE_REVISION",true)
	var relationship: Dictionary = resident_runtime.adjust_relationship(resident_id,int(offer.relationship_points))
	if not relationship.ok:
		_rollback_resident_gift(before_inventory,before_runtime,before_events)
		return _gift_result(command_id,false,String(relationship.error_code),false)
	var appended: Dictionary = fact_events.append(fact)
	if not appended.ok:
		_rollback_resident_gift(before_inventory,before_runtime,before_events)
		return _gift_result(command_id,false,String(appended.error_code),false)
	var learned: Dictionary = resident_knowledge.learn_event(resident_id,event_id,"experienced")
	if not learned.ok:
		_rollback_resident_gift(before_inventory,before_runtime,before_events)
		return _gift_result(command_id,false,String(learned.error_code),false)
	return _gift_result(command_id,true,"",false,[event_id])

func _rollback_resident_gift(inventory_before: Dictionary, runtime_before: Dictionary, events_before: Dictionary) -> void:
	inventory.restore(inventory_before)
	resident_runtime.restore(runtime_before)
	fact_events.restore(events_before)

func _gift_result(command_id: String, ok: bool, error_code: String, retryable: bool, event_ids: Array = []) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":command_id,
		"ok":ok,
		"error_code":error_code,
		"is_retryable":retryable,
		"has_changes":ok,
		"revision":int(inventory.revision),
		"event_ids":event_ids
	}

func _daily_resident_fact_count(kind: String, resident_id: String, day: int) -> int:
	if day<=0:
		return 0
	var start_minute: int = (day-1)*int(clock.minutes_per_day)
	var end_minute: int = day*int(clock.minutes_per_day)
	var count := 0
	var facts: Dictionary = fact_events.projection()
	for fact: Variant in facts.events:
		if not (fact is Dictionary):
			continue
		var minute := int(fact.get("game_minute",-1))
		if minute < start_minute or minute >= end_minute:
			continue
		if String(fact.get("kind",""))==kind and resident_id in fact.get("participant_ids",[]):
			count += 1
	return count

func invite_resident_conversation(conversation_id: String, inviter_id: String, invitee_id: String, space_id: String) -> Dictionary:
	return resident_conversations.invite(conversation_id,inviter_id,invitee_id,space_id)

func approach_resident_conversation(conversation_id: String) -> Dictionary:
	return resident_conversations.mark_approaching(conversation_id)

func begin_resident_conversation(conversation_id: String) -> Dictionary:
	return resident_conversations.begin_participation(conversation_id)

func end_resident_conversation(conversation_id: String) -> Dictionary:
	return resident_conversations.end(conversation_id)

func cancel_resident_conversation(conversation_id: String) -> Dictionary:
	return resident_conversations.cancel(conversation_id)

func release_resident_conversations_for_space(space_id: String) -> Array:
	return resident_conversations.release_space(space_id)

func clear_resident_conversations() -> int:
	return resident_conversations.clear_all()

func append_fact_event(fact: Variant) -> Dictionary:
	return fact_events.append(fact)

func fact_event(event_id: String) -> Dictionary:
	return fact_events.get_event(event_id)

func resident_learn_event(resident_id: String, event_id: String, acquisition: String) -> Dictionary:
	return resident_knowledge.learn_event(resident_id,event_id,acquisition)

func resident_learn_from_command_result(resident_id: String, result: Variant, acquisition: String) -> Dictionary:
	return resident_knowledge.learn_from_command_result(resident_id,result,acquisition)

func resident_tell_event(teller_id: String, receiver_id: String, event_id: String) -> Dictionary:
	return resident_knowledge.tell_event(teller_id,receiver_id,event_id)

func resident_record_summary(resident_id: String, summary_id: String, summary_text: String, source_event_ids: Array, updated_at_game_minute: int) -> Dictionary:
	return resident_knowledge.record_summary(resident_id,summary_id,summary_text,source_event_ids,updated_at_game_minute)

func clear_receipts() -> void:
	if journal != null:
		journal.clear()

func _failure(command_id: String, code: String) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":command_id,
		"ok":false,
		"error_code":code,
		"is_retryable":false,
		"has_changes":false,
		"revision":0,
		"event_ids":[]
	}
