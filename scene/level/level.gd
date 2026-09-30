class_name Level
extends Node2D

##"""基础关卡类（P3）：关卡场景的通用骨架（模板方法 _ready）
##关卡 tscn 节点名约定（必须提供，level_0.tscn 即此结构）：
##  TileMapLayer / HighLightMapLayer / Cursor / Camera / Units / CanvasLayer
##  CanvasLayer/Phase Switch（回合横幅）CanvasLayer/Battle Preview（战斗预览）
##具体关卡 extends Level，只提供本关数据（全部可选 override）：
##  - _setup_units()：本关玩家与敌人摆放（默认空）
##  - _seed_convoy()：运输队初始物品（默认空）
##  - get_talk_dialogue(unit, target)：本关对话数据（默认无对话）
##  - _setup_map_events()：本关事件定义（默认空）
##  - _on_level_ready()：本关收尾处理，如隐藏预摆增援（默认空）
##  - get_village_reward(cell)：村庄门奖励物品（默认伤药）
##通用机制（UI 装配/回合横幅/相机输入/事件执行器/武器工厂/可交互物扫描）全在本类"""

##单位场景与各 UI 剧本/场景（通用装配）
const UNIT_SCENE := preload("res://scene/character/unit.tscn")
const FORECAST_SCENE := preload("res://scene/ui/battle_preview.tscn")
const ACTION_MENU_SCRIPT := preload("res://scripts/action_menu.gd")
const ITEM_MENU_SCRIPT := preload("res://scripts/item_menu.gd")
const TRADE_MENU_SCRIPT := preload("res://scripts/trade_menu.gd")
const TALK_SCENE := preload("res://scene/ui/talk.tscn")
const INTERACTABLE_SCRIPT := preload("res://scripts/interactable.gd")
const CONVOY_SCENE := preload("res://scene/ui/convoy.tscn")
const BATTLE_ANIMATION_SCENE := preload("res://scene/ui/battle_animation.tscn")
const UNIT_INFO_PANEL_SCENE := preload("res://scene/ui/unit_info_panel.tscn")
##九宫格背景（行动菜单/物品栏共用，5F/UI 升级）
const ITEMSBOX_SCENE := preload("res://scene/ui/itemsbox.tscn")

##通用物品模板与武器图标（武器工厂用）
const POTION_TRES := preload("res://data/items/consumable_potion.tres")
const IRON_AXE_ICON := preload("res://assets/graphics/Item Icons/Axes/铁斧.png")
const IRON_SWORD_ICON := preload("res://assets/graphics/Item Icons/Swords/铁剑.png")

##回合横幅图（阶段四）
const PLAYER_PHASE_TEXTURE := preload("res://assets/graphics/UI/{Lukiroh} Player Phase.png")
const ENEMY_PHASE_TEXTURE := preload("res://assets/graphics/UI/{Lukiroh} Enemy Phase.png")

##字体资源
const LABEL_SETTING_TRES := preload("res://assets/graphics/UI/label_settings.tres")
##字体副本，可自由修改
var label_setting = LABEL_SETTING_TRES.duplicate()

##战斗管理器：由本类 _ready 创建与装配（setup/add_unit/begin_battle 流程不变）
var battle_manager: BattleManager

@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var high_light_layer: TileMapLayer = $HighLightMapLayer
@onready var cursor_node: Node2D = $Cursor
@onready var camera: Camera2D = $Camera
@onready var units_node: Node2D = $Units
@onready var phase_switch: TextureRect = $"CanvasLayer/Phase Switch"


##==================== 启动模板（顺序与原 level_0._ready 一致） ====================

func _ready() -> void:
	battle_manager = BattleManager.new()
	battle_manager.setup(tile_map, high_light_layer, cursor_node, camera)
	_setup_units()
	_setup_battle_forecast()
	_setup_action_menu()
	_setup_item_menu()
	_setup_trade()
	_setup_convoy()
	_setup_battle_animation()
	_setup_unit_info_panel()
	_setup_talk()
	_setup_interactables()
	_setup_map_events()
	_on_level_ready()
	battle_manager.turn_started.connect(_on_turn_started)
	add_child(battle_manager)
	battle_manager.begin_battle()


##虚钩子：本关单位摆放（默认空关卡）
func _setup_units() -> void:
	pass


##虚钩子：本关收尾处理（默认无）
func _on_level_ready() -> void:
	pass


##虚钩子：本关地图事件定义（默认无事件）
func _setup_map_events() -> void:
	pass


##==================== 系统 UI 装配 ====================

##初始化战斗预览面板
func _setup_battle_forecast() -> void:
	var forecast := FORECAST_SCENE.instantiate()
	var ui_layer: CanvasLayer = $CanvasLayer
	ui_layer.add_child(forecast)
	forecast.setup()
	battle_manager.set_forecast_panel(forecast)


