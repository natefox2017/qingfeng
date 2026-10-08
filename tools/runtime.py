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


def _installed_engine_candidates(lock: dict) -> list[str]:
    """Discover already installed Godot binaries without installing anything.

    Agent/AC desktops may put Godot outside PATH. Keep the search finite and
    inspect only common executable locations and Godot-named install folders.
    """
    release = lock['version']
    linux_binary = lock['linux_x86_64']['executable']
    names = (
        "godot", "godot4", "Godot", "Godot4",
        "godot-mono", "godot4-mono",
        linux_binary, "Godot_v" + release + "-stable_linux.x86_64",
        "Godot_v" + release + "-stable_linux.x86_64_console",
        "Godot_v" + release + "-stable_macos.universal",
        "Godot.exe", "Godot_v" + release + "-stable_win64.exe",
    )
    home = Path.home()
    locations = [
        ROOT / ".local" / "godot",
        ROOT / ".local" / "bin",
        home / ".local" / "bin",
        home / "bin",
        home / "Applications",
        home / "apps",
        home / "tools",
        Path("/usr/local/bin"),
        Path("/usr/bin"),
        Path("/usr/local/games"),
        Path("/opt/godot"),
        Path("/opt/godot/bin"),
        Path("/opt/Godot"),
        Path("/usr/local/share/godot"),
        Path("/snap/bin"),
        Path("/Applications"),
    ]
    candidates: list[str] = []
    seen: set[str] = set()

    def offer(path: str | Path | None) -> None:
        if not path:
            return
        candidate = str(path)
        normalized = os.path.normcase(os.path.abspath(os.path.expanduser(candidate)))
        if normalized in seen:
            return
        seen.add(normalized)
        candidates.append(candidate)

    # A pinned repository-local engine takes priority, then every PATH name.
    offer(ROOT / ".local" / "godot" / linux_binary)
    for name in names:
        offer(shutil.which(name))

    for folder in locations:
        for name in names:
            offer(folder / name)
        offer(folder / "Godot.app" / "Contents" / "MacOS" / "Godot")

    # Handle desktop installers such as /opt/Godot_4.7.2/ without recursively
    # crawling an entire home directory or accidentally finding an old project.
    for parent in (Path("/opt"), home / "Applications", home / ".local" / "share"):
        if not parent.is_dir():
            continue
        try:
            children = sorted(
                (p for p in parent.iterdir() if "godot" in p.name.lower()),
                key=lambda p: p.name,
            )[:40]
        except OSError:
            continue
        for item in children:
            if item.is_file():
                offer(item)
            else:
                for subpath in (
                    "godot", "godot4", "Godot", linux_binary,
                    "bin/godot", "bin/godot4", "Contents/MacOS/Godot",
                ):
                    offer(item / subpath)
    return candidates


def resolve_engine(value: str | None) -> str:
    lock = json.loads((ROOT / 'tools/engine_lock.json').read_text())
    expected = lock['version_output']
    explicit = value or os.environ.get('GODOT_BIN')
    if explicit:
        candidates = [explicit]
    else:
        candidates = _installed_engine_candidates(lock)

    mismatches: list[str] = []
    for candidate in candidates:
        executable = shutil.which(candidate)
        if not executable:
            continue
        try:
            probe = subprocess.run(
                [executable, '--version'], capture_output=True, text=True,
                timeout=8, check=True,
            )
            detected = probe.stdout.strip()
        except (OSError, subprocess.SubprocessError) as exc:
            mismatches.append(f'{executable}: failed --version ({exc})')
            continue
        if detected == expected:
            print(f'GODOT_SELECTED: {executable} ({detected})')
            return executable
        mismatches.append(f'{executable}: {detected or "no version output"}')

    if explicit:
        raise ValueError(
            f'Specified Godot {explicit!r} was not usable; expected {expected}. '
            + ('; '.join(mismatches[:3]) if mismatches else 'Path was not executable.')
        )
    if mismatches:
        raise ValueError(
            f'AC has Godot installed, but none matches required {expected}. '
            'Found: ' + '; '.join(mismatches[:5])
        )
    raise ValueError(
        f'Cannot find preinstalled Godot {expected} automatically (PATH, '
        'standard app locations and repo-local .local/godot checked). '
        'The launcher never downloads an engine or changes existing saves.'
    )


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



def needs_asset_import(game: Path) -> bool:
    """Cold checkout or updated PNGs need Godot's imported texture cache."""
    cache = game / '.godot' / 'imported'
    for source in (game / 'assets').rglob('*.png'):
        imported = list(cache.glob(f'{source.name}-*.ctex'))
        if not imported or max(path.stat().st_mtime for path in imported) < source.stat().st_mtime:
            return True
    return False


