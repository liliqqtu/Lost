extends Node
class_name BattleManager

##战斗管理器（门面）：状态机与输入分派、单位选中/移动/路径预览、行动收尾、地图基础查询。
##原单文件 1341 行（混入大量非战斗功能，超 500 行红线），已按职责分包为七个模块：
##  battle_unit_commands.gd   单位指令流程（行动菜单/目标选择/战斗预览/物品·运输队·交换面板）
##  battle_map_interaction.gd 村庄·宝箱访问与人物对话（5E）
##  battle_rescue.gd          救援/放下/交接/交换（5F）
##  battle_range_inspect.gd   敌人范围查看
##  battle_canto.gd           再移动（焕发技能）
##  battle_combat.gd          战斗结算执行
##  battle_phases.gd          回合切换、敌方回合与地图事件
##对外接口保持不变（setup/set_*/begin_battle/add_unit/handle_input/open_dialogue/_move_unit 等），
##各分包经 bm 引用共享 units/selected_unit/cursor/range_drawer 等状态（_init 创建，纯逻辑对象不进场景树）。

##回合开始时广播（team 0 玩家 1 敌方），关卡脚本用于播放回合横幅
signal turn_started(team: int)

enum State {
	CURSOR,
	UNIT_SELECTED,
	MOVING,
	TARGET_SELECT,
	ACTION_MENU,
	ENEMY_TURN,
	BATTLE_ANIM,
	UNIT_INFO,
	CANTO_MOVING,
	CONVOY,
	ITEM_MENU,
	DIALOGUE,
	EVENT,
	##救援/放下/交接的目标选择（5F）
	RESCUE_SELECT,
	##交换界面（5F）
	TRADE,
}

var state := State.CURSOR

##当前回合方 0玩家 1敌方
var phase := 0
##回合数
var turn := 1
##战斗是否结束（一方全灭）
var battle_over := false
##敌方回合当前行动单位（相机跟随用）
var current_ai_unit: Unit = null

var tile_map: TileMapLayer
var high_light_layer: TileMapLayer
var cursor: Node2D
var camera: Camera2D
##所有的单位
var units: Array[Unit] = []
##选中的单位
var selected_unit: Unit
##移动范围
var move_range: Dictionary
##攻击范围
var attack_range: Array
##RangeDrawer的实例化
var range_drawer := RangeDrawer.new()
##选择的路径
var current_path: Array = []
var last_path_cursor: Vector2i

##过场焦点单位（事件演绎期间相机跟随，关卡脚本读取）
var cutscene_focus: Node2D = null
##移动前的格子（行动菜单取消时撤回移动）
var _pre_move_cell := Vector2i(-9999, -9999)
##移动后是否已执行过不可撤销的子行动（对话/交换）——此后行动菜单按 no 不再撤回移动，直接待机（原版行为）
var _menu_action_spent := false
##记录上一次行动是否为攻击（目标选择设为 true，_end_action 读取后清零）
var _last_action_was_attack := false

##==================== 功能分包实例 ====================

##单位指令流程（行动菜单/目标选择/战斗预览/子面板）
var commands: BattleUnitCommands
##地图交互（村庄/宝箱/对话，5E）
var interaction: BattleMapInteraction
##救援/放下/交接/交换（5F）
var rescue: BattleRescue
##敌人范围查看
var range_inspect: BattleRangeInspect
##再移动（焕发技能）
var canto: BattleCanto
##战斗结算执行
var combat: BattleCombat
##回合切换、敌方回合与地图事件
var phases: BattlePhases


func _init() -> void:
	commands = BattleUnitCommands.new()
	commands.bm = self
	interaction = BattleMapInteraction.new()
	interaction.bm = self
	rescue = BattleRescue.new()
	rescue.bm = self
	range_inspect = BattleRangeInspect.new()
	range_inspect.bm = self
	canto = BattleCanto.new()
	canto.bm = self
	combat = BattleCombat.new()
	combat.bm = self
	phases = BattlePhases.new()
	phases.bm = self


##==================== 装配（对外接口不变，内部委托分包） ====================

