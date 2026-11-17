extends Resource
class_name ClassData

##"""职业数据：职业名、职业卡、能力上限、技能列表"""
##人物面板等实时读取 Unit.class_data，不在面板内复制数据；上限/技能在资源里调整即可

@export_group("职业信息与经验规则")
## 职业名（人物面板显示，如 弓骑/山贼）
@export var job_name := ""
## 职业描述
@export var job_info := ""
## 职业卡图（人物面板左上角）
@export var class_card: Texture2D
## 职业强度（经验公式 Q）：通常为 3，弱职业为 2；必须大于 0，参与伤害和击杀经验计算。
@export var class_power := 3
## 是否上位/进阶职业（如贤者、圣骑士等，FE8 经验结算等效等级 +20）
@export var is_promoted: bool = false

## 属性（5G 支援系统）：人物面板 BaseInfo/AffinityIcon 显示其图标，数据资源在 data/affinity/
## 支援结算的属性贡献查支援表 SupportPair（scripts/support_pair.gd），两边应保持一致
@export var affinity: Affinity
@export_group("能力上限与成长率")
@export_subgroup("生命 HP")
## 最大生命上限：升级时达到此值后不再增加；初始生命值仍在 Unit 上配置。
@export var cap_hp := 40
## HP 成长率（百分数）：80 表示每次升级有 80% 概率加 1；当前每项每级最多加 1。
@export var growths_hp := 80
@export_subgroup("力量 STR")
## 力量上限：限制升级增长，初始力量在 Unit.str 上配置。
@export var cap_str := 20
## 力量成长率（百分数）：40 表示每次升级有 40% 概率加 1，达到上限后不再增长。
@export var growths_str := 40
@export_subgroup("魔力 MAG")
## 魔力上限
@export var cap_mag := 20
## 魔力成长率（百分数）：每次升级独立判定是否加 1，达到上限后不再增长。
@export var growths_mag := 40
@export_subgroup("技术 SKL")
## 技术上限
@export var cap_skl := 20
## 技术成长率（百分数）：每次升级独立判定是否加 1，达到上限后不再增长。
@export var growths_skl := 40
@export_subgroup("速度 SPD")
## 速度上限
@export var cap_spd := 20
## 速度成长率（百分数）：每次升级独立判定是否加 1，达到上限后不再增长。
@export var growths_spd := 20
@export_subgroup("幸运 LUK")
## 幸运上限
@export var cap_luk := 20
## 幸运成长率（百分数）：每次升级独立判定是否加 1，达到上限后不再增长。
@export var growths_luk := 40
@export_subgroup("守备 DEF")
## 守备上限：对应 Unit.def_h，抵消物理伤害。
@export var cap_def_h := 20
## 守备成长率（百分数）：每次升级独立判定是否加 1，达到上限后不再增长。
@export var growths_def_h := 40
@export_subgroup("魔防 RES")
## 魔防上限
@export var cap_res := 20
## 魔防成长率（百分数）：每次升级独立判定是否加 1，达到上限后不再增长。
@export var growths_res := 40
@export_subgroup("移动与体格")
## 移动力上限：当前仅供人物面板上限显示，升级不会增长移动力，也不自动裁剪初始值。
@export var cap_move := 10
## 体格上限：当前仅供人物面板上限显示，升级不会增长体格，也不自动裁剪初始值。
@export var cap_con := 20
@export_group("职业技能与救援")
## 职业技能（人物面板技能栏，如 data/skills/flourish.tres 焕发=再移动）
## icon 为面板图标，trigger 字段决定技能实际生效方式
@export var skills: Array[Skill] = []

##骑乘类型（5F 救援 Aid 公式，FE8）：步行 Aid=体格-1 / 骑乘·男 Aid=25-体格 / 骑乘·女 Aid=20-体格
enum MountType { FOOT, MOUNTED_MALE, MOUNTED_FEMALE }
##骑乘类型（无职业数据的单位按步行处理）
@export var mount_type: MountType = MountType.FOOT
