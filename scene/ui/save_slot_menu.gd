class_name SaveSlotMenu
extends Control

##"""存档选择界面（SaveSlotMenu）
##复刻 GBA《圣魔之光石》FE8 风格的三槽位存档卡片界面。
##每卡片宽阔居中显示章节名称，右下角展示当前光标选中槽位的游戏时长 (PLAY-TIME)。
##通过 SceneTransition 实现平滑黑屏淡入淡出。"""

enum State {
	SELECT_SLOT,
	ACTION_MENU,
	CONFIRM_NEW,
	CONFIRM_OVERWRITE,
	CONFIRM_DELETE
}

const TITLE_SCREEN_PATH := "res://scene/ui/title_screen.tscn"
const INTRO_CUTSCENE_PATH := "res://scene/ui/intro_cutscene.tscn"

const TEX_SLOT_EMPTY := preload("res://assets/graphics/UI/save_slot_empty.png")
const TEX_SLOT_ACTIVE := preload("res://assets/graphics/UI/save_slot_active.png")

##光标在各槽位的 Y 坐标 (卡片 Y: 27, 65, 103；卡片高 31, 光标居中)
const CURSOR_SLOT_Y: Array[float] = [34.0, 72.0, 110.0]
const CURSOR_SLOT_X: float = 34.0

##二次确认框光标固定坐标（0: 确定, 1: 取消），防止首帧容器未排版导致漂移
const CONFIRM_CURSOR_X: Array[float] = [42.0, 88.0]
const CONFIRM_CURSOR_Y: float = 32.0

@onready var cursor_hand: Control = $CursorHand
@onready var slot_cards: Array[TextureRect] = [
	$Cards/Slot1,
	$Cards/Slot2,
	$Cards/Slot3
]

@onready var play_time_value: Label = $PlayTimePanel/LblPlayTimeValue

##二级操作菜单面板与选项
@onready var action_panel: NinePatchRect = $ActionPanel
@onready var action_items: Array[Label] = [
	$ActionPanel/VBox/ItemContinue,
	$ActionPanel/VBox/ItemNew,
	$ActionPanel/VBox/ItemDelete,
	$ActionPanel/VBox/ItemBack
]
@onready var action_cursor: Control = $ActionPanel/ActionCursor

##确认对话框
@onready var confirm_dialog: NinePatchRect = $ConfirmDialog
@onready var confirm_prompt: Label = $ConfirmDialog/PromptLabel
@onready var confirm_btn_yes: Label = $ConfirmDialog/HBox/BtnYes
@onready var confirm_btn_no: Label = $ConfirmDialog/HBox/BtnNo
@onready var confirm_cursor: Control = $ConfirmDialog/ConfirmCursor

var current_state: State = State.SELECT_SLOT
var selected_slot_index: int = 0  ## 0, 1, 2 (对应 slot 1, 2, 3)
var action_menu_index: int = 0    ## 0: 继续, 1: 新建, 2: 删除, 3: 返回
var confirm_dialog_index: int = 0 ## 0: 确定, 1: 取消
var _is_transitioning: bool = false


func _ready() -> void:
	action_panel.visible = false
	confirm_dialog.visible = false
	_refresh_all_slots()
	_update_slot_cursor()


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if not event.is_pressed() or event.is_echo():
		return

	match current_state:
		State.SELECT_SLOT:
			_handle_input_slot_select(event)
		State.ACTION_MENU:
			_handle_input_action_menu(event)
		State.CONFIRM_NEW, State.CONFIRM_OVERWRITE, State.CONFIRM_DELETE:
			_handle_input_confirm_dialog(event)


##==================== 槽位选择阶段 ====================

