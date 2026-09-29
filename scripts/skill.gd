extends Resource
##"""技能数据资源
##技能分为触发式（再移动）与被动（数值偏移）两大类
##触发类型分级：
##  PASSIVE                  持续生效（如仿徨：射程减一）
##  POST_ACTION_NO_ATTACK    非攻击行动后可再移动（普通焕发：游牧民）
##  POST_ACTION_ALL          所有行动后可再移动（焕发+：游侠/弓骑）
##数值偏移字段覆盖大部分 FE 技能（仿徨/鬼神一击/狙击等），未来出现条件型技能再扩子类
##人物面板通过 view_scene 渲染图标；技能逻辑由 BattleManager/Unit/BattleCalculator 查询"""
class_name Skill

## 触发类型
enum SkillTrigger {
	PASSIVE,
	POST_ACTION_NO_ATTACK,
	POST_ACTION_ALL,
}

## 唯一 ID（推荐用英文枚举，如 &"flourish" &"lost"）
@export var skill_id: StringName
## 显示名（中文，如"焕发"/"仿徨"）
@export var display_name: String
## 图标（人物面板技能栏使用，可空）
@export var icon: Texture2D
## 描述（tooltip 显示）
@export var description: String
## 人物面板展示场景（TextureRect + 描述，可空）
@export var view_scene: PackedScene
## 触发类型
@export var trigger: SkillTrigger = SkillTrigger.PASSIVE

##"""数值偏移：武器射程（仿徨用 -1）"""
@export var min_range_delta: int = 0
@export var max_range_delta: int = 0

## 攻击后是否还能再移动（POST_ACTION_ALL 才能）
func can_canto_after_attack() -> bool:
	return trigger == SkillTrigger.POST_ACTION_ALL

## 非攻击行动后是否还能再移动（POST_ACTION_NO_ATTACK 或 POST_ACTION_ALL 都能）
func can_canto_after_non_attack() -> bool:
	return trigger == SkillTrigger.POST_ACTION_NO_ATTACK \
		or trigger == SkillTrigger.POST_ACTION_ALL
