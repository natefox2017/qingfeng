#!/usr/bin/env python3
"""Check the new repository scaffold. This is not a Godot/gameplay test."""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = "natefox2017/qingfeng"
SKIP = {".git", ".local", ".godot", "__pycache__", "build", "dist", "reports"}
ASSET_EXTENSIONS = {".png", ".webp", ".jpg", ".ttf", ".otf", ".woff2"}
RUNTIME_EXTENSIONS = {".gd", ".tscn", ".tres", ".gdshader"}

def load_json(path: Path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"duplicate key {key}")
            result[key] = value
        return result
    return json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique,
                      parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))

def relative_file(root: Path, value: str) -> Path:
    if not isinstance(value, str) or not value or Path(value).is_absolute():
        raise ValueError(f"expected repository-relative file: {value!r}")
    path = (root / value).resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError(f"missing or escaping file: {value}")
    return path

def check_tasks(data: dict) -> list[str]:
    errors = []
    if data.get("repository_full_name") != REPOSITORY:
        errors.append("task registry points to another repository")
    tasks = data.get("tasks", [])
    if not tasks or data.get("schema_version") != 1:
        errors.append("missing tasks or unsupported task registry")
    ids = [t["task_id"] for t in tasks]
    numbers = [t["issue_number"] for t in tasks]
    if len(ids) != len(set(ids)) or len(numbers) != len(set(numbers)):
        errors.append("duplicate task or issue")
    graph = {}
    for task in tasks:
        tid, number = task["task_id"], task["issue_number"]
        if not re.fullmatch(r"N\d{2}", tid) or type(number) is not int or number < 1:
            errors.append(f"invalid task identity: {tid}")
        if task["issue_url"] != f"https://github.com/{REPOSITORY}/issues/{number}":
            errors.append(f"wrong issue URL: {tid}")
        if not task.get("owned_paths"):
            errors.append(f"missing ownership: {tid}")
        if "status" in task:
            errors.append(f"duplicate progress state outside GitHub: {tid}")
        graph[tid] = task["delivery_depends_on"]
        for dependency in graph[tid]:
            if dependency not in ids:
                errors.append(f"unknown dependency: {tid} -> {dependency}")
    visiting, visited = set(), set()
    def visit(node):
        if node in visiting:
            raise ValueError("cyclic delivery dependencies")
        if node in visited:
            return
        visiting.add(node)
        for dependency in graph.get(node, []):
            visit(dependency)
        visiting.remove(node)
        visited.add(node)
    try:
        for tid in graph:
            visit(tid)
    except ValueError as exc:
        errors.append(str(exc))
    return errors

def check_assets(root: Path, data: dict) -> list[str]:
    errors, seen_ids, paths = [], set(), set()
    if type(data.get("schema_version")) is not int or data["schema_version"] != 1:
        errors.append("invalid asset schema version")
    required = {"kind", "asset_id", "runtime_path", "sha256", "source_url", "source_version",
                "license_id", "license_path", "size_px", "source_anchor_px",
                "review_status", "reviewer", "evidence_paths", "animations"}
    for row in data["assets"]:
        try:
            if set(row) != required:
                raise ValueError("asset fields differ from contract")
            aid = row["asset_id"]
            if not re.fullmatch(r"asset\.[a-z0-9_.]+", aid) or aid in seen_ids:
                raise ValueError("invalid or duplicate asset_id")
            seen_ids.add(aid)
            path_text = row["runtime_path"]
            if not path_text.startswith("game/assets/") or path_text in paths:
                raise ValueError("invalid or duplicate runtime_path")
            paths.add(path_text)
            path = relative_file(root, path_text)
            if not re.fullmatch(r"[a-f0-9]{64}", row["sha256"]):
                raise ValueError("invalid SHA256")
            if hashlib.sha256(path.read_bytes()).hexdigest() != row["sha256"]:
                raise ValueError("asset bytes changed")
            relative_file(root, row["license_path"])
            for key in ("source_url", "source_version", "license_id"):
                if not isinstance(row[key], str) or not row[key].strip():
                    raise ValueError(f"missing provenance: {key}")
            if row["kind"] not in {"terrain", "object", "character", "animation", "icon", "font"}:
                raise ValueError("invalid asset kind")
            if row["kind"] == "font":
                if row["size_px"] is not None or row["source_anchor_px"] is not None or row["animations"]:
                    raise ValueError("font must not invent pixel anchors or animation")
            else:
                size = row["size_px"]
                if set(size) != {"width", "height"} or any(type(v) is not int or v < 1 for v in size.values()):
                    raise ValueError("invalid pixel dimensions")
                anchor = row["source_anchor_px"]
                if set(anchor) != {"x", "y"} or any(type(v) not in (float, int) for v in anchor.values()):
                    raise ValueError("invalid source anchor")
                if not 0 <= anchor["x"] <= size["width"] or not 0 <= anchor["y"] <= size["height"]:
                    raise ValueError("source anchor outside canvas")
                if path.suffix == ".png":
                    b = path.read_bytes()
                    if len(b) < 24 or b[:8] != b"\x89PNG\r\n\x1a\n" or b[12:16] != b"IHDR":
                        raise ValueError("invalid PNG header")
                    if struct.unpack(">II", b[16:24]) != (size["width"], size["height"]):
                        raise ValueError("PNG size differs from manifest")
            if row["review_status"] not in {"proposed", "validated", "accepted", "rejected"}:
                raise ValueError("invalid review state")
            if row["review_status"] == "accepted" and (not row["reviewer"] or not row["evidence_paths"]):
                raise ValueError("accepted asset has no reviewer/evidence")
            for evidence in row["evidence_paths"]:
                relative_file(root, evidence)
            for animation in row["animations"]:
                count, durations = animation["frame_count"], animation["frame_durations_msec"]
                if type(count) is not int or count < 1 or len(durations) != count:
                    raise ValueError("animation frame count mismatch")
                if any(type(v) not in (int, float) or v <= 0 for v in durations):
                    raise ValueError("invalid frame duration")
                if type(animation["is_looping"]) is not bool:
                    raise ValueError("loop flag must be boolean")
                frame, offset = animation["contact_frame"], animation["contact_offset_msec"]
                if (frame is None) != (offset is None):
                    raise ValueError("incomplete contact marker")
                if frame is not None and (type(frame) is not int or not 0 <= frame < count
                        or type(offset) not in (int, float) or not 0 <= offset < durations[frame]):
                    raise ValueError("contact marker outside frame")
        except (ValueError, KeyError, TypeError, AttributeError) as exc:
            errors.append(f"{row.get('asset_id', '<unknown>')}: {exc}")
    for path in (root / "game/assets").rglob("*"):
        if path.is_file() and path.suffix in ASSET_EXTENSIONS and path.relative_to(root).as_posix() not in paths:
            errors.append(f"unregistered runtime asset: {path.relative_to(root)}")
    return errors

