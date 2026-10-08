"""Checks proposed town PNG integrity. Does not confer visual or gameplay approval."""
from pathlib import Path
from PIL import Image
import hashlib,json
root=Path(__file__).resolve().parents[4]
meta=json.loads((root/'art/sources/chapter1/town/town_assets.json').read_text())
checks=[]
for asset in meta['assets']:
 source=root/asset['source_path']; runtime=root/asset['runtime_path']
 for path,key in [(source,'source_sha256'),(runtime,'runtime_sha256')]:assert hashlib.sha256(path.read_bytes()).hexdigest()==asset[key],str(path)
 im=Image.open(runtime).convert('RGBA');assert list(im.size)==asset['size_px'];assert set(im.getchannel('A').get_flattened_data())<={0,255}
 preview=Image.open(root/'art/reviews/chapter1/town'/f'{runtime.stem}_8x.png').convert('RGBA')
 assert preview.tobytes()==im.resize((im.width*8,im.height*8),Image.Resampling.NEAREST).tobytes()
 if asset['layer_paths']:
  reconstructed=Image.new('RGBA',im.size)
  for path in asset['layer_paths']:reconstructed.alpha_composite(Image.open(root/path).convert('RGBA'))
  assert reconstructed.tobytes()==im.tobytes(),f'{runtime.stem} layer reconstruction'
 checks.append({'asset_id':asset['asset_id'],'size_px':list(im.size),'binary_alpha':True,'hash_match':True,'exact_8x':True,'layer_reconstruction':bool(asset['layer_paths'])})
gate=Image.open(root/'game/assets/chapter1/town/stone_gate.png');assert gate.getpixel((32,48))[3]==0
floor=Image.open(root/'game/assets/chapter1/town/plaza_stone_16.png');assert floor.size==(16,16);assert floor.getchannel('A').getextrema()==(255,255)
repeat=Image.new('RGBA',(48,48))
for y in range(3):
 for x in range(3):repeat.paste(floor,(x*16,y*16))
repeat.resize((384,384),Image.Resampling.NEAREST).save(root/'art/reviews/chapter1/town/plaza_repeat_3x3_8x.png')
report={'result':'TOWN_PNG_QA_PASS','assets':checks,'transparent_arch':True,'plaza_3x3_preview':True,'scope':'File, alpha, metadata hash, nearest preview and layer reconstruction only. No movement/collision or user visual approval.'}
(root/'art/reviews/chapter1/town/png_qa.json').write_text(json.dumps(report,indent=2)+'\n')
print('TOWN_PNG_QA_PASS: 9 assets; 17 runtime PNGs; binary alpha; hashes; exact 8x; layer reconstruction; transparent arch')
