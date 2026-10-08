extends RefCounted
## Resident knowledge admission boundary. Facts are owned by CORE; this state
## only decides whether a resident may learn an event and owns subjective
## summaries that cite already-known facts.

const MAX_SUMMARIES_PER_RESIDENT := 64
const MAX_SUMMARY_TEXT := 512
const ACQUISITION_EXPERIENCED := "experienced"
const ACQUISITION_OBSERVED := "observed"

var configuration_error := ""
var _runtime: RefCounted
var _summaries: Dictionary = {}

func _init(runtime_state: RefCounted = null) -> void:
	_runtime = runtime_state
	if _runtime == null or not _runtime.has_method("knows_event") or not _runtime.has_method("add_known_events") or not _runtime.has_method("projection"):
		configuration_error = "RESIDENT_KNOWLEDGE_RUNTIME_INVALID"

func is_configured() -> bool:
	return configuration_error.is_empty()

func learn_from_fact(resident_id: String, fact: Variant, acquisition: String) -> Dictionary:
	if not is_configured():
		return _failure("RESIDENT_KNOWLEDGE_NOT_CONFIGURED")
	var valid: Dictionary = _validate_fact_for(resident_id,fact,acquisition)
	if not valid.ok:
		return valid
	var learned: Dictionary = _runtime.add_known_events(resident_id,[String(fact.event_id)])
	return learned

func learn_from_command_result(resident_id: String, result: Variant, facts_by_id: Variant, acquisition: String) -> Dictionary:
	if not is_configured():
		return _failure("RESIDENT_KNOWLEDGE_NOT_CONFIGURED")
	if not (result is Dictionary) or not result.has("ok") or not result.has("has_changes") or not result.has("event_ids"):
		return _failure("RESIDENT_KNOWLEDGE_RESULT_INVALID")
	if not (result.ok is bool) or not (result.has_changes is bool) or not (result.event_ids is Array):
		return _failure("RESIDENT_KNOWLEDGE_RESULT_INVALID")
	if not result.ok or not result.has_changes:
		return _failure("RESIDENT_KNOWLEDGE_SOURCE_NOT_SUCCESSFUL")
	if result.event_ids.is_empty() or not (facts_by_id is Dictionary):
		return _failure("RESIDENT_KNOWLEDGE_SOURCE_EMPTY")
	var ids: Array[String] = []
	for event_id: Variant in result.event_ids:
		if not (event_id is String) or not facts_by_id.has(event_id):
			return _failure("RESIDENT_KNOWLEDGE_FACT_MISSING")
		var fact: Variant = facts_by_id[event_id]
		var valid: Dictionary = _validate_fact_for(resident_id,fact,acquisition)
		if not valid.ok or String(fact.event_id)!=String(event_id):
			return valid if not valid.ok else _failure("RESIDENT_KNOWLEDGE_FACT_MISMATCH")
		ids.append(String(event_id))
	var learned: Dictionary = _runtime.add_known_events(resident_id,ids)
	return learned

func tell_event(teller_id: String, receiver_id: String, event_id: String) -> Dictionary:
	if not is_configured():
		return _failure("RESIDENT_KNOWLEDGE_NOT_CONFIGURED")
	if teller_id==receiver_id or event_id.is_empty() or event_id.length()>128:
		return _failure("RESIDENT_KNOWLEDGE_TELL_INVALID")
	if not _runtime.knows_event(teller_id,event_id):
		return _failure("RESIDENT_KNOWLEDGE_TELLER_UNKNOWN")
	var learned: Dictionary = _runtime.add_known_events(receiver_id,[event_id])
	return learned

