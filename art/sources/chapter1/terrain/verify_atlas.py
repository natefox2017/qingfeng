"""Check actual PNG hashes, slicing, palette, compatible seams and exact 8x pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[4]
metadata = json.loads((root / "game/assets/chapter1/terrain/grass_dirt_atlas.json").read_text())
atlas_path = root / metadata["source_path"]
assert hashlib.sha256(atlas_path.read_bytes()).hexdigest() == metadata["source_sha256"]
atlas = Image.open(atlas_path).convert("RGBA")
assert atlas.size == tuple(metadata["size_px"])
assert len(set(atlas.get_flattened_data())) == metadata["palette_size"]
assert {c[3] for c in atlas.get_flattened_data()} == {0, 255}
tiles = {}
for region in metadata["regions"]:
    x, y, w, h = region["rect_px"]
    source = root / region["source_png"]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == region["source_sha256"]
    tile = Image.open(source).convert("RGBA")
    assert tile.size == (16, 16) and tile.tobytes() == atlas.crop((x, y, x+w, y+h)).tobytes()
    tiles[region["region_id"]] = tile
for name in ("grass_base", "grass_light", "grass_dark"):
    t = tiles[name]
    assert t.crop((0, 0, 16, 1)).tobytes() == t.crop((0, 15, 16, 16)).tobytes()
    assert t.crop((0, 0, 1, 16)).tobytes() == t.crop((15, 0, 16, 16)).tobytes()
checks = 0
for a in range(16):
    for b in range(16):
        t, u = tiles[f"dirt_mask_{a:02}"], tiles[f"dirt_mask_{b:02}"]
        if bool(a & 2) == bool(b & 8):
            assert t.crop((15, 0, 16, 16)).tobytes() == u.crop((0, 0, 1, 16)).tobytes()
            checks += 1
        if bool(a & 4) == bool(b & 1):
            assert t.crop((0, 15, 16, 16)).tobytes() == u.crop((0, 0, 16, 1)).tobytes()
            checks += 1
preview = Image.open(root / "art/reviews/chapter1/terrain/grass_dirt_atlas_8x.png").convert("RGBA")
assert preview.tobytes() == atlas.resize((512, 640), Image.Resampling.NEAREST).tobytes()
print(f"PIXEL_QA_PASS tiles={len(tiles)} compatible_edges={checks} colors={metadata['palette_size']} nearest_8x=exact")

for family in ("soil_surfaces", "ground_decor"):
    extra = json.loads((root / f"game/assets/chapter1/terrain/{family}.json").read_text())
    source = root / extra["source_png"]
    assert hashlib.sha256(source.read_bytes()).hexdigest() == extra["source_sha256"]
    sheet = Image.open(source).convert("RGBA")
    assert sheet.size == (64, 16)
    assert sheet.tobytes() == Image.open(root / extra["source_path"]).convert("RGBA").tobytes()
    assert {c[3] for c in sheet.get_flattened_data()} <= {0, 255}
    for region in extra["regions"]:
        tile_path = root / region["source_png"]
        assert hashlib.sha256(tile_path.read_bytes()).hexdigest() == region["source_sha256"]
        x, y, w, h = region["rect_px"]
        tile = sheet.crop((x, y, x+w, y+h))
        assert tile.tobytes() == Image.open(tile_path).convert("RGBA").tobytes()
        if family == "soil_surfaces":
            assert tile.crop((0, 0, 16, 1)).tobytes() == tile.crop((0, 15, 16, 16)).tobytes()
            assert tile.crop((0, 0, 1, 16)).tobytes() == tile.crop((15, 0, 16, 16)).tobytes()
        else:
            assert tile.getbbox() is not None
            assert all(tile.getpixel((i, 0))[3] == 0 and tile.getpixel((i, 15))[3] == 0 for i in range(16))
    preview = Image.open(root / f"art/reviews/chapter1/terrain/{family}_8x.png").convert("RGBA")
    assert preview.tobytes() == sheet.resize((512, 128), Image.Resampling.NEAREST).tobytes()
    print(f"EXTRA_PIXEL_QA_PASS {family} regions=4 alpha=binary nearest_8x=exact")
