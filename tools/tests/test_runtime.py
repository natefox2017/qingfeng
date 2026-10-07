"""Regression-result validation: a PASS line must never hide engine errors."""
import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import unittest

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

    def test_declared_runtime_entry(self):
        import json
        config = json.loads((ROOT/'project.json').read_text())
        self.assertEqual(config['main_scene'], 'res://app/main.tscn')
        self.assertTrue((ROOT/'game/app/main.tscn').is_file())
        self.assertEqual(config['engine']['version'], '4.7.2')

if __name__ == '__main__':
    unittest.main()
