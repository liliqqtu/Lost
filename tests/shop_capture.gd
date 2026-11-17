extends Node
## 非 headless 渲染检查；只写 tests/.runtime_saves/，不触碰玩家存档。
var _demo: Control
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_demo = load("res://tests/shop_demo.tscn").instantiate()
	get_tree().root.add_child(_demo)
	var panel: ShopPanel = _demo.get_node("Shop")
	for kind in 3:
		_demo._open_shop(kind)
		_press(panel, "start")
		if kind == 0:
			await _capture("shop_0_mode")
		_press(panel, "yes")
		await _capture("shop_%d_buy" % kind)
		if kind == 0:
			_press(panel, "yes")
			await _capture("shop_0_confirm")
			_press(panel, "no")
			_press(panel, "R")
			await _capture("shop_0_info")
			_press(panel, "no")
		else:
			for i in 4:
				_press(panel, "ui_down")
			_press(panel, "R")
			await _capture("shop_%d_info_lower" % kind)
			_press(panel, "no")
	_demo.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().quit()

func _capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tests/.runtime_saves")
	get_viewport().get_texture().get_image().save_png("res://tests/.runtime_saves/%s.png" % name)

func _press(panel: ShopPanel, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	panel.handle_input(event)
