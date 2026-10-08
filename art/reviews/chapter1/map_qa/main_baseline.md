# Main baseline only — new WORLD map NOT accepted

Tested 2026-10-08 Asia/Shanghai. Worktree `/Users/apple/.codex/worktrees/b2b8/qingfeng`, branch `codex/issue-104-map-qa`; starting main/HEAD `a871fdb2f18eea1f9208dcb6c478823677966460`, clean checkout. Remote verified `https://github.com/natefox2017/qingfeng.git`. Local engineering contract read at `111fd7b`; no WORLD/ART changes integrated.

Runtime: `/Applications/Godot.app/Contents/MacOS/Godot`, `4.7.2.stable.official.ed1daf0bf`.
Import command: `$GODOT --headless --path game --import` (exit 0). No tracked project change. All runtime commands below use `$GODOT --headless --path game --script res://tests/<name>.gd`.

| Script | Exit | Actual result / scope |
| --- | --- | --- |
| chapter1_map_playability_test | 0 | 46 checks, 0 failures; real Input/CharacterBody2D walking from spawn to mature003 and practice004; E contact harvest/till/plant/water; exactly one radish and one consumed seed; farm↔house, farm↔village, village↔shop/workshop; east and west bridge travel, west input blocked by river outside bridge; save/read restores harvested item and watered004. |
| chapter1_map_editability_test | 1 | 10 checks, 2 failures, preserved below. Single erased cell and 4×4 extension survive PackedScene save/reload and runtime ready; separate ground/detail layers present. Copy saved ONLY to untracked root `.tmp/map-qa/edited_farm.tscn`. |
| full_economy_loop_test (existing, unchanged) | 0 | 35 checks, 0 failures; three-day004 crop/seed amounts, configured buy/sell/rebuy prices, home chest transfers, sleep settlement, schema7 save/read/restart. This existing suite teleports at contact/door points and is NOT evidence of walkable paths. |
| world_layout_test (existing, unchanged) | 0 | 31 checks, 0 failures; farm/house anchors, six plots, footprint/tree/river shape queries. |
| door_transition_test (existing, unchanged) | 0 | 20 checks, 0 failures; transition cancellation, bad target rollback, house save/reload, repeated swaps. Teleport fixture is separate from input-driven route. |

## Exact editability failures

1. `independent object scene owns collision`: main farm has no independent Node2D PackedScene instance (excluding CharacterBody2D) containing CollisionShape2D. The current scan therefore cannot exercise instance translation, owned markers or moved collision persistence. It does NOT accept moving a separately authored sprite and collider together as object ownership. It currently examines the first qualifying instance only; it is not a whole-object inventory.
2. `runtime bounds include expanded block`: TerrainGround before edit covers 96×64 cells. Test adds source-compatible cells `(96..99, 10..13)`, saves/reloads, verifies persistence, then checks `get_world_bounds().has_point(Vector2i(layer.map_to_local(Vector2i(99,13))))`. Cell `(99,13)` center is `(1592,216)`; main world bounds remain `Rect2i(0,0,1536,1024)`, so actual runtime extent fails. Persistence alone does not prove camera/perimeter/walkability extension.

Neither assertion removed or weakened. WORLD owns the implementation fix. New independent objects with markers will also be checked for translation ownership and persistence when present.

## Limits and review state

- First playability run reached the route but test reload failed because this test disabled app processing and omitted restoring it before loading; it then accessed a null session and did not finish. Corrected test re-enables processing and guards loading. Final rerun exit0 is the result above; initial attempt is not counted as passing.
- Native `chapter1_map_native_capture.gd` prepared for real renderer framebuffer capture at 640×360/1280×720/1920×1080 of farm and village scenes. Headless invocation intentionally rejected with exit2. No native render/capture, human playthrough, UI/art approval, production/export/provider/performance acceptance claimed. No foreground control taken. Captures are scene-render evidence only, not gameplay or navigation proof.
- Native command when foreground is available: `$GODOT --path game --script res://tests/chapter1_map_native_capture.gd -- <absolute evidence output directory>`.
- Route uses bounded axis-aligned waypoint walking at existing stable anchors, not a general navigation algorithm; new map must rerun same baseline. All eight existing door commands covered; R01–R09 full exploration, forest/hill/pier content and every object/collider remain unverified.
- GitHub preflight: Discussions disabled; open PR114/115/116 have no reviews or Review Threads, repository-policy SKIPPED; latest runs inspected. PR file sets are contract docs/source index, audio manifest and title UI, outside QA writes. Issue104 and Issue1 read live; QA claim posted to104. No PR opened/pushed/merged, no Issue closed or boxes checked.
- Await WORLD exact commit from coordinator before integration run. These logs prove main baseline only.

Official API references checked: https://docs.godotengine.org/en/4.7/classes/class_packedscene.html (owned nodes saved via pack); https://docs.godotengine.org/en/4.7/classes/class_tilemaplayer.html (authored cell access/editing). Documentation is not runtime acceptance evidence.
