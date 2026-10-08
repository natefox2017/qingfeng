extends RefCounted
## Atomic shop coordinator for player inventory + wallet.
## Prices and service hours come only from the current content version.
## All validation and both commits are synchronous; there is no await boundary.

const CONTENT = preload("res://content/content_catalog.gd")
const MAX_TRANSACTION_QUANTITY := 9999

var inventory: RefCounted
var wallet: RefCounted
var clock: RefCounted
var configuration_error := ""
var _content: Dictionary = {}

func _init(inventory_domain: RefCounted, wallet_domain: RefCounted, game_clock: RefCounted, content: Dictionary = {}) -> void:
	inventory = inventory_domain
	wallet = wallet_domain
	clock = game_clock
	var source := content
	if source.is_empty():
		var result: Dictionary = CONTENT.load_current()
		if not result.ok:
			configuration_error = result.error_code
			return
		source = result.data
	if not CONTENT.validate(source):
		configuration_error = "CONTENT_INVALID"
		return
	_content = source.duplicate(true)
	if inventory == null or wallet == null or clock == null or not inventory.is_configured() or not wallet.is_configured() or not clock.is_configured():
		configuration_error = "ECONOMY_DOMAIN_INVALID"

func is_configured() -> bool:
	return configuration_error.is_empty()

func projection() -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":configuration_error}
	return {
		"ok":true,
		"error_code":"",
		"open_minute":int(_content.shop.open_minute),
		"close_minute":int(_content.shop.close_minute),
		"is_open":is_shop_open()
	}

func is_shop_open() -> bool:
	if not is_configured():
		return false
	var minute: int = clock.minute_of_day()
	return minute >= int(_content.shop.open_minute) and minute < int(_content.shop.close_minute)

func handle(command: Dictionary) -> Dictionary:
	var command_id := str(command.get("command_id",""))
	if not is_configured():
		return _result(command_id,false,"ECONOMY_NOT_CONFIGURED",false,false)
	if command.get("actor_id") != "actor.player":
		return _result(command_id,false,"ECONOMY_ACTOR_INVALID",false,false)
	if command.get("expected_revision") != inventory.revision:
		return _result(command_id,false,"STALE_REVISION",true,false)
	var payload: Variant = command.get("payload")
	if not _valid_payload(payload):
		return _result(command_id,false,"ECONOMY_PAYLOAD_INVALID",false,false)
	if payload.wallet_revision != wallet.revision:
		return _result(command_id,false,"WALLET_STALE_REVISION",true,false)
	if not is_shop_open():
		return _result(command_id,false,"SHOP_CLOSED",true,false)
	match String(command.get("action","")):
		"economy.buy":
			return _buy(command_id,payload)
		"economy.sell":
			return _sell(command_id,payload)
		_:
			return _result(command_id,false,"ECONOMY_ACTION_UNSUPPORTED",false,false)

func _buy(command_id: String, payload: Dictionary) -> Dictionary:
	var item: Dictionary = _content.items.get(payload.item_id,{})
	if item.is_empty():
		return _result(command_id,false,"ECONOMY_ITEM_UNKNOWN",false,false)
	var unit_price := int(item.buy_price)
	if unit_price <= 0:
		return _result(command_id,false,"ECONOMY_ITEM_NOT_BUYABLE",false,false)
	var total_price := unit_price * int(payload.quantity)
	var wallet_candidate: Dictionary = wallet.candidate_after_delta(-total_price)
	if not wallet_candidate.ok:
		return _result(command_id,false,wallet_candidate.error_code,false,false)
	var inventory_candidate: Dictionary = inventory.candidate_after_add(payload.item_id,payload.quantity)
	if not inventory_candidate.ok:
		return _result(command_id,false,inventory_candidate.error_code,false,false)
	return _commit_both(command_id,inventory_candidate.slots,wallet_candidate.money)

func _sell(command_id: String, payload: Dictionary) -> Dictionary:
	var item: Dictionary = _content.items.get(payload.item_id,{})
	if item.is_empty():
		return _result(command_id,false,"ECONOMY_ITEM_UNKNOWN",false,false)
	var unit_price := int(item.sell_price)
	if unit_price <= 0:
		return _result(command_id,false,"ECONOMY_ITEM_NOT_SELLABLE",false,false)
	var inventory_candidate: Dictionary = inventory.candidate_after_remove(payload.item_id,payload.quantity)
	if not inventory_candidate.ok:
		return _result(command_id,false,inventory_candidate.error_code,false,false)
	var total_price := unit_price * int(payload.quantity)
	var wallet_candidate: Dictionary = wallet.candidate_after_delta(total_price)
	if not wallet_candidate.ok:
		return _result(command_id,false,wallet_candidate.error_code,false,false)
	return _commit_both(command_id,inventory_candidate.slots,wallet_candidate.money)

func _commit_both(command_id: String, next_slots: Array, next_money: int) -> Dictionary:
	var inventory_before: Dictionary = inventory.projection()
	var wallet_before: Dictionary = wallet.projection()
	var expected_inventory: int = inventory.revision
	var expected_wallet: int = wallet.revision
	if not inventory.commit_slots(next_slots,expected_inventory):
		return _result(command_id,false,"INVENTORY_REVISION_CONFLICT",true,false)
	if not wallet.commit_money(next_money,expected_wallet):
		inventory.restore(inventory_before)
		wallet.restore(wallet_before)
		return _result(command_id,false,"WALLET_REVISION_CONFLICT",true,false)
	return _result(command_id,true,"",false,true)

func _valid_payload(value: Variant) -> bool:
	if not (value is Dictionary) or value.size() != 3:
		return false
	for key: String in ["item_id","quantity","wallet_revision"]:
		if not value.has(key):
			return false
	return (
		value.item_id is String
		and not value.item_id.is_empty()
		and value.quantity is int
		and value.quantity > 0
		and value.quantity <= MAX_TRANSACTION_QUANTITY
		and value.wallet_revision is int
		and value.wallet_revision >= 0
	)

func _result(command_id: String, ok: bool, error_code: String, retryable: bool, changes: bool) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":command_id,
		"ok":ok,
		"error_code":error_code,
		"is_retryable":retryable,
		"has_changes":changes,
		"revision":inventory.revision if inventory != null else 0,
		"event_ids":[]
	}
