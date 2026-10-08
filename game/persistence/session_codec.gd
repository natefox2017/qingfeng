extends RefCounted
## Versioned Qingfeng save envelope.
## Schema 1 preserves the explicit entry/collision fixture used by the current UI.
## Gameplay schemas store first-playable identity/world fields plus the authoritative
## GameplaySession snapshot. Runtime world/layout still performs final restore validation.

const CONTENT = preload("res://content/content_catalog.gd")
const JOURNAL = preload("res://app/command_journal.gd")

const ENTRY_CONTENT_VERSION := "entry_fixture_v1"
const GAMEPLAY_CONTENT_VERSION := "first_playable_v1"
const CONTENT_VERSION := ENTRY_CONTENT_VERSION
const MAX_FILE_BYTES := 262144
const MAX_DEPTH := 12
const MAX_CONTAINER_ITEMS := 512
const MAX_WORLD_COORDINATE := 1000000.0
const MAX_PLOTS := 512

static func failure(code: String) -> Dictionary:
	return {"ok": false, "error_code": code}

static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value >= minimum and value <= maximum

static func keys(value: Variant, required: Array) -> bool:
	if not (value is Dictionary) or value.size() != required.size():
		return false
	for key: String in required:
		if not value.has(key):
			return false
	return true

static func identifier(value: Variant) -> bool:
	if not (value is String) or value.length() != 32:
		return false
	for character in value:
		if not character in "0123456789abcdef":
			return false
	return true

static func name_is_valid(value: Variant, optional := false) -> bool:
	if not (value is String) or value.length() > 16 or value != value.strip_edges():
		return false
	if value.is_empty():
		return optional
	for character in value:
		var code: int = character.unicode_at(0)
		if code < 32 or code == 127 or code in [0x202a,0x202b,0x202c,0x202d,0x202e,0x2066,0x2067,0x2068,0x2069]:
			return false
	return true

static func _valid_world_identity(value: Variant, fixture_only: bool) -> bool:
	var required := ["session_id","player_name","dog_name","space_id","world_position_px","facing"]
	if not keys(value,required):
		return false
	if not identifier(value.session_id) or not name_is_valid(value.player_name) or not name_is_valid(value.dog_name,true):
		return false
	if not (value.space_id is String) or value.space_id.is_empty():
		return false
	if fixture_only and value.space_id != "space.collision_fixture":
		return false
	if value.facing not in ["north","south","east","west"]:
		return false
	var point: Variant = value.world_position_px
	if not keys(point,["x","y"]):
		return false
	for axis: String in ["x","y"]:
		if not (point[axis] is int or point[axis] is float) or not is_finite(float(point[axis])):
			return false
		if absf(float(point[axis])) > MAX_WORLD_COORDINATE:
			return false
	if fixture_only:
		return point.x >= 20 and point.x <= 940 and point.y >= 20 and point.y <= 620
	return true

static func validate_entry_snapshot(value: Variant) -> bool:
	return _valid_world_identity(value,true)

static func _current_content() -> Dictionary:
	var result: Dictionary = CONTENT.load_current()
	if not result.ok:
		return {}
	return result.data

static func _valid_slot(slot: Variant, items: Dictionary) -> bool:
	if slot == null:
		return true
	if not keys(slot,["item_id","quantity"]):
		return false
	if not (slot.item_id is String) or not items.has(slot.item_id):
		return false
	if not (slot.quantity is int) or slot.quantity <= 0:
		return false
	return slot.quantity <= int(items[slot.item_id].stack_limit)

static func _valid_inventory(value: Variant, content: Dictionary) -> bool:
	if not keys(value,["revision","container_id","capacity","slots","selected_slot_index"]):
		return false
	if value.container_id != "container.player" or value.capacity != content.inventory.capacity:
		return false
	if not (value.revision is int) or value.revision < 0:
		return false
	if not (value.selected_slot_index is int) or value.selected_slot_index < 0 or value.selected_slot_index >= value.capacity:
		return false
	if not (value.slots is Array) or value.slots.size() != value.capacity:
		return false
	for slot: Variant in value.slots:
		if not _valid_slot(slot,content.items):
			return false
	return true

static func _valid_storage(value: Variant, content: Dictionary) -> bool:
	if not keys(value,["revision","container_id","capacity","slots"]):
		return false
	if value.container_id != "container.home_chest" or value.capacity != content.storage.chest_capacity:
		return false
	if not (value.revision is int) or value.revision < 0:
		return false
	if not (value.slots is Array) or value.slots.size() != value.capacity:
		return false
	for slot: Variant in value.slots:
		if not _valid_slot(slot,content.items):
			return false
	return true

