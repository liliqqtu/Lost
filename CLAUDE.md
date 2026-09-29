你是个软件工程师兼顾游戏策划

一、项目目标

本项目使用 Godot 4.7 + GDScript 复刻 GBA《火焰纹章》（圣魔之光石）的核心战棋系统。

Agent 在编写代码时，应遵循本文档规定的架构，不得随意修改职责划分。

项目以长期维护为前提，代码质量为第一，功能完善为第二。

编码规范

所有地图坐标：

Vector2i

世界坐标：

Vector2

统一使用：

cell

表示地图坐标。

不要混用：

tile

grid

position

## 当前项目结构 （每次更改后请更新）
Lost (Godot Game Project)
|
|- .godot/                          # Godot引擎自动生成的文件
|   |- editor/                      # 编辑器配置
|   |- imported/                    # 导入的资源文件
|   |- .gdignore
|   |- global_script_class_cache.cfg
|
|- .editorconfig                    # 编辑器配置
|- .gitattributes                   # Git属性
|- .gitignore                       # Git忽略文件
|
|- icon.svg                         # 项目图标
|- icon.svg.import                  # 导入配置
|
|- project.godot                     # Godot项目配置文件
|
|- CLAUDE.md                        # AI项目说明文档
|- 心得.md                          # 心得笔记
|
|- Global.gd                        # 全局脚本
|- Global.gd.uid
|
|- data/                          # 数据资源目录
|   |- map_sprite_frames/       # 地图精灵帧
|   |   |   |- Brigand_map_sprite.tres
|   |   |   |- Nomad_map_sprite.tres
|   |   |   |- Sage_sprite_frames.tres
|   |- battle_animation_tres/   # 战斗动画帧
|   |   |   |- Brigand_M_frames.tres
|   |   |   |- Nomad_M_frames.tres
|   |   |   |- Ranger_M_frames.tres
|   |   |   |- Te.tres
|   |   |   |- Isar.tres
|   |- item/                        # 物品资源（.tres 模板）
|   |   |- weapon_iron_bow.tres     # 铁弓
|   |   |- weapon_fire.tres         # 火炎（ANIMA 魔法，MAGIC_EFFECT_ANIM 表映射 fire 特效）
|   |   |- consumable_potion.tres   # 伤药（恢复15HP，5/5次）
|   |   |- chest_key.tres           # 宝箱钥匙（key_id="chest_1"，5E）
|   |- affinity/                    # 属性资源（5G 支援：属性名/图标/命中·回避·必杀贡献）
|   |   |- fire.tres / dark.tres / anim.tres / thunder.tres / ice.tres / light.tres / wind.tres
|   |- support/                     # 支援表资源（5G：一对角色的支援关系数据）
|   |   |- te_isar.tres             # 忒×伊萨尔（炎×暗，C门槛=1，测试对话"1"）
|   |- skill/                       # 技能场景
|   |   |- flourish.tscn            # 焕发（再移动）
|   |   |- lost.tscn                # 仿徨（所有武器射程减一）
|
|
|- scripts/                         # 核心脚本目录
|   |- battle_calculator.gd         # 战斗计算器（序列生成、相克、地形、经验）
|   |- battle_forecast.gd           # 战斗预测
|   |- battle_manager.gd           # 战斗管理器门面（状态机/输入分派/选中移动/行动收尾/地图查询；对外接口不变，非战斗功能已分包到下列 battle_* 模块，各模块经 bm 引用共享状态）
|   |- battle_unit_commands.gd     # 单位指令流程（行动菜单/目标选择/战斗预览/物品·运输队·交换面板回调/人物面板输入）
|   |- battle_map_interaction.gd   # 地图交互（村庄/宝箱访问、人物对话，5E）
|   |- battle_rescue.gd            # 救援/放下/交接/交换候选与执行（5F）
|   |- battle_range_inspect.gd     # 敌人范围查看（单敌移动+攻击范围 / 全员攻击并集）
|   |- battle_canto.gd             # 再移动（焕发技能，CANTO_MOVING 状态）
|   |- battle_combat.gd            # 战斗结算执行（读序列掷骰+动画同步+武器耐久+战后经验/升级结算）
|   |- battle_phases.gd            # 回合切换/敌方回合/地图事件调度
|   |- enemy_ai.gd                 # 敌方 AI 决策器（纯函数、无状态）
|   |- action_menu.gd              # 行动菜单（动态项+固定项，itemsbox 背景+手光标）
|   |- item_menu.gd                # 物品菜单（使用消耗品/换装，itemsbox 背景+手光标，宽度按内容自适应）
|   |- trade_menu.gd               # 交换界面（5F：双方物品栏+class card，FE GBA 拾取/交换/转移规则）
|   |- pathfinder.gd                # 路径查找
|   |- range_drawer.gd              # 范围绘制
|   |- skill.gd                     # 技能数据（Resource，焕发/仿徨等）
|   |- item.gd                      # 物品基类（display_name/icon/description + is_* 分流钩子）
|   |- weapon.gd                    # 武器（extends Item，might/hit/crit/weight/range/durability + 武器等级 required_rank/武器经验 weapon_exp，WeaponRank 枚举与 FE8 WEXP 阈值）
|   |- consumable.gd                # 消耗品（extends Item，heal_hp + durability 使用次数）
|   |- convoy_store.gd              # 运输队全局仓库（autoload 单例，扁平存储 9 类映射）
|   |- support_store.gd             # 支援系统全局数据（autoload 单例，5G：支援值/等级/章节积累/加成查询）
|   |- support_pair.gd              # 支援表条目（Resource：双方名字/属性/门槛/肖像/C·B·A 对话，5G）
|   |- affinity.gd                  # 属性资源（Resource：属性名/图标/命中·回避·必杀贡献，5G）
|   |- class_data.gd                # 职业数据（职业名/职业卡/能力上限/成长率/职业强度 class_power/武器类型等级 rank_*/技能/骑乘类型/属性 affinity）
|   |- key.gd                       # 钥匙（extends Item，key_id 与宝箱一一对应，5E）
|   |- interactable.gd              # 地图可交互物（村庄门/宝箱，interactables 组，5E）
|   |- map_event.gd                 # 地图事件（Resource：触发条件/trigger_turn/once/actions，5E）
|   |- map_action.gd                # 事件动作基类（execute(ctx) 可 async，5E）
|   |- action_dialogue.gd           # 动作：对话（5E）
|   |- action_reinforce.gd          # 动作：单位增援登场（预摆节点/实例化两种来源+走位演出，5E）
|   |- action_give_item.gd          # 动作：获得物品（背包满落运输队，5E）
|
|- scene/                           # 场景目录
|   |- ui/                          # UI 场景与脚本（5F 整合迁移：原 scene 顶层 Control 场景归拢于此）
|   |   |- camera.gd / camera.tscn   # 相机
|   |   |- cursor.gd / cursor.tscn   # 地图光标
|   |   |- cursorhand.gd / cursorhand.tscn  # 手光标（菜单选择跟随，行动菜单/物品栏共用）
|   |   |- itemsbox.tscn            # 九宫格背景（行动菜单宽 48 / 物品栏宽度按内容自适应，size.y 随内容动态调整）
|   |   |- battle_animation.gd / .tscn  # 战斗动画（阶段五 5A，武器名带耐久、魔法三段演出）
|   |   |- unit_info_panel.gd / .tscn   # 人物信息面板（三页：角色信息/物品/武器&支援等级）
|   |   |- convoy.gd / convoy.tscn  # 运输队面板（取出/寄存，纯键盘）
|   |   |- talk.gd / talk.tscn      # 对话场景（BG背景CG + Dialogue九宫格框 + 四肖像槽+气泡）
|   |   |- itemrow.gd / itemrow.tscn  # 物品行视图组件（图标+名称+耐久，背包/运输队共用）
|   |   |- grade_up.gd / grade_up.tscn  # 升级场景（升级加点动画；人物转职后也调用此场景，但先不开发人物转职功能）
|   |   |- add_up.gd / add_up.tscn  # 单项加点动画（星星螺旋+箭头，受控播放：由 grade_up 调 play()）
|   |   |- exp_box.tscn             # 经验条面板（ExpBar+Exp 数字，战斗结束后由 battle_animation 动态加载）
|   |- animation/                   # 界面动画（interface.tscn、press_start 着色器）
|   |
|   |
|   |
|
|   |
|   |- character/                   # 角色相关
|   |   |- UnitShader.gdshader      # 角色着色器
|   |   |- grayscale.gdshader       # 灰度着色器
|   |   |- unit.tscn                # 基础角色场景
|   |   |
|
|   |   |
|   |   |- class_data/              # 职业数据资源（.tres，检查器可调上限/技能/骑乘类型）
|   |       |- brigand.tres         # 山贼
|   |       |                        # 忒/伊萨尔的职业数据在各自单位目录（te/class_data.tres 游牧民=骑乘·男、isar/class_data.tres 贤者=步行）
|   |   |
|   |   |- units/                   # 单位脚本
|   |       |- unit.gd              # 基础单位脚本（含 class_data 引用、5F 救援字段与 Aid 计算）
|   |       |
|   |       |- level_0/             # 敌对单位
|   |       |   |- brigand.gd       # 山贼(敌人)
|   |       |   |- brigand.tscn
|   |       |
|   |       |- player_team/         # 玩家队伍
|   |           |- te/             # 主角忒（te.gd/te.tscn，talk="伊萨尔"）
|   |           |- isar/           # 贤者伊萨尔（isar.gd/isar.tscn，talk="忒"，第2回合事件登场）
|   |
|   |- level/                       # 关卡
|       |- level.gd                 # 基础关卡类 Level（P3：关卡骨架模板，UI 装配/横幅/相机输入/事件执行器/武器工厂/村庄扫描）
|       |- level_0/
|           |- level_0.gd           # 关卡一脚本（extends Level，本关数据：对话/事件/单位摆放）
|           |- level_0.tscn         # 关卡场景
|
|- tests/                           # 测试目录
	|- test_battle_forecast.gd      # 战斗预测测试
	|- test_battle_sequence.gd     # 战斗序列测试
	|- test_battle_animation.gd    # 战斗动画测试
	|- test_enemy_ai.gd            # 敌方 AI 决策测试（headless 四场景断言）
	|- test_attack_range_union.gd  # P0-1 多武器射程并集测试（8 场景）
	|- test_item_lifecycle.gd      # P0-2 物品/装备实例生命周期测试（8 场景）
	|- test_rescue.gd              # P1 救援/放下/交接测试（7 场景，Unit.tscn + 最小 BM）
	|- test_phase_end.gd           # P1 回合切换与胜负判定测试（7 场景）
	|- test_canto.gd               # P1 Canto 技能等级与 _end_action 决策测试（8 场景）
	|- test_convoy_event.gd        # P1 ConvoyStore + MapEvent 一次触发测试（8 场景）
	|- test_support.gd             # 5G 支援系统测试（支援表/门槛升级/加成距离/章节积累）
	|- test_level_system.gd        # 升级系统测试（经验公式/武器经验阈值与封顶/装备限制/升级掷骰/满级）
	|- test_bm_public_api.gd      # P2 批次2 BM 公开接口测试（7 场景：查询/移除/撤回移动）
