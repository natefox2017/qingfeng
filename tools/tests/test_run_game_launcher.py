"""Exercise the root shell wrapper without launching a user's game or save."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SH = shutil.which("sh")


@unittest.skipUnless(SH, "POSIX shell required")
class RunGameLauncherTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="qingfeng-launcher-")
        self.home = Path(self.temporary.name)
        self.project = self.home / "checkout with spaces"
        (self.project / "tools").mkdir(parents=True)
        self.script = self.project / "run_game.sh"
        shutil.copy2(ROOT / "run_game.sh", self.script)
        (self.project / "tools/runtime.py").write_text("# delegation fixture\n")
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.record = self.home / "calls.json"
        interpreter = self.bin / "python3"
        interpreter.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "Path(os.environ['LAUNCHER_RECORD']).write_text(json.dumps("
            "{'args':sys.argv[1:], 'cwd':os.getcwd(), 'godot':os.environ.get('GODOT_BIN')}))\n"
            "raise SystemExit(int(os.environ.get('LAUNCHER_EXIT', '0')))\n"
        )
        interpreter.chmod(0o755)
        os.symlink(shutil.which("dirname"), self.bin / "dirname")
        self.env = {**os.environ, "PATH": str(self.bin), "LAUNCHER_RECORD": str(self.record)}
        self.env.pop("GODOT_BIN", None)

    def tearDown(self):
        self.temporary.cleanup()

    def launch(self, *args, via_shell=False):
        command = ([SH] if via_shell else []) + [str(self.script), *args]
        return subprocess.run(command, cwd=self.home, env=self.env,
                              capture_output=True, text=True, timeout=10)

    def test_executable_and_shell_syntax(self):
        self.assertEqual((ROOT / "run_game.sh").stat().st_mode & 0o111, 0o111)
        result = subprocess.run([SH, "-n", str(self.script)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_outside_spaced_checkout_and_exact_arguments(self):
        args = ["--godot", "/fake/Godot App/bin;not-a-command", ""]
        result = self.launch(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        record = json.loads(self.record.read_text())
        self.assertEqual(record["args"], [str(self.project / "tools/runtime.py"), "run", *args])
        self.assertEqual(record["cwd"], str(self.home))

    def test_can_use_sh_and_preserves_environment(self):
        self.env["GODOT_BIN"] = "/fake/Godot App/bin"
        result = self.launch(via_shell=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.record.read_text())["godot"], self.env["GODOT_BIN"])

    def test_phase0_test_and_editor_flags_are_routed(self):
        for flag, expected in [
            ("--test", "phase0"),
            ("--test-all", "test"),
            ("--editor", "editor"),
        ]:
            with self.subTest(flag=flag):
                result = self.launch(flag, "--godot", "/fake/Godot App/bin")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    json.loads(self.record.read_text())["args"],
                    [str(self.project / "tools/runtime.py"), expected, "--godot", "/fake/Godot App/bin"],
                )

    def test_capture_requires_exactly_one_output_directory(self):
        directory = str(self.home / "screens with spaces")
        result = self.launch("--capture", directory)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            json.loads(self.record.read_text())["args"],
            [str(self.project / "tools/runtime.py"), "capture", "--capture-dir", directory],
        )
        self.record.unlink()
        missing = self.launch("--capture")
        self.assertEqual(missing.returncode, 2)
        self.assertFalse(self.record.exists())
        self.assertIn("--capture", missing.stderr)

    def test_preserves_exit_code(self):
        self.env["LAUNCHER_EXIT"] = "23"
        self.assertEqual(self.launch().returncode, 23)

    def test_missing_python_reports_dependency(self):
        (self.bin / "python3").unlink()
        result = self.launch()
        self.assertEqual(result.returncode, 127)
        self.assertIn("Python 3", result.stderr)
        self.assertFalse(self.record.exists())

    def test_missing_runtime_does_not_run_another_checkout(self):
        (self.project / "tools/runtime.py").unlink()
        result = self.launch()
        self.assertEqual(result.returncode, 2)
        self.assertIn("tools/runtime.py", result.stderr)
        self.assertFalse(self.record.exists())

    def test_real_runtime_help_needs_no_engine(self):
        shutil.copy2(ROOT / "tools/runtime.py", self.project / "tools/runtime.py")
        (self.bin / "python3").unlink()
        os.symlink(sys.executable, self.bin / "python3")
        result = self.launch("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--godot", result.stdout)

    def test_real_runtime_delegates_version_check_and_main_entry(self):
        for name in ["runtime.py", "engine_lock.json"]:
            shutil.copy2(ROOT / "tools" / name, self.project / "tools" / name)
        (self.bin / "python3").unlink()
        os.symlink(sys.executable, self.bin / "python3")
        version = json.loads((ROOT / "tools/engine_lock.json").read_text())["version_output"]
        engine = self.home / "fake Godot"
        engine.write_text(
            f"#!{sys.executable}\n"
            "import json, os, sys\n"
            "from pathlib import Path\n"
            "if sys.argv[1:] == ['--version']:\n"
            f"    print({version!r})\n"
            "else:\n"
            "    Path(os.environ['LAUNCHER_RECORD']).write_text(json.dumps(sys.argv[1:]))\n"
            "    raise SystemExit(19)\n"
        )
        engine.chmod(0o755)
        result = self.launch("--godot", str(engine))
        self.assertEqual(result.returncode, 19, result.stdout + result.stderr)
        self.assertEqual(json.loads(self.record.read_text()), ["--path", str(self.project / "game")])


if __name__ == "__main__":
    unittest.main()
