extends "res://tests/test_case.gd"
## 通过 tests/test_suite.tscn 或 test_shop.tscn 运行。
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	for kind in 3:
		for item_id in ShopCatalog.DEFAULT_STOCK[kind]:
			assert(ResourceLoader.exists("res://data/items/fe8/%s.tres" % item_id), "默认商品缺失: " + item_id)
		assert(ShopCatalog.default_stock(kind).size() == ShopCatalog.DEFAULT_STOCK[kind].size())
	var wallet := {"gold": 1000}
	var convoy = load("res://scripts/convoy_store.gd").new()
	var unit := Unit.new()
	var sword := Weapon.new()
	sword.display_name = "测试剑"
	sword.buy_price = 200
	sword.durability = 40
	sword.max_durability = 40
	var service := ShopTransactions.new(wallet, convoy)
	assert(service.purchase(unit, sword) == &"ok")
	assert(wallet.gold == 800 and unit.inventory.size() == 1)
	assert(unit.inventory[0] != sword)
	var owned := unit.inventory[0] as Weapon
	owned.durability = 20
	assert(sword.durability == 40, "不能修改模板")
	assert(ShopTransactions.sell_price(owned) == 50)
	assert(service.sell(unit, owned) == &"ok" and wallet.gold == 850)
	assert(service.sell(unit, owned) == &"missing" and wallet.gold == 850)
	for i in Unit.BAG_LIMIT:
		assert(unit.add_item(sword.duplicate(true)))
	assert(service.purchase(unit, sword) == &"bag_full" and wallet.gold == 850)
	assert(service.purchase(unit, sword, true) == &"ok" and wallet.gold == 650)
	assert(convoy.items.size() == 1 and convoy.items[0] != sword)
	while convoy.items.size() < convoy.MAX_ITEMS:
		convoy.add(sword.duplicate(true))
	assert(service.purchase(unit, sword, true) == &"convoy_full" and wallet.gold == 650)
	wallet.gold = 1
	assert(service.purchase(unit, sword) == &"funds" and wallet.gold == 1)
	var treasure := Item.new()
	treasure.buy_price = 10000
	treasure.can_sell = false
	assert(unit.remove_item_at(0))
	assert(unit.add_item(treasure))
	assert(service.sell(unit, treasure) == &"unsellable" and unit.inventory.has(treasure))
	treasure.can_sell = true
	treasure.max_uses = 3
	treasure.remaining_uses = 1
	assert(ShopTransactions.sell_price(treasure) == 1666)
	var stock: Array[Item] = [sword]
	var panel := load("res://scene/ui/shop.tscn").instantiate() as ShopPanel
	get_tree().root.add_child(panel)
	for kind in 3:
		panel.open(unit, stock, kind, wallet, convoy)
		_press(panel, "start")
		assert(panel._phase == ShopPanel.Phase.MODE)
		_press(panel, "yes")
		assert(panel._phase == ShopPanel.Phase.BUY)
		_press(panel, "yes")
		assert(panel._phase == ShopPanel.Phase.DIALOGUE)
		_press(panel, "start")
		assert(panel._phase == ShopPanel.Phase.BUY)
		_press(panel, "R")
		assert(panel.info_viewer.active)
		_press(panel, "no")
		assert(not panel.info_viewer.active)
		_press(panel, "no")
		assert(panel._phase == ShopPanel.Phase.MODE)
		_press(panel, "no")
		_press(panel, "start")
		assert(not panel.visible)
	wallet.gold = 1000
	while not unit.inventory.is_empty():
		unit.remove_item_at(0)
	panel.open(unit, stock, 0, wallet, convoy)
	_press(panel, "start")
	_press(panel, "yes")
	_press(panel, "yes")
	assert(panel._phase == ShopPanel.Phase.CONFIRM_BUY)
	_press(panel, "no")
	assert(wallet.gold == 1000 and unit.inventory.is_empty())
	_press(panel, "yes")
	_press(panel, "yes")
	assert(wallet.gold == 800 and unit.inventory.size() == 1)
	_press(panel, "start")
	_press(panel, "no")
	_press(panel, "ui_right")
	_press(panel, "yes")
	assert(panel._phase == ShopPanel.Phase.SELL)
	_press(panel, "yes")
	assert(panel._phase == ShopPanel.Phase.CONFIRM_SELL)
	_press(panel, "yes")
	assert(wallet.gold == 900 and unit.inventory.is_empty())
	panel.close()
	panel.queue_free()
	unit.free()
	convoy.free()
	await get_tree().process_frame
	print("SHOP ALL PASSED: transactions, isolation, capacities, three shop input flows")
	quit(0)

func _press(panel: ShopPanel, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	panel.handle_input(event)