static func _valid_forage(value: Variant, current_day: int) -> bool:
	if not keys(value,["revision","spots"]):
		return false
	if not (value.revision is int) or value.revision < 0:
		return false
	if not (value.spots is Array) or value.spots.is_empty() or value.spots.size() > 128:
		return false
	var ids: Dictionary = {}
	for spot: Variant in value.spots:
		if not keys(spot,["spot_id","last_collected_day"]):
			return false
		if not (spot.spot_id is String) or spot.spot_id.is_empty() or ids.has(spot.spot_id):
			return false
		if not (spot.last_collected_day is int) or spot.last_collected_day < 0 or spot.last_collected_day > current_day:
			return false
		ids[spot.spot_id]=true
	return true

static func _valid_wallet(value: Variant) -> bool:
	if not keys(value,["revision","owner_id","money"]):
		return false
	return value.owner_id == "actor.player" and value.revision is int and value.revision >= 0 and value.money is int and value.money >= 0

static func _valid_plot(value: Variant, content: Dictionary, current_day: int) -> bool:
	var required := ["plot_id","space_id","cell_position","state","crop_id","growth_days","is_watered","last_settled_day"]
	if not keys(value,required):
		return false
	if not (value.plot_id is String) or value.plot_id.is_empty() or not (value.space_id is String) or value.space_id.is_empty():
		return false
	if not keys(value.cell_position,["x","y"]) or not (value.cell_position.x is int) or not (value.cell_position.y is int):
		return false
	if value.state not in ["untilled","tilled","growing","mature"]:
		return false
	if not (value.growth_days is int) or value.growth_days < 0 or not (value.is_watered is bool):
		return false
	if not (value.last_settled_day is int) or value.last_settled_day < 0 or value.last_settled_day > current_day:
		return false
	if value.state in ["growing","mature"]:
		if not (value.crop_id is String) or not content.crops.has(value.crop_id):
			return false
		var required_days := int(content.crops[value.crop_id].growth_days)
		if value.state == "growing" and value.growth_days >= required_days:
			return false
		if value.state == "mature" and value.growth_days < required_days:
			return false
	else:
		if value.crop_id != null or value.growth_days != 0:
			return false
		if value.state == "untilled" and value.is_watered:
			return false
	return true

static func _valid_farm(value: Variant, content: Dictionary, current_day: int) -> bool:
	if not keys(value,["revision","plots"]):
		return false
	if not (value.revision is int) or value.revision < 0:
		return false
	if not (value.plots is Array) or value.plots.is_empty() or value.plots.size() > MAX_PLOTS:
		return false
	var ids: Dictionary = {}
	for plot: Variant in value.plots:
		if not _valid_plot(plot,content,current_day):
			return false
		if ids.has(plot.plot_id):
			return false
		ids[plot.plot_id] = true
	return true

static func _valid_command_journal(value: Variant) -> bool:
	var journal := JOURNAL.new()
	return journal.restore(value)

