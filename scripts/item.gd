extends Resource
##"""物品基类（武器/消耗品/钥匙等所有可持有物的公共父类）
##字段约定：
##  display_name —— UI 显示名（与 Skill.display_name 一致的命名习惯）
##  icon         —— 物品图标（背包/面板/战斗预览共用）
##  description  —— tooltip/描述文字
##具体子类按 is_weapon()/is_consumable() 分流；
##物品效果（伤药回血/武器相克）由子类额外字段承载，不在基类堆方法"""
class_name Item

## 唯一 ID（程序用，跨场景稳定标识，如 &"iron_bow" &"potion"）
@export var item_id: StringName
## 显示名（人物面板/UI 用）
@export var display_name: String
## 描述（tooltip 用）
@export var description: String
## 图标（背包/面板显示用，可空）
@export var icon: Texture2D

## 类型判定钩子（替代硬编码，让子类自报家门）
func is_weapon() -> bool: return false
func is_consumable() -> bool: return false
func is_key() -> bool: return false