##初始化战斗地图
func setup(p_tile_map: TileMapLayer, p_highlight: TileMapLayer, p_cursor: Node2D, p_camera: Camera2D) -> void:
	tile_map = p_tile_map
	high_light_layer = p_highlight
	cursor = p_cursor
	camera = p_camera

##设置战斗预览面板
func set_forecast_panel(panel: Node) -> void:
	commands.forecast_panel = panel

##设置行动菜单
func set_action_menu(menu: Node) -> void:
	commands.action_menu = menu

##设置战斗动画场景（阶段五 5A）
func set_battle_scene(scene: Node) -> void:
	combat.battle_scene = scene

##设置人物信息面板（阶段五 5B）
func set_unit_info_panel(panel: Node) -> void:
	commands.unit_info_panel = panel

##设置运输队面板（阶段五 5C）
func set_convoy_panel(panel: Node) -> void:
	commands.set_convoy_panel(panel)

##设置物品菜单（阶段五 5D）
func set_item_menu(menu: Node) -> void:
	commands.set_item_menu(menu)

##设置交换界面（5F）
func set_trade_menu(menu: Node) -> void:
	commands.set_trade_menu(menu)

##设置信息查看器（信息查看系统）：分发给物品菜单/运输队/人物面板
func set_info_viewer(viewer: Node) -> void:
	commands.set_info_viewer(viewer)

##设置对话场景（阶段五 5E 重构）
func set_talk_scene(scene: Node) -> void:
	interaction.talk_scene = scene

##设置人物对话数据提供者（阶段五 5E 重构）：cb 签名 func(unit, target) -> Dictionary
##返回 {"lines": [{"speaker","text","side"}...], "portraits": {说话人: Texture2D}}，空字典=无对话
func set_talk_provider(cb: Callable) -> void:
	interaction.talk_provider = cb

##设置地图事件与执行器（阶段五 5E）：runner 签名 func(event: MapEvent) -> void（可 async）
func set_map_events(events: Array[MapEvent], runner: Callable) -> void:
	phases.set_map_events(events, runner)

##战斗开始：广播玩家回合（播放开局横幅），横幅后检查回合事件（阶段五 5E）
func begin_battle() -> void:
	await phases.begin_battle()

##添加单位
func add_unit(unit: Unit) -> void:
	units.append(unit)
	##5G 支援：记录我方登场（章节结算"共同出战一章 +1 支援值"用；增援登场也走此入口）
	if unit.team == 0:
		SupportStore.mark_deployed(unit.unit_name)


##==================== 输入分派 ====================

##处理输入
func handle_input(event: InputEvent) -> void:
	if battle_over:
		return
	match state:
		State.CURSOR:
			_handle_cursor_input(event)
		State.UNIT_SELECTED:
			_handle_unit_selected_input(event)
		State.MOVING:
			pass
		State.TARGET_SELECT:
			commands.handle_target_select_input(event)
		State.ACTION_MENU:
			commands.handle_action_menu_input(event)
		State.ENEMY_TURN:
			pass
		State.BATTLE_ANIM:
			pass
		State.UNIT_INFO:
			commands.handle_unit_info_input(event)
		State.CANTO_MOVING:
			canto.handle_input(event)
		State.CONVOY:
			if commands.convoy_panel != null:
				commands.convoy_panel.handle_input(event)
		State.ITEM_MENU:
			if commands.item_menu != null:
				commands.item_menu.handle_input(event)
		State.DIALOGUE:
			if interaction.talk_scene != null:
				interaction.talk_scene.handle_input(event)
		State.EVENT:
			pass
		State.RESCUE_SELECT:
			rescue.handle_input(event)
		State.TRADE:
			if commands.trade_menu != null:
				commands.trade_menu.handle_input(event)


##==================== 地图基础查询 ====================

##寻找因为其他单位存在而无法通过的瓦片，上锁该瓦片
func _get_blocked_cells(exclude_unit: Unit = null) -> Array:
	var blocked: Array = []
	for unit in units:
		if unit != exclude_unit:
			blocked.append(unit.cell)
	return blocked


##获取指定格子的单位
func _get_unit_at(cell: Vector2i) -> Unit:
	for unit in units:
		if unit.cell == cell:
			return unit
	return null


