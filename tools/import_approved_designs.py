#!/usr/bin/env python3
"""Import owner-approved PNG originals without pretending an illustration is a TileMap.

Read-only validation happens before any write. This runs at art-production time,
not during ./run_game.sh. The operator supplies the archive containing the exact
approved originals; no remote URL, paid call or account token is required.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "art/approved/reference_manifest.json"
ASSETS_PATH = ROOT / "art/manifest.json"


def validate_archive(archive: Path, expected: dict) -> dict[str, bytes]:
    result: dict[str, bytes] = {}
    entries = expected["images"]
    with zipfile.ZipFile(archive) as z:
        for entry in entries:
            archive_name = entry["original_path"]
            if archive_name not in z.namelist():
                raise ValueError(f"Missing approved source: {archive_name}")
            meta = z.getinfo(archive_name)
            if meta.file_size != entry["bytes"] or meta.file_size > 10_000_000:
                raise ValueError(f"Invalid approved file length: {archive_name}")
            data = z.read(meta)
            if hashlib.sha256(data).hexdigest() != entry["sha256"]:
                raise ValueError(f"Approved file hash mismatch: {archive_name}")
            if data[:8] != b"\x89PNG\r\n\x1a\n" or data[12:16] != b"IHDR":
                raise ValueError(f"Not an approved PNG: {archive_name}")
            if struct.unpack(">II", data[16:24]) != (entry["width"], entry["height"]):
                raise ValueError(f"Image size does not match the approved reference: {archive_name}")
            result[entry["id"]] = data
    return result


def register_ui_asset(manifest: dict, name: str, raw: bytes) -> None:
    asset_id = f"asset.ui.approved.{name}"
    runtime_path = f"game/assets/approved/{name}.png"
    checksum = hashlib.sha256(raw).hexdigest()
    record = {
        "kind": "object",
        "asset_id": asset_id,
        "runtime_path": runtime_path,
        "sha256": checksum,
        "source_url": "https://github.com/natefox2017/qingfeng/blob/main/art/approved/reference_manifest.json",
        "source_version": checksum,
        "license_id": "QINGFENG-ORIGINAL",
        "license_path": "art/approved/ART_RIGHTS.md",
        "size_px": {"width": 1672, "height": 941},
        "source_anchor_px": {"x": 0, "y": 0},
        "review_status": "proposed",
        "reviewer": None,
        "evidence_paths": [],
        "animations": [],
    }
    existing = [a for a in manifest["assets"] if a.get("asset_id") == asset_id]
    if existing and existing[0] != record:
        raise ValueError(f"Existing registered UI artwork has different provenance: {name}")
    if not existing:
        manifest["assets"].append(record)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path, help="Original approved-art ZIP (full-resolution PNGs)")
    args = parser.parse_args()
    expected = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    if expected["schema_version"] != 1 or len(expected["images"]) != 8:
        raise ValueError("Unexpected approved visual reference manifest")
    raws = validate_archive(args.archive, expected)
    assets = json.loads(ASSETS_PATH.read_text(encoding="utf-8"))
    for name in ("ui_title", "ui_new_game", "ui_load"):
        register_ui_asset(assets, name, raws[name])

    # Write only after every input and manifest assertion passes.
    references = ROOT / "art/approved/refs"
    references.mkdir(parents=True, exist_ok=True)
    for name, raw in raws.items():
        (references / f"{name}.png").write_bytes(raw)
    runtime = ROOT / "game/assets/approved"
    runtime.mkdir(parents=True, exist_ok=True)
    for name in ("ui_title", "ui_new_game", "ui_load"):
        (runtime / f"{name}.png").write_bytes(raws[name])
    ASSETS_PATH.write_text(json.dumps(assets, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("APPROVED_ART_IMPORTED references=8 runtime_ui=3 SHA256_verified=8")
    print("Next: open Godot and check the real controls above the menu backdrops.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
