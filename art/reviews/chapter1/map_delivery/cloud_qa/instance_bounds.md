# Independent map instance perimeter regression

2026-10-08 UTC, input HEAD `4cc6c2c04f02e09bf555914a6031283d715d2883`, Godot `4.7.2.stable.official.ed1daf0bf`, dot cloud Linux.

The six requested baseline regressions passed (33/56/431/35/35/20 checks, all exit 0). Further instance-isolation inspection found a real expansion bug: two instances of either PackedScene reused the same boundary RectangleShape2D resources. Expanding one instance changed the other instance's collision dimensions without changing its ground or camera.

Reproduction instantiated two farm scenes, then two village scenes, expanded only the second ground and called refresh_world_layout(). Farm A width changed 1792 → 1888; village A changed 1280 → 1376. Reproduction exit 1. Logs: `instance_boundary_before.log`.

Fix: set `resource_local_to_scene=true` on each scene's horizontal/vertical perimeter shapes. Sharing between opposite sides of one instance is intentional; separate scene instances now own separate resources. No scene dimensions, IDs, doors or art moved.

After-fix reproduction exit 0; original widths stay 1792 and 1280. Added 12 assertions in `chapter1_map_editability_test.gd` checking real expansion, unchanged original bounds and four independent unchanged perimeter shapes for each scene. Full editability test now **68 checks / 0 failures, exit 0**, including saved scene reload, actual physics crossing the former perimeter and moved house door/collision persistence.

Command (isolated writable HOME and XDG_CONFIG_HOME/XDG_DATA_HOME/XDG_CACHE_HOME):

```
Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/chapter1_map_editability_test.gd
```

No visual acceptance is implied. PR #117 remains Draft; Issue #84 remains open.

Post-fix neighboring regressions: `world_layout_test.gd` 35/0, `door_transition_test.gd` 20/0, `chapter1_map_playability_test.gd` 431/0, all exit 0. Commands use the same Godot flags above with the corresponding script. Full logs are adjacent `*_fixed.log`.
