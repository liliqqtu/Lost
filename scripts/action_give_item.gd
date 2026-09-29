class_name ActionGiveItem extends MapAction
##"""事件动作：给单位/运输队发放物品（阶段五 5E）
##unit_name 指定的我方单位背包满时自动落入运输队"""

## 物品模板（.tres 引用，发放时 duplicate 成独立实例）
@export var item: Item
## 收件单位名（空 = 直接进运输队）
@export var unit_name := ""


func execute(ctx) -> void:
	if item == null:
		return
	##P0-2：模板 duplicate 成独立实例，避免多个单位共享 Resource
	var reward: Item = item.duplicate() as Item
	if unit_name != "":
		for u in ctx.battle_manager.units:
			if u.unit_name == unit_name:
				if u.add_item(reward):
					return
				break
	ConvoyStore.add(reward)
