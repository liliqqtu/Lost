extends Resource
class_name ClassData

##"""职业数据：职业名、职业卡、能力上限、技能列表"""
##人物面板等实时读取 Unit.class_data，不在面板内复制数据；上限/技能在资源里调整即可

## 职业名（人物面板显示，如 弓骑/山贼）
@export var job_name := ""
## 职业卡图（人物面板左上角）
@export var class_card: Texture2D
##"""职业强度（升级系统，FE8 经验公式 Q）：普通职业=3，弱职业=2，单位无职业数据按 3"""
@export var class_power := 3
##"""武器类型等级（升级系统）：决定职业可用的武器类型与等级上限（E..S）
##单位实际等级 = min(武器经验等级, 职业上限)，UNUSABLE=不可用该类型"""
## 剑武器等级
@export var rank_sword: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_lance: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_axe: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_bow: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_anima: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_dark: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_light: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_staff: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE

##"""武器类型 -> 职业等级上限（Weapon.WeaponRank，UNUSABLE=不可用）"""
func get_weapon_rank(type: int) -> int:
	match type:
		Weapon.WeaponType.SWORD: return rank_sword
		Weapon.WeaponType.LANCE: return rank_lance
		Weapon.WeaponType.AXE: return rank_axe
		Weapon.WeaponType.BOW: return rank_bow
		Weapon.WeaponType.ANIMA: return rank_anima
		Weapon.WeaponType.DARK: return rank_dark
		Weapon.WeaponType.LIGHT: return rank_light
		Weapon.WeaponType.STAFF: return rank_staff
	return Weapon.WeaponRank.UNUSABLE

##"""职业是否可用该武器类型"""
func can_use_weapon(type: int) -> bool:
	return get_weapon_rank(type) >= Weapon.WeaponRank.E

## 属性（5G 支援系统）：人物面板 BaseInfo/AffinityIcon 显示其图标，数据资源在 data/affinity/
## 支援结算的属性贡献查支援表 SupportPair（scripts/support_pair.gd），两边应保持一致
@export var affinity: Affinity
## HP上限（升级掷骰到顶不再加；升级系统）
@export var cap_hp := 40
## HP成长率 为升级时xx概率加点
@export var growths_hp := 80
## 力量上限
@export var cap_str := 20
## 力量成长率 为升级时xx概率加点
@export var growths_str := 40
## 魔力上限
@export var cap_mag := 20
## 魔力成长率 为升级时xx概率加点
@export var growths_mag := 40
## 技术上限
@export var cap_skl := 20
## 技术成长率 为升级时xx概率加点
@export var growths_skl := 40
## 速度上限
@export var cap_spd := 20
## 速度成长率 为升级时xx概率加点
@export var growths_spd := 20
## 幸运上限
@export var cap_luk := 20
## 幸运成长率 为升级时xx概率加点
@export var growths_luk := 40
## 守备上限
@export var cap_def_h := 20
## 守备成长率 为升级时xx概率加点
@export var growths_def_h := 40
## 魔防上限
@export var cap_res := 20
## 魔防成长率 为升级时xx概率加点
@export var growths_res := 40
## 移动力上限
@export var cap_move := 10
## 体格上限
@export var cap_con := 20
## 职业技能（人物面板技能栏，如 scene/skill/flourish.tres 焕发=再移动）
## view_scene 为面板图标（人物面板按 view_scene 实例化渲染），trigger 字段决定技能实际生效方式
@export var skills: Array[Skill] = []

##骑乘类型（5F 救援 Aid 公式，FE8）：步行 Aid=体格-1 / 骑乘·男 Aid=25-体格 / 骑乘·女 Aid=20-体格
enum MountType { FOOT, MOUNTED_MALE, MOUNTED_FEMALE }
##骑乘类型（无职业数据的单位按步行处理）
@export var mount_type: MountType = MountType.FOOT
