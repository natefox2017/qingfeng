# Chapter 1 object family — proposed handoff

Baseline: `a871fdb2f18eea1f9208dcb6c478823677966460`, branch `codex/issue-90-91-world-objects`, isolated worktree `1cdf`. Scope is only this source/review/runtime objects family. WORLD owns placement, collision, doors, YSort, plot projection and shared manifest integration. No gameplay, save, shared style, map scene or original Phase0 image was changed.

## Delivered PNGs

The canonical local record is `game/assets/chapter1/objects/object_metadata.json`: 19 asset records / 29 runtime PNGs including editable split layers. All scale factors are 1; transparent cropping/padding and integer translations preserve the native pixel grid.

| Object | Canvas | Integer root anchor | Notes |
|---|---|---|---|
| well | 80×96 | 40,94 | Independent blue roof/stone well sprite |
| fence | 80×48 | 40,46 | Additional post + horizontal/vertical rails; vertical rail is explicit 90° transpose |
| apple_tree | 96×128 | 48,126 | Exact complementary crown/root layers |
| cherry_tree | 112×112 | 56,110 | Exact complementary crown/root layers; flower detail is stronger than map reference |
| pine_tree | 96×128 | 48,126 | Exact complementary crown/root layers; glossy leaf silhouette remains proposed |
| bush | 64×64 | 32,62 | Environment only |
| doghouse | 64×80 | 32,78 | Red roof, independent kennel |
| chicken_coop | 72×88 | 36,86 | Derived kennel shell, native half-door rail/vent slats; roof/body layers |
| tool_bench | 96×80 | 48,78 | Independent outdoor tool station |
| scarecrow | 48×64 | 24,62 | Environment only; no new interaction |
| rock | 64×64 | 32,62 | Angular silhouette; still requires visual review |
| cabbage | 48×32 | 24,30 | Environment only; no content/item added |
| farmhouse_blue | 192×152 | 96,149 | Phase0 source reused, roof palette only; roof/body layers |
| wood_sign | 48×64 | 24,64 | Blank board assembled from existing bench/post source pixels; no baked text |
| radish_growing / radish_mature | 32×32 each | 16,32 | Plant only, common anchor; 22/24 opaque colors after free exact cleanup |

Split layers use the same full canvas/anchor as their composite. `layer_split_y_px` is an explicit scanline cut; recomposition is byte-exact. WORLD must review the split position against actual player occlusion. No collision polygons, door landing points or sign interaction are encoded in these images.

The real `PlotState` mapping is `untilled/tilled → no plant`, `growing → radish_growing`, `mature → radish_mature`. Harvest is the existing command returning the plot to tilled, not a new persistent state. These are visual candidates for the existing six plots; this ART task does not wire farming or introduce another crop system. Decorative cabbage is not harvestable content.

## Source and generation evidence

Reference: approved `art/approved/refs/world_chapter1_map.png`, SHA `ba35eef32eb0a49a5e50ad8ec4498148845c8f4065d3695b315c4ea1286bddd7`. `production.json` records real native crop rectangles, roof color sample coordinates, original reuse hashes, budget and rejection reasons. `jobs*.json` preserve the exact PixelLab request text and IDs. Raw PNGs remain separate from runtime exports. `pixel_edit_receipts.json` records free software edit IDs; cleanup retained original source PNGs.

14 ordinary subscription jobs were submitted: 12 initial map-object requests and 2 coordinator-authorized PixFlux32 crop states. No Pro mode, purchases or credits were used by this task. Account-wide balance changes also include concurrent tasks and are not attributed from the account delta.

After the user changed priority to AI → PixelLab → pixel software, image_gen was actually tried with the scarecrow reference. Output was 1024×1536 with diffuse glow, partial alpha0..254 and no requested integer enlarged pixel grid. It was rejected; the output/hash is recorded and the raster is kept only in `.tmp/objects`. Subsequent small sprite requests used ordinary PixelLab based on that failure evidence. The first radish map-object job returned a brown stump; `radish_rejected.png` remains archived as REJECTED and is not a runtime asset.

Farmhouse free pixel editing changes 8915 roof pixels in y0..84 to colors sampled from the approved map. All pixels y85..151 and the entire alpha channel are byte-identical to the original Phase0 farmhouse. Chicken coop uses the generated kennel source with four exact native brush operations. Wood sign uses an exact bench board crop and the existing post, without resampling.

Rebuild from repository root with bundled Python/Pillow:

```
python art/sources/chapter1/objects/normalize_objects.py
python art/sources/chapter1/objects/derive_farm_objects.py
python art/sources/chapter1/objects/pack_crop_sprites.py
python art/reviews/chapter1/objects/validate_objects.py
```

## Actual validation

- `validate_objects.py`: 19 records / 29 runtime PNGs, dimensions/hashes/0-or-255 alpha correct; all split-layer recompositions exact; farmhouse non-roof/alpha unchanged; radish common32×32/anchor16,32 and ≤24 colors; rejected stump absent from runtime.
- Godot4.7.2 `--headless --editor --path .tmp/objects/native --import`: exit0, isolated cold import of 29 PNGs; no ERROR/WARNING in import log.
- Godot4.7.2 `--headless --path .tmp/objects/native --script import_load.gd`: exit0, 29 actual imported Texture2D resources loaded.
- Godot4.7.2 `--path .tmp/objects/native --script review.gd -- <worktree> <capture>`: exit0, actual OpenGL/Metal native 1024×800 capture, `native_objects.png`. Original Phase0 farmhouse/oak are included as scale controls. Initial incorrectly supplied script arguments caused a JSON read failure; corrected arguments produced the capture. This is an object sample, not a map-route acceptance.
- 8× images use nearest neighbor and were inspected; originals/composites were also viewed at native size. Source shape/palette limitations are retained as proposed.

No full-world route, player occlusion/collision interaction, doors, export package, performance or human visual acceptance was tested by this ART task. PNG generation, cold import and object screenshots do not complete #84/#90/#91. No Drive upload/unique Drive URL or reviewer signoff is supplied; those fields remain absent/null. PixelLab terms URL is preserved as source authority but the browser could not fetch it in this session. Generated assets are not labelled CC0. All assets remain `proposed`; no PR was pushed, merged or Issue closed.
