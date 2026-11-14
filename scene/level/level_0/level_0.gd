extends Level
##"""关卡一（P3）：extends Level（scene/level/level.gd 基础关卡类）
##本类只存放本关卡的具体数据：对话内容/肖像、地图事件、单位摆放、运输队种子、增援预摆
##通用骨架（UI 装配/回合横幅/相机输入/事件执行器/武器工厂/可交互物扫描）在 Level 基类"""

##人物肖像（Class Card，阶段五 5E 对话系统）
const TE_CARD := preload("res://assets/graphics/Class Card/忒.png")
const ISAR_CARD := preload("res://assets/graphics/Class Card/Isar.png")
const ZAKA_CARD := preload("res://assets/graphics/Class Card/扎卡.png")

##开场对话：忒在废弃驿站荒沙中直面末日狂欢的山贼头目扎卡
const OPENING_LINES: Array = [
	{"speaker": "扎卡", "text": "哈哈哈！看看这个要死不活的小子……脸白得跟风化的骨头一样，还提着张拉不开的破短弓！", "side": "left1"},
	{"speaker": "扎卡", "text": "小子，老老实实把盘缠交出来！大爷给你个痛快，省得你在白风里慢慢风化成灰！", "side": "left1"},
	{"speaker": "忒", "text": "……生来皆无意义。既然最终都要化作风暴里的白尘，你们为何还要如此费力地挥刀？", "side": "right1"},
	{"speaker": "扎卡", "text": "少他妈跟老子扯什么大道理！肚子饿了要吃肉，刀锋砍进肉里有血喷出来，这就是老子的活法！动手！", "side": "left1"},
	{"speaker": "忒", "text": "……天地荒谬，终极的意义或许真的不存在。但既然冰冷的刀锋已逼至眼前一寸……", "side": "right1"},
	{"speaker": "忒", "text": "……那就容不得我退缩！", "side": "right1"},
]

##Boss 交战台词：扎卡 × 玩家角色
const BOSS_BATTLE_ZAKA_TE: Array = [
	{"speaker": "扎卡", "text": "哈哈哈！不知天高地厚的白面小子，也敢来捋大爷的虎须！老子一斧头把你剁碎！", "side": "left1"},
	{"speaker": "忒", "text": "……天地荒谬，终极的意义或许真的不存在。但眼前逼至一寸的刀锋，我绝不退让！", "side": "right1"},
]

const BOSS_BATTLE_ZAKA_ISAR: Array = [
	{"speaker": "扎卡", "text": "哪来的黑袍怪人！少管大爷们的快活事，去死吧！", "side": "left1"},
	{"speaker": "伊萨尔", "text": "在真理的暗门前，荒原狂徒的刀剑不过是微不足道的尘埃。", "side": "right1"},
]

const BOSS_BATTLE_ZAKA_GENERIC: Array = [
	{"speaker": "扎卡", "text": "不长眼的杂碎！尝尝大爷我手中利斧的滋味！", "side": "left1"},
]

##Boss 临终遗言
const BOSS_DEFEAT_ZAKA: Array = [
	{"speaker": "扎卡", "text": "呃……啊！怎、怎么可能……老子横行这片荒原……竟然会栽在这里……咳啊！", "side": "left1"},
]

##人物对话数据：忒 × 伊萨尔
const TALK_TE_ISAR: Array = [
	{"speaker": "忒", "text": "老师！怎么会是您？！您怎么会出现在这片荒原？", "side": "right1"},
	{"speaker": "伊萨尔", "text": "我一直在追踪虚无之潮蔓延的痕迹。听说这片荒野有末日狂徒聚集，特意赶来看看，没想到正好看见你手握短弓的样子。", "side": "left1"},
	{"speaker": "忒", "text": "我……我依然不知道明天该去向何方。我拉不开远方的弓，眼前所见只有这脚下一寸之地。", "side": "right1"},
	{"speaker": "伊萨尔", "text": "那就先看清脚下的一寸之地。心怀迷茫并不耻辱，重要的是你手里的弓还没有放下。并肩作战吧，忒！", "side": "left1"},
]

