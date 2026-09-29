class_name BattleUnitCommands
extends RefCounted

##单位指令流程（自 battle_manager.gd 分包）：行动菜单弹出与附加项探测、攻击目标选择、
##战斗预览刷新、物品/运输队/交换面板的打开与关闭回调、菜单取消撤回移动。
##面板引用与菜单上下文状态归本类；地图、单位、光标等共享数据经 bm（BattleManager）读写。

var bm: BattleManager

##战斗预览面板（阶段二）
var forecast_panel: Node = null
var _forecast_cursor_cell := Vector2i(-9999, -9999)
##行动菜单（阶段四）
var action_menu: Node = null
##交换界面（5F）
var trade_menu: Node = null
##物品菜单（阶段五 5D）
var item_menu: Node = null
##运输队面板（阶段五 5C）
var convoy_panel: Node = null
##人物信息面板（阶段五 5B）
var unit_info_panel: Node = null
##攻击范围内是否有敌方单位（决定菜单"攻击"项是否可用）
var _menu_attack_ready := false
##行动菜单附加上下文项（5E：访问/开启/对话；5F：救援/放下/交接/交换），与菜单动态项一一对应
var _extra_actions: Array[String] = []
##目标选择阶段的可攻击目标列表与当前索引（方向键循环切换）
var _target_list: Array[Unit] = []
var _target_index := 0


##设置运输队面板（连接关闭信号，寄存武器后需重算攻击范围）
func set_convoy_panel(panel: Node) -> void:
	convoy_panel = panel
	if convoy_panel != null and convoy_panel.has_signal("closed"):
		convoy_panel.closed.connect(_on_convoy_closed)


##设置物品菜单（连接关闭/使用信号）
func set_item_menu(menu: Node) -> void:
	item_menu = menu
	if item_menu != null:
		if item_menu.has_signal("closed"):
			item_menu.closed.connect(_on_item_menu_closed)
		if item_menu.has_signal("item_used"):
			item_menu.item_used.connect(_on_item_used)


##设置交换界面（连接关闭信号）
func set_trade_menu(menu: Node) -> void:
	trade_menu = menu
	if trade_menu != null and trade_menu.has_signal("closed"):
		trade_menu.closed.connect(_on_trade_closed)


##显示行动菜单（5E：探测脚下瓦片村庄/宝箱 + 邻接对话目标；5A：攻击也作为动态附加项；5G：邻接支援目标）
##动态项顺序：攻击 → 访问 → 开启 → 对话 → 支援 → 救援 → 放下 → 交接 → 交换；固定项：物品 / 待机 / 运输队
##注意："攻击"由 _menu_attack_ready 单独传给 action_menu.open，不放进 extras
func show_action_menu() -> void:
	bm.state = BattleManager.State.ACTION_MENU
	bm.cursor.set_process(false)
	var has_convoy := bm.selected_unit != null and bm.selected_unit.has_convoy

	_menu_attack_ready = _has_enemy_in_attack_range()
	_extra_actions.clear()
	if _menu_attack_ready:
		_extra_actions.append("攻击")
	var extras: Array[String] = []
	extras.append_array(bm.interaction.gather_menu_extras(bm.selected_unit))
	extras.append_array(bm.rescue.gather_menu_extras(bm.selected_unit))
	_extra_actions.append_array(extras)

	action_menu.open(_menu_attack_ready, has_convoy, extras)
	action_menu.update_side(bm.selected_unit, bm.camera)


##处理行动菜单输入（阶段四）
func handle_action_menu_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		action_menu.move_selection(-1)
	elif event.is_action_pressed("ui_down"):
		action_menu.move_selection(1)
	elif event.is_action_pressed("yes"):
		_on_menu_confirmed(action_menu.get_selected())
	elif event.is_action_pressed("no"):
		if bm.is_action_spent():
			##对话/交换等子行动已完成，移动不可再撤回：no 直接待机（原版行为）
			action_menu.close()
			bm.end_action(false)
		else:
			_undo_move()


