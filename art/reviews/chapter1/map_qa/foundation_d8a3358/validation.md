# WORLD foundation d8a3358 — independent runtime validation

This is foundation validation only. Full approved-map R01–R09 layout, final ART/UI approval and release acceptance remain incomplete.

## Exact source and scope

WORLD source `d8a3358a43313c9438dbb3243861d2cd548c8854` was cherry-picked without conflicts into isolated QA branch `codex/issue-104-map-qa`, yielding capture/integration HEAD `01f63b98842dc9e94a87424d2bd7d6933adad755` (parent QA `bfdfa12`). No writes to WORLD's 1cfd worktree. Main remained `a871fdb2f18eea1f9208dcb6c478823677966460`. The enhanced QA runner is the only subsequent runtime-source modification, committed with this evidence; WORLD scene/app/schema/assets were not independently edited. Prior main baseline logs stay separate and do not stand in for this run.

Remote/status/main/docs/#1/#104/open PR/reviews/threads/checks rechecked before integration. Discussions disabled; PR114/115/116 open, Review Threads/reviews absent and checks SKIPPED. No QA PR, no push/merge/Issue closure or checkbox update.

Runtime `/Applications/Godot.app/Contents/MacOS/Godot` version `4.7.2.stable.official.ed1daf0bf`. Import: `$GODOT --headless --path game --import`, exit0; cache-derived missing UID warnings logged in untracked `.tmp/map-qa/foundation/import.log`, no tracked project rewrite.

## Actual engine results

Headless command for each script: `$GODOT --headless --path game --script res://tests/<script>.gd`.

| Script | Exit | Checks/failures |
| --- | --- | --- |
| chapter1_map_playability_test | 0 | 46/0 |
| chapter1_map_editability_test (original bfdfa12) | 0 | 13/0; has skipped post-free object branch, see below |
| chapter1_map_editability_test (enhanced, committed here) | 0 | 52/0 |
| full_economy_loop_test | 0 | 35/0 |
| door_transition_test | 0 | 20/0 |
| world_layout_test | 0 | 31/0 |
| phase0_visual_contract_test | 0 | 32/0; engine resource contract, not human visual signoff |
| village_shop_route_test | 0 | 19/0 |
| workshop_route_test | 0 | 14/0 |

Real Input movement starts at normal fresh-save spawn: reaches003/contact harvest and004 till/plant/water, checks item/seed counts, physically crosses bridge east/west, is stopped by river outside bridge, uses all eight door transitions, saves and reloads harvested item/watered plot. No teleport used as navigation evidence. Economy suite independently covers the full three-day seed/produce trade, configured money, chest atomic transfer, save/restart; its older contact/route teleports remain fixture evidence only.

Enhanced editability performs all changes only on instantiated copies saved in root untracked `.tmp/map-qa/edited_farm.tscn` and `edited_village.tscn`. It erases one authored ground cell and adds4×4, then verifies persistence after ready/reload without runtime cell rebuilding. Farmhouse instance moves(+32,+16); actual PhysicsPoint queries confirm owned body occupies new location and vacates old footprint edge. Both owned door Marker positions follow and survive reload; moved-house resolver returns `door.farm.house`. Camera limits, all four perimeter RectangleShape sizes/positions and real RID hits match expanded bounds. A labeled physics fixture starts near old perimeter and uses real input to cross into new block; it is not a full-map navigation claim. Village's three authored layers, refresh_world_layout, single-cell+expansion save/reload, camera and four physics boundaries are independently checked.

Test correction: original runner checked `object != null` after freeing its source scene, which skipped post-reload object assertions. Enhanced runner captures object presence before freeing, prioritizes Farmhouse, logs every check, and now actually executes saved-position/collision/Marker/resolver checks. The original13/0 is not used to claim those skipped checks passed. No failing main-baseline assertion was deleted or weakened.

## Native evidence and limits

Capture command: `$GODOT --path game --script res://tests/chapter1_map_native_capture.gd -- /Users/apple/.codex/worktrees/b2b8/qingfeng/.tmp/map-qa/foundation/native`.

Actual renderer: OpenGL4.1 Metal Compatibility, Apple M4 Pro. Exit0. Six actual framebuffer PNGs from farm/village at640×360,1280×720,1920×1080; dimensions and SHA256 in native_manifest.json. Viewed1280 captures: farm renders old house/tree/bridge presentation atop new editable foundation; village remains an engineering tile/building-footprint presentation with small repeated grass squares and no final building sprites. These are scene-render screenshots without GameplaySession crop/HUD projection, not approved full-map visuals or gameplay-route proof.

Initial native capture and first route attempt logged `2 ObjectDB instances were leaked` and `1 resources still in use`; original logs retained. QA capture now calls the existing AudioManager.shutdown_audio at start/end and awaits a frame; playability finish also calls shutdown_audio. Final native capture and route reruns exit cleanly without WARNING/ERROR. No shared audio/app change. This does not prove production/export cleanup.

Native route command: `$GODOT --path game --script res://tests/chapter1_map_playability_test.gd`. Final rerun exit0 checks46/failures0, native renderer, no WARNING/ERROR. Same real engine Input route, no continuous focus override. First attempt exit1 checks28/failures1: walk toward shop stopped at(227.2003,180), target(400,164). No focus/collider diagnostic existed in that initial attempt, so cause remains unverified; concurrent-window focus interference is only a hypothesis. Final runner logs enabled/focus-lock/velocity/input-lock/slide-collider on any future walk failure. Successful rerun began before coordinator announced a reserved native window, and completed before releasing the window; it is not evidence of an exclusive human desktop session. Native screenshots were captured independently; no test image is substituted for route evidence.

No manual keyboard playthrough, full map/forest/hill/pier coverage, Godot editor interactive save walkthrough, export, production/provider, performance/FPS or human final-art approval performed. Future WORLD layout commit requires a new exact-SHA run; this result cannot be reused as full layout acceptance.
