class_name BattleRescue
extends RefCounted

##救援/放下/交接/交换（自 battle_manager.gd 分包，阶段五 5F，FE8 规则）：
##行动菜单附加项探测、四邻接候选计算、RESCUE_SELECT 目标选择与各指令执行。
##交换（TRADE）的目标选择复用本类流程，界面打开/关闭在 BattleUnitCommands.do_trade。

enum Mode { RESCUE, DROP, GIVE, TRADE }

var bm: BattleManager
##救援选择的候选列表（RESCUE/GIVE/TRADE 为 Unit，DROP 为 Vector2i）与当前索引
var _mode: int = Mode.RESCUE
var _list: Array = []
var _index := 0


##行动菜单附加项探测：救援 → 放下 → 交接 → 交换（顺序与原实现一致）
func gather_menu_extras(unit: Unit) -> Array[String]:
	var extras: Array[String] = []
	if unit == null:
		return extras
	if not _rescue_candidates(unit).is_empty():
		extras.append("救援")
	if not _drop_cells(unit).is_empty():
		extras.append("放下")
	if not _give_candidates(unit).is_empty():
		extras.append("交接")
	if not _trade_candidates(unit).is_empty():
		extras.append("交换")
	return extras


##四邻接的可救友军列表（救援者未携带、目标同队且未被救/未携带、救援者 Aid ≥ 目标体格）
func _rescue_candidates(unit: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	if unit.carried_unit != null:
		return out
	for d in Global.directions:
		var other := bm.get_unit_at(unit.cell + d)
		if other == null or other == unit or other.team != unit.team:
			continue
		if unit.can_rescue(other):
			out.append(other)
	return out


##四邻接的可放置空格（放下）：被救单位可通行的地形且无单位占据
func _drop_cells(unit: Unit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if unit.carried_unit == null:
		return out
	for d in Global.directions:
		var c := unit.cell + d as Vector2i
		if bm.tile_map.get_cell_tile_data(c) == null:
			continue
		if unit.carried_unit.move_table.get(Pathfinder.get_terrain_name(bm.tile_map, c), 1) <= 0:
			continue
		if bm.get_unit_at(c) != null:
			continue
		out.append(c)
	return out


##四邻接的可交接友军（交接）：同队、未携带别人、Aid 足够救起当前被救单位
func _give_candidates(unit: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	if unit.carried_unit == null:
		return out
	for d in Global.directions:
		var other := bm.get_unit_at(unit.cell + d)
		if other == null or other == unit or other.team != unit.team:
			continue
		if other.carried_unit == null and other.get_aid() >= unit.carried_unit.con:
			out.append(other)
	return out


##四邻接的可交换友军（5F 交换）：同队、未被救起（脱离地图的单位不能交换）
func _trade_candidates(unit: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	for d in Global.directions:
		var other := bm.get_unit_at(unit.cell + d)
		if other == null or other == unit:
			continue
		if other.team != unit.team or other.carried_by != null:
			continue
		out.append(other)
	return out


##进入救援选择：候选只有一个时直接执行，多个时方向键循环选择（红色高亮候选）
func enter_select(mode: int) -> void:
	bm.commands.action_menu.close()
	_mode = mode
	_index = 0
	_list.clear()
	match mode:
		Mode.RESCUE:
			_list = _rescue_candidates(bm.selected_unit)
		Mode.DROP:
			_list = _drop_cells(bm.selected_unit)
		Mode.GIVE:
			_list = _give_candidates(bm.selected_unit)
		Mode.TRADE:
			_list = _trade_candidates(bm.selected_unit)
	if _list.is_empty():
		bm.commands.show_action_menu()
		return
	if _list.size() == 1:
		_confirm()
		return
	bm.state = BattleManager.State.RESCUE_SELECT
	bm.cursor.set_process(false)
	bm.cursor.restrict_to = {}
	bm.range_drawer.clear_all(bm.high_light_layer)
	##候选格红色高亮 + 光标跳到第一个候选
	var cells: Array = []
	for item in _list:
		cells.append(item.cell if item is Unit else item)
	bm.range_drawer.draw_attack_range(cells, bm.high_light_layer)
	_sync_cursor()


##救援选择输入：方向键循环候选，yes 确认，no 返回行动菜单
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_index = wrapi(_index - 1, 0, _list.size())
		_sync_cursor()
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_index = wrapi(_index + 1, 0, _list.size())
		_sync_cursor()
	elif event.is_action_pressed("yes"):
		_confirm()
	elif event.is_action_pressed("no"):
		bm.commands.show_action_menu()


##光标跳到当前候选（Unit 取其格子，DROP 直接是格子）
func _sync_cursor() -> void:
	var item = _list[_index]
	bm.cursor.set_cell(item.cell if item is Unit else item)


##确认候选并执行对应指令
func _confirm() -> void:
	var item = _list[_index]
	match _mode:
		Mode.RESCUE:
			_execute_rescue(item as Unit)
		Mode.DROP:
			_execute_drop(item as Vector2i)
		Mode.GIVE:
			_execute_give(item as Unit)
		Mode.TRADE:
			bm.commands.do_trade(item as Unit)


##执行救援：被救者脱离地图挂在救援者身上（隐藏 + 哨兵坐标，不可被选中/攻击/寻路）
##救援者的速度技巧惩罚（FE8 携带惩罚）暂未实现
func _execute_rescue(target: Unit) -> void:
	var rescuer := bm.selected_unit
	rescuer.carried_unit = target
	target.carried_by = rescuer
	##人物面板"救出"状态
	target.rescue = true
	target.visible = false
	target.cell = Unit.OFF_MAP_CELL
	bm.range_drawer.clear_all(bm.high_light_layer)
	print("%s 救起了 %s" % [rescuer.unit_name, target.unit_name])
	bm.end_action()


##执行放下：被救者放回相邻空格，本回合不能再行动（FE8：放下的单位当回合不可移动）
func _execute_drop(cell: Vector2i) -> void:
	var rescuer := bm.selected_unit
	var target := rescuer.carried_unit
	rescuer.carried_unit = null
	target.carried_by = null
	target.rescue = false
	target.cell = cell
	target.global_position = Vector2(cell) * Global.TILE_SIZE
	target.visible = true
	target.has_acted = true
	target.apply_grayscale()
	target.play_idle_animation()
	bm.range_drawer.clear_all(bm.high_light_layer)
	print("%s 放下了 %s" % [rescuer.unit_name, target.unit_name])
	bm.end_action()


##执行交接：把被救者转交给相邻友军（被救者保持脱离地图状态）
func _execute_give(receiver: Unit) -> void:
	var giver := bm.selected_unit
	var target := giver.carried_unit
	giver.carried_unit = null
	receiver.carried_unit = target
	target.carried_by = receiver
	bm.range_drawer.clear_all(bm.high_light_layer)
	print("%s 把 %s 交给了 %s" % [giver.unit_name, target.unit_name, receiver.unit_name])
	bm.end_action()