##菜单选项确认：0..N-1 动态附加项（攻击/访问/开启/对话/支援/救援/放下/交接/交换，顺序同 _extra_actions），其后为固定项
##动态项顺序由 show_action_menu 决定；固定项顺序：物品 / 待机 / 运输队
func _on_menu_confirmed(index: int) -> void:
	##动态附加项（索引 0..N-1）
	if index < _extra_actions.size():
		match _extra_actions[index]:
			"攻击":
				if _menu_attack_ready:
					_enter_target_select()
			"访问", "开启":
				bm.interaction.do_interaction()
			"对话":
				bm.interaction.do_talk()
			"支援":
				bm.interaction.do_support()
			"救援":
				bm.rescue.enter_select(BattleRescue.Mode.RESCUE)
			"放下":
				bm.rescue.enter_select(BattleRescue.Mode.DROP)
			"交接":
				bm.rescue.enter_select(BattleRescue.Mode.GIVE)
			"交换":
				bm.rescue.enter_select(BattleRescue.Mode.TRADE)
		return
	##固定项（索引 N 起：物品 / 待机 / 运输队）
	var static_idx := index - _extra_actions.size()
	match static_idx:
		0:
			##物品：打开物品菜单（使用消耗品 / 换装），空背包不打开
			if bm.selected_unit != null and item_menu != null \
					and not bm.selected_unit.inventory.is_empty():
				action_menu.close()
				item_menu.open(bm.selected_unit)
				item_menu.update_side(bm.selected_unit, bm.camera)
				bm.state = BattleManager.State.ITEM_MENU
				bm.cursor.set_process(false)
		1:
			##待机（测试问题3）：主动结束行动，不触发焕发再移动
			action_menu.close()
			bm.end_action(false)
		2:
			if bm.selected_unit != null and bm.selected_unit.has_convoy and convoy_panel != null:
				action_menu.close()
				convoy_panel.show_panel(bm.selected_unit)
				bm.state = BattleManager.State.CONVOY
				bm.cursor.set_process(false)


##取消行动：单位撤回移动前的位置，重新进入选中状态
##P2：坐标还原与重新选中收进 BM.undo_move，此处只负责关闭行动菜单
func _undo_move() -> void:
	action_menu.close()
	bm.undo_move()


##从行动菜单进入目标选择：显示攻击范围，收集敌方目标，光标跳到第一个目标
##光标自身移动关闭（改由方向键循环切换目标），攻击范围不连通时也能到达所有目标
func _enter_target_select() -> void:
	action_menu.close()
	bm.state = BattleManager.State.TARGET_SELECT
	bm.cursor.set_process(false)
	bm.range_drawer.clear_all(bm.high_light_layer)
	bm.range_drawer.draw_attack_range(bm.attack_range, bm.high_light_layer)
	bm.cursor.restrict_to = {}
	_forecast_cursor_cell = Vector2i(-9999, -9999)
	_target_list.clear()
	for cell in bm.attack_range:
		var unit := bm.get_unit_at(cell)
		if unit and unit.team != bm.selected_unit.team:
			_target_list.append(unit)
	_target_list.sort_custom(func(a: Unit, b: Unit): return a.cell < b.cell)
	_target_index = 0
	if not _target_list.is_empty():
		bm.cursor.set_cell(_target_list[0].cell)


