# ca7f756 checkpoint — failed/partial validation, paused

WORLD source: ca7f75686e92c129b1ec7f9e61c312ef690ee1f2. Cherry-picked into isolated QA HEAD9474c452182c38c54a7d2ff710cfb19f5904ec27 after prior QA c9d269f. Main fetched/rechecked at a871fdb2f18eea1f9208dcb6c478823677966460. Remote natefox2017/qingfeng. No read/write of WORLD's subsequent uncommitted layout; no changes to core/app/schema/ART authored by QA. This evidence does not describe the newer six-plot positions reported in WORLD chat.

Runtime: Godot4.7.2.stable.official.ed1daf0bf. Command prefix `/Applications/Godot.app/Contents/MacOS/Godot --headless --path game --script res://tests/` followed by each named `.gd` runner. Import `--headless --path game --import` exit0. Results below are real engine execution, not CI/static acceptance.

| Runner | Exit | Checks/failures | Meaning |
| --- | --- | --- | --- |
| chapter1_map_playability_test | 1 | 65/1 | New radius-safe AStarGrid2D fixture and actual Input movement reached001–004 contacts, then failed005 resolver. No teleport as path proof. |
| chapter1_map_editability_test | 1 | 54/4 | Farmhouse move/physics/two Marker checks fail. Reload edits and expanded camera/bounds checks execute; entire suite fails. |
| world_layout_test | 1 | 33/2 | Four-radius plot004/005 collision checks fail. |
| door_transition_test | 0 | 20/0 | Assertions pass, but serious shutdown leaks remain; not clean runtime acceptance. |
| village_shop_route_test | 1 | 19/13 | Existing hard-position route fixture incompatible with relocated entrance; cascading failures, not diagnosed domain bugs. |
| workshop_route_test | 1 | 14/9 | Same outdated hard-position route fixture limitation. |
| full_economy_loop_test | 1 | 35/24 | Old farm-village/contact coordinates incompatible; subsequent trade/farm/chest failures cascade. No new-layout economy acceptance. |

Some old runners print `_PASS` even with failures; exit/failure counts take precedence. Logs preserved without renaming failures as passing.

## Exact failure evidence

- ca7plot004=(480,512). CircleShape2D radius4/mask1 intersects `/root/FarmFirstScreen/FootSorted/YardFenceSouth488/Footprint`, body global(488,506).
- ca7plot005=(768,512). Same query intersects `FieldScarecrow/Footprint`, global(768,508). Real player walked to(766.3969,532.8004), faced north, then resolve_plot_target returned empty; ray toward marker hit `/root/Main/FarmFirstScreen/FootSorted/FieldScarecrow/Footprint` at(768,512).
- Farmhouse root(272,480) has14 children: first seven report empty tree paths, next seven normal root/Farmhouse paths; four Markers total. First discovered CollisionShape2D has empty path/global(220,464). Move instance(+32,+16) to(304,496), await physics: this shape stays(220,464) instead of(252,480). Two empty-path Markers also fail to follow; normal-path Markers follow. This is observed orphan/duplicate subtree evidence, not a speculative fix. Reported directly to WORLD owner under coordinator authorization.
- Serious CanvasItem/ObjectDB/resource/physics RID leaks in all relevant logs. Door suite20/0 logs15340 CanvasItem and15436 ObjectDB instances,63 resources and2628 Body2D RID allocations at exit. No cleanup fix in shared code attempted.

## Existing QA work saved before pause

Only own playability/editability runners changed. Playability now derives plot contacts from stable definitions, bounds from authored map or interior solid geometry, plans an8px Godot AStarGrid2D path with actual player's Circle radius+1 shape clearance and mask, and executes every corner via bounded real Input movement at unchanged4px destination tolerance. Full bridge cross/reverse uses straight input segments between authored bank markers, preventing alternative-bridge detour from substituting for that crossing. Door assertions preserve exact existing5-field dictionary/ID, same gameplay session and target-owned arrival. Own runner contains walked-anchor trade/chest and save/reload quantity/money checks to replace outdated hard positions without editing old tests.

Later stages are NOT executed in this failing run:003 harvest,004 till/plant/water, trade/chest, bridge/river, eight doors and save/reload. RiverBankProbe/RiverBlockedProbe are proposed reader names awaiting WORLD API confirmation/new checkpoint, not frozen schema or implemented scene markers. Script parsing was checked, not claimed as gameplay coverage. New diagnostics and assertions remain intact; no failures deleted or widened.

No native window/capture started on this checkpoint. No final visual, full R01–R09, export, production, human playthrough/editor approval or fresh-layout acceptance. Prior d8 foundation pass is separate and cannot substitute here. No push/PR/merge/Issue closure. GitHub preflight: #104 OPEN, #1 OPEN, Discussions disabled, PR114/115/116 OPEN with no reviews/Review Threads and repository-policy SKIPPED.

Paused immediately per user instruction relayed by coordinator. All current tests/logs saved locally; coordinator owns combined PR delivery. Await WORLD fix and explicit resume before any further tests or implementation.
