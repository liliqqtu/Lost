extends RefCounted
##"""战斗计算器 计算伤害 命中 必杀"""
class_name BattleCalculator

const WeaponRef := preload("res://scripts/weapon.gd")
const GlobalRef := preload("res://Global.gd")

##"""物理三角相克：剑克斧，斧克枪，枪克剑"""
const PHYSICAL_TRIANGLE := {
	WeaponRef.WeaponType.SWORD: WeaponRef.WeaponType.AXE,
	WeaponRef.WeaponType.AXE: WeaponRef.WeaponType.LANCE,
	WeaponRef.WeaponType.LANCE: WeaponRef.WeaponType.SWORD,
}
##"""魔法三角相克：理克光，光克暗，暗克理"""
const MAGIC_TRIANGLE := {
	WeaponRef.WeaponType.ANIMA: WeaponRef.WeaponType.LIGHT,
	WeaponRef.WeaponType.LIGHT: WeaponRef.WeaponType.DARK,
	WeaponRef.WeaponType.DARK: WeaponRef.WeaponType.ANIMA,
}
##"""三角相克修正：克制 +1威力 +15命中，被克 -1威力 -15命中"""
const TRIANGLE_DAMAGE := 1
const TRIANGLE_HIT := 15


##"""返回攻击方相对防御方的三角相克：1 克制，-1 被克，0 无关系"""
static func get_triangle(attacker: Unit, defender: Unit) -> int:
	var aw: WeaponRef = attacker.current_weapon
	var dw: WeaponRef = defender.current_weapon
	if not aw or not dw:
		return 0
	if PHYSICAL_TRIANGLE.get(aw.weapon_type) == dw.weapon_type or MAGIC_TRIANGLE.get(aw.weapon_type) == dw.weapon_type:
		return 1
	if PHYSICAL_TRIANGLE.get(dw.weapon_type) == aw.weapon_type or MAGIC_TRIANGLE.get(dw.weapon_type) == aw.weapon_type:
		return -1
	return 0


##攻速（AS）：速度 - max(0, 武器重量 - 体格)，无武器按速度
static func get_attack_speed(unit: Unit) -> int:
	var weapon := unit.current_weapon
	if not weapon:
		return unit.spd
	return unit.spd - maxi(0, weapon.weight - unit.con)


##伤害：攻击力 + 三角相克 - 防御（按攻击武器类型选择守备/魔防，含防御方地形加成）
static func calculate_damage(attacker: Unit, defender: Unit, tile_map: TileMapLayer = null) -> int:
	var atk := _get_attack_power(attacker) + get_triangle(attacker, defender) * TRIANGLE_DAMAGE
	var defense := _get_defense(attacker, defender) + _terrain_def_bonus(defender, tile_map)
	return max(atk - defense, 0)


##命中率：武器命中 + 技巧*2 + 幸运/2 + 三角相克 + 支援加成(命中)，减去回避（攻速*2 + 幸运 + 地形回避 + 支援加成(回避)）
##units 传入当前地图全部单位时结算支援加成（支援对象 3 格内生效，SupportStore 查表），为空则支援按 0（旧调用兼容）
static func calculate_hit_rate(attacker: Unit, defender: Unit, tile_map: TileMapLayer = null, units: Array = []) -> int:
	var weapon := attacker.current_weapon
	var hit := (weapon.hit + attacker.skl * 2 + attacker.luk / 2) if weapon else 0
	hit += get_triangle(attacker, defender) * TRIANGLE_HIT
	var support_a := SupportStore.get_support_bonus(attacker, units)
	var support_d := SupportStore.get_support_bonus(defender, units)
	hit += support_a["hit"]
	var avoid := get_attack_speed(defender) * 2 + defender.luk + _terrain_avoid_bonus(defender, tile_map) + support_d["avoid"] as int
	return clampi(hit - avoid, 0, 100)


##必杀率：武器必杀 + 技巧/2 + 支援加成(必杀)，减去必杀回避（幸运）
##units 含义同 calculate_hit_rate
static func calculate_crit_rate(attacker: Unit, defender: Unit, units: Array = []) -> int:
	var weapon := attacker.current_weapon
	if not weapon:
		return 0
	var crit := weapon.crit + attacker.skl / 2 - defender.luk
	crit += SupportStore.get_support_bonus(attacker, units)["crit"]
	return max(crit, 0)


##追击判定：攻速差 >= 4
static func can_double(attacker: Unit, defender: Unit) -> bool:
	return get_attack_speed(attacker) >= get_attack_speed(defender) + 4


##反击判定：防御方有武器且攻击距离在其武器射程内（被动技能如仿徨影响防御方有效射程）
static func can_counter(attacker: Unit, defender: Unit) -> bool:
	var weapon := defender.current_weapon
	if not weapon:
		return false
	var dist := _manhattan(attacker.cell, defender.cell)
	var min_r := defender.get_effective_min_range()
	var max_r := defender.get_effective_max_range()
	return dist >= min_r and dist <= max_r


