# Chapter 1 pixel clarity evidence

Captured 2026-10-09 on macOS using the native Godot 4.7.2 stable app (official build `ed1daf0bf001b61586d9930840f2f1394092c079`) and the actual Chapter 1 entry/game scenes. The recorded logical client sizes are 1280×720, 1920×1080, and 1366×768. PNGs capture the whole native app window, including macOS titlebar/shadow; their pixel dimensions are listed in `manifest.json` and are larger than the logical client area.

## Compared configurations

- A, current baseline: `canvas_items`, `keep`, fractional scale. UI text remains native-resolution, but a non-integer window scale does not preserve integer pixel-art scaling.
- B: `viewport`, `keep`, integer scale. Pixel content is uniform, but the UI is drawn into the 640×360 viewport; Chinese title text is visibly less clear at 1366×768.
- C, selected: `canvas_items`, `keep`, integer scale, 2D transform snapping on and vertex snapping off. UI remains clear; pixel art uses the largest integer scale that fits. At 1366×768, 2× content leaves letterbox margins. Actual mouse activation of new-game and return controls succeeded at all three sizes.

The comparison images are A/B/C at 1366×768. Final images include title/world at 1280×720 and 1920×1080, plus title and a keyboard-driven scrolling world frame at 1366×768.

## Runtime evidence

- Baseline A, 1280×720, 60.156 seconds, 233 samples at 4 Hz: player X range 819.19 and Y range 491; camera X range 819.19 and Y range 331. This was a real visible keyboard walk and camera scroll.
- Selected C, 1366×768, 60.126 seconds, 233 samples at 4 Hz: player X range 822.39 and Y range 491; camera X range 822.39 and Y range 331. This was a real visible keyboard walk and camera scroll.
- Selected C capture sessions: 1280×720 for 20.098 seconds (78 samples), 1920×1080 for 20.202 seconds (78 samples), and 1366×768 for 30.015 seconds (116 samples). Capture-only sessions verify runtime settings and retain input-driven screen captures; motion assertions were applied in the two 60-second walks.
- Runtime reports record effective stretch settings, viewport size, actual TileMapLayer/Sprite texture filters, camera zoom/smoothing, and sampled positions. Both sampled walk sessions exited successfully. A cold editor import completed successfully before graphical sessions.

The 4 Hz position samples and selected screenshots do not constitute frame-by-frame jitter analysis, FPS profiling, export testing, or visual sign-off. No map, gameplay, save logic, route tests, or UI artwork was changed for this task.

## Reproduction

Run the recorder with a graphical Godot 4.7.2 executable and a fresh output directory:

```sh
Godot --path game --resolution 1366x768 --script res://tests/chapter1_pixel_clarity_test.gd -- /absolute/output/path 60
```

Drive the visible game window with keyboard movement during the run. The recorder creates an isolated save/settings location under `user://`, writes `runtime.json`, and exits nonzero if the player does not move or the camera does not scroll. Pass `capture_only` as the third user argument to record settings without requiring movement.
