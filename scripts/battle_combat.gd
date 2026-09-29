class_name BattleCombat
extends RefCounted

##战斗结算执行（自 battle_manager.gd 分包）：
##读取战斗序列逐次掷骰结算（命中 -> 必杀 -> 伤害），阶段五 5A 结算期间切入战斗动画场景，
##打击节奏复用同一份序列数据（与预览同源，禁止重算）；每击的动画播放完毕后才对地图单位结算伤害；
##每次打击（含未命中、反击、追击）消耗攻击方武器 1 点耐久，归零武器损坏（GBA 行为）。
##升级系统：玩家单位命中结算武器经验，战后按 FE8 公式结算角色经验（exp_box/grade_up 演出）。

var bm: BattleManager
##战斗动画场景（阶段五 5A）
var battle_scene: Node = null


##执行攻击：读取战斗序列，逐次掷骰结算（命中 -> 必杀 -> 伤害）
##units 传入以结算支援加成（支援对象 3 格内，5G）
func execute_attack(attacker: Unit, defender: Unit) -> void:
	var sequence := BattleCalculator.generate_battle_sequence(attacker, defender, bm.tile_map, bm.units)

	print("=== 战斗开始 ===")
	print("攻击方: %s, 防御方: %s" % [attacker.unit_name, defender.unit_name])

	var prev_state := bm.state
	bm.state = BattleManager.State.BATTLE_ANIM
	bm.cursor.set_process(false)

	##开场：填充战斗画面标签/动画/地形背景
	if battle_scene != null:
		await battle_scene.play(attacker, defender, sequence,
				Pathfinder.get_terrain_name(bm.tile_map, attacker.cell),
				Pathfinder.get_terrain_name(bm.tile_map, defender.cell))

	##经验统计（升级系统）：参战双方记录 是否造成伤害/是否击杀，战后结算（只有玩家方真正获得）
	var exp_stats := {
		attacker: {"damage": false, "kill": false},
		defender: {"damage": false, "kill": false},
	}

	for strike in sequence:
		var a: Unit = strike["attacker"]
		var d: Unit = strike["defender"]
		var label := "追击" if strike["is_double"] else ("反击" if strike["is_counter"] else "攻击")
		##本击使用的武器（可能中途损坏，先取引用供武器经验结算）
		var strike_weapon: Weapon = a.current_weapon

		#命中判定：1-100随机数 <= 命中率
		var hit_roll := randi_range(1, 100)
		if hit_roll > strike["hit"]:
			print("%s 的%s未命中（命中 %d%%，掷出 %d）" % [a.unit_name, label, strike["hit"], hit_roll])
			if battle_scene != null:
				await battle_scene.play_strike(a, false, false, 0)
			_consume_weapon(a)
			continue

		#必杀判定：命中后单独掷骰，必杀伤害x3
		var damage: int = strike["damage"]
		var is_crit: bool = randi_range(1, 100) <= strike["crit"]
		if is_crit:
			damage *= 3

		#动画播放完毕后结算伤害（画面血条也在动画结束时更新）
		if battle_scene != null:
			await battle_scene.play_strike(a, true, is_crit, damage)

		_apply_damage(d, damage)
		_consume_weapon(a)
		##武器经验：玩家单位每次命中的打击 +武器.weapon_exp（未命中不给，升级系统）
		if a.team == 0 and strike_weapon != null:
			a.gain_weapon_exp(strike_weapon)
		if damage > 0:
			exp_stats[a]["damage"] = true
		var crit_text := "，必杀！" if is_crit else ""
		print("%s 的%s命中：伤害 %d%s（%d/%d）" % [a.unit_name, label, damage, crit_text, d.hp, d.max_hp])

		if d.hp <= 0:
			exp_stats[a]["kill"] = true
			bm.remove_unit(d)
			print("%s 被击败！" % d.unit_name)
			break

	##战后经验/升级演出（战斗画面淡出前，经验条与升级面板覆盖在战斗画面上）
	await _settle_exp(attacker, defender, exp_stats)

	##收尾：淡出战斗画面回地图
	if battle_scene != null:
		await battle_scene.close()

	bm.state = prev_state
	bm.cursor.set_process(prev_state != BattleManager.State.ENEMY_TURN)


##"""战后经验结算（升级系统）：参战的玩家单位（team 0）按 FE8 公式获得经验
##经验条逐段填充：填满 100 → grade_up 升级加点动画 → 继续填余下经验（可连升多级）
##阵亡单位不结算（已被 remove_unit 释放，is_instance_valid 先验活再取属性，
##否则报 Invalid access to property 'team' on previously freed）；满级（Unit.LEVEL_CAP）不再获得经验
##武器经验已在战斗循环中按命中结算（Unit.gain_weapon_exp），不在此处理"""
func _settle_exp(attacker: Unit, defender: Unit, stats: Dictionary) -> void:
	for unit in [attacker, defender]:
		if not is_instance_valid(unit) or unit.team != 0 or unit.hp <= 0 or unit.lv >= Unit.LEVEL_CAP:
			continue
		var other := defender if unit == attacker else attacker
		var s: Dictionary = stats[unit]
		var gain := BattleCalculator.calculate_exp_gain(unit, other, s["damage"], s["kill"])
		if gain <= 0:
			continue
		print("%s 获得 %d 经验" % [unit.unit_name, gain])
		var remaining := gain
		while remaining > 0 and unit.lv < Unit.LEVEL_CAP:
			var old_exp := unit.exp as int
			var step := mini(100 - old_exp, remaining)
			unit.gain_exp(step)
			remaining -= step
			if battle_scene != null:
				await battle_scene.show_exp(old_exp, unit.exp)
			if unit.exp >= 100:
				var gains := BattleCalculator.roll_level_up(unit)
				unit.level_up(gains)
				print("%s 升级！Lv%d 加点：%s" % [unit.unit_name, unit.lv, str(gains)])
				if battle_scene != null:
					await battle_scene.show_level_up(unit, gains)


##消耗攻击方武器耐久（每次打击后调）；归零由 Unit.consume_weapon_durability 内部负责移除背包并卸装
func _consume_weapon(unit: Unit) -> void:
	unit.consume_weapon_durability()


##对单位造成伤害
func _apply_damage(unit: Unit, damage: int) -> void:
	unit.hp = max(unit.hp - damage, 0)
	unit.update_hp_bar()
