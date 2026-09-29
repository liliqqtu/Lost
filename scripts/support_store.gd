extends Node
##支援系统全局数据（5G，autoload 单例，同 ConvoyStore 模式）
##支援值不按原版邻接积累，按章节积累：双方都登场过且我方胜利，该支援对 +1 点
##支援等级 C/B/A 不自动提升——支援值达下一级门槛后，两人相邻时行动菜单出现"支援"项，
##触发支援对话主动升级（见 battle_map_interaction.do_support）
##支援加成（命中/回避/必杀）：属性贡献制——双方属性贡献之和 × 等级倍率，支援对象 3 格内生效

##全部支援表（新增支援对：复制 data/support/ 下 .tres 改数据，然后在此追加）
const PAIRS: Array[SupportPair] = [
	preload("res://data/support/te_isar.tres"),
]

##支援等级倍率：总加成 =（双方属性贡献之和）× 倍率（可调）
const LEVEL_SCALE := {1: 1.0, 2: 2.0, 3: 3.0}
##支援加成生效距离（支援对象须在此曼哈顿距离内）
const BONUS_RANGE := 3
##支援等级显示文字（0=未建立）
const LEVEL_TEXT := {0: "——", 1: "C", 2: "B", 3: "A"}

##pair_key -> 支援值（共同出战章节数积累）
var points := {}
##pair_key -> 支援等级（0 无 1C 2B 3A）
var levels := {}
##本关登场过的我方单位名（章节结算"共同出战"用）
var _deployed := {}


##支援对的字典键（名字排序后拼接，与传参顺序无关）
func _pair_key(a: String, b: String) -> String:
	var names := [a, b]
	names.sort()
	return "+".join(names)


##查支援表：a×b 登记过返回对应 SupportPair，否则 null
func find_pair(a: String, b: String) -> SupportPair:
	for pair in PAIRS:
		if pair.involves(a) and pair.involves(b):
			return pair
	return null


##当前支援值
func get_points(a: String, b: String) -> int:
	return points.get(_pair_key(a, b), 0)


##当前支援等级（0 无 1C 2B 3A）
func get_level(a: String, b: String) -> int:
	return levels.get(_pair_key(a, b), 0)


##支援等级显示文字（"——"/"C"/"B"/"A"）
func get_level_text(a: String, b: String) -> String:
	return LEVEL_TEXT.get(get_level(a, b), "——")


##能否触发支援升级：已登记 + 未满 A + 支援值达下一级门槛
func can_level_up(a: String, b: String) -> bool:
	var pair := find_pair(a, b)
	if pair == null:
		return false
	var level := get_level(a, b)
	if level >= 3:
		return false
	return get_points(a, b) >= pair.next_threshold(level)


##支援升级 +1 级（支援对话播放后调用），返回是否成功
func level_up(a: String, b: String) -> bool:
	if not can_level_up(a, b):
		return false
	var key := _pair_key(a, b)
	levels[key] = get_level(a, b) + 1
	return true


##增加支援值（封顶 A 级门槛，避免无意义膨胀）；未登记的对不加
func add_points(a: String, b: String, n: int) -> void:
	var pair := find_pair(a, b)
	if pair == null:
		return
	var key := _pair_key(a, b)
	points[key] = mini(get_points(a, b) + n, pair.threshold_a)


##记录我方单位本关登场（BattleManager.add_unit 调用，team==0 才记）
func mark_deployed(name: String) -> void:
	if name != "":
		_deployed[name] = true


##章节结算（我方胜利）：双方都登场过的支援对 +1 支援值，随后清空登场记录
func on_chapter_cleared() -> void:
	for pair in PAIRS:
		if _deployed.has(pair.unit_a) and _deployed.has(pair.unit_b):
			add_points(pair.unit_a, pair.unit_b, 1)
	_deployed.clear()


##章节失败：登场记录作废（不影响支援值）
func on_chapter_failed() -> void:
	_deployed.clear()


##该角色的全部支援（人物面板支援列表用）
##每项：{partner: 对方名字, level: 等级, affinity: 对方属性（图标用）}
func get_supports_of(name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for pair in PAIRS:
		if not pair.involves(name):
			continue
		var partner := pair.partner_of(name)
		result.append({
			"partner": partner,
			"level": levels.get(_pair_key(name, partner), 0),
			"affinity": pair.affinity_of(partner),
		})
	return result


##支援加成（战斗结算入口，BattleCalculator 调用）
##支援对象登场、同队、曼哈顿距离 <= BONUS_RANGE 时：各项 =（自己属性贡献 + 对方属性贡献）× 等级倍率
##多个支援对象的加成累加；units 为当前地图全部单位，空数组 = 视为无支援（旧调用兼容）
func get_support_bonus(unit: Unit, units: Array) -> Dictionary:
	var bonus := {"hit": 0, "avoid": 0, "crit": 0}
	if unit == null or unit.unit_name == "" or units.is_empty():
		return bonus
	for pair in PAIRS:
		if not pair.involves(unit.unit_name):
			continue
		var level := get_level(unit.unit_name, pair.partner_of(unit.unit_name))
		if level <= 0:
			continue
		var partner := _find_unit_by_name(units, pair.partner_of(unit.unit_name))
		if partner == null or partner.team != unit.team:
			continue
		if _manhattan(unit.cell, partner.cell) > BONUS_RANGE:
			continue
		var scale: float = LEVEL_SCALE.get(level, 0.0)
		var self_aff: Affinity = pair.affinity_of(unit.unit_name)
		var other_aff: Affinity = pair.affinity_of(partner.unit_name)
		if self_aff == null or other_aff == null:
			continue
		bonus["hit"] += int((self_aff.hit_bonus + other_aff.hit_bonus) * scale)
		bonus["avoid"] += int((self_aff.avoid_bonus + other_aff.avoid_bonus) * scale)
		bonus["crit"] += int((self_aff.crit_bonus + other_aff.crit_bonus) * scale)
	return bonus


##按名字在地图单位中查找（支援对象必须登场才有加成）
func _find_unit_by_name(units: Array, name: String) -> Unit:
	for u in units:
		var unit := u as Unit
		if unit != null and unit.unit_name == name:
			return unit
	return null


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)
