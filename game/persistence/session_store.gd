extends RefCounted
## Append-only bounded store. Each atomic write has a fresh filename; no good
## save is overwritten, imports always get a new identity. No ResourceLoader.
const CODEC = preload("res://persistence/session_codec.gd")
const MAX_SAVES := 128
var directory := "user://qingfeng/saves"

func _ensure_directory() -> bool:
	var parent := directory
	while parent.contains("://"):
		if FileAccess.file_exists(parent): return false
		var previous := parent
		parent = parent.get_base_dir()
		if parent == previous: break
	return DirAccess.make_dir_recursive_absolute(directory) == OK

func read_external(path: String) -> Dictionary:
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return CODEC.failure("SAVE_READ_FAILED")
	var size := file.get_length()
	if size <= 0 or size > CODEC.MAX_FILE_BYTES: return CODEC.failure("SAVE_TOO_LARGE")
	var bytes := file.get_buffer(size)
	if bytes.size() != size: return CODEC.failure("SAVE_READ_FAILED")
	if not CODEC.utf8_is_valid(bytes): return CODEC.failure("SAVE_ENCODING_INVALID")
	var text := bytes.get_string_from_utf8()
	if text.to_utf8_buffer() != bytes: return CODEC.failure("SAVE_ENCODING_INVALID")
	return CODEC.decode(text)

func write_new(snapshot: Dictionary) -> Dictionary:
	if not CODEC.validate_snapshot(snapshot): return CODEC.failure("SAVE_SNAPSHOT_INVALID")
	if not _ensure_directory(): return CODEC.failure("SAVE_WRITE_FAILED")
	if list_saves().size() >= MAX_SAVES: return CODEC.failure("SAVE_CAPACITY_REACHED")
	var id := Crypto.new().generate_random_bytes(16).hex_encode()
	var text: String = CODEC.encode(snapshot,id)
	var final_path := directory.path_join(id+".qfsave")
	var temporary := final_path+".tmp"
	if FileAccess.file_exists(final_path): return CODEC.failure("SAVE_ID_CONFLICT")
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null: return CODEC.failure("SAVE_WRITE_FAILED")
	file.store_buffer(text.to_utf8_buffer()); file.flush()
	var error := file.get_error(); file.close()
	if error != OK or not read_external(temporary).ok:
		DirAccess.remove_absolute(temporary)
		return CODEC.failure("SAVE_VERIFY_FAILED")
	if DirAccess.rename_absolute(temporary,final_path) != OK:
		DirAccess.remove_absolute(temporary)
		return CODEC.failure("SAVE_RENAME_FAILED")
	return {"ok":true,"error_code":"","save_id":id,"path":final_path}

func import_preview(path: String) -> Dictionary:
	return read_external(path)

func confirm_import(envelope: Dictionary) -> Dictionary:
	# Revalidate the frozen preview, not a path which might have changed after
	# the user inspected it. Never use a foreign save_id as a local filename.
	var decoded: Dictionary = CODEC.decode(CODEC.canonical(envelope))
	if not decoded.ok: return decoded
	var snapshot: Dictionary = decoded.envelope.snapshot.duplicate(true)
	snapshot.session_id = Crypto.new().generate_random_bytes(16).hex_encode()
	# Command fingerprints include the source session_id. An imported copy is a
	# new session identity, so old idempotency receipts must not be carried across.
	if snapshot.has("gameplay") and snapshot.gameplay.has("command_journal"):
		snapshot.gameplay.command_journal = {"receipts":[]}
	return write_new(snapshot)

func read_save(id: String) -> Dictionary:
	if not CODEC.identifier(id): return CODEC.failure("SAVE_ID_INVALID")
	return read_external(directory.path_join(id+".qfsave"))

func list_saves() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not DirAccess.dir_exists_absolute(directory): return rows
	for filename in DirAccess.get_files_at(directory):
		if filename.get_extension() != "qfsave": continue
		var id := filename.get_basename()
		if not CODEC.identifier(id): continue
		var result := read_save(id)
		rows.append({"save_id":id,"ok":result.ok,"error_code":result.get("error_code",""),"envelope":result.get("envelope",{})})
	rows.sort_custom(func(a:Dictionary,b:Dictionary):return a.envelope.get("saved_at_utc","") > b.envelope.get("saved_at_utc",""))
	return rows