##移除单位，并检查是否有一方全灭
func _remove_unit(unit: Unit) -> void:
	units.erase(unit)
	unit.queue_free()
	_check_battle_end()


##==================== 地图基础查询（P2 公开接口） ====================

##查询：指定格子上是否有单位（rescue / interaction / commands 等子模块统一走此入口）
func get_unit_at(cell: Vector2i) -> Unit:
	return _get_unit_at(cell)


##查询：除 exclude_unit 外所有单位占据的格子（移动范围/寻路遮挡统一走此入口）
func get_blocked_cells(exclude_unit: Unit = null) -> Array:
	return _get_blocked_cells(exclude_unit)


##移除单位（阵亡结算）并触发胜负检查（combat 等子模块统一走此入口）
func remove_unit(unit: Unit) -> void:
	_remove_unit(unit)


##通用移动演出（敌方回合 / 增援走位复用），结束返回后单位坐标已更新
func move_unit(unit: Unit, destination: Vector2i) -> void:
	await _move_unit(unit, destination)


##胜负判定：任一阵营全灭则结束战斗
func _check_battle_end() -> void:
	if battle_over:
		return
	var has_player := false
	var has_enemy := false
	for unit in units:
		if unit.team == 0:
			has_player = true
		elif unit.team == 1:
			has_enemy = true
	if not has_enemy:
		battle_over = true
		##5G 支援：章节胜利结算——双方都登场过的支援对 +1 支援值
		SupportStore.on_chapter_cleared()
		print("=== 我方胜利！敌方全灭（回合 %d）===" % turn)
	elif not has_player:
		battle_over = true
		##5G 支援：章节失败，登场记录作废
		SupportStore.on_chapter_failed()
		print("=== 我方败北…（回合 %d）===" % turn)


##==================== 光标 ====================

##处理光标输入
func _handle_cursor_input(event: InputEvent) -> void:
	if event.is_action_pressed("yes"):
		for unit in units:
			if unit.cell == cursor.cell and unit.team == 0 and not unit.has_acted:
				range_inspect.clear_display()
				_select_unit(unit)
				return
		##光标停在敌人上（测试问题2）：显示其移动范围（蓝）+最外围攻击范围（红），再按一次取消
		var enemy := _get_unit_at(cursor.cell)
		if enemy != null and enemy.team == 1 and enemy.carried_by == null:
			range_inspect.toggle_single(enemy)
	elif event.is_action_pressed("no"):
		##查看中的敌人范围随取消键关闭
		range_inspect.clear_display()
	elif event.is_action_pressed("start"):
		##显示/关闭全部敌人的攻击范围并集（红色，不显示移动范围）
		range_inspect.toggle_all()
	elif event.is_action_pressed("R"):
		##光标停在任意单位上（不分敌我）打开人物信息面板
		var unit := _get_unit_at(cursor.cell)
		if unit != null and commands.unit_info_panel != null:
			commands.unit_info_panel.show_panel(unit)
			state = State.UNIT_INFO
			cursor.set_process(false)


##==================== 单位选中与移动 ====================

##处理选中的单位输入，这时已经显示移动范围了
func _handle_unit_selected_input(event: InputEvent) -> void:
	if event.is_action_pressed("yes"):
		var cursor_cell: Vector2i = cursor.cell
		if not move_range.has(cursor_cell):
			return
		_pre_move_cell = selected_unit.cell
		if cursor_cell == selected_unit.cell:
			##原地选择：不播放移动动画，直接进入行动菜单
			_finish_move(cursor_cell)
		else:
			_start_move(cursor_cell)
	elif event.is_action_pressed("no"):
		_cancel_selection()


