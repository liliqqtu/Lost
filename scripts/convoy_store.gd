extends Node
##"""运输队全局仓库（autoload，跨章节持久）
##所有物品扁平存储；类别是查询时映射出来的，不侵入存储层。
##注意：同一 .tres 模板多次加入运输队时，必须对每个实例 duplicate()，
##否则多个槽位引用同一 Resource，耐久等状态会互相污染。
##注意：不能写 class_name ConvoyStore——与 project.godot 里的同名 autoload 冲突，
##Godot 会报 "Class hides an autoload singleton"。全局访问直接用 ConvoyStore 单例名。"""

const MAX_ITEMS := 200
var current_items := 0
## 界面图标顺序（与 convoy.tscn 的 ItemIconClass 子节点顺序一致）
## 剑 / 斧 / 枪 / 弓 / 杖 / 理 / 光 / 暗 / 杂物
enum Category {
	SWORD,
	AXE,
	LANCE,
	BOW,
	STAFF,
	ANIMA,
	LIGHT,
	DARK,
	ITEM
}

## 所有物品（扁平存储）
var items: Array[Item] = []


## 根据物品类型判断它属于哪一类图标
static func category_of(item: Item) -> int:
	if item.is_weapon():
		var w: Weapon = item as Weapon
		match w.weapon_type:
			Weapon.WeaponType.SWORD: return Category.SWORD
			Weapon.WeaponType.AXE:   return Category.AXE
			Weapon.WeaponType.LANCE: return Category.LANCE
			Weapon.WeaponType.BOW:   return Category.BOW
			Weapon.WeaponType.STAFF: return Category.STAFF
			Weapon.WeaponType.ANIMA: return Category.ANIMA
			Weapon.WeaponType.LIGHT: return Category.LIGHT
			Weapon.WeaponType.DARK:  return Category.DARK
	return Category.ITEM


## 添加物品；运输队满时返回 false
func add(item: Item) -> bool:
	if items.size() >= MAX_ITEMS:
		return false
	items.append(item)
	current_items += 1
	return true


## 按引用移除物品（每个物品实例唯一，直接 erase 安全）
func remove_item(item: Item) -> void:
	items.erase(item)
	current_items -= 1

func get_current_items() -> int:
	current_items = items.size()
	return current_items


## 返回某一类的所有物品（按加入顺序）
func items_in(cat: int) -> Array[Item]:
	var result: Array[Item] = []
	for item in items:
		if category_of(item) == cat:
			result.append(item)
	return result


## 当前类别数量（UI 角标用）
func count_in(cat: int) -> int:
	var n := 0
	for item in items:
		if category_of(item) == cat:
			n += 1
	return n
