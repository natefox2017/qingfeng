#!/usr/bin/env python3
"""One-time, reviewed, official Noto Sans CJK SC import for the offline game.

Does not run during game launch. Downloads only the immutable Sans2.004 release,
checks upstream Git blob identities, saves OFL with the font, and updates the
existing manifest. No local/container system font is redistributed.
"""
from __future__ import annotations
from pathlib import Path
import hashlib
import json
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
COMMIT = "523d033d6cb47f4a80c58a35753646f5c3608a78"
FONT_GIT_BLOB = "dc15562470b4f842321894787a0d066879ccff8b"
LICENSE_GIT_BLOB = "d952d62c065f3f35fb83a173496e90b21525aef3"
BASE = "https://raw.githubusercontent.com/notofonts/noto-cjk/" + COMMIT + "/"
FONT_REPO_PATH = "Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf"
FONT_PATH = ROOT / "game/assets/fonts/NotoSansCJKsc-Regular.otf"
LICENSE_PATH = ROOT / "art/licenses/noto_sans_cjk_ofl.txt"
MANIFEST_PATH = ROOT / "art/manifest.json"
ASSET_ID = "asset.font.noto_sans_cjk_sc_regular"

def git_sha1(data: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\x00" + data).hexdigest()

def fetch(path: str, expected_sha: str, max_length: int) -> bytes:
    req = urllib.request.Request(BASE + path, headers={"User-Agent": "qingfeng-source-verified-import/1.0"})
    with urllib.request.urlopen(req, timeout=120) as response:
        content = response.read(max_length + 1)
    if len(content) > max_length or git_sha1(content) != expected_sha:
        raise ValueError("Pinned upstream resource hash/size mismatch: " + path)
    return content

def main() -> int:
    font = fetch(FONT_REPO_PATH, FONT_GIT_BLOB, 17_000_000)
    license_content = fetch("LICENSE", LICENSE_GIT_BLOB, 12_000)
    if len(font) != 16_437_364 or font[:4] != b"OTTO":
        raise ValueError("Pinned font must be the expected static OpenType file")
    if b"SIL OPEN FONT LICENSE Version 1.1" not in license_content:
        raise ValueError("Expected SIL OFL license was not found")
    FONT_PATH.parent.mkdir(parents=True, exist_ok=True)
    LICENSE_PATH.parent.mkdir(parents=True, exist_ok=True)
    FONT_PATH.write_bytes(font)
    LICENSE_PATH.write_bytes(license_content)
    digest = hashlib.sha256(font).hexdigest()
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1 or not isinstance(manifest.get("assets"), list):
        raise ValueError("Unexpected asset manifest format")
    row = {
        "asset_id": ASSET_ID,
        "runtime_path": FONT_PATH.relative_to(ROOT).as_posix(),
        "sha256": digest,
        "source_url": "https://github.com/notofonts/noto-cjk/blob/" + COMMIT + "/" + FONT_REPO_PATH,
        "source_version": "Sans2.004@" + COMMIT,
        "license_id": "OFL-1.1",
        "license_path": LICENSE_PATH.relative_to(ROOT).as_posix(),
        "size_px": None,
        "source_anchor_px": None,
        "review_status": "proposed",
        "reviewer": None,
        "evidence_paths": [],
        "animations": [],
        "kind": "font"
    }
    old_rows = [entry for entry in manifest["assets"] if entry.get("asset_id") == ASSET_ID]
    if len(old_rows) > 1:
        raise ValueError("Duplicate font asset ID")
    if old_rows:
        if old_rows[0]["runtime_path"] != row["runtime_path"] or old_rows[0]["sha256"] != digest:
            raise ValueError("Existing font asset ID has mismatched content")
    else:
        manifest["assets"].append(row)
        MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Noto Sans CJK SC 2.004 original OTF validated; sha256=" + digest + "; bytes=" + str(len(font)))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
