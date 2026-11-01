extends SceneTree

func _init() -> void:
	print("--- Running SaveManager Integration Tests ---")

	var sm := SaveManagerClass.new()
	var test_slot := 3

	# 1. 确保初始清理
	sm.delete_slot(test_slot)
	var meta_empty := SaveManagerClass.get_slot_meta(test_slot)
	assert(meta_empty.get("is_empty", false) == true, "Slot 3 should be empty initially")
	print("[PASS] Initial empty check passed.")

	# 2. 新建游戏初始化
	var init_data := sm.start_new_game(test_slot)
	assert(init_data.get("slot_id") == test_slot, "Slot ID mismatch")
	assert(init_data.get("protagonist_name") == "忒", "Protagonist name mismatch")
	assert(init_data.get("chapter_name") == "序章 一寸之遥的呼吸", "Chapter name mismatch")
	print("[PASS] Start new game initialization passed.")

	# 3. 读取元数据验证
	var meta_saved := SaveManagerClass.get_slot_meta(test_slot)
	assert(meta_saved.get("is_empty") == false, "Slot 3 should not be empty")
	assert(meta_saved.get("protagonist_name") == "忒", "Saved protagonist name mismatch")
	print("[PASS] Get slot meta passed.")

	# 4. 加载全量数据
	var loaded := sm.load_from_slot(test_slot)
	assert(loaded.get("slot_id") == test_slot, "Loaded slot ID mismatch")
	assert(sm.current_slot == test_slot, "Current slot should be 3")
	print("[PASS] Load from slot passed.")

	# 5. 删除存档
	var deleted := sm.delete_slot(test_slot)
	assert(deleted == true, "Deletion should succeed")
	var meta_after := SaveManagerClass.get_slot_meta(test_slot)
	assert(meta_after.get("is_empty") == true, "Slot should be empty after deletion")
	print("[PASS] Delete slot passed.")

	# 6. 时间格式化测试
	var time_str1 := SaveManagerClass.format_play_time(125) # 2m 5s -> 02:05
	var time_str2 := SaveManagerClass.format_play_time(3665) # 1h 1m 5s -> 1:01.05
	assert(time_str1 == "02:05", "Format play time 125s expected '02:05', got '%s'" % time_str1)
	assert(time_str2 == "1:01.05", "Format play time 3665s expected '1:01.05', got '%s'" % time_str2)
	print("[PASS] Format play time passed.")

	sm.free()
	print("--- All SaveManager Tests Passed! ---")
	quit(0)
