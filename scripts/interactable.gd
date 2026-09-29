class_name Interactable extends Node2D
##"""地图可交互物（阶段五 5E）：村庄（访问）/ 宝箱（开启需对应钥匙）
##由关卡脚本扫描瓦片创建（村庄贴"民居"瓦片）或编辑器摆放，位置即格子；
##加入 interactables 组供 BattleManager 四邻接查询。
##reward 引用 .tres 模板，发放时由 BattleManager duplicate 成独立实例"""

enum Kind { VILLAGE, CHEST }

## 类型：村庄 = 访问直接给奖励；宝箱 = 需要同 key_id 的钥匙
@export var kind: Kind = Kind.VILLAGE
## 奖励物品（模板，发放时 duplicate；可空 = 空手）
@export var reward: Item
## 宝箱对应的钥匙 id（Key.key_id 与之相同才能开启）
@export var key_id := ""

## 所在格子（_ready 时由 position 换算，关卡脚本只设 position）
var cell := Vector2i.ZERO
## 是否已用过（村庄访问过 / 宝箱开过，不再出现在行动菜单）
var used := false


func _ready() -> void:
	add_to_group("interactables")
	cell = Vector2i(position / Global.TILE_SIZE)
