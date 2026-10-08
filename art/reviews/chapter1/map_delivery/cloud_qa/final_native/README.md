# Final native visual candidate

2026-10-08, Godot 4.7.2 native X11/OpenGL llvmpipe. Map capture 12 images and settings capture 3 images both exit 0. Commands:

`Godot --path game --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/chapter1_map_native_capture.gd -- <absolute output>`

`Godot --path game --rendering-method gl_compatibility --audio-driver Dummy --script ../.tmp/settings_capture.gd`

Settings source is included as `.gd.txt`. Settings volume percentage is one line, measured width 25 logical pixels, in all three requested sizes. These are actual renderer output; 1366x768 filenames explicitly label the 1280x720 integer-scaled content. Whole-window 1366x768 and its real black margins are separately preserved in `../camera` and `../quantity` from actual desktop capture. No composited borders.

The bounded final art pass reuses existing cherry-tree scenes for three border clusters and varies two farm cluster positions. It adds a reusable 64x64 native LibreSprite ground-contact texture beneath existing bushes. Source `.js`, `.aseprite`, `.png` and metadata reside in `art/sources/chapter1/objects/shrub_ground_shadow.*` / object_metadata.json. The native pixel script uses two deliberately selected stepped colors, binary alpha, no noise/resampling, and no new PixelLab job. Original source and runtime PNG are identical SHA256 ce33aa555b4fd47368daa6543a12a3b580acb7857c4d2fb5512097c3c8822e6b. Existing bush collision stays unchanged; alternate tree clearances are covered by final playability/layout tests.

Both captures shut down audio and release scenes before exit: no ObjectDB/resource leak diagnostics. The cloud graphics driver still warns that changing V-Sync is unsupported.

This remains a visual candidate. Compared with the approved reference, large grass regions are still uniform, the village plaza has sparse/repetitive furnishing, shop/workshop frontage correspondence and diagnostic interiors need further visual work. The corrected farmhouse, separated yard props, pixel anchors, camera edges and passable gates are verified improvements, not a claim of final reference equivalence. User visual acceptance is outstanding; PR remains Draft and Issue84 open.
