"""
Fire Emblem GBA 战斗动画导入工具 (FE Battle Animation Importer)
-------------------------------------------------------------
功能：
1. 从 FE-Repo 目录解析 FEditor/FEBuilder 战斗动画（.txt 脚本 + .png 帧序列）。
2. 执行方案 A 规范化：
   - 将 488x160 的双层穿刺帧（Piercing Frame）自动合并为标准的 248x160 完整帧（左侧前景覆盖层叠合到右侧背景本体层）。
   - 保持 248x160 常规帧不变，确保调色板与透明度规范统一。
3. 自动生成 Godot 4 标准的 SpriteFrames (.tres) 资源文件。
4. 计算攻击命中点（Normal Hit C1A / Critical Hit C08）的精确时间（秒），供 AnimationPlayer 命中轨道参考。
"""

import os
import sys
import re
import argparse
from typing import Dict, List, Tuple
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

# 武器模式到动画名称的映射
MODE_MAP = {
    1: ["{wpn}"],                           # 普通近战攻击
    3: ["{wpn}_crit", "{wpn}_critical"],    # 近战暴击（同时提供 _crit 和 _critical 别名）
    5: ["{wpn}_ranged"],                    # 远程攻击
    6: ["{wpn}_ranged_crit"],               # 远程暴击
    7: ["{wpn}_dodge"],                     # 回避动作
    8: ["{wpn}_dodge_ranged"],              # 远程回避
    9: ["{wpn}_stand"],                     # 近战待机
    10: ["{wpn}_idle"],                     # 待机动作
    12: ["{wpn}_miss"],                     # 挥空/MISS 攻击
}

# 关键命中控制码
HIT_CODES = {"C1A", "C08", "C04", "C05"}


