##"""消耗品（如伤药、圣水等有使用次数的物品）
##耐久=剩余使用次数，每次使用扣 1，归零道具耗尽从背包移除（与武器耐久同构）"""
class_name Consumable extends Item

## 恢复 HP 量
@export var heal_hp: int = 0
## 使用次数（剩余）
@export var durability := 5
## 最大使用次数（UI 显示用，如 5/5）
@export var max_durability := 5

func is_consumable() -> bool: return true

##"""消耗一次使用次数，归零返回 true 表示道具耗尽"""
func consume_durability() -> bool:
	durability = maxi(durability - 1, 0)
	return durability <= 0
