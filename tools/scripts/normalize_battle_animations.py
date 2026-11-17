"""Normalize battle SpriteFrames without changing hand-authored attack sequences.

Run from the project root: python tools/scripts/normalize_battle_animations.py
Use --check for a read-only idempotence check. Source matching uses complete frame
sequences, never approximate filenames or guessed impact percentages.
"""
import argparse
import ast
import json
import re
import shutil
import tempfile
from pathlib import Path

from battle_animation_format import clone, read_resource, signature, write_resource

DEFAULT_SOURCE = Path("E:/Dream/资源/FE-Repo-main/FE-Repo-main/Battle Animations")
HAND_AUTHORED = {"Te.tres", "Isar.tres", "Ranger_M_frames.tres", "Brigand_M_frames.tres"}
PREFIXES = ("sword", "lance", "axe", "bow", "magic", "staff", "refresh", "dragonstone")


def class_definitions():
    definitions = {}
    for name in ("batch_import_vanilla_classes.py", "batch_import_female_classes.py"):
        tree = ast.parse(Path(__file__).with_name(name).read_text(encoding="utf-8"))
        for node in tree.body:
            if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "CLASS_DEFINITIONS" for t in node.targets):
                definitions.update({row[0]: row[1:] for row in ast.literal_eval(node.value)})
    definitions["Mercenary_M"] = ("Mercenaries and Heroes", r"\[Mercenary-Base\] Vanilla FE7-8 \+Weapons \[M\]", [("1. Sword", "sword")])
    return definitions


CLASS_DEFINITIONS = class_definitions()


def source_records(path):
    """Keep command locations as frame boundaries (C04/C05 are not hit events)."""
    modes = []
    record = None
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        line = line.strip()
        mode = re.match(r"///\s*-\s*Mode\s+(\d+)", line, re.I)
        if mode:
            record = {"mode": int(mode[1]), "frames": [], "events": [], "ticks": 0,
                      "source": str(path), "category": path.parents[2].name,
                      "class": path.parents[1].name, "weapon": path.parent.name}
            modes.append(record)
        elif line.startswith("~~~"):
            record = None
        elif record is not None:
            frame = re.match(r"(\d+)\s+p-\s+([^\s#]+)", line)
            command = re.match(r"C([0-9A-Fa-f]{2})(?:\s|$)", line)
            if frame:
                duration = float(frame[1])
                record["frames"].append((duration, frame[2]))
                record["ticks"] += duration
            elif command:
                record["events"].append((int(command[1], 16), len(record["frames"]), record["ticks"]))
    return modes


def build_source_index(paths, root):
    wanted = set()
    for path in paths:
        if path.name in HAND_AUTHORED or path.name == "Magic_frames.tres":
            continue
        _, animations, textures = read_resource(path)
        for animation in animations.values():
            wanted.add(signature(animation, textures))
    index = {}
    scripts = [root] if root.is_file() else root.glob("*/*/*/*.txt")
    for path in scripts:
        if "without_comment" in path.name or path.name.startswith("README"):
            continue
        for record in source_records(path):
            key = tuple(record["frames"])
            if key in wanted:
                index.setdefault(key, []).append(record)
    return index


def metadata_from(text):
    return {key: json.loads(value) for key, value in re.findall(
        r"^metadata/battle_animation_(\w+) = (.+)$", text, re.M)}


