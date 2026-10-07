extends RefCounted
## Coordinates farm + inventory mutations in one synchronous validation/commit path.
## There is deliberately no await between validation and commits.

const CONTENT = preload("res://content/content_catalog.gd")

var inventory: RefCounted
var farm: RefCounted
var _content: Dictionary = {}
var configuration_error := ""

func _init(inventory_domain: RefCounted, farm_domain: RefCounted, content: Dictionary = {}) -> void:
	inventory = inventory_domain
	farm = farm_domain
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

func is_configured() -> bool:
	return configuration_error.is_empty() and inventory != null and farm != null and inventory.is_configured() and farm.is_configured()

func handle(command: Dictionary) -> Dictionary:
	var command_id := str(command.get("command_id",""))
	if not is_configured():
		return _result(command_id,false,"GAMEPLAY_NOT_CONFIGURED",false,false)
	if command.get("expected_revision") != farm.revision:
		return _result(command_id,false,"STALE_REVISION",true,false)
	var payload: Variant = command.get("payload")
	if not (payload is Dictionary):
		return _result(command_id,false,"FARM_PAYLOAD_INVALID",false,false)
	match String(command.get("action","")):
		"farm.till":
			return _till(command_id,payload)
		"farm.plant":
			return _plant(command_id,payload)
		"farm.water":
			return _water(command_id,payload)
		"farm.harvest":
			return _harvest(command_id,payload)
		_:
			return _result(command_id,false,"FARM_ACTION_UNSUPPORTED",false,false)

func _till(command_id: String, payload: Dictionary) -> Dictionary:
	if not _exact_payload(payload,["plot_id"]):
		return _result(command_id,false,"FARM_PAYLOAD_INVALID",false,false)
	if inventory.quantity_of("item.hoe") < 1:
		return _result(command_id,false,"FARM_TOOL_MISSING",false,false)
	var farm_candidate := farm.candidate_till(payload.plot_id)
	if not farm_candidate.ok:
		return _result(command_id,false,farm_candidate.error_code,false,false)
	var expected_farm: int = farm.revision
	if not farm.commit_plot(farm_candidate.plot,expected_farm):
		return _result(command_id,false,"FARM_REVISION_CONFLICT",true,false)
	return _result(command_id,true,"",false,true)

func _plant(command_id: String, payload: Dictionary) -> Dictionary:
	if not _exact_payload(payload,["plot_id","crop_id","inventory_revision"]):
		return _result(command_id,false,"FARM_PAYLOAD_INVALID",false,false)
	if not (payload.inventory_revision is int) or payload.inventory_revision != inventory.revision:
		return _result(command_id,false,"INVENTORY_STALE_REVISION",true,false)
	var farm_candidate := farm.candidate_plant(payload.plot_id,payload.crop_id)
	if not farm_candidate.ok:
		return _result(command_id,false,farm_candidate.error_code,false,false)
	var crop: Dictionary = _content.crops.get(payload.crop_id,{})
	if crop.is_empty():
		return _result(command_id,false,"FARM_CROP_UNKNOWN",false,false)
	var inventory_candidate := inventory.candidate_after_remove(String(crop.seed_item_id),1)
	if not inventory_candidate.ok:
		return _result(command_id,false,inventory_candidate.error_code,false,false)
	var expected_inventory: int = inventory.revision
	var expected_farm: int = farm.revision
	if not inventory.commit_slots(inventory_candidate.slots,expected_inventory):
		return _result(command_id,false,"INVENTORY_REVISION_CONFLICT",true,false)
	if not farm.commit_plot(farm_candidate.plot,expected_farm):
		return _result(command_id,false,"FARM_REVISION_CONFLICT",true,false)
	return _result(command_id,true,"",false,true)

func _water(command_id: String, payload: Dictionary) -> Dictionary:
	if not _exact_payload(payload,["plot_id"]):
		return _result(command_id,false,"FARM_PAYLOAD_INVALID",false,false)
	if inventory.quantity_of("item.watering_can") < 1:
		return _result(command_id,false,"FARM_TOOL_MISSING",false,false)
	var farm_candidate := farm.candidate_water(payload.plot_id)
	if not farm_candidate.ok:
		return _result(command_id,false,farm_candidate.error_code,false,false)
	if not farm_candidate.get("has_changes",true):
		return _result(command_id,true,"",false,false)
	var expected_farm: int = farm.revision
	if not farm.commit_plot(farm_candidate.plot,expected_farm):
		return _result(command_id,false,"FARM_REVISION_CONFLICT",true,false)
	return _result(command_id,true,"",false,true)

func _harvest(command_id: String, payload: Dictionary) -> Dictionary:
	if not _exact_payload(payload,["plot_id","inventory_revision"]):
		return _result(command_id,false,"FARM_PAYLOAD_INVALID",false,false)
	if not (payload.inventory_revision is int) or payload.inventory_revision != inventory.revision:
		return _result(command_id,false,"INVENTORY_STALE_REVISION",true,false)
	var farm_candidate := farm.candidate_harvest(payload.plot_id)
	if not farm_candidate.ok:
		return _result(command_id,false,farm_candidate.error_code,false,false)
	var inventory_candidate := inventory.candidate_after_add(farm_candidate.harvest_item_id,farm_candidate.yield_quantity)
	if not inventory_candidate.ok:
		return _result(command_id,false,inventory_candidate.error_code,false,false)
	var expected_inventory: int = inventory.revision
	var expected_farm: int = farm.revision
	if not inventory.commit_slots(inventory_candidate.slots,expected_inventory):
		return _result(command_id,false,"INVENTORY_REVISION_CONFLICT",true,false)
	if not farm.commit_plot(farm_candidate.plot,expected_farm):
		return _result(command_id,false,"FARM_REVISION_CONFLICT",true,false)
	return _result(command_id,true,"",false,true)

func _exact_payload(payload: Dictionary, required: Array[String]) -> bool:
	if payload.size() != required.size():
		return false
	for key: String in required:
		if not payload.has(key):
			return false
	return true

func _result(command_id: String, ok: bool, error_code: String, retryable: bool, changes: bool) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":command_id,
		"ok":ok,
		"error_code":error_code,
		"is_retryable":retryable,
		"has_changes":changes,
		"revision":farm.revision if farm != null else 0,
		"event_ids":[]
	}
