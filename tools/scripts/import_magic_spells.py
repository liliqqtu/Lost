"""
魔法攻击与法杖治愈特效批量导入脚本
(Magic Spells & Staff VFX Batch Importer)
-------------------------------------------------------------
功能：
1. 从 FE-Repo-main 提取原版高品质魔法特效：
   - [Anima] Thunder (雷电 / 闪电)
   - [Anima] Wind (疾风 / 暴风)
   - [Anima] Elfire (烈火 / 业火)
   - [Dark] Flux (熔流 / 暗黑)
   - [Light] Luce / Lightning (闪光 / 神圣)
   - [Staff] Heal / Divine Sigil (治愈之光 / 回复法杖光效)
2. 转换为标准 240x160 32位 RGBA 图像，背景像素 (0,0) 设为 Alpha=0。
3. 生成集成全部魔法动画的 res://data/battle_animation_tres/Magic_frames.tres。
4. 调用 Godot 引擎后台静默重新编译导入全部新增素材。
"""

import os
import sys
import re
import subprocess
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

PROJECT_ROOT = r"E:\Dream\Lost"
REPO_SPELLS = r"E:\Dream\资源\FE-Repo-main\FE-Repo-main\Spells n Skills\7. Spells"
GODOT_BIN = r"E:\Godot\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64_console.exe"

SPELL_DEFS = [
    {
        "anim_name": "thunder",
        "source_dir": os.path.join(REPO_SPELLS, r"1. Anima\[Thunder] Thunder  Thoron {Mikey_Seregon}"),
        "target_dir": os.path.join(PROJECT_ROOT, r"assets\battle_animations\Anima\Thunder"),
        "frame_pattern": r"Spell_b_(\d+)\.png",
        "res_prefix": "res://assets/battle_animations/Anima/Thunder",
        "default_duration": 2.0,
    },
    {
        "anim_name": "wind",
        "source_dir": os.path.join(REPO_SPELLS, r"1. Anima\[Wind] Wind {JeorgeReds, Alice}\[Wind] Wind Fast {JeorgeReds, Alice}"),
        "target_dir": os.path.join(PROJECT_ROOT, r"assets\battle_animations\Anima\Wind"),
        "frame_pattern": r"Spell_b_(\d+)\.png",
        "res_prefix": "res://assets/battle_animations/Anima/Wind",
        "default_duration": 2.0,
    },
    {
        "anim_name": "elfire",
        "source_dir": os.path.join(REPO_SPELLS, r"1. Anima\[Fire] Elfire {SkidMarc25, Alice}"),
        "target_dir": os.path.join(PROJECT_ROOT, r"assets\battle_animations\Anima\Elfire"),
        "frame_pattern": r"Spell_b_(\d+)\.png",
        "res_prefix": "res://assets/battle_animations/Anima/Elfire",
        "default_duration": 2.0,
    },
    {
        "anim_name": "flux",
        "source_dir": os.path.join(REPO_SPELLS, r"3. Dark\[Dark] Flux {SkidMarc25, Alice}"),
        "target_dir": os.path.join(PROJECT_ROOT, r"assets\battle_animations\Dark\Flux"),
        "frame_pattern": r"Spell_b_(\d+)\.png",
        "res_prefix": "res://assets/battle_animations/Dark/Flux",
        "default_duration": 2.0,
    },
    {
        "anim_name": "lightning",
        "source_dir": os.path.join(REPO_SPELLS, r"2. Light\[Light] Luce {SHYUTERz}"),
        "target_dir": os.path.join(PROJECT_ROOT, r"assets\battle_animations\Light\Luce"),
        "frame_pattern": r"(?:Spell_b_|ルーチェ_b_)(\d+)\.png",
        "res_prefix": "res://assets/battle_animations/Light/Luce",
        "default_duration": 2.0,
    },
    {
        "anim_name": "heal",
        "source_dir": os.path.join(REPO_SPELLS, r"2. Light\[Light] Divine Sigil {SHYUTERz}"),
        "target_dir": os.path.join(PROJECT_ROOT, r"assets\battle_animations\Staff\Heal"),
        "frame_pattern": r"Spell_b_(\d+)\.png",
        "res_prefix": "res://assets/battle_animations/Staff/Heal",
        "default_duration": 3.0,
    },
]

