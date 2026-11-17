extends RefCounted

## 移动选择、寻路、动画和落点收尾。门面保留旧接口。
var bm

func _handle_unit_selected_input(event: InputEvent) -> void:
	if event.is_action_pressed("yes"):
		var cursor_cell: Vector2i = bm.cursor.cell
		if not bm.move_range.has(cursor_cell) or not Pathfinder.can_stop_at(bm.selected_unit, cursor_cell, bm.units):
			return
		bm._pre_move_cell = bm.selected_unit.cell
		if cursor_cell == bm.selected_unit.cell:
			##原地选择：不播放移动动画，直接进入行动菜单
			_finish_move(cursor_cell)
		else:
			_start_move(cursor_cell)
	elif event.is_action_pressed("no"):
		_cancel_selection()


func _select_unit(unit: Unit) -> void:
	bm.selected_unit = unit
	bm.state = BattleManager.State.UNIT_SELECTED
	bm.cursor.set_process(true)
	##选中单位会重绘范围层，敌人范围查看状态一并复位；子行动标记重置
	bm.range_inspect.reset()
	bm._menu_action_spent = false

	bm.selected_unit.play_selected_animation()

	var blocked = bm._get_blocked_cells(unit)
	bm.move_range = Pathfinder.get_move_range(bm.tile_map, unit.cell, unit.get_effective_move(bm.units), unit.move_table, blocked)

	##P0-1：攻击范围统一为背包所有可用武器射程并集（含技能修正），不再仅看 current_weapon
	bm.attack_range = unit.get_attack_range(bm.tile_map, Pathfinder.get_stopping_cells(unit, bm.move_range.keys(), bm.units))

	bm.cursor.set_cell(unit.cell)
	bm.cursor.restrict_to = bm.move_range
	bm.last_path_cursor = unit.cell

	bm.range_drawer.clear_all(bm.high_light_layer)
	bm.range_drawer.draw_move_range(bm.move_range, bm.high_light_layer)
	bm.range_drawer.draw_attack_range(bm.attack_range, bm.high_light_layer)
	bm.current_path = [unit.cell]
	## 记录本回合可用于再移动的剩余力（移动开始前=满 MP）
	unit.canto_remaining = unit.get_effective_move(bm.units)


func _cancel_selection() -> void:
	bm.selected_unit.play_idle_animation()
	bm.selected_unit = null
	bm.move_range = {}
	bm.attack_range = []
	bm.current_path = []
	bm.last_path_cursor = Vector2i.ZERO
	bm.commands.reset_forecast_cache()
	bm.cursor.restrict_to = {}
	bm.range_drawer.clear_all(bm.high_light_layer)
	bm.state = BattleManager.State.CURSOR


func _start_move(destination: Vector2i) -> void:
	bm.state = BattleManager.State.MOVING
	bm.cursor.restrict_to = {}
	bm.cursor.set_process(false)
	bm._pre_move_cell = bm.selected_unit.cell

	var blocked = bm._get_blocked_cells(bm.selected_unit)
	bm.current_path = Pathfinder.find_path(bm.tile_map, bm.selected_unit.cell, destination, bm.selected_unit.move_table, blocked)

	bm.range_drawer.clear_all(bm.high_light_layer)
	bm.selected_unit._end_move.connect(_on_move_complete)
	bm.selected_unit._animate_step(bm.current_path, 0)


func _on_move_complete() -> void:
	bm.selected_unit._end_move.disconnect(_on_move_complete)
	var destination = bm.selected_unit.cell
	if not bm.current_path.is_empty():
		destination = bm.current_path[-1]
	_finish_move(destination)


func _finish_move(destination: Vector2i) -> void:
	bm.selected_unit.cell = destination

	# 按已走路程的消耗更新再移动剩余力
	var used = 0
	for i in range(1, bm.current_path.size()):
		var terrain = Pathfinder.get_terrain_name(bm.tile_map, bm.current_path[i])
		used += bm.selected_unit.move_table.get(terrain, 1)
	bm.selected_unit.canto_remaining = maxi(bm.selected_unit.canto_remaining - used, 0)

	bm.current_path = []
	bm.move_range = {}

	# 从新位置计算攻击范围（攻击可用性由行动菜单弹出时判定）
	##P0-1：统一接口——背包所有可用武器射程并集
	bm.attack_range = bm.selected_unit.get_attack_range(bm.tile_map, [bm.selected_unit.cell])

	bm.commands.show_action_menu()


func _move_unit(unit: Unit, destination: Vector2i) -> void:
	if not Pathfinder.can_stop_at(unit, destination, bm.units):
		return
	var path = Pathfinder.find_path(bm.tile_map, unit.cell, destination, unit.move_table, bm._get_blocked_cells(unit))
	if path.is_empty() or path.size() < 2:
		return
	unit._animate_step(path, 0)
	await unit._end_move
	unit.cell = path[-1]


func _update_path_preview() -> void:
	var cursor_cell: Vector2i = bm.cursor.cell
	if cursor_cell == bm.last_path_cursor or not bm.move_range.has(cursor_cell):
		return
	if cursor_cell == bm.selected_unit.cell:
		return

	bm.last_path_cursor = cursor_cell
	var blocked = bm._get_blocked_cells(bm.selected_unit)
	var new_path = Pathfinder.find_path(bm.tile_map, bm.selected_unit.cell, cursor_cell, bm.selected_unit.move_table, blocked)

	bm.range_drawer.clear_all(bm.high_light_layer)
	bm.range_drawer.draw_move_range(bm.move_range, bm.high_light_layer)
	bm.range_drawer.draw_attack_range(bm.attack_range, bm.high_light_layer)
	bm.range_drawer.draw_path(new_path, bm.high_light_layer)
	bm.current_path = new_path