##处理目标选择输入：方向键在攻击目标间循环切换，确认攻击，取消返回行动菜单
##不使用光标逐格移动——弓等武器攻击范围不连通（如仅距离2一圈），逐格移动无法跨过射程外空格
func handle_target_select_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_cycle_target(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_cycle_target(1)
	elif event.is_action_pressed("yes"):
		var cursor_cell: Vector2i = bm.cursor.cell
		if not bm.attack_range.has(cursor_cell):
			return
		var target := bm.get_unit_at(cursor_cell)
		if target and target.team != bm.selected_unit.team:
			hide_forecast()
			bm.mark_attack_action()
			await bm.combat.execute_attack(bm.selected_unit, target)
			bm.end_action()
	elif event.is_action_pressed("no"):
		##取消目标选择，返回行动菜单（单位保持已移动状态）
		hide_forecast()
		show_action_menu()


##循环切换攻击目标：索引回绕，光标直接跳到目标格
func _cycle_target(dir: int) -> void:
	if _target_list.is_empty():
		return
	_target_index = wrapi(_target_index + dir, 0, _target_list.size())
	bm.cursor.set_cell(_target_list[_target_index].cell)


##攻击范围内是否存在敌方单位（无武器时永远不可攻击——装备武器可能被寄存进运输队）
func _has_enemy_in_attack_range() -> bool:
	if bm.selected_unit == null or bm.selected_unit.current_weapon == null:
		return false
	for cell in bm.attack_range:
		var unit := bm.get_unit_at(cell)
		if unit and unit.team != bm.selected_unit.team:
			return true
	return false


##从运输队面板返回：重新显示行动菜单（运输队不消耗单位行动）
##寄存装备中的武器后射程/可用性已变，需重算（与 _on_item_menu_closed 同构）
func _on_convoy_closed() -> void:
	_after_submenu_closed()


##从物品菜单返回：换装可能改变武器射程，重算攻击范围与攻击可用性后回到行动菜单
func _on_item_menu_closed() -> void:
	_after_submenu_closed()


##从交换界面返回：装备中的武器可能已被换走，重算攻击范围与攻击可用性后回行动菜单
func _on_trade_closed() -> void:
	_after_submenu_closed()


##子面板（物品/运输队/交换）关闭的统一收尾：重算攻击范围 → 回行动菜单
##selected_unit 失效（如被反击击杀的兜底）则回光标状态
func _after_submenu_closed() -> void:
	if bm.selected_unit != null and is_instance_valid(bm.selected_unit):
		##P0-1：统一接口——背包所有可用武器射程并集
		bm.attack_range = bm.selected_unit.get_attack_range(bm.tile_map, [bm.selected_unit.cell])
		show_action_menu()
	else:
		bm.state = BattleManager.State.CURSOR
		bm.cursor.set_process(true)


##使用了消耗品：结束行动（非攻击行动，拥有焕发等技能的单位可再移动）
func _on_item_used() -> void:
	if item_menu != null:
		item_menu.close()
	bm.end_action()


##执行交换（5F）：打开交换界面（不结束行动，关闭后回行动菜单）
##目标选择复用救援选择的高亮/循环逻辑（多个邻接友军时先选目标）
func do_trade(target: Unit) -> void:
	bm.range_drawer.clear_all(bm.high_light_layer)
	action_menu.close()
	bm.mark_action_spent()
	if trade_menu == null:
		show_action_menu()
		return
	trade_menu.open(bm.selected_unit, target)
	bm.state = BattleManager.State.TRADE
	bm.cursor.set_process(false)


##TARGET_SELECT 状态下根据光标位置刷新战斗预览
func update_forecast() -> void:
	if forecast_panel == null:
		return
	var cursor_cell: Vector2i = bm.cursor.cell
	if cursor_cell == _forecast_cursor_cell:
		return
	_forecast_cursor_cell = cursor_cell

	if not bm.attack_range.has(cursor_cell):
		hide_forecast()
		return
	var target := bm.get_unit_at(cursor_cell)
	if target == null or target.team == bm.selected_unit.team:
		hide_forecast()
		return
	##units 传入以结算支援加成（支援对象 3 格内，5G）
	var sequence := BattleCalculator.generate_battle_sequence(bm.selected_unit, target, bm.tile_map, bm.units)
	forecast_panel.show_forecast(bm.selected_unit, sequence)
	forecast_panel.update_side(bm.selected_unit, bm.camera)


##隐藏预览面板
func hide_forecast() -> void:
	if forecast_panel == null:
		return
	forecast_panel.hide_forecast()


##清空预览刷新缓存（取消选中/结束行动时调用）
func reset_forecast_cache() -> void:
	_forecast_cursor_cell = Vector2i(-9999, -9999)


##==================== 人物信息面板（阶段五 5B） ====================

##处理人物信息面板输入：R/取消键关闭，左右键切页，上下键切换同队伍单位
func handle_unit_info_input(event: InputEvent) -> void:
	if event.is_action_pressed("R") or event.is_action_pressed("no"):
		unit_info_panel.hide_panel()
		bm.state = BattleManager.State.CURSOR
		bm.cursor.set_process(true)
	elif event.is_action_pressed("ui_left"):
		unit_info_panel.cycle_page(-1)
	elif event.is_action_pressed("ui_right"):
		unit_info_panel.cycle_page(1)
	elif event.is_action_pressed("ui_up"):
		_cycle_info_unit(-1)
	elif event.is_action_pressed("ui_down"):
		_cycle_info_unit(1)


##人物面板上下键：在同队伍单位间循环切换（按格子坐标排序，索引回绕）
func _cycle_info_unit(dir: int) -> void:
	var panel_unit: Unit = unit_info_panel.current_unit
	if panel_unit == null:
		return
	var same_team: Array[Unit] = []
	for unit in bm.units:
		if unit.team == panel_unit.team:
			same_team.append(unit)
	if same_team.size() < 2:
		return
	same_team.sort_custom(func(a: Unit, b: Unit): return a.cell < b.cell)
	var index := same_team.find(panel_unit)
	var next_index := wrapi(index + dir, 0, same_team.size())
	unit_info_panel.show_panel(same_team[next_index], true)
