"""Checker tests are not evidence of a playable game or a verified image."""
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import struct
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("scaffold", ROOT / "tools/check_scaffold.py")
scaffold = importlib.util.module_from_spec(spec)
spec.loader.exec_module(scaffold)

class ScaffoldTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        for name in ["docs", "game", "art", "templates", "schemas", ".github"]:
            shutil.copytree(ROOT / name, self.root / name, ignore=shutil.ignore_patterns("__pycache__", ".godot"))
        for name in ["README.md", "AGENTS.md", "project.json", "CONTRIBUTING.md", "SECURITY.md"]:
            shutil.copy2(ROOT / name, self.root / name)
        # Documentation links refer to the checkers, but no nested .git or cache is copied.
        shutil.copytree(ROOT / "tools", self.root / "tools", ignore=shutil.ignore_patterns("__pycache__", ".godot"))

    def tearDown(self):
        self.temp.cleanup()

    def write_json(self, name, value):
        (self.root / name).write_text(json.dumps(value), encoding="utf-8")

    def errors(self):
        return scaffold.check(self.root)

    def fixture(self, kind="icon"):
        path = self.root / "game/assets/test.png"
        # Only a header fixture. Native image decoding is deliberately NOT claimed.
        path.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\0\0\0\rIHDR" + struct.pack(">II", 16, 16))
        license_path = self.root / "game/assets/license.txt"
        license_path.write_text("Synthetic test fixture; not an imported asset")
        return {"kind":kind,"asset_id":"asset.test","runtime_path":"game/assets/test.png",
                "sha256":hashlib.sha256(path.read_bytes()).hexdigest(),"source_url":"https://example.invalid/fixture",
                "source_version":"test","license_id":"test-only","license_path":"game/assets/license.txt",
                "size_px":{"width":16,"height":16},"source_anchor_px":{"x":8,"y":16},
                "review_status":"validated","reviewer":None,"evidence_paths":[],"animations":[]}

    def test_canonical_remote_spellings(self):
        self.assertTrue(scaffold.is_canonical_remote("https://github.com/natefox2017/qingfeng"))
        self.assertTrue(scaffold.is_canonical_remote("git@github.com:natefox2017/qingfeng.git"))
        self.assertFalse(scaffold.is_canonical_remote("https://github.com/natefox2017/" + "qingfeng-"))
        self.assertFalse(scaffold.is_canonical_remote("https://example.invalid/natefox2017/qingfeng"))

    def test_clean_scaffold(self):
        self.assertEqual(self.errors(), [])

    def test_wrong_repository(self):
        c = scaffold.load_json(self.root / "project.json")
        c["repository_full_name"] = "other/repository"
        self.write_json("project.json", c)
        self.assertIn("wrong canonical repository", self.errors())

    def test_stale_link(self):
        (self.root / "docs/extra.md").write_text("https://github.com/natefox2017/" + "qingfenggu/issues/39")
        self.assertTrue(any("stale repository" in e for e in self.errors()))

    def test_broken_local_link(self):
        (self.root / "docs/extra.md").write_text("[missing](missing.md)")
        self.assertTrue(any("broken local link" in e for e in self.errors()))

    def test_duplicate_json_key(self):
        (self.root / "art/jobs.json").write_text('{"jobs":[],"jobs":[]}')
        self.assertTrue(any("duplicate key" in e for e in self.errors()))

    def test_stage_cannot_claim_runtime(self):
        c = scaffold.load_json(self.root / "project.json")
        c["stage"] = "scaffold"
        c["is_runnable"] = False
        c["main_scene"] = None
        self.write_json("project.json", c)
        (self.root / "game/project.godot").write_text("config_version=5")
        self.assertIn("stage contradicts runtime presence", self.errors())

    def test_task_cycle(self):
        t = scaffold.load_json(self.root / "docs/tasks.json")
        t["tasks"][0]["delivery_depends_on"] = ["N02"]
        self.assertIn("cyclic delivery dependencies", scaffold.check_tasks(t))

    def test_wrong_issue_url(self):
        t = scaffold.load_json(self.root / "docs/tasks.json")
        t["tasks"][0]["issue_url"] = "https://github.com/other/repo/issues/2"
        self.assertTrue(any("wrong issue URL" in e for e in scaffold.check_tasks(t)))

    def test_duplicate_progress(self):
        t = scaffold.load_json(self.root / "docs/tasks.json")
        t["tasks"][0]["status"] = "done"
        self.assertTrue(any("duplicate progress" in e for e in scaffold.check_tasks(t)))

    def test_asset_mismatch(self):
        r = self.fixture()
        r["sha256"] = "0" * 64
        self.assertTrue(any("bytes changed" in e for e in scaffold.check_assets(self.root, {"schema_version":1,"assets":[r]})))

    def test_missing_asset_review(self):
        r = self.fixture()
        r["review_status"] = "accepted"
        self.assertTrue(any("no reviewer" in e for e in scaffold.check_assets(self.root, {"schema_version":1,"assets":[r]})))

    def test_path_traversal(self):
        r = self.fixture()
        r["license_path"] = "../../outside-license.txt"
        self.assertTrue(any("escaping" in e for e in scaffold.check_assets(self.root, {"schema_version":1,"assets":[r]})))

    def test_contact_outside_animation(self):
        r = self.fixture()
        r["animations"]=[{"animation_id":"till","direction":"south","frame_count":2,
            "frame_durations_msec":[100,100],"contact_frame":2,"contact_offset_msec":0,"is_looping":False}]
        self.assertTrue(any("outside frame" in e for e in scaffold.check_assets(self.root, {"schema_version":1,"assets":[r]})))

    def test_boolean_is_not_dimension(self):
        r = self.fixture()
        r["size_px"]["width"] = True
        self.assertTrue(any("dimensions" in e for e in scaffold.check_assets(self.root, {"schema_version":1,"assets":[r]})))

    def test_font_has_no_pixel_anchor(self):
        r = self.fixture("font")
        self.assertTrue(any("font must not" in e for e in scaffold.check_assets(self.root, {"schema_version":1,"assets":[r]})))

    def test_unregistered_asset(self):
        self.fixture()
        self.assertTrue(any("unregistered" in e for e in self.errors()))

if __name__ == "__main__":
    unittest.main()
