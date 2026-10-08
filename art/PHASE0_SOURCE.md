# Phase 0 pixel-art provenance (candidate)

These four runtime PNGs were authored specifically for this Qingfeng farm entry slice from pixel primitives. They are not copied from Stardew Valley or another game's texture sheets, and they were not obtained from PixelLab or the user's earlier project. The user approved creating an original first-pass farm screen in the absence of an approved chapter-one design reference.

- `game/assets/phase0/farm_terrain_16.png`: 8 × 4 atlas of 16 × 16 grass, dirt path, water, banks, planks, soil, crops and ground details.
- `game/assets/phase0/farmhouse.png`: separate 192 × 152 farm home front aligned to the existing house footprint and door Marker.
- `game/assets/phase0/oak_tree.png`: separate 80 × 96 tree sprite anchored at the existing root/foot point and Y-sorted with the player.
- `game/assets/phase0/player_4dir.png`: 4 columns × 4 rows, 24 × 32 per frame. Rows south / west / east / north; columns idle / walk A / walk center / walk B.

The scene uses an external editable `TileSet`, two baked `TileMapLayer` ground layers, and a projection-driven `PlotStates` layer. Gameplay plot Marker IDs, door anchors and solid collision geometry are unchanged.

All four assets are `proposed` in `art/manifest.json`, with exact file SHA-256 digests. These are working playable pixel resources, **not accepted final art**, not an approved recreation of a previously supplied design and not a replacement for the chapter-one full-map milestone. Native Godot 4.7.2 import, visual review, player route and multi-size screenshot validation remain pending.
