extends RefCounted
## Single in-memory gameplay session. It composes domain owners and provides the
## only command/projection surface that app/UI should consume.

const CONTENT = preload("res://content/content_catalog.gd")
const JOURNAL = preload("res://app/command_journal.gd")
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

var configuration_error := ""
var content: Dictionary = {}
var journal: RefCounted
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
var _plot_definitions: Array = []
var _forage_definitions: Array = []

func _init(plot_definitions: Array = [], content_override: Dictionary = {}, forage_definitions: Array = []) -> void:
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
	journal = JOURNAL.new()
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
	if not clock.is_configured() or not inventory.is_configured() or not wallet.is_configured() or not farm.is_configured() or not farming.is_configured() or not storage.is_configured() or not storage_transfer.is_configured() or not economy.is_configured() or not forage.is_configured() or not foraging.is_configured():
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
	return result

func restore(snapshot_value: Variant) -> bool:
	if not is_configured() or not (snapshot_value is Dictionary):
		return false
	var base_required := ["content_version","clock","inventory","wallet","farm"]
	var has_journal: bool = snapshot_value.has("command_journal")
	var has_storage: bool = snapshot_value.has("storage")
	var has_forage: bool = snapshot_value.has("forage")
	var expected_size := base_required.size() + (1 if has_journal else 0) + (1 if has_storage else 0) + (1 if has_forage else 0)
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
	if not next_clock.is_configured() or not next_inventory.is_configured() or not next_wallet.is_configured() or not next_farm.is_configured() or not next_storage.is_configured() or not next_forage.is_configured():
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
	journal = next_journal
	return true

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
