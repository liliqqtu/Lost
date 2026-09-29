extends RefCounted
class_name EnemyAI

##"""敌方 AI 决策器（纯数据、无状态），只负责"决定做什么"，不负责执行
##移动/攻击/回合流程由 BattleManager 执行，符合 Unit 不负责 AI 的职责划分
##优先级：
##1. 移动后可击杀的目标（单次打击伤害 >= 目标HP），选剩余移动力最高的站位
##2. 移动后可攻击的目标，选期望伤害最高的
##3. 向最近的我方单位移动，选离其最近的可达格"""

##"""决策入口：actor 当前要行动的敌人，units 全部存活单位，tile_map 地形图
##返回 {move_to: Vector2i, target: Unit 或 null}"""
static func decide(actor: Unit, units: Array[Unit], tile_map: TileMapLayer) -> Dictionary:
	var plan := {"move_to": actor.cell, "target": null}

	##其他单位占位视为障碍
	var blocked: Array = []
	for u in units:
		if u != actor:
			blocked.append(u.cell)
	var move_range: Dictionary = Pathfinder.get_move_range(tile_map, actor.cell, actor.move, actor.move_table, blocked)

	##敌方阵营的打击目标（不同 team 即敌对，含友军）
	var foes: Array[Unit] = []
	for u in units:
		if u.team != actor.team:
			foes.append(u)
	if foes.is_empty():
		return plan

	##有可用武器才考虑攻击方案（P0-1：遍历背包所有可用武器射程并集）
	var ranges := actor.get_weapon_ranges()
	if not ranges.is_empty():
		var best_kill: Dictionary = {}
		var best_kill_remain := -1
		var best_attack: Dictionary = {}
		var best_attack_damage := -1

		##遍历所有可站位，找射程内的目标（任一武器射程即可）
		for stand_cell in move_range.keys():
			var remain: int = move_range[stand_cell]["remain_move"]
			for foe in foes:
				var dist: int = _manhattan(stand_cell, foe.cell)
				var in_any := false
				for r in ranges:
					if dist >= int(r["min"]) and dist <= int(r["max"]):
						in_any = true
						break
				if not in_any:
					continue
				##攻击方站位不影响伤害（伤害只与防御方地形有关），可直接计算
				var damage := BattleCalculator.calculate_damage(actor, foe, tile_map)
				if damage >= foe.hp:
					if remain > best_kill_remain:
						best_kill = {"stand": stand_cell, "target": foe}
						best_kill_remain = remain
				elif damage > best_attack_damage:
					best_attack = {"stand": stand_cell, "target": foe}
					best_attack_damage = damage

		if not best_kill.is_empty():
			plan["move_to"] = best_kill["stand"]
			plan["target"] = best_kill["target"]
			return plan
		if not best_attack.is_empty():
			plan["move_to"] = best_attack["stand"]
			plan["target"] = best_attack["target"]
			return plan

	##无法攻击：向最近的我方单位移动
	var nearest := foes[0]
	var nearest_dist := _manhattan(actor.cell, foes[0].cell)
	for foe in foes:
		var d := _manhattan(actor.cell, foe.cell)
		if d < nearest_dist:
			nearest_dist = d
			nearest = foe

	var best_cell: Vector2i = actor.cell
	var best_dist := _manhattan(actor.cell, nearest.cell)
	for stand_cell in move_range.keys():
		var d := _manhattan(stand_cell, nearest.cell)
		if d < best_dist:
			best_dist = d
			best_cell = stand_cell
	plan["move_to"] = best_cell
	return plan


##"""曼哈顿距离（与武器射程判定一致）"""
static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