def check(root: Path = ROOT) -> list[str]:
    errors = []
    try:
        config = load_json(root / "project.json")
        if config["repository_full_name"] != REPOSITORY or config["clone_url"] != f"https://github.com/{REPOSITORY}.git":
            errors.append("wrong canonical repository")
        if config["repository_id"] != 1408662571 or config["master_issue"] != 1:
            errors.append("wrong repository/issue identity")
        stage = config["stage"]
        if stage not in {"scaffold", "preproduction", "foundation", "playable"}:
            errors.append("unknown development stage")
        if stage in {"scaffold", "preproduction"}:
            if config["is_runnable"] is not False or config["main_scene"] is not None or (root / "game/project.godot").exists():
                errors.append("stage contradicts runtime presence")
        else:
            if config["is_runnable"] is not True or not re.fullmatch(r"4\.\d+(?:\.\d+)?", config["engine"]["version"] or ""):
                errors.append("runnable stage requires exact Godot version")
            relative_file(root, "game/project.godot")
            relative_file(root, "game/" + str(config["main_scene"]).removeprefix("res://"))
        if config["pixellab"]["is_runtime_required"] is not False:
            errors.append("PixelLab must not be a runtime dependency")
        tasks = load_json(root / "docs/tasks.json")
        errors.extend(check_tasks(tasks))
        errors.extend(check_assets(root, load_json(root / "art/manifest.json")))
        for file in root.rglob("*"):
            if not file.is_file() or set(file.relative_to(root).parts) & SKIP:
                continue
            rel = file.relative_to(root).as_posix()
            if file.suffix == ".json":
                load_json(file)
            if file.suffix in RUNTIME_EXTENSIONS:
                for part in file.relative_to(root).parts[:-1]:
                    if not re.fullmatch(r"[a-z0-9]+(?:_[a-z0-9]+)*", part):
                        errors.append(f"non-snake-case runtime directory: {rel}")
                if not re.fullmatch(r"[a-z0-9]+(?:_[a-z0-9]+)*", file.stem):
                    errors.append(f"non-snake-case runtime path: {rel}")
                if re.search(r"(^|_)(candidate|trial|current|latest|final)(_|$)", file.stem):
                    errors.append(f"workflow status in runtime name: {rel}")
            if file.suffix in {".md", ".json", ".py", ".yml"}:
                text = file.read_text(encoding="utf-8")
                for legacy in ("natefox2017/" + "qingfenggu", "natefox2017/" + "qingfeng-"):
                    if legacy in text:
                        errors.append(f"stale repository reference: {rel}")
                if file.suffix == ".md":
                    for target in re.findall(r"\]\(([^)]+)\)", text):
                        target = target.split()[0]
                        if urlsplit(target).scheme or target.startswith("#"):
                            continue
                        candidate = (file.parent / unquote(target.split("#")[0])).resolve()
                        if not candidate.is_relative_to(root.resolve()) or not candidate.exists():
                            errors.append(f"broken local link: {rel} -> {target}")
        runtime_files = list((root / "game").rglob("*.gd"))
        if stage == "scaffold" and runtime_files:
            errors.append("runtime code added without changing stage")
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        errors.append(f"invalid scaffold: {exc}")
    return errors

def is_canonical_remote(value: str) -> bool:
    value = value.strip()
    return value in {f"https://github.com/{REPOSITORY}",
                     f"https://github.com/{REPOSITORY}.git",
                     f"git@github.com:{REPOSITORY}",
                     f"git@github.com:{REPOSITORY}.git"}

def main() -> int:
    errors = check()
    actual = os.environ.get("GITHUB_REPOSITORY")
    if actual and actual != REPOSITORY:
        errors.append(f"CI running in another repository: {actual}")
    if (ROOT / ".git").exists():
        result = subprocess.run(["git", "-C", str(ROOT), "remote", "get-url", "origin"],
                                capture_output=True, text=True, timeout=10)
        if result.returncode == 0 and not is_canonical_remote(result.stdout):
            errors.append("origin is not the canonical repository")
    if errors:
        print("\n".join(errors))
        return 1
    print("SCAFFOLD_CHECK_PASS (documents/contracts only; not gameplay acceptance)")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
