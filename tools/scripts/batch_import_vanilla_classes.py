"""
GBA 火焰纹章全原版职业战斗动画批量导入工具
(Batch Importer for all Vanilla Fire Emblem GBA Battle Animations)
-----------------------------------------------------------------
功能：
1. 遍历 FE-Repo-main 检索匹配 37 个原版职业（包含下位与上位全部职业）。
2. 执行方案 A 规范化：
   - 将 488x160 的双层穿刺帧（Piercing Frame）自动合并为标准的 248x160 完整帧（左侧前景覆盖层叠合到右侧背景本体层）。
   - 保持 248x160 常规帧不变，确保调色板与透明度规范统一。
3. 支持多武器复合职业（如圣骑士 Sword/Lance/Axe，将军 Lance/Axe/Sword，勇士 Axe/Bow），
   将该职业的多武器动作聚合生成到同一个 SpriteFrames (.tres) 资源中。
4. 保护现有已配好的专属/主角动画（Brigand_M, Te, Isar, Ranger_M）。
5. 自动调用 Godot 4.7 引擎后台静默重新编译导入全部新增素材。
"""

import os
import sys
import re
import subprocess
from typing import Dict, List, Tuple
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

PROJECT_ROOT = r"E:\Dream\Lost"
REPO_BASE = r"E:\Dream\资源\FE-Repo-main\FE-Repo-main\Battle Animations"
GODOT_BIN = r"E:\Godot\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64_console.exe"

# 保护清单：不覆盖已手工配置好的动画
PROTECTED_CLASSES = {"Brigand_M", "Te", "Isar", "Ranger_M"}

# 武器类型 -> 动作别名表
WEAPON_MODE_MAP = {
    "sword": {
        1: ["sword"],
        3: ["sword_crit", "sword_critical"],
        5: ["sword_ranged"],
        6: ["sword_ranged_crit"],
        7: ["sword_dodge"],
        8: ["sword_dodge_ranged"],
        9: ["sword_stand"],
        10: ["sword_idle"],
        12: ["sword_miss"],
    },
    "lance": {
        1: ["lance"],
        3: ["lance_crit", "lance_critical"],
        5: ["lance_ranged"],
        6: ["lance_ranged_crit"],
        7: ["lance_dodge"],
        8: ["lance_dodge_ranged"],
        9: ["lance_stand"],
        10: ["lance_idle"],
        12: ["lance_miss"],
    },
    "axe": {
        1: ["axe"],
        3: ["axe_crit", "axe_critical"],
        5: ["axe_ranged"],
        6: ["axe_ranged_crit"],
        7: ["axe_dodge"],
        8: ["axe_dodge_ranged"],
        9: ["axe_stand"],
        10: ["axe_idle"],
        12: ["axe_miss"],
    },
    "bow": {
        1: ["bow"],
        3: ["bow_crit", "bow_critical"],
        5: ["bow_ranged"],
        6: ["bow_ranged_crit"],
        7: ["bow_dodge"],
        8: ["bow_dodge_ranged"],
        9: ["bow_stand"],
        10: ["bow_idle"],
        12: ["bow_miss"],
    },
    "magic": {
        1: ["magic", "magic_start", "anima", "dark", "light"],
        3: ["magic_crit", "magic_critical", "magic_start_crit"],
        5: ["magic_ranged"],
        6: ["magic_ranged_crit"],
        7: ["magic_dodge"],
        8: ["magic_dodge_ranged"],
        9: ["magic_stand"],
        10: ["magic_idle"],
        12: ["magic_miss"],
    },
    "staff": {
        1: ["staff", "staff_start"],
        3: ["staff_crit", "staff_critical"],
        7: ["staff_dodge"],
        8: ["staff_dodge_ranged"],
        9: ["staff_stand"],
        10: ["staff_idle"],
        12: ["staff_miss"],
    },
    "refresh": {
        1: ["refresh", "dance", "play"],
        3: ["refresh_crit"],
        7: ["refresh_dodge", "dance_dodge"],
        9: ["refresh_stand"],
        10: ["refresh_idle"],
    }
}

