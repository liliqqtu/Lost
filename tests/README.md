# 自动化测试

使用 Godot 4.7，在项目根目录运行（Windows 推荐包装脚本）：

```powershell
./tests/run_tests.ps1 -Godot 'E:/Godot/Godot_v4.7-stable_mono_win64/Godot_v4.7-stable_mono_win64_console.exe'
```

包装脚本同时检查退出码、完整结束标记和脚本错误日志，避免 Godot 报错后仍返回 0。测试输出在 `tests/.runtime_saves/suite.stdout.log` 和 `suite.stderr.log`；如出现引擎原生崩溃，必须先解决启动环境，不能仅凭退出码判断测试结果。本轮还为测试单位和地图补齐了场景树所有权，最新完整运行没有退出时的对象或 RID 泄漏提示。

也可直接运行：

```powershell
godot --headless --path . res://tests/test_suite.tscn
# 只运行指定用例（省略 test_ 前缀和 .gd）
godot --headless --path . res://tests/test_suite.tscn -- campaign_save regressions
```

- 所有用例在项目 autoload 初始化之后作为 Node 运行，不再使用 `-s` 启动 SceneTree 测试。
- `test_case.gd` 提供完成信号；套件对未完成用例设置 30 秒超时。
- `test_runner.gd` 保留原集成测试；完整入口是 `test_suite.tscn`。
- `test_campaign_save.gd` 使用真实章节装配、JSON 文件和加载流程，检查章中恢复、跨章成长、装备绑定、事件、救援、仓库、支援、备份和槽位隔离。
- `test_regressions.gd` 走真实法杖确认、动画/无动画结算、耐久中断、攻击资格、AI 武器选择、再移动和败北界面。
- 存档测试显式覆盖存储目录到 `res://tests/.runtime_saves/` 下，目录已忽略；不删除或改写玩家 `user://` 槽位。

### 物品与商店

- `fe8_item_catalog`：138 件原版资源全量加载、九类运输队、逐件 JSON 存档往返、模板实例隔离及背包上限。
- `shop`：三店默认货单、买入/取消/出售确认、余额、耐久折价、满包寄送与满仓失败原子性。
- `party_funds`：共用钱包存档往返、章节继承与旧存档兼容；`deferred_items`：未实现道具不误消耗、特殊法杖不误入治疗。
- 在编辑器打开 `tests/shop_demo.tscn` 按 F6，按 1/2/3 切换三类商店，使用独立钱包与仓库。方向键选择、Z 确认、X 返回、S 查看说明，Enter 跳过对话。
- `tests/shop_capture.tscn` 为非 headless 视觉检查入口，截图写入 `tests/.runtime_saves/shop_*.png`；需作为普通场景启动，以便先初始化 autoload。

若 Mono 在扫描脚本之前报 `.NET: Assemblies not found` 并原生崩溃，说明本次没有完成测试，不能视为通过；本机受限启动环境曾阻止依赖加载，需在能访问引擎依赖的环境运行，并确认完整的 `SUITE ALL PASSED` 标记和无脚本错误日志。
- `QuietPrologue` / `QuietChapter` 仅跳过自动开场，不替换生产的单位、UI、保存、恢复及结算实现。

- `battle_animation_resources` 加载全部战斗资源，检查待机、别名、纹理与施法阶段，
  实际验证必杀接普攻、回避和普通/必杀施法的单次命中与待机收尾；允许 180 秒完成全量资源加载。

## 友军通行与绿色回合回归

`allied_turns` 覆盖狭窄通道穿过同队/友方单位、敌对阻路、普通移动与再移动的占用落点拒绝、绿色 AI 穿过同队阻挡后实际攻击、绿色治疗蓝军、三阵营回合顺序、横幅期间输入锁定，以及说得后跳过绿色阶段。该用例已加入统一测试入口。