## headless 测试惯例（P0-1 起）
- 入口：`func _initialize() -> void: _run()`（SceneTree 子类；可在 _run 内用 await）
- 纯逻辑场景用 `Unit.new()` 手填字段；需 `apply_grayscale` / 节点操作的场景用 `preload("res://scene/character/unit.tscn").instantiate() as Unit`
- 需要 BattleManager 的场景构造 `_make_minimal_bm(units)`：提供 cursor/tile_map，单元测试统一不挂场景
- 光标必须用 `load("res://scene/ui/cursor.gd").new()`（真脚本节点）：裸 Node2D 没有 set_cell/restrict_to，
  走到 _select_unit / canto.enter_phase 的场景会崩（test_canto 曾踩坑，P2 批次2 已修）
- `ConvoyStore` 是 autoload 单例，开头清空避免污染其他测试

## 开发路线（按顺序执行，前一阶段完成后再进入下一阶段）

如果有刚需但没有的纹理图片一类，先空着或者拿godot的默认纹理。告诉我，我再添加对应的纹理图片。

## 已完成部分：移动范围（Dijkstra）、寻路（A*，启发式已修复）、路径预览、光标限位、选中→移动→攻击的玩家攻击流程、地形消耗表、已行动灰度、战斗计算、战斗预览、武器修正
## 战斗动画、角色面板、运输队、村庄、人物对话等
战斗序列生成器（BattleCalculator.generate_battle_sequence，纯数据，顺序为 攻→反击→攻方追击→防方追击）、掷骰结算（命中/必杀，必杀×3）、攻速（AS = 速度 - max(0, 重量 - 体格)）、Unit 体格字段（con 默认 5，待按角色填写）。防御方反击与追击共享射程判定（can_counter：攻击距离须在防御方武器 min/max_range 内，射程外既不反击也不追击，如弓在 1 格被近战攻击时完全无法出手）。验证脚本：res://tests/test_battle_sequence.gd。


