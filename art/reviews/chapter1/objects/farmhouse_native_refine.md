# Native farmhouse material refinement (candidate)

Native tool: official LibreSprite 1.3 Linux release, https://github.com/LibreSprite/LibreSprite/releases/tag/v1.3. No paid generation, no whole-map image generation, no resampling.

`art/sources/chapter1/objects/farmhouse_pixel_refine.js` rebuilds the editable `.aseprite` and canonical `farmhouse_blue.png` from the preserved original farmhouse plus this project's existing PixelLab well PNG. It transfers the well's blue roof pixels at 1:1, clips intentional compound gable/wing planes, and uses native pixel strokes for façade timber, attic sash, planters and chimney. PixelLab provenance of the donor stays in `object_metadata.json`; this edit is not a new PixelLab generation and has no invented job ID.

From repository root:

```
LibreSprite --batch --script art/sources/chapter1/objects/farmhouse_pixel_refine.js
```

Actual command exited 0 and printed FARMHOUSE_NATIVE_DETAIL_DONE. Native source is 192×152, anchor remains (96,149), alpha is exactly {0,255}; world scale remains 1. Pillow was used only for deterministic body/roof separation at scanline 104, binary-alpha/hash verification and the 8× nearest preview, not to draw the asset. Body+roof recomposes byte-for-byte to the full PNG.

Godot 4.7.2 imported it without ERROR (isolated writable XDG directories), and rendered it in all three requested window sizes. The new source keeps the same canonical asset ID. It is proposed, not accepted; final user visual approval remains pending. The adjacent yard-native screenshots also include the separately recorded layout changes and must not be read as this art commit alone.
