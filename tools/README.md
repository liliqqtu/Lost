# 外部工具与资源批处理管线 (External Tools & Asset Pipeline)

本目录用于存放游戏外部辅助工具、Python 自动化处理脚本及待处理素材，**不参与 Godot 引擎内的游戏构建与运行时打包**。

战斗动画导入后统一执行 `scripts/normalize_battle_animations.py`：合并重复别名、
补角色待机、提取接触时机并按原脚本拆分施法阶段。三个导入入口已自动接入。
可用 `python tools/scripts/normalize_battle_animations.py --check` 只检查规范化状态；
详细约定见 [战斗动画资源规范](../docs/battle_animation_resources.md)。

## 目录结构说明

- `scripts/`：存放 Python 批处理脚本（如地图切帧、调色板提取、精灵表自动切割、TileMap 生成脚本等）。
- `raw_assets/`：存放外部导入的待处理素材（如原始动画切片、未排版的待机/移动精灵帧、参考图等）。
