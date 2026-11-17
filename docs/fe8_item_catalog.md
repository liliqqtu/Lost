# FE8 原版物品资源目录

本批新增 138 个独立资源，存放在 `res://data/items/fe8/`。原有 `data/items/` 根目录的自定义模板保留原数值、ID 和引用；新商店应引用本目录中的原版模板。

## 来源与准确性

- 数值、武器类型、熟练度、原版次数及单次价格取自 [FE8 反编译项目原始物品表](https://github.com/FireEmblemUniverse/fireemblem8u/blob/master/src/data_items.c) 和 [编号表](https://github.com/FireEmblemUniverse/fireemblem8u/blob/master/include/constants/items.h)。本地原表、SHA256、逐物品来源与效果状态保存在 `tools/raw_assets/fe8_items/`。
- 首先检索了用户提供的 [FE-Repo Item Icons](https://github.com/Klokinator/FE-Repo/tree/main/Item%20Icons) `{2WB} (Vanilla + Blitz)` 同名候选；该包与本地 ROM 存在颜色差异，因此最终图标改为从用户的 FE8 中文版 ROM 中只读提取原版图标，使用原始物品调色板，索引 0 转为全透明。未分发 ROM。全部最终图标均为 16×16 RGBA，未缩放、未改绘。
- 中文显示名为本项目整理的译名，不保证与任意汉化补丁的用词完全相同。描述为原版效果摘要，不宣称尚未实现的能力已经可用。
- 范围包括人类武器、法杖、龙石、转职道具、能力药、钥匙、宝玉及特殊持有物。未收录弩车、敌方魔物兵器、事件金币、FE7 遗留空项和未知项。龙石目前登记为普通道具，不扩充武器枚举。

## 使用与兼容边界

- `buy_price` 为满次数总买价，按原表 `costPerUse × maxUses` 生成；原表零价不代表免费购买。`can_sell` 同时遵守原版禁止出售标记与零价限制。宝玉半价出售分别为白10000、青5000、赤2500。
- 武器、法杖使用现有 `Weapon`，运输队仍按现有八种武器分类。其他道具使用 `Item`，运输队归入杂物；`item_kind` 记录细分类。
- 普通道具的 `remaining_uses/max_uses` 只登记次数，暂不提供使用入口；`is_consumable()` 保持 false，防止新道具误执行现有伤药逻辑。武器仍以 `durability/max_durability` 为实际耐久来源。
- 普通攻击、勇者连击、已有属性加成沿用现有系统。毒、吸血、相克反转、职业/角色专用限制、魔法剑、特效等特殊能力仅登记在 `original_data`，描述明确标注待实现。`effect_implemented` 为 false 表示尚有特殊能力未实现，不会禁止普通武器攻击。
- 治疗之杖与回复之杖适配现有 `BattleStaff`，`might` 分别为10和20，原表原始字段保留在 `original_data`。其余特殊法杖只登记，不应进入现有治疗流程；父模块按 `effect_id/effect_implemented` 过滤。
- 原版魔力相关法杖范围以 `original_data.encodedRange` 保留；因效果暂缓，其 `Weapon` 射程采用安全占位，不能作为完整原版法杖实现使用。
- 物品入包和入运输队前必须 `duplicate()`；单位背包必须调用封装入口，不能直接修改数组或装备引用。

## 复现与验证

1. 以32位 Windows PowerShell执行 `tools/scripts/export_fe8_item_icons.ps1`，从本机 FEBuilder 和用户 ROM 导出原图至已忽略的原稿目录。
2. `python tools/scripts/import_fe8_items.py --icons "E:/Dream/资源/FE-Repo-main/FE-Repo-main/Item Icons"`。需要 Pillow；原始表和译名清单随工具保存，工具只覆盖专用 fe8 目录。
3. Godot 完成导入后运行 `res://tests/test_fe8_item_catalog.tscn`，覆盖全量加载、九类运输队、JSON保存往返、模板实例隔离与背包容量。

## 物品清单

| 编号 | 名称 | 类别 | 满次数买价 | 特殊能力已接入 | 资源 |
| --- | --- | --- | ---: | --- | --- |
| SWORD_IRON | 铁剑 | sword | 460 | 是 | `res://data/items/fe8/iron_sword.tres` |
| SWORD_SLIM | 细剑 | sword | 480 | 是 | `res://data/items/fe8/slim_sword.tres` |
| SWORD_STEEL | 钢剑 | sword | 600 | 是 | `res://data/items/fe8/steel_sword.tres` |
| SWORD_SILVER | 银剑 | sword | 1500 | 是 | `res://data/items/fe8/silver_sword.tres` |
| BLADE_IRON | 铁大剑 | sword | 980 | 是 | `res://data/items/fe8/iron_blade.tres` |
| BLADE_STEEL | 钢大剑 | sword | 1250 | 是 | `res://data/items/fe8/steel_blade.tres` |
| BLADE_SILVER | 银大剑 | sword | 1800 | 是 | `res://data/items/fe8/silver_blade.tres` |
| SWORD_VENIN | 毒剑 | sword | 0 | 待实现 | `res://data/items/fe8/poison_sword.tres` |
| SWORD_RAPIER | 突刺剑 | sword | 6000 | 待实现 | `res://data/items/fe8/rapier.tres` |
| SWORD_BRAVE | 勇者剑 | sword | 7500 | 是 | `res://data/items/fe8/brave_sword.tres` |
| SWORD_SHAMSIR | 新月刃 | sword | 1200 | 待实现 | `res://data/items/fe8/shamshir.tres` |
| SWORD_KILLER | 必杀剑 | sword | 1300 | 是 | `res://data/items/fe8/killing_edge.tres` |
| SWORD_ARMORSLAYER | 破甲剑 | sword | 1260 | 待实现 | `res://data/items/fe8/armorslayer.tres` |
| SWORD_WYRMSLAYER | 斩龙剑 | sword | 4500 | 待实现 | `res://data/items/fe8/wyrmslayer.tres` |
| SWORD_LIGHTBRAND | 光之剑 | sword | 1250 | 待实现 | `res://data/items/fe8/light_brand.tres` |
| SWORD_RUNESWORD | 符文剑 | sword | 3300 | 待实现 | `res://data/items/fe8/runesword.tres` |
| SWORD_LANCEREAVER | 破枪剑 | sword | 1800 | 待实现 | `res://data/items/fe8/lancereaver.tres` |
| SWORD_ZANBATO | 斩马刀 | sword | 1260 | 待实现 | `res://data/items/fe8/zanbato.tres` |
| LANCE_IRON | 铁枪 | lance | 360 | 是 | `res://data/items/fe8/iron_lance.tres` |
| LANCE_SLIM | 细枪 | lance | 450 | 是 | `res://data/items/fe8/slim_lance.tres` |
| LANCE_STEEL | 钢枪 | lance | 480 | 是 | `res://data/items/fe8/steel_lance.tres` |
| LANCE_SILVER | 银枪 | lance | 1200 | 是 | `res://data/items/fe8/silver_lance.tres` |
| LANCE_VENIN | 毒枪 | lance | 0 | 待实现 | `res://data/items/fe8/poison_lance.tres` |
| LANCE_BRAVE | 勇者枪 | lance | 7500 | 是 | `res://data/items/fe8/brave_lance.tres` |
| LANCE_KILLER | 必杀枪 | lance | 1200 | 是 | `res://data/items/fe8/killer_lance.tres` |
| LANCE_HORSESLAYER | 刺马枪 | lance | 1040 | 待实现 | `res://data/items/fe8/horseslayer.tres` |
| LANCE_JAVELIN | 投枪 | lance | 400 | 是 | `res://data/items/fe8/javelin.tres` |
| LANCE_SPEAR | 穿刺枪 | lance | 9000 | 是 | `res://data/items/fe8/spear.tres` |
| LANCE_AXEREAVER | 破斧枪 | lance | 1950 | 待实现 | `res://data/items/fe8/axereaver.tres` |
| AXE_IRON | 铁斧 | axe | 270 | 是 | `res://data/items/fe8/iron_axe.tres` |
| AXE_STEEL | 钢斧 | axe | 360 | 是 | `res://data/items/fe8/steel_axe.tres` |
| AXE_SILVER | 银斧 | axe | 1000 | 是 | `res://data/items/fe8/silver_axe.tres` |
| AXE_VENIN | 毒斧 | axe | 0 | 待实现 | `res://data/items/fe8/poison_axe.tres` |
| AXE_BRAVE | 勇者斧 | axe | 7500 | 是 | `res://data/items/fe8/brave_axe.tres` |
| AXE_KILLER | 必杀斧 | axe | 1000 | 是 | `res://data/items/fe8/killer_axe.tres` |
| AXE_HALBERD | 斩马斧 | axe | 810 | 待实现 | `res://data/items/fe8/halberd.tres` |
| AXE_HAMMER | 战锤 | axe | 800 | 待实现 | `res://data/items/fe8/hammer.tres` |
| AXE_DEVIL | 恶魔之斧 | axe | 900 | 待实现 | `res://data/items/fe8/devil_axe.tres` |
| AXE_HANDAXE | 手斧 | axe | 300 | 是 | `res://data/items/fe8/hand_axe.tres` |
| AXE_TOMAHAWK | 战斧 | axe | 3000 | 是 | `res://data/items/fe8/tomahawk.tres` |
| AXE_SWORDREAVER | 破剑斧 | axe | 2100 | 待实现 | `res://data/items/fe8/swordreaver.tres` |
| AXE_SWORDSLAYER | 剑杀斧 | axe | 2000 | 待实现 | `res://data/items/fe8/swordslayer.tres` |
| AXE_HATCHET | 轻斧 | axe | 0 | 是 | `res://data/items/fe8/hatchet.tres` |
| BOW_IRON | 铁弓 | bow | 540 | 待实现 | `res://data/items/fe8/iron_bow.tres` |
| BOW_STEEL | 钢弓 | bow | 720 | 待实现 | `res://data/items/fe8/steel_bow.tres` |
| BOW_SILVER | 银弓 | bow | 1600 | 待实现 | `res://data/items/fe8/silver_bow.tres` |
| BOW_VENIN | 毒弓 | bow | 0 | 待实现 | `res://data/items/fe8/poison_bow.tres` |
| BOW_KILLER | 必杀弓 | bow | 1400 | 待实现 | `res://data/items/fe8/killer_bow.tres` |
| BOW_BRAVE | 勇者弓 | bow | 7500 | 待实现 | `res://data/items/fe8/brave_bow.tres` |
| BOW_SHORTBOW | 短弓 | bow | 1760 | 待实现 | `res://data/items/fe8/short_bow.tres` |
| BOW_LONGBOW | 长弓 | bow | 2000 | 待实现 | `res://data/items/fe8/longbow.tres` |
| ANIMA_FIRE | 火炎 | anima | 560 | 是 | `res://data/items/fe8/fire.tres` |
| ANIMA_THUNDER | 雷电 | anima | 700 | 是 | `res://data/items/fe8/thunder.tres` |
| ANIMA_ELFIRE | 业火 | anima | 1200 | 是 | `res://data/items/fe8/elfire.tres` |
| ANIMA_BOLTING | 雷暴 | anima | 2500 | 是 | `res://data/items/fe8/bolting.tres` |
| ANIMA_FIMBULVETR | 冰雪 | anima | 6000 | 是 | `res://data/items/fe8/fimbulvetr.tres` |
| ANIMA_EXCALIBUR | 风刃·埃克斯卡利伯 | anima | 0 | 待实现 | `res://data/items/fe8/excalibur.tres` |
| LIGHT_LIGHTNING | 闪光 | light | 630 | 是 | `res://data/items/fe8/lightning.tres` |
| LIGHT_SHINE | 光耀 | light | 900 | 是 | `res://data/items/fe8/shine.tres` |
| LIGHT_DIVINE | 神圣 | light | 2500 | 是 | `res://data/items/fe8/divine.tres` |
| LIGHT_PURGE | 净化 | light | 3000 | 是 | `res://data/items/fe8/purge.tres` |
| LIGHT_AURA | 光轮 | light | 8000 | 是 | `res://data/items/fe8/aura.tres` |
| DARK_FLUX | 熔流 | dark | 900 | 是 | `res://data/items/fe8/flux.tres` |
| DARK_LUNA | 月光 | dark | 4200 | 是 | `res://data/items/fe8/luna.tres` |
| DARK_NOSFERATU | 吸星 | dark | 3200 | 待实现 | `res://data/items/fe8/nosferatu.tres` |
| DARK_ECLIPSE | 月蚀 | dark | 4000 | 待实现 | `res://data/items/fe8/eclipse.tres` |
| DARK_FENRIR | 芬布尔 | dark | 9000 | 是 | `res://data/items/fe8/fenrir.tres` |
| DARK_GLEIPNIR | 魔典·格莱普尼尔 | dark | 0 | 是 | `res://data/items/fe8/gleipnir.tres` |
| STAFF_HEAL | 治疗之杖 | staff | 600 | 是 | `res://data/items/fe8/heal.tres` |
| STAFF_MEND | 回复之杖 | staff | 1000 | 是 | `res://data/items/fe8/mend.tres` |
| STAFF_RECOVER | 痊愈之杖 | staff | 2250 | 待实现 | `res://data/items/fe8/recover.tres` |
| STAFF_PHYSIC | 远疗之杖 | staff | 3750 | 待实现 | `res://data/items/fe8/physic.tres` |
| STAFF_FORTIFY | 圣愈之杖 | staff | 8000 | 待实现 | `res://data/items/fe8/fortify.tres` |
| STAFF_RESTORE | 复原之杖 | staff | 2000 | 待实现 | `res://data/items/fe8/restore.tres` |
| STAFF_SILENCE | 沉默之杖 | staff | 1200 | 待实现 | `res://data/items/fe8/silence.tres` |
| STAFF_SLEEP | 睡眠之杖 | staff | 1500 | 待实现 | `res://data/items/fe8/sleep.tres` |
| STAFF_BERSERK | 狂乱之杖 | staff | 1800 | 待实现 | `res://data/items/fe8/berserk.tres` |
| STAFF_WARP | 传送之杖 | staff | 7500 | 待实现 | `res://data/items/fe8/warp.tres` |
| STAFF_RESCUE | 救援之杖 | staff | 1800 | 待实现 | `res://data/items/fe8/rescue.tres` |
| STAFF_TORCH | 照明之杖 | staff | 1000 | 待实现 | `res://data/items/fe8/torch_staff.tres` |
| STAFF_REPAIR | 修理之杖 | staff | 1800 | 待实现 | `res://data/items/fe8/hammerne.tres` |
| STAFF_UNLOCK | 开锁之杖 | staff | 1500 | 待实现 | `res://data/items/fe8/unlock.tres` |
| STAFF_BARRIER | 屏障之杖 | staff | 2250 | 待实现 | `res://data/items/fe8/barrier.tres` |
| BOOSTER_HP | 天使之衣 | stat_booster | 8000 | 待实现 | `res://data/items/fe8/angelic_robe.tres` |
| BOOSTER_POW | 力量之环 | stat_booster | 8000 | 待实现 | `res://data/items/fe8/energy_ring.tres` |
| BOOSTER_SKL | 秘传之书 | stat_booster | 8000 | 待实现 | `res://data/items/fe8/secret_book.tres` |
| BOOSTER_SPD | 疾风之羽 | stat_booster | 8000 | 待实现 | `res://data/items/fe8/speedwing.tres` |
| BOOSTER_LCK | 女神像 | stat_booster | 8000 | 待实现 | `res://data/items/fe8/goddess_icon.tres` |
| BOOSTER_DEF | 龙盾 | stat_booster | 8000 | 待实现 | `res://data/items/fe8/dracoshield.tres` |
| BOOSTER_RES | 护身符 | stat_booster | 8000 | 待实现 | `res://data/items/fe8/talisman.tres` |
| BOOSTER_MOV | 靴子 | stat_booster | 8000 | 待实现 | `res://data/items/fe8/boots.tres` |
| BOOSTER_CON | 体格戒指 | stat_booster | 8000 | 待实现 | `res://data/items/fe8/body_ring.tres` |
| HEROCREST | 英雄之证 | promotion | 10000 | 待实现 | `res://data/items/fe8/hero_crest.tres` |
| KNIGHTCREST | 骑士勋章 | promotion | 10000 | 待实现 | `res://data/items/fe8/knight_s_crest.tres` |
| ORIONSBOLT | 猎户座之箭 | promotion | 10000 | 待实现 | `res://data/items/fe8/orion_s_bolt.tres` |
| ELYSIANWHIP | 天空之鞭 | promotion | 10000 | 待实现 | `res://data/items/fe8/elysian_whip.tres` |
| GUIDINGRING | 指引之戒 | promotion | 10000 | 待实现 | `res://data/items/fe8/guiding_ring.tres` |
| CHESTKEY | 宝箱钥匙 | key | 300 | 待实现 | `res://data/items/fe8/chest_key.tres` |
| DOORKEY | 门钥匙 | key | 50 | 待实现 | `res://data/items/fe8/door_key.tres` |
| LOCKPICK | 盗贼钥匙 | key | 1200 | 待实现 | `res://data/items/fe8/lockpick.tres` |
| VULNERARY | 伤药 | consumable | 300 | 待实现 | `res://data/items/fe8/vulnerary.tres` |
| ELIXIR | 特效药 | consumable | 3000 | 待实现 | `res://data/items/fe8/elixir.tres` |
| PUREWATER | 圣水 | consumable | 900 | 待实现 | `res://data/items/fe8/pure_water.tres` |
| ANTITOXIN | 解毒药 | consumable | 450 | 待实现 | `res://data/items/fe8/antitoxin.tres` |
| TORCH | 火把 | consumable | 500 | 待实现 | `res://data/items/fe8/torch_item.tres` |
| DELPHISHIELD | 菲利之盾 | accessory | 10000 | 待实现 | `res://data/items/fe8/delphi_shield.tres` |
| MEMBERCARD | 会员卡 | accessory | 6000 | 待实现 | `res://data/items/fe8/member_card.tres` |
| SILVERCARD | 银卡 | accessory | 4000 | 待实现 | `res://data/items/fe8/silver_card.tres` |
| WHITEGEM | 白宝玉 | valuable | 20000 | 是 | `res://data/items/fe8/white_gem.tres` |
| BLUEGEM | 青宝玉 | valuable | 10000 | 是 | `res://data/items/fe8/blue_gem.tres` |
| REDGEM | 赤宝玉 | valuable | 5000 | 是 | `res://data/items/fe8/red_gem.tres` |
| LANCE_REGINLEIF | 雷金勒夫 | lance | 7200 | 待实现 | `res://data/items/fe8/reginleif.tres` |
| CHESTKEY_BUNDLE | 宝箱钥匙串 | key | 1500 | 待实现 | `res://data/items/fe8/chest_key_bundle.tres` |
| HOPLON_SHIELD | 必杀护符 | accessory | 5000 | 待实现 | `res://data/items/fe8/hoplon_guard.tres` |
| SWORD_SHADOWKILLR | 斩魔剑 | sword | 0 | 待实现 | `res://data/items/fe8/shadowkiller.tres` |
| LANCE_BRIGHTLANCE | 光辉之枪 | lance | 0 | 待实现 | `res://data/items/fe8/bright_lance.tres` |
| AXE_FIENDCLEAVER | 斩魔斧 | axe | 0 | 待实现 | `res://data/items/fe8/fiendcleaver.tres` |
| BOW_BEACONBOW | 破魔弓 | bow | 0 | 待实现 | `res://data/items/fe8/beacon_bow.tres` |
| SWORD_SIEGLINDE | 雷剑·吉克林迪 | sword | 0 | 待实现 | `res://data/items/fe8/sieglinde.tres` |
| AXE_BATTLEAXE | 斗斧 | axe | 1000 | 是 | `res://data/items/fe8/battle_axe.tres` |
| LIGHT_IVALDI | 光辉·伊瓦尔迪 | light | 0 | 待实现 | `res://data/items/fe8/ivaldi.tres` |
| MASTERSEAL | 统领之证 | promotion | 20000 | 待实现 | `res://data/items/fe8/master_seal.tres` |
| METISSTOME | 梅缇斯之书 | consumable | 0 | 待实现 | `res://data/items/fe8/metis_s_tome.tres` |
| STAFF_LATONA | 圣杖·拉特娜 | staff | 0 | 待实现 | `res://data/items/fe8/latona.tres` |
| LANCE_DRAGON | 龙枪 | lance | 4500 | 待实现 | `res://data/items/fe8/dragonspear.tres` |
| LANCE_VIDOFNIR | 翼枪·维德弗尼尔 | lance | 0 | 待实现 | `res://data/items/fe8/vidofnir.tres` |
| SWORD_AUDHULMA | 冰剑·奥德修拉 | sword | 0 | 待实现 | `res://data/items/fe8/audhulma.tres` |
| LANCE_SIEGMUND | 炎枪·吉克穆德 | lance | 0 | 待实现 | `res://data/items/fe8/siegmund.tres` |
| AXE_GARM | 黑斧·加尔姆 | axe | 0 | 待实现 | `res://data/items/fe8/garm.tres` |
| BOW_NIDHOGG | 蛇弓·尼德霍格 | bow | 0 | 待实现 | `res://data/items/fe8/nidhogg.tres` |
| LANCE_HEAVYSPEAR | 重枪 | lance | 1200 | 待实现 | `res://data/items/fe8/heavy_spear.tres` |
| LANCE_SHORTSPEAR | 短枪 | lance | 900 | 是 | `res://data/items/fe8/short_spear.tres` |
| OCEANSEAL | 海之霸者 | promotion | 10000 | 待实现 | `res://data/items/fe8/ocean_seal.tres` |
| LUNARBRACE | 月之腕轮 | promotion | 0 | 待实现 | `res://data/items/fe8/lunar_brace.tres` |
| SOLARBRACE | 日之腕轮 | promotion | 0 | 待实现 | `res://data/items/fe8/solar_brace.tres` |
| SWORD_WINDSWORD | 风之剑 | sword | 8000 | 待实现 | `res://data/items/fe8/wind_sword.tres` |
| DIVINESTONE | 龙石 | dragonstone | 0 | 待实现 | `res://data/items/fe8/divinestone.tres` |
| JUNAFRUIT | 尤娜果实 | consumable | 0 | 待实现 | `res://data/items/fe8/juna_fruit.tres` |
