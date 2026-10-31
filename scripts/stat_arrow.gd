class_name StatArrow extends TextureRect

##"""属性比较升降指示箭头组件（复刻 GBA 火焰纹章）：
##使用 assets/graphics/UI/up_and_down.png (30x10)
##左侧 15x10 为上升箭头，右侧 15x10 为下降箭头。
##通过脚本实现原版像素级微微上下浮动动画。"""

const ARROW_TEXTURE := preload("res://assets/graphics/UI/up_and_down.png")
const REGION_UP := Rect2(0, 0, 15, 10)
const REGION_DOWN := Rect2(15, 0, 15, 10)

enum Mode { NONE, UP, DOWN }

var mode: Mode = Mode.NONE
var base_y: float = 0.0
var _timer: float = 0.0
var _atlas: AtlasTexture


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(15, 10)
	size = Vector2(15, 10)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_atlas = AtlasTexture.new()
	_atlas.atlas = ARROW_TEXTURE
	texture = _atlas
	visible = false


func _ready() -> void:
	base_y = position.y


func set_base_pos(pos: Vector2) -> void:
	position = pos
	base_y = pos.y


func set_comparison(cur_val: int, orig_val: int) -> void:
	if cur_val > orig_val:
		set_mode(Mode.UP)
	elif cur_val < orig_val:
		set_mode(Mode.DOWN)
	else:
		set_mode(Mode.NONE)


func set_mode(p_mode: Mode) -> void:
	mode = p_mode
	if mode == Mode.NONE:
		visible = false
		position.y = base_y
		_timer = 0.0
		return
	visible = true
	if mode == Mode.UP:
		_atlas.region = REGION_UP
	elif mode == Mode.DOWN:
		_atlas.region = REGION_DOWN


func _process(delta: float) -> void:
	if not visible or mode == Mode.NONE:
		return
	_timer += delta * 8.0
	var offset := 0
	if mode == Mode.UP:
		# 向上微微浮动（0 -> -1 -> -2 -> -1 -> 0）
		offset = -roundi(absf(sin(_timer)) * 2.0)
	elif mode == Mode.DOWN:
		# 向下微微浮动（0 -> 1 -> 2 -> 1 -> 0）
		offset = roundi(absf(sin(_timer)) * 2.0)
	position.y = base_y + offset
