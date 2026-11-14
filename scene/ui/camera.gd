extends Camera2D

## 摄像机移动速度
var speed := 500
## 摄像机目标位置
var target_position := Vector2.ZERO
var map_down_margin: int
var map_right_margin: int
## Drag Margin 上下屏幕限制 距离中心点距离
const DOWN_MARGIN = 48
## Drag Margin 左右边屏幕限制 距离中心点距离
const RIGHT_MARGIN = 64

var has_map_limits := false
var map_pixel_rect := Rect2()


func set_map_limits(used_rect: Rect2i, tile_size: int = 16) -> void:
	var min_x := float(used_rect.position.x * tile_size)
	var min_y := float(used_rect.position.y * tile_size)
	var max_x := float((used_rect.position.x + used_rect.size.x) * tile_size)
	var max_y := float((used_rect.position.y + used_rect.size.y) * tile_size)

	limit_left = int(min_x)
	limit_top = int(min_y)
	limit_right = int(max_x)
	limit_bottom = int(max_y)

	map_pixel_rect = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
	has_map_limits = true


func _process(_delta: float) -> void:
	var screen_pos = target_position - global_position
	# 右边缘
	if screen_pos.x > RIGHT_MARGIN:
		global_position.x += screen_pos.x - RIGHT_MARGIN
	# 左边缘
	elif screen_pos.x < -RIGHT_MARGIN:
		global_position.x += RIGHT_MARGIN + screen_pos.x
	# 下边缘
	if screen_pos.y > DOWN_MARGIN:
		global_position.y += screen_pos.y - DOWN_MARGIN
	# 上边缘
	elif screen_pos.y < -DOWN_MARGIN:
		global_position.y += DOWN_MARGIN + screen_pos.y

	# 视口边缘保护：防止摄像机滚动到地图边界外
	if has_map_limits:
		var half_w := 120.0
		var half_h := 80.0
		if map_pixel_rect.size.x >= 240.0:
			global_position.x = clampf(global_position.x, map_pixel_rect.position.x + half_w, map_pixel_rect.position.x + map_pixel_rect.size.x - half_w)
		else:
			global_position.x = map_pixel_rect.position.x + map_pixel_rect.size.x * 0.5

		if map_pixel_rect.size.y >= 160.0:
			global_position.y = clampf(global_position.y, map_pixel_rect.position.y + half_h, map_pixel_rect.position.y + map_pixel_rect.size.y - half_h)
		else:
			global_position.y = map_pixel_rect.position.y + map_pixel_rect.size.y * 0.5
