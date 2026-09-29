class_name MapEvent extends Resource
##"""地图事件（阶段五 5E）：触发条件 → 动作序列
##由关卡脚本构建（代码建事件，.tres 留给以后关卡数据化），
##BattleManager 在玩家回合开始（横幅后）检查并依次执行
##触发条件目前支持回合数，坐标/单位存活等按需扩展"""

enum Trigger { TURN_START }

## 触发类型（目前仅回合开始）
@export var trigger: Trigger = Trigger.TURN_START
## 触发回合（玩家方回合数，与 BattleManager.turn 一致）
@export var trigger_turn := 1
## 是否只触发一次
@export var once := true
## 动作序列（按顺序执行，可含异步等待）
@export var actions: Array[MapAction] = []

## 运行时标记：是否已触发过
var done := false
