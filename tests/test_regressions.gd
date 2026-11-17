extends "res://tests/test_case.gd"

const FIXTURES = preload("res://tests/test_campaign_save.gd")
var failures := 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _ready() -> void:
	var level: Level = load("res://scene/level/level_1/level_1.tscn").instantiate()
	level.set_script(FIXTURES.QuietChapter)
	add_child(level)
	var bm := level.battle_manager
	var te: Unit = level.get_node("Units/Te")
	var vera: Unit = level.get_node("Units/Vera")
	te.cell = Vector2i(5, 5)
	vera.cell = Vector2i(5, 6)
	vera.team = 0
	vera.lv = Unit.LEVEL_CAP
	te.hp = te.max_hp - 10
	bm.selected_unit = vera
	bm.state = BattleManager.State.TARGET_SELECT
	bm.staff_mgr.current_staff = vera.current_weapon
	bm.staff_mgr._target_list = [te]
	var durability := vera.current_weapon.durability
	bm.staff_mgr._update_heal_forecast()
	check(bm.commands.forecast_panel.visible, "real healing forecast accepts typed sequence")
	await bm.staff_mgr._confirm_heal()
	check(te.hp == te.max_hp and vera.current_weapon.durability == durability - 1, "real animated staff action heals HP and consumes one use")
	var battle_view := bm.combat.battle_scene
	bm.combat.battle_scene = null
	te.hp -= 10
	bm.selected_unit = vera
	bm.staff_mgr._target_list = [te]
	await bm.staff_mgr._confirm_heal()
	check(te.hp == te.max_hp, "headless staff action matches animated action")
	var learner := Unit.new()
	add_child(learner)
	learner.lv = 1
	learner.exp = 95
	await bm.combat.award_exp(learner, 15)
	check(learner.lv == 2 and learner.exp == 10, "XP advances levels without animation scene")
	learner.free()
	var attacker := Unit.new()
	add_child(attacker)
	var defender := Unit.new()
	add_child(defender)
	attacker.team = 1
	defender.team = 2
	attacker.cell = Vector2i(5, 5)
	defender.cell = Vector2i(5, 6)
	attacker.spd = 20
	attacker.str = 10
	defender.spd = 0
	defender.def_h = 0
	defender.hp = 200
	var sword := Weapon.new()
	sword.durability = 1
	sword.might = 0
	sword.weight = 0
	sword.hit = 1000
	attacker.add_item(sword)
	attacker.equip_item(sword)
	var sequence := BattleCalculator.generate_battle_sequence(attacker, defender, bm.tile_map, bm.units)
	check(sequence.size() == 1, "forecast limits strikes to available durability")
	var expected_damage: int = sequence[0].damage
	await bm.combat.execute_attack(attacker, defender)
	check(defender.hp == 200 - expected_damage and attacker.current_weapon == null, "broken weapon stops follow-up damage")
	var staff := Weapon.new()
	staff.weapon_type = Weapon.WeaponType.STAFF
	defender.add_item(staff)
	defender.equip_item(staff)
	check(not BattleCalculator.can_counter(attacker, defender) and defender.get_weapon_ranges().is_empty(), "staff cannot counter or contribute threat range")
	defender.team = 0
	attacker.team = 2
	check(not BattleCalculator.is_hostile(attacker, defender) and BattleCalculator.generate_battle_sequence(attacker, defender).is_empty(), "blue and green units are allied")
	sword = Weapon.new()
	attacker.add_item(sword)
	attacker.equip_item(sword)
	attacker.team = 1
	attacker.move = 0
	defender.cell = Vector2i(5, 7)
	var bow := Weapon.new()
	bow.weapon_type = Weapon.WeaponType.BOW
	bow.min_range = 2
	bow.max_range = 2
	attacker.add_item(bow)
	var plan := EnemyAI.decide(attacker, [attacker, defender], bm.tile_map)
	check(plan.target == defender and plan.weapon == bow and attacker.current_weapon == sword, "AI returns matching weapon without mutating live equipment")
	check(not BattleCalculator.can_attack(attacker, defender), "melee attack cannot execute at range two")
	attacker.free()
	defender.free()
	var owned := Unit.new()
	add_child(owned)
	sword = Weapon.new()
	owned.add_item(sword)
	owned.equip_item(sword)
	owned._own_inventory()
	check(owned.inventory.has(owned.current_weapon) and owned.current_weapon != sword, "ownership cloning rebinds equipment")
	owned.free()
	bm.selected_unit = vera
	bm.commands.show_action_menu()
	var menu = bm.commands.action_menu
	menu._selected = menu._visible_labels().find(menu._labels[3])
	check(menu.get_selected() == bm.commands._extra_actions.size() + 3, "hiding convoy keeps save menu command mapped correctly")
	menu.close()
	bm.combat.battle_scene = battle_view
	# 再移动执行时，重复确认与取消都必须被阻断。
	bm.selected_unit = te
	te.canto_remaining = 2
	bm.canto.enter_phase()
	var destination := te.cell
	for cell in bm.move_range:
		if cell != te.cell:
			destination = cell
			break
	check(destination != te.cell, "canto regression has a reachable destination")
	bm.canto._start_canto_move(destination)
	bm.canto._start_canto_move(destination)
	var cancel := InputEventAction.new()
	cancel.action = "no"
	cancel.pressed = true
	bm.canto.handle_input(cancel)
	check(bm.selected_unit == te and bm.canto._moving, "canto animation ignores duplicate commands and cancel")
	await te._end_move
	check(te.cell == destination and not bm.canto._moving, "canto finishes exactly once")
	var carrier: Unit = level.get_node("Units/Isar")
	carrier.carried_unit = te
	te.carried_by = carrier
	te.visible = false
	te.cell = Unit.OFF_MAP_CELL
	var released_cell := carrier.cell
	bm.state = BattleManager.State.BATTLE_ANIM
	bm.remove_unit(carrier)
	check(te.carried_by == null and te.visible and te.cell == released_cell and bm.units.has(te), "carrier death releases surviving passenger")
	# 真正发出败北信号，验证界面订阅和输入入口，而不是只测布尔标记。
	bm.state = BattleManager.State.CURSOR
	for unit in bm.units.duplicate():
		if unit.team == 0:
			bm.remove_unit(unit)
	check(bm.battle_over and level.system_ui._defeat_dialog and level.system_ui._confirm_dialog.visible, "defeat opens retry/title dialog")
	level.queue_free()
	await get_tree().process_frame
	print("REGRESSION FAILURES: ", failures)
	quit(1 if failures else 0)
