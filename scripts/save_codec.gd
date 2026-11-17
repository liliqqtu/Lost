extends RefCounted

## JSON 边界：只重建已知物品类型，其他资源按项目内路径引用。
const UNIT_FIELDS := ["unit_id", "unit_name", "info", "team", "is_boss", "has_convoy",
	"lv", "exp", "max_hp", "hp", "str", "mag", "skl", "spd", "def_h", "res", "luk", "con", "move",
	"rank_sword", "rank_lance", "rank_axe", "rank_bow", "rank_anima", "rank_dark", "rank_light", "rank_staff",
	"status", "talk", "cmd", "class_data", "battle_frames", "personal_skills", "weapon_xp", "move_table",
	"has_acted", "canto_remaining", "relentless_advance_triggered_this_turn"]

static func encode(value: Variant) -> Variant:
	if value is Item:
		var fields := {}
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE:
				fields[property.name] = encode(value.get(property.name))
		return {"_item": "weapon" if value is Weapon else ("consumable" if value is Consumable else ("key" if value is Key else "item")), "fields": fields}
	if value is Resource:
		return {"_resource": value.resource_path}
	if value is Vector2i:
		return {"_cell": [value.x, value.y]}
	if value is Array:
		var array: Array = []
		for entry in value:
			array.append(encode(entry))
		return array
	if value is Dictionary:
		var dict := {}
		for key in value:
			dict[str(key)] = encode(value[key])
		return dict
	return str(value) if value is StringName else value

static func decode(value: Variant) -> Variant:
	if value is Array:
		var array: Array = []
		for entry in value:
			array.append(decode(entry))
		return array
	if value is Dictionary:
		if value.has("_resource"):
			var path: String = value._resource
			return load(path) if path.begins_with("res://") and ResourceLoader.exists(path) else null
		if value.has("_cell"):
			return Vector2i(int(value._cell[0]), int(value._cell[1]))
		if value.has("_item"):
			var item: Item
			match value._item:
				"weapon": item = Weapon.new()
				"consumable": item = Consumable.new()
				"key": item = Key.new()
				_: item = Item.new()
			for property in item.get_property_list():
				if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE and value.fields.has(property.name):
					_assign(item, property.name, decode(value.fields[property.name]))
			return item
		var dict := {}
		for key in value:
			dict[key] = decode(value[key])
		return dict
	return value

static func _assign(object: Object, key: String, value: Variant) -> void:
	var existing: Variant = object.get(key)
	if existing is Array and value is Array:
		# 保留 Array[Skill] 等类型，JSON 普通数组不能直接赋给它们。
		existing.clear()
		existing.assign(value)
	else:
		object.set(key, value)

static func unit_state(unit: Unit) -> Dictionary:
	var fields := {}
	for key in UNIT_FIELDS:
		fields[key] = encode(unit.get(key))
	return {"fields": fields, "inventory": encode(unit.inventory),
		"equipped": unit.inventory.find(unit.current_weapon), "scene": unit.scene_file_path}

static func apply_unit(unit: Unit, data: Dictionary) -> void:
	for key in UNIT_FIELDS:
		if not data.fields.has(key):
			continue
		var value: Variant = decode(data.fields[key])
		if key == "weapon_xp":
			var xp := {}
			for type in value:
				xp[int(type)] = int(value[type])
			value = xp
		_assign(unit, key, value)
	unit.restore_inventory(decode(data.get("inventory", [])), int(data.get("equipped", -1)))
	unit.update_hp_bar()
	if unit.has_acted:
		unit.apply_grayscale()
	else:
		unit.remove_grayscale()