# 37 个原版核心职业映射定义
CLASS_DEFINITIONS = [
    # 剑系步兵
    ("Myrmidon_M", "Myrms and Swordmasters", r"\[Myrmidon-Base\].*Vanilla FE6-8 Generic \[M\]", [("1. Sword", "sword")]),
    ("Swordmaster_M", "Myrms and Swordmasters", r"\[Swordmaster-Base\].*Vanilla FE6 \[M\]", [("1. Sword", "sword")]),
    ("Hero_M", "Mercenaries and Heroes", r"\[Hero-Base\].*Vanilla FE7-8 \+Weapons \[M\]", [("1. Sword", "sword"), ("3. Axe", "axe")]),
    ("Thief_M", "Thieves, Rogues, Assassins", r"\[Thief-Base\].*Chad Vanilla FE6 \[M\]|\[Thief-Base\].*Vanilla FE7 Legault", [("1. Sword", "sword")]),
    ("Assassin_M", "Thieves, Rogues, Assassins", r"\[Assassin-Base\].*Jaffar Vanilla \+Weapons \[M\]", [("1. Sword", "sword")]),
    ("Rogue_M", "Thieves, Rogues, Assassins", r"\[Rogue-Base\].*Vanilla \+Staff \[M\]", [("1. Sword", "sword")]),
    
    # 枪系步兵
    ("Soldier_M", "Soldiers, Halberdiers", r"\[Soldier-Base\].*Vanilla \+Weapons \[M\]", [("2. Lance", "lance")]),
    
    # 斧系步兵
    ("Fighter_M", "Fighters and Warriors", r"\[Fighter-Base\].*Vanilla \+ Weapons \[M\]", [("3. Axe", "axe")]),
    ("Warrior_M", "Fighters and Warriors", r"\[Warrior-Base\].*Vanilla \+Magic \[M\]", [("3. Axe", "axe"), ("5. Bow", "bow")]),
    ("Pirate_M", "Brigs, Pirates, Zerkers", r"\[Pirate-Base\].*Vanilla \+Sword \[M\]", [("3. Axe", "axe")]),
    ("Berserker_M", "Brigs, Pirates, Zerkers", r"\[Berserker-Base\].*Vanilla \+Magic \[M\]", [("3. Axe", "axe")]),
    
    # 弓系步兵
    ("Archer_M", "Archers and Hunters", r"\[Archer-Base\].*Vanilla FE6 \[M\]", [("5. Bow", "bow")]),
    ("Sniper_M", "Snipers and Ballistae", r"\[Sniper-Base\].*Vanilla FE6 \[M\]", [("5. Bow", "bow")]),
    
    # 重装
    ("Knight_M", "Knights, Generals, Armors", r"\[Knight-Base\].*Vanilla \+Weapons \[U\]", [("2. Lance", "lance")]),
    ("General_M", "Knights, Generals, Armors", r"\[General-Base\].*Vanilla \+Weapons \[U\]", [("2. Lance", "lance"), ("3. Axe", "axe"), ("1. Sword", "sword")]),
    
    # 骑兵
    ("Cavalier_M", "Cavs, Paladins, Rangers", r"\[Cavalier-Base\].*\[M\] Vanilla \+Weapons", [("1. Sword", "sword"), ("2. Lance", "lance")]),
    ("Paladin_M", "Cavs, Paladins, Rangers", r"\[Paladin-Base\].*\[M\] Vanilla \+Weapons", [("1. Sword", "sword"), ("2. Lance", "lance"), ("3. Axe", "axe")]),
    ("Great_Knight_M", "Cavs, Paladins, Rangers", r"\[GK-Base\].*\[U\] Vanilla \+Weapons", [("2. Lance", "lance"), ("3. Axe", "axe")]),
    
    # 飞行
    ("Pegasus_Knight_F", "Pegs, Wyverns, Griffons", r"\[Peg T1 Base\].*\[F\] Vanilla \+Weapons", [("2. Lance", "lance")]),
    ("Falcon_Knight_F", "Pegs, Wyverns, Griffons", r"\[Peg T2 Base\].*\[F\] Vanilla \+Weapons", [("1. Sword", "sword"), ("2. Lance", "lance")]),
    ("Wyvern_Rider_M", "Pegs, Wyverns, Griffons", r"\[WR Base\].*\[U\] Vanilla \+Weapons", [("2. Lance", "lance")]),
    ("Wyvern_Lord_M", "Pegs, Wyverns, Griffons", r"\[WL Base\].*\[U\] Vanilla \+Weapons", [("2. Lance", "lance"), ("3. Axe", "axe")]),
    ("Wyvern_Knight_M", "Pegs, Wyverns, Griffons", r"\[WK Base\].*\[U\] Vanilla", [("2. Lance", "lance")]),
    
    # 魔法 / 神职
    ("Mage_M", "Nature-Type", r"\[Mage-Base\].*Vanilla FE6 \+Fix \[M\]", [("6. Magic", "magic")]),
    ("Sage_M", "Nature-Type", r"\[Sage-Base\].*Vanilla FE6 \+Fixes \[M\]", [("6. Magic", "magic"), ("7. Staff", "staff")]),
    ("Mage_Knight_M", "Valks, MKs, Magi", r"\[MK-Base\].*Vanilla \+Weapons \[M\]", [("6. Magic", "magic"), ("1. Sword", "sword")]),
    ("Monk_M", "Holy-Type", r"\[Monk-Base\].*Repal \+Staff \[M\] by Teraspark", [("6. Magic", "magic")]),
    ("Priest_M", "Holy-Type", r"\[T1 Priest-Base\].*Repal v2 \[M\]", [("7. Staff", "staff")]),
    ("Cleric_F", "Holy-Type", r"\[T1 Cleric-Base\].*Improved Repal \[F\]", [("7. Staff", "staff")]),
    ("Bishop_M", "Holy-Type", r"\[T2 Bishop-Base\].*Repal \[M\] by Eldritch", [("6. Magic", "magic"), ("7. Staff", "staff")]),
    ("Shaman_M", "Dark-Type", r"\[Shaman-Base\].*Vanilla \+Staff \[M\]", [("6. Magic", "magic")]),
    ("Druid_M", "Dark-Type", r"\[T2 Druid-Base\].*Vanilla FE6-8 \[M\]", [("6. Magic", "magic"), ("7. Staff", "staff")]),
    ("Summoner_M", "Dark-Type", r"\[T2 Summoner-Base\].*Vanilla \+Axes \[M\]", [("6. Magic", "magic")]),
    ("Troubadour_F", "Valks, MKs, Magi", r"\[Troubadour-Base\].*Vanilla FE7 \+Swords \[F\]", [("7. Staff", "staff")]),
    ("Valkyrie_F", "Valks, MKs, Magi", r"\[Valkyrie-Base\].*Vanilla \+Alt \[F\]", [("6. Magic", "magic"), ("7. Staff", "staff")]),
    
    # 特殊
    ("Dancer_F", "Bards, Dancers, Suppliers, Misc", r"\[Dancer-Base\].*Vanilla FE6 Larum", [("8. Refresh", "refresh")]),
    ("Bard_M", "Bards, Dancers, Suppliers, Misc", r"\[Bard-Base\].*Elffin by UltraFenix|\[Bard-Base\].*Nils", [("8. Refresh", "refresh")]),
]


