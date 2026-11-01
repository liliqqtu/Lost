class_name TitleScreen
extends Control

##"""游戏标题界面（TitleScreen）
##显示游戏标题 Logo 与闪烁的 Press Start。
##按下确认键（Z / Enter / Space / Start）后，触发确认动画并切入存档界面 (save_slot_menu.tscn)。"""

const SAVE_SLOT_MENU_PATH := "res://scene/ui/save_slot_menu.tscn"

@onready var press_start: TextureRect = $BG/PressStart

var _is_transitioning: bool = false


func _ready() -> void:
	_is_transitioning = false


func _unhandled_input(event: InputEvent) -> void:
	if _is_transitioning:
		return

	if _is_confirm_action(event):
		_on_start_pressed()


func _is_confirm_action(event: InputEvent) -> bool:
	if not event.is_pressed() or event.is_echo():
		return false
	if event.is_action_pressed("yes") or event.is_action_pressed("start") or event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_Z):
		return true
	return false


func _on_start_pressed() -> void:
	_is_transitioning = true
	get_viewport().set_input_as_handled()

	##加速闪烁 3 次反馈效果
	var tween := create_tween()
	for i in range(3):
		tween.tween_property(press_start, "modulate:a", 0.0, 0.06)
		tween.tween_property(press_start, "modulate:a", 1.0, 0.06)
	tween.tween_interval(0.1)
	tween.tween_callback(_goto_save_menu)


func _goto_save_menu() -> void:
	if ResourceLoader.exists(SAVE_SLOT_MENU_PATH):
		SceneTransition.change_scene(SAVE_SLOT_MENU_PATH, 0.25, 0.25)
	else:
		push_error("SaveSlotMenu scene not found: %s" % SAVE_SLOT_MENU_PATH)
		_is_transitioning = false