def normalize_resource(path, index):
    original, animations, textures = read_resource(path)
    if path.name == "Magic_frames.tres":
        return False  # Spell effects have no unit idle/attack contract.
    metadata = metadata_from(original)
    aliases = metadata.get("aliases", {})
    impacts = metadata.get("impacts", {})
    matched = {}
    definition = CLASS_DEFINITIONS.get(path.stem.removesuffix("_frames"))
    for name, animation in animations.items():
        if path.name in HAND_AUTHORED:
            continue
        records = index.get(signature(animation, textures), [])
        if definition:
            category, pattern, _ = definition
            preferred = [r for r in records if category.lower() in r["category"].lower()
                         and re.search(pattern, r["class"], re.I)]
            # Prefer the actual base weapon folder over alternative crit/ranged edits.
            plain = [r for r in preferred if "(" not in r["weapon"]]
            if preferred:
                records = plain or preferred
        if records:
            # Same frame sequence can occur in several modes/classes. Only accept
            # a timing when all matching hit commands agree.
            hits = {ticks / animation["speed"] for r in records for code, _, ticks in r["events"]
                    if code in (0x1A, 0x08, 0x09, 0x0A, 0x0B, 0x0C)}
            if name.endswith("_miss") and not hits:
                hits = {ticks / animation["speed"] for r in records if r["mode"] == 12
                        for code, _, ticks in r["events"] if code == 0x04}
            if len(hits) == 1:
                impacts[name] = hits.pop()
            matched[name] = records

    def merge(old, new):
        if old not in animations:
            return
        if new not in animations:
            animations[new] = animations.pop(old)
        elif animations[old] == animations[new]:
            del animations[old]
        else:
            return  # Never discard a genuinely distinct action.
        aliases[old] = new
        if old in impacts:
            impacts.setdefault(new, impacts.pop(old))

    for prefix in PREFIXES:
        merge(prefix + "_critical", prefix + "_crit")
        merge(prefix + "_stand", prefix + "_idle")
        merge(prefix + "_mode_11", prefix + "_idle_ranged")
        for mode, suffix in ((5, "ranged"), (6, "ranged_crit"), (8, "dodge_ranged"), (12, "miss")):
            merge(f"{prefix}_mode_{mode}", f"{prefix}_{suffix}")
        if prefix + "_idle" not in animations:
            base = next((n for n in (prefix, prefix + "_start", prefix + "_ranged") if n in animations), None)
            if base:
                animations[prefix + "_idle"] = clone(animations[base], animations[base]["frames"][:1], True)
        for name in (prefix + "_idle", prefix + "_idle_ranged"):
            if name in animations:
                animations[name]["loop"] = True
        # Equal close/ranged idle definitions share a single canonical action.
        merge(prefix + "_idle_ranged", prefix + "_idle")
        merge(prefix + "_dodge_ranged", prefix + "_dodge")

    # Hand-crafted Isar already has proper three-phase casting; imported aliases
    # named magic_start still contain the entire script and must be split at C05/C01.
    if "magic_start" in animations and "magic_loop" not in animations:
        for suffix in ("", "_crit"):
            name = "magic_start" + suffix
            if name not in animations:
                continue
            records = matched.get(name, [])
            splits = set()
            for record in records:
                release = next((i for code, i, _ in record["events"] if code == 5), None)
                wait = next((i for code, i, _ in record["events"] if code == 1 and release is not None and i >= release), None)
                if release is not None and wait is not None:
                    splits.add((release, wait))
            if len(splits) != 1:
                raise ValueError(f"Cannot safely split casting: {path.name}/{name}: {splits}")
            release, wait = splits.pop()
            full = clone(animations[name])
            frames = full["frames"]
            animations[name] = clone(full, frames[:release], False)
            hold = frames[release:wait] or [(1.0, frames[release - 1][1])]
            animations["magic_loop" + suffix] = clone(full, hold, True)
            animations["magic_end" + suffix] = clone(full, frames[wait:] or animations["magic_idle"]["frames"], False)
            # Full-script aliases must route through the new casting lifecycle.
            for alias in list(animations):
                if alias != name and animations[alias] == full:
                    del animations[alias]
                    aliases[alias] = name
                    impacts.pop(alias, None)
            impacts.pop(name, None)
        for phase in ("loop", "end"):
            merge("magic_" + phase + "_crit", "magic_" + phase)

    for old, new in (("dance", "refresh"), ("play", "refresh"), ("dance_dodge", "refresh_dodge"),
                     ("staff_start", "staff"), ("transform", "dragonstone"),
                     ("breath", "dragonstone"), ("transform_crit", "dragonstone_crit")):
        merge(old, new)
    # Collapse identical family aliases left by legacy bulk importers.
    for old in ("anima", "dark", "light", "magic"):
        if old in animations and "magic_start" in animations:
            merge(old, "magic_start")
    for key in list(aliases):
        seen = {key}
        target = aliases[key]
        while target in aliases and target not in seen:
            seen.add(target)
            target = aliases[target]
        aliases[key] = target
        if target not in animations or key in animations:
            del aliases[key]
    metadata.update(version=1, aliases=aliases, impacts={n: v for n, v in impacts.items() if n in animations})
    return write_resource(path, original, animations, metadata)


def normalize_paths(paths, source=DEFAULT_SOURCE, write=True):
    paths = list(paths)
    if not Path(source).exists():
        raise FileNotFoundError(f"Animation script source missing: {source}")
    index = build_source_index(paths, Path(source))
    # Validate every conversion before committing any resource in the batch.
    pending = []
    with tempfile.TemporaryDirectory() as directory:
        for path in paths:
            copy = Path(shutil.copy2(path, directory))
            if normalize_resource(copy, index):
                pending.append((path, copy.read_text(encoding="utf-8")))
        if write:
            for path, content in pending:
                path.write_text(content, encoding="utf-8", newline="\n")
    changed = len(pending)
    print(f"Battle animations: checked {len(paths)}, updated {changed}")
    return changed


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--directory", type=Path, default=Path(__file__).resolve().parents[2] / "data/battle_animation_tres")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    paths = sorted(args.directory.glob("*.tres"))
    changed = normalize_paths(paths, args.source, write=not args.check)
    raise SystemExit(1 if args.check and changed else 0)