TARGET_SELECT 状态悬停敌方目标时使用 level_0.tscn 里的 `CanvasLayer/Battle Preview`（TextureRect）作为面板，子节点在编辑器中布局、脚本按名称绑定填充（PlayerName/PlayerDPH/PlayerWeapon/EnemyName/EnemyDPH/EnemyWeapon/EnemyWeaponName，HP 与 PowerAccuracyCriticalHit 为固定文字）；面板直接读取战斗序列渲染（禁止重算）：双方 HP/威力（追击在威力行追加 ×2）/命中/必杀，无法反击显示"——"；update_side 按攻击方所在半屏左右换位避免遮挡。Weapon 已配 icon 字段，铁斧已配图标，铁剑图标待补。验证脚本：res://tests/test_battle_forecast.gd。

- 三角相克：物理 剑>斧>枪>剑，魔法 理>光>暗>理，克制 +1威力+15命中、被克 -1威力-15命中（BattleCalculator.get_triangle，相克修正只作用于伤害与命中，不影响必杀）。
- 武器耐久：Weapon.consume_durability()，每次实际打击（含未命中、反击、追击）扣 1 点，归零武器损坏、current_weapon 置空（BattleManager._consume_weapon）；战斗序列在开战前生成，战斗中途损坏不影响本场后续打击（GBA 行为）。
- 地形加成：瓦片集自定义属性 Name（中文值：道路/山/河/森林…）→ Global.TERRAIN_BONUS 表（数值取自 FE8：山=防御1/回避30，森林=防御1/回避20，要塞=防御2/回避20，民居/店铺/斗技场/水=回避10，其余 0/0）。防御方地形的守备加成计入伤害、回避加成计入命中。generate_battle_sequence 增加可选 tile_map 参数（默认 null 按无地形），预览面板读取同一序列自动体现。单位 move_table 键已同步改为中文与瓦片 Name 一致。
- 地图 HP 条：Unit 下的 "hp"（ProgressBar）节点，unit.gd 的 update_hp_bar()：满血隐藏，血量 >1/2 绿、<=1/2 黄、<=1/4 红，背景黑色（运行时 StyleBoxFlat）。_apply_damage 后刷新。unit.tscn（动态创建敌人的模板）暂未放 hp 节点，脚本已做空节点兼容。
验证脚本：res://tests/test_battle_sequence.gd。

- 回合切换：玩家回合 ↔ 敌方回合，回合开始重置 has_acted 并恢复灰度；胜负判定（一方全灭），完整对局可进行到底。
- 回合横幅：场景树 `CanvasLayer/Phase Switch`（TextureRect），Tween 从屏幕右侧外滑入中央→停留→滑到左侧外消失（level_0.gd 顶部常量与 tween 可调）；Phase Switch Shadow 固定不动。
- 行动菜单：移动后（含原地选择按确认）弹出 攻击/待机/物品；攻击无目标时置灰；菜单按单位所在半屏左右换位避免遮挡（同战斗预览）；取消可撤回移动。
- 攻击目标选择（TARGET_SELECT）：方向键在攻击范围内所有敌方目标间循环跳转（左/上上一个、右/下下一个，索引回绕），光标不逐格移动——弓等武器攻击范围不连通（仅距离2一圈），逐格移动无法跨过射程外空格；战斗预览随光标跳转刷新。
- 敌方 AI：scripts/enemy_ai.gd 纯函数决策（静态 decide(unit, units, tile_map) 返回 {move_to, target}），优先级：可击杀目标 > 移动后可攻击 > 向最近玩家单位接近。属性/武器差异属于数据：靠 Unit @export 属性 + 关卡脚本赋值武器实现，不改 Unit 结构；后续需要行为分化（守桥型/蹲伏型）时再加 ai_profile 字段。敌方回合相机跟随行动单位。
- 验证：tests/test_enemy_ai.gd（headless 四场景断言）。

- 独立战斗场景 scene/battle_animation.tscn（已创建）：地图 → 战斗画面切换，打击节奏复用战斗序列数据（与预览同源，禁止重算）。
- 每次进入更新场景label标签（命中  伤害  必杀  交战双方名字 武器名 当前hp） 动画资源 武器图标
- 血条TextureProgressBar 更新
- 命中/未命中/必杀/追击各有演出，结束回地图并同步 HP。
- 魔法三段演出（物理之外的第二条打击流程）：武器类型为 ANIMA/DARK/LIGHT 且施法者帧资源有 magic_start 动画时走 _play_magic_strike——① 施法者 PlayTreamAnimation 播 magic_start（起手，播完才继续）→ ② 切 magic_loop 循环 + MagicAnimation 节点播武器对应特效动画 + AnimationPlayer 播 Magic 库同名函数轨道（命中帧回调 on_impact 受击闪白/MISS）→ ③ 特效播完隐藏、施法者切 magic_end（收手）播完本击结束。特效动画名：MAGIC_EFFECT_ANIM 表（火炎→fire）→ 与武器同名的特效动画 → 特效帧第一个动画；新魔法加表或在 Magic_frames 建同名动画即可。魔法单位待机姿态用 magic_loop（_pick_anim_name）。
- 需要战斗动画 sprite；地形背景按防御方所在瓦片选取（背景和地形目前我只添加了一个，以后再慢慢加）。
- 敌方的战斗动画需要用着色器渲染为红色（魔法的特效动画不用）

