class_name Key extends Item
##"""钥匙（阶段五 5E）：开启宝箱用
##key_id 与宝箱 Interactable.key_id 一一对应，开箱后钥匙损坏（从背包移除）"""

## 对应宝箱的 id（与 Interactable.key_id 相同才能开启）
@export var key_id := ""

## 类型钩子：自报家门为钥匙
func is_key() -> bool:
	return true
