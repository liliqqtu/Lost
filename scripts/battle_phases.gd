class_name BattlePhases
extends RefCounted

##回合系统（自 battle_manager.gd 分包，阶段四 + 5E 地图事件）：
##玩家/敌方回合切换、回合横幅信号广播、敌方 AI 行动调度、回合开始地图事件检查。
##事件执行器为关卡侧注入的 async 回调（run_map_event）。

var bm: BattleManager
##地图事件列表与关卡侧执行器（阶段五 5E；runner 为关卡脚本的 async 回调）
var map_events: Array[MapEvent] = []
var _event_runner: Callable


##设置地图事件与执行器（阶段五 5E）：runner 签名 func(event: MapEvent) -> void（可 async）
func set_map_events(events: Array[MapEvent], runner: Callable) -> void:
	map_events = events
	_event_runner = runner


##战斗开始：广播玩家回合（播放开局横幅），横幅后检查回合事件（阶段五 5E）
func begin_battle() -> void:
	bm.turn_started.emit(0)
	await bm.get_tree().create_timer(1.35).timeout
	await _run_map_events()


##我方全部行动完毕则进入敌方回合
func check_player_phase_end() -> void:
	for unit in bm.units:
		##被救起脱离地图的单位当回合不可行动，不算"未行动"（全队被救/行动完时回合才能正确结束）
		if unit.team == 0 and not unit.has_acted and unit.carried_by == null:
			return
	start_enemy_phase()


##开始敌方回合：播放横幅后依次执行每个敌人的 AI 决策
func start_enemy_phase() -> void:
	bm.phase = 1
	bm.state = BattleManager.State.ENEMY_TURN
	bm.cursor.set_process(false)
	bm.cursor.visible = false
	bm.turn_started.emit(1)
	await bm.get_tree().create_timer(0.9).timeout
	##遍历快照：循环中敌人可能死于我方反击被移除
	for enemy in bm.units.duplicate():
		if bm.battle_over:
			break
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.team != 1 or enemy.has_acted:
			continue
		await _execute_enemy_action(enemy)
	bm.current_ai_unit = null
	if not bm.battle_over:
		start_player_phase()


##开始玩家回合：回合数+1，重置全部单位的行动状态与灰度
##横幅播完后检查地图事件（5E），事件演绎完才交还控制权
func start_player_phase() -> void:
	bm.turn += 1
	bm.phase = 0
	for unit in bm.units:
		unit.has_acted = false
		unit.remove_grayscale()
	bm.cursor.visible = true
	bm.turn_started.emit(0)
	await bm.get_tree().create_timer(1.35).timeout
	await _run_map_events()
	bm.state = BattleManager.State.CURSOR
	bm.cursor.set_process(true)


##检查并依次执行本回合触发的地图事件（5E）：EVENT 状态阻塞输入，执行器为关卡侧回调
func _run_map_events() -> void:
	for e in map_events:
		if e.done:
			continue
		if e.trigger != MapEvent.Trigger.TURN_START or e.trigger_turn != bm.turn:
			continue
		if e.once:
			e.done = true
		bm.state = BattleManager.State.EVENT
		bm.cursor.set_process(false)
		await _event_runner.call(e)
	if bm.phase == 0 and bm.state == BattleManager.State.EVENT:
		bm.state = BattleManager.State.CURSOR
		bm.cursor.set_process(true)


##执行单个敌人的行动：AI 决策 -> 移动 -> 攻击 -> 标记已行动
func _execute_enemy_action(enemy: Unit) -> void:
	bm.current_ai_unit = enemy
	var plan: Dictionary = EnemyAI.decide(enemy, bm.units, bm.tile_map)
	var destination: Vector2i = plan["move_to"]
	if destination != enemy.cell:
		await bm.move_unit(enemy, destination)
		await bm.get_tree().create_timer(0.2).timeout
	if bm.battle_over:
		bm.current_ai_unit = null
		return
	var target = plan["target"]
	if target != null and is_instance_valid(target) and not target.is_queued_for_deletion() and bm.units.has(target):
		await bm.combat.execute_attack(enemy, target)
		await bm.get_tree().create_timer(0.3).timeout
	##敌人可能死于我方反击，标记已行动前需判存活
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
		enemy.has_acted = true
		enemy.apply_grayscale()
	bm.current_ai_unit = null
