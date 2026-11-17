extends "res://tests/test_case.gd"

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _ready() -> void:
	var bm := BattleManager.new()
	bm.tile_map = _map()
	bm.high_light_layer = _map()
	bm.cursor = load("res://scene/ui/cursor.gd").new()
	add_child(bm.cursor)
	add_child(bm)
	var player := _unit(0, 0)
	var healer := _unit(2, 1)
	var fighter := _unit(2, 2)
	var blocker := _unit(2, 3)
	var enemy := _unit(1, 5)
	bm.units.assign([player, healer, fighter, blocker, enemy])
	player.move = 4
	fighter.move = 2
	blocker.move = 0
	enemy.move = 0
	enemy.hp = 200
	enemy.max_hp = 200
	var sword := Weapon.new()
	sword.hit = 1000
	sword.weight = 0
	fighter.add_item(sword)
	fighter.equip_item(sword)
	var staff := Weapon.new()
	staff.weapon_type = Weapon.WeaponType.STAFF
	staff.might = 10
	healer.add_item(staff)
	healer.equip_item(staff)
	var blocked := bm.get_blocked_cells(player)
	var moves := Pathfinder.get_move_range(bm.tile_map, player.cell, 4, player.move_table, blocked)
	check(moves.has(Vector2i(4, 0)), "blue unit can cross a corridor occupied by green allies")
	check(not moves.has(enemy.cell), "hostile unit still blocks passage")
	var path := Pathfinder.find_path(bm.tile_map, player.cell, Vector2i(4, 0), player.move_table, blocked)
	check(path.has(healer.cell) and path.has(blocker.cell), "actual movement path passes through allies")
	healer.team = 0
	check(not bm.get_blocked_cells(player).has(healer.cell), "same-team blue unit permits passage")
	healer.team = 2
	check(not Pathfinder.can_stop_at(player, healer.cell, bm.units), "occupied friendly cell cannot be a destination")
	bm.movement._select_unit(player)
	bm.cursor.set_cell(healer.cell)
	var yes := InputEventAction.new()
	yes.action = "yes"
	yes.pressed = true
	bm.movement._handle_unit_selected_input(yes)
	check(bm.state == BattleManager.State.UNIT_SELECTED and player.cell == Vector2i.ZERO, "normal move rejects occupied friendly destination")
	bm.canto.enter_phase()
	bm.cursor.set_cell(healer.cell)
	bm.canto.handle_input(yes)
	check(bm.state == BattleManager.State.CANTO_MOVING and not bm.canto._moving, "canto also rejects occupied friendly destination")
	bm.movement._cancel_selection()
	var plan := EnemyAI.decide(fighter, bm.units, bm.tile_map)
	check(plan.move_to == Vector2i(4, 0) and plan.target == enemy, "green AI crosses same-team blocker to attack enemy")
	player.hp = 5
	var heal_plan := EnemyAI.decide(healer, bm.units, bm.tile_map)
	check(heal_plan.get("action") == "heal" and heal_plan.target == player, "green healer targets wounded blue ally")
	var phases: Array = []
	var locked: Array = []
	bm.turn_started.connect(func(team):
		phases.append(team)
		locked.append(not bm.cursor.is_processing()))
	enemy.has_acted = true
	player.has_acted = true
	var old_turn := bm.turn
	await bm.phases.start_enemy_phase()
	check(phases == [1, 2, 0], "complete phase cycle is enemy, green ally, player")
	check(not locked.has(false), "cursor input stays locked during all phase banners")
	check(fighter.cell == Vector2i(4, 0) and enemy.hp < 200, "green phase executes real movement and combat")
	check(player.hp == 15 and staff.durability == 39, "green phase executes real healing and durability cost")
	check(bm.turn == old_turn + 1 and bm.phase == 0 and bm.state == BattleManager.State.CURSOR, "one full round increments turn once and returns player control")
	check(not fighter.has_acted and not healer.has_acted, "next round resets action flags")
	# Recruited units no longer receive green AI actions or a green phase banner.
	for unit in [healer, fighter, blocker]:
		unit.team = 0
	enemy.has_acted = true
	phases.clear()
	await bm.phases.start_enemy_phase()
	check(phases == [1, 0], "green phase is skipped when all green units have been recruited")
	print("ALLIED TURN FAILURES: ", failures)
	quit(1 if failures else 0)

func _unit(team: int, x: int) -> Unit:
	var unit: Unit = load("res://scene/character/unit.tscn").instantiate()
	unit.team = team
	unit.cell = Vector2i(x, 0)
	unit.position = Vector2(unit.cell) * Global.TILE_SIZE
	unit.lv = Unit.LEVEL_CAP
	add_child(unit)
	return unit

func _map() -> TileMapLayer:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0, "Name")
	tiles.set_custom_data_layer_type(0, TYPE_STRING)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create_empty(16, 16, false, Image.FORMAT_RGBA8))
	tiles.add_source(source, 0)
	source.create_tile(Vector2i.ZERO)
	source.get_tile_data(Vector2i.ZERO, 0).set_custom_data("Name", "道路")
	var map := TileMapLayer.new()
	map.tile_set = tiles
	add_child(map)
	for x in range(8):
		map.set_cell(Vector2i(x, 0), 0, Vector2i.ZERO)
	return map
