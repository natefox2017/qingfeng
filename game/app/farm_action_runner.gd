extends RefCounted
## Engineering fallback for prepare -> contact -> recover farm actions.
## Accepted character animations will replace the fixed phase durations, but the
## contact event remains the only point allowed to submit the prepared command.

const PREPARE_SECONDS := 0.12
const RECOVER_SECONDS := 0.12

var _phase := ""
var _elapsed := 0.0
var _command: Dictionary = {}
var _plot_id := ""
var _label := ""

func is_busy() -> bool:
	return not _phase.is_empty()

func is_before_contact() -> bool:
	return _phase == "prepare"

func begin(command: Dictionary, plot_id: String, label: String) -> bool:
	if is_busy() or command.is_empty() or plot_id.is_empty():
		return false
	_phase = "prepare"
	_elapsed = 0.0
	_command = command.duplicate(true)
	_plot_id = plot_id
	_label = label
	return true

func cancel_before_contact() -> bool:
	if not is_before_contact():
		return false
	_clear()
	return true

func advance(delta: float) -> Dictionary:
	if delta < 0.0:
		return {"event":"invalid"}
	if not is_busy():
		return {"event":"none"}
	_elapsed += delta
	if _phase == "prepare" and _elapsed >= PREPARE_SECONDS:
		_elapsed -= PREPARE_SECONDS
		_phase = "recover"
		return {
			"event":"contact",
			"command":_command.duplicate(true),
			"plot_id":_plot_id,
			"label":_label
		}
	if _phase == "recover" and _elapsed >= RECOVER_SECONDS:
		var label := _label
		_clear()
		return {"event":"finished","label":label}
	return {"event":"none"}

func projection() -> Dictionary:
	return {
		"is_busy":is_busy(),
		"phase":_phase,
		"plot_id":_plot_id,
		"label":_label
	}

func _clear() -> void:
	_phase = ""
	_elapsed = 0.0
	_command.clear()
	_plot_id = ""
	_label = ""
