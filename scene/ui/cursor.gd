extends Node2D

var cell := Vector2i(0, 0)
## 移动限制：非空时只能在字典包含的格子中移动
var restrict_to: Dictionary = {}
## 地图边界限制：防止光标移动到地图外部
var map_rect: Rect2i = Rect2i()
##第一次移动光标后delay
var first_move_delay := 0.3
##之后光标移动delay
var repeat_delay := 0.12
##移动delay
var move_delay := first_move_delay
##记录时间
var timer := 0.0


func _ready() -> void:
	cell = Vector2i(round(position.x / Global.TILE_SIZE), round(position.y / Global.TILE_SIZE))


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
	# 地图边界限制保护
	if map_rect.has_area() and not map_rect.has_point(new_cell):
		move_delay = first_move_delay
		timer = 0.0
		return

	#判断可移动路径是否为空  
	if restrict_to.is_empty() or restrict_to.has(new_cell):
		cell = new_cell
		global_position = Vector2(cell) * Global.TILE_SIZE
		timer += move_delay
		move_delay = repeat_delay


func set_cell(new_cell: Vector2i) -> void:
	cell = new_cell
	global_position = Vector2(cell) * Global.TILE_SIZE
