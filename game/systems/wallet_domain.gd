extends RefCounted
## Integer-only player wallet. UI receives projection() and never writes money.

const CONTENT = preload("res://content/content_catalog.gd")

var owner_id := "actor.player"
var revision: int = 0
var money: int = 0
var configuration_error := ""

func _init(content: Dictionary = {}) -> void:
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
	money = source.economy.initial_money

func is_configured() -> bool:
	return configuration_error.is_empty() and money >= 0

func projection() -> Dictionary:
	return {"revision":revision,"owner_id":owner_id,"money":money}

func restore(snapshot_value: Variant) -> bool:
	if not is_configured() or not (snapshot_value is Dictionary):
		return false
	var required := ["revision","owner_id","money"]
	if snapshot_value.size() != required.size():
		return false
	for key: String in required:
		if not snapshot_value.has(key):
			return false
	if snapshot_value.owner_id != owner_id:
		return false
	if not (snapshot_value.revision is int) or snapshot_value.revision < 0:
		return false
	if not (snapshot_value.money is int) or snapshot_value.money < 0:
		return false
	revision = snapshot_value.revision
	money = snapshot_value.money
	return true

func candidate_after_delta(delta: int) -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":"WALLET_NOT_CONFIGURED"}
	var candidate := money + delta
	if candidate < 0:
		return {"ok":false,"error_code":"WALLET_INSUFFICIENT_FUNDS"}
	return {"ok":true,"error_code":"","money":candidate}

func commit_money(candidate: int, expected_revision: int) -> bool:
	if expected_revision != revision or candidate < 0:
		return false
	money = candidate
	revision += 1
	return true

func credit(amount: int) -> Dictionary:
	if amount <= 0:
		return {"ok":false,"error_code":"WALLET_AMOUNT_INVALID","revision":revision}
	var candidate := candidate_after_delta(amount)
	if not candidate.ok:
		return {"ok":false,"error_code":candidate.error_code,"revision":revision}
	if not commit_money(candidate.money, revision):
		return {"ok":false,"error_code":"WALLET_REVISION_CONFLICT","revision":revision}
	return {"ok":true,"error_code":"","revision":revision}

func debit(amount: int) -> Dictionary:
	if amount <= 0:
		return {"ok":false,"error_code":"WALLET_AMOUNT_INVALID","revision":revision}
	var candidate := candidate_after_delta(-amount)
	if not candidate.ok:
		return {"ok":false,"error_code":candidate.error_code,"revision":revision}
	if not commit_money(candidate.money, revision):
		return {"ok":false,"error_code":"WALLET_REVISION_CONFLICT","revision":revision}
	return {"ok":true,"error_code":"","revision":revision}