def make_transparent_and_save(src_path: str, dst_path: str) -> None:
    im = Image.open(src_path)
    im_rgba = im.convert("RGBA")
    w, h = im_rgba.size
    # 背景基色取 (0, 0)
    bg_r, bg_g, bg_b, _ = im_rgba.getpixel((0, 0))
    
    # 获取原始像素
    pixels = im_rgba.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            # 颜色匹配或高容差匹配背景色
            if abs(r - bg_r) <= 8 and abs(g - bg_g) <= 8 and abs(b - bg_b) <= 8:
                pixels[x, y] = (0, 0, 0, 0)
    
    # 严格统一为标准 GBA 240x160 魔法特效画幅（部分特异条形帧如 240x64 居中对齐）
    if (w, h) != (240, 160):
        canvas = Image.new("RGBA", (240, 160), (0, 0, 0, 0))
        y_offset = (160 - h) // 2
        canvas.paste(im_rgba, (0, y_offset))
        im_rgba = canvas

    os.makedirs(os.path.dirname(dst_path), exist_ok=True)
    im_rgba.save(dst_path, "PNG")


def parse_spell_txt(txt_path: str) -> dict:
    """解析 Spell.txt 获取每帧持续时间"""
    durations = {}
    if not os.path.exists(txt_path):
        return durations
    try:
        with open(txt_path, "r", encoding="utf-8", errors="ignore") as f:
            lines = [l.strip() for l in f if l.strip()]
        for i, line in enumerate(lines):
            m = re.search(r"[BO]\s+([\w\-\.]+)\.png", line, re.IGNORECASE)
            if m:
                fn = m.group(1).lower()
                # 寻找下一行的持续帧数数字
                if i + 1 < len(lines):
                    next_line = lines[i + 1]
                    dur_m = re.match(r"^(\d+)$", next_line)
                    if dur_m:
                        durations[fn] = float(dur_m.group(1))
    except Exception as e:
        print(f"[-] 警告：解析 {txt_path} 失败: {e}")
    return durations


