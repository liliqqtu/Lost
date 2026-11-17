"""Generate the FE8 catalog from its upstream table and the local FE-Repo icons.

Run from project root: python tools/scripts/import_fe8_items.py --icons <Item Icons>
Source files and curated Chinese labels live in tools/raw_assets/fe8_items.
Only the dedicated data/items/fe8 and graphics/Item Icons/fe8 files are replaced.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "tools/raw_assets/fe8_items"
TYPES = {"SWORD": (0, "Swords"), "LANCE": (1, "Lances"),
         "AXE": (2, "Axes"), "BOW": (3, "Bows"), "ANIMA": (4, "Anima"),
         "DARK": (5, "Dark"), "LIGHT": (6, "Light"), "STAFF": (7, "Staff")}
PROMOTION = {"HEROCREST", "KNIGHTCREST", "ORIONSBOLT", "ELYSIANWHIP",
             "GUIDINGRING", "MASTERSEAL", "OCEANSEAL", "LUNARBRACE", "SOLARBRACE"}
KEYS = {"CHESTKEY", "CHESTKEY_BUNDLE", "DOORKEY", "LOCKPICK"}
VALUABLE = {"WHITEGEM", "BLUEGEM", "REDGEM"}
PASSIVE = {"DELPHISHIELD", "HOPLON_SHIELD", "MEMBERCARD", "SILVERCARD"}
BONUSES = {"ANIMA_EXCALIBUR": "spd", "DARK_GLEIPNIR": "skl",
           "SWORD_SIEGLINDE": "str", "LIGHT_IVALDI": "def",
           "LANCE_VIDOFNIR": "def", "SWORD_AUDHULMA": "res",
           "LANCE_SIEGMUND": "str", "AXE_GARM": "spd", "BOW_NIDHOGG": "luk"}


def slug(text):
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")


def literal(value):
    if isinstance(value, bool):
        return str(value).lower()
    return json.dumps(value, ensure_ascii=False)


def read_table():
    source = (RAW / "data_items.c").read_text(encoding="utf-8")
    constants = (RAW / "items.h").read_text(encoding="utf-8")
    ids = {key: int(value, 16) for key, value in
           re.findall(r"(ITEM_\w+)\s*=\s*0x([0-9A-Fa-f]+)", constants)}
    table = {}
    for key, body in re.findall(r"\[(ITEM_\w+)\]\s*=\s*\{(.*?)\n\s*\}", source, re.S):
        table[key[5:]] = dict(re.findall(r"\.(\w+)\s*=\s*([^,\n]+)", body))
    return ids, table


def number(row, field, default=0):
    return int(row.get(field, str(default)), 0)


def icon_source(index, english):
    filename = "{2WB} (Vanilla + Blitz) " + english + ".png"
    candidates = index.get(filename, [])
    if len(candidates) != 1:
        raise ValueError(f"Expected one original icon for {english}: {candidates}")
    return candidates[0]


def generate(icons):
    ids, table = read_table()
    icon_index = {}
    for path in icons.rglob("*.png"):
        icon_index.setdefault(path.name, []).append(path)
    out = ROOT / "data/items/fe8"
    out.mkdir(parents=True, exist_ok=True)
    manifest = []
    for line in (RAW / "catalog.tsv").read_text(encoding="utf-8").splitlines():
        key, chinese, english, description = line.split("|", 3)
        row = table[key]
        type_name = row["weaponType"].removeprefix("ITYPE_")
        weapon = type_name in TYPES
        kind = type_name.lower() if weapon else "consumable"
        if key.startswith("BOOSTER_"):
            kind = "stat_booster"
        elif key in PROMOTION:
            kind = "promotion"
        elif key in KEYS:
            kind = "key"
        elif key in VALUABLE:
            kind = "valuable"
        elif key in PASSIVE:
            kind = "accessory"
        elif key == "DIVINESTONE":
            kind = "dragonstone"
        stem = "chest_key_bundle" if key == "CHESTKEY_BUNDLE" else slug(english)
        source = icon_source(icon_index, english)
        folder = TYPES[type_name][1] if weapon else "Item"
        image_path = ROOT / "assets/graphics/Item Icons/fe8" / folder / (stem + ".png")
        image_path.parent.mkdir(parents=True, exist_ok=True)
        candidate = Image.open(source).convert("RGBA")
        original = Image.open(RAW / "rom_icons" / ("ITEM_" + key + ".png"))
        indexes = list(original.getdata())
        image = original.convert("RGBA")
        image.putdata([color if indexes[index] else (0, 0, 0, 0)
                       for index, color in enumerate(image.getdata())])
        if image.size != (16, 16):
            raise ValueError(f"Incorrect icon size: {source}: {image.size}")
        image.save(image_path)
        uses = number(row, "maxUses", 1)
        cost = number(row, "costPerUse") * uses
        attributes = row.get("attributes", "")
        special = (any(tag in attributes for tag in ["IA_MAGICDAMAGE", "IA_REVERTTRIANGLE", "IA_LOCK"])
                   or "pEffectiveness" in row or "weaponEffectId" in row)
        implemented = weapon and not special and type_name != "STAFF"
        if key in {"STAFF_HEAL", "STAFF_MEND"}:
            implemented = True
        if kind == "valuable":
            implemented = True
        effect = "" if implemented else key.lower()
        if not implemented:
            description += "（特殊效果待实现）" if weapon else "（使用或持有效果待实现）"
        fields = {
            "item_id": stem, "display_name": chinese, "description": description,
            "buy_price": cost,
            "can_sell": cost > 0 and "IA_UNSELLABLE" not in attributes,
            "item_kind": kind, "effect_id": effect, "effect_implemented": implemented,
            "remaining_uses": uses, "max_uses": uses, "original_id": ids["ITEM_" + key],
            "original_data": {name: value for name, value in row.items()
                              if name not in {"nameTextId", "descTextId", "number", "iconId"}},
        }
        if weapon:
            encoded = number(row, "encodedRange", 0x11)
            fields.update({
                "weapon_type": TYPES[type_name][0],
                "required_rank": {"WPN_EXP_E": 0, "WPN_EXP_D": 1, "WPN_EXP_C": 2,
                                  "WPN_EXP_B": 3, "WPN_EXP_A": 4, "WPN_EXP_S": 5}.get(row.get("weaponRank"), 0),
                "weapon_exp": number(row, "weaponExp", 1),
                "might": {"STAFF_HEAL": 10, "STAFF_MEND": 20}.get(key, number(row, "might")),
                "hit": number(row, "hit"),
                "crit": number(row, "crit"), "weight": number(row, "weight"),
                "durability": uses, "max_durability": uses,
                "min_range": max(1, encoded >> 4),
                # Variable magic-based staff range remains raw metadata until implemented.
                "max_range": max(1, encoded & 15), "is_brave": "IA_BRAVE" in attributes,
            })
            if key in BONUSES:
                fields["bonus_" + BONUSES[key]] = 5
        cls = "Weapon" if weapon else "Item"
        script = "weapon" if weapon else "item"
        icon_path = "res://" + image_path.relative_to(ROOT).as_posix()
        lines = [f'[gd_resource type="Resource" script_class="{cls}" format=3]', "",
                 f'[ext_resource type="Script" path="res://scripts/{script}.gd" id="1_script"]',
                 f'[ext_resource type="Texture2D" path="{icon_path}" id="2_icon"]', "",
                 "[resource]", 'script = ExtResource("1_script")', 'icon = ExtResource("2_icon")']
        for name, value in fields.items():
            prefix = "&" if name in {"item_id", "item_kind", "effect_id"} else ""
            lines.append(f"{name} = {prefix}{literal(value)}")
        target = out / (stem + ".tres")
        target.write_text("\n".join(lines) + "\n", encoding="utf-8")
        manifest.append({"resource": "res://" + target.relative_to(ROOT).as_posix(),
                         "source_id": key, "source_icon": source.relative_to(icons).as_posix(),
                         "final_icon_source": "FE8J Chinese ROM / original icon palette / index 0 transparent",
                         "original_verified": True,
                         "repo_pixel_differences": sum(a != b for a, b in zip(candidate.getdata(), image.getdata())
                                                       if a[3] or b[3]),
                         "display_name": chinese, "item_kind": kind, "price": cost,
                         "effect_implemented": implemented})
    report = {"table_url": "https://github.com/FireEmblemUniverse/fireemblem8u/blob/master/src/data_items.c",
              "table_sha256": hashlib.sha256((RAW / "data_items.c").read_bytes()).hexdigest(),
              "icon_source": "https://github.com/Klokinator/FE-Repo/tree/main/Item%20Icons",
              "icon_pack": "FE8J ROM originals; FE-Repo {2WB} candidates retained in provenance",
              "count": len(manifest), "items": manifest}
    (RAW / "manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(manifest)} original FE8 resources and icons.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--icons", type=Path, required=True)
    generate(parser.parse_args().icons)
