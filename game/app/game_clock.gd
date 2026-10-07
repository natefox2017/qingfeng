extends RefCounted
## The single gameplay clock. Real-time/UI systems may request pause tokens,
## but only this class mutates game_minute.

const MINUTES_PER_DAY := 1440
const DAY_START_MINUTE := 360

var game_minute: int = DAY_START_MINUTE
var _pause_owners: Dictionary = {}

func reset(value := DAY_START_MINUTE) -> bool:
	if not value is int or value < 0:
		return false
	game_minute = value
	_pause_owners.clear()
	return true

func acquire_pause(owner: StringName) -> bool:
	if owner == &"":
		return false
	_pause_owners[owner] = true
	return true

func release_pause(owner: StringName) -> bool:
	if not _pause_owners.has(owner):
		return false
	_pause_owners.erase(owner)
	return true

func is_paused() -> bool:
	return not _pause_owners.is_empty()

func pause_owner_count() -> int:
	return _pause_owners.size()

func current_day() -> int:
	return game_minute / MINUTES_PER_DAY + 1

func minute_of_day() -> int:
	return game_minute % MINUTES_PER_DAY

func advance(minutes: int) -> Dictionary:
	if minutes < 0:
		return {"ok":false,"error_code":"CLOCK_NEGATIVE_ADVANCE","crossed_days":[]}
	if is_paused():
		return {"ok":false,"error_code":"CLOCK_PAUSED","crossed_days":[]}
	var before_day := current_day()
	game_minute += minutes
	var crossed: Array[int] = []
	for day in range(before_day + 1, current_day() + 1):
		crossed.append(day)
	return {"ok":true,"error_code":"","crossed_days":crossed}

func rest_to_next_day_start() -> Dictionary:
	if is_paused():
		return {"ok":false,"error_code":"CLOCK_PAUSED","crossed_days":[]}
	var target := (game_minute / MINUTES_PER_DAY + 1) * MINUTES_PER_DAY + DAY_START_MINUTE
	var before_day := current_day()
	game_minute = target
	var crossed: Array[int] = []
	for day in range(before_day + 1, current_day() + 1):
		crossed.append(day)
	return {"ok":true,"error_code":"","crossed_days":crossed}
