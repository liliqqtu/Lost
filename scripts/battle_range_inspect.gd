class_name BattleRangeInspect
extends RefCounted

##敌人范围查看（自 battle_manager.gd 分包，测试问题2）：
##光标停在敌人上按 yes 显示该敌人移动范围（蓝）+最外围攻击范围（红），再按一次取消；
##按 start 显示全部敌人攻击范围并集（红，含各敌人可达位置的射程覆盖，不显示移动范围）；
##no 键关闭任何查看。

var bm: BattleManager
##查看中的单个敌人
var _inspect_enemy: Unit = null
##是否显示全部敌人攻击范围并集
var _all_range_shown := false


##光标停在敌人上按 yes：同一敌人再按一次取消，否则显示其范围
func toggle_single(enemy: Unit) -> void:
	if _inspect_enemy == enemy and not _all_range_shown:
		clear_display()
	else:
		_show_enemy_range(enemy)


##按 start：显示/关闭全部敌人的攻击范围并集（红色；不显示移动范围）
func toggle_all() -> void:
	if _all_range_shown:
		clear_display()
		return
	_inspect_enemy = null
	_all_range_shown = true
	var cells := {}
	for enemy in bm.units:
		if enemy.team != 1 or enemy.carried_by != null:
			continue
		var ranges := enemy.get_weapon_ranges()
		if ranges.is_empty():
			continue
		var blocked := bm.get_blocked_cells(enemy)
		var mv := Pathfinder.get_move_range(bm.tile_map, enemy.cell, enemy.move,
			enemy.move_table, blocked)
		##GBA 的敌人威胁区显示：移动范围 ∪ 攻击范围整片标红（不显示蓝色）
		for cell in mv.keys():
			cells[cell] = true
		##P0-1：统一接口——每个敌人用其背包所有可用武器射程并集
		for cell in enemy.get_attack_range(bm.tile_map, mv.keys()):
			cells[cell] = true
	bm.range_drawer.clear_all(bm.high_light_layer)
	bm.range_drawer.draw_attack_range(cells.keys(), bm.high_light_layer)


##显示单个敌人的范围：蓝色=移动范围，红色=最外围攻击范围（get_attack_range 已剔除移动范围内的格子）
func _show_enemy_range(enemy: Unit) -> void:
	_inspect_enemy = enemy
	_all_range_shown = false
	var blocked := bm.get_blocked_cells(enemy)
	var mv := Pathfinder.get_move_range(bm.tile_map, enemy.cell, enemy.move, enemy.move_table, blocked)
	##P0-1：统一接口——背包所有可用武器射程并集
	var atk := enemy.get_attack_range(bm.tile_map, mv.keys())
	bm.range_drawer.clear_all(bm.high_light_layer)
	bm.range_drawer.draw_move_range(mv, bm.high_light_layer)
	bm.range_drawer.draw_attack_range(atk, bm.high_light_layer)


##关闭敌人范围查看（单敌与并集共用）
func clear_display() -> void:
	if _inspect_enemy == null and not _all_range_shown:
		return
	_inspect_enemy = null
	_all_range_shown = false
	bm.range_drawer.clear_all(bm.high_light_layer)


##选中单位时复位查看状态（范围层由选中流程重绘，无需清层）
func reset() -> void:
	_inspect_enemy = null
	_all_range_shown = false
