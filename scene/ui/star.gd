extends Sprite2D

@export var frame_count: int = 3
## 闪烁频率
@export var interval: float = 0.2
## 持续时间
@export var timer:float = 0.6

func _ready():
	_loop_frames()

func _loop_frames():
	frame = 2
	while timer >= 0:
		await get_tree().create_timer(interval).timeout
		frame = (frame + 1) % frame_count
		timer = timer - interval
	queue_free()
