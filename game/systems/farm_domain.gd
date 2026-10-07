extends RefCounted
## Authoritative farm plot state. Layout supplies stable plot ids/cells; crop balance
## comes from content_version. UI/world consume projection copies.

const CONTENT = preload("res://content/content_catalog.gd")

var revision: int = 0
var configuration_error := ""
var plots: Dictionary = {}
var _plot_order: Array[String] = []
var _crops: Dictionary = {}

func _init(plot_definitions: Array = [], content: Dictionary = {}) -> void:
	var source := content
	if source.is_empty():
		var result: Dictionary = CONTENT.load_current()
		if not result.ok:
			configuration_error = result.error_code
			return
		source = result.data
	if not CONTENT.validate(source):
		configuration_error = "CONTENT_INVALID"
		return
	_crops = source.crops.duplicate(true)
	for definition: Variant in plot_definitions:
		if not _valid_definition(definition):
			configuration_error = "FARM_PLOT_DEFINITION_INVALID"
			plots.clear()
			_plot_order.clear()
			return
		var plot_id := String(definition.plot_id)
		if plots.has(plot_id):
			configuration_error = "FARM_PLOT_DUPLICATE"
			plots.clear()
			_plot_order.clear()
			return
		plots[plot_id] = {
			"plot_id":plot_id,
			"space_id":String(definition.space_id),
			"cell_position":{"x":int(definition.cell_position.x),"y":int(definition.cell_position.y)},
			"state":"untilled",
			"crop_id":null,
			"growth_days":0,
			"is_watered":false,
			"last_settled_day":0
		}
		_plot_order.append(plot_id)

func _valid_definition(value: Variant) -> bool:
	if not (value is Dictionary) or value.size() != 3:
		return false
	for key: String in ["plot_id","space_id","cell_position"]:
		if not value.has(key):
			return false
	if not (value.plot_id is String) or String(value.plot_id).is_empty():
		return false
	if not (value.space_id is String) or String(value.space_id).is_empty():
		return false
	var cell: Variant = value.cell_position
	return cell is Dictionary and cell.size() == 2 and cell.has("x") and cell.has("y") and cell.x is int and cell.y is int

func is_configured() -> bool:
	return configuration_error.is_empty() and not plots.is_empty()

func projection() -> Dictionary:
	var ordered: Array = []
	for plot_id: String in _plot_order:
		ordered.append(plots[plot_id].duplicate(true))
	return {"revision":revision,"plots":ordered}

func restore(snapshot_value: Variant) -> bool:
	if not is_configured() or not (snapshot_value is Dictionary):
		return false
	if snapshot_value.size() != 2 or not snapshot_value.has("revision") or not snapshot_value.has("plots"):
		return false
	if not (snapshot_value.revision is int) or snapshot_value.revision < 0:
		return false
	if not (snapshot_value.plots is Array) or snapshot_value.plots.size() != _plot_order.size():
		return false
	var restored: Dictionary = {}
	for index in range(_plot_order.size()):
		var expected_id: String = _plot_order[index]
		var candidate: Variant = snapshot_value.plots[index]
		if not (candidate is Dictionary) or not _valid_plot_state(candidate):
			return false
		if candidate.plot_id != expected_id:
			return false
		var current: Dictionary = plots[expected_id]
		if candidate.space_id != current.space_id or candidate.cell_position != current.cell_position:
			return false
		restored[expected_id] = candidate.duplicate(true)
	plots = restored
	revision = snapshot_value.revision
	return true

func get_plot(plot_id: String) -> Dictionary:
	if not plots.has(plot_id):
		return {}
	return plots[plot_id].duplicate(true)

func _candidate(plot_id: Variant) -> Dictionary:
	if not is_configured():
		return {"ok":false,"error_code":"FARM_NOT_CONFIGURED"}
	if not (plot_id is String) or not plots.has(plot_id):
		return {"ok":false,"error_code":"FARM_PLOT_UNKNOWN"}
	return {"ok":true,"error_code":"","plot":plots[plot_id].duplicate(true)}