def process_spells():
    print("==========================================================")
    print("  GBA 火焰纹章魔法攻击与治愈光效特效批量导入流水线")
    print("==========================================================")
    
    all_animations_data = []
    ext_resources = []
    ext_id = 1
    
    # 1. 保持现有的 Fire 特效帧
    fire_dir = os.path.join(PROJECT_ROOT, r"assets\battle_animations\Anima\[Fire] Fire {SkidMarc25, Alice}")
    fire_frames = []
    for fn in sorted(os.listdir(fire_dir)):
        if fn.startswith("Spell_b_") and fn.endswith(".png"):
            res_id = f"{ext_id}_fire_{fn.replace('.', '_')}"
            res_path = f"res://assets/battle_animations/Anima/[Fire] Fire {{SkidMarc25, Alice}}/{fn}"
            ext_resources.append((res_id, res_path))
            fire_frames.append({"id": res_id, "duration": 2.0})
            ext_id += 1
            
    all_animations_data.append({
        "name": "fire",
        "frames": fire_frames,
        "speed": 60.0
    })
    print(f"[+] 保留现有火炎特效: fire (共 {len(fire_frames)} 帧)")
    
    # 2. 依次处理新增魔法特效
    for sdef in SPELL_DEFS:
        anim_name = sdef["anim_name"]
        src_dir = sdef["source_dir"]
        dst_dir = sdef["target_dir"]
        pattern = re.compile(sdef["frame_pattern"], re.IGNORECASE)
        res_prefix = sdef["res_prefix"]
        default_dur = sdef["default_duration"]
        
        if not os.path.exists(src_dir):
            print(f"[-] 目录不存在: {src_dir}")
            continue
            
        durations = parse_spell_txt(os.path.join(src_dir, "Spell.txt"))
        
        # 收集有效帧文件并排序
        frame_files = []
        for fn in os.listdir(src_dir):
            m = pattern.match(fn)
            if m:
                frame_files.append((int(m.group(1)), fn))
        frame_files.sort(key=lambda x: x[0])
        
        print(f"[+] 正在导入魔法特效: {anim_name} <- {os.path.basename(src_dir)} (发现 {len(frame_files)} 帧)")
        
        anim_frames = []
        for _, fn in frame_files:
            src_file = os.path.join(src_dir, fn)
            # 统一输出文件名标准为 Spell_b_XXX.png
            dst_fn = fn
            if dst_fn.startswith("ルーチェ_b_"):
                dst_fn = dst_fn.replace("ルーチェ_b_", "Spell_b_")
            dst_file = os.path.join(dst_dir, dst_fn)
            
            make_transparent_and_save(src_file, dst_file)
            
            res_id = f"{ext_id}_{anim_name}_{dst_fn.replace('.', '_')}"
            res_path = f"{res_prefix}/{dst_fn}"
            ext_resources.append((res_id, res_path))
            
            # 时长查表
            base_key = os.path.splitext(fn)[0].lower()
            dur = durations.get(base_key, default_dur)
            dur = max(1.0, float(dur))
            anim_frames.append({"id": res_id, "duration": dur})
            ext_id += 1
            
        all_animations_data.append({
            "name": anim_name,
            "frames": anim_frames,
            "speed": 60.0
        })
        # 如果是 lightning，增加别名 luce
        if anim_name == "lightning":
            all_animations_data.append({
                "name": "luce",
                "frames": anim_frames,
                "speed": 60.0
            })
            
    # 3. 生成 res://data/battle_animation_tres/Magic_frames.tres
    tres_path = os.path.join(PROJECT_ROOT, r"data\battle_animation_tres\Magic_frames.tres")
    print(f"\n[+] 正在写入聚合 SpriteFrames 资源: {tres_path}")
    
    with open(tres_path, "w", encoding="utf-8") as f:
        f.write('[gd_resource type="SpriteFrames" format=3 uid="uid://y0bhqolok4ke"]\n\n')
        for res_id, res_path in ext_resources:
            f.write(f'[ext_resource type="Texture2D" path="{res_path}" id="{res_id}"]\n')
        f.write('\n[resource]\nanimations = [\n')
        for i, anim in enumerate(all_animations_data):
            f.write('{\n')
            f.write('"frames": [\n')
            for j, frame in enumerate(anim["frames"]):
                comma = "," if j < len(anim["frames"]) - 1 else ""
                f.write(f'{{"duration": {frame["duration"]:.1f}, "texture": ExtResource("{frame["id"]}")}}{comma}\n')
            f.write('],\n')
            f.write('"loop": false,\n')
            f.write(f'"name": &"{anim["name"]}",\n')
            f.write(f'"speed": {anim["speed"]:.1f}\n')
            f.write('}' + (",\n" if i < len(all_animations_data) - 1 else "\n") + '\n')
        f.write(']\n')
        
    print(f"[+] Magic_frames.tres 生成完毕！包含 {len(all_animations_data)} 个魔法动画，共计 {len(ext_resources)} 个纹理引用。")
    
    # 4. 调用 Godot 后台静默编译资源
    print("\n正在启动 Godot 引擎后台重新扫描编译导入所有新增魔法特效...")
    try:
        subprocess.run(
            [GODOT_BIN, "--headless", "--editor", "--quit", "--path", PROJECT_ROOT],
            check=True,
            capture_output=True,
            timeout=120
        )
        print("Godot 引擎资产编译导入完成！")
    except Exception as e:
        print(f"[-] 调用 Godot 引擎扫描出现异常: {e}")

if __name__ == "__main__":
    process_spells()
