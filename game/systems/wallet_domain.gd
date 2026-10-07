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