def ensure_assets_imported(engine: str, game: Path, reports: Path, timeout: float) -> bool:
    if not needs_asset_import(game):
        return True
    print('PHASE0_IMPORT: importing missing or updated PNG textures before game launch')
    command = [engine, '--headless', '--path', str(game), '--editor', '--import', '--quit']
    code, output = execute(command, reports / 'asset_import.log', timeout, os.environ.copy())
    return clean_run(output, code)


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
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/shop_trade_ui_test.gd'], reports/'shop_trade_ui.log', timeout, env)
            markers = re.findall(r'^SHOP_TRADE_UI_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['shop_trade_ui_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/first_harvest_intro_test.gd'], reports/'first_harvest_intro.log', timeout, env)
            markers = re.findall(r'^INTRO_HARVEST_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['intro_harvest_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/farm_exploration_test.gd'], reports/'farm_exploration.log', timeout, env)
            markers = re.findall(r'^FARM_EXPLORATION_PASS checks=(\\d+) failures=0\\s*$', output, re.M)
            summary['farm_exploration_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/phase0_visual_contract_test.gd'], reports/'phase0_visual.log', timeout, env)
            markers = re.findall(r'^PHASE0_VISUAL_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['phase0_visual_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/world_clock_flow_test.gd'], reports/'world_clock_flow.log', timeout, env)
            markers = re.findall(r'^WORLD_CLOCK_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['world_clock_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/forage_domain_test.gd'], reports/'forage_domain.log', timeout, env)
            markers = re.findall(r'^FORAGE_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['forage_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/forage_recovery_loop_test.gd'], reports/'forage_recovery_loop.log', timeout, env)
            markers = re.findall(r'^RECOVERY_LOOP_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['recovery_loop_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/full_economy_loop_test.gd'], reports/'full_economy_loop.log', timeout, env)
            markers = re.findall(r'^FULL_ECONOMY_LOOP_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['full_economy_loop_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/workshop_route_test.gd'], reports/'workshop_route.log', timeout, env)
            markers = re.findall(r'^WORKSHOP_ROUTE_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['workshop_route_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/resident_schedule_contract_test.gd'], reports/'resident_schedule_contract.log', timeout, env)
            markers = re.findall(r'^RESIDENT_SCHEDULE_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['resident_schedule_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/resident_motion_test.gd'], reports/'resident_motion.log', timeout, env)
            markers = re.findall(r'^RESIDENT_MOTION_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['resident_motion_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/resident_runtime_persistence_test.gd'], reports/'resident_runtime_persistence.log', timeout, env)
            markers = re.findall(r'^RESIDENT_PERSISTENCE_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['resident_persistence_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/resident_space_handoff_test.gd'], reports/'resident_space_handoff.log', timeout, env)
            markers = re.findall(r'^RESIDENT_SPACE_HANDOFF_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['resident_space_handoff_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/fact_event_log_test.gd'], reports/'fact_event_log.log', timeout, env)
            markers = re.findall(r'^FACT_EVENT_LOG_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['fact_event_log_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/resident_knowledge_test.gd'], reports/'resident_knowledge.log', timeout, env)
            markers = re.findall(r'^RESIDENT_KNOWLEDGE_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['resident_knowledge_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/resident_conversation_test.gd'], reports/'resident_conversation.log', timeout, env)
            markers = re.findall(r'^RESIDENT_CONVERSATION_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['resident_conversation_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/resident_conversation_world_test.gd'], reports/'resident_conversation_world.log', timeout, env)
            markers = re.findall(r'^RESIDENT_CONVERSATION_WORLD_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['resident_conversation_world_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/player_resident_dialogue_test.gd'], reports/'player_resident_dialogue.log', timeout, env)
            markers = re.findall(r'^PLAYER_RESIDENT_DIALOGUE_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['player_resident_dialogue_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/grocer_dialogue_test.gd'], reports/'grocer_dialogue.log', timeout, env)
            markers = re.findall(r'^GROCER_DIALOGUE_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['grocer_dialogue_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/resident_gift_test.gd'], reports/'resident_gift.log', timeout, env)
            markers = re.findall(r'^RESIDENT_GIFT_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['resident_gift_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/hud_quickbar_test.gd'], reports/'hud_quickbar.log', timeout, env)
            markers = re.findall(r'^HUD_QUICKBAR_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['hud_quickbar_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/inventory_ui_test.gd'], reports/'inventory_ui.log', timeout, env)
            markers = re.findall(r'^INVENTORY_UI_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['inventory_ui_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/storage_ui_layout_test.gd'], reports/'storage_ui_layout.log', timeout, env)
            markers = re.findall(r'^STORAGE_UI_LAYOUT_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['storage_ui_layout_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/trade_ui_layout_test.gd'], reports/'trade_ui_layout.log', timeout, env)
            markers = re.findall(r'^TRADE_UI_LAYOUT_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['trade_ui_layout_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/pause_ui_test.gd'], reports/'pause_ui.log', timeout, env)
            markers = re.findall(r'^PAUSE_UI_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['pause_ui_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/settings_ui_test.gd'], reports/'settings_ui.log', timeout, env)
            markers = re.findall(r'^SETTINGS_UI_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['settings_ui_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/title_ui_test.gd'], reports/'title_ui.log', timeout, env)
            markers = re.findall(r'^TITLE_UI_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['title_ui_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/new_game_ui_test.gd'], reports/'new_game_ui.log', timeout, env)
            markers = re.findall(r'^NEW_GAME_UI_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['new_game_ui_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/load_ui_test.gd'], reports/'load_ui.log', timeout, env)
            markers = re.findall(r'^LOAD_UI_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['load_ui_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/import_review_ui_test.gd'], reports/'import_review_ui.log', timeout, env)
            markers = re.findall(r'^IMPORT_REVIEW_UI_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['import_review_ui_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            code, output = execute([engine, '--headless', '--audio-driver', 'Dummy', '--path', str(game), '--script', 'res://tests/loading_ui_test.gd'], reports/'loading_ui.log', timeout, env)
            markers = re.findall(r'^LOADING_UI_PASS checks=(\d+) failures=0\s*$', output, re.M)
            summary['loading_ui_passed'] = clean_run(output, code) and len(markers) == 1 and int(markers[0]) > 0
            summary['passed'] = summary['test_passed'] and summary['pages_passed'] and summary['core_passed'] and summary['gameplay_passed'] and summary['world_passed'] and summary['receipt_passed'] and summary['farm_interaction_passed'] and summary['door_passed'] and summary['three_day_passed'] and summary['storage_passed'] and summary['storage_ui_passed'] and summary['economy_passed'] and summary['village_shop_passed'] and summary['shop_trade_ui_passed'] and summary['farm_exploration_passed'] and summary['phase0_visual_passed'] and summary['intro_harvest_passed'] and summary['world_clock_passed'] and summary['forage_passed'] and summary['recovery_loop_passed'] and summary['full_economy_loop_passed'] and summary['workshop_route_passed'] and summary['resident_schedule_passed'] and summary['resident_motion_passed'] and summary['resident_persistence_passed'] and summary['resident_space_handoff_passed'] and summary['fact_event_log_passed'] and summary['resident_knowledge_passed'] and summary['resident_conversation_passed'] and summary['resident_conversation_world_passed'] and summary['player_resident_dialogue_passed'] and summary['grocer_dialogue_passed'] and summary['resident_gift_passed'] and summary['hud_quickbar_passed'] and summary['inventory_ui_passed'] and summary['storage_ui_layout_passed'] and summary['trade_ui_layout_passed'] and summary['pause_ui_passed'] and summary['settings_ui_passed'] and summary['title_ui_passed'] and summary['new_game_ui_passed'] and summary['load_ui_passed'] and summary['import_review_ui_passed'] and summary['loading_ui_passed']
            return 0 if summary['passed'] else 1
        finally:
            (reports/'summary.json').write_text(json.dumps(summary, indent=2))


def run_phase0_tests(engine: str, reports: Path, timeout: float) -> int:
    """Run cold-imported, isolated, real-scene Phase0 tests with explicit receipts."""
    reports.mkdir(parents=True, exist_ok=True)
    cases = [
        ("foundation", "FOUNDATION_PASS"),
        ("entry_pages", "PAGES_PASS"),
        ("world_layout", "WORLD_PASS"),
        ("phase0_visual_contract", "PHASE0_VISUAL_PASS"),
        ("farm_exploration", "FARM_EXPLORATION_PASS"),
        ("farm_interaction", "FARM_INTERACTION_PASS"),
        ("first_harvest_intro", "INTRO_HARVEST_PASS"),
        ("door_transition", "DOOR_PASS"),
        ("village_shop_route", "VILLAGE_SHOP_PASS"),
        ("new_game_ui", "NEW_GAME_UI_PASS"),
    ]
    summary = {"import_passed": False, "passed": False, "tests": {}}
    with tempfile.TemporaryDirectory(prefix="qingfeng-phase0-") as temporary:
        temp = Path(temporary)
        game = temp / "game"
        shutil.copytree(ROOT / "game", game, ignore=shutil.ignore_patterns(".godot", "__pycache__"))
        hashes = {p.relative_to(game).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                  for p in sorted(game.rglob("*")) if p.is_file()}
        (reports / "source_hashes.json").write_text(json.dumps(hashes, indent=2))
        env = os.environ.copy()
        for key in ("HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA",
                    "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            home = temp / key.lower()
            home.mkdir()
            env[key] = str(home)
        env["GODOT_SILENCE_ROOT_WARNING"] = "1"
        try:
            code, output = execute(
                [engine, "--headless", "--path", str(game), "--editor", "--import", "--quit"],
                reports / "import.log", timeout, env,
            )
            summary["import_passed"] = clean_run(output, code)
            if not summary["import_passed"]:
                return 1
            passed_all = True
            for name, marker in cases:
                code, output = execute(
                    [engine, "--headless", "--audio-driver", "Dummy", "--path", str(game),
                     "--script", f"res://tests/{name}_test.gd"],
                    reports / f"{name}.log", timeout, env,
                )
                lines = re.findall(rf"^{re.escape(marker)} checks=(\d+) failures=0\s*$", output, re.M)
                passed = clean_run(output, code) and len(lines) == 1 and int(lines[0]) > 0
                summary["tests"][name] = {"passed": passed, "exit_code": code}
                passed_all = passed_all and passed
                print(f"PHASE0_CASE name={name} passed={passed} exit={code}")
            summary["passed"] = passed_all
            return 0 if passed_all else 1
        finally:
            (reports / "summary.json").write_text(json.dumps(summary, indent=2))
            print(f'PHASE0_SUITE_PASS passed={summary["passed"]}')


def capture_native_phase0(engine: str, reports: Path, destination: Path, timeout: float) -> int:
    """Capture Godot frames with a graphical display; check PNG sizes and marker."""
    import struct
    game = ROOT / "game"
    reports.mkdir(parents=True, exist_ok=True)
    destination = destination.resolve()
    destination.mkdir(parents=True, exist_ok=True)
    if not ensure_assets_imported(engine, game, reports, timeout):
        return 1
    with tempfile.TemporaryDirectory(prefix="qingfeng-native-capture-") as temporary:
        env = os.environ.copy()
        for key in ("HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA",
                    "XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME"):
            home = Path(temporary) / key.lower()
            home.mkdir()
            env[key] = str(home)
        env["GODOT_SILENCE_ROOT_WARNING"] = "1"
        code, output = execute(
            [engine, "--audio-driver", "Dummy", "--path", str(game), "--script", "res://tests/phase0_capture.gd",
             "--", str(destination)],
            reports / "native_capture.log", timeout, env,
        )
        marker_ok = len(re.findall(r"^PHASE0_CAPTURE_PASS\s*$", output, re.M)) == 1
        if not clean_run(output, code) or not marker_ok:
            return 1
        for width, height in ((1280, 720), (1920, 1080)):
            path = destination / f"phase0_farm_{width}.png"
            try:
                image = path.read_bytes()
                correct = (image[:8] == b"\x89PNG\r\n\x1a\n" and
                           image[12:16] == b"IHDR" and
                           struct.unpack(">II", image[16:24]) == (width, height))
                if not correct:
                    raise ValueError(f"invalid Godot screenshot: {path}")
            except (OSError, ValueError, struct.error) as exc:
                print(f"PHASE0_CAPTURE_FAILED: {exc}")
                return 1
        print(f"PHASE0_CAPTURE_PASS destination={destination}")
        return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['run', 'editor', 'test', 'phase0', 'capture'])
    parser.add_argument('--capture-dir', type=Path)
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
        if args.mode == 'phase0':
            return run_phase0_tests(engine, args.report_dir, args.timeout)
        if args.mode == 'capture':
            if args.capture_dir is None:
                parser.error('capture needs --capture-dir')
            return capture_native_phase0(engine, args.report_dir, args.capture_dir, args.timeout)
        game = ROOT / 'game'
        if args.mode == 'run' and not ensure_assets_imported(engine, game, args.report_dir, args.timeout):
            print('PHASE0_IMPORT_FAILED: see asset_import.log; game not launched with missing textures')
            return 1
        command = [engine, '--path', str(game)]
        if args.mode == 'editor':
            command += ['--editor', 'res://app/main.tscn']
        return subprocess.call(command)
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        print(f'RUNTIME_TOOL_ERROR: {exc}')
        return 2

if __name__ == '__main__':
    raise SystemExit(main())
