extends SceneTree
## Regression: a signed pre-PR117 six-plot save loads on the new authored map.
## Runs in a fresh isolated user:// save directory; does not edit user saves.

const MAIN = preload("res://app/main.tscn")
const CODEC = preload("res://persistence/session_codec.gd")
const MIGRATION = preload("res://app/chapter1_map_migration.gd")

const OLD_PLOTS = {
	"plot.farm.001":Vector2i(17,7),
	"plot.farm.002":Vector2i(18,7),
	"plot.farm.003":Vector2i(19,7),
	"plot.farm.004":Vector2i(17,8),
	"plot.farm.005":Vector2i(18,8),
	"plot.farm.006":Vector2i(19,8)
}

var app: Control
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("MAP_SAVE_MIGRATION_FAIL ", label)

func _initialize() -> void:
	run.call_deferred()

func wait_world() -> bool:
	for tick in range(240):
		await physics_frame
		if app.state == app.State.WORLD:
			return true
		if app.state == app.State.TITLE and not app.last_error.is_empty():
			print("MAP_SAVE_MIGRATION_LOAD_ERROR ", app.last_error)
			return false
	return false

func run() -> void:
	create_timer(60).timeout.connect(func(): printerr("MAP_SAVE_MIGRATION_TIMEOUT"); quit(1))
	app = MAIN.instantiate()
	var temp_name := "user://ch1_layout_migration_" + Crypto.new().generate_random_bytes(8).hex_encode()
	app.store.directory = temp_name + "/saves"
	app.settings.path = temp_name + "/settings.json"
	root.add_child(app)
	current_scene = app
	app.set_application_focused(true)
	app._on_action("new_game", {})
	app.view.player_name.text = "小禾"
	app.view.dog_name.text = "阿豆"
	app._on_action("create", {})
	check(await wait_world(), "fresh scene opens before migration test")
	if app.state != app.State.WORLD:
		await finish()
		return

	var seed_count: int = app.gameplay_session.inventory.quantity_of("item.radish_seed")
	var money: int = app.gameplay_session.wallet.money
	var original: Dictionary = app.save_progress()
	check(bool(original.get("ok", false)), "current gameplay save writes")
	if not bool(original.get("ok", false)):
		await finish()
		return
	var original_read: Dictionary = app.store.read_save(String(original.save_id))
	check(bool(original_read.get("ok", false)), "current gameplay save reads")
	if not bool(original_read.get("ok", false)):
		await finish()
		return
	var baseline: Dictionary = original_read.envelope.snapshot.duplicate(true)
	var legacy: Dictionary = baseline.duplicate(true)
	for plot: Variant in legacy.gameplay.farm.plots:
		var old_cell: Vector2i = OLD_PLOTS[String(plot.plot_id)]
		plot.cell_position = {"x":old_cell.x, "y":old_cell.y}
	legacy.world_position_px = {"x":144.0, "y":176.0}
	for resident: Variant in legacy.gameplay.residents.residents:
		if String(resident.space_id) == "space.village":
			resident.world_position_px = {"x":48.0, "y":180.0}
	check(CODEC.validate_snapshot(legacy), "old layout is a structurally valid schema-seven gameplay snapshot")
	var legacy_unchanged: Dictionary = legacy.duplicate(true)
	var plot_defs: Array = app.room.get_plot_definitions()
	var resident_defs: Array = app._resident_anchor_definitions_for_gameplay()
	var spawn: Vector2 = app.room.get_spawn_position()
	var prepared: Dictionary = MIGRATION.migrate(legacy, plot_defs, resident_defs, spawn)
	check(bool(prepared.ok) and bool(prepared.migrated), "exact six-plot legacy fingerprint migrates")
	if not bool(prepared.ok) or not bool(prepared.migrated):
		await finish()
		return
	check(CODEC.validate_snapshot(prepared.snapshot), "migrated result still satisfies snapshot schema")
	check(prepared.snapshot.world_position_px == {"x":spawn.x, "y":spawn.y}, "legacy outdoor player relocated to authored safe spawn")
	check(prepared.snapshot.gameplay.farm.plots[2].cell_position == plot_defs[2].cell_position, "003 gets current authored cell")
	check(prepared.snapshot.gameplay.farm.plots[2].state == baseline.gameplay.farm.plots[2].state, "harvest state unchanged by coordinate migration")
	check(legacy == legacy_unchanged, "migration leaves input and original save untouched")

	var current_result: Dictionary = MIGRATION.migrate(baseline, plot_defs, resident_defs, spawn)
	check(bool(current_result.ok) and not bool(current_result.migrated), "modern save is never migrated")
	var hybrid: Dictionary = legacy.duplicate(true)
	hybrid.gameplay.farm.plots[0].cell_position = plot_defs[0].cell_position.duplicate(true)
	var hybrid_result: Dictionary = MIGRATION.migrate(hybrid, plot_defs, resident_defs, spawn)
	check(bool(hybrid_result.ok) and not bool(hybrid_result.migrated), "unknown partially remapped save is not silently rewritten")

	var legacy_village: Dictionary = legacy.duplicate(true)
	legacy_village.space_id = "space.village"
	legacy_village.world_position_px = {"x":48.0, "y":180.0}
	var village_scene := load("res://world/village_first_screen.tscn") as PackedScene
	var village_instance := village_scene.instantiate() as Node2D
	var village_spawn: Vector2 = village_instance.get_spawn_position()
	village_instance.free()
	var village_result: Dictionary = MIGRATION.migrate(legacy_village, plot_defs, resident_defs, village_spawn)
	check(bool(village_result.ok) and bool(village_result.migrated), "legacy village save also migrates")
	check(village_result.snapshot.world_position_px == {"x":village_spawn.x,"y":village_spawn.y}, "legacy village player reanchors without changing space identity")
	var found_village_resident := false
	for resident: Variant in village_result.snapshot.gameplay.residents.residents:
		if String(resident.space_id) != "space.village":
			continue
		found_village_resident = true
		for anchor: Variant in resident_defs:
			if String(anchor.anchor_id) == "anchor.%s.social" % String(resident.resident_id):
				check(resident.world_position_px == anchor.world_position_px, "village resident reanchors to valid authored social point")
				break
	check(found_village_resident, "legacy fixture contains a village resident to verify")

	var legacy_interior: Dictionary = legacy.duplicate(true)
	legacy_interior.space_id = "space.house"
	legacy_interior.world_position_px = {"x":320.0, "y":320.0}
	var interior_result: Dictionary = MIGRATION.migrate(legacy_interior, plot_defs, resident_defs, Vector2(0,0))
	check(bool(interior_result.ok) and bool(interior_result.migrated), "interior old save migrates farm plots")
	check(interior_result.snapshot.world_position_px == legacy_interior.world_position_px, "unchanged interior player coordinates survive farm migration")

	var old_save: Dictionary = app.store.write_new(legacy)
	check(bool(old_save.get("ok", false)), "signed legacy layout save written through real store")
	if not bool(old_save.get("ok", false)):
		await finish()
		return
	var old_save_id := String(old_save.save_id)
	var old_save_path: String = app.store.directory.path_join(old_save_id + ".qfsave")
	var old_save_bytes_before: PackedByteArray = FileAccess.get_file_as_bytes(old_save_path)
	check(not old_save_bytes_before.is_empty(), "signed legacy save bytes captured before migration")
	app.return_to_title()
	app._on_action("read_save", {"save_id":old_save_id})
	check(await wait_world(), "real read_save loads old signed layout")
	if app.state != app.State.WORLD:
		await finish()
		return
	check(app.room.get_space_id() == "space.farm", "legacy outdoor room identity preserved")
	check(app.room.get_player().position.distance_to(app.room.get_spawn_position()) < 0.01, "loaded position uses new authored farm spawn")
	check(app.gameplay_session.inventory.quantity_of("item.radish_seed") == seed_count and app.gameplay_session.wallet.money == money, "inventory and money survive one-time migration")
	check(CODEC.canonical(app.gameplay_session.farm.projection().plots) == CODEC.canonical(prepared.snapshot.gameplay.farm.plots), "all six loaded plots use current cells and preserve full crop state")
	check(CODEC.canonical(app.gameplay_session.resident_runtime.snapshot()) == CODEC.canonical(prepared.snapshot.gameplay.residents), "all loaded resident positions match safe migrated anchors")
	var after_old_load: Dictionary = app.store.read_save(old_save_id)
	var old_save_bytes_after: PackedByteArray = FileAccess.get_file_as_bytes(old_save_path)
	check(bool(after_old_load.ok) and CODEC.canonical(after_old_load.envelope.snapshot) == CODEC.canonical(legacy), "signed legacy payload remains semantically unchanged")
	check(old_save_bytes_after == old_save_bytes_before, "original signed legacy save bytes remain unchanged")
	var new_save: Dictionary = app.save_progress()
	check(bool(new_save.get("ok", false)), "fresh save after migration succeeds")
	if bool(new_save.get("ok", false)):
		var new_read: Dictionary = app.store.read_save(String(new_save.save_id))
		check(bool(new_read.ok) and CODEC.canonical(new_read.envelope.snapshot.gameplay.farm.plots) == CODEC.canonical(prepared.snapshot.gameplay.farm.plots), "subsequent signed save round-trips all six migrated plots")
		check(bool(new_read.ok) and CODEC.canonical(new_read.envelope.snapshot.gameplay.residents) == CODEC.canonical(prepared.snapshot.gameplay.residents), "subsequent signed save round-trips migrated resident positions")
	await finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	root.get_node("AudioManager").shutdown_audio()
	await process_frame
	print("MAP_SAVE_MIGRATION_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