##战后收尾对话：伊萨尔递上水壶，探讨一寸之遥的呼吸与存在的明证
const ENDING_LINES: Array = [
	{"speaker": "忒", "text": "呼……哈……呼……刀刃……终于停下了……", "side": "right1"},
	{"speaker": "伊萨尔", "text": "（递过皮水壶）大口喘息吧，忒。喝点水。", "side": "left1"},
	{"speaker": "忒", "text": "（接过水壶大口咽下，双手仍微微颤抖）老师……刚才在刀光扑来的那一瞬，我浑身都在发抖……我以为自己随时会变成风化的死人。", "side": "right1"},
	{"speaker": "伊萨尔", "text": "二十年前，贤者们推开真理的暗门，发现宏大的命途不过是一场虚妄。整片大陆的人因此绝望沉沦，任由灵魂风化为灰烬。", "side": "left1"},
	{"speaker": "伊萨尔", "text": "但看看你刚才，忒。剧烈起伏的胸膛，狂跳的心脏，手腕上的鲜血与泥土——这就是你一寸之遥的呼吸。在虚无的荒原上，这声呼吸就是你存在的明证。", "side": "left1"},
	{"speaker": "忒", "text": "存在的……明证？可是荒原的前方……真的还有道路吗？", "side": "right1"},
	{"speaker": "伊萨尔", "text": "路从来不是现成的，是你踏出的每一步定义了它。收拾行装吧，随我前往断风隘口。", "side": "left1"},
	{"speaker": "伊萨尔", "text": "听说那里的难民车队正被狂徒截杀……我们要去看看，在没有救世主的世界里，还有没有人愿意迈出脚步。", "side": "left1"},
	{"speaker": "忒", "text": "……断风隘口吗。哪怕不知道明天会怎样……我也想去亲眼看一看。", "side": "right1"},
]

##地图事件动作（本关：第 2 回合 Isar 增援）
const MAP_EVENT_SCRIPT := preload("res://scripts/map_event.gd")
const ACTION_REINFORCE_SCRIPT := preload("res://scripts/action_reinforce.gd")

##敌人容器（关卡约定：场景摆放的敌人在 Units/Enemy 下）
@onready var enemy_node: Node2D = $Units/Enemy


##==================== 单位摆放（override 基类虚钩子） ====================

func _setup_units() -> void:
	_setup_player_unit()
	_setup_enemies()
	##支援系统测试（5G）：预置 1 点支援值——忒与伊萨尔相邻即可触发"支援"升 C（对话内容 "1"）
	##正式门槛按支援对在 data/support/te_isar.tres 里配置（共同出战一章 +1 点）
	SupportStore.add_points("忒", "伊萨尔", 1)


func _setup_player_unit() -> void:
	var player: Unit = $Units/Te
	##武器不再单独 new：Unit 进树时 _own_inventory 会把 current_weapon
	##归位到背包内的铁弓实例（攻击扣耐久与 UI 显示才是同一把武器）
	player.global_position = Vector2(player.cell) * Global.TILE_SIZE
	battle_manager.add_unit(player)


func _setup_enemies() -> void:
	for enemy in enemy_node.get_children():
		enemy.cell = Vector2i(enemy.global_position) / Global.TILE_SIZE
		##场景摆放的敌人默认配铁斧，属性可在检查器里按实例单独调整
		if enemy.current_weapon == null:
			var axe := _create_iron_axe()
			##P0-2：装备并入背包统一走 Unit 接口（add_item + equip_item 保持不变量）
			enemy.add_item(axe)
			enemy.equip_item(axe)
		battle_manager.add_unit(enemy)
	#_create_enemy(Vector2i(5, 5), "山贼", _create_iron_axe(), 18, 6, 3, 2, 3)
	#_create_enemy(Vector2i(6, 7), "山贼", _create_iron_axe(), 18, 6, 3, 2, 3)