- 打开/关闭：CURSOR 状态光标停在任意单位上（不分敌我）按 R 键打开，BattleManager 新增 UNIT_INFO 状态；R 或 no 键关闭回到 CURSOR。
- 三页循环切换：左右键（InfoData 角色信息 / Items 物品 / Weapon&SupportLevel 武器&支援等级），打开默认显示角色信息。
- 上下键在同队伍单位间循环切换（按格子坐标排序回绕），面板保持当前页。
- 面板 scene/unit_info_panel.tscn + unit_info_panel.gd，全部数据从 Unit/ClassData/Weapon 实时读取（每次打开/切换重新填充，不复制数据）：
  - 基本信息页：姓名/职业/等级/经验(exp%100)/当前HP/最大HP；八项能力 力/魔/技/速/幸/守/防/移 数值 + 能力条（职业上限=40）；；体格同上；救出/状态异常显示"——"（5E 后填真值）；指挥⭐有值显示"%d⭐"否则"——"；对话对象显示 unit.talk 否则"——"。
  - 技能栏：运行时按 ClassData.skills 实例化技能场景（焕发=flourish.tscn），无职业数据留空。
  - 地图立绘：复制单位 MapSprite2D 的 sprite_frames 播放 idle_selected。
  - 物品页：当前只有 current_weapon 一件（图标/名称/"耐久/最大耐久"），背包 5C 实现后扩展。
  - 武器&支援等级页：按武器类型显示 ItemIconClass 图标（剑/枪/斧/弓，魔法/杖暂无图标），武器经验条填 0（未实现）。
- 职业数据：scripts/class_data.gd（Resource，job_name/class_card/cap_* 上限/skills），.tres 资源在 scene/character/class_data/（nomad.tres 弓骑、brigand.tres 山贼），Unit 新增 @export class_data 引用；无 class_data 的单位上限回落 Unit 自身 max_* 字段。
- 装配：level_0.gd _setup_unit_info_panel() 实例化挂 CanvasLayer 并 set_unit_info_panel 传给 BattleManager。
）
- Unit 增加 inventory 数组（FE 上限 5），current_weapon 指向背包内实例（Unit._own_inventory 保证唯一性，见 5D）；weapon.gd 增加非武器物品类型（伤药等可使用物品）。
- 行动菜单"物品"打开 ItemMenu（5D 实现）：换装 / 使用（丢弃未实现）。
- 战斗预览与背包显示武器当前耐久（如 25/45）；战斗画面武器名附带耐久。
- 攻击目标选择改为遍历背包内所有武器的射程并集。
- 攻击范围统一接口（P0-1，2026-09）：`Unit.get_weapon_ranges()` 返回背包所有可用武器（含耐久>0 的判定）的技能后修正射程区间；`Unit.get_attack_range(tile_map, cells)` 与 `Pathfinder.get_attack_range_union(cells, ranges, tile_map)` 是唯一查询入口。BattleManager._select_unit / _finish_move、BattleUnitCommands._after_submenu_closed、EnemyAI.decide、BattleRangeInspect.toggle_all / _show_enemy_range 全部迁移到此接口。旧 `Unit.get_min_attack_range()` / `get_max_attack_range()` / `get_effective_*` 与 `Pathfinder.get_attack_range` / `get_attack_range_from_cell` 保留为兼容包装（只读 current_weapon）。"攻击"菜单可用性仍要求 `current_weapon != null`（FE 惯例：必须装备武器才能攻击，范围内出现的目标先选后再决定是否换武器）。
- 范围显示规则（GBA 同款；2026-09 修复回归，勿再改坏）：选中单位时 `move_range` 画 **MOVE_TILE（蓝）**，`attack_range` 必须是与 `move_range` 的**差集**，画 **ATTACK_TILE（红）**，蓝红不重叠。`Pathfinder.get_attack_range_union(cells, ranges, tile_map)` 内部用 `cells` 构建站位集合做差集（`stand.has(target) → continue`），因此调用方**必须把真实站位列表传进去**（预览传 `move_range.keys()`，落地后传 `[unit.cell]`），传 `[]` 会返回空数组。唯一例外是 `BattleRangeInspect.toggle_all()`：GBA 的"查看全部敌人范围"是整片红的**威胁区**，需手动 `mv ∪ atk`（先并入 `mv.keys()` 再并入 `atk`）。`_finish_move` 后无移动范围显示，只需 `cells = [unit.cell]` 排除自身落点。
- 物品转移统一接口（P0-2，2026-09）：`Unit.BAG_LIMIT = 5` 常量；`Unit.add_item(item)` / `remove_item(item)` / `remove_item_at(index)` / `equip_item(item)` / `consume_weapon_durability()` / `break_current_weapon()` 是唯一修改 inventory 与 current_weapon 的入口，**任何外部代码不再直接操作 inventory 数组或给 current_weapon 赋值**。移除物品（含武器耐久归零）时若该物品是 current_weapon 则自动卸装；非背包实例不能装备；add_item 不复制（调用方负责 duplicate .tres）。BattleCombat._consume_weapon、BattleMapInteraction.do_interaction（开箱消耗钥匙 + 发奖）、ItemMenu._confirm（换装）、TradeMenu._transfer_append / _transfer_swap、ConvoyPanel._take_item / _deposit_item、ActionGiveItem.execute、level_0 敌人初始化（_setup_enemies / _create_enemy）全部改用 Unit 接口。`Unit.use_item` 仍负责消耗品的回血 + 扣使用次数 + 耗尽移除。tests/test_item_lifecycle.gd 新增 8 场景覆盖不变量。

