class_name MapMenu
extends Control

##"""关卡地图系统菜单（MapMenu）
##光标停在空地或无行动单位时按确认键（Z）或菜单键（Start/Enter）唤出。
##提供：结束（回合结束）、保存（写入当前进度）、主菜单（返回标题）。"""

signal end_turn_selected
signal save_selected
signal return_to_title_selected
signal closed

const ITEMSBOX_SCENE := preload("res://scene/ui/itemsbox.tscn")
const CURSOR_HAND_SCENE := preload("res://scene/ui/cursorhand.tscn")
const LABEL_SETTING_TRES := preload("res://assets/graphics/UI/label_settings.tres")

const PANEL_WIDTH := 52.0
const ROW_HEIGHT := 13.0
const PATCH_MARGIN := 13.0

const COLOR_SELECTED := Color(1, 0.95, 0.4)
const COLOR_NORMAL := Color(1, 1, 1)

var _panel: NinePatchRect
var _vbox: VBoxContainer
var _hand: Control
var _labels: Array[Label] = []
var _selected: int = 0
var _is_open: bool = false


func _ready() -> void:
	visible = false
	_build_ui()


func _build_ui() -> void:
	_panel = ITEMSBOX_SCENE.instantiate()
	_panel.name = "MapMenuPanel"
	add_child(_panel)

	_vbox = VBoxContainer.new()
	_vbox.name = "VBox"
	_vbox.position = Vector2(PATCH_MARGIN, PATCH_MARGIN)
	_vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(_vbox)

	var options := ["结束", "保存", "主菜单"]
	for text in options:
		var lbl := Label.new()
		lbl.text = text
		lbl.label_settings = LABEL_SETTING_TRES.duplicate()
		lbl.custom_minimum_size = Vector2(26, 10)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vbox.add_child(lbl)
		_labels.append(lbl)

	_hand = CURSOR_HAND_SCENE.instantiate()
	_panel.add_child(_hand)

	var total_h := PATCH_MARGIN * 2 + options.size() * ROW_HEIGHT
	_panel.size = Vector2(PANEL_WIDTH, total_h)


func open(screen_pos: Vector2 = Vector2(12, 24)) -> void:
	_selected = 0
	_is_open = true
	_panel.position = screen_pos
	_refresh()
	visible = true


func close() -> void:
	_is_open = false
	visible = false
	closed.emit()


func is_active() -> bool:
	return _is_open


func handle_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if not event.is_pressed() or event.is_echo():
		return

	if event.is_action_pressed("ui_up"):
		_selected = (_selected - 1 + _labels.size()) % _labels.size()
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_selected = (_selected + 1) % _labels.size()
		_refresh()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("no") or event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_X):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed("yes") or event.is_action_pressed("start") or event.is_action_pressed("ui_accept") or (event is InputEventKey and (event.keycode == KEY_Z or event.keycode == KEY_ENTER)):
		get_viewport().set_input_as_handled()
		_on_confirm()


func _on_confirm() -> void:
	var sel_text := _labels[_selected].text
	close()
	match sel_text:
		"结束":
			end_turn_selected.emit()
		"保存":
			save_selected.emit()
		"主菜单":
			return_to_title_selected.emit()


func _refresh() -> void:
	for i in _labels.size():
		var col := COLOR_SELECTED if i == _selected else COLOR_NORMAL
		_labels[i].add_theme_color_override("font_color", col)

	if _hand != null:
		_hand.visible = true
		_hand.position = Vector2(-3.0, PATCH_MARGIN + _selected * ROW_HEIGHT - 3.0)
