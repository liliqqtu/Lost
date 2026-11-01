class_name SaveManagerClass
extends Node

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


##获取存档物理路径
static func get_slot_path(slot_id: int) -> String:
	return SAVE_PATH_TEMPLATE % slot_id


##检测指定槽位是否存在有效存档
static func has_save(slot_id: int) -> bool:
	var path := get_slot_path(slot_id)
	return FileAccess.file_exists(path)


##读取槽位摘要元数据（用于存档界面卡片渲染）
static func get_slot_meta(slot_id: int) -> Dictionary:
	var path := get_slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return {
			"slot_id": slot_id,
			"is_empty": true
		}

	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return {
			"slot_id": slot_id,
			"is_empty": true,
			"error": "无法读取文件"
		}

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_str)
	if err != OK or not (json.data is Dictionary):
		return {
			"slot_id": slot_id,
			"is_empty": true,
			"error": "存档损坏"
		}

	var data: Dictionary = json.data
	data["is_empty"] = false
	data["slot_id"] = slot_id
	return data


##全量保存至指定槽位
func save_to_slot(slot_id: int, data: Dictionary) -> bool:
	if slot_id < 1 or slot_id > MAX_SLOTS:
		push_error("SaveManager: 无效槽位 ID %d" % slot_id)
		return false

	var path := get_slot_path(slot_id)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: 无法写入存档文件: %s" % path)
		return false

	data["slot_id"] = slot_id
	data["timestamp"] = Time.get_datetime_string_from_system()

	var json_str := JSON.stringify(data, "  ")
	file.store_string(json_str)
	file.close()

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
	return active_game_data


##删除指定槽位存档
func delete_slot(slot_id: int) -> bool:
	var path := get_slot_path(slot_id)
	if FileAccess.file_exists(path):
		var err := DirAccess.remove_absolute(path)
		if err == OK:
			if current_slot == slot_id:
				active_game_data.clear()
			slot_updated.emit(slot_id)
			return true
		else:
			push_error("SaveManager: 删除存档失败 %s, 错误码: %d" % [path, err])
			return false
	return true


##开始新游戏并初始化指定槽位
func start_new_game(slot_id: int) -> Dictionary:
	var initial_data: Dictionary = {
		"version": 1,
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
		"convoy": []
	}

	save_to_slot(slot_id, initial_data)
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
