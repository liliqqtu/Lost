class_name ActionReinforce extends MapAction
##"""事件动作：单位增援登场（阶段五 5E）
##两种来源二选一：
##  1. placed_node_name —— 关卡场景里预摆的单位节点（如 Units/Isar，
##     开局由关卡脚本隐藏，登场时淡入；位置=编辑器摆放处，适合主角团登场）
##  2. unit_scene —— 直接实例化的单位场景（适合敌军增援批量刷兵）
##登场后可选走位到 walk_to（Vector2i.MIN = 原地不动）"""

## 预摆单位节点名（Units 下的名字，空 = 不用此来源）
@export var placed_node_name := ""
## 实例化的单位场景（与 placed_node_name 互斥，优先用预摆节点）
@export var unit_scene: PackedScene
## 实例化时的出生格（预摆节点忽略此值，用编辑器位置；MIN = 场景自带位置）
@export var spawn_cell := Vector2i.MIN
## 登场后走到的格子（MIN = 不走）
@export var walk_to := Vector2i.MIN
## 淡入时长（秒，0 = 无登场动画）
@export var fade_in_time := 0.4


func execute(ctx) -> void:
	var unit: Unit = null
	if placed_node_name != "" and ctx.has_node("Units/" + placed_node_name):
		##预摆节点：关卡脚本开局已隐藏，这里显形
		unit = ctx.get_node("Units/" + placed_node_name) as Unit
	elif unit_scene != null:
		unit = unit_scene.instantiate() as Unit
		ctx.get_node("Units").add_child(unit)
		if spawn_cell != Vector2i.MIN:
			unit.global_position = Vector2(spawn_cell) * Global.TILE_SIZE
	if unit == null:
		return

	##格子坐标以实际位置为准
	unit.cell = Vector2i(unit.global_position / Global.TILE_SIZE)
	unit.visible = true

	##登场动画占位：淡入（以后可换专门的登场演出）
	if fade_in_time > 0.0:
		unit.modulate.a = 0.0
		var tween := unit.create_tween()
		tween.tween_property(unit, "modulate:a", 1.0, fade_in_time)

	##注册进战斗（之后可被选中/AI 识别/面板查看）
	ctx.battle_manager.add_unit(unit)
	##事件演绎期间相机跟随
	ctx.battle_manager.cutscene_focus = unit

	if fade_in_time > 0.0:
		##Resource 不在场景树里没有 get_tree()，借已进树的单位节点拿 SceneTree
		await unit.get_tree().create_timer(fade_in_time).timeout

	##走位到目标格（复用通用移动：避开单位寻路 + 步进动画）
	if walk_to != Vector2i.MIN and walk_to != unit.cell:
		await ctx.battle_manager.move_unit(unit, walk_to)
		unit.play_idle_animation()

	ctx.battle_manager.cutscene_focus = null
