extends SceneTree

const BattleForecastRef := preload("res://scripts/battle_forecast.gd")

##阶段二验证脚本：测试 BattleForecast 读取战斗序列后是否渲染出正确文字/——
func _init() -> void:
	var attacker := Unit.new()
	attacker.unit_name = "忒"
	attacker.lv = 5
	attacker.max_hp = 26
	attacker.hp = 26
	attacker.str = 8
	attacker.skl = 10
	attacker.spd = 11
	attacker.luk = 5
	attacker.con = 7
	attacker.cell = Vector2i(5, 5)
	var sword := Weapon.new()
	sword.display_name = "铁剑"
	sword.might = 5
	sword.hit = 100
	sword.weight = 5
	attacker.current_weapon = sword

	var defender := Unit.new()
	defender.unit_name = "山贼"
	defender.team = 1
	defender.lv = 1
	defender.max_hp = 24
	defender.hp = 24
	defender.str = 7
	defender.skl = 3
	defender.spd = 5
	defender.luk = 0
	defender.con = 11
	defender.cell = Vector2i(5, 6)
	var axe := Weapon.new()
	axe.display_name = "铁斧"
	axe.might = 8
	axe.hit = 70
	axe.weight = 10
	defender.current_weapon = axe

	var forecast := BattleForecastRef.new()
	var panel := _build_panel()
	forecast.setup(panel)

	var sequence := BattleCalculator.generate_battle_sequence(attacker, defender)
	forecast.show_forecast(attacker, sequence)

	print("玩家 名字:", forecast._player_name.text)
	print("玩家 数值(HP/威力/命中/必杀):")
	print(forecast._player_dph.text)
	print("玩家 武器图片: ", forecast._player_weapon.texture)
	print("敌方 名字:", forecast._enemy_name.text)
	print("敌方 数值(HP/威力/命中/必杀):")
	print(forecast._enemy_dph.text)
	print("敌方 武器图片: ", forecast._enemy_weapon.texture)
	print("敌方 武器名字:", forecast._enemy_weapon_name.text)

	# 无法反击场景：山贼距离 2，斧头射程 1
	defender.cell = Vector2i(7, 5)
	var sequence2 := BattleCalculator.generate_battle_sequence(attacker, defender)
	forecast.show_forecast(attacker, sequence2)
	print("敌方 无法反击时数值(后三行应为 ——):")
	print(forecast._enemy_dph.text)

	attacker.free()
	defender.free()
	forecast.free()
	quit()


##构造与 level_0.tscn 中 Battle Preview 同名子节点的面板，供脚本绑定
func _build_panel() -> TextureRect:
	var panel := TextureRect.new()
	panel.name = "Battle Preview"
	for label_name in ["PlayerName", "PlayerDPH", "EnemyName", "EnemyDPH", "EnemyWeaponName"]:
		var label := Label.new()
		label.name = label_name
		panel.add_child(label)
	for icon_name in ["PlayerWeapon", "EnemyWeapon"]:
		var icon := TextureRect.new()
		icon.name = icon_name
		panel.add_child(icon)
	return panel
