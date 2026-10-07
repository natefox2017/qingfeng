extends RefCounted
## Authoritative player inventory for the first playable slice.
## UI receives projection() copies and never mutates slots directly.

const CONTENT = preload("res://content/content_catalog.gd")

var container_id := "container.player"
var revision: int = 0
var capacity: int = 0
var selected_slot_index: int = 0
var slots: Array = []
var configuration_error := ""
var _items: Dictionary = {}

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
	capacity = source.inventory.capacity
	_items = source.items.duplicate(true)
	slots.resize(capacity)
	slots.fill(null)
	for entry: Dictionary in source.new_game.initial_items:
		var candidate := candidate_after_add(entry.item_id, entry.quantity)
		if not candidate.ok:
			configuration_error = candidate.error_code
			slots.clear()
			return
		slots = candidate.slots
	revision = 0

func is_configured() -> bool:
	return configuration_error.is_empty() and capacity > 0 and slots.size() == capacity

func projection() -> Dictionary:
	return {
		"revision": revision,
		"container_id": container_id,
		"capacity": capacity,
		"slots": slots.duplicate(true),
		"selected_slot_index": selected_slot_index
	}

func _valid_item(item_id: Variant) -> bool:
	return item_id is String and _items.has(item_id)

func _valid_quantity(quantity: Variant) -> bool:
	return quantity is int and quantity > 0

func _stack_limit(item_id: String) -> int:
	return int(_items[item_id].stack_limit)

func candidate_after_add(item_id: Variant, quantity: Variant) -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":"INVENTORY_NOT_CONFIGURED"}
	if not _valid_item(item_id) or not _valid_quantity(quantity):
		return {"ok":false,"error_code":"INVENTORY_ITEM_INVALID"}
	var candidate: Array = slots.duplicate(true)
	var remaining := int(quantity)
	var limit := _stack_limit(item_id)
	for index in range(candidate.size()):
		var slot: Variant = candidate[index]
		if slot != null and slot.item_id == item_id and slot.quantity < limit:
			var moved := mini(limit - int(slot.quantity), remaining)
			var next: Dictionary = slot.duplicate(true)
			next.quantity += moved
			candidate[index] = next
			remaining -= moved
			if remaining == 0:
				return {"ok":true,"error_code":"","slots":candidate}
	for index in range(candidate.size()):
		if candidate[index] == null:
			var moved := mini(limit, remaining)
			candidate[index] = {"item_id":String(item_id),"quantity":moved}
			remaining -= moved
			if remaining == 0:
				return {"ok":true,"error_code":"","slots":candidate}
	return {"ok":false,"error_code":"INVENTORY_FULL"}

func candidate_after_remove(item_id: Variant, quantity: Variant) -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":"INVENTORY_NOT_CONFIGURED"}
	if not _valid_item(item_id) or not _valid_quantity(quantity):
		return {"ok":false,"error_code":"INVENTORY_ITEM_INVALID"}
	var available := quantity_of(String(item_id))
	if available < int(quantity):
		return {"ok":false,"error_code":"INVENTORY_INSUFFICIENT_ITEM"}
	var candidate: Array = slots.duplicate(true)
	var remaining := int(quantity)
	for index in range(candidate.size() - 1, -1, -1):
		var slot: Variant = candidate[index]
		if slot == null or slot.item_id != item_id:
			continue
		var moved := mini(int(slot.quantity), remaining)
		var next_quantity := int(slot.quantity) - moved
		candidate[index] = null if next_quantity == 0 else {"item_id":String(item_id),"quantity":next_quantity}
		remaining -= moved
		if remaining == 0:
			break
	return {"ok":true,"error_code":"","slots":candidate}

func _valid_slots(candidate: Array) -> bool:
	if candidate.size() != capacity:
		return false
	for slot: Variant in candidate:
		if slot == null:
			continue
		if not (slot is Dictionary) or slot.size() != 2 or not slot.has("item_id") or not slot.has("quantity"):
			return false
		if not _valid_item(slot.item_id) or not _valid_quantity(slot.quantity):
			return false
		if slot.quantity > _stack_limit(slot.item_id):
			return false
	return true

func can_commit(candidate: Array, expected_revision: int) -> bool:
	return expected_revision == revision and _valid_slots(candidate)

func commit_slots(candidate: Array, expected_revision: int) -> bool:
	if not can_commit(candidate,expected_revision):
		return false
	slots = candidate.duplicate(true)
	revision += 1
	return true

func restore(snapshot_value: Variant) -> bool:
	if not is_configured() or not (snapshot_value is Dictionary):
		return false
	var required := ["revision","container_id","capacity","slots","selected_slot_index"]
	if snapshot_value.size() != required.size():
		return false
	for key: String in required:
		if not snapshot_value.has(key):
			return false
	if snapshot_value.container_id != container_id or snapshot_value.capacity != capacity:
		return false
	if not (snapshot_value.revision is int) or snapshot_value.revision < 0:
		return false
	if not (snapshot_value.selected_slot_index is int) or snapshot_value.selected_slot_index < 0 or snapshot_value.selected_slot_index >= capacity:
		return false
	if not (snapshot_value.slots is Array) or not _valid_slots(snapshot_value.slots):
		return false
	slots = snapshot_value.slots.duplicate(true)
	selected_slot_index = snapshot_value.selected_slot_index
	revision = snapshot_value.revision
	return true

func add(item_id: String, quantity: int) -> Dictionary:
	var candidate := candidate_after_add(item_id, quantity)
	if not candidate.ok:
		return {"ok":false,"error_code":candidate.error_code,"revision":revision}
	if not commit_slots(candidate.slots, revision):
		return {"ok":false,"error_code":"INVENTORY_REVISION_CONFLICT","revision":revision}
	return {"ok":true,"error_code":"","revision":revision}

func remove(item_id: String, quantity: int) -> Dictionary:
	var candidate := candidate_after_remove(item_id, quantity)
	if not candidate.ok:
		return {"ok":false,"error_code":candidate.error_code,"revision":revision}
	if not commit_slots(candidate.slots, revision):
		return {"ok":false,"error_code":"INVENTORY_REVISION_CONFLICT","revision":revision}
	return {"ok":true,"error_code":"","revision":revision}

func quantity_of(item_id: String) -> int:
	var total := 0
	for slot: Variant in slots:
		if slot != null and slot.item_id == item_id:
			total += int(slot.quantity)
	return total

func handle_select(command: Dictionary) -> Dictionary:
	var command_id := str(command.get("command_id",""))
	if command.get("action") != "inventory.select":
		return _command_result(command_id,false,"INVENTORY_ACTION_UNSUPPORTED",false,false)
	if command.get("expected_revision") != revision:
		return _command_result(command_id,false,"STALE_REVISION",true,false)
	var payload: Variant = command.get("payload")
	if not (payload is Dictionary) or payload.size() != 1 or not payload.has("slot_index"):
		return _command_result(command_id,false,"INVENTORY_PAYLOAD_INVALID",false,false)
	if not (payload.slot_index is int) or payload.slot_index < 0 or payload.slot_index >= capacity:
		return _command_result(command_id,false,"INVENTORY_SLOT_INVALID",false,false)
	if selected_slot_index == payload.slot_index:
		return _command_result(command_id,true,"",false,false)
	selected_slot_index = payload.slot_index
	revision += 1
	return _command_result(command_id,true,"",false,true)

func _command_result(command_id: String, ok: bool, error_code: String, retryable: bool, changes: bool) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":command_id,
		"ok":ok,
		"error_code":error_code,
		"is_retryable":retryable,
		"has_changes":changes,
		"revision":revision,
		"event_ids":[]
	}