def parse_weapon_txt(txt_path: str, weapon_type: str) -> Dict[str, List[Tuple[float, str]]]:
    """解析单个武器的 .txt 动画脚本。"""
    with open(txt_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    current_mode = None
    mode_frames: Dict[int, List[Tuple[float, str]]] = {}

    for line in lines:
        line_clean = line.strip()
        if not line_clean or line_clean.startswith('#'):
            continue

        m = re.match(r'^///\s*-\s*Mode\s+(\d+)', line_clean, re.IGNORECASE)
        if m:
            current_mode = int(m.group(1))
            mode_frames[current_mode] = []
            continue

        if line_clean.startswith('~~~'):
            current_mode = None
            continue

        if current_mode is not None:
            fm = re.match(r'^(\d+)\s+p-\s+([^\s#]+)', line_clean)
            if fm:
                duration = float(fm.group(1))
                frame_name = fm.group(2)
                mode_frames[current_mode].append((duration, frame_name))

    mode_map = WEAPON_MODE_MAP.get(weapon_type, WEAPON_MODE_MAP["sword"])
    result_anims: Dict[str, List[Tuple[float, str]]] = {}

    for mode_id, frames in mode_frames.items():
        if not frames:
            continue
        aliases = mode_map.get(mode_id, [f"{weapon_type}_mode_{mode_id}"])
        for alias in aliases:
            result_anims[alias] = frames

    return result_anims


def normalize_and_save_frame(src_path: str, dest_path: str) -> bool:
    """处理并规范化单张战斗动画帧。如果是 488x160 穿刺帧，执行方案 A 合成。"""
    im = Image.open(src_path)
    is_wide = False

    if im.size == (488, 160):
        is_wide = True
        left = im.crop((0, 0, 240, 160))
        right = im.crop((240, 0, 488, 160))

        if im.mode == 'P':
            bg_idx = left.getpixel((0, 0))
            composite = right.copy()
            for y in range(160):
                for x in range(240):
                    px = left.getpixel((x, y))
                    if px != bg_idx:
                        composite.putpixel((x, y), px)
            composite.save(dest_path, transparency=bg_idx)
        else:
            left_rgba = left.convert('RGBA')
            right_rgba = right.convert('RGBA')
            composite = right_rgba.copy()
            composite.paste(left_rgba, (0, 0), mask=left_rgba)
            composite.save(dest_path)
    else:
        if im.mode == 'P':
            bg_idx = im.getpixel((0, 0))
            im.save(dest_path, transparency=bg_idx)
        else:
            im.save(dest_path)

    return is_wide


def batch_import_all() -> None:
    print("==========================================================")
    print("  GBA 火焰纹章全原版职业战斗动画批量导入流水线 (Plan A)  ")
    print("==========================================================")
    print(f"源库路径: {REPO_BASE}")
    print(f"工程路径: {PROJECT_ROOT}\n")

    imported_classes = 0
    total_pierce_frames = 0
    total_frames = 0

    for cid, cat_sub, fold_pat, wpn_specs in CLASS_DEFINITIONS:
        if cid in PROTECTED_CLASSES:
            print(f"[-] 保护跳过已配专属职业: {cid}")
            continue

        # 查找类别目录
        cat_dir = None
        for c in os.listdir(REPO_BASE):
            if cat_sub.lower() in c.lower():
                cat_dir = os.path.join(REPO_BASE, c)
                break
        if not cat_dir:
            print(f"[!] 找不到分类: {cat_sub}")
            continue

        # 查找职业目录
        target_folder = None
        for f in os.listdir(cat_dir):
            if re.search(fold_pat, f, re.IGNORECASE):
                target_folder = os.path.join(cat_dir, f)
                break
        if not target_folder:
            print(f"[!] 找不到职业目录: {cid} (pattern: {fold_pat})")
            continue

        print(f"\n[+] 正在导入职业: {cid} <- {os.path.basename(target_folder)}")

        # 聚合该职业下所有武器的动画和素材引用
        class_all_anims: Dict[str, List[Tuple[float, str]]] = {}
        class_unique_textures: List[Tuple[str, str]] = []  # (rel_path, tex_file)
        seen_tex_paths = set()

        class_asset_dir_name = cid.replace('_M', '-Base[M]').replace('_F', '-Base[F]')

        for w_prefix, w_type in wpn_specs:
            # 找到匹配的武器子目录
            matched_w_dir = None
            for s in os.listdir(target_folder):
                if s.lower().startswith(w_prefix.lower()):
                    matched_w_dir = s
                    break
            if not matched_w_dir:
                print(f"    [?] 缺少武器子目录: {w_prefix}")
                continue

            src_w_path = os.path.join(target_folder, matched_w_dir)
            weapon_capital = w_type.capitalize()
            dest_w_rel = f"assets/battle_animations/{class_asset_dir_name}/{weapon_capital}"
            dest_w_abs = os.path.join(PROJECT_ROOT, dest_w_rel)
            os.makedirs(dest_w_abs, exist_ok=True)

            # 解析 .txt
            txt_files = [f for f in os.listdir(src_w_path) if f.endswith('.txt') and not f.startswith('README')]
            main_txt = [f for f in txt_files if not 'without_comment' in f]
            script_file = main_txt[0] if main_txt else txt_files[0]
            txt_path = os.path.join(src_w_path, script_file)

            weapon_anims = parse_weapon_txt(txt_path, w_type)

            # 复制与规范化帧图片
            png_files = [f for f in os.listdir(src_w_path) if f.endswith('.png') and not 'Sheet' in f]
            wpn_pierce_count = 0
            for png_name in png_files:
                src_png = os.path.join(src_w_path, png_name)
                dest_png = os.path.join(dest_w_abs, png_name)
                is_wide = normalize_and_save_frame(src_png, dest_png)
                total_frames += 1
                if is_wide:
                    wpn_pierce_count += 1
                    total_pierce_frames += 1

                # 记录资源路径
                rel_godot_path = f"res://{dest_w_rel.replace('\\', '/')}/{png_name}"
                if rel_godot_path not in seen_tex_paths:
                    seen_tex_paths.add(rel_godot_path)
                    class_unique_textures.append((rel_godot_path, f"{w_type}_{png_name}"))

            # 记录动画帧映射（按全局 res 路径）
            for anim_name, frames in weapon_anims.items():
                mapped_frames = []
                for dur, fname in frames:
                    rel_godot_path = f"res://{dest_w_rel.replace('\\', '/')}/{fname}"
                    mapped_frames.append((dur, rel_godot_path))
                class_all_anims[anim_name] = mapped_frames

            print(f"    - 武器 [{w_type}]: 处理 {len(png_files)} 帧 (穿刺合成 {wpn_pierce_count} 帧), 动作: {list(weapon_anims.keys())}")

        # 生成该职业的综合 SpriteFrames .tres
        if class_all_anims:
            ext_resources = []
            path_to_id = {}
            for idx, (res_path, alias) in enumerate(class_unique_textures, 1):
                clean_alias = re.sub(r'[^a-zA-Z0-9_]', '_', alias)
                res_id = f"{idx}_{clean_alias}"
                path_to_id[res_path] = res_id
                ext_resources.append(f'[ext_resource type="Texture2D" path="{res_path}" id="{res_id}"]')

            anim_blocks = []
            for anim_name, frames in class_all_anims.items():
                frame_entries = []
                for dur, rpath in frames:
                    res_id = path_to_id[rpath]
                    frame_entries.append(
                        '{\n'
                        f'"duration": {dur:.1f},\n'
                        f'"texture": ExtResource("{res_id}")\n'
                        '}'
                    )
                frames_joined = ", ".join(frame_entries)
                anim_blocks.append(
                    '{\n'
                    f'"frames": [{frames_joined}],\n'
                    '"loop": false,\n'
                    f'"name": &"{anim_name}",\n'
                    '"speed": 60.0\n'
                    '}'
                )

            animations_joined = ",\n".join(anim_blocks)
            tres_content = (
                '[gd_resource type="SpriteFrames" format=3]\n\n'
                + "\n".join(ext_resources) + "\n\n"
                + "[resource]\n"
                + f"animations = [\n{animations_joined}\n]\n"
            )

            tres_path = os.path.join(PROJECT_ROOT, "data", "battle_animation_tres", f"{cid}_frames.tres")
            os.makedirs(os.path.dirname(tres_path), exist_ok=True)
            with open(tres_path, 'w', encoding='utf-8') as f:
                f.write(tres_content)

            imported_classes += 1

    print("\n==========================================================")
    print(f"所有动画文件导出完成！")
    print(f"共导入 {imported_classes} 个原版职业动画，总计处理 {total_frames} 帧，合成 {total_pierce_frames} 个穿刺帧。")
    print("==========================================================")

    # 调用 Godot 引擎自动批量编译导入全部新增素材
    if os.path.exists(GODOT_BIN):
        print("\n正在启动 Godot 引擎静默批量编译导入所有新增资产...")
        subprocess.run([GODOT_BIN, "--headless", "--path", PROJECT_ROOT, "--editor", "--quit"], capture_output=True, text=True)
        print("Godot 引擎资产编译导入完成！")


if __name__ == "__main__":
    batch_import_all()
