class_name SaveManagerClass
extends Node

const SNAPSHOT = preload("res://scripts/campaign_snapshot.gd")
const CODEC = preload("res://scripts/save_codec.gd")

##"""存档管理器（SaveManager）
##负责 3 槽位存档文件的读写、元数据读取、删除与新游戏初始化。
##物理文件存储于 user://save_slot_{1,2,3}.json。
##作为 Autoload 单例运行。"""

signal slot_updated(slot_id: int)

const MAX_SLOTS := 3
const SAVE_PATH_TEMPLATE := "user://save_slot_%d.json"

##当前会话使用的槽位
var current_slot: int = 1
##当前加载的存档数据缓存
var active_game_data: Dictionary = {}
var pending_restore: Dictionary = {}
var fallen_units: Array = []
## 全军共用资金；商店可持有此字典，测试可注入独立钱包。
var party_funds: Dictionary = {"gold": 0}
var _play_base := 0
var _play_started := Time.get_ticks_msec()
## 测试必须显式覆盖存储目录，避免读写玩家槽位。
static var storage_directory := "user://"


##获取存档物理路径
static func get_slot_path(slot_id: int) -> String:
	return storage_directory.path_join("save_slot_%d.json" % slot_id)


##检测指定槽位是否存在有效存档
static func has_save(slot_id: int) -> bool:
	return not get_slot_meta(slot_id).get("is_empty", true)


## 主文件损坏时尝试上一份完整备份，不接受任意 JSON 字典。
static func get_slot_meta(slot_id: int) -> Dictionary:
	if slot_id < 1 or slot_id > MAX_SLOTS:
		return {"slot_id": slot_id, "is_empty": true, "error": "无效槽位"}
	var path := get_slot_path(slot_id)
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var file := FileAccess.open(candidate, FileAccess.READ)
		if file == null:
			continue
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error != OK or not json.data is Dictionary or not _valid_data(json.data):
			continue
		var data: Dictionary = json.data
		if not data.has("chapter_scene"):
			data["chapter_scene"] = SNAPSHOT.CHAPTERS.get(data.chapter_id, {}).get("scene", "")
		data["is_empty"] = false
		data["slot_id"] = slot_id
		return data
	return {"slot_id": slot_id, "is_empty": true}


static func _valid_data(data: Dictionary) -> bool:
	if int(data.get("version", 0)) not in [1, 2] or not data.get("chapter_id") is String:
		return false
	if int(data.version) == 1:
		return data.chapter_id == "cleared" or SNAPSHOT.CHAPTERS.has(data.chapter_id)
	if data.get("save_kind") not in ["new_game", "chapter_start", "battle", "cleared"]:
		return false
	if not data.get("convoy", []) is Array or not data.get("support", {}) is Dictionary:
		return false
	if data.save_kind == "battle":
		if not data.get("units") is Array or not data.get("cursor") is Dictionary:
			return false
		for record in data.units:
			if not record is Dictionary or not record.get("id") is String or not record.get("fields") is Dictionary or not record.get("cell") is Dictionary:
				return false
	return true


##全量保存至指定槽位
func save_to_slot(slot_id: int, data: Dictionary) -> bool:
	if slot_id < 1 or slot_id > MAX_SLOTS:
		push_error("SaveManager: 无效槽位 ID %d" % slot_id)
		return false

	var path := get_slot_path(slot_id)
	DirAccess.make_dir_recursive_absolute(storage_directory)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if not file:
		push_error("SaveManager: 无法写入存档文件: %s" % path)
		return false

	data["slot_id"] = slot_id
	data["timestamp"] = Time.get_datetime_string_from_system()

	var json_str := JSON.stringify(data, "  ")
	file.store_string(json_str)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false
	if FileAccess.file_exists(path):
		var previous := FileAccess.open(path, FileAccess.READ)
		var previous_json := JSON.new()
		var valid_previous := previous != null and previous_json.parse(previous.get_as_text()) == OK and previous_json.data is Dictionary and _valid_data(previous_json.data)
		if previous != null:
			previous.close()
		if valid_previous and DirAccess.copy_absolute(path, path + ".bak") != OK:
			return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		return false

	current_slot = slot_id
	active_game_data = data.duplicate(true)
	slot_updated.emit(slot_id)
	return true