- 运输队 E:/SDL_Game/Lost/scene/convoy.tscn 实现运输队功能
- 纯键盘操作：方向键移动，Z 确认，X 取消。
- 流程：
MODE_SELECT：选择"取出"或"寄存"，方向键切换，Z 进入，X 关闭面板
TAKE：右侧仓库列表 ↑↓ 移动光标（滚动窗口），←→ 切换 9 类，Z 取回物品
DEPOSIT：左侧背包 ↑↓ 移动光标，Z 寄存物品，无 ←→ 操作
- ConvoyStore.current_items 记录当前物品数量，存取时同步更新，面板打开时刷新。
- 消耗品耐久：Consumable.durability/max_durability（默认 5/5，伤药恢复 15 HP），ItemRow 消耗品分支与武器同样显示 "5/5"。
- 物品使用：行动菜单"物品"打开 ItemMenu（scripts/item_menu.gd，代码构建面板：5 行 ItemRow + 手指光标 + 选中行高亮）。Z 使用消耗品（Unit.use_item：回血、扣 1 次使用次数、耗尽从背包移除，之后结束行动，属非攻击行动可触发焕发再移动）；武器则换装（不结束行动）；X 取消回行动菜单（换装后 BattleManager 重算攻击范围）。BattleManager 新增 ITEM_MENU 状态。
- 武器耐久显示修复：根因是 level_0 曾给 current_weapon 单独 new 实例、与背包里的铁弓不是同一对象（攻击扣前者、UI 显示后者）。现约定：**current_weapon 必须指向背包 inventory 内的实例**。Unit._ready 的 _own_inventory() 负责：duplicate 背包所有 .tres 引用（ExtResource 是共享模板）、current_weapon 为空时默认装备背包第一件武器、装备不在背包时复制入包。武器损坏时 _consume_weapon 同时从背包移除（GBA 行为）。战斗画面武器名附带耐久（如 "铁弓 40/40"，开场读一次）。

村庄、宝箱，地图事件、多人物控制，人物对话（完成）
- 可交互物：scripts/interactable.gd（Interactable，Kind: VILLAGE/CHEST，reward + key_id，_ready 入 interactables 组）。level_0._setup_interactables() 扫描地形"民居"瓦片自动生成村庄门（reward=伤药）；宝箱暂无对应瓦片未摆放，钥匙模板 scene/item/chest_key.tres 已就绪，摆放方式：编辑器加 Interactable 节点或加宝箱地形层。
- 行动菜单附加项：action_menu.open() 第三参 extra_items 动态附加"攻击/访问/开启/对话"（攻击由 attack_enabled 单独控制，动态项排在固定项之上，隐藏项不占空间）。BattleManager._show_action_menu 探测攻击范围内敌人（→"攻击"）、脚下瓦片可交互物（VILLAGE→"访问"；CHEST 且背包有对应 key_id→"开启"）与邻接对话对象（talk 字段互指）后追加。宝箱开启消耗钥匙→duplicate reward→背包满落 ConvoyStore→对话框提示→结束行动；"对话"经 talk provider 播放人物对话后结束行动（见下"对话系统"）。
- 增援接口：scripts/action_reinforce.gd（ActionReinforce extends MapAction），两种来源二选一——placed_node_name（关卡预摆节点，如 Units/Isar，开局由关卡隐藏、登场淡入显形）或 unit_scene（实例化刷兵）；可选 spawn_cell/walk_to（走位复用 _move_unit 寻路演出）/fade_in_time。取代旧 _create_enemy 的增援职责（后者保留作直接摆怪）。
- 地图事件系统：scripts/map_event.gd（Resource：Trigger.TURN_START + trigger_turn + once + actions: Array[MapAction]）。BattleManager.set_map_events(events, runner) 注入，begin_battle/start_player_phase 横幅后 await _run_map_events()（EVENT 状态阻塞输入，执行器为关卡侧 run_map_event 回调顺序 await 各 action）。动作子类：action_dialogue.gd / action_reinforce.gd / action_give_item.gd。
- 多人物控制：现有系统天然支持（光标选 team==0、AI 收 units 列表、面板同队循环），事件只需 add_unit 注册。
- 对话系统（5E 重构，替代旧 dialogue_box.gd）：scene/talk.tscn + scene/talk.gd。Talk.open(lines, portraits, bg) 播放，closed 信号通知播完；lines 每项 {"speaker","text","side"}（side ∈ left1/left2/right1/right2，系统提示省略 side 无肖像）；portraits 为 {说话人名: Texture2D}，左侧槽强制 flip_h（人物默认面向右侧）；BG 为背景 CG（关卡内对话为 null 不显示，剧情演绎时传图）。逐字显示（CHAR_DELAY 0.04s/字）：yes/no 打字中=立即显示完整句 / 打字完=下一句；start=跳过全部。Dialogue 九宫格框宽高随 Label 完整内容测量（字体 get_multiline_string_size + MarginContainer 边距，限制在场景 min 91×48 / max 224×64 之间），下边界恒为 81（position.y + size.y）。说话者肖像槽显示 Bubble 气泡，其余隐藏。BattleManager：open_dialogue(speaker, lines) 保留为系统提示/事件对话包装（内部转 talk 格式），play_dialogue(lines, portraits, bg) 为正式入口（DIALOGUE 状态）；_do_talk 经 set_talk_provider 注入的关卡回调取对话数据（func(unit, target) -> {"lines","portraits"}），播完清空双方 talk 字段（FE 惯例防重复，反复测试需恢复 tscn 的 talk 值）。action_dialogue.gd 不变（走 open_dialogue）。
- 测试对话（level_0）：忒 × 伊萨尔四句（TALK_TE_ISAR，忒 right1 / 伊萨尔 left1，肖像 TE_CARD/ISAR_CARD 由 _get_talk_dialogue 按单位名对匹配提供）。
- 测试事件（level_0）：第 2 回合开始时贤者伊萨尔（isar.tscn 预摆于格子 (2,0)，开局隐藏）淡入登场，走位到 (-1,0) 地图中央（相机 cutscene_focus 跟随演出）；主角忒（talk="伊萨尔"）与其（talk="忒"）相邻可"对话"。isar.tscn 已补 unit_name/等级/属性。
- 相机：level_0._process 三级焦点——cutscene_focus（事件演出）> 敌方回合 current_ai_unit > 光标。
  -人物对话重构（已完成，见上"对话系统"条目）
  - 规格：talk.tscn（BG 背景CG 关卡内为空 / Dialogue 九宫格框随 Label 内容动态调整、下边界恒 81 / DialogueArrow 播完一句显示、yes 可打断打字 / 逐字显示 / Right1 Right2 Left1 Left2 肖像槽右侧水平翻转 + Bubble 说话气泡）。
