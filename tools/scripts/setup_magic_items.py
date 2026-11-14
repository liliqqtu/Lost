"""
配置魔法与法杖武器资源脚本
(Setup Magic and Staff Weapon Resources)
"""

import os
import sys
import shutil

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

PROJECT_ROOT = r"E:\Dream\Lost"
REPO_ICONS = r"E:\Dream\资源\FE-Repo-main\FE-Repo-main\Item Icons"

def setup():
    # 1. 复制武器图标
    anima_icons = [
        (os.path.join(REPO_ICONS, r"Magic - Anima\{2WB} (Vanilla + Blitz) Thunder.png"), 
         os.path.join(PROJECT_ROOT, r"assets\graphics\Item Icons\Anima\雷电.png")),
        (os.path.join(REPO_ICONS, r"Magic - Anima\{Artist Unknown} Wind.png"), 
         os.path.join(PROJECT_ROOT, r"assets\graphics\Item Icons\Anima\疾风.png")),
        (os.path.join(REPO_ICONS, r"Magic - Anima\{2WB} (Vanilla + Blitz) Elfire.png"), 
         os.path.join(PROJECT_ROOT, r"assets\graphics\Item Icons\Anima\业火.png")),
    ]
    for sp, dp in anima_icons:
        if os.path.exists(sp) and not os.path.exists(dp):
            shutil.copyfile(sp, dp)
            print(f"[+] 复制图标: {os.path.basename(dp)}")

    # 2. 生成武器资源
    weapons = [
        {
            "filename": "weapon_thunder.tres",
            "item_id": "weapon_thunder",
            "display_name": "雷电",
            "description": "凝聚雷电之力的理法术",
            "icon_path": "res://assets/graphics/Item Icons/Anima/雷电.png",
            "weapon_type": 4, # ANIMA
            "required_rank": 0, # E
            "might": 8,
            "hit": 80,
            "crit": 5,
            "weight": 6,
            "durability": 35,
            "min_range": 1,
            "max_range": 2,
        },
        {
            "filename": "weapon_wind.tres",
            "item_id": "weapon_wind",
            "display_name": "疾风",
            "description": "如风刃般锐利的风系理法术",
            "icon_path": "res://assets/graphics/Item Icons/Anima/疾风.png",
            "weapon_type": 4, # ANIMA
            "required_rank": 1, # D
            "might": 6,
            "hit": 85,
            "crit": 0,
            "weight": 4,
            "durability": 40,
            "min_range": 1,
            "max_range": 2,
        },
        {
            "filename": "weapon_elfire.tres",
            "item_id": "weapon_elfire",
            "display_name": "业火",
            "description": "释放高热狂暴爆炎的中级理法术",
            "icon_path": "res://assets/graphics/Item Icons/Anima/业火.png",
            "weapon_type": 4, # ANIMA
            "required_rank": 2, # C
            "might": 10,
            "hit": 75,
            "crit": 0,
            "weight": 10,
            "durability": 30,
            "min_range": 1,
            "max_range": 2,
        },
        {
            "filename": "weapon_flux.tres",
            "item_id": "weapon_flux",
            "display_name": "熔流",
            "description": "翻涌虚无吞噬生灵的基础暗黑法术",
            "icon_path": "res://assets/graphics/Item Icons/Dark/熔流.png",
            "weapon_type": 5, # DARK
            "required_rank": 1, # D
            "might": 7,
            "hit": 80,
            "crit": 0,
            "weight": 8,
            "durability": 45,
            "min_range": 1,
            "max_range": 2,
        },
        {
            "filename": "weapon_lightning.tres",
            "item_id": "weapon_lightning",
            "display_name": "闪光",
            "description": "自苍穹降下神圣天罚的初级光法术",
            "icon_path": "res://assets/graphics/Item Icons/Light/闪光.png",
            "weapon_type": 6, # LIGHT
            "required_rank": 0, # E
            "might": 4,
            "hit": 95,
            "crit": 5,
            "weight": 3,
            "durability": 35,
            "min_range": 1,
            "max_range": 2,
        },
    ]

    for w in weapons:
        path = os.path.join(PROJECT_ROOT, r"data\items", w["filename"])
        content = f'''[gd_resource type="Resource" script_class="Weapon" format=3]

[ext_resource type="Script" uid="uid://d4d43f53sv7ne" path="res://scripts/weapon.gd" id="1_script"]
[ext_resource type="Texture2D" path="{w["icon_path"]}" id="2_icon"]

[resource]
script = ExtResource("1_script")
item_id = &"{w["item_id"]}"
display_name = "{w["display_name"]}"
description = "{w["description"]}"
icon = ExtResource("2_icon")
required_rank = {w["required_rank"]}
weapon_type = {w["weapon_type"]}
might = {w["might"]}
hit = {w["hit"]}
crit = {w["crit"]}
weight = {w["weight"]}
durability = {w["durability"]}
max_durability = {w["durability"]}
min_range = {w["min_range"]}
max_range = {w["max_range"]}
'''
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"[+] 创建武器资源: {w['filename']}")

if __name__ == "__main__":
    setup()
