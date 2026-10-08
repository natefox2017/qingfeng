extends SceneTree
const MAIN = preload("res://app/main.tscn")
const CODEC = preload("res://persistence/session_codec.gd")
const STORE = preload("res://persistence/session_store.gd")
const SETTINGS = preload("res://persistence/settings_store.gd")
const UI_THEME = preload("res://ui/theme/ui_theme.gd")
const SESSION = preload("res://app/gameplay_session.gd")
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
	app._on_action("new_game",{});app._on_action("back",{})
	check(app.view.buttons["new_game"].has_focus(),"closing new-game form restores its title trigger")
	app._on_action("load",{});app._on_action("back",{})
	check(app.view.buttons["load"].has_focus(),"closing load page restores its title trigger")
	app._on_action("settings",{});app._on_action("back",{})
	check(app.view.buttons["settings"].has_focus(),"closing settings restores its title trigger")
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
	check(await wait_world(),"title new form loads farm world")
	if app.state!=app.State.WORLD:printerr(app.last_error);finish();return
	check(app.gameplay_session != null and app.room.has_method("get_plot_definitions") and app.active_snapshot.space_id=="space.farm","new game publishes one gameplay session on farm world")
	check(app.active_snapshot.has("gameplay") and app.store.list_saves().size()==1,"new game commits gameplay snapshot once after world validation")
	var initial_save:Dictionary=app.store.read_save(app.active_save_id)
	check(initial_save.ok and int(initial_save.envelope.schema_version)==7 and initial_save.envelope.snapshot.gameplay.inventory.slots.size()==12 and initial_save.envelope.snapshot.gameplay.residents.residents.size()==3 and initial_save.envelope.snapshot.gameplay.fact_events.events.is_empty(),"new game persists current full gameplay schema with resident runtime and empty fact log")
	check(app.gameplay_session.inventory.quantity_of("item.radish_seed")==4 and app.gameplay_session.wallet.money==200,"new game uses authoritative content-version inventory and wallet")
	check(app.view.quickbar != null and app.view.quickbar.get_child_count()==12 and app.view.buttons.has("inventory"),"world HUD renders twelve live quick slots and backpack action")
	check(app.view.wallet_label != null and app.view.wallet_label.text.contains("200"),"world HUD projects authoritative wallet value")
	check(app.gameplay_session.projection().items["item.hoe"].display_name=="锄头","item display name comes from content-version projection")
	app._on_action("select_slot",{"slot_index":2})
	check(app.gameplay_session.inventory.selected_slot_index==2 and app.view.quickbar.get_child(2).text.begins_with("[3]"),"click intent selects slot through inventory command and rerenders selection")
	var b_key:=InputEventKey.new();b_key.physical_keycode=KEY_B;b_key.pressed=true
	check(InputMap.event_is_action(b_key,"inventory_menu"),"B is mapped to backpack input")
	app._unhandled_key_input(b_key)
	check(app.locks.has_owner(&"inventory") and app.gameplay_session.clock.is_paused() and app.view.title.text=="背包","B opens backpack and owns input/clock pause")
	var two_key:=InputEventKey.new();two_key.physical_keycode=KEY_2;two_key.pressed=true
	check(InputMap.event_is_action(two_key,"select_slot_2"),"number key is mapped to quick-slot selection")
	app._unhandled_key_input(two_key)
	check(app.gameplay_session.inventory.selected_slot_index==1 and app.locks.has_owner(&"inventory"),"number selection uses command while backpack remains topmost")
	var escape_inventory:=InputEventKey.new();escape_inventory.physical_keycode=KEY_ESCAPE;escape_inventory.pressed=true
	app._unhandled_key_input(escape_inventory)
	check(not app.locks.has_owner(&"inventory") and not app.gameplay_session.clock.is_paused() and app.room.get_player().is_input_enabled,"Esc closes only backpack and releases its pause token")
	var till_command:Dictionary={
		"protocol_version":1,"command_id":"entry-till","session_id":app.active_snapshot.session_id,
		"actor_id":"actor.player","action":"farm.till","expected_revision":app.gameplay_session.farm.revision,
		"payload":{"plot_id":"plot.farm.001"}
	}
	var till_result:Dictionary=app.gameplay_session.execute(till_command)
	check(till_result.ok and app.gameplay_session.farm.get_plot("plot.farm.001").state=="tilled","farm command mutates authoritative session before save")
	app.room.get_player().position=Vector2(240,176)
	app.set_pause_menu(true)
	check(app.gameplay_session.clock.is_paused(),"pause menu pauses authoritative gameplay clock")
	var saved:Dictionary=app.save_progress()
	check(saved.ok and app.store.list_saves().size()==2,"pause saves fresh gameplay file without overwriting previous save")
	app.return_to_title()
	app._on_action("read_save",{"save_id":saved.save_id})
	check(await wait_world(),"current gameplay save reloads through farm world")
	check(app.room.get_player().position.is_equal_approx(Vector2(240,176)),"farm position restored after physical validation")
	check(app.gameplay_session != null and app.gameplay_session.farm.get_plot("plot.farm.001").state=="tilled","gameplay farm state restores with world-owned plot definitions")
	check(not app.gameplay_session.clock.is_paused(),"load does not persist stale UI pause tokens")
	app.set_pause_menu(true);app._on_action("settings",{})
	app.view.volume.value=0.35;app._on_action("preview_settings",{})
	app.set_application_focused(false)
	check(not app.settings.is_previewing,"lost focus reverts display preview")
	app._on_action("back",{})
	check(app.locks.has_owner(&"pause_menu") and app.locks.has_owner(&"focus"),"settings never clears pause/focus owners")
	check(app.gameplay_session.clock.is_paused(),"settings/focus locks keep gameplay clock paused")
	app.set_application_focused(true);app._on_action("resume",{})
	check(app.room.get_player().is_input_enabled and not app.gameplay_session.clock.is_paused(),"resume restores world input and gameplay clock")
	app.return_to_title()
	var legacy_saved:Dictionary=app.store.write_new(snapshot)
	check(legacy_saved.ok,"legacy schema-one fixture save remains writable for compatibility")
	if legacy_saved.ok:
		app._on_action("read_save",{"save_id":legacy_saved.save_id})
		check(await wait_world(),"legacy schema-one save still loads explicit collision fixture")
		check(app.gameplay_session==null and not app.active_snapshot.has("gameplay"),"legacy fixture never fabricates gameplay state")
		app.return_to_title()
	app._on_action("load",{})
	app._on_action("preview_import",{"path":first.path})
	check(app._page=="import_review","import shows metadata confirmation")
	var count:int=app.store.list_saves().size()
	app._on_action("cancel_import",{})
	check(app.store.list_saves().size()==count,"cancel import writes nothing")
	check(app.view.buttons["choose_import"].has_focus(),"cancel import returns focus to import trigger")
	app._on_action("back",{})
	var mismatched_session = SESSION.new([
		{"plot_id":"plot.entry.v2","space_id":"space.farm","cell_position":{"x":1,"y":1}}
	])
	var mismatched_identity:Dictionary=CODEC.new_snapshot("不匹配档","阿豆")
	mismatched_identity.space_id="space.farm"
	mismatched_identity.world_position_px={"x":144.0,"y":176.0}
	var v2_snapshot: Dictionary = CODEC.compose_gameplay_snapshot(mismatched_identity,mismatched_session.snapshot())
	var v2_saved: Dictionary = app.store.write_new(v2_snapshot)
	check(v2_saved.ok,"gameplay save can share the same bounded store")
	if v2_saved.ok:
		app._on_action("read_save",{"save_id":v2_saved.save_id})
		check(not await wait_world() and app.room==null and app.gameplay_session==null and app.last_error.contains("不兼容"),"layout-mismatched gameplay restore fails atomically")
	var blocked_snapshot:=snapshot.duplicate(true);blocked_snapshot.world_position_px={"x":176,"y":140}
	var blocked_file:Dictionary=store.write_new(blocked_snapshot)
	app._entry_snapshot=store.read_save(blocked_file.save_id).envelope.snapshot
	app.start_world()
	check(not await wait_world() and app.room==null,"wall-embedded legacy save rejected without teleport fallback")
	finish()

func finish() -> void:
	if is_instance_valid(app):app.queue_free();await process_frame
	print("PAGES_PASS checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
