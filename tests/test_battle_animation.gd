extends SceneTree

##阶段五 5A 验证脚本：战斗动画场景（标签填充 / 血条更新 / 未命中 / 击杀淡出 / 收尾）
##运行：godot --headless --path . -s res://tests/test_battle_animation.gd

func _initialize() -> void:
	_run()


func _run() -> void:
	var scene := preload("res://scene/ui/battle_animation.tscn").instantiate()
	root.add_child(scene)
	##-s 模式下 root 尚未进树，等一帧让 _ready（@onready 绑定）执行
	await process_frame

	##造一对交战单位（带战斗动画帧与武器）
	var player := Unit.new()
	player.unit_name = "忒"
	player.team = 0
	player.cell = Vector2i(3, 3)
	player.battle_frames = preload("res://scene/character/battle_animation_tres/Ranger_M_frames.tres")
	var sword := Weapon.new()
	sword.display_name = "铁剑"
	sword.weapon_type = Weapon.WeaponType.SWORD
	sword.might = 5
	sword.hit = 100
	player.current_weapon = sword

	var enemy := Unit.new()
	enemy.unit_name = "山贼"
	enemy.team = 1
	enemy.cell = Vector2i(4, 3)
	enemy.max_hp = 18
	enemy.hp = 18
	enemy.def_h = 2
	enemy.battle_frames = preload("res://scene/character/battle_animation_tres/Bandit_M_frames.tres")
	var axe := Weapon.new()
	axe.display_name = "铁斧"
	axe.weapon_type = Weapon.WeaponType.AXE
	axe.might = 8
	axe.hit = 70
	axe.weight = 10
	enemy.current_weapon = axe

	var sequence := BattleCalculator.generate_battle_sequence(player, enemy, null)

	##加速动画播放，缩短测试耗时
	scene.player_anim.speed_scale = 20.0
	scene.enemy_anim.speed_scale = 20.0

	await scene.play(player, enemy, sequence, "平原", "森林")

	##--- 断言：标签填充（数值全部来自战斗序列，不重算） ---
	var p_strike := {}
	var e_strike := {}
	for strike in sequence:
		if strike["attacker"] == player and p_strike.is_empty():
			p_strike = strike
		if strike["attacker"] == enemy and e_strike.is_empty():
			e_strike = strike

	print("--- 标签填充 ---")
	assert(scene.player_unit == player)
	assert(scene.enemy_unit == enemy)
	assert(scene.player_name_label.text == "忒")
	assert(scene.enemy_name_label.text == "山贼")
	assert(scene.player_weapon_name_label.text == "铁剑")
	assert(scene.enemy_weapon_name_label.text == "铁斧")
	assert(scene.player_hit_label.text == str(p_strike["hit"]))
	assert(scene.player_dmg_label.text == str(p_strike["damage"]))
	assert(scene.enemy_hit_label.text == str(e_strike["hit"]))
	assert(scene.enemy_hp_label.text == "18")
	assert(scene.player_health_bar.max_value == player.max_hp)
	assert(scene.enemy_health_bar.value == 18)
	print("标签/血条 OK")

##--- 命中：命中帧 on_impact 即时扣血（画面血条同步） ---
	await scene.play_strike(player, true, false, p_strike["damage"])
	assert(scene.enemy_display_hp == 18 - p_strike["damage"])
	assert(scene.enemy_hp_label.text == str(18 - p_strike["damage"]))
	print("命中扣血 OK（18 -> %d）" % scene.enemy_display_hp)

	##--- 未命中：不动血量 ---
	await scene.play_strike(enemy, false, false, 0)
	assert(scene.player_display_hp == player.hp)
	print("未命中不掉血 OK")

	##--- 击杀：血量归零防御方淡出 ---
	await scene.play_strike(player, true, false, 999)
	assert(scene.enemy_display_hp == 0)
	assert(scene.enemy_anim.modulate.a == 0.0)
	print("击杀淡出 OK")

	##--- 收尾：整场淡出隐藏 ---
	await scene.close()
	assert(scene.visible == false)
	print("收尾隐藏 OK")

	print("=== test_battle_animation 全部通过 ===")
	player.free()
	enemy.free()
	scene.free()
	quit()
