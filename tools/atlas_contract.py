#!/usr/bin/env python3
"""Validate an explicit PixelLab atlas export and emit Godot AtlasTexture regions.

Never calls a generation API, guesses silhouettes, rescales or trims source art.
PNG header checks here are structural; native image decoding and visual QA remain
required. Source bytes must match the handoff's SHA256 before regions are emitted.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[1]

def load(path: Path) -> dict:
    if path.stat().st_size > 1_048_576:
        raise ValueError('atlas metadata exceeds 1 MiB')
    def pairs(values):
        result = {}
        for key, value in values:
            if key in result:
                raise ValueError(f'duplicate JSON key: {key}')
            result[key] = value
        return result
    return json.loads(path.read_text(encoding='utf-8'), object_pairs_hook=pairs,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))

def integer(value, low=0, high=4096):
    return type(value) is int and low <= value <= high

def validate(data: dict, root: Path = ROOT) -> list[str]:
    errors = []
    try:
        if data['schema_version'] != 1 or type(data['schema_version']) is not int:
            raise ValueError('unsupported schema_version')
        source = data['source_path']
        if not isinstance(source, str) or not source.startswith('game/assets/') or not re.fullmatch(r'[a-z0-9_/.-]+', source):
            raise ValueError('source must be below game/assets')
        path = (root / source).resolve()
        if not path.is_relative_to((root / 'game/assets').resolve()) or not path.is_file():
            raise ValueError('source missing or escapes asset directory')
        if path.suffix.lower() != '.png' or path.stat().st_size > 32 * 1024 * 1024:
            raise ValueError('source must be a bounded PNG')
        b = path.read_bytes()
        if hashlib.sha256(b).hexdigest() != data['source_sha256']:
            raise ValueError('source SHA256 mismatch')
        if len(b) < 24 or b[:8] != b'\x89PNG\r\n\x1a\n' or b[12:16] != b'IHDR':
            raise ValueError('source is not a PNG header')
        width, height = struct.unpack('>II', b[16:24])
        if not integer(width, 1) or not integer(height, 1):
            raise ValueError('atlas dimensions exceed 4096px')
        if data['size_px'] != [width, height] or any(type(v) is not int for v in data['size_px']):
            raise ValueError('declared dimensions do not match source')
        regions = data['regions']
        if not isinstance(regions, list) or not 1 <= len(regions) <= 1024:
            raise ValueError('expected 1..1024 regions')
        ids = {}
        for region in regions:
            name = region['region_id']
            if not isinstance(name, str) or not re.fullmatch('[a-z][a-z0-9_]*', name) or name in ids:
                raise ValueError('duplicate or non-semantic region_id')
            rect = region['rect_px']
            if not isinstance(rect, list) or len(rect) != 4 or any(not integer(v) for v in rect):
                raise ValueError(f'{name}: invalid rectangle')
            x, y, w, h = rect
            if not w or not h or x + w > width or y + h > height:
                raise ValueError(f'{name}: region is outside source')
            anchor = region['anchor_px']
            if not isinstance(anchor, list) or len(anchor) != 2 or any(not integer(v) for v in anchor) or anchor[0] > w or anchor[1] > h:
                raise ValueError(f'{name}: invalid frame-local anchor')
            borders = region.get('nine_patch_px')
            if borders is not None:
                if len(borders) != 4 or any(not integer(v) for v in borders) or borders[0] + borders[2] >= w or borders[1] + borders[3] >= h:
                    raise ValueError(f'{name}: nine-patch has no center')
            ids[name] = region
        for clip in data['animations']:
            frames = clip['region_ids']
            durations = clip['durations_msec']
            if not frames or len(frames) != len(durations) or any(f not in ids for f in frames):
                raise ValueError('animation references absent frames or wrong duration count')
            if any(not integer(v, 1, 60_000) for v in durations):
                raise ValueError('animation duration must be positive integer milliseconds')
            sizes = {tuple(ids[f]['rect_px'][2:]) for f in frames}
            anchors = {tuple(ids[f]['anchor_px']) for f in frames}
            if len(sizes) != 1 or len(anchors) != 1:
                raise ValueError('animation frames must retain one canvas and foot anchor')
            contacts = clip['contact']
            if clip['action'] in {'till', 'sow', 'water', 'harvest'} and (contacts is None or clip['is_looping']):
                raise ValueError('tool action requires an explicit contact event')
            if contacts is not None:
                frame, offset = contacts['frame'], contacts['offset_msec']
                if not integer(frame, 0, len(frames)-1) or not integer(offset, 0, durations[frame]-1):
                    raise ValueError('contact is outside the frame interval')
            if type(clip['is_looping']) is not bool:
                raise ValueError('is_looping must be boolean')
    except (OSError, ValueError, KeyError, TypeError, IndexError) as exc:
        errors.append(str(exc))
    return errors

def emit(data: dict, output: Path, root: Path = ROOT) -> None:
    errors = validate(data, root)
    if errors:
        raise ValueError('; '.join(errors))
    output.mkdir(parents=True, exist_ok=True)
    destinations = [output / (r['region_id'] + '.tres') for r in data['regions']]
    if any(p.exists() for p in destinations):
        raise ValueError('refusing to overwrite existing region resources')
    texture = 'res://' + data['source_path'][len('game/'):]
    for region, path in zip(data['regions'], destinations):
        rect = ', '.join(map(str, region['rect_px']))
        path.write_text('[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n'
                        f'[ext_resource type="Texture2D" path="{texture}" id="1"]\n\n'
                        '[resource]\natlas = ExtResource("1")\n'
                        f'region = Rect2({rect})\nfilter_clip = true\n', encoding='utf-8')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('manifest', type=Path)
    parser.add_argument('--emit', type=Path, help='Explicit new output directory; never overwrites.')
    args = parser.parse_args()
    try:
        data = load(args.manifest)
        errors = validate(data)
        if errors:
            raise ValueError('; '.join(errors))
        if args.emit:
            emit(data, args.emit)
        print('ATLAS_CONTRACT_PASS (metadata/source hash only; not visual acceptance)')
        return 0
    except (OSError, ValueError, RecursionError) as exc:
        print(f'ATLAS_CONTRACT_REJECTED: {exc}', file=sys.stderr)
        return 1

if __name__ == '__main__':
    raise SystemExit(main())
