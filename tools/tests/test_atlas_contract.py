import copy
import hashlib
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest
ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('atlas', ROOT / 'tools/atlas_contract.py')
atlas = importlib.util.module_from_spec(spec); spec.loader.exec_module(atlas)

class AtlasTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.root = Path(self.temp.name)
        p = self.root / 'game/assets/fixture.png';p.parent.mkdir(parents=True)
        p.write_bytes(b'\x89PNG\r\n\x1a\n'+b'\0\0\0\rIHDR'+struct.pack('>II', 64, 32))
        self.data = {'schema_version':1, 'source_path':'game/assets/fixture.png',
            'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(), 'size_px':[64,32],
            'regions':[{'region_id':'prep','rect_px':[0,0,32,32],'anchor_px':[16,28]},
                       {'region_id':'contact','rect_px':[32,0,32,32],'anchor_px':[16,28]}],
            'animations':[{'action':'till','region_ids':['prep','contact'], 'durations_msec':[100,120],
                           'contact':{'frame':1,'offset_msec':20},'is_looping':False}]}
    def tearDown(self): self.temp.cleanup()
    def test_valid_header_contract(self): self.assertEqual(atlas.validate(self.data,self.root),[])
    def test_changed_hash(self):
        self.data['source_sha256']='0'*64;self.assertTrue(atlas.validate(self.data,self.root))
    def test_rect_out_of_bounds(self):
        self.data['regions'][1]['rect_px'][0]=33;self.assertTrue(atlas.validate(self.data,self.root))
    def test_duplicate_region(self):
        self.data['regions'][1]['region_id']='prep';self.assertTrue(atlas.validate(self.data,self.root))
    def test_anchor_drift(self):
        self.data['regions'][1]['anchor_px'][1]=27;self.assertTrue(atlas.validate(self.data,self.root))
    def test_contact_bounds(self):
        self.data['animations'][0]['contact']['offset_msec']=120;self.assertTrue(atlas.validate(self.data,self.root))
    def test_tool_action_without_contact(self):
        self.data['animations'][0]['contact']=None;self.assertTrue(atlas.validate(self.data,self.root))
    def test_nine_patch_center(self):
        self.data['regions'][0]['nine_patch_px']=[16,4,16,4];self.assertTrue(atlas.validate(self.data,self.root))
    def test_boolean_is_not_dimension(self):
        self.data['size_px'][0]=True;self.assertTrue(atlas.validate(self.data,self.root))
    def test_source_escape(self):
        self.data['source_path']='game/assets/../../outside.png';self.assertTrue(atlas.validate(self.data,self.root))
    def test_emit_no_overwrite(self):
        target=self.root/'regions';atlas.emit(self.data,target,self.root)
        self.assertIn('Rect2(32, 0, 32, 32)',(target/'contact.tres').read_text())
        with self.assertRaises(ValueError):atlas.emit(self.data,target,self.root)
    def test_duplicate_json_key(self):
        p=self.root/'bad.json';p.write_text('{"a":1,"a":2}')
        with self.assertRaises(ValueError):atlas.load(p)

if __name__ == '__main__': unittest.main()
