class_name SceneTransitionClass
extends CanvasLayer

##"""全局场景平滑转场管理器（SceneTransition）
##挂载于 Autoload 单例，图层设为 128（最顶层）。
##消除场景切换时的掉帧卡顿与生硬割裂感，提供 GBA 原版级别的黑屏淡入淡出。"""

signal fade_out_finished
signal fade_in_finished

var _color_rect: ColorRect
var _is_transitioning: bool = false


func _ready() -> void:
	layer = 128
	_color_rect = ColorRect.new()
	_color_rect.name = "FadeOverlay"
	_color_rect.color = Color(0, 0, 0, 0)
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_color_rect)


##平滑黑屏切场
func change_scene(target_path: String, fade_out_duration: float = 0.25, fade_in_duration: float = 0.25) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	##第一阶段：淡出至全黑
	var tween_out := create_tween()
	tween_out.tween_property(_color_rect, "color:a", 1.0, fade_out_duration)
	await tween_out.finished
	fade_out_finished.emit()

	##第二阶段：黑屏保护下执行换场
	var err := get_tree().change_scene_to_file(target_path)
	if err != OK:
		push_error("SceneTransition: 切换场景失败 %s, 错误码: %d" % [target_path, err])
		_color_rect.color.a = 0.0
		_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_is_transitioning = false
		return

	##等待一帧以确保新场景节点树初始化与 _ready() 执行完毕
	await get_tree().process_frame

	##第三阶段：全黑淡入新场景
	var tween_in := create_tween()
	tween_in.tween_property(_color_rect, "color:a", 0.0, fade_in_duration)
	await tween_in.finished

	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	fade_in_finished.emit()


##仅执行淡出到黑
func fade_to_black(duration: float = 0.3) -> void:
	_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_color_rect, "color:a", 1.0, duration)
	await tween.finished


##仅执行从黑淡入
func fade_from_black(duration: float = 0.3) -> void:
	var tween := create_tween()
	tween.tween_property(_color_rect, "color:a", 0.0, duration)
	await tween.finished
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