def parse_animation_script(txt_path: str, weapon_type: str) -> Tuple[Dict[str, List[Tuple[float, str]]], Dict[str, float]]:
    """解析 .txt 脚本，返回 (动画列表, 关键帧时间点)。"""
    with open(txt_path, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()

    current_mode = None
    mode_frames: Dict[int, List[Tuple[float, str]]] = {}
    mode_hits: Dict[int, float] = {}

    current_ticks = 0
    hit_recorded = False

    for line in lines:
        line_clean = line.strip()
        if not line_clean or line_clean.startswith('#'):
            continue

        # 匹配模式标识：/// - Mode X
        m = re.match(r'^///\s*-\s*Mode\s+(\d+)', line_clean, re.IGNORECASE)
        if m:
            current_mode = int(m.group(1))
            mode_frames[current_mode] = []
            current_ticks = 0
            hit_recorded = False
            continue

        if line_clean.startswith('~~~'):
            current_mode = None
            continue

        if current_mode is not None:
            # 检查命令码（如 C1A 命中）
            for code in HIT_CODES:
                if line_clean.startswith(code) and not hit_recorded:
                    mode_hits[current_mode] = current_ticks / 60.0
                    hit_recorded = True
                    break

            # 匹配帧行：如 "3 p- Sword_001.png"
            fm = re.match(r'^(\d+)\s+p-\s+([^\s#]+)', line_clean)
            if fm:
                duration = float(fm.group(1))
                frame_name = fm.group(2)
                mode_frames[current_mode].append((duration, frame_name))
                current_ticks += duration

    # 映射为 Godot 动画名称
    result_anims: Dict[str, List[Tuple[float, str]]] = {}
    result_hit_times: Dict[str, float] = {}

    for mode_id, frames in mode_frames.items():
        if not frames:
            continue
        aliases = MODE_MAP.get(mode_id, [f"{weapon_type}_mode_{mode_id}"])
        hit_time = mode_hits.get(mode_id, -1.0)
        for alias in aliases:
            anim_name = alias.format(wpn=weapon_type)
            result_anims[anim_name] = frames
            if hit_time >= 0:
                result_hit_times[anim_name] = hit_time

    return result_anims, result_hit_times


def process_frame_image(src_path: str, dest_path: str) -> Tuple[bool, str]:
    """处理并规范化单张战斗动画帧。如果是 488x160 穿刺帧，执行方案 A 合成。"""
    im = Image.open(src_path)
    is_wide = False
    info_msg = ""

    if im.size == (488, 160):
        is_wide = True
        # 拆分为左半（前景 240x160）与右半（本体 248x160）
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

        info_msg = f"[方案A合成] 488x160 -> 248x160: {os.path.basename(dest_path)}"
    else:
        # 常规 248x160 帧
        if im.mode == 'P':
            bg_idx = im.getpixel((0, 0))
            im.save(dest_path, transparency=bg_idx)
        else:
            im.save(dest_path)
        info_msg = f"[常规保存] {im.size[0]}x{im.size[1]}: {os.path.basename(dest_path)}"

    return is_wide, info_msg


def generate_sprite_frames_tres(anims: Dict[str, List[Tuple[float, str]]], 
                                asset_rel_dir: str, 
                                dest_tres_path: str) -> None:
    """生成 Godot 4 标准 SpriteFrames .tres 资源文件。"""
    # 收集全部引用的纹理文件名（保持有序且唯一）
    unique_textures = []
    seen = set()
    for anim_name, frames in anims.items():
        for duration, frame_file in frames:
            if frame_file not in seen:
                seen.add(frame_file)
                unique_textures.append(frame_file)

    # 构建 ext_resource 映射
    ext_resources = []
    tex_to_id = {}
    for idx, tex_file in enumerate(unique_textures, 1):
        res_id = f"{idx}_{tex_file.replace('.', '_')}"
        res_path = f"res://{asset_rel_dir.replace('\\', '/')}/{tex_file}"
        tex_to_id[tex_file] = res_id
        ext_resources.append(f'[ext_resource type="Texture2D" path="{res_path}" id="{res_id}"]')

    # 构建 animations 数组
    anim_blocks = []
    for anim_name, frames in anims.items():
        frame_entries = []
        for duration, frame_file in frames:
            res_id = tex_to_id[frame_file]
            frame_entries.append(
                '{\n'
                f'"duration": {duration:.1f},\n'
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

    os.makedirs(os.path.dirname(dest_tres_path), exist_ok=True)
    with open(dest_tres_path, 'w', encoding='utf-8') as f:
        f.write(tres_content)


def import_battle_animation(src_dir: str, 
                            project_root: str,
                            dest_asset_subpath: str,
                            tres_name: str, 
                            weapon_type: str = "sword") -> None:
    """执行单个职业战斗动画的完整导入流程。"""
    print(f"=== 开始导入战斗动画 ===")
    print(f"来源目录: {src_dir}")
    print(f"目标素材: res://{dest_asset_subpath}")
    print(f"目标资源: res://data/battle_animation_tres/{tres_name}")

    # 1. 查找动画脚本
    txt_files = [f for f in os.listdir(src_dir) if f.endswith('.txt') and not f.startswith('README')]
    if not txt_files:
        raise FileNotFoundError(f"在 {src_dir} 中未找到 .txt 动画脚本")
    
    # 优先选主脚本（如 Sword.txt，排除 without_comment.txt）
    main_txt = [f for f in txt_files if not 'without_comment' in f]
    script_file = main_txt[0] if main_txt else txt_files[0]
    txt_path = os.path.join(src_dir, script_file)
    print(f"解析动画脚本: {script_file}")

    anims, hit_times = parse_animation_script(txt_path, weapon_type)
    print(f"成功解析 {len(anims)} 个动作动画:")
    for anim_name, frames in anims.items():
        total_ticks = sum(f[0] for f in frames)
        hit_str = f", 命中时刻: {hit_times[anim_name]:.3f}s" if anim_name in hit_times else ""
        print(f"  - [{anim_name}]: {len(frames)} 帧, 时长: {total_ticks/60.0:.2f}s ({int(total_ticks)} ticks){hit_str}")

    # 2. 规范化并复制所有 PNG 帧
    abs_dest_dir = os.path.join(project_root, dest_asset_subpath)
    os.makedirs(abs_dest_dir, exist_ok=True)

    png_files = [f for f in os.listdir(src_dir) if f.endswith('.png') and not 'Sheet' in f]
    print(f"开始处理 {len(png_files)} 张图像帧...")

    wide_count = 0
    for png_name in sorted(png_files):
        src_png = os.path.join(src_dir, png_name)
        dest_png = os.path.join(abs_dest_dir, png_name)
        is_wide, msg = process_frame_image(src_png, dest_png)
        if is_wide:
            wide_count += 1
            print(f"  * {msg}")

    print(f"图像处理完成: 共处理 {len(png_files)} 帧，其中合成了 {wide_count} 个 488x160 穿刺帧！")

    # 3. 生成 SpriteFrames .tres 资源
    dest_tres_path = os.path.join(project_root, "data", "battle_animation_tres", tres_name)
    generate_sprite_frames_tres(anims, dest_asset_subpath, dest_tres_path)
    print(f"已生成动画资源: {dest_tres_path}")

    # 4. 自动触发 Godot 引擎扫描与资产导入（如已配置 Godot 可执行路径）
    godot_bin = r"E:\Godot\Godot_v4.7-stable_mono_win64\Godot_v4.7-stable_mono_win64_console.exe"
    if os.path.exists(godot_bin):
        print("正在调用 Godot 引擎自动注册与编译导入素材...")
        import subprocess
        res = subprocess.run([godot_bin, "--headless", "--path", project_root, "--editor", "--quit"], capture_output=True, text=True)
        print("Godot 资产导入完成！")
    else:
        print("提示: 未检测到 Godot 控制台路径，请在打开 Godot 编辑器时自动触发资源导入。")

    print("=== 导入完成 ===")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="FE Battle Animation Importer")
    parser.add_argument("--src", required=True, help="FE-Repo 原始动画目录 (包含 .txt 与 .png)")
    parser.add_argument("--project_root", default=r"E:\Dream\Lost", help="项目根目录")
    parser.add_argument("--dest_asset", required=True, help="assets 相对路径 (例如 assets/battle_animations/Mercenary-Base[M]/Sword)")
    parser.add_argument("--tres", required=True, help="生成的 .tres 文件名 (例如 Mercenary_M_frames.tres)")
    parser.add_argument("--weapon", default="sword", help="武器类型英文缩写 (例如 sword, axe, lance, bow)")

    args = parser.parse_args()
    import_battle_animation(
        src_dir=args.src,
        project_root=args.project_root,
        dest_asset_subpath=args.dest_asset,
        tres_name=args.tres,
        weapon_type=args.weapon
    )
