extends SceneTree

##阶段四验证脚本：EnemyAI 决策优先级（击杀 > 移动后可攻击 > 向最近我方移动）
##运行：godot --headless --path . -s res://tests/test_enemy_ai.gd

func _init() -> void:
	var tile_map := _build_test_tile_map()

	##场景一：低血我方单位可被击杀，高血单位同样在射程内，应优先选择击杀目标
	var enemy := _make_unit("山贼", 1, Vector2i(3, 3))
	var weak_player := _make_unit("忒", 0, Vector2i(2, 3))
	weak_player.hp = 3
	var healthy_player := _make_unit("卫兵", 0, Vector2i(4, 3))
	healthy_player.hp = 30
	healthy_player.max_hp = 30

	var units: Array[Unit] = [enemy, weak_player, healthy_player]
	var plan := EnemyAI.decide(enemy, units, tile_map)
	print("--- 场景一：击杀优先 ---")
	print("目标: %s（期望 忒） 站位: %s（期望 3,3 原地）" % [plan["target"].unit_name, plan["move_to"]])
	assert(plan["target"] == weak_player)
	assert(plan["move_to"] == Vector2i(3, 3))

	##场景二：目标都在射程外但可移动后攻击，应选择站位并攻击
	weak_player.cell = Vector2i(3, 0)
	weak_player.hp = 30
	weak_player.max_hp = 30
	healthy_player.cell = Vector2i(6, 6)
	plan = EnemyAI.decide(enemy, units, tile_map)
	print("--- 场景二：移动后攻击 ---")
	print("目标: %s（期望 忒） 站位: %s（期望 3,2 或 3,1）" % [plan["target"].unit_name, plan["move_to"]])
	assert(plan["target"] == weak_player)
	assert(plan["move_to"] == Vector2i(3, 2) or plan["move_to"] == Vector2i(3, 1))

	##场景三：我方单位远超移动+射程，应向最近的我方单位（卫兵 6,6）移动
	##移动力 2 内距 (6,6) 最近的格：(4,4)/(5,3)/(3,5) 并列，任一即可
	weak_player.cell = Vector2i(8, 8)
	plan = EnemyAI.decide(enemy, units, tile_map)
	print("--- 场景三：无法攻击向最近目标移动 ---")
	print("站位: %s（期望 4,4 / 5,3 / 3,5 之一） 目标: %s（期望 null）" % [plan["move_to"], plan["target"]])
	assert(plan["move_to"] in [Vector2i(4, 4), Vector2i(5, 3), Vector2i(3, 5)])
	assert(plan["target"] == null)

	##场景四：无武器敌人不产生攻击方案，直接接近最近的我方单位（忒 1,1）
	##移动力 2 内距 (1,1) 最近的格：(2,2)/(3,1)/(1,3) 并列，任一即可
	enemy.current_weapon = null
	weak_player.cell = Vector2i(1, 1)
	plan = EnemyAI.decide(enemy, units, tile_map)
	print("--- 场景四：无武器接近 ---")
	print("站位: %s（期望 2,2 / 3,1 / 1,3 之一） 目标: %s（期望 null）" % [plan["move_to"], plan["target"]])
	assert(plan["move_to"] in [Vector2i(2, 2), Vector2i(3, 1), Vector2i(1, 3)])
	assert(plan["target"] == null)

	print("=== test_enemy_ai 全部通过 ===")

	for u in units:
		u.free()
	quit()


##"""构造测试单位"""
func _make_unit(p_name: String, p_team: int, p_cell: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.unit_name = p_name
	unit.team = p_team
	unit.cell = p_cell
	unit.move = 2
	unit.str = 5
	unit.skl = 3
	unit.spd = 5
	unit.def_h = 5
	unit.con = 11
	var axe := Weapon.new()
	axe.display_name = "铁斧"
	axe.weapon_type = Weapon.WeaponType.AXE
	axe.might = 8
	axe.hit = 70
	axe.weight = 10
	unit.current_weapon = axe
	return unit


##"""构造 10x10 全道路测试地图"""
func _build_test_tile_map() -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "Name")
	tile_set.set_custom_data_layer_type(0, TYPE_STRING)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create_empty(32, 16, false, Image.FORMAT_RGBA8))
	tile_set.add_source(source, 0)
	source.create_tile(Vector2i(0, 0))
	source.get_tile_data(Vector2i(0, 0), 0).set_custom_data("Name", "道路")
	var tile_map := TileMapLayer.new()
	tile_map.tile_set = tile_set
	for x in range(10):
		for y in range(10):
			tile_map.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	return tile_map
