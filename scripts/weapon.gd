##"""武器（继承 Item）
##所有武器共有字段（might/hit/crit/weight/range/durability）在 Weapon 上，
##公共字段（display_name/icon/description）走 Item 基类。
##武器命名规范化：原来 weapon_name 字段统一改用 display_name（Item 基类字段）"""
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

func is_weapon() -> bool: return true

##"""消耗一点耐久（每次实际打击调用，含未命中），归零返回 true 表示武器损坏"""
func consume_durability() -> bool:
	durability = maxi(durability - 1, 0)
	return durability <= 0