- 行为修正（测试反馈）：对话不消耗行动——_do_talk 播完对话后回到行动菜单可继续选择（攻击/物品/待机），talk 已清空故"对话"项不再出现；待机不触发焕发再移动（_end_action(allow_canto) 参数，选择待机=主动放弃再移动，攻击/用物品结束才按焕发规则）。
- 敌人范围查看（测试反馈）：CURSOR 状态光标停在敌人上按 yes 显示该敌人的移动范围（蓝）+最外围攻击范围（红，get_attack_range 已剔除移动范围格子），再按一次取消、停在别的敌人上切换；按 start 显示全部敌人攻击范围并集（红色，含各敌人可达位置的射程覆盖，不显示移动范围），再按 start 取消；no 键关闭任何查看。
进阶战术机制（完成）
- 救援/放下/交接（FE8 规则）：
  - Aid 救援力：ClassData.mount_type（FOOT 步行=体格-1 / MOUNTED_MALE 骑乘·男=25-体格 / MOUNTED_FEMALE 骑乘·女=20-体格，无职业数据按步行）；Unit.get_aid() / can_rescue()（救援者 Aid ≥ 被救者体格，且双方都未携带/未被携带）。忒=骑乘·男（Aid 18），伊萨尔=步行（Aid 11），二人可互救（测试用）。
  - "救援"项：四邻接有可救友军时出现（_rescue_candidates）。执行：被救者脱离地图挂在救援者身上——visible=false + cell=Unit.OFF_MAP_CELL 哨兵坐标（不可被选中/攻击/寻路，AI 距离巨大自动忽略，胜负判定仍计存活），rescue 字段置 true 供人物面板"救出"显示；救援者身上的携带标记贴图暂缺（需要时再补）。
  - "放下"项：携带单位且四邻接有空格（被救者可通行地形+无单位）时出现（_drop_cells）。执行：被救者放回所选空格，**当回合不能再行动**（has_acted+灰度，FE8 行为）。
  - "交接"项：携带单位且四邻接有 Aid 足够的未携带友军时出现（_give_candidates）。执行：被救者转交，保持脱离地图状态。
  - 三个指令都结束单位行动（焕发按非攻击行动触发再移动）。多个候选时进入 RESCUE_SELECT 状态：候选格红色高亮、方向键循环、yes 确认、no 返回行动菜单；单候选直接执行。
  - 携带时的救援者速度/技巧惩罚（FE8）暂未实现。
- 再移动（Canto，5E 已随焕发技能实现）：BattleManager.CANTO_MOVING 状态，攻击/非攻击行动结束后按技能触发等级（POST_ACTION_ALL/NO_ATTACK）与剩余移动力判定；待机跳过（见 5E 行为修正）。
- 菜单 UI 升级：行动菜单与物品栏背景替换为 scene/ui/itemsbox.tscn 九宫格——行动菜单宽 48、物品栏宽度按物品内容自适应（=手光标位16+最宽物品行+右边距13，不小于 48；104 只是纹理原始宽度），size.y 随可见选项/背包物品数量动态调整（高度=上边距13+行数×行高+下边距14，原版效果）；scene/ui/cursorhand.tscn 手光标在两菜单中跟随选中项移动（实现模式同运输队面板 $Cursor）。
- 交换（5F，FE GBA 规则）：四邻接有同队在地图上的友军时行动菜单出现"交换"（_trade_candidates；目标选择复用 RESCUE_SELECT 的高亮/循环）。scripts/trade_menu.gd 代码构建界面：左右两侧各 itemsbox 物品栏（固定 5 行、贴屏幕底边、宽度按内容自适应）+ 上方 class card（unit.class_data.class_card，底部被物品栏遮挡=FE 原版处理）。交互：↑↓ 移动（可停空槽位）、←→ 切换操作侧、Z 拾取物品跳另一侧 / 放到有物行=交换 / 空槽位=转移到对方背包末尾 / 同侧=调换整理、X 取消拾取或关闭。交换不结束行动；装备中的武器被换走则卸下（current_weapon 置空）；关闭后 BattleManager 重算攻击范围回行动菜单。新增 TRADE 状态。
- 行为修正（第二轮测试反馈）：① 对话/交换完成后行动菜单按 no 不再撤回移动而是直接待机（_menu_action_spent 标记，选中单位时重置）；② 被救起脱离地图的单位不计入"我方未行动"（_check_player_phase_end 跳过 carried_by≠null，全队被救/行动完时回合正确结束，不再死机）。
- **Godot 教训：custom_maximum_size 的"无限制"是 (-1,-1) 而非 (0,0)**——(0,0) 表示上限 0×0，会把 Control（如九宫格背景）钳成零尺寸导致不显示（子节点默认不裁剪所以文字仍可见）。另：set_anchors_preset 只设锚点不重置 offset，铺满父节点要用 set_anchors_and_offsets_preset。
- 测试问题修复汇总（测试测出来的问题.md）：1 对话后回行动菜单+移动规则；2 敌人范围显示（yes/start）；3 待机不再移动。