##选择单位后，计算移动范围和攻击范围,并更新待机动画
func _select_unit(unit: Unit) -> void:
	selected_unit = unit
	state = State.UNIT_SELECTED
	cursor.set_process(true)
	##选中单位会重绘范围层，敌人范围查看状态一并复位；子行动标记重置
	range_inspect.reset()
	_menu_action_spent = false

	selected_unit.play_selected_animation()

	var blocked := _get_blocked_cells(unit)
	move_range = Pathfinder.get_move_range(tile_map, unit.cell, unit.move, unit.move_table, blocked)

	##P0-1：攻击范围统一为背包所有可用武器射程并集（含技能修正），不再仅看 current_weapon
	attack_range = unit.get_attack_range(tile_map, move_range.keys())

	cursor.set_cell(unit.cell)
	cursor.restrict_to = move_range
	last_path_cursor = unit.cell

	range_drawer.clear_all(high_light_layer)
	range_drawer.draw_move_range(move_range, high_light_layer)
	range_drawer.draw_attack_range(attack_range, high_light_layer)
	current_path = [unit.cell]
	## 记录本回合可用于再移动的剩余力（移动开始前=满 MP）
	unit.canto_remaining = unit.move


##返回选择的单位时，清空杂七杂八的缓存数据
func _cancel_selection() -> void:
	selected_unit.play_idle_animation()
	selected_unit = null
	move_range = {}
	attack_range = []
	current_path = []
	last_path_cursor = Vector2i.ZERO
	commands.reset_forecast_cache()
	cursor.restrict_to = {}
	range_drawer.clear_all(high_light_layer)
	state = State.CURSOR


##开始移动，状态置为MOVING
func _start_move(destination: Vector2i) -> void:
	state = State.MOVING
	cursor.restrict_to = {}
	cursor.set_process(false)
	_pre_move_cell = selected_unit.cell

	var blocked := _get_blocked_cells(selected_unit)
	current_path = Pathfinder.find_path(tile_map, selected_unit.cell, destination, selected_unit.move_table, blocked)

	range_drawer.clear_all(high_light_layer)
	selected_unit._animate_step(current_path, 0)
	selected_unit._end_move.connect(_on_move_complete)


##移动完成，弹出行动菜单（攻击可用性取决于范围内是否有敌人）
func _on_move_complete() -> void:
	selected_unit._end_move.disconnect(_on_move_complete)
	var destination := selected_unit.cell
	if not current_path.is_empty():
		destination = current_path[-1]
	_finish_move(destination)


##统一收尾：更新单位坐标、计算攻击范围、弹出行动菜单
func _finish_move(destination: Vector2i) -> void:
	selected_unit.cell = destination

	# 按已走路程的消耗更新再移动剩余力
	var used := 0
	for i in range(1, current_path.size()):
		var terrain := Pathfinder.get_terrain_name(tile_map, current_path[i])
		used += selected_unit.move_table.get(terrain, 1)
	selected_unit.canto_remaining = maxi(selected_unit.canto_remaining - used, 0)

	current_path = []
	move_range = {}

	# 从新位置计算攻击范围（攻击可用性由行动菜单弹出时判定）
	##P0-1：统一接口——背包所有可用武器射程并集
	attack_range = selected_unit.get_attack_range(tile_map, [selected_unit.cell])

	commands.show_action_menu()


##通用移动：播放移动动画，结束后更新格子坐标（玩家与敌方共用，增援走位也复用）
func _move_unit(unit: Unit, destination: Vector2i) -> void:
	var path := Pathfinder.find_path(tile_map, unit.cell, destination, unit.move_table, _get_blocked_cells(unit))
	if path.is_empty() or path.size() < 2:
		return
	unit._animate_step(path, 0)
	await unit._end_move
	unit.cell = path[-1]


##==================== 行动结束（P2 公开接口） ====================

##行动结束公开入口（P2）：子模块统一经此结束行动，不再调用 _end_action
##allow_canto=false 时跳过再移动（待机=主动放弃，测试问题3）
func end_action(allow_canto := true) -> void:
	_end_action(allow_canto)


##标记已执行不可撤销的子行动（对话/交换/开启宝箱后调用；此后行动菜单按 no 不再撤回移动）
func mark_action_spent() -> void:
	_menu_action_spent = true


##是否已执行不可撤销的子行动（行动菜单按 no 时判断撤回还是待机）
func is_action_spent() -> bool:
	return _menu_action_spent


##标记本次行动为攻击（_end_action 据此选择 Canto 触发等级，读取后自动清零）
func mark_attack_action() -> void:
	_last_action_was_attack = true


