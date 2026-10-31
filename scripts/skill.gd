extends Resource
##"""技能数据资源（统一技能体系：武器/人物/职业共享）
##包含被动属性修正、光环辐射、再移动分级、再次行动（笃行）与勇者连续打击"""
class_name Skill

## 触发类型
enum SkillTrigger {
	PASSIVE,
	POST_ACTION_NO_ATTACK,
	POST_ACTION_ALL,
	ACT_AGAIN,
}

## 唯一 ID（推荐用英文，如 &"flourish" &"lost" &"mitsein" &"relentless_advance"）
@export var skill_id: StringName
## 显示名（中文，如"焕发"/"仿徨"/"公在"/"笃行"）
@export var display_name: String
## 图标（人物面板技能栏使用，可空）
@export var icon: Texture2D
## 描述（tooltip 显示）
@export var description: String
## 触发类型
@export var trigger: SkillTrigger = SkillTrigger.PASSIVE

## 数值偏移：武器射程（仿徨用 -1）
@export var min_range_delta: int = 0
@export var max_range_delta: int = 0

## 属性增益字典（如 {"def_h": 2, "res": 2} 或 {"skl": 10, "spd": 10}）
@export var stat_modifiers: Dictionary = {}
## 显式属性增益字段（检查器编辑方便）
@export var bonus_str: int = 0
@export var bonus_mag: int = 0
@export var bonus_skl: int = 0
@export var bonus_spd: int = 0
@export var bonus_def: int = 0
@export var bonus_res: int = 0
@export var bonus_luk: int = 0
@export var bonus_con: int = 0
@export var bonus_move: int = 0

## 光环辐射格数（0 为自身被动，>0 为辐射格数，曼哈顿距离）
@export var aura_range: int = 0
## 光环目标（0: 友军, 1: 敌军, 2: 全部）
@export var aura_targets: int = 0
## 勇者特性（连续攻击）
@export var is_brave: bool = false


## 取特定属性的加成
func get_stat_bonus(stat_name: String) -> int:
	var from_dict: int = stat_modifiers.get(stat_name, 0) as int
	var from_field := 0
	match stat_name:
		"str": from_field = bonus_str
		"mag": from_field = bonus_mag
		"skl": from_field = bonus_skl
		"spd": from_field = bonus_spd
		"def_h": from_field = bonus_def
		"res": from_field = bonus_res
		"luk": from_field = bonus_luk
		"con": from_field = bonus_con
		"move": from_field = bonus_move
	## 优先使用显式填写的字典值，未配置字典时回落到独立字段，避免两者同时存在时重复累加
	var total := from_dict if from_dict != 0 else from_field
	##兼容“公在”兜底：临近2格所有友军双防+2
	if skill_id == &"mitsein" or display_name == "公在" or display_name == "共在":
		if (stat_name == "def_h" or stat_name == "res") and total == 0:
			total = 2
	return total


## 攻击后是否还能再移动（POST_ACTION_ALL 才能）
func can_canto_after_attack() -> bool:
	return trigger == SkillTrigger.POST_ACTION_ALL


## 非攻击行动后是否还能再移动
func can_canto_after_non_attack() -> bool:
	return trigger == SkillTrigger.POST_ACTION_NO_ATTACK \
		or trigger == SkillTrigger.POST_ACTION_ALL


## 是否为再次行动技能（笃行）
func is_act_again() -> bool:
	return trigger == SkillTrigger.ACT_AGAIN or skill_id == &"relentless_advance"
