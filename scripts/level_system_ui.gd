class_name LevelSystemUI
extends RefCounted

##"""关卡系统级菜单与弹窗控制器（LevelSystemUI）
##管理地图菜单（MapMenu）、保存提示吐司（Toast）与返回主菜单二次确认弹窗。
##保持 Level 基类精简并严格控制在 500 行以内。"""

const ITEMSBOX_SCENE := preload("res://scene/ui/itemsbox.tscn")
const CURSOR_HAND_SCENE := preload("res://scene/ui/cursorhand.tscn")
const MAP_MENU_SCRIPT := preload("res://scripts/map_menu.gd")

var _level: Node2D
var _bm: BattleManager
var _canvas_layer: CanvasLayer
var _camera: Camera2D
var _cursor_node: Node2D
var _label_setting: LabelSettings

var map_menu: MapMenu = null
var _confirm_dialog: NinePatchRect = null
var _confirm_index: int = 1
var _confirm_cursor: Control = null
var _confirm_btn_yes: Label = null
var _confirm_btn_no: Label = null


func _init(level: Node2D, bm: BattleManager, canvas: CanvasLayer, cam: Camera2D, cursor: Node2D, font: LabelSettings) -> void:
	_level = level
	_bm = bm
	_canvas_layer = canvas
	_camera = cam
	_cursor_node = cursor
	_label_setting = font
	_setup_map_menu()


func _setup_map_menu() -> void:
	map_menu = MAP_MENU_SCRIPT.new()
	_canvas_layer.add_child(map_menu)
	_bm.map_menu_requested.connect(_on_map_menu_requested)
	_bm.save_requested.connect(save_game)
	_bm.return_to_title_requested.connect(prompt_return_to_title)
	map_menu.end_turn_selected.connect(_on_map_menu_end_turn)
	map_menu.save_selected.connect(save_game)
	map_menu.return_to_title_selected.connect(prompt_return_to_title)
	map_menu.closed.connect(_on_map_menu_closed)


func _on_map_menu_requested() -> void:
	if map_menu == null or map_menu.is_active():
		return
	_cursor_node.set_process(false)
	var screen_x: float = _cursor_node.global_position.x - _camera.get_screen_center_position().x + 120.0
	var menu_x: float = 12.0 if screen_x >= 120.0 else 176.0
	map_menu.open(Vector2(menu_x, 24.0))


func _on_map_menu_closed() -> void:
	_cursor_node.set_process(true)


func _on_map_menu_end_turn() -> void:
	_cursor_node.set_process(true)
	_bm.phases.end_player_phase()


func save_game() -> bool:
	var slot_id := SaveManager.current_slot
	var meta := SaveManager.get_slot_meta(slot_id)
	var play_seconds: int = meta.get("play_time_seconds", 0)

	var data: Dictionary = {
		"version": 1,
		"slot_id": slot_id,
		"is_empty": false,
		"chapter_id": _level.name,
		"chapter_scene": _level.scene_file_path if _level.scene_file_path != "" else "res://scene/level/level_0/level_0.tscn",
		"chapter_name": "序章 一寸之遥的呼吸",
		"protagonist_name": "忒",
		"protagonist_level": 1,
		"play_time_seconds": play_seconds,
		"turn_count": _bm.turn,
		"timestamp": Time.get_datetime_string_from_system()
	}

	var ok := SaveManager.save_to_slot(slot_id, data)
	if ok:
		_show_save_toast("进度已保存！")
	return ok


func _show_save_toast(text: String) -> void:
	var toast: NinePatchRect = ITEMSBOX_SCENE.instantiate()
	toast.size = Vector2(80, 26)
	toast.position = Vector2(80, 10)
	var lbl := Label.new()
	lbl.text = text
	lbl.label_settings = _label_setting
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	toast.add_child(lbl)
	_canvas_layer.add_child(toast)

	toast.modulate.a = 0.0
	var tween := _level.create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.2)
	tween.tween_interval(0.8)
	tween.tween_property(toast, "modulate:a", 0.0, 0.3)
	tween.tween_callback(toast.queue_free)


func prompt_return_to_title() -> void:
	if _confirm_dialog == null:
		_build_confirm_dialog()
	_confirm_index = 1
	_confirm_dialog.visible = true
	_cursor_node.set_process(false)
	_update_confirm_cursor()


func _build_confirm_dialog() -> void:
	_confirm_dialog = ITEMSBOX_SCENE.instantiate()
	_confirm_dialog.name = "ReturnToTitleDialog"
	_confirm_dialog.size = Vector2(140, 52)
	_confirm_dialog.position = Vector2(50, 54)

	var lbl_prompt := Label.new()
	lbl_prompt.text = "返回开始界面？"
	lbl_prompt.label_settings = _label_setting
	lbl_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_prompt.position = Vector2(0, 8)
	lbl_prompt.size = Vector2(140, 16)
	_confirm_dialog.add_child(lbl_prompt)

	var hbox := HBoxContainer.new()
	hbox.position = Vector2(0, 28)
	hbox.size = Vector2(140, 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	_confirm_dialog.add_child(hbox)

	_confirm_btn_yes = Label.new()
	_confirm_btn_yes.text = "确定"
	_confirm_btn_yes.label_settings = _label_setting
	hbox.add_child(_confirm_btn_yes)

	_confirm_btn_no = Label.new()
	_confirm_btn_no.text = "取消"
	_confirm_btn_no.label_settings = _label_setting
	hbox.add_child(_confirm_btn_no)

	_confirm_cursor = CURSOR_HAND_SCENE.instantiate()
	_confirm_dialog.add_child(_confirm_cursor)

	_canvas_layer.add_child(_confirm_dialog)


const CONFIRM_CURSOR_X: Array[float] = [24.0, 66.0]
const CONFIRM_CURSOR_Y: float = 28.0


func _update_confirm_cursor() -> void:
	if _confirm_cursor == null:
		return
	var target := _confirm_btn_yes if _confirm_index == 0 else _confirm_btn_no
	var cursor_x: float = CONFIRM_CURSOR_X[_confirm_index]
	if target != null and target.position.x > 0:
		cursor_x = target.position.x - 16.0
	_confirm_cursor.position = Vector2(cursor_x, CONFIRM_CURSOR_Y)


func handle_input(event: InputEvent) -> bool:
	if _confirm_dialog != null and _confirm_dialog.visible:
		_handle_confirm_dialog_input(event)
		return true
	if map_menu != null and map_menu.is_active():
		map_menu.handle_input(event)
		return true
	return false


func _handle_confirm_dialog_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_confirm_index = 1 - _confirm_index
		_update_confirm_cursor()
		_level.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("no") or event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_X):
		_confirm_dialog.visible = false
		_cursor_node.set_process(true)
		_level.get_viewport().set_input_as_handled()
	elif event.is_action_pressed("yes") or event.is_action_pressed("start") or event.is_action_pressed("ui_accept") or (event is InputEventKey and (event.keycode == KEY_Z or event.keycode == KEY_ENTER)):
		_level.get_viewport().set_input_as_handled()
		if _confirm_index == 0:
			_confirm_dialog.visible = false
			SceneTransition.change_scene("res://scene/ui/title_screen.tscn", 0.35, 0.35)
		else:
			_confirm_dialog.visible = false
			_cursor_node.set_process(true)
