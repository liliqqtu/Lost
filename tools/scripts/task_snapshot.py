"""Isolate parallel Godot tasks without sharing imports or modifying Git state.

Snapshot the current checkout (including staged/unstaged work); merge only files
changed since that snapshot. Existing destination edits are never overwritten.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def snapshot(root, destination):
    destination.mkdir(parents=True, exist_ok=False)
    output = subprocess.check_output(
        ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=root
    )
    names = set(output.decode("utf-8").split("\0")) | {"AGENTS.md"}
    baseline = {}
    for name in sorted(names):
        if not name or name.startswith("tools/raw_assets/parallel_work_"):
            continue
        source = root / name
        if not source.is_file():
            continue
        target = destination / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        baseline[name] = digest(source)
    (destination.parent / (destination.name + ".baseline.json")).write_text(
        json.dumps(baseline, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"Snapshot {destination}: {len(baseline)} files")


def changes(root):
    baseline = json.loads(
        (root.parent / (root.name + ".baseline.json")).read_text(encoding="utf-8")
    )
    changed = []
    for path in root.rglob("*"):
        if not path.is_file() or ".godot" in path.relative_to(root).parts:
            continue
        name = path.relative_to(root).as_posix()
        if name.startswith("tests/.runtime_saves/"):
            continue
        if digest(path) != baseline.get(name):
            changed.append(name)
    return baseline, sorted(changed)


def merge(source, destination, apply):
    baseline, changed = changes(source)
    conflicts = [name for name in changed if digest(destination / name) not in
                 (baseline.get(name), digest(source / name))]
    if conflicts:
        raise SystemExit("Destination changed; resolve explicitly: " + ", ".join(conflicts))
    for name in changed:
        print(name)
        if apply:
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / name, target)
    print(f"{'Merged' if apply else 'Reviewed'} {len(changed)} changed files")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["snapshot", "merge"])
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if args.operation == "snapshot":
        snapshot(args.source.resolve(), args.destination.resolve())
    else:
        merge(args.source.resolve(), args.destination.resolve(), args.apply)
