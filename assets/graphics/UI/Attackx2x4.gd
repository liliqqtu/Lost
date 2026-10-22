extends Sprite2D
## 追击指示图标（x2 / x4）动画与控制脚本

var _tween: Tween = null
var _base_position := Vector2.ZERO
var _initialized := false


func _ready() -> void:
	_init_pos()


func _init_pos() -> void:
	if not _initialized:
		_base_position = position
		_initialized = true


## 设置显示倍数并启动动画（times <= 1 时停止并隐藏）
func set_chase(times: int) -> void:
	_init_pos()
	if times <= 1:
		stop_animation()
		return
	frame = 1 if times >= 4 else 0
	play_animation()


## 启动浮动动画（横向平滑来回微动）
func play_animation() -> void:
	_init_pos()
	stop_animation()
	visible = true
	position = _base_position
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "position:x", _base_position.x + 2.0, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "position:x", _base_position.x, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 停止动画并隐藏
func stop_animation() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_tween = null
	if _initialized:
		position = _base_position
	visible = false
