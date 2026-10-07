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

var configuration_error := ""
var content: Dictionary = {}
var journal: RefCounted
var clock: RefCounted
var inventory: RefCounted
var wallet: RefCounted
var farm: RefCounted
var farming: RefCounted

func _init(plot_definitions: Array = [], content_override: Dictionary = {}) -> void:
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
	journal = JOURNAL.new()
	clock = CLOCK.new(content)
	inventory = INVENTORY.new(content)
	wallet = WALLET.new(content)
	farm = FARM.new(plot_definitions,content)
	farming = FARMING.new(inventory,farm,content)
	if not clock.is_configured() or not inventory.is_configured() or not wallet.is_configured() or not farm.is_configured() or not farming.is_configured():
		configuration_error = "GAMEPLAY_SESSION_DOMAIN_INVALID"

func is_configured() -> bool:
	return configuration_error.is_empty() and journal != null

func execute(command: Dictionary) -> Dictionary:
	if not is_configured():
		return _failure(str(command.get("command_id","")),"GAMEPLAY_SESSION_NOT_CONFIGURED")
	var action := String(command.get("action",""))
	if action == "inventory.select":
		return journal.execute(command,inventory.handle_select)
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

func acquire_pause(owner: StringName) -> bool:
	return is_configured() and clock.acquire_pause(owner)

func release_pause(owner: StringName) -> bool:
	return is_configured() and clock.release_pause(owner)

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
		"wallet":wallet.projection(),
		"farm":farm.projection()
	}

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