##行动收尾唯一出口（P2）：清空选中上下文/范围层/光标限制并回 CURSOR，
##再检查胜负与玩家回合是否结束；_end_action 与 BattleCanto._finish_canto 共用
func finalize_action() -> void:
	selected_unit = null
	move_range = {}
	attack_range = []
	current_path = []
	cursor.restrict_to = {}
	cursor.set_process(true)
	range_drawer.clear_all(high_light_layer)
	state = State.CURSOR
	if not battle_over:
		_check_battle_end()
		if not battle_over and phase == 0:
			phases.check_player_phase_end()


##行动结束（selected_unit 可能已死于反击被移除，需判空）
##若单位拥有再移动技能且有剩余力，根据行动类型（攻击/非攻击）判断是否进入 CANTO 阶段
##allow_canto=false 时跳过再移动（待机：测试问题3，选择待机=主动放弃再移动）
func _end_action(allow_canto := true) -> void:
	commands.hide_forecast()
	commands.reset_forecast_cache()
	if commands.action_menu != null:
		commands.action_menu.close()
	if selected_unit != null and is_instance_valid(selected_unit) and not selected_unit.is_queued_for_deletion():
		var was_attack := _last_action_was_attack
		_last_action_was_attack = false
		var can_canto := false
		if was_attack:
			can_canto = selected_unit.can_canto_after_attack()
		else:
			can_canto = selected_unit.can_canto_after_non_attack()
		if allow_canto and can_canto and selected_unit.canto_remaining > 0:
			canto.enter_phase()
			return
		selected_unit.has_acted = true
		selected_unit.apply_grayscale()
		selected_unit.play_idle_animation()
	finalize_action()


##==================== 撤回移动（P2 公开接口） ====================

##撤回移动：单位回到移动前位置并重新进入选中状态（行动菜单按 no 且未执行子行动时）
##坐标还原 + 重新选中（重算移动/攻击范围、重置子行动标记）收进 BM，外部不再触碰 _pre_move_cell / _select_unit
##调用方负责先关闭行动菜单
func undo_move() -> void:
	if selected_unit == null or not is_instance_valid(selected_unit) \
			or selected_unit.is_queued_for_deletion():
		return
	selected_unit.cell = _pre_move_cell
	selected_unit.global_position = Vector2(_pre_move_cell) * Global.TILE_SIZE
	_select_unit(selected_unit)


##==================== 对话入口（委托 interaction，保持原接口） ====================

##简单对话/系统提示（无肖像）：村庄宝箱发奖提示、事件对话用（action_dialogue 经此调用）
func open_dialogue(speaker: String, lines: Array[String]) -> void:
	await interaction.open_dialogue(speaker, lines)


##正式对话（5E 重构）：lines 每项 {"speaker","text","side"}，portraits 说话人->肖像，bg 背景CG
##DIALOGUE 状态阻塞输入，播完恢复原状态
func play_dialogue(lines: Array, portraits: Dictionary = {}, bg_texture: Texture2D = null) -> void:
	await interaction.play_dialogue(lines, portraits, bg_texture)


##==================== 帧更新 ====================

func _process(_delta: float) -> void:
	if state == State.UNIT_SELECTED and selected_unit != null:
		_update_path_preview()
	elif state == State.TARGET_SELECT and selected_unit != null:
		commands.update_forecast()


##UNIT_SELECTED 状态下实时刷新移动路径预览
func _update_path_preview() -> void:
	var cursor_cell: Vector2i = cursor.cell
	if cursor_cell == last_path_cursor or not move_range.has(cursor_cell):
		return
	if cursor_cell == selected_unit.cell:
		return

	last_path_cursor = cursor_cell
	var blocked := _get_blocked_cells(selected_unit)
	var new_path := Pathfinder.find_path(tile_map, selected_unit.cell, cursor_cell, selected_unit.move_table, blocked)

	range_drawer.clear_all(high_light_layer)
	range_drawer.draw_move_range(move_range, high_light_layer)
	range_drawer.draw_attack_range(attack_range, high_light_layer)
	range_drawer.draw_path(new_path, high_light_layer)
	current_path = new_path
