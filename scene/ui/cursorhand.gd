extends Control

func _ready() -> void:
	var tween_cursor := create_tween()
	tween_cursor.set_loops()
	tween_cursor.tween_property($CursorTex,"position",Vector2(6,0),0.6)
	tween_cursor.tween_property($CursorTex,"position",Vector2.ZERO,0.6)
