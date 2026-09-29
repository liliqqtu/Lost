extends Level
##"""关卡一（P3）：extends Level（scene/level/level.gd 基础关卡类）
##本类只存放本关卡的具体数据：对话内容/肖像、地图事件、单位摆放、运输队种子、增援预摆
##通用骨架（UI 装配/回合横幅/相机输入/事件执行器/武器工厂/可交互物扫描）在 Level 基类"""

##人物肖像（Class Card，阶段五 5E 对话系统）
const TE_CARD := preload("res://assets/graphics/Class Card/忒.png")
const ISAR_CARD := preload("res://assets/graphics/Class Card/Isar.png")

##人物对话数据（5E 测试）：忒 × 伊萨尔，伊萨尔在 left1、忒在 right1
const TALK_TE_ISAR: Array = [
	{"speaker": "忒", "text": "老师！是你嘛？！哦谢天谢地，你怎么会在这里？", "side": "right1"},
	{"speaker": "伊萨尔", "text": "我打算去王都xxx，特意绕远路过来看看你，看来国王的高税收诞生的后果已经蔓延到这里了。", "side": "left1"},
	{"speaker": "忒", "text": "是的，很多老实本分的人当起了山贼来抢劫村庄。", "side": "right1"},
	{"speaker": "伊萨尔", "text": "话不多说，先解决掉眼前的敌人吧。", "side": "left1"},
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
	ConvoyStore.add(potion2)
