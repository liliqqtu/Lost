extends Node

const CASES := ["party_funds", "deferred_items", "fe8_item_catalog", "shop", "campaign_save", "regressions", "allied_turns", "runner", "item_lifecycle", "attack_range_union",
	"battle_sequence", "battle_forecast", "enemy_ai", "canto", "rescue", "phase_end",
	"bm_public_api", "level_system", "convoy_event", "support", "unified_skills", "save_system", "battle_animation", "battle_animation_resources"]

func _ready() -> void:
	var failures := 0
	SaveManagerClass.storage_directory = "res://tests/.runtime_saves/suite"
	var cases: Array = Array(OS.get_cmdline_user_args())
	if cases.is_empty():
		cases.assign(CASES)
	for case_name in cases:
		print("SUITE START: ", case_name)
		SaveManager.activate_game_data({})
		var script = load("res://tests/test_%s.gd" % case_name)
		if script == null or not script.can_instantiate():
			get_tree().quit(1)
			return
		var test = script.new()
		var result := [-1]
		test.set_meta("suite", true)
		test.completed.connect(func(code: int): result[0] = code)
		add_child(test)
		var started := Time.get_ticks_msec()
		var timeout_ms := 180000 if case_name == "battle_animation_resources" else 30000
		while result[0] == -1 and Time.get_ticks_msec() - started < timeout_ms:
			await get_tree().process_frame
		if result[0] != 0:
			push_error("SUITE FAILED: %s (code %d)" % [case_name, result[0]])
			failures += 1
		test.queue_free()
		await get_tree().process_frame
		print("SUITE PASS: " if result[0] == 0 else "SUITE FAIL: ", case_name)
	print("SUITE ALL PASSED" if failures == 0 else "SUITE FAILURES: %d" % failures)
	get_tree().quit(1 if failures else 0)
