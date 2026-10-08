from PIL import Image
from pathlib import Path
import json,hashlib,math
src=Path('art/sources/chapter1/objects'); dest=Path('game/assets/chapter1/objects'); review=Path('art/reviews/chapter1/objects')
import re
jobs={}
for job_log in src.glob('jobs*.json'):
 for name,text in json.loads(job_log.read_text()).items():
  jobs[name]=re.search(r'^id: ([0-9a-f-]+)',text).group(1)
assets=[]
for path in sorted(src.glob('*_generated.png')):
 name=path.stem.removesuffix('_generated');im=Image.open(path).convert('RGBA'); box=im.getbbox(); w=math.ceil((box[2]-box[0]+4)/16)*16; h=math.ceil((box[3]-box[1]+4)/16)*16
 crop=im.crop(box); out=Image.new('RGBA',(w,h)); offset=((w-crop.width)//2,h-crop.height-2);out.paste(crop,offset);out.save(dest/f'{name}.png')
 row={'asset_id':f'asset.object.chapter1.{name}','runtime_path':str(dest/f'{name}.png'),'source_path':str(path),'source_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'sha256':hashlib.sha256((dest/f'{name}.png').read_bytes()).hexdigest(),'size_px':[w,h],'anchor_px':[w//2,h-2],'source_crop_px':list(box),'crop_offset_px':list(offset),'job_id':jobs[name],'reference_path':str(src/f'reference_{name}.png'),'reference_sha256':hashlib.sha256((src/f'reference_{name}.png').read_bytes()).hexdigest(),'alpha_values':sorted(set(out.getchannel('A').get_flattened_data())),'opaque_color_count':len(set(p for p in out.get_flattened_data() if p[3])),'review_status':'proposed','reviewer':None,'world_scale':1,'collision_owner':'WORLD; root footprint authored in scene; no collision baked into image','usage':'environment_only','license_note':'PixelLab generated under active account; not CC0; input project approved original map','drive_url':None,'processing':'tight alpha crop, integer centering with 2px bottom margin; no resampling'}
 out.resize((w*8,h*8),Image.Resampling.NEAREST).save(review/f'{name}_8x.png')
 if name.endswith('_tree'):
  split=int(h*.78); back=out.copy(); front=out.copy();back.paste((0,0,0,0),(0,0,w,split));front.paste((0,0,0,0),(0,split,w,h));back.save(dest/f'{name}_root.png');front.save(dest/f'{name}_crown.png'); row['layer_split_y_px']=split;row['layers']={'root':str(dest/f'{name}_root.png'),'crown':str(dest/f'{name}_crown.png')};row['layer_note']='Exact disjoint scanline split, recompose at same integer anchor; crown sprite uses world canopy depth, root sprite root YSort. Inspect cutoff before final acceptance.'
 assets.append(row)
for n in ['fence_post','fence_rails_h','fence_rails_v']:
 p=dest/f'{n}.png';im=Image.open(p);assets.append({'asset_id':f'asset.object.chapter1.{n}','runtime_path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'size_px':list(im.size),'anchor_px':[im.width//2,im.height],'source_path':str(src/'fence_generated.png'),'job_id':jobs['fence'],'review_status':'proposed','usage':'environment_only','processing':'exact native crop; rails_v rotated 90 degrees; geometry/light requires WORLD review'})
(dest/'object_metadata.json').write_text(json.dumps({'schema_version':1,'world_tile_px':16,'asset_review_status':'proposed','assets':assets},indent=2)+'\n')
print([(a['asset_id'],a['size_px']) for a in assets])
