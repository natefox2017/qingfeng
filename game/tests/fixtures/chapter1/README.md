# Actual pre-map implementation save

`legacy_a871fdb.qfsave` is test data, not a user's private save. It was genuinely written by this repository's pre-PR117 game at commit `a871fdb2f18eea1f9208dcb6c478823677966460` using Godot `4.7.2.stable.official.ed1daf0bf` on Linux. No snapshot fields were edited or re-signed by the current code.

SHA-256: `447fe13e78d79219a43b7f1997cf65d1719d3f7e65119005bf5ad9fae10c6b8b`.

Generation: archive that commit's `game/` into an isolated directory (not the old qingfenggu project); copy `export_legacy_map_save.gd.txt` to that archive's `game/tests/export_legacy_map_save.gd`. The subclass runs the historical `full_economy_loop_test.gd` unchanged, then its overridden finish() asks that same historical app/store to save and copies the resulting bytes. The old implementation executes the three-day buying, planting, watering, chest storage, harvesting, selling and replanting path. Its movement is the original economy test's positioning fixture, not a recorded manual walk.

With independent writable HOME/XDG_CONFIG_HOME/XDG_DATA_HOME/XDG_CACHE_HOME:

```
Godot_v4.7.2-stable_linux.x86_64 --headless --path <archive>/game --editor --import --quit
Godot_v4.7.2-stable_linux.x86_64 --headless --path <archive>/game --script res://tests/export_legacy_map_save.gd -- <absolute-output.qfsave>
```

Both exit 0, generation **37 checks / 0 failures**. The isolated cold import had no ERROR lines; the earlier non-isolated current-HEAD import exited 0 with two editor-settings path errors, which are not hidden or counted as clean.

Fixture state: day 3, 195 coins, all six original cells `(17..19,7..8)`, plot 003 mature, plot 004 growing and watered, chest reserve and complete inventory, three village residents with genuine historical positions. Generated save/session identifiers and time are intentionally not deterministic. Reproduction produces equivalent gameplay state, not necessarily identical bytes.

Current test:

```
Godot_v4.7.2-stable_linux.x86_64 --headless --path game --script res://tests/chapter1_historical_save_test.gd
```

Result **28 checks / 0 failures, exit 0**: real checksum/read_save load; unchanged full six crop states except new authored cells; full inventory/chest and 195 coins; old residents reanchored to in-bounds collision-free village positions; original source bytes unchanged; distinct new migrated file and actual reload preserve state. An initial harness attempt disabled `_process` before asynchronous reload and timed out; restoring processing before reload fixed that test harness mistake, without changing production loading/migration code.

Logs are in `art/reviews/chapter1/map_delivery/cloud_qa/legacy-generation.log` and `historical-save-final.log`. This verifies an actual old-version-generated save, not a private user file that was never supplied.
