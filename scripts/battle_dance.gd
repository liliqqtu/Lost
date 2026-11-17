class_name BattleDance
extends RefCounted

## 舞者与吟游诗人行动管理（跳舞 / 奏乐）：
## 探测邻接四格内已行动完毕的友方单位、目标选择、战斗动画/激励再动结算。
## 与 BattleRescue / BattleStaff 同构，经 bm（BattleManager）读写共享状态。

var bm: BattleManager

var _target_list: Array[Unit] = []
var _target_index := 0
var _is_dance_selecting := false
var _action_label := "跳舞"


## 判断单位是否为舞者或吟游诗人（或具备相应技能）
func can_dance_or_play(unit: Unit) -> bool:
	if unit == null:
		return false
	if unit.class_data != null:
		var jn := unit.class_data.job_name.to_lower()
		if "舞者" in jn or "dancer" in jn or "诗人" in jn or "bard" in jn:
			return true
	for s in unit.get_all_active_skills():
		if s != null and (s.skill_id == &"dance" or s.skill_id == &"play"):
			return true
	return false


## 获取行动菜单显示的动词（诗人为"奏乐"，舞者为"跳舞"）
func get_action_label(unit: Unit) -> String:
	if unit != null and unit.class_data != null:
		var jn := unit.class_data.job_name.to_lower()
		if "诗人" in jn or "bard" in jn:
			return "奏乐"
	return "跳舞"


## 探测行动菜单附加项：若为舞者/诗人且四邻接有已行动友军，显示对应动词
func gather_menu_extras(unit: Unit) -> Array[String]:
	var extras: Array[String] = []
	if not can_dance_or_play(unit):
		return extras
	var targets := get_dance_targets(unit)
	if not targets.is_empty():
		extras.append(get_action_label(unit))
	return extras


## 获取四邻接内所有已完成行动（has_acted == true）的友军
func get_dance_targets(unit: Unit) -> Array[Unit]:
	var targets: Array[Unit] = []
	if unit == null:
		return targets
	for d in Global.directions:
		var other := bm.get_unit_at(unit.cell + d)
		if other == null or other == unit or other.team != unit.team:
			continue
		if other.carried_by != null:
			continue
		# 必须是已行动过的友军才能被跳舞再动
		if other.has_acted:
			targets.append(other)
	targets.sort_custom(func(a: Unit, b: Unit): return a.cell < b.cell)
	return targets


## 进入跳舞/奏乐目标选择
func enter_select(unit: Unit) -> void:
	_target_list = get_dance_targets(unit)
	if _target_list.is_empty():
		return
	_action_label = get_action_label(unit)
	bm.commands.action_menu.close()
	_is_dance_selecting = true
	_target_index = 0
	bm.state = BattleManager.State.TARGET_SELECT
	bm.cursor.set_process(false)

	# 绘制邻接高亮格
	bm.range_drawer.clear_all(bm.high_light_layer)
	var cells: Array = []
	for d in Global.directions:
		var c := unit.cell + d as Vector2i
		if bm.tile_map != null and bm.tile_map.get_cell_tile_data(c) != null:
			cells.append(c)
	bm.range_drawer.draw_attack_range(cells, bm.high_light_layer)

	# 光标聚焦首个目标
	bm.cursor.set_cell(_target_list[0].cell)


## 处理跳舞/奏乐目标选择输入
func handle_input(event: InputEvent) -> void:
	if not _is_dance_selecting:
		return
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_cycle_target(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_cycle_target(1)
	elif event.is_action_pressed("yes"):
		_confirm_dance()
	elif event.is_action_pressed("no"):
		_cancel_select()


## 循环切换目标
func _cycle_target(dir: int) -> void:
	if _target_list.is_empty():
		return
	_target_index = wrapi(_target_index + dir, 0, _target_list.size())
	bm.cursor.set_cell(_target_list[_target_index].cell)


## 确认执行跳舞/奏乐
func _confirm_dance() -> void:
	if _target_list.is_empty():
		return
	var dancer := bm.selected_unit
	var target := _target_list[_target_index]
	_is_dance_selecting = false
	bm.range_drawer.clear_all(bm.high_light_layer)

	print("=== %s 发动 ===" % _action_label)
	print("%s 为 %s 献上 %s，唤醒同伴重新行动！" % [dancer.unit_name, target.unit_name, _action_label])

	var prev_state := bm.state
	bm.state = BattleManager.State.BATTLE_ANIM

	# 1. 播放跳舞战斗动画演出
	if bm.combat.battle_scene != null and bm.combat.battle_scene.has_method("play_dance_refresh"):
		await bm.combat.battle_scene.play_dance_refresh(dancer, target, _action_label)
	else:
		# 无战斗特写兜底：短暂停留
		await bm.get_tree().create_timer(0.4).timeout

	# 2. 核心规则：恢复目标行动状态并解除灰色
	target.has_acted = false
	target.remove_grayscale()
	target.play_idle_animation()
	target.relentless_advance_triggered_this_turn = false

	# 3. 舞者/诗人获得固定 10 点经验值（FE8 原版规则）
	if dancer.team == 0 and dancer.lv < Unit.LEVEL_CAP:
		var exp_gain := 10
		await bm.combat.award_exp(dancer, exp_gain)

	# 4. 关闭特写并收尾行动
	if bm.combat.battle_scene != null and bm.combat.battle_scene.visible:
		await bm.combat.battle_scene.close()

	bm.state = prev_state
	bm.end_action(false)


## 取消选择：返回行动菜单
func _cancel_select() -> void:
	_is_dance_selecting = false
	bm.range_drawer.clear_all(bm.high_light_layer)
	bm.commands.show_action_menu()
