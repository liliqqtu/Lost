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

@export_group("技能信息")
## 唯一 ID（推荐用英文，如 &"flourish" &"lost" &"mitsein" &"relentless_advance"）
@export var skill_id: StringName
## 显示名（中文，如"焕发"/"仿徨"/"公在"/"笃行"）
@export var display_name: String
## 图标（人物面板技能栏使用，可空）
@export var icon: Texture2D
## 描述（tooltip 显示）
@export var description: String
## PASSIVE＝被动；POST_ACTION_NO_ATTACK＝非攻击后再移动；POST_ACTION_ALL＝行动后再移动；ACT_AGAIN＝再次行动。
@export var trigger: SkillTrigger = SkillTrigger.PASSIVE

@export_group("射程修正")
## 最小攻击射程增减（格）：负数缩短，正数增大，最终至少为 1。
@export var min_range_delta: int = 0
## 最大攻击射程增减（格）：负数缩短，正数增大，最终至少为 1；与最小射程分别配置。
@export var max_range_delta: int = 0

@export_group("能力修正")
## 属性修正字典，如 {"def_h": 2, "res": 2}；某项非零时优先于对应 Bonus 字段，不重复相加。
@export var stat_modifiers: Dictionary = {}
## 力量修正（STR）：影响物理攻击力；可填负数。
@export var bonus_str: int = 0
## 魔力修正（MAG）：影响魔法攻击力与治疗量；可填负数。
@export var bonus_mag: int = 0
## 技术修正（SKL）：影响命中、必杀；可填负数。
@export var bonus_skl: int = 0
## 速度修正（SPD）：影响攻速、回避和追击；可填负数。
@export var bonus_spd: int = 0
## 守备修正（DEF）：降低受到的物理伤害，对应字典键 def_h。
@export var bonus_def: int = 0
## 魔防修正（RES）：降低受到的魔法伤害。
@export var bonus_res: int = 0
## 幸运修正（LUK）：影响命中、回避和必杀回避。
@export var bonus_luk: int = 0
## 体格修正（CON）：当前用于抵消武器重量的攻速惩罚；救援判定仍读取单位基础体格。
@export var bonus_con: int = 0
## 移动力修正：增减可消耗的地形移动点。
@export var bonus_move: int = 0

@export_group("光环与连续攻击")
## 光环半径（曼哈顿距离/格）：0＝自身被动，正数＝给范围内其他同阵营单位提供能力修正。
@export var aura_range: int = 0
## 预留的光环目标编号（0友军/1敌军/2全部）；当前尚未按此值筛选，只对同阵营其他单位生效。
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
