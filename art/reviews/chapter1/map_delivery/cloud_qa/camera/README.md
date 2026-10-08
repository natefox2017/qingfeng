# Camera look-ahead obeys authored limits

Actual keyboard movement to the north gate exposed 120 logical pixels of grey outside the farm, despite limit_top=0. Preserved before screenshot: ../manual_route/north-camera-void-defect.png. Godot's offset is applied after limits: at player (896,104), actual inverse canvas mapping was top-left (576,-120), bottom-right (1216,240), screen center (896,60). This was a real rendering bug, not just a configuration discrepancy.

Fix: move the same (0,-120) look-ahead to the child Camera2D.position and leave offset=(0,0). Native clamping now includes it. Physics/player/doors/collisions/zoom and integer+nearest settings are unchanged. The native capture script restores the actual authored camera position, rather than replacing it with player position.

Commands, Godot 4.7.2, isolated XDG:

```
Godot --headless --path game --script res://tests/chapter1_camera_bounds_test.gd
Godot --audio-driver Dummy --path game --script res://tests/chapter1_camera_bounds_test.gd
```

Before: 234 checks / 12 failures, exit 1. After: 234/0, exit 0 in both headless and graphical renderer. Tests map every screen corner back to world coordinates at all four map corners, center and repeated arrival for farm+village, at 1280×720 / 1920×1080 / 1366×768; check physical player unchanged, constant zoom/no smoothing, integer display scale, repeated arrival framing. The smaller house/shop/workshop spaces remain exactly one 640×360 logical viewport under each window size; no arbitrary zoom or invented outdoor shrinking policy was added.

The same real desktop save was reopened through Continue at unchanged (896,104): top-left is now (576,0), bottom-right (1216,360), grey void gone. CUA captured full native client windows, verified PNG dimensions 1280×720, 1920×1080, 1366×768. The latter retains actual 43px horizontal/24px vertical margins. These are entire windows, not renamed 1280px textures.

Linux llvmpipe emitted a V-Sync-mode unsupported warning; it is not hidden and no native-FPS guarantee is claimed. User visual approval remains pending.
