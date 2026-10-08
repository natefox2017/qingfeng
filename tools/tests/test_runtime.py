"""Regression-result validation: a PASS line must never hide engine errors."""
import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('runtime', ROOT/'tools/runtime.py')
runtime = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runtime)

class RuntimeTests(unittest.TestCase):
    def test_valid_result(self):
        self.assertTrue(runtime.test_passed('FOUNDATION_PASS checks=12 failures=0\n', 0))

    def test_failures_and_exit(self):
        for text, code in [('FOUNDATION_PASS checks=12 failures=1\n', 0),
                           ('FOUNDATION_PASS checks=12 failures=0\n', 1),
                           ('FOUNDATION_PASS checks=0 failures=0\n', 0),
                           ('not FOUNDATION_PASS checks=12 failures=0\n', 0),
                           ('FOUNDATION_PASS checks=12 failures=0\n'*2, 0)]:
            self.assertFalse(runtime.test_passed(text, code))

    def test_engine_errors_override_pass(self):
        for marker in ['ERROR:', 'SCRIPT ERROR:', 'SHADER ERROR:', 'Parse Error:', 'CHECK_FAIL', 'FOUNDATION_TIMEOUT']:
            text = marker+' bad\nFOUNDATION_PASS checks=12 failures=0\n'
            self.assertFalse(runtime.test_passed(text, 0), marker)
            self.assertFalse(runtime.clean_run(text, 0), marker)

    def test_timeout_is_reported(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)/'nested/timeout.log'
            code, output = runtime.execute([sys.executable, '-S', '-c', 'import time;time.sleep(10)'], path, .05, os.environ.copy())
            self.assertEqual(code, 124)
            self.assertTrue(path.is_file())
            self.assertIn('RUNNER_TIMEOUT', output)
            self.assertIn('ELAPSED_SECONDS=', path.read_text())

    def test_asset_import_only_when_cache_is_missing_or_stale(self):
        with tempfile.TemporaryDirectory() as temporary:
            game = Path(temporary)
            assets = game / 'assets' / 'phase0'
            assets.mkdir(parents=True)
            self.assertFalse(runtime.needs_asset_import(game))  # old text-only fixture

            sprite = assets / 'player_4dir.png'
            sprite.write_bytes(b'png source fixture')
            self.assertTrue(runtime.needs_asset_import(game))

            cache = game / '.godot' / 'imported'
            cache.mkdir(parents=True)
            imported = cache / 'player_4dir.png-abcdef.ctex'
            imported.write_bytes(b'imported fixture')
            os.utime(sprite, (5, 5))
            os.utime(imported, (10, 10))
            self.assertFalse(runtime.needs_asset_import(game))

            os.utime(sprite, (15, 15))
            self.assertTrue(runtime.needs_asset_import(game))

    def test_import_failure_blocks_game_launch(self):
        with tempfile.TemporaryDirectory() as temporary:
            game = Path(temporary) / 'game'
            assets = game / 'assets'
            assets.mkdir(parents=True)
            (assets / 'new.png').write_bytes(b'new texture')
            with patch.object(runtime, 'execute', return_value=(0, 'ERROR: failed import')) as mocked:
                result = runtime.ensure_assets_imported('godot', game, Path(temporary)/'reports', 60)
                self.assertFalse(result)
                self.assertEqual(mocked.call_args.args[0], [
                    'godot', '--headless', '--path', str(game), '--editor', '--import', '--quit'
                ])
            with patch.object(runtime, 'execute', return_value=(0, '')) as mocked:
                self.assertTrue(runtime.ensure_assets_imported('godot', game, Path(temporary)/'reports', 60))
                self.assertEqual(mocked.call_count, 1)

    def _fake_engine(self, path: Path) -> Path:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/sh\nexit 0\n")
        path.chmod(0o755)
        return path

    def test_auto_discovers_ac_path_without_configuring_godot_bin(self):
        from types import SimpleNamespace
        with tempfile.TemporaryDirectory(prefix="qingfeng-ac-godot-") as tmp:
            root = Path(tmp) / "checkout"
            (root / "tools").mkdir(parents=True)
            (root / "tools" / "engine_lock.json").write_text(
                (ROOT / "tools" / "engine_lock.json").read_text()
            )
            executable = self._fake_engine(Path(tmp) / "ac-bin" / "godot4")
            version = "4.7.2.stable.official.ed1daf0bf"
            with patch.object(runtime, "ROOT", root), \
                    patch.dict(os.environ, {"GODOT_BIN": "", "PATH": str(executable.parent)}), \
                    patch.object(runtime.subprocess, "run", return_value=SimpleNamespace(stdout=version)):
                self.assertEqual(runtime.resolve_engine(None), str(executable))

    def test_auto_skips_incompatible_installed_godot_in_favor_of_correct_one(self):
        from types import SimpleNamespace
        with tempfile.TemporaryDirectory(prefix="qingfeng-ac-godot-") as tmp:
            root = Path(tmp) / "checkout"
            (root / "tools").mkdir(parents=True)
            lock = (ROOT / "tools" / "engine_lock.json").read_text()
            (root / "tools" / "engine_lock.json").write_text(lock)
            wrong = self._fake_engine(root / ".local" / "godot" / "Godot_v4.7.2-stable_linux.x86_64")
            correct = self._fake_engine(Path(tmp) / "ac-bin" / "godot")
            calls = []

            def version_probe(args, **kwargs):
                calls.append(args[0])
                return SimpleNamespace(stdout=(
                    "4.6.stable.official.fake" if args[0] == str(wrong)
                    else "4.7.2.stable.official.ed1daf0bf"
                ))

            with patch.object(runtime, "ROOT", root), \
                    patch.dict(os.environ, {"GODOT_BIN": "", "PATH": str(correct.parent)}), \
                    patch.object(runtime.subprocess, "run", side_effect=version_probe):
                self.assertEqual(runtime.resolve_engine(None), str(correct))
            self.assertEqual(calls, [str(wrong), str(correct)])

    def test_explicit_godot_path_stays_authoritative(self):
        from types import SimpleNamespace
        with tempfile.TemporaryDirectory(prefix="qingfeng-ac-godot-") as tmp:
            wrong = self._fake_engine(Path(tmp) / "wrong-godot")
            correct = self._fake_engine(Path(tmp) / "bin" / "godot4")
            with patch.dict(os.environ, {"GODOT_BIN": "", "PATH": str(correct.parent)}), \
                    patch.object(runtime.subprocess, "run", return_value=SimpleNamespace(stdout="4.6.stable")):
                with self.assertRaisesRegex(ValueError, "Specified Godot"):
                    runtime.resolve_engine(str(wrong))

    def test_default_reports_found_but_incompatible_version(self):
        from types import SimpleNamespace
        with tempfile.TemporaryDirectory(prefix="qingfeng-ac-godot-") as tmp:
            root = Path(tmp) / "checkout"
            (root / "tools").mkdir(parents=True)
            (root / "tools" / "engine_lock.json").write_text(
                (ROOT / "tools" / "engine_lock.json").read_text()
            )
            wrong = self._fake_engine(Path(tmp) / "ac-bin" / "godot")
            with patch.object(runtime, "ROOT", root), \
                    patch.dict(os.environ, {"GODOT_BIN": "", "PATH": str(wrong.parent)}), \
                    patch.object(runtime.subprocess, "run", return_value=SimpleNamespace(stdout="4.6.stable")):
                with self.assertRaisesRegex(ValueError, r"none matches required.*Found"):
                    runtime.resolve_engine(None)

    def test_known_local_ac_install_dirs_are_considered(self):
        from types import SimpleNamespace
        with tempfile.TemporaryDirectory(prefix="qingfeng-ac-godot-") as tmp:
            root = Path(tmp) / "checkout"
            (root / "tools").mkdir(parents=True)
            (root / "tools" / "engine_lock.json").write_text(
                (ROOT / "tools" / "engine_lock.json").read_text()
            )
            ac_home = Path(tmp) / "ac-home"
            executable = self._fake_engine(ac_home / ".local" / "bin" / "Godot")
            with patch.object(runtime, "ROOT", root), \
                    patch.object(runtime.Path, "home", return_value=ac_home), \
                    patch.dict(os.environ, {"GODOT_BIN": "", "PATH": str(Path(tmp) / "no-bin")}), \
                    patch.object(runtime.subprocess, "run",
                                 return_value=SimpleNamespace(stdout="4.7.2.stable.official.ed1daf0bf")):
                self.assertEqual(runtime.resolve_engine(None), str(executable))

    def test_declared_runtime_entry(self):
        import json
        config = json.loads((ROOT/'project.json').read_text())
        self.assertEqual(config['main_scene'], 'res://app/main.tscn')
        self.assertTrue((ROOT/'game/app/main.tscn').is_file())
        self.assertEqual(config['engine']['version'], '4.7.2')

if __name__ == '__main__':
    unittest.main()