static func _valid_gameplay_common(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var required := ["content_version","clock","inventory","wallet","farm"]
	for key: String in required:
		if not value.has(key):
			return false
	for key: Variant in value.keys():
		if key not in ["content_version","clock","inventory","wallet","farm","command_journal","storage","forage"]:
			return false
	if value.has("storage") and not value.has("command_journal"):
		return false
	if value.has("command_journal") and not _valid_command_journal(value.command_journal):
		return false
	if value.content_version != GAMEPLAY_CONTENT_VERSION:
		return false
	var content := _current_content()
	if content.is_empty() or content.content_version != value.content_version:
		return false
	if value.has("storage") and not _valid_storage(value.storage,content):
		return false
	if not keys(value.clock,["game_minute"]) or not (value.clock.game_minute is int) or value.clock.game_minute < 0:
		return false
	var current_day := floori(float(value.clock.game_minute) / float(content.clock.minutes_per_day)) + 1
	if value.has("forage") and not _valid_forage(value.forage,current_day):
		return false
	return _valid_inventory(value.inventory,content) and _valid_wallet(value.wallet) and _valid_farm(value.farm,content,current_day)

static func _valid_gameplay_v2(value: Variant) -> bool:
	return value is Dictionary and value.size() == 5 and not value.has("command_journal") and not value.has("storage") and _valid_gameplay_common(value)

static func _valid_gameplay_v3(value: Variant) -> bool:
	return value is Dictionary and value.size() == 6 and value.has("command_journal") and not value.has("storage") and _valid_gameplay_common(value)

static func _valid_gameplay_v4(value: Variant) -> bool:
	return value is Dictionary and value.size() == 7 and value.has("command_journal") and value.has("storage") and not value.has("forage") and _valid_gameplay_common(value)

static func _valid_gameplay_v5(value: Variant) -> bool:
	return value is Dictionary and value.size() == 8 and value.has("command_journal") and value.has("storage") and value.has("forage") and _valid_gameplay_common(value)

static func validate_gameplay_snapshot(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var identity: Dictionary = value.duplicate(true)
	identity.erase("gameplay")
	if not _valid_world_identity(identity,false):
		return false
	if value.size() != 7 or not value.has("gameplay"):
		return false
	return _valid_gameplay_common(value.gameplay)

static func validate_snapshot(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	if value.has("gameplay"):
		return validate_gameplay_snapshot(value)
	return validate_entry_snapshot(value)

static func new_snapshot(player_name: String, dog_name: String) -> Dictionary:
	return {
		"session_id":Crypto.new().generate_random_bytes(16).hex_encode(),
		"player_name":player_name.strip_edges(),
		"dog_name":dog_name.strip_edges(),
		"space_id":"space.collision_fixture",
		"world_position_px":{"x":96.0,"y":96.0},
		"facing":"south"
	}

static func compose_gameplay_snapshot(identity_snapshot: Dictionary, gameplay_snapshot: Dictionary) -> Dictionary:
	if not _valid_world_identity(identity_snapshot,false) or not _valid_gameplay_common(gameplay_snapshot):
		return {}
	var result := identity_snapshot.duplicate(true)
	result["gameplay"] = gameplay_snapshot.duplicate(true)
	if not validate_gameplay_snapshot(result):
		return {}
	return result

static func canonical(value: Variant) -> String:
	return JSON.stringify(normalized_numbers(value),"",true,true)

static func normalized_numbers(value: Variant) -> Variant:
	# Godot JSON decodes numbers as floats. Normalize integer-valued numbers
	# before hashing, so 1 and 1.0 cannot break a valid save on round-trip.
	if value is float and is_finite(value) and value == floor(value) and absf(value) < 9007199254740992.0:
		return int(value)
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = normalized_numbers(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(normalized_numbers(item))
		return result
	return value

static func _schema_for_snapshot(snapshot: Dictionary) -> int:
	if not snapshot.has("gameplay"):
		return 1
	if snapshot.gameplay.has("forage"):
		return 5
	if snapshot.gameplay.has("storage"):
		return 4
	return 3 if snapshot.gameplay.has("command_journal") else 2

static func _content_for_snapshot(snapshot: Dictionary) -> String:
	return GAMEPLAY_CONTENT_VERSION if snapshot.has("gameplay") else ENTRY_CONTENT_VERSION

static func encode(snapshot: Dictionary, save_id: String) -> String:
	if not validate_snapshot(snapshot) or not identifier(save_id):
		return ""
	var unix_usec := int(Time.get_unix_time_from_system()*1000000)
	var envelope := {
		"save_format":"qingfeng",
		"schema_version":_schema_for_snapshot(snapshot),
		"content_version":_content_for_snapshot(snapshot),
		"save_id":save_id,
		"saved_at_utc":Time.get_datetime_string_from_unix_time(unix_usec/1000000)+(".%06dZ" % (unix_usec % 1000000)),
		"snapshot":snapshot.duplicate(true)
	}
	envelope["checksum"] = canonical(envelope).sha256_text()
	return canonical(envelope)

static func _timestamp_is_valid(value: Variant) -> bool:
	if not (value is String) or value.length() != 27 or not value.ends_with("Z"):
		return false
	var regex := RegEx.new()
	regex.compile("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{6}Z$")
	return regex.search(value) != null

static func decode(text: String) -> Dictionary:
	if text.to_utf8_buffer().size() > MAX_FILE_BYTES:
		return failure("SAVE_TOO_LARGE")
	if not bounded_json(text):
		return failure("SAVE_JSON_STRUCTURE")
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return failure("SAVE_JSON_INVALID")
	var envelope: Variant = normalized_numbers(parser.data)
	if not keys(envelope,["save_format","schema_version","content_version","save_id","saved_at_utc","snapshot","checksum"]):
		return failure("SAVE_FIELDS")
	if envelope.save_format != "qingfeng" or not integer(envelope.schema_version,1,5):
		return failure("SAVE_VERSION_UNSUPPORTED")
	var schema_version := int(envelope.schema_version)
	if schema_version == 1:
		if envelope.content_version != ENTRY_CONTENT_VERSION or not validate_entry_snapshot(envelope.snapshot):
			return failure("SAVE_CONTENT_UNSUPPORTED" if envelope.content_version != ENTRY_CONTENT_VERSION else "SAVE_SNAPSHOT_INVALID")
	elif schema_version == 2:
		if envelope.content_version != GAMEPLAY_CONTENT_VERSION:
			return failure("SAVE_CONTENT_UNSUPPORTED")
		if not validate_gameplay_snapshot(envelope.snapshot) or not _valid_gameplay_v2(envelope.snapshot.gameplay) or envelope.snapshot.gameplay.content_version != envelope.content_version:
			return failure("SAVE_SNAPSHOT_INVALID")
	elif schema_version == 3:
		if envelope.content_version != GAMEPLAY_CONTENT_VERSION:
			return failure("SAVE_CONTENT_UNSUPPORTED")
		if not validate_gameplay_snapshot(envelope.snapshot) or not _valid_gameplay_v3(envelope.snapshot.gameplay) or envelope.snapshot.gameplay.content_version != envelope.content_version:
			return failure("SAVE_SNAPSHOT_INVALID")
	elif schema_version == 4:
		if envelope.content_version != GAMEPLAY_CONTENT_VERSION:
			return failure("SAVE_CONTENT_UNSUPPORTED")
		if not validate_gameplay_snapshot(envelope.snapshot) or not _valid_gameplay_v4(envelope.snapshot.gameplay) or envelope.snapshot.gameplay.content_version != envelope.content_version:
			return failure("SAVE_SNAPSHOT_INVALID")
	elif schema_version == 5:
		if envelope.content_version != GAMEPLAY_CONTENT_VERSION:
			return failure("SAVE_CONTENT_UNSUPPORTED")
		if not validate_gameplay_snapshot(envelope.snapshot) or not _valid_gameplay_v5(envelope.snapshot.gameplay) or envelope.snapshot.gameplay.content_version != envelope.content_version:
			return failure("SAVE_SNAPSHOT_INVALID")
	else:
		return failure("SAVE_VERSION_UNSUPPORTED")
	if not identifier(envelope.save_id):
		return failure("SAVE_ID_INVALID")
	if not _timestamp_is_valid(envelope.saved_at_utc):
		return failure("SAVE_TIMESTAMP_INVALID")
	if not (envelope.checksum is String) or envelope.checksum.length() != 64:
		return failure("SAVE_CHECKSUM")
	var candidate: Dictionary = envelope.duplicate(true)
	candidate.erase("checksum")
	if canonical(candidate).sha256_text() != envelope.checksum:
		return failure("SAVE_CHECKSUM")
	return {"ok":true,"error_code":"","envelope":envelope}

static func bounded_json(text: String) -> bool:
	var stack: Array[Dictionary] = []
	var index := 0
	while index < text.length():
		var character := text[index]
		if character == '"':
			var start := index
			index += 1
			while index < text.length():
				if text[index] == "\\":
					index += 2
					continue
				if text[index] == '"':
					break
				index += 1
			if index >= text.length():
				return false
			if not stack.is_empty() and stack[-1].kind == "{" and stack[-1].expects_key:
				var key_parser := JSON.new()
				if key_parser.parse(text.substr(start,index-start+1)) != OK or not (key_parser.data is String):
					return false
				if stack[-1].keys.has(key_parser.data):
					return false
				stack[-1].keys[key_parser.data] = true
				stack[-1].expects_key = false
				if stack[-1].keys.size() > MAX_CONTAINER_ITEMS:
					return false
		elif character in ["{","["]:
			stack.append({"kind":character,"keys":{},"expects_key":true,"items":0})
			if stack.size() > MAX_DEPTH:
				return false
		elif character in ["}","]"]:
			if stack.is_empty() or (character == "}" and stack[-1].kind != "{") or (character == "]" and stack[-1].kind != "["):
				return false
			stack.pop_back()
		elif character == "," and not stack.is_empty():
			stack[-1].expects_key = true
			stack[-1].items += 1
			if stack[-1].items > MAX_CONTAINER_ITEMS:
				return false
		index += 1
	return stack.is_empty()

static func utf8_is_valid(bytes: PackedByteArray) -> bool:
	var index := 0
	while index < bytes.size():
		var byte: int = bytes[index]
		if byte < 0x80:
			index += 1
			continue
		var extra := 1 if byte >= 0xc2 and byte <= 0xdf else (2 if byte >= 0xe0 and byte <= 0xef else (3 if byte >= 0xf0 and byte <= 0xf4 else -1))
		if extra < 0 or index+extra >= bytes.size():
			return false
		for offset in range(1,extra+1):
			if bytes[index+offset] < 0x80 or bytes[index+offset] > 0xbf:
				return false
		var second: int = bytes[index+1]
		if (byte == 0xe0 and second < 0xa0) or (byte == 0xed and second >= 0xa0) or (byte == 0xf0 and second < 0x90) or (byte == 0xf4 and second >= 0x90):
			return false
		index += extra+1
	return true
