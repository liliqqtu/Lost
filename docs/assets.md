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

### 3. 角色静态肖像制作范式（80×72，Te 首例）

当前角色以独立 `ClassData.class_card` 展示人物肖像，因此角色静态头像同样使用 **80×72 px**，存放于 `assets/graphics/Class Card/`。这与上方 128×112 的对话动画图集是两种交付物；静态头像不能直接替换含嘴型、眨眼切片的图集。

* **先读角色再设计**：阅读角色剧情、单位场景及其独立 `ClassData`，确定故事阶段、身份、性格与参考人物。保留明确要求的发色和辨识特征，用眉眼、嘴角及服装表达人物，避免提前加入觉醒后或后期剧情的象征物。
* **画面标准**：单人头肩像，三分之四侧脸；头顶约留 1～2 像素透明空间，肩胸自然截断于底边。真实 80×72 RGBA PNG，透明处 Alpha=0、人物 Alpha=255，深色像素轮廓、少量分层色块，无柔光、抗锯齿、文字和边框。建议 16～24 种不透明颜色；本项目静态头像不强制兼容 GBA ROM 的硬件色板限制。
* **采样与导入**：无损压缩、关闭 mipmaps、Nearest 最近邻，使用原尺寸或整数倍显示。模型生成的大图必须规范化后入库，不能仅靠 UI 缩放冒充原生像素素材。
* **保留过程**：原稿、提示词、处理命令及放大预览放在 `tools/raw_assets/portrait/{unit_id}/`，其父目录用 `.gdignore` 排除 Godot 导入；最终文件采用 `{角色名}_v1.png` 等版本名，保留旧素材。
* **接入与验收**：更新独立 `data/class_data/{unit_id}.tres` 的 `class_card`，同步场景中已有的 `ClassCard.texture` 引用。换成新 PNG 时删除旧资源 UID，交由 Godot 为新图生成 UID。检查原生尺寸、最近邻放大图、深浅底可读性及两处引用；对话图集需单独设计与验收。

**Te / 忒 v1（前期·彷徨）**：基于当前鲁斯参考，保留绿发、修长脸型、锈褐头巾与游牧服饰，年轻俊秀的脸搭配略低垂、疏离的眉眼，旧斗篷和皮革肩带表现漂泊身份。此版本尚未经历后期的觉醒，不加入断弦或艾莲遗物。

* 成品：`assets/graphics/Class Card/忒_v1.png`，20 种不透明颜色加透明背景。
* 原稿与完整最终提示词：`tools/raw_assets/portrait/te/source_v1.png`、`prompt_v1.txt`；六倍预览：`preview_v1.png`。
* 生成方式：内置 `image_gen`，以上述鲁斯静态头像与对话图集作为形象参考。

后续角色可沿用提示词结构：

```text
Asset: ONE GBA FE7/FE8-style character portrait, 80x72 logical pixels, 10:9.
Reference: {参考图及需要继承的脸型、朝向、服饰特征}.
Character: {姓名、剧情阶段、年龄感、身份、固定发色与辨识特征}.
Expression: {用眉、眼神、嘴角具体描述性格；不要只写情绪标签}.
Clothing: {符合身份的服装、材质与简洁配色}.
Style: hard pixel outlines, compact color clusters, limited palette,
no gradients or antialiasing; readable at actual 80x72 resolution.
Composition: one three-quarter head-and-shoulders bust, slight top clearance,
shoulders cropped at bottom; actual transparent background.
No text, border, watermark, alternate views, animation patches or sprite sheet.
```

处理命令（从项目根目录运行，Windows PowerShell + System.Drawing，无额外依赖）：

```powershell
powershell -NoProfile -File tools/scripts/prepare_character_portrait.ps1 -Source tools/raw_assets/portrait/te/source_v1.png -Output "assets/graphics/Class Card/忒_v1.png" -Preview tools/raw_assets/portrait/te/preview_v1.png -Colors 20
```

工具对约 10:9 的透明生成稿执行最近邻缩图、确定性色板归并与二值 Alpha 清理，默认拒绝覆盖。后续版本需改用新文件名；采样不能代替美术验收，若眉眼或轮廓失真，应调整生成稿后再处理。

