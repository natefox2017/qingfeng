#!/usr/bin/env python3
"""Explicit Linux CI/bootstrap install; verify pinned upstream bytes, no API token."""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--directory', type=Path, required=True)
    args = parser.parse_args()
    lock = json.loads((ROOT/'tools/engine_lock.json').read_text())
    spec = lock['linux_x86_64']
    try:
        with urllib.request.urlopen(spec['url'], timeout=120) as response:
            data = response.read()
        if hashlib.sha256(data).hexdigest() != spec['sha256']:
            raise ValueError('Official engine archive hash mismatch')
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            binary = archive.read(spec['executable'])
        args.directory.mkdir(parents=True, exist_ok=True)
        target = args.directory / spec['executable']
        target.write_bytes(binary)
        target.chmod(0o755)
        print(target.resolve())
        return 0
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as exc:
        print(f'ENGINE_INSTALL_FAILED: {exc}')
        return 1

if __name__ == '__main__':
    raise SystemExit(main())