func _handle_input_slot_select(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		selected_slot_index = (selected_slot_index - 1 + 3) % 3
		_update_slot_cursor()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		selected_slot_index = (selected_slot_index + 1) % 3
		_update_slot_cursor()
		get_viewport().set_input_as_handled()
	elif _is_cancel_action(event):
		_is_transitioning = true
		get_viewport().set_input_as_handled()
		SceneTransition.change_scene(TITLE_SCREEN_PATH, 0.25, 0.25)
	elif _is_confirm_action(event):
		get_viewport().set_input_as_handled()
		_on_slot_confirmed()


func _update_slot_cursor() -> void:
	cursor_hand.position = Vector2(CURSOR_SLOT_X, CURSOR_SLOT_Y[selected_slot_index])
	_update_play_time_display()


func _update_play_time_display() -> void:
	var slot_id := selected_slot_index + 1
	var meta := SaveManager.get_slot_meta(slot_id)
	if meta.get("is_empty", true):
		play_time_value.text = "--:--"
	else:
		var seconds: int = meta.get("play_time_seconds", 0)
		play_time_value.text = SaveManager.format_play_time(seconds)


func _on_slot_confirmed() -> void:
	var slot_id := selected_slot_index + 1
	var meta := SaveManager.get_slot_meta(slot_id)

	if meta.get("is_empty", true):
		_show_confirm_dialog(State.CONFIRM_NEW, "在此档案开始新游戏？")
	else:
		_open_action_menu()


##==================== 二级操作菜单阶段 ====================

func _open_action_menu() -> void:
	current_state = State.ACTION_MENU
	action_menu_index = 0
	action_panel.visible = true
	var base_y: float = CURSOR_SLOT_Y[selected_slot_index] - 12.0
	action_panel.position = Vector2(170.0, clampf(base_y, 16.0, 85.0))
	_update_action_menu_cursor()


func _close_action_menu() -> void:
	action_panel.visible = false
	current_state = State.SELECT_SLOT


func _handle_input_action_menu(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		action_menu_index = (action_menu_index - 1 + action_items.size()) % action_items.size()
		_update_action_menu_cursor()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		action_menu_index = (action_menu_index + 1) % action_items.size()
		_update_action_menu_cursor()
		get_viewport().set_input_as_handled()
	elif _is_cancel_action(event):
		get_viewport().set_input_as_handled()
		_close_action_menu()
	elif _is_confirm_action(event):
		get_viewport().set_input_as_handled()
		_execute_action_menu_choice()


func _update_action_menu_cursor() -> void:
	var target_label := action_items[action_menu_index]
	action_cursor.position = Vector2(-1.0, target_label.position.y + 5.0)


func _execute_action_menu_choice() -> void:
	match action_menu_index:
		0: ##继续游戏
			var slot_id := selected_slot_index + 1
			_load_and_start_game(slot_id)
		1: ##新建游戏 (覆盖)
			_show_confirm_dialog(State.CONFIRM_OVERWRITE, "覆盖此档案开始新游戏？")
		2: ##删除存档
			_show_confirm_dialog(State.CONFIRM_DELETE, "确定删除此档案？")
		3: ##返回
			_close_action_menu()


##==================== 二次确认弹窗 ====================

func _show_confirm_dialog(new_state: State, prompt_text: String) -> void:
	current_state = new_state
	confirm_dialog_index = 0
	confirm_prompt.text = prompt_text
	confirm_dialog.visible = true
	_update_confirm_cursor()


func _close_confirm_dialog() -> void:
	confirm_dialog.visible = false
	if current_state == State.CONFIRM_NEW:
		current_state = State.SELECT_SLOT
	else:
		current_state = State.ACTION_MENU


func _handle_input_confirm_dialog(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		confirm_dialog_index = 1 - confirm_dialog_index
		_update_confirm_cursor()
		get_viewport().set_input_as_handled()
	elif _is_cancel_action(event):
		get_viewport().set_input_as_handled()
		_close_confirm_dialog()
	elif _is_confirm_action(event):
		get_viewport().set_input_as_handled()
		_execute_confirm_choice()


func _update_confirm_cursor() -> void:
	var target_btn: Label = confirm_btn_yes if confirm_dialog_index == 0 else confirm_btn_no
	var cursor_x: float = CONFIRM_CURSOR_X[confirm_dialog_index]
	if target_btn != null and target_btn.position.x > 0:
		cursor_x = target_btn.position.x - 16.0
	confirm_cursor.position = Vector2(cursor_x, CONFIRM_CURSOR_Y)


func _execute_confirm_choice() -> void:
	var slot_id := selected_slot_index + 1

	if confirm_dialog_index == 1:
		_close_confirm_dialog()
		return

	match current_state:
		State.CONFIRM_NEW, State.CONFIRM_OVERWRITE:
			confirm_dialog.visible = false
			action_panel.visible = false
			_start_new_game_flow(slot_id)
		State.CONFIRM_DELETE:
			SaveManager.delete_slot(slot_id)
			_refresh_all_slots()
			_update_play_time_display()
			confirm_dialog.visible = false
			action_panel.visible = false
			current_state = State.SELECT_SLOT


##==================== 业务跳转与状态刷新 ====================

func _start_new_game_flow(slot_id: int) -> void:
	_is_transitioning = true
	SaveManager.start_new_game(slot_id)
	SceneTransition.change_scene(INTRO_CUTSCENE_PATH, 0.35, 0.35)


func _load_and_start_game(slot_id: int) -> void:
	_is_transitioning = true
	var data := SaveManager.load_from_slot(slot_id)
	var scene_path: String = data.get("chapter_scene", "res://scene/level/level_0/level_0.tscn")
	if not ResourceLoader.exists(scene_path):
		scene_path = "res://scene/level/level_0/level_0.tscn"
	SceneTransition.change_scene(scene_path, 0.35, 0.35)


func _refresh_all_slots() -> void:
	for i in range(3):
		var slot_id := i + 1
		var card := slot_cards[i]
		var meta := SaveManager.get_slot_meta(slot_id)
		var lbl_chapter: Label = card.get_node("LblChapter")

		if meta.get("is_empty", true):
			card.texture = TEX_SLOT_EMPTY
			lbl_chapter.text = "-- 没有档案 --"
			lbl_chapter.modulate = Color(0.75, 0.75, 0.75, 0.9)
		else:
			card.texture = TEX_SLOT_ACTIVE
			var ch_name: String = meta.get("chapter_name", "序章 一寸之遥的呼吸")
			lbl_chapter.text = ch_name
			lbl_chapter.modulate = Color(1.0, 1.0, 1.0, 1.0)


func _is_confirm_action(event: InputEvent) -> bool:
	if event.is_action_pressed("yes") or event.is_action_pressed("start") or event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_Z):
		return true
	return false


func _is_cancel_action(event: InputEvent) -> bool:
	if event.is_action_pressed("no") or event.is_action_pressed("ui_cancel"):
		return true
	if event is InputEventKey and (event.keycode == KEY_X or event.keycode == KEY_ESCAPE):
		return true
	return false