---

## 四、图标与UI系统 (Icons & UI)

| 资产类别 | 存放路径 | 尺寸标准 | 说明 |
| :--- | :--- | :--- | :--- |
| **武器图标** | `assets/graphics/Item Icons/{Swords,Axes,Lances,Bows,Staff,Anima,Dark,Light}/` | **$16 \times 16$ px** | 武器与法术书小图标 |
| **消耗道具** | `assets/graphics/Item Icons/Item/` | **$16 \times 16$ px** | 伤药、宝箱钥匙、转职道具 |
| **技能图标** | `assets/graphics/skill/` | **$16 \times 16$ px** | 个人、职业及武器附加技能统一管理 |,所有技能图标被技能框("E:\Dream\Lost\assets\graphics\skill\技能框.png")覆盖,并且不透明
| **支援属性图标** | `assets/graphics/UI/AffinityIcon/` | **$13 \times 13$ px** | 炎、雷、风、冰、暗、光、理 |
| **兵种克制图标** | `assets/graphics/UI/ItemIconClass/` | **$16 \times 16$ px** | 骑兵特效、重装特效、飞行特效等 |

FE8 原版可携带物品的独立模板见 `data/items/fe8/`，图标在 `assets/graphics/Item Icons/fe8/{类别}/` 下独立归档，保留既有图标。资源清单、来源与效果登记见 `docs/fe8_item_catalog.md`。本轮仅整理原版图标与物品资料；特殊物品使用效果按清单标注，后续单独实现。

---

### 技能图标规范与可复用设计范式

#### 资源与显示约定
* **统一分类**：个人技能、职业技能、武器附加技能均属于“技能”，共用 `Skill` 资源与图标目录，不按来源另建图标体系。
* **最终文件**：`res://assets/graphics/skill/{技能显示名}.png`，真实尺寸必须为 **16×16 px**，RGBA PNG。英文 `skill_id` 保持稳定，沿用现有中文图标文件命名；显示名变更时同步更新引用。
* **资源绑定**：`res://data/skills/{skill_id}.tres` 的 **`icon`**（Inspector 中的 Icon）引用对应 `Texture2D`，不把 PNG 放进 `data/skills/`，也不在 UI 中硬编码技能名称与图片的映射。
* **角色信息面板**：沿用 `Unit.get_all_active_skills()` → `Skill.icon` → 技能栏的显示路径，统一展示职业、个人和装备武器提供的生效技能；现有面板最多显示 6 项。
* **导入与采样**：保持无损压缩、关闭 mipmaps，使用 Nearest 最近邻过滤。项目默认已配置最近邻；控件保持继承，局部覆盖时同样设为 Nearest。图标以原生尺寸或整数倍显示，避免非整数位置、线性插值和拉伸变形。

#### 像素美术约束
* 先在 **16×16 的逻辑像素网格**内设计，底图满幅填充，**不留白边或透明边距**；主体关键细节放在中间约 12×12 区域，避免被统一边框遮住，动势与背景可延伸至画布边缘。
* 每枚图标只表现 **一个主体 + 一个辅助动势/效果**，不添加技能名称、数字、文字或水印。属性数值由面板说明承担。模型不绘制边框，入库时统一叠加 `res://assets/graphics/skill/技能框.png`，以 `焕发.png` 为既有范例。
* 底图建议使用 **8～12 种不透明颜色，最多 16 种**，用深色轮廓、中间色块和少量亮色高光建立体积。统一技能框的颜色不计入底图色数，叠框后不得再次量化色板。避免柔光、渐变、抗锯齿和缩小后消失的细碎线条。
* **技能图标最终完全不透明，所有像素 Alpha = 255**。背景采用与主题协调的暗色，可适量填充像素纹理，不得留白或绘制棋盘格。先填满不透明底图，再将技能框以原尺寸、原位置进行 Alpha 合成；即使框本身带透明区域，最终成品也必须全不透明。
* 颜色服务技能语义：力量可用赤橙/金色与爆发形，守备可用厚重盾形，速度可用简洁方向线；这些是设计建议，不按技能来源强制染色。
* **验收必须看原生 16×16 和最近邻放大预览**：主体清晰、动作方向明确、暗色与浅色面板上均能辨认，不能只验收大尺寸生成稿。

