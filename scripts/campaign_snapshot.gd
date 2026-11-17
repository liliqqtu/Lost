extends RefCounted

const CODEC = preload("res://scripts/save_codec.gd")

const CHAPTERS = {
	"level_0": {"scene": "res://scene/level/level_0/level_0.tscn", "title": "序章 一寸之遥的呼吸"},
	"level_1": {"scene": "res://scene/level/level_1/level_1.tscn", "title": "第一章 向崖底纵跃之人"},
}

static func chapter_id(scene: String) -> String:
	return scene.get_file().get_basename()

static func all_units(level: Node) -> Array[Unit]:
	var result: Array[Unit] = []
	for node in level.units_node.find_children("*", "", true, false):
		if node is Unit and not node.is_queued_for_deletion():
			result.append(node)
	return result

static func unit_key(level: Node, unit: Unit) -> String:
	return str(unit.unit_id) if unit.unit_id != &"" else str(level.units_node.get_path_to(unit))

static func capture(level: Node) -> Dictionary:
	var bm = level.battle_manager
	var records: Array = []
	for unit in all_units(level):
		var record = CODEC.unit_state(unit)
		record.merge({"id": unit_key(level, unit), "cell": CODEC.encode(unit.cell),
			"visible": unit.visible, "registered": bm.units.has(unit),
			"carried": unit_key(level, unit.carried_unit) if is_instance_valid(unit.carried_unit) else ""})
		records.append(record)
	var events: Array = []
	for event in bm.phases.map_events:
		events.append(event.done)
	var interactables = {}
	for node in level.get_tree().get_nodes_in_group("interactables"):
		if level.is_ancestor_of(node):
			interactables[str(level.get_path_to(node))] = node.used
	var id = chapter_id(level.scene_file_path)
	var data = {"version": 2, "save_kind": "battle", "chapter_id": id,
		"chapter_scene": level.scene_file_path, "chapter_name": CHAPTERS.get(id, {}).get("title", id),
		"turn_count": bm.turn, "units": records, "events": events, "interactables": interactables,
		"boss_quotes": bm._boss_quotes_played.duplicate(), "cursor": CODEC.encode(bm.cursor.cell),
		"selection": bm.save_selection_context(unit_key(level, bm.selected_unit) if is_instance_valid(bm.selected_unit) else ""), "convoy": CODEC.encode(ConvoyStore.items),
		"support": SupportStore.export_state(), "fallen": SaveManager.fallen_units.duplicate(),
		"play_time_seconds": SaveManager.play_time_seconds(), "difficulty": "普通"}
	data["gold"] = maxi(0, int(SaveManager.party_funds.get("gold", 0)))
	for unit in bm.units:
		if unit.unit_id == &"te":
			data.merge({"protagonist_name": unit.unit_name, "protagonist_level": unit.lv,
				"protagonist_class": unit.class_data.job_name if unit.class_data else ""})
	return data

static func next_chapter(level: Node) -> Dictionary:
	var data = capture(level)
	data.save_kind = "chapter_start" if level.get_next_chapter_path() != "" else "cleared"
	data.chapter_scene = level.get_next_chapter_path()
	data.chapter_id = chapter_id(data.chapter_scene) if data.chapter_scene != "" else "cleared"
	data.chapter_name = level.get_next_chapter_title() if data.chapter_scene != "" else "已通关"
	data.turn_count = 1
	data["party"] = []
	for record in data.units:
		if int(record.fields.team) == 0:
			data.party.append(record)
	for field in ["units", "events", "interactables", "boss_quotes", "selection"]:
		data.erase(field)
	return data

static func restore(level: Node, data: Dictionary) -> bool:
	if data.get("save_kind") != "battle":
		_apply_party(level, data)
		return false
	var bm = level.battle_manager
	var existing = {}
	for unit in all_units(level):
		existing[unit_key(level, unit)] = unit
	bm.units.clear()
	var restored = {}
	for record in data.units:
		var unit: Unit = existing.get(record.id)
		if unit == null:
			var path: String = record.get("scene", "")
			var packed = load(path) if path != "" and ResourceLoader.exists(path) else load("res://scene/character/unit.tscn")
			unit = packed.instantiate()
			level.units_node.add_child(unit)
		existing.erase(record.id)
		CODEC.apply_unit(unit, record)
		unit.cell = CODEC.decode(record.cell)
		unit.global_position = Vector2(unit.cell) * Global.TILE_SIZE
		unit.visible = record.visible
		unit.carried_by = null
		unit.carried_unit = null
		unit.rescue = false
		restored[record.id] = unit
		if record.registered:
			bm.units.append(unit)
	for unit in existing.values():
		unit.get_parent().remove_child(unit)
		unit.queue_free()
	for record in data.units:
		var unit: Unit = restored[record.id]
		var carried: Unit = restored.get(record.get("carried", ""))
		if carried != null:
			unit.carried_unit = carried
			carried.carried_by = unit
			carried.rescue = true
	for i in mini(bm.phases.map_events.size(), data.get("events", []).size()):
		bm.phases.map_events[i].done = data.events[i]
	for path in data.get("interactables", {}):
		var node = level.get_node_or_null(NodePath(path))
		if node is Interactable:
			node.used = data.interactables[path]
	bm._boss_quotes_played = data.get("boss_quotes", {}).duplicate()
	bm.turn = int(data.turn_count)
	bm.cursor.set_cell(CODEC.decode(data.cursor))
	bm.restore_selection_context(data.get("selection", {}), restored)
	return true

static func _apply_party(level: Node, data: Dictionary) -> void:
	var party = {}
	for record in data.get("party", []):
		party[record.id] = record
	for unit in all_units(level):
		if unit.unit_id == &"":
			continue
		if SaveManager.fallen_units.has(str(unit.unit_id)):
			level.battle_manager.units.erase(unit)
			unit.get_parent().remove_child(unit)
			unit.queue_free()
		elif party.has(str(unit.unit_id)):
			CODEC.apply_unit(unit, party[str(unit.unit_id)])
			unit.hp = unit.max_hp
			unit.reset_turn_state()
			unit.update_hp_bar()
			SupportStore.mark_deployed(unit.unit_name)
