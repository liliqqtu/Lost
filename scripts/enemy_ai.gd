extends RefCounted
class_name EnemyAI

## 返回站位、目标和实际使用的武器；候选计算不改动真实单位。
static func decide(actor: Unit, units: Array[Unit], tile_map: TileMapLayer) -> Dictionary:
	var plan := {"move_to": actor.cell, "target": null, "weapon": null}
	var blocked := Pathfinder.get_unit_blockers(actor, units)
	var foes: Array[Unit] = []
	for unit in units:
		if unit.carried_by != null or unit.hp <= 0:
			continue
		if BattleCalculator.is_hostile(actor, unit):
			foes.append(unit)
	if foes.is_empty():
		return plan
	var moves := Pathfinder.get_move_range(tile_map, actor.cell, actor.get_effective_move(units), actor.move_table, blocked)
	for cell in moves.keys():
		if not Pathfinder.can_stop_at(actor, cell, units):
			moves.erase(cell)
	if actor.team == 2:
		var healing := _healing_plan(actor, units, moves)
		if not healing.is_empty():
			return healing
	var best_score := -INF
	for ranges in actor.get_weapon_ranges():
		var weapon: Weapon = ranges.weapon
		var preview := actor.preview_with_weapon(weapon)
		var context: Array = units.duplicate()
		context[context.find(actor)] = preview
		for cell in moves:
			preview.cell = cell
			for target in foes:
				if not BattleCalculator.can_attack(preview, target):
					continue
				var damage := BattleCalculator.calculate_damage(preview, target, tile_map, context)
				var hit := BattleCalculator.calculate_hit_rate(preview, target, tile_map, context)
				var score: float = 10000.0 + moves[cell].remain_move if damage >= target.hp and hit > 0 else damage * hit / 100.0
				if score > best_score:
					best_score = score
					plan = {"move_to": cell, "target": target, "weapon": weapon}
		preview.free()
	if plan.target != null:
		return plan
	var nearest := foes[0]
	for target in foes:
		if _manhattan(actor.cell, target.cell) < _manhattan(actor.cell, nearest.cell):
			nearest = target
	var distance := _manhattan(actor.cell, nearest.cell)
	for cell in moves:
		var next_distance := _manhattan(cell, nearest.cell)
		if next_distance < distance:
			distance = next_distance
			plan.move_to = cell
	return plan

static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## 绿色持杖单位优先选择可达范围内能恢复最多 HP 的蓝/绿同伴。
static func _healing_plan(actor: Unit, units: Array[Unit], moves: Dictionary) -> Dictionary:
	var result := {}
	var best_heal := 0
	for item in actor.inventory:
		var staff := item as Weapon
		if staff == null or staff.weapon_type != Weapon.WeaponType.STAFF or staff.durability <= 0 or not actor.can_equip(staff):
			continue
		for target in units:
			if target == actor or target.carried_by != null or target.hp <= 0 or target.hp >= target.max_hp or BattleCalculator.is_hostile(actor, target):
				continue
			for cell in moves:
				var distance := _manhattan(cell, target.cell)
				if distance < staff.min_range or distance > staff.max_range:
					continue
				var heal := mini(target.max_hp - target.hp, staff.might + actor.get_effective_mag(units))
				if heal > best_heal:
					best_heal = heal
					result = {"move_to": cell, "target": target, "weapon": staff, "action": "heal"}
	return result
