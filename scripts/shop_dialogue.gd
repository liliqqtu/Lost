extends "res://scene/ui/talk.gd"
## 复用原对话场景和打字输入，仅适配商店右上角区域。

func _ready() -> void:
	super._ready()
	dialogue.custom_minimum_size = Vector2(160, 48)
	dialogue.custom_maximum_size = Vector2(160, 48)
	text_label.custom_maximum_size = Vector2(144, 28)
	text_label.add_theme_font_size_override("font_size", 10)

func _resize_dialogue(text: String) -> void:
	super._resize_dialogue(text)
	dialogue.position = Vector2(72, 8)

func show_prompt(text: String) -> void:
	open([{"text": text}])
	_complete_line()
	_active = false
	arrow.hide()
