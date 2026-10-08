extends RefCounted
## Narrow, non-destructive migration from the six-plot map on pre-PR117 main.
## Do not infer that arbitrary mismatched layouts are compatible.
## Original signed saves remain untouched; a new save writes the migrated layout.

const LEGACY_PLOTS = {
	"plot.farm.001": Vector2i(17, 7),
	"plot.farm.002": Vector2i(18, 7),
	"plot.farm.003": Vector2i(19, 7),
	"plot.farm.004": Vector2i(17, 8),
	"plot.farm.005": Vector2i(18, 8),
	"plot.farm.006": Vector2i(19, 8)
}

static func migrate(snapshot: Dictionary, current_plots: Array, resident_anchors: Array, safe_spawn: Vector2) -> Dictionary:
	var unchanged := {"ok":true, "migrated":false, "snapshot":snapshot}
	if not snapshot.has("gameplay") or not (snapshot.gameplay is Dictionary):
		return unchanged
	var gameplay: Dictionary = snapshot.gameplay
	if not gameplay.has("farm") or not (gameplay.farm is Dictionary):
		return unchanged
	var farm: Dictionary = gameplay.farm
	if not farm.has("plots") or not (farm.plots is Array):
		return unchanged
	var saved_plots: Array = farm.plots
	if saved_plots.size() != LEGACY_PLOTS.size() or current_plots.size() != LEGACY_PLOTS.size():
		return unchanged
	var new_positions: Dictionary = {}
	for definition: Variant in current_plots:
		if not (definition is Dictionary) or not definition.has("plot_id") or not definition.has("cell_position"):
			return unchanged
		var id := String(definition.plot_id)
		var cell: Variant = definition.cell_position
		if not LEGACY_PLOTS.has(id) or not (cell is Dictionary) or not cell.has("x") or not cell.has("y") or new_positions.has(id):
			return unchanged
		new_positions[id] = {"x":int(cell.x), "y":int(cell.y)}
	if new_positions.size() != LEGACY_PLOTS.size():
		return unchanged
	var needs_migration := false
	var seen: Dictionary = {}
	for row: Variant in saved_plots:
		if not (row is Dictionary) or not row.has("plot_id") or not row.has("cell_position"):
			return unchanged
		var id := String(row.plot_id)
		var cell: Variant = row.cell_position
		if not LEGACY_PLOTS.has(id) or seen.has(id) or not (cell is Dictionary) or not cell.has("x") or not cell.has("y"):
			return unchanged
		seen[id] = true
		# Migrate ONLY the exact legacy six-marker fingerprint, never a corrupt
		# or partially moved save. Other layouts keep existing strict validation.
		var legacy: Vector2i = LEGACY_PLOTS[id]
		if int(cell.x) != legacy.x or int(cell.y) != legacy.y:
			return unchanged
		if cell != new_positions[id]:
			needs_migration = true
	if seen.size() != LEGACY_PLOTS.size() or not needs_migration:
		return unchanged
	if not safe_spawn.is_finite():
		return {"ok":false, "migrated":false, "snapshot":snapshot, "reason":"MIGRATION_SPAWN_INVALID"}
	var migrated: Dictionary = snapshot.duplicate(true)
	for row: Variant in migrated.gameplay.farm.plots:
		row.cell_position = new_positions[String(row.plot_id)].duplicate(true)

	# PR117 relocates paths, buildings and the village, not only farm plots.
	# A saved outdoor player position has no trustworthy geometric transform.
	# Re-enter at this room's authored safe spawn, preserving the room and facing.
	if String(migrated.get("space_id", "")) in ["space.farm", "space.village"]:
		migrated.world_position_px = {"x":safe_spawn.x, "y":safe_spawn.y}

	# Keep resident identity, relationship, events and current space. Re-anchor
	# villagers to their corresponding authored social markers after the move.
	if migrated.gameplay.has("residents") and migrated.gameplay.residents is Dictionary:
		var residents: Dictionary = migrated.gameplay.residents
		if residents.has("residents") and residents.residents is Array:
			var village_anchors: Dictionary = {}
			for anchor: Variant in resident_anchors:
				if anchor is Dictionary and anchor.has("anchor_id") and String(anchor.get("space_id", "")) == "space.village":
					village_anchors[String(anchor.anchor_id)] = anchor
			for row: Variant in residents.residents:
				if not (row is Dictionary) or String(row.get("space_id", "")) != "space.village":
					continue
				var anchor_id := "anchor.%s.social" % String(row.get("resident_id", ""))
				if not village_anchors.has(anchor_id):
					return {"ok":false, "migrated":false, "snapshot":snapshot, "reason":"MIGRATION_RESIDENT_ANCHOR_MISSING"}
				var anchor: Dictionary = village_anchors[anchor_id]
				row.world_position_px = anchor.world_position_px.duplicate(true)
	return {"ok":true, "migrated":true, "snapshot":migrated}