##==================== 对话数据（override 基类虚方法） ====================

##人物对话数据提供者（override 基类虚方法）：按对话双方单位名匹配，返回空字典表示无对话
func get_talk_dialogue(unit: Unit, target: Unit) -> Dictionary:
	var pair := [unit.unit_name, target.unit_name]
	if pair.has("忒") and pair.has("伊萨尔"):
		return {"lines": TALK_TE_ISAR, "portraits": {"忒": TE_CARD, "伊萨尔": ISAR_CARD}}
	return {}


func get_opening_dialogue() -> Dictionary:
	return {
		"lines": OPENING_LINES,
		"portraits": {"忒": TE_CARD, "扎卡": ZAKA_CARD}
	}


func get_ending_dialogue() -> Dictionary:
	return {
		"lines": ENDING_LINES,
		"portraits": {"忒": TE_CARD, "伊萨尔": ISAR_CARD}
	}


func get_boss_battle_dialogue(attacker: Unit, defender: Unit) -> Dictionary:
	var boss: Unit = defender if defender.unit_name == "扎卡" else (attacker if attacker.unit_name == "扎卡" else null)
	if boss == null:
		return {}
	var other: Unit = attacker if defender == boss else defender
	if other.unit_name == "忒":
		return {"lines": BOSS_BATTLE_ZAKA_TE, "portraits": {"扎卡": ZAKA_CARD, "忒": TE_CARD}}
	elif other.unit_name == "伊萨尔":
		return {"lines": BOSS_BATTLE_ZAKA_ISAR, "portraits": {"扎卡": ZAKA_CARD, "伊萨尔": ISAR_CARD}}
	else:
		return {"lines": BOSS_BATTLE_ZAKA_GENERIC, "portraits": {"扎卡": ZAKA_CARD}}


func get_boss_defeat_dialogue(boss: Unit, _killer: Unit) -> Dictionary:
	if boss.unit_name == "扎卡":
		return {"lines": BOSS_DEFEAT_ZAKA, "portraits": {"扎卡": ZAKA_CARD}}
	return {}


func get_next_chapter_path() -> String:
	return "res://scene/level/level_1/level_1.tscn"


func get_next_chapter_title() -> String:
	return "第一章 向崖底纵跃之人"


##==================== 地图事件（override 基类虚钩子） ====================

##初始化地图事件（阶段五 5E）：第 2 回合开始时 Isar 登场并走到地图中央
##事件执行器 run_map_event 在基类 Level（通用：顺序 await 各动作）
func _setup_map_events() -> void:
	var reinforce: ActionReinforce = ACTION_REINFORCE_SCRIPT.new()
	reinforce.placed_node_name = "Isar"
	reinforce.walk_to = Vector2i(-1, 0)
	var event: MapEvent = MAP_EVENT_SCRIPT.new()
	event.trigger_turn = 2
	event.actions.append(reinforce)
	battle_manager.set_map_events([event], run_map_event)


##==================== 本关收尾（override 基类虚钩子） ====================

func _on_level_ready() -> void:
	##预摆的 Isar 先隐藏：等第 2 回合地图事件登场（淡入 + 走位演出）
	if has_node("Units/Isar"):
		$Units/Isar.visible = false


##==================== 运输队种子（override 基类虚钩子） ====================

##测试数据：运输队初始有铁剑、铁斧、伤药*2（都是独立实例）
func _seed_convoy() -> void:
	if not ConvoyStore.items.is_empty():
		return
	var sword := _create_iron_sword()
	sword.durability = 40
	ConvoyStore.add(sword)
	var axe := _create_iron_axe()
	axe.durability = 38
	ConvoyStore.add(axe)
	var potion1: Consumable = POTION_TRES.duplicate()
	ConvoyStore.add(potion1)
	var potion2: Consumable = POTION_TRES.duplicate()