func record_summary(resident_id: String, summary_id: String, summary_text: String, source_event_ids: Array, updated_at_game_minute: int) -> Dictionary:
	if not is_configured():
		return _failure("RESIDENT_KNOWLEDGE_NOT_CONFIGURED")
	if summary_id.is_empty() or summary_id.length()>128 or summary_text.is_empty() or summary_text.length()>MAX_SUMMARY_TEXT or updated_at_game_minute<0:
		return _failure("RESIDENT_SUMMARY_INVALID")
	if source_event_ids.is_empty():
		return _failure("RESIDENT_SUMMARY_SOURCE_EMPTY")
	var seen: Dictionary = {}
	for event_id: Variant in source_event_ids:
		if not (event_id is String) or event_id.is_empty() or event_id.length()>128 or seen.has(event_id):
			return _failure("RESIDENT_SUMMARY_SOURCE_INVALID")
		if not _runtime.knows_event(resident_id,event_id):
			return _failure("RESIDENT_SUMMARY_SOURCE_UNKNOWN")
		seen[event_id]=true
	var rows: Dictionary = _summaries.get(resident_id,{})
	if not rows.has(summary_id) and rows.size()>=MAX_SUMMARIES_PER_RESIDENT:
		return _failure("RESIDENT_SUMMARY_FULL")
	var row: Dictionary = {
		"resident_id":resident_id,
		"summary_id":summary_id,
		"summary_text":summary_text,
		"source_event_ids":source_event_ids.duplicate(),
		"updated_at_game_minute":updated_at_game_minute
	}
	var changed: bool = not rows.has(summary_id) or rows[summary_id]!=row
	rows[summary_id]=row
	_summaries[resident_id]=rows
	return {"ok":true,"error_code":"","has_changes":changed,"summary":row.duplicate(true)}

func projection() -> Dictionary:
	var rows: Array = []
	var resident_ids: Array = _summaries.keys()
	resident_ids.sort()
	for resident_id: Variant in resident_ids:
		var summaries: Dictionary = _summaries[resident_id]
		var summary_ids: Array = summaries.keys()
		summary_ids.sort()
		for summary_id: Variant in summary_ids:
			rows.append(summaries[summary_id].duplicate(true))
	return {"summaries":rows}

func _validate_fact_for(resident_id: String, fact: Variant, acquisition: String) -> Dictionary:
	if acquisition not in [ACQUISITION_EXPERIENCED,ACQUISITION_OBSERVED]:
		return _failure("RESIDENT_KNOWLEDGE_ACQUISITION_INVALID")
	if not _valid_fact(fact):
		return _failure("RESIDENT_KNOWLEDGE_FACT_INVALID")
	if acquisition==ACQUISITION_EXPERIENCED and resident_id not in fact.participant_ids:
		return _failure("RESIDENT_KNOWLEDGE_NOT_PARTICIPANT")
	if acquisition==ACQUISITION_OBSERVED:
		var runtime_row: Dictionary = _runtime_row(resident_id)
		if runtime_row.is_empty() or String(runtime_row.space_id)!=String(fact.space_id):
			return _failure("RESIDENT_KNOWLEDGE_NOT_OBSERVER")
	return {"ok":true,"error_code":"","has_changes":false}

func _runtime_row(resident_id: String) -> Dictionary:
	var projection: Dictionary = _runtime.projection()
	for row: Variant in projection.residents:
		if row is Dictionary and String(row.get("resident_id",""))==resident_id:
			return row
	return {}

func _valid_fact(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	for key: String in ["event_id","kind","space_id","game_minute","participant_ids","payload"]:
		if not value.has(key):
			return false
	if not (value.event_id is String) or value.event_id.is_empty() or value.event_id.length()>128:
		return false
	if not (value.kind is String) or value.kind.is_empty():
		return false
	if not (value.space_id is String) or not String(value.space_id).begins_with("space."):
		return false
	if not (value.game_minute is int) or value.game_minute<0:
		return false
	if not (value.participant_ids is Array) or not (value.payload is Dictionary):
		return false
	var participants: Dictionary = {}
	for actor_id: Variant in value.participant_ids:
		if not (actor_id is String) or actor_id.is_empty() or participants.has(actor_id):
			return false
		participants[actor_id]=true
	if not value.has("source_command_id"):
		return false
	var command_source_ok: bool = value.source_command_id is String and not value.source_command_id.is_empty()
	var system_source_ok: bool = value.has("source_system") and value.source_system is String and not value.source_system.is_empty()
	if value.source_command_id==null:
		return system_source_ok
	return command_source_ok

func _failure(code: String) -> Dictionary:
	return {"ok":false,"error_code":code,"has_changes":false}
