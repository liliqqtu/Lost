extends Resource
class_name SupportPair

##"""支援表条目（5G 支援系统）：一对角色的支援关系数据
##谁能和谁支援、双方属性（结算与面板图标用）、各等级门槛（共同出战章节数）、支援对话
##数据资源在 data/support/（如 te_isar.tres 忒×伊萨尔）
##SupportStore（autoload）持有全部支援表，新增支援对 = 复制一份 .tres 改数据 + 在 SupportStore.PAIRS 追加"""

@export_group("支援双方")
## A 方名字：须与对应 Unit.unit_name 完全一致。
@export var unit_a := ""
## B 方名字：须与对应 Unit.unit_name 完全一致。
@export var unit_b := ""
## A 方属性：用于支援加成与图标，应与 A 方 ClassData.affinity 一致。
@export var affinity_a: Affinity
## B 方属性：用于支援加成与图标，应与 B 方 ClassData.affinity 一致。
@export var affinity_b: Affinity

@export_group("支援升级门槛")
## 升 C 所需累计支援值：双方共同出战且本章胜利加 1；达标后需相邻触发支援。
@export var threshold_c := 1
## 升 B 所需累计支援值；请设为不低于 C 门槛。
@export var threshold_b := 2
## 升 A 所需累计支援值；请设为不低于 B 门槛。
@export var threshold_a := 3

@export_group("肖像与对话")
## A 方对话肖像（Class Card 纹理）。
@export var card_a: Texture2D
## B 方对话肖像（Class Card 纹理）。
@export var card_b: Texture2D

## C 级对话：[{"speaker": "名字", "text": "台词", "side": "left1"}]；side 可用 left1/left2/right1/right2，空数组直接升级。
@export var c_lines: Array = []
## B 级对话：格式同 C Lines；空数组跳过对话并直接升级。
@export var b_lines: Array = []
## A 级对话：格式同 C Lines；空数组跳过对话并直接升级。
@export var a_lines: Array = []


##是否涉及该角色
func involves(name: String) -> bool:
	return name != "" and (unit_a == name or unit_b == name)


##另一方的名字（不在支援对内返回空串）
func partner_of(name: String) -> String:
	if unit_a == name:
		return unit_b
	if unit_b == name:
		return unit_a
	return ""


##该角色的属性（支援加成/图标用）
func affinity_of(name: String) -> Affinity:
	if unit_a == name:
		return affinity_a
	if unit_b == name:
		return affinity_b
	return null


##该角色的肖像
func card_of(name: String) -> Texture2D:
	if unit_a == name:
		return card_a
	if unit_b == name:
		return card_b
	return null


##指定等级的支援对话：1=C 2=B 3=A
func lines_for_level(level: int) -> Array:
	match level:
		1:
			return c_lines
		2:
			return b_lines
		3:
			return a_lines
	return []


##从 current_level 升到下一级所需支援值（已是 A 返回极大值）
func next_threshold(current_level: int) -> int:
	match current_level:
		0:
			return threshold_c
		1:
			return threshold_b
		2:
			return threshold_a
	return 999999
