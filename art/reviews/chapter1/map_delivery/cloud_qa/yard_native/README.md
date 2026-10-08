# Roomier playable yard and reusable border clusters

The anchor correction revealed dog/façade, kennel/fence and coop/workbench overlap. The south yard fence moved 64px south and its side rails extended; unchanged house door, player spawn and six plot markers are retained. Dog/kennel/bench/chickens move as their independent scene instances with existing collision ownership. Existing terrain is repainted through TileMapLayer.set_cells_terrain_connect for the door→south gate→field corridor; no runtime map regeneration.

The dog/chickens remain static environment instances. No wandering/following/animal gameplay was added or claimed. A reusable two-bush PackedScene uses the same existing PixelLab bush asset without resampling, new generated textures or changed IDs; both child collision footprints move with the cluster. Ten farm and six village placements add border structure, not a whole-map image. Cluster contact shadows/variety and wider map density still need refinement, and user visual approval remains pending.

Godot 4.7.2, isolated XDG, all exit 0:
- chapter1_yard_layout_test.gd: 30/0, opaque-image bounds separate dog/house, kennel/well/fence and coop/bench; actual physics queries place static animals on clear ground; stable spawn/door/six plots.
- chapter1_object_anchor_test.gd: 316/0 including fixed membership and new instances.
- chapter1_map_editability_test.gd: 68/0.
- chapter1_map_playability_test.gd: 447/0 actual Input/physics path including farming, orchard, bridge both ways, shops/workshop, save/load.

Commands: `Godot --headless --path game --script res://tests/<test-name>.gd`.
Native captures: `Godot --audio-driver Dummy --path game --script res://tests/chapter1_map_native_capture.gd -- <absolute-output>`; exit 0, 12 original PNGs at 1280×720, 1920×1080 and 1366×768 (last is 1280×720 integer content; full-window evidence is separate). Farmhouse native refinement is the preceding art commit. All screenshots remain proposed.
