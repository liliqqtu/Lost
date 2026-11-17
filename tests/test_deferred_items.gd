extends "res://tests/test_case.gd"

var failures := 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _ready() -> void:
	var unit := Unit.new()
	unit.rank_staff = Weapon.WeaponRank.S
	unit.weapon_xp[Weapon.WeaponType.STAFF] = 251
	var staff := Weapon.new()
	staff.weapon_type = Weapon.WeaponType.STAFF
	staff.effect_id = &"warp"
	staff.effect_implemented = false
	check(unit.add_item(staff), "deferred staff is still a carryable item")
	var action := BattleStaff.new()
	check(action.get_first_usable_staff(unit) == null, "warp cannot enter healing action")
	staff.effect_id = &"heal"
	staff.effect_implemented = true
	check(action.get_first_usable_staff(unit) == staff, "implemented heal remains usable")
	staff.effect_id = &""
	staff.effect_implemented = false
	check(action.get_first_usable_staff(unit) == staff, "legacy healing resources remain compatible")
	staff.durability = 0
	check(action.get_first_usable_staff(unit) == null, "exhausted healing staff is unusable")
	var item := Item.new()
	item.original_id = 1
	item.remaining_uses = 3
	item.max_uses = 3
	item.effect_id = &"promotion"
	unit.hp = 1
	check(unit.add_item(item), "deferred non-healing item fits the bag")
	check(not unit.use_item(item) and item.remaining_uses == 3 and unit.inventory.has(item),
		"deferred promotion item cannot accidentally heal or be consumed")
	var row = load("res://scene/ui/itemrow.tscn").instantiate()
	add_child(row)
	row.set_item(item)
	check(row.get_node("ItemDurability").visible and row.get_node("ItemDurability").text == "3/3",
		"convoy item rows display recorded uses")
	row.free()
	unit.free()
	quit(1 if failures else 0)