##生成战斗序列（纯数据，无随机），供战斗预览 UI 与实际结算共用
##顺序：攻方打击 -> 防御方反击 -> 攻方追击 -> 防方追击
##按期望伤害模拟血量，任一方死亡则不再生成后续打击
##每项：{attacker, defender, damage, hit, crit, is_counter, is_double}
##tile_map 传入时结算双方地形加成，为空则地形按 0/0 处理
##units 传入时命中/必杀结算支援加成（3 格内），为空则支援按 0（旧调用兼容）
static func generate_battle_sequence(attacker: Unit, defender: Unit, tile_map: TileMapLayer = null, units: Array = []) -> Array[Dictionary]:
	var sequence: Array[Dictionary] = []
	var sim_hp := {attacker: attacker.hp, defender: defender.hp}

	var attacker_doubles := can_double(attacker, defender)
	var defender_doubles := can_double(defender, attacker)
	##防御方射程外不能反击，追击与反击共享射程判定（GBA 行为）
	var defender_can_strike := can_counter(attacker, defender)

	if not _append_strike(sequence, sim_hp, attacker, defender, false, false, tile_map, units):
		return sequence
	if defender_can_strike:
		if not _append_strike(sequence, sim_hp, defender, attacker, true, false, tile_map, units):
			return sequence
	if attacker_doubles:
		if not _append_strike(sequence, sim_hp, attacker, defender, false, true, tile_map, units):
			return sequence
	if defender_doubles and defender_can_strike:
		_append_strike(sequence, sim_hp, defender, attacker, false, true, tile_map, units)
	return sequence


##追加一次打击到序列，模拟扣血，返回防御方是否存活
static func _append_strike(sequence: Array[Dictionary], sim_hp: Dictionary, a: Unit, d: Unit, is_counter: bool, is_double: bool, tile_map: TileMapLayer, units: Array) -> bool:
	var damage := calculate_damage(a, d, tile_map)
	sequence.append({
		"attacker": a,
		"defender": d,
		"damage": damage,
		"hit": calculate_hit_rate(a, d, tile_map, units),
		"crit": calculate_crit_rate(a, d, units),
		"is_counter": is_counter,
		"is_double": is_double,
	})
	sim_hp[d] = maxi(sim_hp[d] - damage, 0)
	return sim_hp[d] > 0


##攻击力：魔法武器用魔力，物理武器用力量，无武器裸力量
static func _get_attack_power(unit: Unit) -> int:
	var weapon := unit.current_weapon
	if not weapon:
		return unit.str
	if weapon.weapon_type == WeaponRef.WeaponType.ANIMA or weapon.weapon_type == WeaponRef.WeaponType.DARK or weapon.weapon_type == WeaponRef.WeaponType.LIGHT:
		return unit.mag + weapon.might
	return unit.str + weapon.might


##防御：魔法攻击对魔防，物理攻击对守备
static func _get_defense(attacker: Unit, defender: Unit) -> int:
	var weapon := attacker.current_weapon
	if weapon and (weapon.weapon_type == WeaponRef.WeaponType.ANIMA or weapon.weapon_type == WeaponRef.WeaponType.DARK or weapon.weapon_type == WeaponRef.WeaponType.LIGHT):
		return defender.res
	return defender.def_h


##"""单位所在地形的守备加成，无地图时按 0"""
static func _terrain_def_bonus(unit: Unit, tile_map: TileMapLayer) -> int:
	if tile_map == null:
		return 0
	return GlobalRef.get_terrain_bonus(Pathfinder.get_terrain_name(tile_map, unit.cell))["def"]


##"""单位所在地形的回避加成，无地图时按 0"""
static func _terrain_avoid_bonus(unit: Unit, tile_map: TileMapLayer) -> int:
	if tile_map == null:
		return 0
	return GlobalRef.get_terrain_bonus(Pathfinder.get_terrain_name(tile_map, unit.cell))["avoid"]


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


##==================== 经验与升级（升级系统） ====================

##"""FE8 经验公式（转职加成/BOSS/盗贼标记未实现，有这些系统后再扩展）：
##造成伤害 = (31 + 敌Lv - 己Lv) / 己职业强度（下取整，最低1）
##未命中或 0 伤 = 1
##击杀 = 伤害经验 + max(0, 敌Lv×敌职业强度 - 己Lv×己职业强度 + 20)，封顶 100"""
static func calculate_exp_gain(player_unit: Unit, enemy_unit: Unit, did_damage: bool, killed: bool) -> int:
	var qp := _class_power(player_unit)
	var qe := _class_power(enemy_unit)
	var exp_dmg := 1
	if did_damage:
		exp_dmg = maxi(floori((31.0 + enemy_unit.lv - player_unit.lv) / qp), 1)
	if not killed:
		return exp_dmg
	var kill_bonus := maxi(enemy_unit.lv * qe - player_unit.lv * qp + 20, 0)
	return mini(exp_dmg + kill_bonus, 100)


##"""职业强度（无职业数据按普通职业 3）"""
static func _class_power(unit: Unit) -> int:
	if unit.class_data != null:
		return unit.class_data.class_power
	return 3


##"""升级掷骰（GBA 规则，无保底）：八项能力按 ClassData 成长率% 独立掷骰 +1
##已到职业上限的能力不再加；无职业数据成长全 0（不加点）
##返回 {stat: 0/1}，stat ∈ hp/str/mag/skl/spd/luk/def_h/res"""
static func roll_level_up(unit: Unit) -> Dictionary:
	var gains := {}
	for key in LEVEL_STAT_KEYS:
		var growth := 0
		var cap := 0
		var cur := 0
		if unit.class_data != null:
			growth = unit.class_data.get("growths_" + key)
			cap = unit.class_data.get("cap_" + key)
			cur = unit.max_hp if key == "hp" else unit.get(key)
		gains[key] = 1 if (growth > 0 and cur < cap and randi_range(1, 100) <= growth) else 0
	return gains

##"""升级掷骰的能力键（与 grade_up 场景 Add 子节点顺序一致：HP 力量 魔力 技术 速度 幸运 防御 魔防）"""
const LEVEL_STAT_KEYS := ["hp", "str", "mag", "skl", "spd", "luk", "def_h", "res"]