##从指定槽位读取全量数据
func load_from_slot(slot_id: int) -> Dictionary:
	var meta := get_slot_meta(slot_id)
	if meta.get("is_empty", true):
		return {}

	current_slot = slot_id
	active_game_data = meta.duplicate(true)
	activate_game_data(active_game_data)
	return active_game_data.duplicate(true)

func activate_game_data(data: Dictionary) -> void:
	pending_restore = data.duplicate(true)
	party_funds = {"gold": maxi(0, int(data.get("gold", 0)))}
	fallen_units = data.get("fallen", []).duplicate()
	ConvoyStore.reset_state(CODEC.decode(data.get("convoy", [])))
	SupportStore.reset_state(data.get("support", {}))
	_play_base = int(data.get("play_time_seconds", 0))
	_play_started = Time.get_ticks_msec()

func play_time_seconds() -> int:
	return _play_base + int((Time.get_ticks_msec() - _play_started) / 1000)

func restore_level(level: Node) -> bool:
	if pending_restore.is_empty() or pending_restore.get("chapter_scene") != level.scene_file_path:
		return false
	var data := pending_restore
	pending_restore = {}
	var resumed := SNAPSHOT.restore(level, data)
	# 场景装配可能添加默认仓库/支援；加载的数据必须覆盖它们。
	if data.get("version", 1) >= 2 and data.get("save_kind") != "new_game":
		ConvoyStore.reset_state(CODEC.decode(data.get("convoy", [])))
		SupportStore.reset_state(data.get("support", {}))
		if not resumed:
			for unit in level.battle_manager.units:
				if unit.team == 0:
					SupportStore.mark_deployed(unit.unit_name)
	return resumed

func save_level(level: Node) -> bool:
	if level.battle_manager.phase != 0 or level.battle_manager.battle_over:
		return false
	if level.battle_manager.state not in [BattleManager.State.CURSOR, BattleManager.State.ACTION_MENU]:
		return false
	return save_to_slot(current_slot, SNAPSHOT.capture(level))

func advance_chapter(level: Node) -> bool:
	var data := SNAPSHOT.next_chapter(level)
	var saved := save_to_slot(current_slot, data)
	activate_game_data(data)
	return saved


##删除指定槽位存档
func delete_slot(slot_id: int) -> bool:
	if slot_id < 1 or slot_id > MAX_SLOTS:
		return false
	var path := get_slot_path(slot_id)
	for candidate in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(candidate) and DirAccess.remove_absolute(candidate) != OK:
			return false
	if current_slot == slot_id:
		active_game_data.clear()
	slot_updated.emit(slot_id)
	return true


##开始新游戏并初始化指定槽位
func start_new_game(slot_id: int) -> Dictionary:
	if slot_id < 1 or slot_id > MAX_SLOTS:
		return {}
	var initial_data: Dictionary = {
		"version": 2,
		"save_kind": "new_game",
		"slot_id": slot_id,
		"is_empty": false,
		"chapter_id": "level_0",
		"chapter_scene": "res://scene/level/level_0/level_0.tscn",
		"chapter_name": "序章 一寸之遥的呼吸",
		"protagonist_name": "忒",
		"protagonist_level": 1,
		"protagonist_class": "游牧民",
		"play_time_seconds": 0,
		"turn_count": 1,
		"difficulty": "普通",
		"party": [],
		"convoy": [],
		"gold": 0
	}

	if not save_to_slot(slot_id, initial_data):
		return {}
	activate_game_data(initial_data)
	return initial_data


##游玩时间格式化 (00:00 或 H:MM.SS)
static func format_play_time(seconds: int) -> String:
	var hours := seconds / 3600
	var mins := (seconds % 3600) / 60
	var secs := seconds % 60
	if hours > 0:
		return "%d:%02d.%02d" % [hours, mins, secs]
	else:
		return "%02d:%02d" % [mins, secs]
