extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const CODEC = preload("res://persistence/session_codec.gd")
const FACTS = preload("res://app/fact_event_log.gd")
const SESSION = preload("res://app/gameplay_session.gd")
const FARM = preload("res://world/farm_first_screen.tscn")
const VILLAGE = preload("res://world/village_first_screen.tscn")
const SHOP = preload("res://world/shop_interior.tscn")
const WORKSHOP = preload("res://world/workshop_interior.tscn")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL fact_event_log ",label)

func system_fact(event_id: String, resident_id := "resident.neighbor") -> Dictionary:
	return {
		"event_id":event_id,
		"source_command_id":null,
		"source_system":"conversation.authored",
		"kind":"resident.met_player",
		"space_id":"space.village",
		"game_minute":500,
		"participant_ids":["actor.player",resident_id],
		"payload":{}
	}

func collect_plot_definitions() -> Array:
	var scene := FARM.instantiate()
	var rows: Array = scene.get_plot_definitions()
	scene.free()
	return rows

func collect_forage_definitions() -> Array:
	var scene := VILLAGE.instantiate()
	var rows: Array = scene.get_forage_definitions()
	scene.free()
	return rows

func collect_resident_anchors() -> Array:
	var rows: Array = []
	for packed: PackedScene in [VILLAGE,SHOP,WORKSHOP]:
		var scene := packed.instantiate()
		rows.append_array(scene.get_resident_anchor_definitions())
		scene.free()
	return rows

func new_session() -> RefCounted:
	return SESSION.new(
		collect_plot_definitions(),
		{},
		collect_forage_definitions(),
		collect_resident_anchors()
	)

func identity() -> Dictionary:
	var result: Dictionary = CODEC.new_snapshot("小禾","阿豆")
	result.space_id="space.village"
	result.world_position_px={"x":48.0,"y":180.0}
	result.facing="east"
	return result

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var log := FACTS.new()
	check(log.is_configured(),"fact log configures")
	var first := system_fact("event.meet.neighbor.001")
	var appended: Dictionary = log.append(first)
	check(appended.ok and appended.has_changes and log.revision==1 and log.has_event(first.event_id),"valid fact appends once")
	var replay: Dictionary = log.append(first)
	check(replay.ok and not replay.has_changes and log.revision==1,"same event id and same fact is idempotent")
	var conflict := first.duplicate(true)
	conflict.game_minute=501
	var conflicted: Dictionary = log.append(conflict)
	check(not conflicted.ok and conflicted.error_code=="FACT_EVENT_ID_CONFLICT" and log.revision==1,"same id with different fact conflicts without mutation")

	var bad_source := system_fact("event.bad.source")
	bad_source.source_command_id="cmd.bad"
	var before_bad: Dictionary = log.snapshot()
	check(not log.append(bad_source).ok and log.snapshot()==before_bad,"fact cannot name command and system sources together")
	var missing_source := system_fact("event.missing.source")
	missing_source.source_system=null
	check(not log.append(missing_source).ok and log.snapshot()==before_bad,"fact requires exactly one source")
	var duplicate_participants := system_fact("event.bad.participants")
	duplicate_participants.participant_ids=["actor.player","actor.player"]
	check(not log.append(duplicate_participants).ok,"duplicate participant ids are rejected")
	var deep_payload := system_fact("event.deep.payload")
	deep_payload.payload={"a":{"b":{"c":{"d":{"e":1}}}}}
	check(not log.append(deep_payload).ok,"payload depth is bounded")

	var snap: Dictionary = log.snapshot()
	var restored := FACTS.new()
	check(restored.restore(snap) and restored.get_event(first.event_id)==first,"fact log snapshot roundtrips immutable facts")
	var bad_restore := snap.duplicate(true)
	bad_restore.revision=9
	check(not FACTS.new().restore(bad_restore),"fact log revision must match append-only event count")

	var session: RefCounted = new_session()
	check(session.is_configured(),"gameplay session composes fact log and resident knowledge")
	var session_fact := system_fact("event.meet.neighbor.session")
	check(session.append_fact_event(session_fact).ok,"gameplay session records CORE fact")
	var learned: Dictionary = session.resident_learn_event("resident.neighbor",session_fact.event_id,"experienced")
	check(learned.ok and session.resident_runtime.knows_event("resident.neighbor",session_fact.event_id),"resident learns only a logged fact by id")
	var unknown_learn: Dictionary = session.resident_learn_event("resident.grocer","event.not.logged","observed")
	check(not unknown_learn.ok and not session.resident_runtime.knows_event("resident.grocer","event.not.logged"),"unknown fact id cannot become resident knowledge")

	var full: Dictionary = CODEC.compose_gameplay_snapshot(identity(),session.snapshot())
	check(not full.is_empty() and full.gameplay.fact_events.events.size()==1,"current gameplay snapshot includes persistent fact log")
	var encoded := CODEC.encode(full,"0123456789abcdef0123456789abcdef")
	var decoded: Dictionary = CODEC.decode(encoded)
	check(decoded.ok and int(decoded.envelope.schema_version)==7,"current gameplay save writes schema seven")
	var next: RefCounted = new_session()
	check(next.restore(decoded.envelope.snapshot.gameplay),"schema seven gameplay restores atomically")
	check(next.fact_event(session_fact.event_id)==session_fact and next.resident_runtime.knows_event("resident.neighbor",session_fact.event_id),"schema seven restores facts before known-event references")

	var fresh: RefCounted = new_session()
	var legacy_gameplay: Dictionary = fresh.snapshot()
	legacy_gameplay.erase("fact_events")
	var legacy_full: Dictionary = CODEC.compose_gameplay_snapshot(identity(),legacy_gameplay)
	var legacy_encoded := CODEC.encode(legacy_full,"fedcba9876543210fedcba9876543210")
	var legacy_decoded: Dictionary = CODEC.decode(legacy_encoded)
	check(legacy_decoded.ok and int(legacy_decoded.envelope.schema_version)==6,"schema six with empty resident knowledge remains readable")
	var migrated: RefCounted = new_session()
	check(migrated.restore(legacy_decoded.envelope.snapshot.gameplay) and migrated.fact_events.snapshot().events.is_empty(),"schema six migration initializes an empty fact log")
	var migrated_full: Dictionary = CODEC.compose_gameplay_snapshot(identity(),migrated.snapshot())
	var migrated_encoded := CODEC.encode(migrated_full,"00112233445566778899aabbccddeeff")
	check(CODEC.decode(migrated_encoded).envelope.schema_version==7,"next save after schema six migration upgrades to schema seven")

	var dangling_gameplay: Dictionary = legacy_gameplay.duplicate(true)
	dangling_gameplay.residents.residents[0].known_event_ids.append("event.missing")
	var dangling_full: Dictionary = identity()
	dangling_full["gameplay"]=dangling_gameplay
	var dangling_encoded := CODEC.encode(dangling_full,"ffeeddccbbaa99887766554433221100")
	check(not dangling_encoded.is_empty() and not CODEC.decode(dangling_encoded).ok,"legacy schema six rejects dangling known_event_ids on decode")

	var broken_v7: Dictionary = session.snapshot()
	broken_v7.residents.residents[0].known_event_ids.append("event.not.in.log")
	var broken_full: Dictionary = identity()
	broken_full["gameplay"]=broken_v7
	check(not CODEC.validate_snapshot(broken_full),"schema seven rejects known_event_ids missing from persistent fact log")

	finish()

func finish() -> void:
	print("FACT_EVENT_LOG_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
