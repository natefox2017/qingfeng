extends RefCounted
## The single gameplay clock. Balance comes from the content-version table;
## real-time/UI systems may request pause tokens, but only this class mutates game_minute.

const CONTENT = preload("res://content/content_catalog.gd")

var minutes_per_day: int = 0
var day_start_minute: int = 0
var real_seconds_per_game_minute: float = 0.0
var game_minute: int = 0
var _real_seconds_remainder: float = 0.0
var configuration_error: String = ""
var _pause_owners: Dictionary = {}

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
	minutes_per_day = source.clock.minutes_per_day
	day_start_minute = source.clock.day_start_minute
	real_seconds_per_game_minute = float(source.clock.real_seconds_per_game_minute)
	game_minute = day_start_minute

func is_configured() -> bool:
	return configuration_error.is_empty() and minutes_per_day > 0 and real_seconds_per_game_minute > 0.0

func reset(value: Variant = null) -> bool:
	if not is_configured():
		return false
	var target: Variant = day_start_minute if value == null else value
	if not (target is int) or target < 0:
		return false
	game_minute = target
	_real_seconds_remainder = 0.0
	_pause_owners.clear()
	return true

func snapshot() -> Dictionary:
	return {"game_minute":game_minute}

func restore(snapshot_value: Variant) -> bool:
	if not is_configured() or not (snapshot_value is Dictionary):
		return false
	if snapshot_value.size() != 1 or not snapshot_value.has("game_minute"):
		return false
	if not (snapshot_value.game_minute is int) or snapshot_value.game_minute < 0:
		return false
	return reset(snapshot_value.game_minute)

func acquire_pause(owner: StringName) -> bool:
	if not is_configured() or owner == &"":
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
	if not is_configured():
		return 0
	return game_minute / minutes_per_day + 1

func minute_of_day() -> int:
	if not is_configured():
		return 0
	return game_minute % minutes_per_day

func advance_real_seconds(seconds: float) -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":"CLOCK_NOT_CONFIGURED","advanced_minutes":0,"crossed_days":[]}
	if not is_finite(seconds) or seconds < 0.0:
		return {"ok":false,"error_code":"CLOCK_REAL_TIME_INVALID","advanced_minutes":0,"crossed_days":[]}
	if is_paused() or seconds == 0.0:
		return {"ok":true,"error_code":"","advanced_minutes":0,"crossed_days":[]}
	_real_seconds_remainder += seconds
	var minutes: int = floori(_real_seconds_remainder / real_seconds_per_game_minute)
	if minutes <= 0:
		return {"ok":true,"error_code":"","advanced_minutes":0,"crossed_days":[]}
	_real_seconds_remainder -= float(minutes) * real_seconds_per_game_minute
	var result: Dictionary = advance(minutes)
	if not result.ok:
		return {"ok":false,"error_code":result.error_code,"advanced_minutes":0,"crossed_days":[]}
	return {"ok":true,"error_code":"","advanced_minutes":minutes,"crossed_days":result.crossed_days}

func advance(minutes: int) -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":"CLOCK_NOT_CONFIGURED","crossed_days":[]}
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
	if not is_configured():
		return {"ok":false,"error_code":"CLOCK_NOT_CONFIGURED","crossed_days":[]}
	if is_paused():
		return {"ok":false,"error_code":"CLOCK_PAUSED","crossed_days":[]}
	var target := (game_minute / minutes_per_day + 1) * minutes_per_day + day_start_minute
	var before_day := current_day()
	game_minute = target
	_real_seconds_remainder = 0.0
	var crossed: Array[int] = []
	for day in range(before_day + 1, current_day() + 1):
		crossed.append(day)
	return {"ok":true,"error_code":"","crossed_days":crossed}
