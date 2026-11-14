# 《火焰纹章：存在与虚无》美术资源与批处理管线技术规范 (Asset Guidelines)

> 本文档为全项目美术资源的标准工业化规范。后续所有原始素材导入、Python 批量切帧/对齐工具、Godot `SpriteFrames` 及 `AtlasTexture` 生成均严格以本规范为准。

---

## 目录索引
1. [地图精灵规范 (Map Sprites)](#一地图精灵规范-map-sprites)
2. [战斗特写动画规范 (Battle Animations)](#二战斗特写动画规范-battle-animations)
3. [人物半身像与职业卡 (Portraits & Class Cards)](#三人物半身像与职业卡-portraits--class-cards)
4. [图标与UI系统 (Icons & UI)](#四图标与ui系统-icons--ui)
5. [地图瓦片集 (Tilesets)](#五地图瓦片集-tilesets)
6. [色彩、透明度与 Shader 变色规约](#六色彩透明度与-shader-变色规约)
7. [外部工具与批量处理工作流 (Pipeline Workflow)](#七外部工具与批量处理工作流-pipeline-workflow)

---

## 一、地图精灵规范 (Map Sprites)

存放目录：`res://assets/graphics/map_sprite/`

地图精灵分为**待机精灵 (Stand / Idle)**与**移动/选中精灵 (Walk / Movement)**两大类：

### 1. 待机精灵 (Stand Sprite)
* **动作特征**：3 帧循环待命呼吸动作（帧序列：`0 -> 1 -> 2 -> 1` 或 `0 -> 1 -> 2` 循环）。
* **排列方式**：单列纵向排列（Vertical Strip）。
* **尺寸规格与体型分类**：
  * **常规/大型/骑兵/上位职业（主流标准）**：
    * 单图总尺寸：**$16 \times 96$ px**
    * 包含帧数：3 帧，每帧切片尺寸为 **$16 \times 32$ px**
    * 帧区间分布：
      * 第 0 帧：`Rect2(0, 0, 16, 32)`（顶部 $y=0$，**底部接地线 $y=32$**）
      * 第 1 帧：`Rect2(0, 32, 16, 32)`（顶部 $y=32$，**底部接地线 $y=64$**）
      * 第 2 帧：`Rect2(0, 64, 16, 32)`（顶部 $y=64$，**底部接地线 $y=96$**）
  * **小型步兵职业（如修女 Cleric、盗贼 Thief、见习兵等）**：
    * 单图总尺寸：**$16 \times 48$ px**
    * 包含帧数：3 帧，每帧切片尺寸为 **$16 \times 16$ px**
    * 底部接地线分别为 $y = 16, 32, 48$。
* **核心对齐法则（严禁漂移）**：
  * **垂直对齐**：角色的**脚底接地像素必须贴紧该帧切片的底部下边缘**（即 $16 \times 32$ 区域的最后一行）。这样角色在地图格子上停留时，脚底能稳定踩在地面网格基准线上，动画播放时绝不发生上下跳动。
  * **水平对齐**：角色站立重心应位于水平中轴线（$x = 8$ 像素处），保持左右平衡。
* **文件命名规范**：`{职业名}-stand.png`（例如 `Mercenary-stand.png`, `Nomad-stand.png`）。

---

### 2. 行走与选中精灵 (Walk & Selected Sprite)
* **动作特征**：左移行走循环、下移行走循环、上移行走循环、选中激活待命动作。
* **排列方式**：单列纵向排列。
* **尺寸规格**：
  * 单图总尺寸：**$32 \times 480$ px**
  * 包含帧数：15 帧，每帧切片尺寸统一为 **$32 \times 32$ px**。
* **帧分布与动作切分（严禁错位）**：
  | 帧索引 | Y 偏移区间 | 动作名称 | 帧数 | 说明 |
  | :--- | :--- | :--- | :--- | :--- |
  | **Frame 0 ~ 3** | $y = 0 \sim 128$ (`0, 32, 64, 96`) | `move_left` | 4 帧 | 向左迈步行走动画 |
  | **Frame 4 ~ 7** | $y = 128 \sim 256$ (`128, 160, 192, 224`) | `move_down` | 4 帧 | 朝屏幕正面/向下迈步行走动画 |
  | **Frame 8 ~ 11** | $y = 256 \sim 384$ (`256, 288, 320, 352`) | `move_up` | 4 帧 | 朝后方/向上迈步行走动画 |
  | **Frame 12 ~ 14**| $y = 384 \sim 480$ (`384, 416, 448`) | `idle_selected` | 3 帧 | 光标选中单位时的预备动作 |
* **关于向右行走 (`move_right`) 的实现**：
  * GBA 经典规则：**无需额外绘制向右走的素材**！Godot 的 `AnimatedSprite2D` 通过设置 `flip_h = true`（水平翻转）复用 `move_left` 即可。
* **文件命名规范**：`{职业名}-walk.png`（例如 `Mercenary-walk.png`）。

---

## 二、战斗特写动画规范 (Battle Animations)

存放目录：
* 图像素材：`res://assets/battle_animations/{职业名}/{武器类型}/`
* 资源定义：`res://data/battle_animation_tres/{职业名}_frames.tres`

* **物理与武器打击帧**：
  * 单帧画幅尺寸：**$248 \times 160$ px**（GBA 战斗特写原生画幅）。
  * 地面参考线：人物双脚接地线通常位于约 $y = 136 \sim 140$ 像素处。
  * 帧类型：起手（Intro）、攻击循环（Attack/Loop）、暴击蓄力（Crit）、命中收手（Hit/Return）、回避（Dodge）。
  * **方案 A 穿刺帧合成规约**：FE 原版中针对长枪贯穿、重斧劈地冲击波、剑圣刀光的 $488 \times 160$ 双层穿刺帧，统一在入库管线中将左半 $240 \times 160$ 前景覆盖层与右半 $248 \times 160$ 背景本体层叠合成单张 $248 \times 160$ 标准帧。
  * **已入库全原版职业一览 (男 [M] 37 类 + 女 [F] 31 类，共 68+ 种组合)**：
    * **男性职业库 (37 类)**：Archer_M, Assassin_M, Bard_M, Berserker_M, Bishop_M, Cavalier_M, Druid_M, Fighter_M, General_M, Great_Knight_M, Hero_M, Knight_M, Mage_Knight_M, Mage_M, Mercenary_M, Monk_M, Myrmidon_M, Paladin_M, Pirate_M, Priest_M, Rogue_M, Sage_M, Shaman_M, Sniper_M, Soldier_M, Summoner_M, Swordmaster_M, Thief_M, Warrior_M, Wyvern_Knight_M, Wyvern_Lord_M, Wyvern_Rider_M 等。
    * **女性职业库 (31 类)**：Archer_F, Assassin_F, Bishop_F, Cavalier_F, Cleric_F, Dancer_F, Druid_F, Falcon_Knight_F, Fighter_F, General_F, Great_Knight_F, Hero_F, Knight_F, Mage_F, Mage_Knight_F, Manakete_F, Mercenary_F, Monk_F, Myrmidon_F, Nomad_F, Nomad_Trooper_F, Paladin_F, Pegasus_Knight_F, Pirate_F, Rogue_F, Sage_F, Shaman_F, Sniper_F, Soldier_F, Swordmaster_F, Thief_F, Troubadour_F, Valkyrie_F, Warrior_F, Wyvern_Knight_F, Wyvern_Lord_F, Wyvern_Rider_F 等。包含剑、枪、斧、弓、理/光/暗魔法、杖、龙石等多武器动作支持。
* **魔法与全屏特效帧**：
  * 单帧画幅尺寸：**$240 \times 160$ px**（GBA 全屏分辨率），背景统一为 32-bit RGBA 透明通道。
  * 组织形式：三段式施法（起手蓄力 `magic_start`、主体爆裂循环 `magic_loop` + 全屏法术特效 `MagicAnimation`、收手归位 `magic_end`）。
  * **已入库魔法与法杖特效库 (`Magic_frames.tres`)**：
    * **火炎 (Fire)**：`res://assets/battle_animations/Anima/[Fire] Fire.../` (24 帧)
    * **雷电 (Thunder)**：`res://assets/battle_animations/Anima/Thunder/` (37 帧)
    * **疾风 (Wind)**：`res://assets/battle_animations/Anima/Wind/` (27 帧)
    * **业火 (Elfire)**：`res://assets/battle_animations/Anima/Elfire/` (31 帧)
    * **熔流 (Flux - 暗魔法)**：`res://assets/battle_animations/Dark/Flux/` (22 帧)
    * **闪光 / 神圣 (Lightning / Luce - 光魔法)**：`res://assets/battle_animations/Light/Luce/` (86 帧)
    * **治愈之光 (Heal - 回复法杖光效)**：`res://assets/battle_animations/Staff/Heal/` (13 帧)
* **法杖与再动支援特写系统**：
  * **法杖逻辑 (`BattleStaff`)**：神职人员背包持有可用法杖且射程内存在受伤友军时，行动菜单动态唤出“杖”选项。支持目标循环切换、治愈量预估、施法举杖与神圣光效升腾、血条增长、耐久消耗与施法经验结算。
  * **舞者/吟游诗人逻辑 (`BattleDance`)**：四邻接存在已行动同伴时动态唤出“跳舞”（舞者）或“奏乐”（诗人）。播放曼妙舞姿特写，唤醒同伴清除灰度重置行动状态，获得固定 10 点经验值。
* **战斗背景与对战台**：
  * 战斗背景 (Battle BG)：**$240 \times 160$ px**。
  * 对战地台 (Floor/Platform)：**$80 \times 32$ px**。

---

## 三、人物半身像与职业卡 (Portraits & Class Cards)

### 1. 人物半身像 (Character Portrait)
* 存放目录：`res://assets/graphics/Character Portrait/`
* 画幅尺寸：**$128 \times 112$ px**（标准 GBA 肖像画幅）。
* 构图规范：人物头部位于上方中心，胸部/肩膀自然截断在画幅底边，背景为透明通道。

### 2. 职业卡 (Class Card)
* 存放目录：`res://assets/graphics/Class Card/`
* 画幅尺寸：**$80 \times 72$ px**。
* 用于状态面板、转职预览与剧情兵种说明。

---

## 四、图标与UI系统 (Icons & UI)

| 资产类别 | 存放路径 | 尺寸标准 | 说明 |
| :--- | :--- | :--- | :--- |
| **武器图标** | `assets/graphics/Item Icons/{Swords,Axes,Lances,Bows,Staff,Anima,Dark,Light}/` | **$16 \times 16$ px** | 武器与法术书小图标 |
| **消耗道具** | `assets/graphics/Item Icons/Item/` | **$16 \times 16$ px** | 伤药、宝箱钥匙、转职道具 |
| **个人特技图标** | `assets/graphics/skill/` | **$16 \times 16$ px** | 角色技能图标 |
| **支援属性图标** | `assets/graphics/UI/AffinityIcon/` | **$13 \times 13$ px** | 炎、雷、风、冰、暗、光、理 |
| **兵种克制图标** | `assets/graphics/UI/ItemIconClass/` | **$16 \times 16$ px** | 骑兵特效、重装特效、飞行特效等 |

---

## 五、地图瓦片集 (Tilesets)

* 存放目录：`res://assets/graphics/Tilesets/`
* 图像画幅：**$512 \times 512$ px**（由 $32 \times 32$ 个 $16 \times 16$ px 的地块组成）。
* 自定义属性绑定：
  * 在 Godot `TileSet` 中必须开启 `custom_data_layer_0`，名称定义为 `"Name"`，类型为 `String`。
  * 所有可通行与不可通行的地块必须登记符合引擎识别的地形名称（`平原`, `道路`, `山`, `峰`, `森林`, `河`, `桥`, `要塞`, `民居`）。

---

## 六、色彩、透明度与 Shader 变色规约

1. **透明背景约定**：
   * 所有导出的 PNG 素材统一使用 RGBA 8-bit（32位带有 Alpha 通道），透明区域 Alpha 值必须为 0。
2. **阵营变色与灰阶着色 (Shader)**：
   * 引擎内通过 `res://data/shader/UnitShader.gdshader` 统一动态处理阵营配色：
     * **玩家方（蓝方）**：默认原版色调。
     * **敌方（红方）**：开启 `red_tint` 材质参数变色。
     * **友方（绿方）**：替换主强调色为绿色调。
     * **已行动待机**：开启 `grayscale = true` 渲染为灰阶。

---

## 七、外部工具与批量处理工作流 (Pipeline Workflow)

为了便于后续批量处理动画帧与切片，项目目录结构现已严格隔离：

```text
E:\Dream\Lost\
├── assets\               # [引擎内] 最终经过标准化切分、导入工程的标准素材
│   ├── battle_animations\
│   └── graphics\
│       ├── map_sprite\   # 标准化的待机与移动精灵
│       └── ...
├── data\                 # [引擎内] 游戏数据与资源定义 (.tres / .gdshader)
├── tests\                # [引擎内] Godot 自动化测试套件 (.gd 测试脚本 / test_runner.tscn)
│   ├── test_runner.tscn
│   └── test_*.gd
└── tools\                # [外部工具] Python 批处理脚本与待处理原始资源（不打包进游戏）
    ├── scripts\          # 批量处理 Python 脚本（切帧、调色、对齐检测）
    └── raw_assets\       # 外部收集的未切分、未对齐原始素材池
```

### 批量处理操作流程：
1. **收集原始素材**：将从网络、FE-Repo 或自绘的原始素材存入 `tools/raw_assets/`。
2. **运行批处理工具**：在 `tools/scripts/` 中编写或运行 Python 处理脚本（自动读取尺寸、定位底部接地线、按 $16 \times 96$ 或 $32 \times 480$ 纵向合并排列、清洗背景透明度）。
3. **输出并入库**：处理完毕的合规素材直接输出至 `assets/graphics/map_sprite/`，在 Godot 中自动生成 `SpriteFrames` 资源。
