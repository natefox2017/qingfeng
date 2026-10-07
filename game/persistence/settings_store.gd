extends RefCounted
const CODEC = preload("res://persistence/session_codec.gd")
const DEFAULTS := {"master_volume":0.8,"is_fullscreen":false,"is_vsync_enabled":true}
var path := "user://qingfeng/settings.json"
var committed: Dictionary = DEFAULTS.duplicate(true)
var is_previewing := false
var remaining_seconds := 0.0
var draft: Dictionary = {}
var load_error := ""

func is_valid(value: Variant) -> bool:
	return CODEC.keys(value,DEFAULTS.keys()) and (value.master_volume is int or value.master_volume is float) and is_finite(float(value.master_volume)) and value.master_volume >= 0 and value.master_volume <= 1 and value.is_fullscreen is bool and value.is_vsync_enabled is bool

func initialize() -> void:
	# Recover the last good settings if a process ended between two renames.
	if not FileAccess.file_exists(path) and FileAccess.file_exists(path+".bak"):
		DirAccess.rename_absolute(path+".bak",path)
	if FileAccess.file_exists(path):
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null or file.get_length() > 4096:
			load_error = "SETTINGS_READ_FAILED"
		else:
			var text := file.get_as_text()
			var parser := JSON.new()
			if CODEC.bounded_json(text) and parser.parse(text) == OK and is_valid(parser.data): committed = parser.data
			else: load_error = "SETTINGS_INVALID"
	apply(committed)

func apply(value: Dictionary) -> void:
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,float(value.master_volume))))
	AudioServer.set_bus_mute(0,is_zero_approx(float(value.master_volume)))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value.is_fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if value.is_vsync_enabled else DisplayServer.VSYNC_DISABLED)

func begin_preview(value: Dictionary) -> Dictionary:
	if not is_valid(value): return CODEC.failure("SETTINGS_INVALID")
	draft = value.duplicate(true)
	is_previewing = true
	remaining_seconds = 10.0
	apply(draft)
	return {"ok":true}

func tick(delta: float) -> bool:
	if not is_previewing: return false
	remaining_seconds -= delta
	if remaining_seconds > 0: return false
	revert()
	return true

func revert() -> void:
	if is_previewing: apply(committed)
	is_previewing = false
	draft.clear()
	remaining_seconds = 0

func confirm() -> Dictionary:
	if not is_previewing: return CODEC.failure("SETTINGS_NO_PREVIEW")
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK: return CODEC.failure("SETTINGS_WRITE_FAILED")
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null: return CODEC.failure("SETTINGS_WRITE_FAILED")
	file.store_string(CODEC.canonical(draft));file.flush()
	var error := file.get_error();file.close()
	if error != OK: return CODEC.failure("SETTINGS_WRITE_FAILED")
	# Keep an old good file until the replacement is published; no delete-first.
	var had_old := FileAccess.file_exists(path)
	if had_old:
		if FileAccess.file_exists(path+".bak"): DirAccess.remove_absolute(path+".bak")
		if DirAccess.rename_absolute(path,path+".bak") != OK: return CODEC.failure("SETTINGS_WRITE_FAILED")
	if DirAccess.rename_absolute(path+".tmp",path) != OK:
		if had_old: DirAccess.rename_absolute(path+".bak",path)
		return CODEC.failure("SETTINGS_WRITE_FAILED")
	committed = draft.duplicate(true)
	is_previewing = false;draft.clear();load_error = ""
	return {"ok":true}
