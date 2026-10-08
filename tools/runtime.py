#!/usr/bin/env python3
"""Launch or test the one pinned Godot project; never downloads on launch."""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
ERROR = re.compile(r"(?:^|\s)(?:ERROR:|SCRIPT ERROR:|SHADER ERROR:|Parse Error:|CHECK_FAIL|FOUNDATION_TIMEOUT)", re.M)


def clean_run(output: str, returncode: int) -> bool:
    return returncode == 0 and not ERROR.search(output)


def test_passed(output: str, returncode: int) -> bool:
    markers = re.findall(r"^FOUNDATION_PASS checks=(\d+) failures=(\d+)\s*$", output, re.M)
    return clean_run(output, returncode) and len(markers) == 1 and int(markers[0][0]) > 0 and markers[0][1] == '0'


def resolve_engine(value: str | None) -> str:
    candidate = value or os.environ.get('GODOT_BIN') or shutil.which('godot') or shutil.which('godot4')
    executable = shutil.which(candidate) if candidate else None
    if not executable:
        raise ValueError('Godot not found. Set GODOT_BIN to the pinned official binary; launch never installs it.')
    version = subprocess.run([executable, '--version'], capture_output=True, text=True, timeout=10, check=True).stdout.strip()
    lock = json.loads((ROOT / 'tools/engine_lock.json').read_text())
    if version != lock['version_output']:
        raise ValueError(f"Expected {lock['version_output']}, got {version!r}")
    return executable


def execute(command: list[str], report: Path, timeout: float, env: dict[str, str]) -> tuple[int, str]:
    report.parent.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    try:
        process = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 text=True, timeout=timeout, env=env)
        code, output = process.returncode, process.stdout
    except subprocess.TimeoutExpired as exc:
        output = exc.stdout or ''
        if isinstance(output, bytes):
            output = output.decode(errors='replace')
        code, output = 124, output + '\nRUNNER_TIMEOUT\n'
    except OSError as exc:
        code, output = 127, f'RUNNER_EXECUTION_ERROR: {exc}\n'
    report.write_text(f'COMMAND={command!r}\nEXIT_CODE={code}\nELAPSED_SECONDS={time.monotonic()-start:.3f}\n{output}', encoding='utf-8')
    print(output, end='')
    return code, output


def run_tests(engine: str, reports: Path, timeout: float) -> int:
    reports.mkdir(parents=True, exist_ok=True)
    summary = {'import_passed': False, 'test_passed': False, 'passed': False}
    # A fresh small project copy isolates caches, editor changes and user:// state.
    with tempfile.TemporaryDirectory(prefix='qingfeng-test-') as temporary:
        temp = Path(temporary)
        game = temp / 'game'
        shutil.copytree(ROOT / 'game', game, ignore=shutil.ignore_patterns('.godot', '__pycache__'))
        hashes = {p.relative_to(game).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in sorted(game.rglob('*')) if p.is_file()}
        (reports / 'source_hashes.json').write_text(json.dumps(hashes, indent=2))
        env = os.environ.copy()
        for key in ['HOME', 'USERPROFILE', 'APPDATA', 'LOCALAPPDATA', 'XDG_DATA_HOME', 'XDG_CONFIG_HOME', 'XDG_CACHE_HOME']:
            path = temp / key.lower()
            path.mkdir()
            env[key] = str(path)
        env['GODOT_SILENCE_ROOT_WARNING'] = '1'
        try:
            code, output = execute([engine, '--headless', '--path', str(game), '--editor', '--import', '--quit'], reports/'import.log', timeout, env)
            summary['import_passed'] = clean_run(output, code)
            if not summary['import_passed']:
                return 1
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/foundation_test.gd'], reports/'foundation.log', timeout, env)
            summary['test_passed'] = test_passed(output, code)
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/entry_pages_test.gd'], reports/'entry_pages.log', timeout, env)
            markers = re.findall(r'^PAGES_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['pages_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/core_contract_test.gd'], reports/'core_contract.log', timeout, env)
            markers = re.findall(r'^CORE_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['core_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/gameplay_domain_test.gd'], reports/'gameplay_domain.log', timeout, env)
            markers = re.findall(r'^GAMEPLAY_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['gameplay_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/world_layout_test.gd'], reports/'world_layout.log', timeout, env)
            markers = re.findall(r'^WORLD_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['world_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/receipt_persistence_test.gd'], reports/'receipt_persistence.log', timeout, env)
            markers = re.findall(r'^RECEIPT_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['receipt_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/farm_interaction_test.gd'], reports/'farm_interaction.log', timeout, env)
            markers = re.findall(r'^FARM_INTERACTION_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['farm_interaction_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/door_transition_test.gd'], reports/'door_transition.log', timeout, env)
            markers = re.findall(r'^DOOR_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['door_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/three_day_farm_loop_test.gd'], reports/'three_day_farm_loop.log', timeout, env)
            markers = re.findall(r'^THREE_DAY_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['three_day_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/storage_domain_test.gd'], reports/'storage_domain.log', timeout, env)
            markers = re.findall(r'^STORAGE_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['storage_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/storage_ui_test.gd'], reports/'storage_ui.log', timeout, env)
            markers = re.findall(r'^STORAGE_UI_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['storage_ui_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/economy_domain_test.gd'], reports/'economy_domain.log', timeout, env)
            markers = re.findall(r'^ECONOMY_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['economy_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/village_shop_route_test.gd'], reports/'village_shop_route.log', timeout, env)
            markers = re.findall(r'^VILLAGE_SHOP_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['village_shop_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            summary['passed'] = summary['test_passed'] and summary['pages_passed'] and summary['core_passed'] and summary['gameplay_passed'] and summary['world_passed'] and summary['receipt_passed'] and summary['farm_interaction_passed'] and summary['door_passed'] and summary['three_day_passed'] and summary['storage_passed'] and summary['storage_ui_passed'] and summary['economy_passed'] and summary['village_shop_passed']
            return 0 if summary['passed'] else 1
        finally:
            (reports/'summary.json').write_text(json.dumps(summary, indent=2))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['run', 'editor', 'test'])
    parser.add_argument('--godot')
    parser.add_argument('--report-dir', type=Path, default=ROOT/'reports/runtime')
    parser.add_argument('--timeout', type=float, default=60)
    args = parser.parse_args()
    if args.timeout <= 0:
        parser.error('--timeout must be positive')
    try:
        engine = resolve_engine(args.godot)
        if args.mode == 'test':
            return run_tests(engine, args.report_dir, args.timeout)
        # There are no imported image/font dependencies in the current foundation.
        # The editor owns future incremental imports; do not cold-import every launch.
        command = [engine, '--path', str(ROOT/'game')]
        if args.mode == 'editor':
            command += ['--editor', 'res://app/main.tscn']
        return subprocess.call(command)
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        print(f'RUNTIME_TOOL_ERROR: {exc}')
        return 2

if __name__ == '__main__':
    raise SystemExit(main())
