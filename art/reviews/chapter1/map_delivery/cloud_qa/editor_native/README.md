# Native Godot 4.7.2 editor check, 2026-10-08

Actual cloud-desktop mouse and keyboard actions against an independent scene copy (`game/tests/fixtures/editor_farm_probe.tscn`, untracked, not a delivered world).

1. Open the copy in the native editor; choose 2D and Farmhouse.
2. Use the Move tool and drag 16 pixels right: (272,480) → (288,480). Save.
3. Select TerrainGround and paint five cells immediately west of x=0. Save.
4. Exit the editor (0), restart it from the saved file, and observe the persisted extension.
5. Load those exact saved bytes in the native engine with the included read-only verifier: 17 checks, 0 failures, exit 0. Both door markers and all three farmhouse bodies follow the move. Bounds become (-16,0,1808,1024); camera and all four actual perimeter colliders follow.

Images 01–05 show the operation. `saved-scene.patch` records the exact editor serialization relative to the unchanged authored world (including editor-added UIDs). `runtime_verify.gd.txt` checks the saved copy; it does not make the tested edits.

The editor also automatically reserialized project.godot and two shared TileSets. Those unrelated automatic rewrites were recorded outside the repository and restored to their exact pre-editor HEAD bytes after exit; no such changes are included. The world scene itself was never saved or moved. This verifies a small extension and one composed object, not every possible designer edit.

Renderer startup fell back from unavailable Vulkan to OpenGL and from unavailable ALSA to Dummy audio. The editor nevertheless opened, saved, reloaded and exited successfully. These environment diagnostics remain in the raw editor log; they are not represented as a warning-free editor launch.
