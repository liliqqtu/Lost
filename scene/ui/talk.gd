extends Control
##"""对话场景（阶段五 5E 重构）：talk.tscn 的控制脚本，加载进关卡的 CanvasLayer 下
##节点结构（编辑器搭建）：
##  BG            背景CG（关卡内对话为空；剧情演绎时传指定图片）
##  Dialogue      九宫格对话框（MarginContainer/Label 正文 + DialogueArrow 箭头）
##  Left1/Left2/Right1/Right2  肖像槽（子节点 Bubble 气泡，说话者显示）
##用法：open(lines, portraits, bg) 播放，closed 信号通知播完
##  lines 每项 {"speaker": 名字, "text": 台词, "side": "left1"/"left2"/"right1"/"right2"}
##  系统提示（如"获得了伤药！"）省略 side，不显示肖像与气泡
##  portraits：{说话人名: Texture2D}，右侧槽强制水平翻转（人物默认面向右侧，以文档为准）
##逐字显示：yes/no 打字中=立即显示完整句 / 打字完=下一句；"start"=跳过全部
##输入由 BattleManager 在 DIALOGUE 状态转发到 handle_input"""

signal closed

@onready var bg: TextureRect = $BG
@onready var dialogue: NinePatchRect = $Dialogue
@onready var arrow: TextureRect = $Dialogue/DialogueArrow
@onready var margin: MarginContainer = $Dialogue/MarginContainer
@onready var text_label: Label = $Dialogue/MarginContainer/Label

##四个肖像槽：槽位名 -> TextureRect
@onready var slots: Dictionary = {
	"left1": $Left1,
	"left2": $Left2,
	"right1": $Right1,
	"right2": $Right2,
}

##逐字速度（秒/字）
const CHAR_DELAY := 0.04
##Dialogue 下边界恒定值（position.y + size.y = 81）
const DIALOGUE_BOTTOM := 81.0
##Dialogue 左边缘固定
const DIALOGUE_X := 8.0

var _lines: Array = []
var _portraits: Dictionary = {}
var _index := 0
var _active := false
var _typing := false
var _type_tween: Tween
##说话人名 -> 槽位名（open 时预扫描登记）
var _speaker_sides: Dictionary = {}


func _ready() -> void:
	visible = false
	##箭头上下浮动：动画锚点偏移（不捕获 position，Dialogue 改尺寸后不会漂移）
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(arrow, "offset_top", -14.0, 0.6)
	tween.parallel().tween_property(arrow, "offset_bottom", 2.0, 0.6)
	tween.tween_property(arrow, "offset_top", -16.0, 0.6)
	tween.parallel().tween_property(arrow, "offset_bottom", 0.0, 0.6)


##打开对话：lines 空直接结束；portraits 说话人->肖像贴图；bg 背景CG（null=关卡内对话不显示）
func open(lines: Array, portraits: Dictionary = {}, bg_texture: Texture2D = null) -> void:
	if lines.is_empty():
		closed.emit()
		return
	_lines = lines.duplicate(true)
	_portraits = portraits
	_index = 0
	_active = true
	_setup_speakers()
	##背景：关卡内对话为空
	if bg_texture == null:
		bg.visible = false
	else:
		bg.texture = bg_texture
		bg.visible = true
	visible = true
	_show_line(_index)


##外部输入入口（由 BattleManager 在 DIALOGUE 状态转发）
func handle_input(event: InputEvent) -> void:
	if not _active or not event.is_pressed():
		return
	if event.is_action_pressed("yes") or event.is_action_pressed("no"):
		if _typing:
			_complete_line()
		else:
			_index += 1
			if _index >= _lines.size():
				_finish()
			else:
				_show_line(_index)
	elif event.is_action_pressed("start"):
		_finish()


##预扫描登记说话人槽位，摆好肖像与翻转（左侧翻转，人物默认面向左侧）
func _setup_speakers() -> void:
	_speaker_sides.clear()
	for line in _lines:
		var speaker: String = line.get("speaker", "")
		var side: String = line.get("side", "")
		if speaker != "" and side != "" and not _speaker_sides.has(speaker):
			_speaker_sides[speaker] = side
	##先全部隐藏，再显示有对话槽位的
	for side_name in slots:
		slots[side_name].visible = false
	for speaker in _speaker_sides:
		var side: String = _speaker_sides[speaker]
		var slot: TextureRect = slots[side]
		slot.visible = true
		if _portraits.has(speaker):
			slot.texture = _portraits[speaker]
		slot.flip_h = side.begins_with("left")


##显示第 i 句：更新气泡、按完整台词测量并调整 Dialogue 尺寸、开始逐字
func _show_line(i: int) -> void:
	var line: Dictionary = _lines[i]
	var speaker: String = line.get("speaker", "")
	var text: String = line.get("text", "")
	_update_bubbles(speaker)
	text_label.text = text
	_resize_dialogue(text)
	arrow.visible = false
	text_label.visible_characters = 0
	_start_typing(text)


##说话者的槽位显示气泡，其余隐藏；系统提示（无槽位）全部隐藏
func _update_bubbles(speaker: String) -> void:
	for side_name in slots:
		var slot: TextureRect = slots[side_name]
		(slot.get_node("Bubble") as TextureRect).visible = false
	if speaker != "" and _speaker_sides.has(speaker):
		(slots[_speaker_sides[speaker]].get_node("Bubble") as TextureRect).visible = true


##按完整台词测量 Label 内容大小，Dialogue = 内容 + 边距，限制在场景 min/max 之间
##下边界恒为 81（position.y + size.y = 81）
func _resize_dialogue(text: String) -> void:
	var content := _measure_text(text)
	var m := margin.get_theme_constant("margin_left") + margin.get_theme_constant("margin_right")
	var mv := margin.get_theme_constant("margin_top") + margin.get_theme_constant("margin_bottom")
	var size := Vector2(content.x + m, content.y + mv)
	size.x = clampf(size.x, dialogue.custom_minimum_size.x, dialogue.custom_maximum_size.x)
	size.y = clampf(size.y, dialogue.custom_minimum_size.y, dialogue.custom_maximum_size.y)
	dialogue.size = size
	dialogue.position = Vector2(DIALOGUE_X, DIALOGUE_BOTTOM - size.y)


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


##逐字显示当前句
func _start_typing(text: String) -> void:
	var total := text.length()
	if total <= 0:
		_complete_line()
		return
	_typing = true
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(text_label, "visible_characters", total, total * CHAR_DELAY)
	_type_tween.finished.connect(_on_typing_done)


##打字自然结束
func _on_typing_done() -> void:
	_typing = false
	arrow.visible = true


##立即显示完整句（yes 打断打字时）
func _complete_line() -> void:
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	text_label.visible_characters = -1
	_typing = false
	arrow.visible = true


##结束：隐藏整个对话场景、广播
func _finish() -> void:
	_active = false
	_typing = false
	if _type_tween != null and _type_tween.is_valid():
		_type_tween.kill()
	visible = false
	closed.emit()
