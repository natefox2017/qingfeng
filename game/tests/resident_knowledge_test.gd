extends SceneTree

const CONTENT = preload("res://content/content_catalog.gd")
const RUNTIME = preload("res://systems/resident_runtime_state.gd")
const FACTS = preload("res://app/fact_event_log.gd")
const KNOWLEDGE = preload("res://systems/resident_knowledge_state.gd")

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CHECK_FAIL resident_knowledge ",label)

func command_fact(event_id: String, participants: Array, space_id := "space.village", command_id := "cmd.test") -> Dictionary:
	return {
		"event_id":event_id,
		"source_command_id":command_id,
		"source_system":null,
		"kind":"test.fact",
		"space_id":space_id,
		"game_minute":500,
		"participant_ids":participants,
		"payload":{}
	}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var loaded: Dictionary = CONTENT.load_current()
	check(loaded.ok,"content loads")
	if not loaded.ok:
		finish()
		return
	var anchors := [
		{"anchor_id":"anchor.resident.grocer.home","space_id":"space.village","world_position_px":{"x":344.0,"y":240.0}},
		{"anchor_id":"anchor.resident.maker.home","space_id":"space.village","world_position_px":{"x":560.0,"y":176.0}},
		{"anchor_id":"anchor.resident.neighbor.home","space_id":"space.village","world_position_px":{"x":112.0,"y":240.0}}
	]
	var runtime := RUNTIME.new(anchors,loaded.data)
	var facts := FACTS.new()
	var knowledge := KNOWLEDGE.new(runtime,facts)
	check(runtime.is_configured() and facts.is_configured() and knowledge.is_configured(),"knowledge composes around persisted runtime and CORE fact log")

	var harvest := command_fact("event.harvest.001",["resident.neighbor"])
	check(facts.append(harvest).ok,"CORE accepts fact without granting knowledge")
	check(not runtime.knows_event("resident.neighbor","event.harvest.001") and not runtime.knows_event("resident.grocer","event.harvest.001"),"fact existence alone teaches nobody")
	var experienced: Dictionary = knowledge.learn_event("resident.neighbor","event.harvest.001","experienced")
	check(experienced.ok and experienced.has_changes and runtime.knows_event("resident.neighbor","event.harvest.001"),"participant can learn personally experienced fact")
	var repeat: Dictionary = knowledge.learn_event("resident.neighbor","event.harvest.001","experienced")
	check(repeat.ok and not repeat.has_changes and runtime.known_events_for("resident.neighbor").count("event.harvest.001")==1,"relearning same fact is idempotent")
	var false_experience: Dictionary = knowledge.learn_event("resident.maker","event.harvest.001","experienced")
	check(not false_experience.ok and false_experience.error_code=="RESIDENT_KNOWLEDGE_NOT_PARTICIPANT","nonparticipant cannot claim experience")

	var observed: Dictionary = knowledge.learn_event("resident.maker","event.harvest.001","observed")
	check(observed.ok and runtime.knows_event("resident.maker","event.harvest.001"),"explicit same-space observer can learn")
	var remote := command_fact("event.shop.001",["resident.grocer"],"space.shop")
	check(facts.append(remote).ok,"remote fact is valid CORE fact")
	var remote_observe: Dictionary = knowledge.learn_event("resident.maker","event.shop.001","observed")
	check(not remote_observe.ok and remote_observe.error_code=="RESIDENT_KNOWLEDGE_NOT_OBSERVER","other-space resident cannot observe")

	var unsourced := command_fact("event.unsourced",["resident.neighbor"])
	unsourced.source_command_id=null
	check(not facts.append(unsourced).ok and not facts.has_event("event.unsourced"),"CORE rejects fact with no provenance")
	var system_fact := command_fact("event.weather.001",["resident.neighbor"])
	system_fact.source_command_id=null
	system_fact.source_system="world.weather"
	check(facts.append(system_fact).ok and knowledge.learn_event("resident.neighbor","event.weather.001","experienced").ok,"system fact requires explicit source_system")

	var told: Dictionary = knowledge.tell_event("resident.neighbor","resident.grocer","event.harvest.001")
	check(told.ok and runtime.knows_event("resident.grocer","event.harvest.001"),"known fact can be explicitly told")
	var invented_tell: Dictionary = knowledge.tell_event("resident.neighbor","resident.grocer","event.unknown")
	check(not invented_tell.ok and invented_tell.error_code=="RESIDENT_KNOWLEDGE_FACT_MISSING","unlogged fact cannot be told")

	var failed_fact := command_fact("event.failed-success",["resident.grocer"])
	check(facts.append(failed_fact).ok,"failed action fact fixture exists only for result-gate test")
	var failed_result := {"ok":false,"has_changes":false,"event_ids":["event.failed-success"]}
	var failed_learn: Dictionary = knowledge.learn_from_command_result("resident.grocer",failed_result,"experienced")
	check(not failed_learn.ok and failed_learn.error_code=="RESIDENT_KNOWLEDGE_SOURCE_NOT_SUCCESSFUL" and not runtime.knows_event("resident.grocer","event.failed-success"),"failed result cannot create success knowledge")

	var good_a := command_fact("event.batch.a",["resident.neighbor"],"space.village","cmd.batch")
	var good_b := command_fact("event.batch.b",["resident.neighbor"],"space.village","cmd.batch")
	check(facts.append(good_a).ok and facts.append(good_b).ok,"batch facts are committed before knowledge")
	var success_result := {"ok":true,"has_changes":true,"event_ids":["event.batch.a","event.batch.b"]}
	var learned_batch: Dictionary = knowledge.learn_from_command_result("resident.neighbor",success_result,"experienced")
	check(learned_batch.ok and runtime.knows_event("resident.neighbor","event.batch.a") and runtime.knows_event("resident.neighbor","event.batch.b"),"successful result learns all logged facts")

	var atomic_good := command_fact("event.atomic.good",["resident.neighbor"])
	check(facts.append(atomic_good).ok,"atomic-good fact is logged")
	var before_atomic: Array = runtime.known_events_for("resident.neighbor")
	var bad_batch: Dictionary = knowledge.learn_from_command_result(
		"resident.neighbor",
		{"ok":true,"has_changes":true,"event_ids":["event.atomic.good","event.atomic.missing"]},
		"experienced"
	)
	check(not bad_batch.ok and bad_batch.error_code=="RESIDENT_KNOWLEDGE_FACT_MISSING" and runtime.known_events_for("resident.neighbor")==before_atomic,"missing fact rejects whole knowledge batch")

	var summary: Dictionary = knowledge.record_summary(
		"resident.neighbor","summary.harvest","我看见那次收成很顺利。",
		["event.harvest.001","event.batch.a"],520
	)
	check(summary.ok and summary.summary.source_event_ids==["event.harvest.001","event.batch.a"],"summary cites logged known facts")
	check(not runtime.knows_event("resident.neighbor","summary.harvest"),"summary id never masquerades as fact")
	var bad_summary: Dictionary = knowledge.record_summary(
		"resident.neighbor","summary.unknown","我不该知道这个。",["event.never-learned"],521
	)
	check(not bad_summary.ok and bad_summary.error_code=="RESIDENT_SUMMARY_SOURCE_UNKNOWN" and knowledge.projection().summaries.size()==1,"summary cannot cite unknown fact")

	var runtime_snapshot: Dictionary = runtime.snapshot()
	var fact_snapshot: Dictionary = facts.snapshot()
	var restored_runtime := RUNTIME.new(anchors,loaded.data)
	var restored_facts := FACTS.new()
	check(restored_runtime.restore(runtime_snapshot) and restored_facts.restore(fact_snapshot) and restored_facts.known_ids_exist(restored_runtime.known_events_for("resident.neighbor")),"known ids resolve after runtime and fact-log restore")
	var restored_knowledge := KNOWLEDGE.new(restored_runtime,restored_facts)
	check(restored_knowledge.is_configured() and restored_knowledge.projection().summaries.is_empty(),"summaries remain separate transient state")

	finish()

func finish() -> void:
	print("RESIDENT_KNOWLEDGE_PASS checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
