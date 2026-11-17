extends Sprite2D

## 闪烁循环的帧数：需大于 0，并与 Sprite2D 的图集帧数对应。
@export var frame_count: int = 3
## 每次切换帧的间隔（秒）：需大于 0；值越小闪烁越快。
@export var interval: float = 0.2
## 闪烁剩余时长（秒）：播放中逐次扣减，耗尽后删除星星节点。
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