##初始化行动菜单（面板节点代码创建，之后可移入 tscn 用编辑器布局）
func _setup_action_menu() -> void:
	var menu := ACTION_MENU_SCRIPT.new()
	var ui_layer: CanvasLayer = $CanvasLayer
	ui_layer.add_child(menu)
	menu.setup(_build_action_menu_panel())
	battle_manager.set_action_menu(menu)


##初始化物品菜单（阶段五 5D）：面板代码构建，挂在 CanvasLayer 下
func _setup_item_menu() -> void:
	var menu := ITEM_MENU_SCRIPT.new()
	$CanvasLayer.add_child(menu)
	battle_manager.set_item_menu(menu)


##初始化交换界面（5F）：面板代码构建，挂在 CanvasLayer 下
func _setup_trade() -> void:
	var trade := TRADE_MENU_SCRIPT.new()
	$CanvasLayer.add_child(trade)
	battle_manager.set_trade_menu(trade)


##初始化运输队面板：挂在 CanvasLayer 下，初始物品由关卡 _seed_convoy 提供
func _setup_convoy() -> void:
	var convoy := CONVOY_SCENE.instantiate()
	$CanvasLayer.add_child(convoy)
	convoy.visible = false
	battle_manager.set_convoy_panel(convoy)
	_seed_convoy()
	convoy.current_items.text = str(ConvoyStore.get_current_items())


##虚钩子：运输队初始物品（默认空；塞物品用 _create_iron_sword 等工厂，注意给独立实例）
func _seed_convoy() -> void:
	pass


##初始化战斗动画场景（阶段五 5A）：挂在 CanvasLayer 下覆盖地图
func _setup_battle_animation() -> void:
	var battle_anim := BATTLE_ANIMATION_SCENE.instantiate()
	$CanvasLayer.add_child(battle_anim)
	battle_anim.visible = false
	battle_manager.set_battle_scene(battle_anim)


##初始化人物信息面板（阶段五 5B）：挂在 CanvasLayer 下覆盖地图
func _setup_unit_info_panel() -> void:
	var info_panel := UNIT_INFO_PANEL_SCENE.instantiate()
	$CanvasLayer.add_child(info_panel)
	info_panel.visible = false
	battle_manager.set_unit_info_panel(info_panel)


##构建行动菜单面板（5F/UI 升级）：itemsbox 九宫格背景（宽 48，高度随选项数动态调整）
##+ VBox（内容区从九宫格上/左边距起）+ 固定项 Label（物品/待机/运输队）
func _build_action_menu_panel() -> Control:
	var panel: NinePatchRect = ITEMSBOX_SCENE.instantiate()
	panel.name = "Action Menu"
	panel.visible = false
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.position = Vector2(13, 13)
	vbox.add_theme_constant_override("separation", 0)
	panel.add_child(vbox)
	for text in ["物品", "待机", "运输队"]:
		var label := Label.new()
		label.text = text
		label.custom_minimum_size = Vector2(22, 10)
		label.label_settings = label_setting
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)
	$CanvasLayer.add_child(panel)
	return panel


##==================== 对话系统 ====================

##初始化对话系统（通用）：talk.tscn 挂 CanvasLayer，注入 BattleManager 与对话数据提供者
##对话内容由具体关卡 override get_talk_dialogue 提供
func _setup_talk() -> void:
	var talk := TALK_SCENE.instantiate()
	$CanvasLayer.add_child(talk)
	battle_manager.set_talk_scene(talk)
	battle_manager.set_talk_provider(get_talk_dialogue)


##人物对话数据提供者（虚方法）：按对话双方单位匹配，返回空字典表示无对话
##返回格式 {"lines": [{"speaker","text","side"}...], "portraits": {说话人名: Texture2D}}
##具体关卡 override 此方法返回本关对话；默认无对话
func get_talk_dialogue(_unit: Unit, _target: Unit) -> Dictionary:
	return {}


##==================== 可交互物 ====================

##初始化可交互物（阶段五 5E）：扫描地形为"民居"的瓦片生成村庄门
##宝箱暂无对应瓦片，后续可在编辑器摆 Interactable 节点或加地形层
##奖励物品由 get_village_reward 提供（默认伤药，关卡可 override）
func _setup_interactables() -> void:
	var container := Node2D.new()
	container.name = "Interactables"
	add_child(container)
	for cell in tile_map.get_used_cells():
		if Pathfinder.get_terrain_name(tile_map, cell) == "民居":
			var door: Interactable = INTERACTABLE_SCRIPT.new()
			door.kind = Interactable.Kind.VILLAGE
			door.reward = get_village_reward(cell)
			door.position = Vector2(cell) * Global.TILE_SIZE
			container.add_child(door)


##村庄门奖励（虚方法）：默认伤药；关卡可按格子返回不同奖励，null = 无奖励
func get_village_reward(_cell: Vector2i) -> Item:
	return POTION_TRES


