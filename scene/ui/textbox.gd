class_name TextBox
extends NinePatchRect
##"""通用文字框（信息查看系统）：textbox.tscn 的控制脚本
##textbox.tscn 是从 talk.tscn 的 Dialogue 分离出来的独立场景，两处共用一个文字框实现：
##  - 对话系统（talk.tscn 实例它作正文框，逐字/尺寸调整由 talk.gd 自己驱动）
##  - 信息查看系统（InfoViewer 实例它显示描述）
##show_text(text)：按完整文字测量并自适应尺寸（复用 talk.gd 的测量规则：
##  min 91×48 / max 224×64、下边界恒定、左边缘固定），文字整段立即显示（浏览信息无逐字需求）
##hide_box()：隐藏。
##注意：不在 _ready 里隐藏自身——talk.tscn 也实例本场景，可见性由 talk 根节点控制"""

##文字框下边界（屏幕固定，位置随内容高度上移；GBA 240×160，底部留 4px 边距）
const BOX_BOTTOM := 156.0
##文字框左边缘固定
const BOX_X := 8.0

@onready var arrow: TextureRect = $DialogueArrow
@onready var margin: MarginContainer = $MarginContainer
@onready var text_label: Label = $MarginContainer/Label


func _ready() -> void:
	##信息查看不翻页，箭头常隐藏（对话模式下箭头仍由 talk.gd 控制）
	arrow.visible = false


##显示一段文字：测量整段内容并自适应尺寸，立即完整显示
func show_text(text: String) -> void:
	text_label.text = text
	text_label.visible_characters = -1
	_resize(text)
	visible = true


##隐藏文字框
func hide_box() -> void:
	visible = false


##按完整文字测量内容大小，框 = 内容 + 边距，限制在 min/max 之间（同 talk.gd 规则）
func _resize(text: String) -> void:
	var content := _measure_text(text)
	var m := margin.get_theme_constant("margin_left") + margin.get_theme_constant("margin_right")
	var mv := margin.get_theme_constant("margin_top") + margin.get_theme_constant("margin_bottom")
	var box_size := Vector2(content.x + m, content.y + mv)
	box_size.x = clampf(box_size.x, custom_minimum_size.x, custom_maximum_size.x)
	box_size.y = clampf(box_size.y, custom_minimum_size.y, custom_maximum_size.y)
	size = box_size
	position = Vector2(BOX_X, BOX_BOTTOM - box_size.y)


##用字体直接测量换行后的内容大小（autowrap 宽度取 Label 的 custom_maximum_size.x）
func _measure_text(text: String) -> Vector2:
	var font: Font = text_label.get_theme_font("font")
	var font_size: int = text_label.get_theme_font_size("font_size")
	var spacing: int = text_label.get_theme_constant("line_spacing")
	var max_width: float = text_label.custom_maximum_size.x
	var size: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, max_width, font_size)
	##get_multiline_string_size 不含行距，手动补
	if size.y > 0.0:
		var line_count: int = ceili(size.y / font.get_height(font_size))
		size.y += (line_count - 1) * spacing
	return size.min(text_label.custom_maximum_size)
