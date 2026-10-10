# Village courtyard and visible entrances

2026-10-08 cloud continuation of Issue84; this is a further candidate, not user acceptance.

- Keep the four existing house instance names, move them into visible side bands. Reposition the six existing stalls around connected courtyards instead of one empty row. Preserve the x608–672 main pedestrian lane, all functional anchors, NPC IDs and TerrainGround (1280×640) bytes/extent.
- Trim only PlazaStone cells into linked courts and paths. The approved map's town grouping and low central water feature guide this arrangement; it is not a replica of the concept image.
- Shop uses the existing native blue-roof facade above its original 160×96 solid. Workshop retains the northern approach at (520,216), with an original LibreSprite north-open courtyard assembled from the existing 1:1 tool bench plus deliberate timber/stone pixels. The workshop solid remains its original 144×96; no false south-facing doorway.
- Add an independent low open basin variant from the existing well's stone ring/water in native LibreSprite, keeping the original well unchanged. No resampling, whole-map generation or new paid PixelLab job. Editable source, rebuild JS, PNG and metadata are committed.

Native Godot map capture: exit 0, all three requested sizes; 1366 filenames describe the actual 1280×720 content. Manual 1366×768 whole-window screenshots record actual keyboard approach, workshop entry/return, shop entry/return, and farm return. The manual run exposed an existing coincident resident/player arrival physics defect inside both interiors; that is being fixed separately and this evidence does not claim it was absent.

The pre-occupancy-fix serial regression passed: frontage49, playability454, editability68, anchor coverage, world layout, shop/workshop routes, resident space handoff/motion, door transition and historical save. The initial frontage fixture expected stale height656; actual old and new TerrainGround both have40 rows (640px). Its corrected 49/0 log and initial failure are retained. The low basin changes only native art at the same radius16 footprint. Final post-occupancy regression remains required before completion.

Commands use pinned Godot 4.7.2 with isolated writable HOME/XDG: `--headless --path game --script res://tests/<name>_test.gd`; native capture uses `--rendering-method gl_compatibility --audio-driver Dummy --script res://tests/chapter1_map_native_capture.gd -- <output>`. Native capture exit0, only cloud unsupported V-Sync warning. Interiors still have diagnostic artwork; residents still diagnostic glyphs. These are disclosed unfinished visual differences.
