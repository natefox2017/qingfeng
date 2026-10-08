extends RefCounted
## Atomic forage pickup over the authoritative ForageDomain + player Inventory.

var inventory: RefCounted
var forage: RefCounted
var clock: RefCounted
var configuration_error := ""

func _init(inventory_domain: RefCounted, forage_domain: RefCounted, game_clock: RefCounted) -> void:
	inventory=inventory_domain
	forage=forage_domain
	clock=game_clock
	if inventory==null or forage==null or clock==null or not inventory.is_configured() or not forage.is_configured() or not clock.is_configured():
		configuration_error="FORAGE_COORDINATOR_INVALID"

func is_configured() -> bool:
	return configuration_error.is_empty()

func handle(command: Dictionary) -> Dictionary:
	var command_id := str(command.get("command_id",""))
	if not is_configured():
		return _result(command_id,false,"FORAGE_NOT_CONFIGURED",false,false)
	if command.get("action")!="forage.collect":
		return _result(command_id,false,"FORAGE_ACTION_UNSUPPORTED",false,false)
	if command.get("actor_id")!="actor.player":
		return _result(command_id,false,"FORAGE_ACTOR_INVALID",false,false)
	if command.get("expected_revision")!=forage.revision:
		return _result(command_id,false,"FORAGE_STALE_REVISION",true,false)
	var payload: Variant = command.get("payload")
	if not _valid_payload(payload):
		return _result(command_id,false,"FORAGE_PAYLOAD_INVALID",false,false)
	if payload.inventory_revision!=inventory.revision:
		return _result(command_id,false,"INVENTORY_STALE_REVISION",true,false)

	var forage_before: Dictionary = {"revision":forage.revision,"spots":forage.spots.duplicate(true)}
	var inventory_before: Dictionary = inventory.projection()
	var prepared: Dictionary = forage.candidate_collect(String(payload.spot_id),clock.current_day())
	if not prepared.ok:
		return _result(command_id,false,prepared.error_code,false,false)
	var inventory_candidate: Dictionary = inventory.candidate_after_add(prepared.item_id,prepared.quantity)
	if not inventory_candidate.ok:
		return _result(command_id,false,inventory_candidate.error_code,false,false)

	if not forage.commit_spots(prepared.spots,forage.revision,clock.current_day()):
		return _result(command_id,false,"FORAGE_COMMIT_FAILED",true,false)
	if not inventory.commit_slots(inventory_candidate.slots,int(inventory_before.revision)):
		forage.restore(forage_before,clock.current_day())
		return _result(command_id,false,"FORAGE_COMMIT_FAILED",true,false)
	return _result(command_id,true,"",false,true)

func _valid_payload(value: Variant) -> bool:
	return (
		value is Dictionary
		and value.size()==2
		and value.has("spot_id")
		and value.has("inventory_revision")
		and value.spot_id is String
		and not value.spot_id.is_empty()
		and value.inventory_revision is int
		and value.inventory_revision>=0
	)

func _result(command_id:String, ok:bool, error_code:String, retryable:bool, changes:bool) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":command_id,
		"ok":ok,
		"error_code":error_code,
		"is_retryable":retryable,
		"has_changes":changes,
		"revision":forage.revision if forage!=null else 0,
		"event_ids":[]
	}
