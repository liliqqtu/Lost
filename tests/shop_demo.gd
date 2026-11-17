extends Control
## F6 预览：1/2/3 切换三店；测试钱包与仓库不接玩家存档。
var _unit: Unit
var _wallet := {"gold": 20000}
var _convoy: Node
@onready var _shop: ShopPanel = $Shop

func _ready() -> void:
	_unit = Unit.new()
	_unit.unit_name = "商店测试员"
	_unit.rank_sword = Weapon.WeaponRank.S
	_unit.rank_bow = Weapon.WeaponRank.S
	_unit.rank_anima = Weapon.WeaponRank.S
	_unit.rank_staff = Weapon.WeaponRank.S
	_convoy = load("res://scripts/convoy_store.gd").new()
	_shop.closed.connect(func(): $Hint.show())
	_open_shop(0)

func _open_shop(kind: int) -> void:
	$Hint.hide()
	var stock := ShopCatalog.default_stock(kind)
	if _unit.inventory.is_empty() and not stock.is_empty():
		_unit.add_item(stock[0].duplicate(true))
	_shop.open(_unit, stock, kind, _wallet, _convoy)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_3:
			_open_shop(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if is_instance_valid(_unit):
		_unit.free()
	if is_instance_valid(_convoy):
		_convoy.free()
