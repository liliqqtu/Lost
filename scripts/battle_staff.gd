class_name BattleStaff
extends RefCounted

## 法杖行动管理（治愈/状态法杖）：
## 探测背包内可用法杖与射程内需救治友军、目标选择高亮与循环、战斗动画/治愈结算。
## 与 BattleRescue / BattleMapInteraction 同构，经 bm（BattleManager）读写共享状态。

var bm: BattleManager

## 当前选用的法杖
var current_staff: Weapon = null
## 目标候选列表与当前索引
var _target_list: Array[Unit] = []
var _target_index := 0
var _is_staff_selecting := false


## 探测行动菜单附加项：若持有可用法杖且射程内有受伤友军，显示"杖"
func gather_menu_extras(unit: Unit) -> Array[String]:
	var extras: Array[String] = []
	if unit == null or unit.inventory.is_empty():
		return extras
	var staff := get_first_usable_staff(unit)
	if staff == null:
		return extras
	var targets := get_heal_targets(unit, staff)
	if not targets.is_empty():
		extras.append("杖")
	return extras


## 获取单位背包中第一个可用的法杖（优先使用已装备的法杖）
func get_first_usable_staff(unit: Unit) -> Weapon:
	if unit == null:
		return null
	if _is_healing_staff(unit.current_weapon) and unit.can_equip(unit.current_weapon):
		return unit.current_weapon
	for item in unit.inventory:
		var w := item as Weapon
		if _is_healing_staff(w) and unit.can_equip(w):
			return w
	return null


## 未接入效果的传送/状态杖仅作为物品持有，不能误入治疗流程。
## 旧资源没有 effect_id 时维持原有治疗行为。
func _is_healing_staff(staff: Weapon) -> bool:
	return staff != null and staff.weapon_type == Weapon.WeaponType.STAFF \
		and staff.durability > 0 and (staff.effect_id == &"" or staff.effect_implemented)


## 获取法杖射程内所有需救治的友方单位（hp < max_hp）
func get_heal_targets(unit: Unit, staff: Weapon) -> Array[Unit]:
	var targets: Array[Unit] = []
	if unit == null or not _is_healing_staff(staff):
		return targets
	var min_r := staff.min_range
	var max_r := staff.max_range
	for other in bm.units:
		if not is_instance_valid(other) or other == unit or other.team != unit.team:
			continue
		if other.carried_by != null or other.hp >= other.max_hp:
			continue
		var dist := absi(unit.cell.x - other.cell.x) + absi(unit.cell.y - other.cell.y)
		if dist >= min_r and dist <= max_r:
			targets.append(other)
	targets.sort_custom(func(a: Unit, b: Unit): return a.cell < b.cell)
	return targets


## 计算法杖射程在地图上的瓦片集合
func get_staff_range_cells(unit: Unit, staff: Weapon) -> Array:
	var cells: Array = []
	if unit == null or staff == null:
		return cells
	var min_r := staff.min_range
	var max_r := staff.max_range
	for x in range(-max_r, max_r + 1):
		for y in range(-max_r, max_r + 1):
			var dist := absi(x) + absi(y)
			if dist >= min_r and dist <= max_r:
				var c := unit.cell + Vector2i(x, y)
				if bm.tile_map != null and bm.tile_map.get_cell_tile_data(c) != null:
					cells.append(c)
	return cells


## 进入法杖目标选择
func enter_select(unit: Unit) -> void:
	current_staff = get_first_usable_staff(unit)
	if current_staff == null:
		return
	unit.equip_item(current_staff)
	_target_list = get_heal_targets(unit, current_staff)
	if _target_list.is_empty():
		return

	bm.commands.action_menu.close()
	_is_staff_selecting = true
	_target_index = 0
	bm.state = BattleManager.State.TARGET_SELECT
	bm.cursor.set_process(false)

	# 绘制绿色/高亮治疗射程
	bm.range_drawer.clear_all(bm.high_light_layer)
	var range_cells := get_staff_range_cells(unit, current_staff)
	bm.range_drawer.draw_attack_range(range_cells, bm.high_light_layer)

	# 光标跳到首个目标
	bm.cursor.set_cell(_target_list[0].cell)
	_update_heal_forecast()


