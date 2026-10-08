extends RefCounted
## Strict loader for the first playable balance table.
## Gameplay/UI consume this projection instead of duplicating prices or capacities.

const CURRENT_PATH := "res://content/first_playable_v1.json"

static func failure(code: String) -> Dictionary:
	return {"ok": false, "error_code": code}

static func _exact_keys(value: Variant, required: Array[String]) -> bool:
	if not (value is Dictionary) or value.size() != required.size():
		return false
	for key: String in required:
		if not value.has(key):
			return false
	return true

static func _normalize_numbers(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floor(value):
		return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value:
			result[key] = _normalize_numbers(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(_normalize_numbers(item))
		return result
	return value

static func _positive_int(value: Variant) -> bool:
	return value is int and value > 0

static func _nonnegative_int(value: Variant) -> bool:
	return value is int and value >= 0

static func _positive_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0

static func validate(data: Variant) -> bool:
	if not _exact_keys(data, ["content_version","clock","inventory","storage","economy","shop","items","crops","forage","residents","dialogues","new_game"]):
		return false
	if data.content_version != "first_playable_v1":
		return false
	if not _exact_keys(data.clock, ["minutes_per_day","day_start_minute","real_seconds_per_game_minute"]):
		return false
	if not _positive_int(data.clock.minutes_per_day) or not _nonnegative_int(data.clock.day_start_minute) or not _positive_number(data.clock.real_seconds_per_game_minute):
		return false
	if data.clock.day_start_minute >= data.clock.minutes_per_day:
		return false
	if not _exact_keys(data.inventory, ["capacity"]) or not _positive_int(data.inventory.capacity):
		return false
	if not _exact_keys(data.storage, ["chest_capacity"]) or not _positive_int(data.storage.chest_capacity):
		return false
	if not _exact_keys(data.economy, ["initial_money"]) or not _nonnegative_int(data.economy.initial_money):
		return false
	if not _exact_keys(data.shop, ["open_minute","close_minute"]):
		return false
	if not _nonnegative_int(data.shop.open_minute) or not _positive_int(data.shop.close_minute):
		return false
	if data.shop.open_minute >= data.shop.close_minute or data.shop.close_minute > data.clock.minutes_per_day:
		return false
	if not (data.items is Dictionary) or data.items.is_empty():
		return false
	for item_id: Variant in data.items:
		if not (item_id is String) or not String(item_id).begins_with("item."):
			return false
		var item: Variant = data.items[item_id]
		if not _exact_keys(item, ["stack_limit","buy_price","sell_price","display_name"]):
			return false
		if not _positive_int(item.stack_limit) or not _nonnegative_int(item.buy_price) or not _nonnegative_int(item.sell_price):
			return false
		if not (item.display_name is String) or item.display_name.is_empty() or item.display_name.length() > 24:
			return false
	if not (data.crops is Dictionary) or data.crops.is_empty():
		return false
	for crop_id: Variant in data.crops:
		if not (crop_id is String) or not String(crop_id).begins_with("crop."):
			return false
		var crop: Variant = data.crops[crop_id]
		if not _exact_keys(crop, ["seed_item_id","harvest_item_id","growth_days","yield_quantity"]):
			return false
		if not crop.seed_item_id in data.items or not crop.harvest_item_id in data.items:
			return false
		if not _positive_int(crop.growth_days) or not _positive_int(crop.yield_quantity):
			return false
	if not _exact_keys(data.forage,["types"]) or not (data.forage.types is Dictionary) or data.forage.types.is_empty():
		return false
	for forage_id: Variant in data.forage.types:
		if not (forage_id is String) or not String(forage_id).begins_with("forage."):
			return false
		var forage: Variant = data.forage.types[forage_id]
		if not _exact_keys(forage,["item_id","quantity","respawn_days"]):
			return false
		if not forage.item_id in data.items or not _positive_int(forage.quantity) or not _positive_int(forage.respawn_days):
			return false
	if not _exact_keys(data.residents,["daily_greeting_limit","daily_gift_limit","definitions"]):
		return false
	if not _positive_int(data.residents.daily_greeting_limit) or not _positive_int(data.residents.daily_gift_limit):
		return false
	if not (data.residents.definitions is Dictionary) or data.residents.definitions.size()!=3:
		return false
	for resident_id: Variant in data.residents.definitions:
		if not (resident_id is String) or not String(resident_id).begins_with("resident."):
			return false
		var resident: Variant = data.residents.definitions[resident_id]
		if not _exact_keys(resident,["display_name","occupation_id","home_anchor_id","work_anchor_id","social_anchor_id","rain_anchor_id","schedule","rain_schedule"]):
			return false
		for field: String in ["display_name","occupation_id","home_anchor_id","work_anchor_id","social_anchor_id","rain_anchor_id"]:
			if not (resident[field] is String) or String(resident[field]).is_empty():
				return false
		if resident.display_name.length()>24 or not String(resident.occupation_id).begins_with("occupation."):
			return false
		var anchor_by_activity := {
			"home":String(resident.home_anchor_id),
			"work":String(resident.work_anchor_id),
			"social":String(resident.social_anchor_id),
			"rain":String(resident.rain_anchor_id)
		}
		for activity_id: String in anchor_by_activity:
			if not anchor_by_activity[activity_id].begins_with("anchor.resident."):
				return false
		for schedule_key: String in ["schedule","rain_schedule"]:
			var schedule: Variant = resident[schedule_key]
			if not (schedule is Array) or schedule.is_empty():
				return false
			if schedule[0].start_minute != data.clock.day_start_minute or schedule[-1].activity_id != "home":
				return false
			var required_activities: Array = ["home","work","social"] if schedule_key=="schedule" else ["home","rain"]
			var seen_activities: Dictionary = {}
			var previous_start := -1
			for entry: Variant in schedule:
				if not _exact_keys(entry,["start_minute","activity_id","anchor_id"]):
					return false
				if not _nonnegative_int(entry.start_minute) or entry.start_minute>=data.clock.minutes_per_day or entry.start_minute<=previous_start:
					return false
				if entry.activity_id not in required_activities or not (entry.anchor_id is String) or entry.anchor_id.is_empty():
					return false
				if String(entry.anchor_id) != String(anchor_by_activity[entry.activity_id]):
					return false
				seen_activities[String(entry.activity_id)] = true
				previous_start=entry.start_minute
			for activity_id: String in required_activities:
				if not seen_activities.has(activity_id):
					return false
	if not _exact_keys(data.dialogues,["player_resident"]) or not (data.dialogues.player_resident is Dictionary) or data.dialogues.player_resident.is_empty():
		return false
	var dialogue_ids: Dictionary = {}
	var dialogue_event_ids: Dictionary = {}
	for resident_id: Variant in data.dialogues.player_resident:
		if not (resident_id is String) or not data.residents.definitions.has(resident_id):
			return false
		var dialogue: Variant = data.dialogues.player_resident[resident_id]
		if not _exact_keys(dialogue,["space_id","first_meeting","repeat"]):
			return false
		if not (dialogue.space_id is String) or not String(dialogue.space_id).begins_with("space.") or String(dialogue.space_id).length()>128:
			return false
		if not _exact_keys(dialogue.first_meeting,["dialogue_id","event_id","event_kind","text"]):
			return false
		if not _exact_keys(dialogue.repeat,["dialogue_id","text"]):
			return false
		for dialogue_id: Variant in [dialogue.first_meeting.dialogue_id,dialogue.repeat.dialogue_id]:
			if not (dialogue_id is String) or not String(dialogue_id).begins_with("dialogue.") or String(dialogue_id).length()>128 or dialogue_ids.has(dialogue_id):
				return false
			dialogue_ids[String(dialogue_id)]=true
		if not (dialogue.first_meeting.event_id is String) or not String(dialogue.first_meeting.event_id).begins_with("event.") or String(dialogue.first_meeting.event_id).length()>128 or dialogue_event_ids.has(dialogue.first_meeting.event_id):
			return false
		dialogue_event_ids[String(dialogue.first_meeting.event_id)]=true
		if not (dialogue.first_meeting.event_kind is String) or dialogue.first_meeting.event_kind.is_empty() or String(dialogue.first_meeting.event_kind).length()>128:
			return false
		for text_value: Variant in [dialogue.first_meeting.text,dialogue.repeat.text]:
			if not (text_value is String) or String(text_value).is_empty() or String(text_value).length()>512:
				return false
	if not _exact_keys(data.new_game, ["initial_items"]) or not (data.new_game.initial_items is Array):
		return false
	var occupied_slots := 0
	for entry: Variant in data.new_game.initial_items:
		if not _exact_keys(entry, ["item_id","quantity"]):
			return false
		if not entry.item_id in data.items or not _positive_int(entry.quantity):
			return false
		if entry.quantity > data.items[entry.item_id].stack_limit:
			return false
		occupied_slots += 1
	if occupied_slots > data.inventory.capacity:
		return false
	return true

static func load_path(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return failure("CONTENT_OPEN_FAILED")
	var text := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return failure("CONTENT_JSON_INVALID")
	var data: Variant = _normalize_numbers(parser.data)
	if not validate(data):
		return failure("CONTENT_INVALID")
	return {"ok": true, "error_code": "", "data": data}

static func load_current() -> Dictionary:
	return load_path(CURRENT_PATH)
