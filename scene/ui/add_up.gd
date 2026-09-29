extends Control
## 阿基米德线显示星星 总动画时长为星星数量*星星出现的间隔时间：count * spawn_interval
## 升级系统：改为受控播放——grade_up 场景调用 play() 触发，不再 _ready 自动播放

const STAR_SCENE := preload("res://scene/ui/star.tscn")
## 角度
var theta := 0.0
## 变化的角度
var theta_change := TAU / 15
var spawn_timer := 0.0

## 下一个星星的时间
var spawn_interval := 0.08
## 箭头间隔的时间
var arrowt_spawn := 0.2

var a := 2
var b := 2
## 一共出现的星星数量
var count := 15

func _ready() -> void:
	$"1".visible = false
	$"+".visible = false


##"""播放加点动画：星星螺旋 + 箭头推进 + "1"/"+" 显示
##await 到两条动画全部播完；可重复播放（每次重置计数与角度）"""
func play() -> void:
	count = 15
	theta = 0.0
	$"1".visible = false
	$"+".visible = false
	await play_star()
	await play_arrowt()
	

func play_arrowt():
	var n := 6
	$Arrowt.frame = 0
	while n :
		n = n - 1
		await get_tree().create_timer(0.2).timeout
		$Arrowt.frame += 1
	$"1".visible = true
	$"+".visible = true


func play_star():
	while count :
		count = count - 1
		theta += theta_change
		spawn_star()
		await get_tree().create_timer(spawn_interval).timeout


func spiral_position() -> Vector2:
	var r = a + b * theta

	return Vector2(
		cos(theta) * r,
		sin(theta) * r
	)

func spawn_star():
	var star = STAR_SCENE.instantiate()

	star.position = spiral_position()
	star.frame = 2
	add_child(star)

	theta += theta_change
