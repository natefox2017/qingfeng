# Coincident arrival safety, Godot 4.7.2

The real keyboard village run exposed a pre-existing indoor physics problem. A persisted resident could occupy the exact same DoorArrival as an entering player. With both CharacterBody2Ds active, zero input caused repeated same-direction depenetration: in the preserved physical probe, the player moved (320,320) → (320,248.66) while the resident moved toward (320,256.736). Both shop and workshop reproduce it. `before-overlap.log` and the source preserve this trajectory; the diagnostic probe prints the unsafe collision behavior and exits 0, rather than claiming an old whole-suite failure.

This was not a stuck key: native telemetry confirmed all four directions false, vector and velocity zero. A held-direction doorway test returned to village with zero vector after release; backpack interruption then a 150ms right press moved 14.4px normally. No input-clearing change was made.

## Repair scope

Before player activation after load or door commit, only an overlapping active resident yields into a bounded neighboring location toward its scheduled route. This avoids routing immediately back through the player's arrival. The authored player anchor, resident identity, schedule, relations, and original save file stay intact.

Candidates must remain inside the world/interior, avoid static geometry, active residents and interaction markers. Start and destination are checked; a native `cast_motion` sweep uses the resident's actual CollisionShape2D shape and transform to reject intervening walls. The API returns a safe motion fraction and ignores shapes initially overlapped, which is why the separate start check remains: [Godot PhysicsDirectSpaceState2D](https://docs.godotengine.org/en/stable/classes/class_physicsdirectspacestate2d.html#class-physicsdirectspacestate2d-method-cast-motion).

No legal candidate means a conservative rejection. A physics synchronization frame precedes input activation; generation/pending checks preserve cancellation. Candidate runtime is captured only after that guard.

## Verification

`Godot --headless --path game --script res://tests/chapter1_arrival_occupancy_test.gd`: exit0, 45/0. Both interiors, day-working/night-leaving/absent; stable idle player for90 physics frames; no residual direction; physical return marker; occupied alternative candidates; only overlapping NPC moves; conservative rejection; repeated reservation; thin intermediate wall with a clear endpoint.

`Godot --headless --path game --script res://tests/chapter1_arrival_load_test.gd`: exit0, 52/0. Actual app stage/commit, four day/night interior cases, save/write-new/read_save, original file-byte checks, return transactions, second-wait cancellation and no-candidate failure restoring old scene/position/input. This is engine integration, not claimed as keyboard input.

The original reviewer’s village NorthWall coordinate example is covered by an equivalent synthetic thin-wall regression, not a separate dynamic replay of that exact coordinate. The reviewer found no remaining blocker. Session non-mutation on canceled staged targets was also reviewed by commit-order inspection; the tests assert scene/position/input recovery, not full before/after session equality.

The affected 13-script serial pass is included here. After the final sweep/cancellation additions, the two new scripts were rerun as45/0 and52/0; the final complete cold suite is recorded separately when complete.

## Actual native replay

`manual-source.qfsave` is an unchanged byte copy of the assistant-created earlier keyboard-run save f512e5c510031d5c40547aa5c846b728 (day2, minute2016), whose shopkeeper really occupies (320,320). It is not a private user save and is separate from the historical-version fixture documented elsewhere.

Using the actual native menu, Continue → farm → keyboard street walk → shop E produced a player that stayed exactly (320,320) for68 telemetry samples over20.6 seconds, with zero input/velocity and no slide collisions. Then actual UI Save → Title → Continue loaded the new shop save at (320,320),200 coins; south/E returned to village (400,168). Three whole-window1366×768 screenshots and `native-summary.json` document it. The source save hash was rechecked unchanged. Engine exited0. Only unsupported V-Sync environment warning remains.

Final complete cold-import regression: `GODOT_BIN=<pinned4.7.2> ./run_game.sh --test-all --timeout 180 --report-dir /workspace/shared/qingfeng-qa-4cc6c2c/post-arrival-full` exited0; all summary booleans true. All46 logs (including cold import), timings and source hashes are in `full_suite/`. This run includes the final motion sweep and cancellation guards.