支援系统&等级（5G，完成 2026-09-28）
- 属性资源 scripts/affinity.gd（Affinity：属性名/图标/命中·回避·必杀贡献），数据 data/affinity/*.tres 七种（炎/暗/理/雷/冰/光/风，数值为占位可在检查器调整）；ClassData 新增 @export affinity（te.tres=炎、isar.tres=暗），人物面板 BaseInfo/AffinityIcon 显示属性图标（无属性单位留空隐藏）。
- 支援表 scripts/support_pair.gd（SupportPair：双方名字/双方属性/各等级门槛/肖像/C·B·A 支援对话），数据 data/support/te_isar.tres（忒×伊萨尔，门槛 C=1/B=2/A=3 可按对自定义，测试对话"1"）；SupportStore（autoload，scripts/support_store.gd）持有全部支援表（PAIRS 常量追加 preload），project.godot 已注册。
- 支援值按章节积累（非原版邻接）：BattleManager.add_unit 对 team==0 记录登场（SupportStore.mark_deployed，增援走同一入口），我方胜利 _check_battle_end 时 on_chapter_cleared 给双方都登场过的支援对 +1 点（封顶 A 级门槛；败北 on_chapter_failed 作废登场记录）。
- 支援升级（玩家主动触发）：两人相邻 + 支援值达下一级门槛 → 行动菜单出现"支援"项（动态项顺序：攻击→访问→开启→对话→支援→救援→放下→交接→交换）；do_support 播放对应等级支援对话（SupportPair.c/b/a_lines，格式同 talk 系统）后支援等级 +1，不结束行动（同"对话"行为修正：mark_action_spent 后回行动菜单，no 不再撤回移动）。
- 支援加成（命中/回避/必杀）：属性贡献制——双方属性贡献之和 × 等级倍率（SupportStore.LEVEL_SCALE：C=1/B=2/A=3，可调），支援对象须登场、同队、曼哈顿距离 ≤3 格（BONUS_RANGE）才生效，多个支援对象累加。BattleCalculator.calculate_hit_rate/calculate_crit_rate/generate_battle_sequence 增加可选 units 参数（默认 [] 旧调用兼容），战斗预览（update_forecast）与实际结算（execute_attack）都传 bm.units——预览与结算同源序列，支援加成自动一致。
- 人物面板支援列表：Weapon&SupportLevel/SupportLevel 动态生成行——icon=对方属性图标、Name=对方名字、Level=C/B/A（未建立"——"）；tscn 里的 character 节点作模板，_ready 时脱容器隐藏，填充时 duplicate（避免空槽占布局）。
- 测试：tests/test_support.gd（headless：支援表查询/门槛与升级/加成距离与队伍判定/章节积累）；level_0._setup_units 预置 1 点支援值（测试用），忒与伊萨尔相邻第 1 回合即可触发"支援"升 C。

升级系统&武器等级（5H，完成 2026-09-28）
- 数据：Weapon 新增 required_rank（需求等级）与 weapon_exp（每次命中获得的武器经验，FE8 数据铁剑=1）；WeaponRank 枚举与 WEXP_THRESHOLDS（FE8：E=1/D=31/C=71/B=121/A=181/S=251）定义在 weapon.gd。ClassData 新增 class_power（FE8 经验公式职业强度，普通职业=3）、8 个 rank_*（职业可用武器类型与等级上限）、cap_hp。
- Unit：weapon_xp 字典（{武器类型(int): 累计经验}；可用类型惰性初始化为 E=1，预转职角色可在 tscn 预填更高值）；get_weapon_xp/get_weapon_rank（=min(经验等级, 职业上限)）/gain_weapon_exp（封顶职业上限，不可用类型不积累）/can_equip/gain_exp（满级不获得）/level_up（应用掷骰结果）。equip_item 与 _own_inventory 默认装备都走 can_equip 限制；无职业数据的单位不限制（敌人兜底）。
- 角色经验（BattleCalculator.calculate_exp_gain，FE8 原版公式；转职加成/BOSS/盗贼加成待这些系统实现后扩展）：造成伤害 = (31+敌Lv-己Lv)/己职业强度（下取整）；未命中或 0 伤 = 1；击杀 = 伤害经验 + max(0, 敌Lv×敌职业强度-己Lv×己职业强度+20)，封顶 100。只有玩家方（team 0）结算；参战双方都给（含敌方回合被打的防守方）；阵亡单位不结算。
- 升级掷骰（BattleCalculator.roll_level_up，GBA 规则无保底）：八项能力按 ClassData 成长率% 独立掷骰 +1，到职业上限（cap_*）不再加，可能空升级。LEVEL_STAT_KEYS 顺序 = grade_up 场景 Add 子节点顺序 = HP/力/魔/技/速/幸/守/防。
- 战后结算（BattleCombat._settle_exp）：经验逐段填充——填满 100 → battle_animation.show_level_up 加载 grade_up 场景播放加点动画 → 继续填余下经验（可连升多级）；满级（Unit.LEVEL_CAP=20）不再获得。
- 武器经验（BattleCombat 战斗循环）：玩家单位每次命中的打击 +武器.weapon_exp（按用户规则：未命中不给；与 FE8 的未命中也给、击杀翻倍不同）；武器中途损坏照常结算（循环内先取引用再扣耐久）。
- 演出：exp_box.tscn（ExpBar + Exp 数字）由 battle_animation.show_exp 动态加载并 tween 填充——**挂父节点（CanvasLayer）而非 battle_animation 自身**（本场景是居中的 Node2D，Control 子节点会被位移半屏）。grade_up 场景：填充职业/等级/职业卡/八项能力，Add 下 8 个 add_up 子节点对应加点的项依次播放（前一个快播完时开始下一个），播完自动隐藏无需输入；add_up.gd 改为受控播放（play()，可重复）。
- 面板：Weapon&SupportLevel 页按 ClassData 可用武器类型逐行复制 WeaponXP/WeaponClass（类型图标+当前等级内进度条，到职业上限或 S 填满）与 WeaponLevel（等级字母 E..S，两容器子节点一一对应）；魔法/杖暂无类型图标（图标隐藏，条与等级照常显示）。职业配置：te=弓 C、isar=理 C/暗 E/杖 E、brigand=斧 E。
- 测试：tests/test_level_system.gd（6 场景：经验公式/武器经验阈值与等级文字/积累与封顶/装备限制/升级掷骰与应用/满级）。
## 待开发
### 物品描述
- 在某些信息面板，运输队，物品栏，人物信息面板，按下“R”键，显示物品描述，并可以按移动键上下左右切换。在人物属性面板，按下“R”键，相应显示人物属性信息 的描述，如职业描述，角色描述，人物力量，防御等描述。描述框
### 

# 新增功能时，优先扩展已有类，没有已有类，再创建新的 Manager、Controller、Component、Resource 或 Scene 并不构成代码重复

# 如果现有类职责已经明确，应通过新增方法或接口扩展，而不是重新实现相同功能。

# 所有脚本文件 不建议超过500行，如果超过了大概率承担了不该承担的功能，就分包处理。

# battle_manager.gd 已按此规则分包（2026-09）：门面保留状态机/输入分派/选中移动/行动收尾，
# 非战斗功能拆入 battle_unit_commands / battle_map_interaction / battle_rescue /
# battle_range_inspect / battle_canto / battle_combat / battle_phases 七个模块
# （RefCounted 纯逻辑对象，_init 创建、经 bm 引用共享状态；对外接口 set_*/begin_battle/
# add_unit/handle_input/open_dialogue/_move_unit 保持不变，关卡与事件脚本零改动）。

