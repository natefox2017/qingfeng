# Follow the actual courtyard opening and reach the real east bank

The final 46-log cold suite caught the old exploration fixture walking straight south from spawn (320,560), now inside the roomier fenced yard. It hit the visible south rail instead of the gate. The comprehensive pathfinding/playability test already used the real opening. Production geometry was not changed to make the stale trajectory pass.

The fixture now first walks left 48px with actual Input to x272 (new additive assertion), then follows the same southward and eastward route. All prior scene/river/camera/controllability assertions remain. The old final x>1450 assertion only established reaching mid-bridge; it is strengthened to x>1552 and >1200px physical displacement so the player actually reaches the eastern bank.

Godot4.7.2 `--headless --path game --script res://tests/farm_exploration_test.gd`: before 12 checks / 3 failures exit1; after 13/0 exit0. This is a route-fixture correction with stricter destination coverage, not removed assertions or a physics bypass. A complete fresh cold suite is rerun after this change.
