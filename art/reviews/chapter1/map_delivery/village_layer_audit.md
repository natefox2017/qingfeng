# Village TileMapLayer audit

Date: 2026-10-09
Audited base: PR #117 head `cd713905fb11a103b014dc5f7339e8e3049489c6`
Local audit branch: `codex/village-layer-audit`
Scope: `game/world/village_first_screen.tscn`, the village-specific regression test, and this report.

## Finding

`@TileMapLayer@2` and `@TileMapLayer@3` are redundant serialized leftovers. Godot 4.7.2 loaded both with their assigned `res://assets/chapter1/terrain/farm_world_tileset.tres`, but each had **zero used cells** (`get_used_cells()` returned an empty array and `get_used_rect()` returned `[P: (0, 0), S: (0, 0)]`). Each layer had `collision_enabled=true`, but no tile cell could render or contribute tile collision. Neither overlapped any authored layer. They had no semantic name or content for future editing, and did not affect the world bounds, camera limits, perimeter collision, or scene appearance. Their serialized `tile_map_data` consists only of empty-cell records.

The minimum fix removes those two nodes. Existing named layers remain intact, including the currently empty `GroundDetails` plane. No `TerrainGround`, `GroundPaths`, `PlazaStone`, `TownDetails`, object, anchor, boundary, camera, or gameplay data was changed.

## Runtime inventory before removal

Cold-loaded the scene by Godot 4.7.2, instantiated it, and enumerated every remaining used cell as `(layer, x, y, source_id, atlas_x, atlas_y, alternative_id)` into `.tmp/village-layer-audit/cell_inventory_after.tsv` (4,242 records). The before-removal log records both anonymous layers as empty and records their zero overlap with every existing layer. The full cell inventory and engine logs remain local and untracked.

| Layer | TileSet | Used cells | Cell rectangle | Cell identities |
| --- | --- | ---: | --- | --- |
| `TerrainGround` | `farm_world_tileset.tres` | 3,200 | `(0,0) 80×40` | source 0 atlas `(0,0)`: 3,192; `(1,0)`: 4; `(2,0)`: 4 |
| `GroundPaths` | `farm_world_tileset.tres` | 273 | `(19,4) 39×37` | source 1 atlas `(0,0)`: 273 |
| `PlazaStone` | `plaza_tileset.tres` | 765 | `(18,8) 45×17` | source 0 atlas `(0,0)`: 765 |
| `TownDetails` | `farm_world_tileset.tres` | 4 | `(8,12) 63×19` | source 2 atlas `(0,0)`: 2; `(2,0)`: 2 |
| `GroundDetails` | `farm_world_tileset.tres` | 0 | empty | none; named layer retained |
| `@TileMapLayer@2` | `farm_world_tileset.tres` | 0 | empty | none; removed |
| `@TileMapLayer@3` | `farm_world_tileset.tres` | 0 | empty | none; removed |

Ground intentionally lies beneath paths and plaza stone: overlaps were 270 cells for `TerrainGround`/`GroundPaths`, 765 for `TerrainGround`/`PlazaStone`, and 163 for `GroundPaths`/`PlazaStone`. `TownDetails` had 4 cells coinciding with `TerrainGround`. The two anonymous layers had **zero overlap with each other or any of the five named layers**. This distinguishes intended base-ground overlays from duplicated content.

The active `village_first_screen.gd` bounds source is `TerrainGround` only. Its cell extent is `[P: (0,0), S: (80,40)]`, corresponding to pixel bounds `1280×640`; after the scene enters the tree, the camera limits are `(0,0)-(1280,640)` and the four perimeter shapes use the same `1280×640` extent. Since the removed layers have no used cells and are not consulted by bounds logic, their removal cannot change the authored extent or collision.

## Verification

Godot binary: `/Applications/Godot.app/Contents/MacOS/Godot`, version `4.7.2.stable.official.ed1daf0bf`. All full logs and outputs are under `.tmp/village-layer-audit/` (not committed).

| Command | Exit | Log/output |
| --- | ---: | --- |
| `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --editor --import --quit` | 0 | `cold_import_after.log` |
| `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/village_tile_layer_audit_test.gd` | 0 | `village_tile_layer_audit_test.log` — 12 checks, 0 failures |
| `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/world_layout_test.gd` | 0 | `world_layout_test.log` — 35 checks, 0 failures |
| `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/chapter1_map_editability_test.gd` | 0 | `chapter1_map_editability_test.log` — 56 checks, 0 failures |
| `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://../.tmp/village-layer-audit/inspect_layers.gd` | 0 | `layer_inventory_after.log`, `cell_inventory_after.tsv` (SHA-256 `55fafaf1de03a01ef87de7e03deffb766cc1f0a4fa2a8b566a42979db1e9cff3`) |
| `/Applications/Godot.app/Contents/MacOS/Godot --path game --script res://tests/chapter1_map_native_capture.gd -- /Users/apple/.codex/worktrees/6b23/qingfeng/.tmp/village-layer-audit/screenshots` | 0 | `native_capture.log`; native renderer captured `space_village_640.png`, `space_village_1280.png`, `space_village_1920.png` (640×360, 1280×720, 1920×1080) and corresponding farm captures |

The new test checks explicit layer semantics, retention of all authored content planes, bounds ownership, camera limits, and all perimeter collision dimensions. Renderer screenshots are evidence of rendering only, not interactive or visual acceptance.

PR #117 remains Draft and open. At audit time GitHub had zero review threads, Discussions were disabled, and `repository-policy` was `SKIPPED`; none is treated as acceptance. This audit does not cover full playable-route QA, pixel scaling/movement, or human comparison against the approved map reference.


## Final-head addendum (2026-10-09, after `4d4b236`)

The cell inventory above is the original audit snapshot from base `cd713905`; its statement that `GroundDetails` had zero cells is historical and was superseded by the map-dressing change. Current `GroundDetails` contains 32 static decoration cells, all using atlas source 2 from `farm_world_tileset.tres`, inside the unchanged `TerrainGround` 80×40 extent. The shared TileSet has zero physics layers, so these tiles add no tile collision. `TownDetails` remains a separate named layer. No anonymous TileMapLayer nodes have returned, and bounds/camera/perimeter collision remain sourced only from `TerrainGround`.

The first audit-test rerun after dressing exited 1 because an earlier assertion required `GroundDetails` to stay empty. The test was updated to require authored in-bounds decoration tiles, no TileSet collision layer, and distinct `GroundDetails` / `TownDetails` semantics. This preserves and expands the audit contract rather than dropping the check.

| Command | Exit | Result / local log |
| --- | ---: | --- |
| `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/village_tile_layer_audit_test.gd` (first run) | 1 | stale empty-layer expectation; `.tmp/map-pr117-final/direct-final/village_tile_layer_audit_test-first-run.log` (captured console output) |
| `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/village_tile_layer_audit_test.gd` (after assertion update) | 0 | 14 checks, 0 failures; `.tmp/map-pr117-final/direct-final/village_tile_layer_audit_test.log` |

The failed first-run console output is retained separately; the corrected run is the saved final log. The final evidence and screenshot status remain proposed, awaiting user visual review.
