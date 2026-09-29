extends Camera2D

##摄像机移动速度
var speed := 500
##摄像机目标位置
var target_position := Vector2.ZERO
var map_down_margin :int 
var map_right_margin :int 
##Drag Margin 上下屏幕限制 距离中心点距离
const DOWN_MARGIN = 48
##Drag Margin 左右边屏幕限制 距离中心点距离
const RIGHT_MARGIN = 64

func _process(_delta):
	#global_position = global_position.move_toward(
		#target_position,
		#speed * delta
	#)
	
	var screen_pos = target_position - global_position
	#右边缘
	if screen_pos.x > RIGHT_MARGIN:
		global_position.x += screen_pos.x - RIGHT_MARGIN
		
	#左边缘
	elif screen_pos.x < -RIGHT_MARGIN:
		global_position.x += RIGHT_MARGIN + screen_pos.x
	#下边缘
	if screen_pos.y > DOWN_MARGIN:
		global_position.y += screen_pos.y - DOWN_MARGIN
	#上边缘
	elif screen_pos.y < -DOWN_MARGIN:
		global_position.y += DOWN_MARGIN + screen_pos.y
