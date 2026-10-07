extends RefCounted
## Strict schema-v2 save envelope: identity/position plus authoritative gameplay snapshot.
## Old schema-v1 entry-fixture saves are left untouched and reported unsupported.

const CONTENT = preload("res://content/content_catalog.gd")
const SCHEMA_VERSION := 2
const CONTENT_VERSION := "first_playable_v1"
const MAX_FILE_BYTES := 262144
const MAX_DEPTH := 16
const MAX_CONTAINER_ITEMS := 128
const MAX_INT := 2147483647

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
		if character not in "0123456789abcdef":
			return false
	return true

static func text_id(value: Variant) -> bool:
	return value is String and not value.is_empty() and value.length() <= 128

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

static func _content() -> Dictionary:
	var result: Dictionary = CONTENT.load_current()
	return result.data if result.ok else {}

static func _validate_inventory(value: Variant, content: Dictionary) -> bool:
	if not keys(value,["revision","container_id","capacity","slots","selected_slot_index"]):
		return false
	if value.container_id != "container.player" or not integer(value.revision,0,MAX_INT):
		return false
	if not integer(value.capacity,1,128) or int(value.capacity) != int(content.inventory.capacity):
		return false
	if not integer(value.selected_slot_index,0,int(value.capacity)-1):
		return false
	if not (value.slots is Array) or value.slots.size() != int(value.capacity):
		return false
	for slot: Variant in value.slots:
		if slot == null:
			continue
		if not keys(slot,["item_id","quantity"]) or not (slot.item_id is String) or not content.items.has(slot.item_id):
			return false
		if not integer(slot.quantity,1,int(content.items[slot.item_id].stack_limit)):
			return false
	return true

static func _validate_wallet(value: Variant) -> bool:
	return keys(value,["revision","owner_id","money"]) and value.owner_id == "actor.player" and integer(value.revision,0,MAX_INT) and integer(value.money,0,MAX_INT)

static func _validate_plot(value: Variant, content: Dictionary) -> bool:
	if not keys(value,["plot_id","space_id","cell_position","state","crop_id","growth_days","is_watered","last_settled_day"]):
		return false
	if not text_id(value.plot_id) or not text_id(value.space_id):
		return false
	if not keys(value.cell_position,["x","y"]) or not integer(value.cell_position.x,-100000,100000) or not integer(value.cell_position.y,-100000,100000):
		return false
	if value.state not in ["untilled","tilled","growing","mature"] or not (value.is_watered is bool):
		return false
	if not integer(value.growth_days,0,100000) or not integer(value.last_settled_day,0,1000000):
		return false
	if value.state in ["untilled","tilled"]:
		return value.crop_id == null and int(value.growth_days) == 0
	if not (value.crop_id is String) or not content.crops.has(value.crop_id):
		return false
	var required_days := int(content.crops[value.crop_id].growth_days)
	if value.state == "growing":
		return int(value.growth_days) < required_days
	return int(value.growth_days) >= required_days and not value.is_watered

static func _validate_farm(value: Variant, content: Dictionary) -> bool:
	if not keys(value,["revision","plots"]) or not integer(value.revision,0,MAX_INT):
		return false
	if not (value.plots is Array) or value.plots.is_empty() or value.plots.size() > 64:
		return false
	var ids: Dictionary = {}
	for plot: Variant in value.plots:
		if not _validate_plot(plot,content) or ids.has(plot.plot_id):
			return false
		ids[plot.plot_id] = true
	return true

static func validate_gameplay(value: Variant) -> bool:
	var content := _content()
	if content.is_empty() or not keys(value,["content_version","clock","inventory","wallet","farm"]):
		return false
	if value.content_version != CONTENT_VERSION:
		return false
	if not keys(value.clock,["game_minute"]) or not integer(value.clock.game_minute,0,100000000):
		return false
	return _validate_inventory(value.inventory,content) and _validate_wallet(value.wallet) and _validate_farm(value.farm,content)

static func validate_snapshot(value: Variant) -> bool:
	if not keys(value,["session_id","player_name","dog_name","space_id","world_position_px","facing","gameplay"]):
		return false
	if not identifier(value.session_id) or not name_is_valid(value.player_name) or not name_is_valid(value.dog_name,true):
		return false
	if value.space_id != "space.collision_fixture" or value.facing not in ["north","south","east","west"]:
		return false
	var point: Variant = value.world_position_px
	if not keys(point,["x","y"]):
		return false
	for axis: String in ["x","y"]:
		if not (point[axis] is int or point[axis] is float) or not is_finite(float(point[axis])):
			return false
	if point.x < 20 or point.x > 940 or point.y < 20 or point.y > 620:
		return false
	return validate_gameplay(value.gameplay)

static func new_identity(player_name: String, dog_name: String) -> Dictionary:
	return {
		"session_id":Crypto.new().generate_random_bytes(16).hex_encode(),
		"player_name":player_name.strip_edges(),
		"dog_name":dog_name.strip_edges(),
		"space_id":"space.collision_fixture",
		"world_position_px":{"x":96.0,"y":96.0},
		"facing":"south"
	}

static func new_snapshot(player_name: String, dog_name: String, gameplay_snapshot: Dictionary) -> Dictionary:
	var snapshot := new_identity(player_name,dog_name)
	snapshot["gameplay"] = gameplay_snapshot.duplicate(true)
	return snapshot

static func canonical(value: Variant) -> String:
	return JSON.stringify(normalized_numbers(value),"",true,true)

static func normalized_numbers(value: Variant) -> Variant:
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

static func encode(snapshot: Dictionary, save_id: String) -> String:
	if not validate_snapshot(snapshot) or not identifier(save_id):
		return ""
	var unix_usec := int(Time.get_unix_time_from_system()*1000000)
	var envelope := {
		"save_format":"qingfeng",
		"schema_version":SCHEMA_VERSION,
		"content_version":CONTENT_VERSION,
		"save_id":save_id,
		"saved_at_utc":Time.get_datetime_string_from_unix_time(unix_usec/1000000)+(".%06dZ" % (unix_usec % 1000000)),
		"snapshot":snapshot.duplicate(true)
	}
	envelope["checksum"] = canonical(envelope).sha256_text()
	return canonical(envelope)

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
	if envelope.save_format != "qingfeng" or not integer(envelope.schema_version,SCHEMA_VERSION,SCHEMA_VERSION):
		return failure("SAVE_VERSION_UNSUPPORTED")
	if envelope.content_version != CONTENT_VERSION:
		return failure("SAVE_CONTENT_UNSUPPORTED")
	if not identifier(envelope.save_id) or not validate_snapshot(envelope.snapshot):
		return failure("SAVE_SNAPSHOT_INVALID")
	if not (envelope.saved_at_utc is String) or envelope.saved_at_utc.length() != 27 or not envelope.saved_at_utc.ends_with("Z"):
		return failure("SAVE_TIMESTAMP_INVALID")
	var regex := RegEx.new()
	regex.compile("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{6}Z$")
	if regex.search(envelope.saved_at_utc) == null:
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
				if text[index] == "\":
					index += 2
					continue
				if text[index] == '"':
					break
				index += 1
			if index >= text.length():
				return false
			if not stack.is_empty() and stack[-1].kind == "{" and stack[-1].expects_key:
				var parser := JSON.new()
				if parser.parse(text.substr(start,index-start+1)) != OK or not (parser.data is String):
					return false
				if stack[-1].keys.has(parser.data):
					return false
				stack[-1].keys[parser.data] = true
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
