extends SceneTree
const MAIN = preload("res://app/main.tscn")
const CODEC = preload("res://persistence/session_codec.gd")
const STORE = preload("res://persistence/session_store.gd")
const SETTINGS = preload("res://persistence/settings_store.gd")
const UI_THEME = preload("res://ui/theme/ui_theme.gd")
var checks := 0
var failures: Array[String] = []
var app: Control
var directory: String

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label);printerr("CHECK_FAIL ", label)

func write(path: String, text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE);file.store_string(text);file.close()

func wait_world() -> bool:
	for i in 180:
		await physics_frame
		if app.state==app.State.WORLD:return true
		if app.state==app.State.TITLE and not app.last_error.is_empty():return false
	return false

func run() -> void:
	create_timer(25).timeout.connect(func():printerr("PAGES_TIMEOUT");quit(1))
	directory="user://page_test_"+Crypto.new().generate_random_bytes(8).hex_encode()
	DirAccess.make_dir_recursive_absolute(directory)
	var snapshot:Dictionary=CODEC.new_snapshot("小禾","阿豆")
	var id: String=Crypto.new().generate_random_bytes(16).hex_encode()
	var encoded:String=CODEC.encode(snapshot,id)
	check(CODEC.decode(encoded).ok,"save canonical checksum roundtrip")
	check(not CODEC.decode(encoded.replace("小禾","小林")).ok,"mutated checksum rejected")
	check(not CODEC.decode('{"a":1,"a":2}').ok,"duplicate fields rejected")
	check(not CODEC.decode('{"a":1,"\\u0061":2}').ok,"escaped duplicate field rejected")
	check(not CODEC.decode("[".repeat(32)+"]".repeat(32)).ok,"nested input rejected before parser")
	check(not CODEC.decode("x".repeat(CODEC.MAX_FILE_BYTES+1)).ok,"oversized input rejected")
	check(not CODEC.decode('[gd_resource type="Script"]').ok,"import never loads a Godot resource")
	for field: String in snapshot:
		var malformed:=snapshot.duplicate(true);malformed.erase(field)
		check(not CODEC.validate_snapshot(malformed),"missing field rejected: "+field)
	var malformed:=snapshot.duplicate(true);malformed.world_position_px.x=true
	check(not CODEC.validate_snapshot(malformed),"boolean coordinate rejected")
	malformed=snapshot.duplicate(true);malformed.world_position_px.x=NAN
	check(not CODEC.validate_snapshot(malformed),"nonfinite coordinate rejected")
	check(not CODEC.name_is_valid("\u202eabc"),"bidi control rejected")
	check(not CODEC.utf8_is_valid(PackedByteArray([0xc0,0xaf])),"overlong UTF8 rejected without engine decode")
	check(not CODEC.utf8_is_valid(PackedByteArray([0xed,0xa0,0x80])),"UTF8 surrogate rejected")
	check(CODEC.utf8_is_valid("小禾😀".to_utf8_buffer()),"valid multilingual UTF8 supported")
	check(not CODEC.name_is_valid(""),"empty player name rejected")
	check(CODEC.name_is_valid("",true),"optional dog name allowed")
	var foreign:Dictionary=JSON.parse_string(encoded);foreign.schema_version=200
	check(CODEC.decode(CODEC.canonical(foreign)).error_code=="SAVE_VERSION_UNSUPPORTED","future schema rejected")
	foreign=JSON.parse_string(encoded);foreign.content_version="different_map"
	check(CODEC.decode(CODEC.canonical(foreign)).error_code=="SAVE_CONTENT_UNSUPPORTED","wrong map content rejected")
	var store:=STORE.new();store.directory=directory.path_join("saves")
	check(store.list_saves().is_empty(),"empty save directory usable")
	var first:Dictionary=store.write_new(snapshot)
	check(first.ok,"save writes verified atomic file")
	if not first.ok:finish();return
	var before_hash:=FileAccess.get_sha256(first.path)
	check(not store.read_save("../other").ok,"save identifier prevents path traversal")
	var preview:Dictionary=store.import_preview(first.path)
	check(preview.ok and store.list_saves().size()==1,"import preview is read-only")
	var imported:Dictionary=store.confirm_import(preview.envelope)
	check(imported.ok and imported.save_id!=first.save_id,"import copy has new local identity")
	check(FileAccess.get_sha256(first.path)==before_hash,"import never overwrites source")
	var imported_snapshot:Dictionary=store.read_save(imported.save_id).envelope.snapshot
	check(imported_snapshot.session_id!=snapshot.session_id,"import isolates session identity")
	write(directory.path_join("not_directory"),"file")
	var blocked_store:=STORE.new();blocked_store.directory=directory.path_join("not_directory/saves")
	check(not blocked_store.write_new(snapshot).ok,"write failure does not fabricate success")
	check(FileAccess.get_sha256(first.path)==before_hash,"failure preserves previous valid save")
	# Draft application rolls back independently of game state and persists only on confirm.
	var settings:=SETTINGS.new();settings.path=directory.path_join("settings.json");settings.initialize()
	var original:Dictionary=settings.committed.duplicate(true)
	var proposed:Dictionary=original.duplicate(true);proposed.master_volume=0.25
	check(settings.begin_preview(proposed).ok and settings.committed==original,"preview is not committed")
	check(settings.tick(11.0) and settings.committed==original and not settings.is_previewing,"timeout restores settings")
	check(not FileAccess.file_exists(settings.path),"timeout writes no settings")
	settings.begin_preview(proposed)
	check(settings.confirm().ok,"confirm saves settings")
	var reloaded:=SETTINGS.new();reloaded.path=settings.path;reloaded.initialize()
	check(is_equal_approx(reloaded.committed.master_volume,0.25),"settings survive restart")
	app=MAIN.instantiate();app.store.directory=directory.path_join("app_saves");app.settings.path=directory.path_join("app_settings.json")
	root.add_child(app);current_scene=app;app.set_application_focused(true)
	check(app.view.theme != null and app.view.theme.default_font_size == UI_THEME.FONT_BODY,"shared UI theme is installed")
	check(app.view.title.get_theme_font_size("font_size") == UI_THEME.FONT_HEADING,"heading token drives title size")
	check(app.view.subtitle.get_theme_color("font_color") == UI_THEME.COLOR_MUTED,"caption token drives subtitle color")
	check(app.view.notice.get_theme_color("font_color") == UI_THEME.COLOR_ERROR,"error token drives notice color")
	check(app.view.buttons["new_game"].tooltip_text == app.view.buttons["new_game"].accessibility_name and not app.view.buttons["new_game"].tooltip_text.is_empty(),"icon action has tooltip and accessible name")
	check(app.view.buttons["continue"].disabled,"title disables continue without saves")
	app._on_action("new_game",{})
	app.view.player_name.text="小禾";app.view.dog_name.text="阿豆"
	app._on_action("create",{})
	app._on_action("create",{})
	check(app.state==app.State.LOADING,"double create click is ignored safely")
	app._on_action("cancel_load",{})
	await physics_frame
	check(app.state==app.State.TITLE and app.store.list_saves().is_empty(),"cancel before activation creates no save")
	app._on_action("new_game",{})
	app.view.player_name.text="小禾";app.view.dog_name.text="阿豆"
	app._on_action("create",{})
	check(await wait_world(),"title new form loads world")
	if app.state!=app.State.WORLD:printerr(app.last_error);finish();return
	check(app.active_snapshot.player_name=="小禾" and app.store.list_saves().size()==1,"new identity is committed once on successful entry")
	app.room.get_player().position=Vector2(120,90)
	app.set_pause_menu(true)
	var saved:Dictionary=app.save_progress()
	check(saved.ok and app.store.list_saves().size()==2,"pause saves fresh non-overwriting revision")
	app.return_to_title()
	app._on_action("read_save",{"save_id":saved.save_id})
	check(await wait_world(),"saved entry can reload")
	check(app.room.get_player().position.is_equal_approx(Vector2(120,90)),"position restored after validation")
	app.set_pause_menu(true);app._on_action("settings",{})
	app.view.volume.value=0.35;app._on_action("preview_settings",{})
	app.set_application_focused(false)
	check(not app.settings.is_previewing,"lost focus reverts display preview")
	app._on_action("back",{})
	check(app.locks.has_owner(&"pause_menu") and app.locks.has_owner(&"focus"),"settings never clears pause/focus owners")
	app.set_application_focused(true);app._on_action("resume",{})
	check(app.room.get_player().is_input_enabled,"resume after settings is usable")
	app.return_to_title();app._on_action("load",{})
	app._on_action("preview_import",{"path":first.path})
	check(app._page=="import_review","import shows metadata confirmation")
	var count:int=app.store.list_saves().size()
	app._on_action("cancel_import",{})
	check(app.store.list_saves().size()==count,"cancel import writes nothing")
	var blocked_snapshot:=snapshot.duplicate(true);blocked_snapshot.world_position_px={"x":176,"y":140}
	var blocked_file:Dictionary=store.write_new(blocked_snapshot)
	app._entry_snapshot=store.read_save(blocked_file.save_id).envelope.snapshot
	app.start_world()
	check(not await wait_world() and app.room==null,"wall-embedded save rejected without teleport fallback")
	finish()

func finish() -> void:
	if is_instance_valid(app):app.queue_free();await process_frame
	print("PAGES_PASS checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
