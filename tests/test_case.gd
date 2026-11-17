extends Node

signal completed(code: int)

func quit(code: int = 0) -> void:
	if get_meta("suite", false):
		completed.emit(code)
	else:
		get_tree().quit(code)