# P2 行动结束解耦（2026-09，渐进式）：行动结束流程统一走 BattleManager 公开接口——
# end_action(allow_canto)（=原 _end_action 公开包装）、mark_action_spent()/is_action_spent()
# （替代直写 _menu_action_spent）、mark_attack_action()（替代直写 _last_action_was_attack）、
# finalize_action()（行动收尾唯一出口：清选中上下文/范围层/光标限制→回 CURSOR→查胜负与回合结束）。
# BattleCanto._finish_canto 与 _end_action 共用 finalize_action，不再各自实现清理尾巴
# （此前两处 11 行重复，正是"状态恢复互相覆盖"风险点）。子模块（unit_commands/map_interaction/
# rescue/canto）已全部迁移；_end_action/_menu_action_spent/_last_action_was_attack 保留为兼容入口
# （旧测试可继续用）。
#
# P2 批次2（2026-09，查询/单位操作/撤回移动解耦）：BattleManager 新增公开接口
# get_unit_at(cell) / get_blocked_cells(exclude)（查询簇）、remove_unit(unit)（阵亡移除+胜负检查）、
# move_unit(unit, destination)（通用移动演出，敌方回合与增援走位复用）、undo_move()（撤回移动：
# 坐标还原+重新选中收进 BM，外部不再触碰 _pre_move_cell/_select_unit）。
# 全部外部调用方已迁移（unit_commands/rescue/map_interaction/range_inspect/canto/combat/phases/
# action_reinforce 共 19 处），生产代码对 bm 私有成员的访问归零（bm._* 仅 BM 内部使用）。
# 私有名 _get_unit_at/_get_blocked_cells/_remove_unit/_move_unit 保留为兼容入口（旧测试与
# 关卡脚本可继续用）。注意：move_unit 是协程，调用方需 await。

# P3 关卡职责整理（2026-09，渐进式）：scene/level/level.gd 为基础关卡类（class_name Level extends
# Node2D），承载跨关卡通用职责；具体关卡 extends Level 只填本关数据。首批拆"地图事件/对话"组，
# 批次2（2026-09-27）拆完全部剩余职责组，Level 现为完整关卡骨架模板：
#   - _ready() 模板方法（顺序与原 level_0._ready 逐行一致）：创建+setup BattleManager → _setup_units()
#     → 各 UI _setup_*（forecast/action_menu/item_menu/trade/convoy/battle_animation/unit_info_panel）→
#     _setup_talk() → _setup_interactables() → _setup_map_events() → _on_level_ready() → 连接横幅 →
#     add_child + begin_battle
#   - 虚钩子（关卡按需 override，全部有默认实现）：_setup_units()（单位摆放，默认空）、
#     _seed_convoy()（运输队种子，默认空）、get_talk_dialogue()（对话数据，默认无）、
#     _setup_map_events()（事件定义，默认空）、_on_level_ready()（本关收尾如隐藏预摆增援，默认空）、
#     get_village_reward(cell)（村庄门奖励，默认伤药）
#   - 通用机制：_build_action_menu_panel、回合横幅 _on_turn_started（含 Phase Switch 节点约定）、
#     相机 _process / 输入 _unhandled_input 转发、run_map_event 事件执行器、
#     _create_enemy / _create_iron_sword / _create_iron_axe 工厂
#   - 关卡 tscn 节点名约定：TileMapLayer / HighLightMapLayer / Cursor / Camera / Units（敌人在
#     Units/Enemy 下，约定由关卡自己持有 enemy_node）/ CanvasLayer（含 Phase Switch、Battle Preview）
# level_0.gd 只剩本关数据：对话+肖像、第 2 回合 Isar 增援事件、Te/敌人摆放、运输队种子、
# 隐藏预摆 Isar。场景节点名、资源路径、BattleManager 对外接口、level_0.tscn 均零改动。
# 第二张地图复用方式：新建 level_1.gd extends Level + level_1.tscn（同名节点约定），按需 override
# 虚钩子即可，不需要动基类。

# 修改现有接口前，应保持向后兼容，不要无故改变已完成模块的调用方式，如果模块管理了不该管理的内容，应拆包到新模块。

# 修改项目后，你可以不用测试，由我来测试反馈

### Unit

表示地图上的一个可行动单位。

一个 Unit 对应一个角色实例。

无论玩家、敌人、NPC，都使用 Unit。

区别由 team 字段决定。

Unit 负责：

- 数据
- 动画
- Tween
- 武器
- 当前格子

Unit 不负责：

- AI
- 回合
- 寻路
- 战斗结算

### Class
class 不在存放职业数据，用来存放角色静态数据。为了达到这样效果：不同人物同一职业，但是能力上限和技能不同。
