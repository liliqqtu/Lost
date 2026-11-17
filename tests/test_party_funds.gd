extends "res://tests/test_case.gd"

const SNAPSHOT = preload("res://scripts/campaign_snapshot.gd")

class QuietPrologue extends "res://scene/level/level_0/level_0.gd":
	func _start_level_flow() -> void:
		pass

var failures := 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func _ready() -> void:
	var old_directory := SaveManagerClass.storage_directory
	SaveManagerClass.storage_directory = "res://tests/.runtime_saves/party_funds"
	SaveManager.activate_game_data({})
	check(SaveManager.party_funds.gold == 0, "legacy saves default to zero gold")
	SaveManager.party_funds.gold = 12345
	var level = load("res://scene/level/level_0/level_0.tscn").instantiate()
	level.set_script(QuietPrologue)
	add_child(level)
	var data := SNAPSHOT.capture(level)
	check(data.gold == 12345, "battle snapshot captures shared wallet")
	check(SaveManager.save_to_slot(3, data), "wallet snapshot saves in isolated directory")
	SaveManager.party_funds.gold = 9
	check(not SaveManager.load_from_slot(3).is_empty(), "wallet snapshot loads")
	check(SaveManager.party_funds.gold == 12345, "gold survives JSON save round trip")
	check(SNAPSHOT.next_chapter(level).gold == 12345, "gold follows chapter transitions")
	level.free()
	SaveManager.activate_game_data({"gold": -4})
	check(SaveManager.party_funds.gold == 0, "negative legacy gold is clamped")
	SaveManager.party_funds.gold = 20
	check(not SaveManager.start_new_game(3).is_empty(), "new game saves successfully")
	check(SaveManager.party_funds.gold == 0, "new game resets shared wallet")
	SaveManagerClass.storage_directory = old_directory
	quit(1 if failures else 0)