func candidate_till(plot_id: Variant) -> Dictionary:
	var result := _candidate(plot_id)
	if not result.ok:
		return result
	if result.plot.state != "untilled":
		return {"ok":false,"error_code":"FARM_NOT_UNTILLED"}
	result.plot.state = "tilled"
	return result

func candidate_plant(plot_id: Variant, crop_id: Variant) -> Dictionary:
	var result := _candidate(plot_id)
	if not result.ok:
		return result
	if result.plot.state != "tilled":
		return {"ok":false,"error_code":"FARM_NOT_TILLED"}
	if not (crop_id is String) or not _crops.has(crop_id):
		return {"ok":false,"error_code":"FARM_CROP_UNKNOWN"}
	result.plot.state = "growing"
	result.plot.crop_id = String(crop_id)
	result.plot.growth_days = 0
	return result

func candidate_water(plot_id: Variant) -> Dictionary:
	var result := _candidate(plot_id)
	if not result.ok:
		return result
	if result.plot.state not in ["tilled","growing"]:
		return {"ok":false,"error_code":"FARM_NOT_WATERABLE"}
	if result.plot.is_watered:
		result["has_changes"] = false
		return result
	result.plot.is_watered = true
	result["has_changes"] = true
	return result

func candidate_harvest(plot_id: Variant) -> Dictionary:
	var result := _candidate(plot_id)
	if not result.ok:
		return result
	if result.plot.state != "mature" or result.plot.crop_id == null:
		return {"ok":false,"error_code":"FARM_NOT_MATURE"}
	var crop_id := String(result.plot.crop_id)
	var crop: Dictionary = _crops[crop_id]
	result["harvest_item_id"] = String(crop.harvest_item_id)
	result["yield_quantity"] = int(crop.yield_quantity)
	result.plot.state = "tilled"
	result.plot.crop_id = null
	result.plot.growth_days = 0
	result.plot.is_watered = false
	return result

func commit_plot(candidate: Dictionary, expected_revision: int) -> bool:
	if expected_revision != revision or not candidate.has("plot_id"):
		return false
	var plot_id := String(candidate.plot_id)
	if not plots.has(plot_id) or not _valid_plot_state(candidate):
		return false
	plots[plot_id] = candidate.duplicate(true)
	revision += 1
	return true

func _valid_plot_state(plot: Dictionary) -> bool:
	var required := ["plot_id","space_id","cell_position","state","crop_id","growth_days","is_watered","last_settled_day"]
	if plot.size() != required.size():
		return false
	for key: String in required:
		if not plot.has(key):
			return false
	if plot.state not in ["untilled","tilled","growing","mature"]:
		return false
	if not (plot.growth_days is int) or plot.growth_days < 0:
		return false
	if not (plot.is_watered is bool) or not (plot.last_settled_day is int) or plot.last_settled_day < 0:
		return false
	if plot.state in ["growing","mature"]:
		return plot.crop_id is String and _crops.has(plot.crop_id)
	return plot.crop_id == null

func settle_day(day: int) -> Dictionary:
	if not is_configured() or day <= 1:
		return {"ok":false,"error_code":"FARM_DAY_INVALID","revision":revision}
	var changed := false
	for plot_id: String in _plot_order:
		var plot: Dictionary = plots[plot_id].duplicate(true)
		if plot.last_settled_day >= day:
			continue
		if plot.state == "growing" and plot.is_watered:
			plot.growth_days += 1
			var required_days := int(_crops[plot.crop_id].growth_days)
			if plot.growth_days >= required_days:
				plot.state = "mature"
		plot.is_watered = false
		plot.last_settled_day = day
		plots[plot_id] = plot
		changed = true
	if changed:
		revision += 1
	return {"ok":true,"error_code":"","has_changes":changed,"revision":revision}
