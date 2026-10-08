extends RefCounted
## Resident knowledge admission boundary. Facts are owned by CORE FactEventLog;
## this state only decides whether a resident may learn an event and owns
## subjective summaries that cite already-known facts.

const MAX_SUMMARIES_PER_RESIDENT := 64
const MAX_SUMMARY_TEXT := 512
const ACQUISITION_EXPERIENCED := "experienced"
const ACQUISITION_OBSERVED := "observed"

var configuration_error := ""
var _runtime: RefCounted
var _facts: RefCounted
var _summaries: Dictionary = {}

func _init(runtime_state: RefCounted = null, fact_log: RefCounted = null) -> void:
	_runtime = runtime_state
	_facts = fact_log
	if _runtime == null or not _runtime.has_method("knows_event") or not _runtime.has_method("add_known_events") or not _runtime.has_method("projection"):
		configuration_error = "RESIDENT_KNOWLEDGE_RUNTIME_INVALID"
		return
	if _facts == null or not _facts.has_method("get_event") or not _facts.has_method("has_event"):
		configuration_error = "RESIDENT_KNOWLEDGE_FACT_LOG_INVALID"

func is_configured() -> bool:
	return configuration_error.is_empty()

func learn_event(resident_id: String, event_id: String, acquisition: String) -> Dictionary:
	if not is_configured():
		return _failure("RESIDENT_KNOWLEDGE_NOT_CONFIGURED")
	var fact: Dictionary = _facts.get_event(event_id)
	if fact.is_empty():
		return _failure("RESIDENT_KNOWLEDGE_FACT_MISSING")
	var valid: Dictionary = _validate_fact_for(resident_id,fact,acquisition)
	if not valid.ok:
		return valid
	var learned: Dictionary = _runtime.add_known_events(resident_id,[event_id])
	return learned

func learn_from_command_result(resident_id: String, result: Variant, acquisition: String) -> Dictionary:
	if not is_configured():
		return _failure("RESIDENT_KNOWLEDGE_NOT_CONFIGURED")
	if not (result is Dictionary) or not result.has("ok") or not result.has("has_changes") or not result.has("event_ids"):
		return _failure("RESIDENT_KNOWLEDGE_RESULT_INVALID")
	if not (result.ok is bool) or not (result.has_changes is bool) or not (result.event_ids is Array):
		return _failure("RESIDENT_KNOWLEDGE_RESULT_INVALID")
	if not result.ok or not result.has_changes:
		return _failure("RESIDENT_KNOWLEDGE_SOURCE_NOT_SUCCESSFUL")
	if result.event_ids.is_empty():
		return _failure("RESIDENT_KNOWLEDGE_SOURCE_EMPTY")
	var ids: Array[String] = []
	for event_id: Variant in result.event_ids:
		if not (event_id is String):
			return _failure("RESIDENT_KNOWLEDGE_FACT_MISSING")
		var fact: Dictionary = _facts.get_event(String(event_id))
		if fact.is_empty():
			return _failure("RESIDENT_KNOWLEDGE_FACT_MISSING")
		var valid: Dictionary = _validate_fact_for(resident_id,fact,acquisition)
		if not valid.ok:
			return valid
		ids.append(String(event_id))
	var learned: Dictionary = _runtime.add_known_events(resident_id,ids)
	return learned

func tell_event(teller_id: String, receiver_id: String, event_id: String) -> Dictionary:
	if not is_configured():
		return _failure("RESIDENT_KNOWLEDGE_NOT_CONFIGURED")
	if teller_id==receiver_id or event_id.is_empty() or event_id.length()>128:
		return _failure("RESIDENT_KNOWLEDGE_TELL_INVALID")
	if not _facts.has_event(event_id):
		return _failure("RESIDENT_KNOWLEDGE_FACT_MISSING")
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
		if not _facts.has_event(String(event_id)) or not _runtime.knows_event(resident_id,String(event_id)):
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

func _validate_fact_for(resident_id: String, fact: Dictionary, acquisition: String) -> Dictionary:
	if acquisition not in [ACQUISITION_EXPERIENCED,ACQUISITION_OBSERVED]:
		return _failure("RESIDENT_KNOWLEDGE_ACQUISITION_INVALID")
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

func _failure(code: String) -> Dictionary:
	return {"ok":false,"error_code":code,"has_changes":false}
