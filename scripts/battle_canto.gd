class_name BattleCanto
extends RefCounted

##再移动（自 battle_manager.gd 分包，Canto，阶段五 5E 关联技能焕发）：
##攻击/非攻击行动结束后按技能触发等级与剩余移动力进入 CANTO_MOVING 状态。
##再移动不能攻击，移动流程与正常移动一致（寻路 + 步进动画 + 按地形消耗扣剩余力）。

var bm: BattleManager


##进入再移动阶段：用剩余力重算移动范围，攻击范围置空（再移动不能攻击）
func enter_phase() -> void:
	bm.state = BattleManager.State.CANTO_MOVING
	var blocked := bm.get_blocked_cells(bm.selected_unit)
	bm.move_range = Pathfinder.get_move_range(bm.tile_map, bm.selected_unit.cell,
		bm.selected_unit.canto_remaining, bm.selected_unit.move_table, blocked)
	bm.attack_range = []
	bm.cursor.set_cell(bm.selected_unit.cell)
	bm.cursor.restrict_to = bm.move_range
	bm.cursor.set_process(true)
	bm.last_path_cursor = bm.selected_unit.cell
	bm.current_path = [bm.selected_unit.cell]
	bm.range_drawer.clear_all(bm.high_light_layer)
	bm.range_drawer.draw_move_range(bm.move_range, bm.high_light_layer)
	print("%s 进入再移动阶段，剩余力 %d" % [bm.selected_unit.unit_name, bm.selected_unit.canto_remaining])


##CANTO_MOVING 状态输入：yes 移动到目标格，no 原地结束再移动
func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("yes"):
		var cursor_cell: Vector2i = bm.cursor.cell
		if not bm.move_range.has(cursor_cell):
			return
		if cursor_cell == bm.selected_unit.cell:
			_finish_canto(cursor_cell)
		else:
			_start_canto_move(cursor_cell)
	elif event.is_action_pressed("no"):
		_finish_canto(bm.selected_unit.cell)


##开始再移动（与正常移动一致，只是状态不同）
func _start_canto_move(destination: Vector2i) -> void:
	bm.cursor.restrict_to = {}
	bm.cursor.set_process(false)
	var blocked := bm.get_blocked_cells(bm.selected_unit)
	bm.current_path = Pathfinder.find_path(bm.tile_map, bm.selected_unit.cell, destination,
		bm.selected_unit.move_table, blocked)
	bm.range_drawer.clear_all(bm.high_light_layer)
	bm.selected_unit._animate_step(bm.current_path, 0)
	bm.selected_unit._end_move.connect(_on_canto_move_complete)


##再移动动画结束 → 更新坐标 + 扣剩余力 → 收尾
func _on_canto_move_complete() -> void:
	bm.selected_unit._end_move.disconnect(_on_canto_move_complete)
	var destination := bm.selected_unit.cell
	if not bm.current_path.is_empty():
		destination = bm.current_path[-1]
		var used := 0
		for i in range(1, bm.current_path.size()):
			var terrain := Pathfinder.get_terrain_name(bm.tile_map, bm.current_path[i])
			used += bm.selected_unit.move_table.get(terrain, 1)
		bm.selected_unit.canto_remaining = maxi(bm.selected_unit.canto_remaining - used, 0)
	_finish_canto(destination)


##再移动收尾：标记已行动 + 灰度 → 交 BM 统一收尾出口
##（P2：不再重复实现 _end_action 的清理尾巴与胜负/回合检查）
func _finish_canto(_destination: Vector2i) -> void:
	if bm.selected_unit != null and is_instance_valid(bm.selected_unit) and not bm.selected_unit.is_queued_for_deletion():
		bm.selected_unit.cell = _destination
		bm.selected_unit.has_acted = true
		bm.selected_unit.apply_grayscale()
		bm.selected_unit.play_idle_animation()
	bm.finalize_action()
