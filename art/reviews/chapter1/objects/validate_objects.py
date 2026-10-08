from pathlib import Path
from PIL import Image
import hashlib,json
p=Path('game/assets/chapter1/objects/object_metadata.json');m=json.loads(p.read_text());checked=set()
for a in m['assets']:
 path=Path(a['runtime_path']);im=Image.open(path).convert('RGBA');assert list(im.size)==a['size_px'],path;assert hashlib.sha256(path.read_bytes()).hexdigest()==a['sha256'],path;assert set(im.getchannel('A').get_flattened_data())=={0,255},path;checked.add(str(path))
 for field,hash_field in [('source_path','source_sha256'),('original_source_path','original_source_sha256'),('reference_path','reference_sha256'),('palette_reference_path','palette_reference_sha256')]:
  if hash_field in a:assert hashlib.sha256(Path(a[field]).read_bytes()).hexdigest()==a[hash_field],a[field]
 if 'layers' in a:
  stack=Image.new('RGBA',im.size)
  for path in a['layers'].values():
   layer=Image.open(path).convert('RGBA');assert layer.size==im.size,path;assert set(layer.getchannel('A').get_flattened_data())=={0,255},path;stack=Image.alpha_composite(stack,layer);checked.add(path)
  assert stack.tobytes()==im.tobytes(),a['asset_id']
 if 'crop_status' in a:assert a['size_px']==[32,32] and a['anchor_px']==[16,32] and a['opaque_color_count']<=24,a
 assert a['review_status']=='proposed',a
original=Image.open('game/assets/phase0/farmhouse.png').convert('RGBA');blue=Image.open('game/assets/chapter1/objects/farmhouse_blue.png').convert('RGBA');assert original.getchannel('A').tobytes()==blue.getchannel('A').tobytes();assert original.crop((0,85,192,152)).tobytes()==blue.crop((0,85,192,152)).tobytes()
assert not Path('game/assets/chapter1/objects/radish.png').exists()
print(json.dumps({'metadata_assets':len(m['assets']),'runtime_png_checked':len(checked),'alpha_binary':True,'layer_recomposition_exact':True,'farmhouse_nonroof_unchanged':True,'crop_canvas_anchor_shared':True,'review_status':'proposed'},indent=2))
