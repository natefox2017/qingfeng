# River modules — #89 proposed delivery

Canonical runtime: `game/assets/chapter1/river/`. Source/references/requests:
this directory. `metadata.json` records actual PNG SHA, raw source SHA, crops,
anchors, native 16px atlas cell rectangles, connectivity intent and remote IDs.
No scene, shared TileSet, global manifest, contract or UI was edited.

| PNG | Canvas | Consumption |
| --- | --- | --- |
| water_tile | 16×16 | Opaque repeating blue water; no walkable collision |
| water_animation | 32×16 | Two 16×16 frames, 150ms each; exact horizontal ripple shift |
| bridge_deck | 32×16 | Repeat horizontally at native size; proposed walking band y3–13 |
| bridge_rail | 32×16 | Transparent independent 2px handrail at y7–9; WORLD owns blocking |
| bridge_post | 16×16 | Separate bridge or dock support, root (8,14) |
| bank_north | 32×32 | Opaque grass/rock/water northbank strip; four native cells |
| bank_cliff | 32×32 | Transparent outside the rock wall; moss/grass edge supplied separately |
| bank_cliff_cap | 32×16 | Grass/moss lip over wall, independent RGBA |
| waterfall_mouth | 16×16 | Top termination |
| waterfall_middle | 16×32 | Narrow flowing stream, repeat vertically without scaling |
| waterfall_splash | 16×16 | Bottom termination |
| dock_deck | 16×16 | Full opaque wooden floor cell; posts remain a separate layer |
| boat | 32×32 | Decorative original hull; actual NE/SW axis, not requested N/S |
| reeds | 32×32 | Decorative cattail root (16,29) |

## Production and rights

Approved `world_chapter1_map.png` and the user's identical attachment were
actually opened. Exact reference crops and map SHA/rects are in metadata.
PixelLab received these local crop colors via `color_image_base64`; the cliff
object used a true local 32×64 crop via `background_image` in style-match mode.
These are original generated assets, not copied game textures or legacy assets.
PixelLab output is not labelled CC0; input rights remain the user-provided design
permission recorded in `art/approved/ART_RIGHTS.md`.

10 ordinary subscription generations were submitted (9 Pixflux + 1 map object),
budget 12. No purchase or Pro call. The account is shared: global balance changes
include other tasks and are not this task's expenditure. Free workbench repairs
copied exact water boundary pixels, shifted ripples and collapsed distracting
minor shades to three approved blue tones. Raw inputs are retained.

After the user's tool-order correction, built-in image_gen was tried first for
the vertical bank. Its actual 1254×1254 result failed the requested native32 grid
and remains rejected in `.tmp/river/ai_bank_rejected.png`; it was not downscaled
or imported. One Pixflux vertical-bank retry also produced an opaque diagonal
scene (`bank_west_raw.png`), retained for review only, excluded from runtime.
The style-match map object supplied usable cliff parts instead. The initial
`bank_raw.png` was a horizontal northbank, and is accurately named accordingly.

## Technical evidence and reproduction

Offline report: `art/reviews/chapter1/river/offline_report.json`. Run with Pillow:

```sh
python3 art/reviews/chapter1/river/verify_assets.py
```

Actual result: 14 PNGs hash/size/RGBA/grid/source-rect verified; 64 opposing-water
edge pairs equal across both frames; the two water frames have different bytes.
All independent objects have only alpha 0/255. Water, dock floor and northbank
terrain intentionally fill their tiles and are opaque RGBA.

Godot4.7.2 isolated macOS/OpenGL capture: `art/reviews/chapter1/river/native_sample.png`
and `native_animation_second.png`, both 960×576. No simulation/synthetic screenshot.
12 unique PNG assets are rendered with native Nearest; 14 files were imported.
The sample is an ART fixture with no player/collision, not the formal map.
A fixed 0.17-second sample initially differed, then repeated with identical bytes.
The corrected native fixture samples every0.04s until a genuinely different
rendered frame appears, or fails after16 samples. `native_report.json` preserves
the failed fixed-time sample and the actual final distinct-frame result.
It proves real engine advancement, not human loop acceptance or performance.

Reproduce using an isolated project (do not overwrite another task's project):

```sh
mkdir -p .tmp/river/native/assets
cp game/assets/chapter1/river/*.png .tmp/river/native/assets/
cp art/reviews/chapter1/river/native_sample_project.godot .tmp/river/native/project.godot
cp art/reviews/chapter1/river/native_sample.gd art/reviews/chapter1/river/native_sample.tscn .tmp/river/native/
/Applications/Godot.app/Contents/MacOS/Godot --headless --path .tmp/river/native --editor --import
open -g -n -a /Applications/Godot.app --args --path "$(pwd)/.tmp/river/native" --rendering-method gl_compatibility
```

The short native process saves captures and quits. Shared-desktop capture
requires coordination; this task used background launch/no_focus and never
controlled the #88-owned Pixelorama editor. The native fixture uses the documented
[TileSetAtlasSource frame APIs](https://docs.godotengine.org/en/stable/classes/class_tilesetatlassource.html).

## Remaining, not accepted

Full bank inner/outer corner terrain-peering combinations, shallow/deep matching
water, bridge landings/endcaps, unique dock post/cap and lily pads remain missing.
WORLD may reuse bridge_post for the dock. Waterfalls are narrow4px streams and
must not be stretched to impersonate a broad waterfall. Bank/cliff seams and
bridge/dock landings need formal-map review. The boat orientation differs from
its request. No water-blocking/bridge-walkthrough, door routes, full chapter map,
performance, export, production or human visual acceptance was performed here.
No asset is accepted, no Issue checkbox was marked, no PR created/pushed/merged.
