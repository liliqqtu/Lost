class_name IntroCutscene
extends Control

##"""开场动画与世界观旁白播报（IntroCutscene）
##搭载四幕定制像素插画背景（真理暗门 / 虚无之潮 / 彷徨之忒 / 拂晓启程）。
##文字无框悬浮于背景之上，打字机流转推进，平滑淡入切入序章。"""

const NEXT_SCENE_PATH := "res://scene/level/level_0/level_0.tscn"

const BG_TEXTURES: Array[Texture2D] = [
	preload("res://assets/graphics/cutscene/intro_bg_1.png"),
	preload("res://assets/graphics/cutscene/intro_bg_2.png"),
	preload("res://assets/graphics/cutscene/intro_bg_3.png"),
	preload("res://assets/graphics/cutscene/intro_bg_4.png")
]

const NARRATION_PAGES: Array[String] = [
	"很久以前，人们从不追问『我为何而生』。\n因为高悬于天际的『命途』，早已为每一颗灵魂写好了注脚——农夫属于麦田，骑士属于王座，死者属于星辰。\n\n直到二十年前，贤者们推开了真理的暗门……门后没有神明，也没有宿命，只有一片沉默而荒凉的虚空。",
	"当『一切皆无意义』的真相席卷大陆，宏大的秩序崩溃了。\n有人熄灭了炉火，在倦怠中风化为骸骨；有人放纵着兽性，在末日的狂欢中挥起屠刀。\n\n人类社会的绝望与迷茫，在大地上凝结成吞噬万物的暗影——『虚无之潮』。",
	"在没有路标的荒原上，一个连自己的过去都已遗忘的青年，正握着一张拉不开远方的弓，独自徘徊……\n\n青年名为忒。\n没有故乡，没有信仰，甚至不知道明天的太阳是否值得升起。",
	"然而，当生存的风暴迫近，手握缰绳与短弓的他，仍本能地策马前行——\n\n在荒谬的世界里，哪怕没有终极的意义，选择与行动……就是存在的证明。"
]

@onready var bg_under: TextureRect = $BgUnder
@onready var bg_over: TextureRect = $BgOver
@onready var label_subtitle: Label = $Header/LblSubtitle
@onready var label_text: Label = $LblText
@onready var label_prompt: Label = $Footer/LblPrompt

var current_page: int = 0
var displayed_char_count: int = 0
var is_typing: bool = false
var is_fading: bool = false
var type_timer: float = 0.0

const CHARS_PER_SECOND: float = 24.0


func _ready() -> void:
	current_page = 0
	is_fading = false
	bg_over.modulate.a = 0.0
	bg_under.texture = BG_TEXTURES[0]
	label_prompt.text = "Z 继续    Space 跳过"
	_start_page(0)


func _process(delta: float) -> void:
	if not is_typing or is_fading:
		return

	type_timer += delta
	var target_chars := int(type_timer * CHARS_PER_SECOND)
	var full_text: String = NARRATION_PAGES[current_page]

	if target_chars > displayed_char_count:
		displayed_char_count = mini(target_chars, full_text.length())
		label_text.text = full_text.substr(0, displayed_char_count)

		if displayed_char_count >= full_text.length():
			_finish_typing_current_page()


func _unhandled_input(event: InputEvent) -> void:
	if is_fading:
		return

	if not event.is_pressed() or event.is_echo():
		return

	##跳过全片
	if _is_skip_action(event):
		get_viewport().set_input_as_handled()
		_fade_to_game()
		return

	##推进操作
	if _is_advance_action(event):
		get_viewport().set_input_as_handled()
		if is_typing:
			_skip_to_full_text()
		else:
			_advance_next_page()


func _start_page(page_index: int) -> void:
	current_page = page_index
	displayed_char_count = 0
	type_timer = 0.0
	is_typing = true
	label_text.text = ""
	label_subtitle.text = "序幕 · 存在与虚无 (%d/4)" % (current_page + 1)
	label_prompt.text = "Z 快进    Space 跳过"


func _skip_to_full_text() -> void:
	var full_text: String = NARRATION_PAGES[current_page]
	displayed_char_count = full_text.length()
	label_text.text = full_text
	_finish_typing_current_page()


func _finish_typing_current_page() -> void:
	is_typing = false
	if current_page < NARRATION_PAGES.size() - 1:
		label_prompt.text = "Z 下一页    Space 跳过"
	else:
		label_prompt.text = "Z 启程    Space 跳过"


func _advance_next_page() -> void:
	if current_page < NARRATION_PAGES.size() - 1:
		var next_idx := current_page + 1

		##插画平滑交叉淡化与文字淡入淡出
		bg_over.texture = BG_TEXTURES[next_idx]
		bg_over.modulate.a = 0.0

		var tween := create_tween().set_parallel(true)
		tween.tween_property(label_text, "modulate:a", 0.0, 0.25)
		tween.tween_property(bg_over, "modulate:a", 1.0, 0.5)

		tween.chain().tween_callback(func():
			bg_under.texture = BG_TEXTURES[next_idx]
			bg_over.modulate.a = 0.0
			label_text.modulate.a = 1.0
			_start_page(next_idx)
		)
	else:
		_fade_to_game()


func _fade_to_game() -> void:
	if is_fading:
		return
	is_fading = true
	SceneTransition.change_scene(NEXT_SCENE_PATH, 0.5, 0.5)


func _is_advance_action(event: InputEvent) -> bool:
	if event.is_action_pressed("yes") or event.is_action_pressed("ui_accept"):
		return true
	if event is InputEventKey and (event.keycode == KEY_Z or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER):
		return true
	return false


func _is_skip_action(event: InputEvent) -> bool:
	if event.is_action_pressed("start"):
		return true
	if event is InputEventKey and (event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE):
		return true
	return false
