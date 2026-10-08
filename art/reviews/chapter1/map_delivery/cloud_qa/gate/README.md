# Walk under the stone arch instead of detouring around an invisible lintel

The native keyboard route exposed a blocking top beam in both gate instances: the image depicts an overhead arch but its Lintel was a full-width ground StaticBody2D. The pathfinder regression could detour around it, so generic route success did not prove the obvious center route.

Focused Godot 4.7.2 actual Input/physics test before: farm stops at y99.07, village at y547.07; 6 checks / 2 failures, exit 1. After removing only the overhead lintel ground collider/subresource: 6/0, exit 0. Both stone pillars remain solid and are queried independently. Sprite, gate coordinates, save/door markers and IDs are unchanged.

Command: `Godot --headless --path game --script res://tests/chapter1_gate_passage_test.gd`. Logs are adjacent. This fix concerns traversal; native editor/art acceptance is separate.
