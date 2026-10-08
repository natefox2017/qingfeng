extends "res://tests/chapter1_map_save_migration_test.gd"
## Fixture was written by the unchanged old a871fdb game/store after its actual
## three-day economy test, not synthesized from today's snapshot. No user data.
const FIXTURE := "res://tests/fixtures/chapter1/legacy_a871fdb.qfsave"
const FIXTURE_SHA := "447fe13e78d79219a43b7f1997cf65d1719d3f7e65119005bf5ad9fae10c6b8b"

func run() -> void:
	create_timer(60).timeout.connect(func(): printerr("HISTORICAL_SAVE_TIMEOUT"); quit(1))
	check(FileAccess.get_sha256(FIXTURE) == FIXTURE_SHA, "untouched old-version-generated fixture SHA")
	app = MAIN.instantiate()
	var isolated := "user://historical_map_" + Crypto.new().generate_random_bytes(8).hex_encode()
	app.store.directory = isolated + "/saves"
	app.settings.path = isolated + "/settings.json"
	root.add_child(app)
	current_scene = app
	app.set_application_focused(true)
	var read: Dictionary = app.store.read_external(FIXTURE)
	check(bool(read.get("ok", false)), "current real store verifies old checksum and schema")
	if not read.get("ok", false):
		await finish()
		return
	var old: Dictionary = read.envelope.snapshot
	var old_id := String(read.envelope.save_id)
	DirAccess.make_dir_recursive_absolute(app.store.directory)
	var old_path: String = app.store.directory.path_join(old_id + ".qfsave")
	check(DirAccess.copy_absolute(FIXTURE, old_path) == OK, "copy unchanged old bytes into isolated store")
	app._on_action("read_save", {"save_id":old_id})
	check(await wait_world(), "old implementation save loads actual world: " + app.last_error)
	if app.state != app.State.WORLD:
		await finish()
		return
	app.set_process(false)
	check(app.gameplay_session.clock.current_day() == 3 and app.gameplay_session.wallet.money == 195, "actual old three-day economy result survives")
	check(CODEC.canonical(app.gameplay_session.inventory.projection()) == CODEC.canonical(old.gameplay.inventory), "full old inventory including selection survives")
	check(CODEC.canonical(app.gameplay_session.storage.projection()) == CODEC.canonical(old.gameplay.storage), "full old chest reserve survives")
	check(app.room.get_player().position.distance_to(app.room.get_spawn_position()) < 0.01, "old farm player uses safe new spawn")
	var definitions: Array = app.room.get_plot_definitions()
	check(definitions.size() == 6, "all six authored plots remain")
	for previous: Dictionary in old.gameplay.farm.plots:
		var current: Dictionary = app.gameplay_session.farm.get_plot(previous.plot_id)
		var expected: Dictionary = previous.duplicate(true)
		for definition: Dictionary in definitions:
			if definition.plot_id == previous.plot_id:
				expected.cell_position = definition.cell_position
		check(CODEC.canonical(current) == CODEC.canonical(expected), "full old crop state and new cell preserved " + previous.plot_id)
	var anchors: Array = app._resident_anchor_definitions_for_gameplay()
	var residents: Array = app.gameplay_session.resident_runtime.snapshot().residents
	for previous: Dictionary in old.gameplay.residents.residents:
		var expected: Dictionary = previous.duplicate(true)
		for anchor: Dictionary in anchors:
			if anchor.anchor_id == "anchor.%s.social" % previous.resident_id:
				expected.world_position_px = anchor.world_position_px
		var found := false
		for current: Dictionary in residents:
			if current.resident_id == previous.resident_id:
				found = CODEC.canonical(current) == CODEC.canonical(expected)
		check(found, "old resident identity/state survives at new social anchor " + previous.resident_id)
	var village := load("res://world/village_first_screen.tscn").instantiate() as Node2D
	# Separate translated physics fixture avoids overlaying the farm colliders.
	village.position = Vector2(8192, 8192)
	root.add_child(village)
	await physics_frame
	for resident: Dictionary in residents:
		var point := Vector2(resident.world_position_px.x, resident.world_position_px.y)
		check(village.get_world_bounds().has_point(Vector2i(point)) and village._resident_position_is_safe(point), "migrated resident is in bounds and collision-free " + resident.resident_id)
	village.queue_free()
	await process_frame
	check(FileAccess.get_sha256(old_path) == FIXTURE_SHA, "loading never overwrites original old bytes")
	var saved: Dictionary = app.save_progress()
	check(saved.get("ok", false) and saved.get("save_id", "") != old_id, "migrated state writes a distinct new save")
	if saved.get("ok", false):
		var new_read: Dictionary = app.store.read_save(saved.save_id)
		check(new_read.get("ok", false), "new migrated file verifies checksum")
		app.set_process(true)
		app.return_to_title()
		app._on_action("read_save", {"save_id":saved.save_id})
		check(await wait_world(), "new migrated save reopens actual world")
		if app.state == app.State.WORLD:
			var again: Dictionary = app.save_progress()
			var reread: Dictionary = app.store.read_save(again.get("save_id", ""))
			check(reread.get("ok", false) and CODEC.canonical(reread.envelope.snapshot.gameplay.farm) == CODEC.canonical(new_read.envelope.snapshot.gameplay.farm), "new save reload preserves all six complete crop states")
			check(app.gameplay_session.wallet.money == 195 and CODEC.canonical(app.gameplay_session.inventory.projection()) == CODEC.canonical(old.gameplay.inventory), "new save reload preserves money and inventory")
	check(FileAccess.get_sha256(old_path) == FIXTURE_SHA and FileAccess.get_sha256(FIXTURE) == FIXTURE_SHA, "both old source and isolated copy remain byte identical")
	await finish()

func finish() -> void:
	if is_instance_valid(app):
		app.queue_free()
		await process_frame
	root.get_node("AudioManager").shutdown_audio()
	await process_frame
	print("HISTORICAL_SAVE_RESULT checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
