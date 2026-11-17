extends "res://tests/test_case.gd"

const SNAPSHOT = preload("res://scripts/campaign_snapshot.gd")

class QuietPrologue extends "res://scene/level/level_0/level_0.gd":
	func _start_level_flow() -> void:
		pass

class QuietChapter extends "res://scene/level/level_1/level_1.gd":
	func _start_level_flow() -> void:
		pass

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
	else:
		print("PASS: ", message)

func make_level(id: String) -> Level:
	var level = load(SNAPSHOT.CHAPTERS[id].scene).instantiate()
	level.set_script(QuietPrologue if id == "level_0" else QuietChapter)
	add_child(level)
	return level

func _ready() -> void:
	SaveManagerClass.storage_directory = "res://tests/.runtime_saves/campaign"
	SaveManager.start_new_game(1)
	var level := make_level("level_0")
	var bm := level.battle_manager
	var te: Unit = level.get_node("Units/Te")
	var isar: Unit = level.get_node("Units/Isar")
	te.lv = 9
	te.exp = 44
	te.max_hp = 33
	te.hp = 12
	te.current_weapon.durability = 7
	te.weapon_xp[Weapon.WeaponType.BOW] = 193
	bm.turn = 5
	bm.phases.map_events[0].done = true
	bm.add_unit(isar)
	te.carried_unit = isar
	isar.carried_by = te
	isar.cell = Unit.OFF_MAP_CELL
	isar.visible = false
	var dead: Unit = bm.units.filter(func(u): return u.team == 1)[0]
	var dead_path := level.units_node.get_path_to(dead)
	bm.units.erase(dead)
	dead.free()
	ConvoyStore.reset_state()
	SupportStore.levels["test"] = 2
	var doors := get_tree().get_nodes_in_group("interactables")
	if not doors.is_empty():
		doors[0].used = true
	bm.selected_unit = te
	bm.state = BattleManager.State.ACTION_MENU
	bm._pre_move_cell = te.cell
	bm.mark_action_spent()
	check(level.system_ui.save_game(), "real menu save writes isolated snapshot")
	check(bm.commands.action_menu._panel.visible, "save returns to visible action menu")
	level.free()
	SaveManager.start_new_game(2)
	check(ConvoyStore.items.is_empty() and SupportStore.levels.is_empty(), "new game resets global stores")
	check(not SaveManager.load_from_slot(1).is_empty(), "saved JSON can be loaded")
	level = make_level("level_0")
	bm = level.battle_manager
	te = level.get_node("Units/Te")
	isar = level.get_node("Units/Isar")
	check(te.lv == 9 and te.exp == 44 and te.hp == 12 and bm.turn == 5, "unit growth, HP and turn restored")
	check(te.current_weapon.durability == 7 and te.inventory.has(te.current_weapon), "durability and equipped instance restored")
	check(te.weapon_xp.get(Weapon.WeaponType.BOW) == 193, "integer weapon XP keys survive JSON")
	check(te.carried_unit == isar and isar.carried_by == te and not isar.visible, "rescue links restored by ID")
	check(level.units_node.get_node_or_null(dead_path) == null, "defeated enemy stays absent")
	check(bm.phases.map_events[0].done and ConvoyStore.items.is_empty(), "event completion and deliberately empty convoy restored")
	check(SupportStore.levels.get("test") == 2 and bm.selected_unit == te and bm.is_action_spent(), "support and action menu context restored")
	check(SaveManager.advance_chapter(level), "chapter clear writes next chapter snapshot")
	var next_data := SaveManager.get_slot_meta(1)
	check(next_data.chapter_scene == SNAPSHOT.CHAPTERS.level_1.scene, "chapter clear persists loadable scene")
	level.free()
	level = make_level("level_1")
	te = level.get_node("Units/Te")
	check(te.lv == 9 and te.exp == 44 and te.current_weapon.durability == 7, "growth and items survive live chapter transition")
	check(te.hp == te.max_hp and not te.has_acted, "next chapter starts healed and ready")
	level.free()
	SaveManager.start_new_game(2)
	SaveManager.load_from_slot(1)
	level = make_level("level_1")
	te = level.get_node("Units/Te")
	check(te.lv == 9 and te.exp == 44, "chapter start restores after reload, not just live transition")
	level.free()
	SaveManager.save_to_slot(3, {"version": 1, "chapter_id": "level_1"})
	check(SaveManager.load_from_slot(3).chapter_scene == SNAPSHOT.CHAPTERS.level_1.scene, "legacy chapter ID repairs missing scene")
	SaveManager.save_to_slot(3, {"version": 1, "chapter_id": "level_0"})
	var broken := FileAccess.open(SaveManager.get_slot_path(3), FileAccess.WRITE)
	broken.store_string("broken json")
	broken.close()
	check(SaveManager.load_from_slot(3).chapter_id == "level_1", "corrupt primary recovers previous valid backup")
	SaveManager._play_base = 100
	SaveManager._play_started = Time.get_ticks_msec() - 3000
	check(SaveManager.play_time_seconds() == 103 and SaveManager.play_time_seconds() == 103, "play time reads elapsed delta without double counting")
	for slot in range(1, 4):
		SaveManager.delete_slot(slot)
	print("CAMPAIGN TEST FAILURES: ", failures)
	quit(1 if failures else 0)
