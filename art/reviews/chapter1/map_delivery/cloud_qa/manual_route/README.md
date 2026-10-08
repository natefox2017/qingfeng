# Actual native-keyboard route, 1366×768

Godot 4.7.2 Linux/llvmpipe, existing canvas_items + keep + integer. The app window itself is 1366×768, with actual 1280×720 game content and 43px horizontal / 24px vertical black margins. These PNGs were captured from the native game window through CUA, not fabricated or resized render textures.

All movement and interaction used the real game window keyboard/mouse: title click → new game → farmhouse entry/return → eastward farm walk → plot003 E harvest → plot004 key1/E till, key3/E plant, key2/E water → orchard → bridge east and west → village → shop → workshop → farm. Native screenshot steps 01–10 and actual farm save files document the progression. No player teleport or Input.action_press was used in this desktop session. A temporary read-only observer exported current state and occasional AStar navigation hints; it never assigned positions or invoked gameplay actions.

Observed inventory changes: 003 yields exactly one radish; planting consumes one of four seeds. Money remains 200 because this desktop run entered the shop but did not trade. Existing headless full-economy regression separately verifies trading. The overnight passage of real time advanced to day 2: watered plot004 has growth_days=1 and is_watered=false after normal daily settlement, not save loss.

At continuation, workshop/farm PNGs 09–10 and new farm saves at (896,104) were present. We did not infer completion merely from seeing the title: backed up and hashed all existing test saves, explicitly clicked Continue, loaded the real farm again, verified 200 money / 3 seeds / 1 radish / all six plots and day-2 crop state, then used Save and Return and quit through the UI. PNGs 11–13 show this independent reload/resave confirmation; prior saves remain byte-identical.

The route revealed real defects rather than a clean visual acceptance:
- `north-camera-void-defect.png`: Camera2D offset exposes grey beyond the north world limit. Separate camera fix/regression follows.
- `pause-money-wrap-defect.png` / `12-pause-before-resave.png`: the pause wallet wraps each digit into a narrow column. Separate quantity-label fix follows.
- The village stone arch's lintel blocks direct north passage; the route can detour, but the lintel should be overhead rather than a ground collider.
- Shop/workshop interiors remain diagnostic art; this route proves entry/exit, not their final art approval.

Short initial directional taps and the west reed approach required correction. We verified actual movement/state instead of assuming a successful input call crossed the bridge. The east-bank PNG was saved after confirmed x=1685, then the same bridge was traversed west. This is not a timing/FPS benchmark or final user visual acceptance.
