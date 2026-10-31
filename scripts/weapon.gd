##"""武器（继承 Item）
##所有武器共有字段（might/hit/crit/weight/range/durability）在 Weapon 上，
##公共字段（display_name/icon/description）走 Item 基类。
##支持附加技能列表、属性增益与勇者连击特性（统一技能体系）。"""
class_name Weapon extends Item

## 武器类型枚举 分别是剑、枪、斧、弓、魔法（理）、魔法（暗）、魔法（光）、杖
enum WeaponType {
	SWORD,
	LANCE,
	AXE,
	BOW,
	ANIMA,
	DARK,
	LIGHT,
	STAFF
}

##"""武器等级（升级系统，FE8）：UNUSABLE=职业不可用该类型，E..S 为可用等级"""
enum WeaponRank { UNUSABLE = -1, E = 0, D = 1, C = 2, B = 3, A = 4, S = 5 }

##"""武器经验累计阈值（FE8 原版数据）：达到该值升到对应等级，索引=等级"""
const WEXP_THRESHOLDS := [1, 31, 71, 121, 181, 251]

##"""累计武器经验 -> 等级（-1 不可用/未入门），超过 S 阈值封顶 S"""
static func wexp_to_rank(xp: int) -> int:
	var rank := WeaponRank.UNUSABLE
	for i in WEXP_THRESHOLDS.size():
		if xp >= WEXP_THRESHOLDS[i]:
			rank = i
	return rank


##"""等级 -> 显示文字（-1 显示 ——）"""
static func rank_to_text(rank: int) -> String:
	const TEXTS := ["——", "E", "D", "C", "B", "A", "S"]
	if rank < WeaponRank.UNUSABLE or rank > WeaponRank.S:
		return "——"
	return TEXTS[rank + 1]


## 使用该武器所需的武器等级（铁剑=E）
@export var required_rank: WeaponRank = WeaponRank.E
##"""每次命中获得的该类武器经验（FE8 数据：铁剑/铁弓=1，铁刃剑/银刃剑=2 等）"""
@export var weapon_exp := 1

## 武器类型
@export var weapon_type: WeaponType = WeaponType.SWORD
## 武器伤害值
@export var might := 5
## 武器命中率
@export var hit := 100
## 武器暴击率
@export var crit := 0
## 武器重量
@export var weight := 5
## 武器耐久度
@export var durability := 40
## 武器最大耐久（人物面板显示用，如 40/40）
@export var max_durability := 40
## 武器最小攻击范围
@export var min_range := 1
## 武器最大攻击范围
@export var max_range := 1

## 武器附加技能列表（统一技能体系：武器/人物/职业共享技能资源）
@export var skills: Array[Skill] = []
## 武器附加属性修正（如 S 弓 +10 技 +10 速）
@export var stat_modifiers: Dictionary = {}
@export var bonus_str: int = 0
@export var bonus_mag: int = 0
@export var bonus_skl: int = 0
@export var bonus_spd: int = 0
@export var bonus_def: int = 0
@export var bonus_res: int = 0
@export var bonus_luk: int = 0
@export var bonus_con: int = 0
@export var bonus_move: int = 0
## 是否为勇者武器（连续攻击）
@export var is_brave: bool = false

func is_weapon() -> bool: return true

##"""消耗一点耐久（每次实际打击调用，含未命中），归零返回 true 表示武器损坏"""
func consume_durability() -> bool:
	durability = maxi(durability - 1, 0)
	return durability <= 0


## 取得武器自身的直接属性修正（附带技能加成统一由 Unit 在 get_all_active_skills 中汇系统计，避免双重累加）
func get_stat_bonus(stat_name: String) -> int:
	var from_dict: int = stat_modifiers.get(stat_name, 0) as int
	var from_field := 0
	match stat_name:
		"str": from_field = bonus_str
		"mag": from_field = bonus_mag
		"skl": from_field = bonus_skl
		"spd": from_field = bonus_spd
		"def_h": from_field = bonus_def
		"res": from_field = bonus_res
		"luk": from_field = bonus_luk
		"con": from_field = bonus_con
		"move": from_field = bonus_move
	## 优先使用显式填写的字典值，未配置字典时回落到独立字段，避免两者同时存在时重复累加
	var total := from_dict if from_dict != 0 else from_field
	##针对断弦（snapped_string_bow）兜底：+10 技 +10 速
	if item_id == &"snapped_string_bow" or display_name == "断弦":
		if (stat_name == "skl" or stat_name == "spd") and total == 0:
			total = 10
	return total


## 是否具有勇者武器连续攻击特性
func is_brave_weapon() -> bool:
	if is_brave or item_id == &"brave_bow" or display_name.contains("勇者"):
		return true
	for s in skills:
		if s != null and (s.is_brave or s.skill_id == &"brave"):
			return true
	return false


## 获取武器附带技能列表（针对断弦兜底附加“笃行”）
func get_skills() -> Array[Skill]:
	var list: Array[Skill] = skills.duplicate()
	if item_id == &"snapped_string_bow" or display_name == "断弦":
		var has_advance := false
		for s in list:
			if s != null and s.skill_id == &"relentless_advance":
				has_advance = true
				break
		if not has_advance:
			var adv = load("res://data/skills/relentless_advance.tres")
			if adv is Skill:
				list.append(adv)
	return list
