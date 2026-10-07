extends RefCounted
## Atomic player <-> home chest whole-stack/quantity transfer coordinator.
## It prepares both slot arrays before commit and rolls back defensively if the
## second commit ever fails despite the no-await validated critical section.

var inventory: RefCounted
var storage: RefCounted
var configuration_error := ""

func _init(inventory_domain: RefCounted, storage_domain: RefCounted) -> void:
	inventory = inventory_domain
	storage = storage_domain
	if inventory == null or storage == null or not inventory.is_configured() or not storage.is_configured():
		configuration_error = "STORAGE_TRANSFER_DOMAIN_INVALID"

func is_configured() -> bool:
	return configuration_error.is_empty()

func handle(command: Dictionary) -> Dictionary:
	var command_id := str(command.get("command_id",""))
	if not is_configured():
		return _result(command_id,false,"STORAGE_TRANSFER_NOT_CONFIGURED",false,false)
	if command.get("action") != "storage.transfer":
		return _result(command_id,false,"STORAGE_ACTION_UNSUPPORTED",false,false)
	var payload: Variant = command.get("payload")
	if not _valid_payload(payload):
		return _result(command_id,false,"STORAGE_PAYLOAD_INVALID",false,false)
	if command.get("expected_revision") != inventory.revision:
		return _result(command_id,false,"STALE_REVISION",true,false)
	if payload.storage_revision != storage.revision:
		return _result(command_id,false,"STORAGE_STALE_REVISION",true,false)

	var source: RefCounted
	var target: RefCounted
	if payload.source_container_id == inventory.container_id and payload.target_container_id == storage.container_id:
		source = inventory
		target = storage
	elif payload.source_container_id == storage.container_id and payload.target_container_id == inventory.container_id:
		source = storage
		target = inventory
	else:
		return _result(command_id,false,"STORAGE_CONTAINER_INVALID",false,false)

	var source_before: Dictionary = source.projection()
	var target_before: Dictionary = target.projection()
	var removed: Dictionary = source.candidate_after_remove(payload.item_id,payload.quantity)
	if not removed.ok:
		return _result(command_id,false,removed.error_code,false,false)
	var target_original_slots: Array = target.slots
	target.slots = target_before.slots.duplicate(true)
	var added: Dictionary = target.candidate_after_add(payload.item_id,payload.quantity)
	target.slots = target_original_slots
	if not added.ok:
		return _result(command_id,false,added.error_code,false,false)

	if not source.commit_slots(removed.slots,int(source_before.revision)):
		return _result(command_id,false,"STORAGE_COMMIT_FAILED",true,false)
	if not target.commit_slots(added.slots,int(target_before.revision)):
		source.restore(source_before)
		return _result(command_id,false,"STORAGE_COMMIT_FAILED",true,false)
	return _result(command_id,true,"",false,true)

func _valid_payload(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var required := ["source_container_id","target_container_id","item_id","quantity","storage_revision"]
	if value.size() != required.size():
		return false
	for key: String in required:
		if not value.has(key):
			return false
	return (
		value.source_container_id is String
		and value.target_container_id is String
		and value.item_id is String
		and not value.item_id.is_empty()
		and value.quantity is int
		and value.quantity > 0
		and value.storage_revision is int
		and value.storage_revision >= 0
	)

func _result(command_id: String, ok: bool, error_code: String, retryable: bool, changes: bool) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":command_id,
		"ok":ok,
		"error_code":error_code,
		"is_retryable":retryable,
		"has_changes":changes,
		"revision":inventory.revision,
		"event_ids":[]
	}
