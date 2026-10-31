# 你是个软件工程师兼顾游戏策划,如有需求不明的地方，向用户询问

一、项目目标与开发准则

本项目使用 Godot 4.7 + GDScript 复刻 GBA《火焰纹章》（圣魔之光石）的核心战棋系统。
Agent 在编写代码时，应遵循本文档规定的架构，不得随意修改职责划分。
项目以长期维护为前提，代码质量为第一，功能完善为第二。

### 核心编码规范
1. **坐标命名统一**：
   - 地图格子坐标：必须使用 `Vector2i`，变量名统一为 `cell`（禁止混用 `tile`, `grid`, `position`）。
   - 像素世界坐标：使用 `Vector2`，变量名统一为 `position` 或 `global_position`。
2. **脚本行数硬约束**：
   - **所有脚本文件严禁超过 500 行**。超过即代表承担了过多职责，必须按业务领域分包/拆出子模块或组件。
3. **接口稳定性与向后兼容**：
   - 修改现有接口前必须保持向后兼容，不随意破坏旧模块调用方式；新增功能优先扩展已有类，现有类职责明确时通过新增方法或接口扩展。
4. **领域文档协同**：
   - 详细系统设计与公式说明归档于 `docs/` 目录：
     - `docs/combat_system.md`：战斗序列、伤害/相克公式、勇者连击与特技
     - `docs/unit_and_items.md`：单位数据、背包生命周期、武器熟练度、支援系统
     - `docs/ui_and_interaction.md`：信息查看（上下避让）、UI 状态机、数值升降微动箭头

---

## 二、核心架构约定与不变量约束

### 1. 战斗管理器门面（BattleManager Facade）
- `scripts/battle_manager.gd` 仅作为对外门面（持有状态机、顶层输入分派、落点查询、生命周期收尾 `finalize_action`）。
- 具体子系统分包为 RefCounted 逻辑模块：
  - `battle_unit_commands.gd`：指令流程与子菜单/面板回调
  - `battle_combat.gd`：战斗结算循环、耐久扣减、经验升级
  - `battle_phases.gd`：回合切换、敌方 AI 调度、地图事件调度
  - `battle_map_interaction.gd`：村庄、宝箱、对话、支援交互
  - `battle_rescue.gd`：救援、放下、交接候选与执行
  - `battle_canto.gd`：再移动判定与移动控制
  - `battle_range_inspect.gd`：单敌与全敌威胁范围并集

### 2. 单位与背包生命周期不变量（必须遵守）
- **背包容量**：`Unit.BAG_LIMIT = 5`。
- **唯一操作入口**：外部代码**严禁直接修改 `unit.inventory` 数组或给 `current_weapon` 赋值**，必须调用 Unit 封装接口：
  - `add_item(item)` / `remove_item(item)` / `remove_item_at(index)`
  - `equip_item(item)` / `consume_weapon_durability(amt)` / `break_current_weapon()`
- **唯一实例绑定**：`current_weapon` 必须指向 `inventory` 数组内的实例；物品入包前须 `duplicate()` 隔离 `.tres` 模板。
- **攻击范围统一查询**：全系统一律通过 `Unit.get_weapon_ranges()` 与 `Unit.get_attack_range(tile_map, cells)` 查询攻击范围。

### 3. 统一技能模型（Skill Resource）
- 武器技能、角色个人技能、职业技能统一使用 `Skill` 资源（`scripts/skill.gd`）。
- 武器额外属性加成（如断弦 `stat_bonus_skl = 10, stat_bonus_spd = 10`）由 `Unit.get_effective_*()` 统一计算。
- 战斗与面板统一调用 `Unit.get_all_active_skills()` 获取当前生效技能。

### 4. 信息查看系统（InfoViewer）
- 通用流程控制器（`scripts/info_viewer.gd`）：只认 `get_info() -> String` 接口，禁止在 Viewer 内针对具体对象写类型分流。
- **上下避让原则**：上半区条目向下展开，下半区条目向上展开；水平方向起始位置对齐手光标/条目左缘（`row_pos.x - 12.0`），长文本向左自适应收缩，严禁遮挡当前行与手光标。

---

## 三、当前工作看板

## 待测试
- [ ] **勇者之弓连击测试**：装备勇者之弓攻击敌人，普通攻击打 2 击，攻速差 $\ge 4$ 追击打 4 击。
- [ ] **断弦属性增益与笃行特技**：装备断弦后技术 +10、速度 +10，人物面板显示绿色加成数字；攻击后触发再次行动（每回合限 1 次）。
- [ ] **公在光环技能**：携带公在技能的单位，其临近 2 格内同队友军获得守备 +2、魔防 +2 加成。
- [ ] **武器选择菜单升降指示**：进入战斗选择武器时，属性增减在数字旁显示微动升降箭头（蓝 ▲ / 红 ▼）。
- [ ] **人物面板物品描述框**：按 R 查看第 1~5 行物品，文字框在物品行上下自适应展开，起始 X 坐标对齐手光标/物品左缘，不遮挡当前物品行。

## 待开发 (完成后更新到待测试)
- [ ] **特殊概率触发战斗特技**：如“日耀”按技术%概率触发吸血等战斗特技的动画演出与战中触发结算。
- [ ] **InfoData 结构化资源**（按规划暂缓：当前描述仍为单一字符串，后续需要标题+图标+多段文字时再建立）。
