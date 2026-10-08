extends RefCounted
## Authoritative home chest container. UI receives projection() copies only.
## Transfer orchestration lives outside this domain so both source/target can be
## validated before either side commits.

const CONTENT = preload("res://content/content_catalog.gd")

var container_id := "container.home_chest"
var revision: int = 0
var capacity: int = 0
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
	capacity = int(source.storage.chest_capacity)
	_items = source.items.duplicate(true)
	slots.resize(capacity)
	slots.fill(null)

func is_configured() -> bool:
	return configuration_error.is_empty() and capacity > 0 and slots.size() == capacity

func projection() -> Dictionary:
	return {
		"revision":revision,
		"container_id":container_id,
		"capacity":capacity,
		"slots":slots.duplicate(true)
	}

func _valid_item(item_id: Variant) -> bool:
	return item_id is String and _items.has(item_id)

func _valid_quantity(quantity: Variant) -> bool:
	return quantity is int and quantity > 0

func _stack_limit(item_id: String) -> int:
	return int(_items[item_id].stack_limit)

func candidate_after_add(item_id: Variant, quantity: Variant) -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":"STORAGE_NOT_CONFIGURED"}
	if not _valid_item(item_id) or not _valid_quantity(quantity):
		return {"ok":false,"error_code":"STORAGE_ITEM_INVALID"}
	var candidate: Array = slots.duplicate(true)
	var remaining := int(quantity)
	var limit := _stack_limit(String(item_id))
	for index in range(candidate.size()):
		var slot: Variant = candidate[index]
		if slot != null and slot.item_id == item_id and slot.quantity < limit:
			var moved := mini(limit-int(slot.quantity),remaining)
			var next: Dictionary = slot.duplicate(true)
			next.quantity += moved
			candidate[index] = next
			remaining -= moved
			if remaining == 0:
				return {"ok":true,"error_code":"","slots":candidate}
	for index in range(candidate.size()):
		if candidate[index] == null:
			var moved := mini(limit,remaining)
			candidate[index] = {"item_id":String(item_id),"quantity":moved}
			remaining -= moved
			if remaining == 0:
				return {"ok":true,"error_code":"","slots":candidate}
	return {"ok":false,"error_code":"STORAGE_FULL"}

func candidate_after_remove(item_id: Variant, quantity: Variant) -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":"STORAGE_NOT_CONFIGURED"}
	if not _valid_item(item_id) or not _valid_quantity(quantity):
		return {"ok":false,"error_code":"STORAGE_ITEM_INVALID"}
	if quantity_of(String(item_id)) < int(quantity):
		return {"ok":false,"error_code":"STORAGE_INSUFFICIENT_ITEM"}
	var candidate: Array = slots.duplicate(true)
	var remaining := int(quantity)
	for index in range(candidate.size()-1,-1,-1):
		var slot: Variant = candidate[index]
		if slot == null or slot.item_id != item_id:
			continue
		var moved := mini(int(slot.quantity),remaining)
		var next_quantity := int(slot.quantity)-moved
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
		if int(slot.quantity) > _stack_limit(String(slot.item_id)):
			return false
	return true

func commit_slots(candidate: Array, expected_revision: int) -> bool:
	if expected_revision != revision or not _valid_slots(candidate):
		return false
	slots = candidate.duplicate(true)
	revision += 1
	return true

func restore(snapshot_value: Variant) -> bool:
	if not is_configured() or not (snapshot_value is Dictionary):
		return false
	var required := ["revision","container_id","capacity","slots"]
	if snapshot_value.size() != required.size():
		return false
	for key: String in required:
		if not snapshot_value.has(key):
			return false
	if snapshot_value.container_id != container_id or snapshot_value.capacity != capacity:
		return false
	if not (snapshot_value.revision is int) or snapshot_value.revision < 0:
		return false
	if not (snapshot_value.slots is Array) or not _valid_slots(snapshot_value.slots):
		return false
	revision = int(snapshot_value.revision)
	slots = snapshot_value.slots.duplicate(true)
	return true

func quantity_of(item_id: String) -> int:
	var total := 0
	for slot: Variant in slots:
		if slot != null and slot.item_id == item_id:
			total += int(slot.quantity)
	return total
