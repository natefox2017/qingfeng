extends RefCounted
## One named owner cannot release another owner's input lock.
signal changed
var _owners: Dictionary = {}

func set_locked(owner: StringName, enabled: bool) -> void:
	assert(not owner.is_empty(), "Input lock requires an owner")
	if _owners.has(owner) == enabled:
		return
	if enabled:
		_owners[owner] = true
	else:
		_owners.erase(owner)
	changed.emit()

func is_locked() -> bool:
	return not _owners.is_empty()

func has_owner(owner: StringName) -> bool:
	return _owners.has(owner)
