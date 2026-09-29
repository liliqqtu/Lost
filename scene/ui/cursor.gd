extends Node2D

var cell := Vector2i(0, 0)
## 移动限制：非空时只能在字典包含的格子中移动
var restrict_to: Dictionary = {}
##第一次移动光标后delay
var first_move_delay := 0.3
##之后光标移动delay
var repeat_delay := 0.12
##移动delay
var move_delay := first_move_delay
##记录时间
var timer := 0.0


func _process(delta: float) -> void:
	timer -= delta
	if timer > 0:
		return
	#光标移动方向
	var dir := Vector2i.ZERO
	if Input.is_action_pressed("ui_right"):
		dir.x += 1
	elif Input.is_action_pressed("ui_left"):
		dir.x -= 1
	elif Input.is_action_pressed("ui_up"):
		dir.y -= 1
	elif Input.is_action_pressed("ui_down"):
		dir.y += 1
	#不移动时
	if dir == Vector2i.ZERO:
		move_delay = first_move_delay
		timer = 0.0
		return

	var new_cell := cell + dir
	#判断可移动路径是否为空  
	if restrict_to.is_empty() or restrict_to.has(new_cell):
		cell = new_cell
		global_position = Vector2(cell) * Global.TILE_SIZE
		timer += move_delay
		move_delay = repeat_delay


func set_cell(new_cell: Vector2i) -> void:
	cell = new_cell
	global_position = Vector2(cell) * Global.TILE_SIZE
