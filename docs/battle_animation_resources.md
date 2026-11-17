# 战斗动画资源规范

适用于 `data/battle_animation_tres/` 的角色 SpriteFrames。`Magic_frames.tres`
是独立法术特效库，不添加角色待机或武器动作。角色图片与原有资源 UID 保持不变。

## 动作与命名

| 职责 | 标准名称 | 约定 |
| --- | --- | --- |
| 待机 | `<武器>_idle` | 可为单帧；循环；每一击结束明确恢复 |
| 普通攻击 | `sword` / `lance` / `axe` / `bow` 等 | 一次完整出手与收招；不循环 |
| 必杀 | `<武器>_crit` | 可选；缺失回退同距离普通攻击 |
| 远程 | `<武器>_ranged` / `_ranged_crit` | 按交战格距选取；与伤害使用力量/魔力分别判断 |
| 回避 | `<武器>_dodge` / `_dodge_ranged` | 可选；在攻击接触事件播放，结束回待机 |
| 挥空 | `<武器>_miss` | 有独立动作时保留；缺失使用普通攻击并显示 MISS |
| 施法 | `magic_start` / `magic_loop` / `magic_end` | 起手、等待法术的循环、收手 |
| 必杀施法 | `magic_start_crit`，可选 `magic_loop_crit` / `magic_end_crit` | 循环和收手相同则复用普通版本 |

`_critical` 统一为 `_crit`，相同的 `_stand` / `_idle` / Mode 11 待机合并。
相同的近远程回避也共用一份动作。确实不同的帧序列保留，不做跨职责的任意去重。
历史名称保存在 `metadata/battle_animation_aliases`，由
`BattleAnimationActions.resolve()` 兼容；直接调用 `SpriteFrames.has_animation()`
或 `AnimatedSprite2D.play()` 不会自动解析别名，新增业务应通过动作选择模块。

## 播放职责

- `BattleAnimationActions` 只负责动作选择、别名和恢复待机。每击重新根据武器、
  距离、普通/必杀、命中/落空选择动作，不从当前动画名称拼接下一击。
- `BattleAnimationPlayback` 协调角色、独立法术特效与命中时机。已有战斗画面的
  `play_strike()` 等接口保持不变。
- 物理动作无需强制拆三段。完整收招后恢复待机；老资源无独立待机时保持基础
  动作第 0 帧。不能把任意攻击末帧当作站姿，也不能跳过实际收招。
- 魔法必须具有完整三段才能进入三段流程。循环或保持施法姿势，直到独立法术
  播完，再收手。伊萨尔已有手工三段动作保持原有帧序列和时长。
- 回避、受击闪光、MISS 等必要反应结束后再进入下一击；法杖与舞蹈也明确恢复待机。
- 动画只消费预先确定的战斗结果、更新显示 HP；真实 HP、耐久和技能结算归
  `BattleCombat`，Boss 遗言/击破和终局时序保持原有流程。

## 命中事件

角色资源的 `metadata/battle_animation_impacts` 保存“动画名 -> 秒数”。原版导入
依据整个帧序列匹配源脚本，普通接触使用 C1A，必杀使用 C08～C0C；挥空脚本的
C04 用作回避接触点。C04 不当作一般伤害标记，C05 是释放法术，不当作命中。

手工资源继续使用场景中以自身资源名命名的 AnimationPlayer 动画库。例如
`Te/bow`、`Brigand_M/axe_crit`。禁止借用其他职业同名动作的命中轨道。
新手工作品应配置自己的命中轨道；无法确定命中点的动作仍在动作播完后兜底一次，
不猜测百分比时机。尚未接入独立投射物的远程动作保留完整帧序列，命中同样遵循
已配置事件或结束兜底；本次规范化不补造箭矢、投斧或魔法剑特效。

法术命中由独立效果的 `Magic/<效果名>` 轨道或已有法术时间表控制。每击只触发
一次显示结算，延时回调带打击序号防止串入下一击；动画速度与事件速度同步。

## 导入与批量整理

三个现有导入入口导出后都调用同一个规范化工具：

```powershell
python tools/scripts/normalize_battle_animations.py
python tools/scripts/normalize_battle_animations.py --check
```

默认原始脚本目录为 `E:/Dream/资源/FE-Repo-main/FE-Repo-main/Battle Animations`，
可用 `--source` 指定其他仓库或单个源脚本。工具先在临时副本中验证整批转换，
全部成功后才写回；`--check` 只检查，存在待整理内容时返回非零。

导入法师依据 C05/C01 边界拆成起手、维持与收手；两条命令之间没有图片时，
用起手的最后姿势作为单帧维持。发现无法唯一确定的拆分边界会报错，避免猜测。
Te、伊萨尔、山贼和男游侠手工攻击的帧序列、时长保持原样，仅补待机和规范名称。

## 验证

`battle_animation_resources` 加载目录下全部资源并检查纹理、别名、循环与施法
阶段，实际播放佣兵必杀接普通攻击、回避、导入法师普通/必杀与伊萨尔施法，验证
单次显示扣血与待机收尾。资源检查允许 180 秒，其余用例仍为 30 秒。
