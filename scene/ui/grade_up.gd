extends Control
##"""升级场景（升级系统）：人物升级后由战斗动画加载，显示职业/等级/八项能力与加点动画
##Add 下 8 个 add_up 子节点按 HP 力量 魔力 技术 速度 幸运 防御 魔防 排列，
##对应能力加点时显示并播放；多个加点依次播放（前一个快播完时开始下一个）
##人物转职后也调用此场景显示能力变化（转职功能暂不开发）
##数据全部实时读取 Unit，播完自动隐藏，无需输入"""

##加点能力键（与 Add 子节点顺序一致，也与 BattleCalculator.LEVEL_STAT_KEYS 一致）
const STAT_KEYS := ["hp", "str", "mag", "skl", "spd", "luk", "def_h", "res"]

##前一个加点动画快播完时开始下一个（add_up 全程约 1.2s）
const NEXT_DELAY := 0.9
##全部播完后停留时长
const FINISH_STAY := 5.0

@onready var _class_name_label: Label = $ClassName
@onready var _level_label: Label = $level
@onready var _card: TextureRect = $Card
@onready var _stats: VFlowContainer = $AbilityStats
@onready var _add: VFlowContainer = $Add


##"""播放升级演出：填充职业/等级/卡片/八项能力（升级后的当前值），
##按 gains（BattleCalculator.roll_level_up 结果）依次播放加点动画，await 到播完"""
func play_for(unit: Unit, gains: Dictionary) -> void:
	##职业名/职业卡（无职业数据保留场景默认）
	var cd: ClassData = unit.class_data
	if cd != null:
		_class_name_label.text = cd.job_name
		if cd.class_card != null:
			_card.texture = cd.class_card
	_level_label.text = str(unit.lv)

	##八项能力：HP 用最大生命，其余直接读字段
	for key in STAT_KEYS:
		var value := str(unit.max_hp) if key == "hp" else str(unit.get(key))
		(_stats.get_node(key) as Label).text = value
		print(value)

	##加点动画：默认全部隐藏，仅加点的项依次播放
	for child in _add.get_children():
		child.visible = false
	visible = true
	#var anim_done
	for i in STAT_KEYS.size():
		if gains.get(STAT_KEYS[i], 0) > 0:
			var anim = _add.get_child(i)
			anim.visible = true
			#anim_done = anim.play()
			anim.play()
			await get_tree().create_timer(NEXT_DELAY).timeout
			#await anim_done
			

	await get_tree().create_timer(FINISH_STAY).timeout
	visible = false
