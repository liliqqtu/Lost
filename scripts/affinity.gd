extends Resource
class_name Affinity

##"""属性资源（5G 支援系统）：属性名 / 图标 / 属性贡献加成
##支援总加成 = 双方属性贡献之和 × 支援等级倍率（SupportStore.LEVEL_SCALE），支援对象 3 格内生效
##数据资源在 data/affinity/（fire/dark/anim/thunder/ice/light/wind）
##ClassData.affinity 选择对应资源（人物面板 BaseInfo/AffinityIcon 显示其图标）"""

@export_group("属性信息")
## 属性名（炎/暗/理…），这里是支援属性，不等同于武器类型。
@export var affinity_name := ""
##属性图标（人物面板属性位 + 支援列表行图标，res://assets/graphics/UI/AffinityIcon/）
@export var icon: Texture2D
@export_group("每级支援贡献")
## 命中贡献（百分点）：与支援对象的贡献相加后，再乘支援等级倍率。
@export var hit_bonus := 0
## 回避贡献（百分点）：与支援对象的贡献相加后，再乘支援等级倍率。
@export var avoid_bonus := 0
## 必杀贡献（百分点）：与支援对象的贡献相加后，再乘支援等级倍率。
@export var crit_bonus := 0
