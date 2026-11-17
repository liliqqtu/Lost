extends "res://tests/test_case.gd"

## Full catalog loading, convoy categories, JSON save roundtrip and template isolation.
const CODEC = preload("res://scripts/save_codec.gd")
const STORE = preload("res://scripts/convoy_store.gd")
const CATALOG := "res://data/items/fe8/"

func _ready() -> void:
	var convoy := STORE.new()
	var categories := {}
	var names := {}
	var count := 0
	for filename in DirAccess.get_files_at(CATALOG):
		if not filename.ends_with(".tres"):
			continue
		var template := load(CATALOG + filename) as Item
		assert(template != null, "Cannot load " + filename)
		assert(template.icon != null and template.icon.get_size() == Vector2(16, 16))
		assert(not template.display_name.is_empty() and not template.description.is_empty())
		assert(not names.has(template.item_id), "Duplicate item id: " + str(template.item_id))
		names[template.item_id] = true
		assert(template.original_id > 0 and template.max_uses > 0)
		assert(template.buy_price >= 0)
		var item := template.duplicate(true) as Item
		assert(convoy.add(item))
		categories[STORE.category_of(item)] = true
		var restored := CODEC.decode(JSON.parse_string(JSON.stringify(CODEC.encode(item)))) as Item
		assert(restored != null and restored != item)
		assert(restored.item_id == item.item_id and restored.item_kind == item.item_kind)
		assert(restored.buy_price == item.buy_price and restored.can_sell == item.can_sell)
		assert(restored.effect_id == item.effect_id and restored.effect_implemented == item.effect_implemented)
		assert(restored.max_uses == item.max_uses and restored.remaining_uses == item.remaining_uses)
		assert(restored.original_data == item.original_data)
		if item is Weapon:
			assert(restored is Weapon)
			assert(restored.weapon_type == item.weapon_type and restored.max_durability == item.max_durability)
			assert(item.min_range >= 1 and item.max_range >= item.min_range)
			item.consume_durability()
			assert(item.durability == template.durability - 1)
			assert(template.durability == template.max_durability)
		else:
			assert(not item.is_consumable(), "Deferred item must not invoke existing healing logic")
			item.remaining_uses -= 1
			assert(template.remaining_uses == template.max_uses)
		count += 1
	assert(count == 138, "Catalog count: %d" % count)
	assert(categories.size() == 9, "All nine convoy categories must be represented")
	assert(convoy.get_current_items() == count)
	var heal := load(CATALOG + "heal.tres") as Weapon
	var mend := load(CATALOG + "mend.tres") as Weapon
	assert(heal.might == 10 and heal.effect_implemented)
	assert(mend.might == 20 and mend.effect_implemented)
	var warp := load(CATALOG + "warp.tres") as Weapon
	assert(not warp.effect_implemented and not warp.effect_id.is_empty())
	var gem := load(CATALOG + "white_gem.tres") as Item
	assert(gem.buy_price == 20000 and gem.can_sell)
	var unit := Unit.new()
	for i in Unit.BAG_LIMIT:
		assert(unit.add_item(heal.duplicate(true)))
	assert(not unit.add_item(heal.duplicate(true)))
	unit.free()
	convoy.free()
	print("FE8_ITEM_CATALOG_PASS: 138 resources; 9 convoy categories; JSON roundtrips; isolated templates")
	quit(0)
