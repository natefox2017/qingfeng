extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const SESSION = preload("res://app/gameplay_session.gd")
const CODEC = preload("res://persistence/session_codec.gd")
const STORE = preload("res://persistence/session_store.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL receipt ", label)

func farm_command(id: String, action: String, revision: int, payload: Dictionary) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":id,
		"session_id":"session.receipt",
		"actor_id":"actor.player",
		"action":action,
		"expected_revision":revision,
		"payload":payload
	}

func _initialize() -> void:
	var loaded: Dictionary = CONTENT.load_current()
	check(loaded.ok, "content loads")
	if not loaded.ok:
		finish()
		return
	var plot_definitions := [
		{"plot_id":"plot.receipt.001","space_id":"space.farm","cell_position":{"x":17,"y":7}}
	]
	var session = SESSION.new(plot_definitions, loaded.data)
	check(session.is_configured(), "session configures")
	var command: Dictionary = farm_command("receipt-till","farm.till",session.farm.revision,{"plot_id":"plot.receipt.001"})
	var first: Dictionary = session.execute(command)
	check(first.ok and session.farm.get_plot("plot.receipt.001").state == "tilled", "first command mutates once")
	var saved: Dictionary = session.snapshot()
	check(saved.has("command_journal") and saved.command_journal.receipts.size() == 1, "gameplay snapshot includes receipt journal")

	var restored = SESSION.new(plot_definitions, loaded.data)
	check(restored.restore(saved), "session restores receipt journal")
	var restored_revision: int = restored.farm.revision
	var replay: Dictionary = restored.execute(command)
	check(replay == first and restored.farm.revision == restored_revision, "same request replays after restore without second mutation")
	var conflict: Dictionary = restored.execute(farm_command("receipt-till","farm.water",0,{"plot_id":"plot.receipt.001"}))
	check(not conflict.ok and conflict.error_code == "COMMAND_ID_CONFLICT" and restored.farm.revision == restored_revision, "same id different request conflicts after restore")

	var before_bad: Dictionary = restored.snapshot()
	var bad: Dictionary = saved.duplicate(true)
	bad.command_journal.receipts[0].fingerprint = "0"
	check(not restored.restore(bad) and restored.snapshot() == before_bad, "invalid receipt cannot partially restore session")

	var identity: Dictionary = CODEC.new_snapshot("小禾","阿豆")
	identity.space_id = "space.farm"
	identity.world_position_px = {"x":144.0,"y":176.0}
	var full: Dictionary = CODEC.compose_gameplay_snapshot(identity,saved)
	check(not full.is_empty() and CODEC.validate_gameplay_snapshot(full), "receipt gameplay composes into save snapshot")
	var save_id := Crypto.new().generate_random_bytes(16).hex_encode()
	var encoded := CODEC.encode(full,save_id)
	var decoded: Dictionary = CODEC.decode(encoded)
	check(decoded.ok and int(decoded.envelope.schema_version) == 4, "receipt gameplay with storage writes schema four")
	check(CODEC.canonical(decoded.envelope.snapshot) == CODEC.canonical(full), "schema four roundtrip preserves receipt journal")

	var legacy_v3_gameplay: Dictionary = saved.duplicate(true)
	legacy_v3_gameplay.erase("storage")
	var legacy_v3_full: Dictionary = CODEC.compose_gameplay_snapshot(identity,legacy_v3_gameplay)
	var legacy_v3_decoded: Dictionary = CODEC.decode(CODEC.encode(legacy_v3_full,Crypto.new().generate_random_bytes(16).hex_encode()))
	check(legacy_v3_decoded.ok and int(legacy_v3_decoded.envelope.schema_version) == 3 and legacy_v3_decoded.envelope.snapshot.gameplay.has("command_journal"), "schema three remains readable and migrates storage at runtime")
	var legacy_gameplay: Dictionary = legacy_v3_gameplay.duplicate(true)
	legacy_gameplay.erase("command_journal")
	var legacy_full: Dictionary = CODEC.compose_gameplay_snapshot(identity,legacy_gameplay)
	var legacy_encoded := CODEC.encode(legacy_full,Crypto.new().generate_random_bytes(16).hex_encode())
	var legacy_decoded: Dictionary = CODEC.decode(legacy_encoded)
	check(legacy_decoded.ok and int(legacy_decoded.envelope.schema_version) == 2 and not legacy_decoded.envelope.snapshot.gameplay.has("command_journal"), "schema two remains readable without fabricated receipts")

	var tampered: Dictionary = decoded.envelope.duplicate(true)
	tampered.snapshot.gameplay.command_journal.receipts[0].fingerprint = "bad"
	tampered.erase("checksum")
	tampered["checksum"] = CODEC.canonical(tampered).sha256_text()
	check(CODEC.decode(CODEC.canonical(tampered)).error_code == "SAVE_SNAPSHOT_INVALID", "recomputed checksum cannot bless invalid receipt")

	var store := STORE.new()
	store.directory = "user://receipt_save_"+Crypto.new().generate_random_bytes(8).hex_encode()
	var written: Dictionary = store.write_new(full)
	check(written.ok, "schema four uses atomic store")
	if written.ok:
		var read: Dictionary = store.read_save(written.save_id)
		check(read.ok and CODEC.canonical(read.envelope.snapshot) == CODEC.canonical(full), "atomic store reads receipt journal unchanged")
		var imported: Dictionary = store.confirm_import(read.envelope)
		check(imported.ok, "schema four import creates independent local save")
		if imported.ok:
			var imported_read: Dictionary = store.read_save(imported.save_id)
			check(imported_read.ok and imported_read.envelope.snapshot.session_id != full.session_id, "import creates new session identity")
			check(imported_read.ok and imported_read.envelope.snapshot.gameplay.command_journal.receipts.is_empty(), "import clears source-session idempotency receipts")

	finish()

func finish() -> void:
	print("RECEIPT_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
