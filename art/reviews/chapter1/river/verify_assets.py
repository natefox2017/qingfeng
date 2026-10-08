"""Offline file/rect/seam checks; does not claim runtime or visual acceptance."""
import hashlib
import json
from pathlib import Path
from PIL import Image

repo = Path(__file__).resolve().parents[4]
metadata = json.loads((repo / 'art/sources/chapter1/river/metadata.json').read_text())
report = []
for asset in metadata['assets']:
    path = repo / asset['runtime_path']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == asset['sha256'], path
    image = Image.open(path)
    assert image.mode == 'RGBA', path
    assert list(image.size) == asset['size_px'], path
    source = Image.open(repo / asset['source_crop']['path'])
    x, y, w, h = asset['source_crop']['rect']
    assert x >= 0 and y >= 0 and x + w <= source.width and y + h <= source.height, path
    assert image.width % 16 == 0 and image.height % 16 == 0, path
    alpha = sorted({value for count, value in image.getchannel('A').getcolors(256)})
    report.append({'asset_id': asset['asset_id'], 'size_px': list(image.size), 'colors': len(image.getcolors(100000)), 'alpha_values': alpha, 'sha256': asset['sha256']})
water = Image.open(repo / 'game/assets/chapter1/river/water_tile.png')
assert all(water.getpixel((0, y)) == water.getpixel((15, y)) for y in range(16))
assert all(water.getpixel((x, 0)) == water.getpixel((x, 15)) for x in range(16))
animation = Image.open(repo / 'game/assets/chapter1/river/water_animation.png')
a, b = animation.crop((0, 0, 16, 16)), animation.crop((16, 0, 32, 16))
assert a.tobytes() == water.tobytes() and a.tobytes() != b.tobytes()
assert all(b.getpixel((0, y)) == b.getpixel((15, y)) for y in range(16))
assert all(b.getpixel((x, 0)) == b.getpixel((x, 15)) for x in range(16))
assert metadata['generations_submitted'] <= metadata['generation_budget']
print(json.dumps({'assets_checked': len(report), 'water_edge_pairs': 64, 'water_frames_distinct': True, 'ordinary_generations': metadata['generations_submitted'], 'assets': report}, indent=2))