##==================== 地图事件执行器 ====================

##事件执行器（通用）：顺序 await 每个动作（对话/增援/给物品都可能是协程）
##关卡把此方法作为 runner 传给 battle_manager.set_map_events(events, run_map_event)
func run_map_event(event: MapEvent) -> void:
	for action in event.actions:
		await action.execute(self)


##==================== 单位与武器工厂 ====================

## 创建敌人 cell_pos: 瓦片坐标, unit_name: 敌人名称, weapon: 武器实例, hp_val: 血量, str_val: 力量, skl_val: 技巧, spd_val: 速度, def_val: 防御
## 武器通过 Unit 接口入包+装备（P0-2 不变量），属性全部可按需覆盖
func _create_enemy(cell_pos: Vector2i, unit_name: String, weapon: Weapon, hp_val: int, str_val: int, skl_val: int, spd_val: int, def_val: int) -> void:
	var enemy: Unit = UNIT_SCENE.instantiate()
	enemy.unit_name = unit_name
	enemy.team = 1
	enemy.cell = cell_pos
	enemy.global_position = Vector2(cell_pos) * Global.TILE_SIZE
	if weapon != null:
		enemy.add_item(weapon)
		enemy.equip_item(weapon)
	enemy.max_hp = hp_val
	enemy.hp = hp_val
	enemy.str = str_val
	enemy.skl = skl_val
	enemy.spd = spd_val
	enemy.def_h = def_val
	units_node.add_child(enemy)
	battle_manager.add_unit(enemy)


##"""铁剑工厂（每次独立实例）：might 5 / hit 100 / weight 5 / 射程 1-1"""
func _create_iron_sword() -> Weapon:
	var sword := Weapon.new()
	sword.display_name = "铁剑"
	sword.weapon_type = Weapon.WeaponType.SWORD
	sword.might = 5
	sword.hit = 100
	sword.crit = 0
	sword.weight = 5
	sword.min_range = 1
	sword.max_range = 1
	sword.icon = IRON_SWORD_ICON
	return sword


##"""铁斧工厂（每次独立实例）：might 8 / hit 70 / weight 10 / 射程 1-1"""
func _create_iron_axe() -> Weapon:
	var axe := Weapon.new()
	axe.display_name = "铁斧"
	axe.weapon_type = Weapon.WeaponType.AXE
	axe.might = 8
	axe.hit = 70
	axe.crit = 0
	axe.weight = 10
	axe.min_range = 1
	axe.max_range = 1
	axe.icon = IRON_AXE_ICON
	return axe


##==================== 回合横幅 ====================

##回合开始：横幅从右外侧滑入中央停留，再滑到左外侧消失
##要调整速度/距离，改下面三个时间常量与 MARGIN 即可
const PHASE_SWITCH_DURATION_IN := 0.35
const PHASE_SWITCH_DURATION_STAY := 0.5
const PHASE_SWITCH_DURATION_OUT := 0.35
const PHASE_SWITCH_MARGIN := 32.0

func _on_turn_started(team: int) -> void:
	var texture: Texture2D = PLAYER_PHASE_TEXTURE if team == 0 else ENEMY_PHASE_TEXTURE
	var view_size: Vector2 = get_viewport().get_visible_rect().size
	var tex_size: Vector2 = texture.get_size()

	phase_switch.texture = texture
	phase_switch.size = tex_size
	phase_switch.visible = true

	var center_x: float = (view_size.x - tex_size.x) * 0.5
	var start_x: float = view_size.x + PHASE_SWITCH_MARGIN
	var end_x: float = -tex_size.x - PHASE_SWITCH_MARGIN

	phase_switch.position = Vector2(start_x, (view_size.y - tex_size.y) * 0.5)

	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(phase_switch, "position:x", center_x, PHASE_SWITCH_DURATION_IN)
	tween.tween_interval(PHASE_SWITCH_DURATION_STAY)
	tween.tween_property(phase_switch, "position:x", end_x, PHASE_SWITCH_DURATION_OUT)
	tween.tween_callback(func(): phase_switch.visible = false)


##==================== 相机与输入转发 ====================

func _process(_delta: float) -> void:
	##敌方回合相机跟随当前行动的敌人，事件演出跟随 cutscene_focus，其余时间跟随光标
	var focus: Node2D = cursor_node
	if battle_manager.cutscene_focus != null and is_instance_valid(battle_manager.cutscene_focus):
		focus = battle_manager.cutscene_focus
	elif battle_manager.state == BattleManager.State.ENEMY_TURN \
			and battle_manager.current_ai_unit != null \
			and is_instance_valid(battle_manager.current_ai_unit):
		focus = battle_manager.current_ai_unit
	camera.target_position = focus.global_position


func _unhandled_input(event: InputEvent) -> void:
	battle_manager.handle_input(event)