#### 生成、处理与入库范式
1. 阅读技能 `.tres` 的 `display_name`、`description` 和实际效果，用一句话确定视觉语义，避免图标暗示未实现的机制。
2. 使用下面的提示词模板生成满幅不透明大图，明确“16×16 逻辑像素的整数倍放大”，周围用主题背景填充。模型输出尺寸及像素对齐不可靠，生成稿不能直接当最终图标。
3. 原始生成稿、最终提示词与处理命令保存在 `tools/raw_assets/skill/{skill_id}/`；最终游戏素材只保留在 `assets/graphics/skill/`。
4. 用 `tools/scripts/prepare_skill_icon.py` 转为真实 16×16，默认 `--padding 0` 不加边距；缩图、合成不透明底色、量化底图颜色后，最后叠加原始技能框。默认最近邻适合网格对齐的像素稿；不规则大图可尝试 `--sample box` 面积采样，再检查轮廓。脚本接受正方形透明或不透明输入，透明部分用 `--background` 指定的底色填满；`--frame` 默认指向统一技能框。默认拒绝覆盖，确认替换已有成品时使用 `--force`。
5. 复查原生大小与放大预览；若拳头、武器等主体无法辨认，应简化构图、修像素或重新生成，不能靠模糊缩图掩盖问题。少量星光或心焰高光被默认色板合并时，可使用 `--palette maximum` 保留对比色，并重新检查整体色彩。
6. 给 `.tres` 添加 `Texture2D` 外部资源并设置 `icon`，在 Godot 导入后检查角色技能栏与原有说明焦点。美术接入不修改技能效果。

提示词模板（替换花括号字段，保留像素与透明约束）：

```text
Asset: one GBA tactical RPG skill icon, {skill_id / 显示名}.
Meaning: {已实现的技能效果}; visual metaphor: {一个主体 + 一个辅助效果}.
Style: exact 16 by 16 logical pixel art enlarged as uniform square blocks,
hard stair-step edges, dark outline, 8-12 opaque colors, no antialiasing.
Composition: full-bleed background, no blank or transparent margin;
keep key subject details in the central 12 by 12 area for a separate frame.
Palette: {主色 / 阴影 / 高光}; motion: {动势方向或静态构图}.
Background: fully opaque {主题暗色}, a few subdued pixel motion accents.
Fill the whole square edge to edge. No text, numbers, frame or watermark.
```

处理命令（在项目根目录运行，需要 Pillow）：

```powershell
python tools/scripts/prepare_skill_icon.py tools/raw_assets/skill/surge/source_opaque.png assets/graphics/skill/惊鸿.png --colors 12 --padding 0 --preview tools/raw_assets/skill/surge/preview.png
```

**首个范例：惊鸿（`surge`）**
* 资源效果：`豪迈突进，自身力量+6`，属于力量被动加成，不额外暗示移动力或概率触发。
* 视觉意象：向右上挥出的金色铁拳、赤橙爆发尾迹、少量象牙白冲击高光；深紫褐轮廓保证小尺寸对比。
* 背景与边框：深红褐色满幅背景、少量暗红动势纹理，完全不透明，最上层覆盖统一 `技能框.png`。
* 成品：`res://assets/graphics/skill/惊鸿.png`，绑定 `res://data/skills/surge.tres` 的 `icon`。

**其他范例**：`守望.png`（`vigilance`）使用青蓝盾牌和象牙白星光表达魔防与幸运；`热血重燃.png`（`blood_boil`）使用赤红心形和金橙火焰表达低血量下的战意重燃。两者均为 16×16 不透明成品，覆盖同一技能框，原稿、提示词与转换命令分别保存在对应的 `tools/raw_assets/skill/{skill_id}/` 目录。

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
   * **技能图标例外**：底图满幅不透明并覆盖统一技能框，最终所有像素 Alpha = 255，详见第四节；不得沿用精灵的透明留边规则。
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
