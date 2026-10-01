extends HBoxContainer
##"""物品行视图组件（图标 + 名称 + 耐久/数量）
##背包/运输队/商店等所有"列出物品"的地方都套用这个场景
##通过 set_item(item: Item) 渲染；clear() 清空（用于空槽位）"""
class_name ItemRow

@onready var _icon: TextureRect = $ItemIcon
@onready var _name_label: Label = $ItemName
@onready var _durability_label: Label = $ItemDurability

##当前渲染的物品（信息查看 get_info 用；clear 时置空）
var _item: Item = null

##"""信息查看接口（信息查看系统）：返回当前物品的说明
##优先物品资源的 description（.tres 里配置），未配置时退回显示名"""
func get_info() -> String:
	if _item == null:
		return ""
	if _item.description != "":
		return _item.description
	return _item.display_name

## 渲染一行物品（item 为 null 时清空并隐藏）
func set_item(item: Item) -> void:
	_item = item
	if item == null:
		clear()
		return
	visible = true
	_icon.texture = item.icon
	_name_label.text = item.display_name
	if item.is_weapon():
		var w: Weapon = item as Weapon
		_durability_label.text = "%d/%d" % [w.durability, w.max_durability]
		_durability_label.visible = true
	elif item.is_consumable():
		##消耗品显示使用次数（如伤药 5/5），与武器耐久同构
		var c: Consumable = item as Consumable
		_durability_label.text = "%d/%d" % [c.durability, c.max_durability]
		_durability_label.visible = true
	else:
		_durability_label.text = ""
		_durability_label.visible = false

## 清空行内容并隐藏（用于背包空槽位）
func clear() -> void:
	_item = null
	visible = false
	_icon.texture = null
	_name_label.text = ""
	_durability_label.text = ""