## 处理法杖目标选择输入
func handle_input(event: InputEvent) -> void:
	if not _is_staff_selecting:
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_cycle_target(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_cycle_target(1)
	elif event.is_action_pressed("yes"):
		_confirm_heal()
	elif event.is_action_pressed("no"):
		_cancel_select()


## 循环切换治疗目标
func _cycle_target(dir: int) -> void:
	if _target_list.is_empty():
		return
	_target_index = wrapi(_target_index + dir, 0, _target_list.size())
	bm.cursor.set_cell(_target_list[_target_index].cell)
	_update_heal_forecast()


## 刷新治疗预估面板
func _update_heal_forecast() -> void:
	if _target_list.is_empty() or bm.commands.forecast_panel == null:
		return
	var target := _target_list[_target_index]
	var caster := bm.selected_unit
	var heal_val := calculate_heal_amount(caster, current_staff)
	# 构造虚拟单一结算序列用于展示
	var dummy_sequence: Array[Dictionary] = [{
		"attacker": caster,
		"defender": target,
		"hit": 100,
		"damage": heal_val,
		"crit": 0,
		"is_counter": false,
		"is_double": false
	}]
	bm.commands.forecast_panel.show_forecast(caster, dummy_sequence)
	bm.commands.forecast_panel.update_side(caster, bm.camera)


## 计算治愈量：staff.might + caster.mag
func calculate_heal_amount(caster: Unit, staff: Weapon) -> int:
	var base := staff.might if staff != null else 10
	var mag := caster.get_effective_mag(bm.units) if caster != null else 0
	return base + mag


## 确认执行治愈
func _confirm_heal() -> void:
	if _target_list.is_empty():
		return
	var caster := bm.selected_unit
	var target := _target_list[_target_index]
	_is_staff_selecting = false
	bm.commands.hide_forecast()
	bm.range_drawer.clear_all(bm.high_light_layer)
	await execute_heal(caster, target, current_staff)
	bm.end_action(false)

## 玩家与 AI 共用治疗结算，AI 不进入玩家的行动菜单或再移动输入。
func execute_heal(caster: Unit, target: Unit, staff: Weapon) -> void:
	if staff == null or staff.durability <= 0 or not caster.equip_item(staff):
		return
	var heal_val := calculate_heal_amount(caster, staff)
	var actual_heal := mini(target.max_hp - target.hp, heal_val)

	print("=== 法杖发动 ===")
	print("%s 对 %s 使用 %s，预估治愈 %d (实际 +%d HP)" % [
		caster.unit_name, target.unit_name, staff.display_name, heal_val, actual_heal
	])

	var prev_state := bm.state
	bm.state = BattleManager.State.BATTLE_ANIM

	# 1. 播放战斗特写或治愈特效
	if bm.combat.battle_scene != null and bm.combat.battle_scene.has_method("play_staff_heal"):
		await bm.combat.battle_scene.play_staff_heal(caster, target, staff, actual_heal)
	else:
		# 无战斗特写兜底：短暂停留并刷新血量
		await bm.get_tree().create_timer(0.4).timeout

	# 真实血量统一结算，演出只负责显示。
	target.hp += actual_heal
	target.update_hp_bar()

	# 2. 扣除法杖耐久并增加武器熟练度
	caster.consume_weapon_durability()
	caster.gain_weapon_exp(staff)

	# 3. 施法者获得经验值（FE 经验公式：基础 10 + 治愈量的一半，单次 10~35 经验）
	if caster.team == 0 and caster.lv < Unit.LEVEL_CAP:
		var exp_gain := clampi(10 + int(actual_heal * 0.5), 10, 35)
		await bm.combat.award_exp(caster, exp_gain)

	# 4. 关闭特写并收尾行动
	if bm.combat.battle_scene != null and bm.combat.battle_scene.visible:
		await bm.combat.battle_scene.close()

	bm.state = prev_state


## 取消目标选择：返回行动菜单
func _cancel_select() -> void:
	_is_staff_selecting = false
	bm.commands.hide_forecast()
	bm.range_drawer.clear_all(bm.high_light_layer)
	bm.commands.show_action_menu()
