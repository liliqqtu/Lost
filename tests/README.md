# 引擎内自动化测试套件 (Godot In-Engine Test Suite)

本目录专门存放 Godot 引擎内部的 GDScript 自动化测试用例与测试运行场景。

## 核心文件说明

- `test_runner.tscn` / `test_runner.gd`：集成测试入口总控，可通过命令行无头运行：
  ```bash
  godot --headless "res://tests/test_runner.tscn"
  ```
- `test_*.gd`：各模块的底层逻辑单元测试（AI、战斗结算、伤害计算、技能系统、再移动、救援、支援等）。
- `test_save_system.gd`：存档与读档系统测试。
