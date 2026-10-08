# Final cloud regression, 2026-10-08

Pinned engine: Godot 4.7.2.stable.official.ed1daf0bf.

`GODOT_BIN=/workspace/scratch/2bd695cff14d/godot472/Godot_v4.7.2-stable_linux.x86_64 ./run_game.sh --test-all --timeout 180 --report-dir /workspace/shared/qingfeng-qa-4cc6c2c/final-suite-rerun`

Exit 0. The runner creates a clean isolated project and HOME/XDG roots, cold imports it, then runs the complete official suite serially. All summary booleans are true. `full_suite/` preserves all 46 logs (including import, not 46 distinct gameplay scripts), timings, source hashes and summary. This includes fresh/new/load UI, door transitions, settings, economy, and the strengthened full bridge exploration.

The earlier full run failed the old exploration fixture that walked directly through the now-visible yard fence; that evidence and the route correction are retained in `../exploration`. It is not presented as a clean first attempt.

Additional serial native scripts used the same pinned binary, isolated writable HOME/XDG, and `--headless --path game --script res://tests/<name>_test.gd`; every exit was 0:

- chapter1_map_save_migration: 33/0
- chapter1_map_editability: 68/0
- chapter1_map_playability: 451/0
- world_layout: 35/0
- full_economy_loop: 35/0
- door_transition: 20/0
- chapter1_historical_save: 28/0
- chapter1_object_anchor: 346/0
- chapter1_camera_bounds: 234/0
- chapter1_gate_passage: 6/0
- chapter1_yard_layout: 30/0
- settings_ui: 18/0 (six additional three-window quantity assertions added after the aggregate run; focused rerun passed)

The engine tests cover real app state and physics but do not replace the separate desktop keyboard route, whole-window captures, native editor operations, or user visual acceptance. Camera bounds 234 checks are scene-level corner/arrival checks; the app fresh/save/load/door chain is exercised by other listed scripts and manual evidence.
