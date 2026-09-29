extends SceneTree

##阶段一/三验证脚本：godot --headless -s res://tests/test_battle_sequence.gd
func _init() -> void:
	##攻击方：忒 剑士 高速
	var attacker := Unit.new()
	attacker.unit_name = "忒"
	attacker.str = 8
	attacker.skl = 10
	attacker.spd = 11
	attacker.luk = 5
	attacker.con = 7
	attacker.max_hp = 26
	attacker.hp = 26
	attacker.cell = Vector2i(5, 5)
	var sword := Weapon.new()
	sword.display_name = "铁剑"
	sword.weapon_type = Weapon.WeaponType.SWORD
	sword.might = 5
	sword.hit = 100
	sword.weight = 5
	attacker.current_weapon = sword

	##防御方：山贼 高伤低速 重斧
	var defender := Unit.new()
	defender.unit_name = "山贼"
	defender.team = 1
	defender.str = 7
	defender.skl = 3
	defender.spd = 5
	defender.luk = 0
	defender.con = 11
	defender.max_hp = 24
	defender.hp = 24
	defender.cell = Vector2i(5, 6)
	var axe := Weapon.new()
	axe.display_name = "铁斧"
	axe.weapon_type = Weapon.WeaponType.AXE
	axe.might = 8
	axe.hit = 70
	axe.weight = 10
	axe.crit = 0
	defender.current_weapon = axe

	print("攻速: 忒=%d 山贼=%d" % [BattleCalculator.get_attack_speed(attacker), BattleCalculator.get_attack_speed(defender)])
	print("追击判定: 忒->山贼 %s / 山贼->忒 %s" % [BattleCalculator.can_double(attacker, defender), BattleCalculator.can_double(defender, attacker)])

	print("--- 阶段三：三角相克（剑克斧） ---")
	var triangle := BattleCalculator.get_triangle(attacker, defender)
	var triangle_back := BattleCalculator.get_triangle(defender, attacker)
	print("忒(剑)对山贼(斧)相克: %d（期望 1） 山贼(斧)对忒(剑)相克: %d（期望 -1）" % [triangle, triangle_back])

	print("--- 阶段三：地形加成（山贼站山上） ---")
	var tile_map := _build_test_tile_map()
	var dmg_plain := BattleCalculator.calculate_damage(attacker, defender)
	var dmg_mountain := BattleCalculator.calculate_damage(attacker, defender, tile_map)
	var hit_plain := BattleCalculator.calculate_hit_rate(attacker, defender)
	var hit_mountain := BattleCalculator.calculate_hit_rate(attacker, defender, tile_map)
	print("平地: 伤害%d 命中%d%%（期望 伤害9 命中100%%）" % [dmg_plain, hit_plain])
	print("山:   伤害%d 命中%d%%（期望 伤害8 命中97%%：武器100+技20+幸2+相克15-回避10-地形30）" % [dmg_mountain, hit_mountain])

	print("--- 战斗序列（山贼在山上） ---")
	var sequence := BattleCalculator.generate_battle_sequence(attacker, defender, tile_map)
	for strike in sequence:
		var label := "追击" if strike["is_double"] else ("反击" if strike["is_counter"] else "攻击")
		print("%s %s: 伤害%d 命中%d%% 必杀%d%%" % [strike["attacker"].unit_name, label, strike["damage"], strike["hit"], strike["crit"]])

	print("--- 阶段三：武器耐久 ---")
	var test_weapon := Weapon.new()
	test_weapon.display_name = "测试剑"
	test_weapon.durability = 3
	for i in range(3):
		var broken := test_weapon.consume_durability()
		print("第%d次消耗: 耐久%d 损坏%s" % [i + 1, test_weapon.durability, broken])
	print("第4次消耗（已损坏后不重复扣）: 损坏%s" % test_weapon.consume_durability())

	attacker.free()
	defender.free()
	quit()


##"""构造测试用地图：(5,5)道路 (5,6)山，瓦片带 Name 自定义数据"""
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
	source.get_tile_data(Vector2i(0, 0), 0).set_custom_data("Name", "山")
	source.create_tile(Vector2i(1, 0))
	source.get_tile_data(Vector2i(1, 0), 0).set_custom_data("Name", "道路")
	var tile_map := TileMapLayer.new()
	tile_map.tile_set = tile_set
	tile_map.set_cell(Vector2i(5, 5), 0, Vector2i(1, 0))
	tile_map.set_cell(Vector2i(5, 6), 0, Vector2i(0, 0))
	return tile_map
