extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const SESSION = preload("res://app/gameplay_session.gd")
const CODEC = preload("res://persistence/session_codec.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL forage ",label)

func collect_command(id:String, session, spot_id:String) -> Dictionary:
	return {
		"protocol_version":1,
		"command_id":id,
		"session_id":"session.forage",
		"actor_id":"actor.player",
		"action":"forage.collect",
		"expected_revision":session.forage.revision,
		"payload":{
			"spot_id":spot_id,
			"inventory_revision":session.inventory.revision
		}
	}

func definitions() -> Array:
	return [
		{"spot_id":"forage.village.001","space_id":"space.village","forage_id":"forage.wild_herb"},
		{"spot_id":"forage.village.002","space_id":"space.village","forage_id":"forage.wild_herb"}
	]

func _initialize() -> void:
	var loaded: Dictionary = CONTENT.load_current()
	check(loaded.ok,"content loads")
	if not loaded.ok:
		finish()
		return
	var content: Dictionary = loaded.data
	check(content.items["item.wild_herb"].sell_price==10 and content.forage.types["forage.wild_herb"].respawn_days==1,"recovery forage balance comes from content version")

	var plots := [{"plot_id":"plot.forage.001","space_id":"space.farm","cell_position":{"x":17,"y":7}}]
	var session = SESSION.new(plots,content,definitions())
	check(session.is_configured() and session.forage.has_spots(),"gameplay session owns village forage state")
	var initial: Dictionary = session.projection().forage
	check(initial.spots.size()==2 and initial.spots[0].is_available and initial.spots[1].is_available,"both recovery spots start available on day one")

	var first_command := collect_command("forage-first",session,"forage.village.001")
	var first: Dictionary = session.execute(first_command)
	check(first.ok and session.inventory.quantity_of("item.wild_herb")==1,"collect atomically adds configured forage item")
	check(not session.projection().forage.spots[0].is_available,"collected spot becomes unavailable for current day")
	var revision_after: int = session.forage.revision
	var replay: Dictionary = session.execute(first_command)
	check(replay==first and session.inventory.quantity_of("item.wild_herb")==1 and session.forage.revision==revision_after,"same collect command replays without duplicate pickup")
	var duplicate: Dictionary = session.execute(collect_command("forage-again",session,"forage.village.001"))
	check(not duplicate.ok and duplicate.error_code=="FORAGE_ALREADY_COLLECTED" and session.inventory.quantity_of("item.wild_herb")==1,"new command cannot harvest same spot twice in one day")

	var saved: Dictionary = session.snapshot()
	check(saved.has("forage") and saved.forage.spots[0].last_collected_day==1,"snapshot persists collected day")
	var restored = SESSION.new(plots,content,definitions())
	check(restored.restore(saved) and not restored.projection().forage.spots[0].is_available,"restore keeps same-day forage unavailable")
	var before_bad: Dictionary = restored.snapshot()
	var bad: Dictionary = saved.duplicate(true)
	bad.forage.spots[0].last_collected_day=99
	check(not restored.restore(bad) and restored.snapshot()==before_bad,"future forage collection day cannot partially restore session")

	check(restored.rest_to_next_day().ok and restored.clock.current_day()==2,"single clock advances to next day")
	check(restored.projection().forage.spots[0].is_available,"daily forage respawns from persisted last-collected day")
	var day_two: Dictionary = restored.execute(collect_command("forage-day-two",restored,"forage.village.001"))
	check(day_two.ok and restored.inventory.quantity_of("item.wild_herb")==2,"same stable spot can be collected again next day")

	var full = SESSION.new(plots,content,definitions())
	check(full.inventory.add("item.radish_seed",95).ok and full.inventory.add("item.radish",99*9).ok,"test fills all twelve inventory slots")
	var full_before: Dictionary = full.projection().forage
	var full_collect: Dictionary = full.execute(collect_command("forage-full",full,"forage.village.002"))
	check(not full_collect.ok and full_collect.error_code=="INVENTORY_FULL" and full.projection().forage==full_before,"full backpack leaves forage spot untouched")

	var identity: Dictionary = CODEC.new_snapshot("小禾","阿豆")
	identity.space_id="space.village"
	identity.world_position_px={"x":184.0,"y":172.0}
	var full_save: Dictionary = CODEC.compose_gameplay_snapshot(identity,saved)
	var decoded: Dictionary = CODEC.decode(CODEC.encode(full_save,Crypto.new().generate_random_bytes(16).hex_encode()))
	check(decoded.ok and int(decoded.envelope.schema_version)==5,"forage state upgrades full gameplay save to schema five")
	check(decoded.envelope.snapshot.gameplay.forage.spots[0].last_collected_day==1,"schema-five roundtrip preserves forage collection state")

	var legacy_v4: Dictionary = saved.duplicate(true)
	legacy_v4.erase("forage")
	var legacy_save: Dictionary = CODEC.compose_gameplay_snapshot(identity,legacy_v4)
	var legacy_decoded: Dictionary = CODEC.decode(CODEC.encode(legacy_save,Crypto.new().generate_random_bytes(16).hex_encode()))
	check(legacy_decoded.ok and int(legacy_decoded.envelope.schema_version)==4,"schema four remains readable without fabricated forage state")
	var migrated = SESSION.new(plots,content,definitions())
	check(migrated.restore(legacy_decoded.envelope.snapshot.gameplay) and migrated.projection().forage.spots.all(func(spot): return spot.is_available),"legacy schema-four restore migrates to fresh daily forage spots")

	var wrong_defs := [{"spot_id":"forage.village.999","space_id":"space.village","forage_id":"forage.wild_herb"}]
	var mismatch = SESSION.new(plots,content,wrong_defs)
	check(not mismatch.restore(saved),"forage restore cannot move or replace WORLD-owned spot ids")

	finish()

func finish() -> void:
	print("FORAGE_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
