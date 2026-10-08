# Correct original asset anchors without moving gameplay geometry

Input commit `6961ce8`, Godot 4.7.2 Linux. Asset-by-asset audit uses the existing object/animal/town/river metadata and each Sprite2D.get_rect(). Only 45 nodes in 25 scene files already authored with a negative pixel anchor (including intentional 1–2px vertical seating) were changed to `centered=false`. The audit list includes exact texture, source anchor and preserved offset. No texture, scale, parent position, physics shape, door, plot or save marker changed.

The bug was double application of origin: Sprite2D defaults centered, so a sprite with offset = -source_anchor was shifted by another half texture. Actual Godot farm house draw rect started at (-192,-225) instead of (-96,-149), moving the visible door 96px left/76px up from its actual door/physics anchor. Well/tree/market cases similarly shifted 40×48 / 48×64 / 32×24 px.

A metadata-driven native test checks 141 standalone and instantiated occurrences. Before: 141 failures / exit 1. After: 141 checks / zero failures / exit 0. Correctly centered fence rails/posts and player sprites are excluded from this different top-left authoring contract and left unchanged. This is not a blanket center-mode rewrite.

```
Godot --headless --path game --script res://tests/chapter1_object_anchor_test.gd
Godot --path game --audio-driver Dummy --script res://tests/chapter1_map_native_capture.gd -- <absolute-output>
```

Native renderer before and after both exit 0, all 12 farm/village arrival/focus captures produced at requested windows 1280×720, 1920×1080, 1366×768. Selected original PNGs are kept in before/after. 1366 windows produced 1280×720 integer content; these render textures do not prove the full OS letterbox. PNGs are unedited Godot output, not illustrations or manual walking evidence.

Six focused post-fix regressions: migration 33/0, editability 68/0, playability 431/0, world layout 35/0, full economy 35/0, doors 20/0, all exit 0. Historical implementation save replay 28/0 exit 0. Real Input.action_press movement and real door resolution remain covered by playability; desktop manual route is still pending.

Visual review now confirms the house image actually aligns above the original doorway path. It also reveals pre-existing layout problems that the shifted sprites concealed: dog on the farmhouse façade, kennel over the south fence, and coop/workbench overlap. Those are separate layout work, not hidden by another sprite offset or z-index change. New native editor instances/reloads are required to see the committed resource changes. Final style/visual acceptance remains with the user; no #84 closure or merge.
