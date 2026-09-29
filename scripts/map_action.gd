class_name MapAction extends Resource
##"""地图事件动作基类（阶段五 5E）
##execute 由关卡侧执行器 await 调用，子类可包含异步等待（对话框/移动等）
##ctx = 关卡脚本（level_0），可访问 battle_manager / get_node 等关卡装配"""

func execute(_ctx) -> void:
	pass
