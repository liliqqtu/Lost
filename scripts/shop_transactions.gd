class_name ShopTransactions
extends RefCounted
## 只负责交易：库存模板只读，成功交付后才扣款。

var wallet: Dictionary
var convoy: Object

func _init(p_wallet: Dictionary, p_convoy: Object = null) -> void:
	wallet = p_wallet
	convoy = p_convoy

static func buy_price(item: Item) -> int:
	return maxi(item.buy_price, 0) if item != null else 0

static func sell_price(item: Item) -> int:
	if item == null or not item.can_sell:
		return 0
	var price := buy_price(item)
	if item is Weapon:
		price = _used_price(price, (item as Weapon).durability, (item as Weapon).max_durability)
	elif item is Consumable:
		price = _used_price(price, (item as Consumable).durability, (item as Consumable).max_durability)
	elif item.max_uses > 0:
		price = floori(float(price) * clampi(item.remaining_uses, 0, item.max_uses) / item.max_uses)
	return floori(price / 2.0)

static func _used_price(price: int, remaining: int, maximum: int) -> int:
	return floori(float(price) * clampi(remaining, 0, maximum) / maximum) if maximum > 0 else 0

func gold() -> int:
	return maxi(int(wallet.get("gold", 0)), 0)

func purchase(unit: Unit, template: Item, send_to_convoy := false) -> StringName:
	var price := buy_price(template)
	if template == null or price <= 0:
		return &"unavailable"
	if gold() < price:
		return &"funds"
	if send_to_convoy:
		if convoy == null:
			return &"no_convoy"
		if convoy.get_current_items() >= convoy.MAX_ITEMS:
			return &"convoy_full"
	elif unit == null or unit.inventory.size() >= Unit.BAG_LIMIT:
		return &"bag_full"
	var instance := template.duplicate(true) as Item
	var accepted: bool = convoy.add(instance) if send_to_convoy else unit.add_item(instance)
	if not accepted:
		return &"convoy_full" if send_to_convoy else &"bag_full"
	wallet["gold"] = gold() - price
	return &"ok"

func sell(unit: Unit, item: Item) -> StringName:
	if unit == null or item == null or not unit.inventory.has(item):
		return &"missing"
	var price := sell_price(item)
	if price <= 0:
		return &"unsellable"
	if not unit.remove_item(item):
		return &"missing"
	wallet["gold"] = gold() + price
	return &"ok"
