extends SceneTree

##P1 验证：回合切换与胜负判定（BattlePhases + _check_battle_end）
##覆盖：
##  1. _check_battle_end：双方都存活 → 不结束
##  2. _check_battle_end：玩家全灭 → 我方败北
##  3. _check_battle_end：敌方全灭 → 我方胜利
##  4. _check_battle_end：battle_over 已 true → 不再触发
##  5. check_player_phase_end：未行动玩家存在 → 不进入敌方回合
##  6. check_player_phase_end：全部玩家已行动 → 进入敌方回合
##  7. check_player_phase_end：被救起的玩家不计入"未行动"
##运行：godot --headless --path . -s res://tests/test_phase_end.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	# ===== 场景一：双方都存活 =====
	var bm1 := _make_minimal_bm([
		_make_unit("玩家", 5, 0),
		_make_unit("敌人", 5, 1),
	])
	bm1.turn = 1
	bm1._check_battle_end()
	assert(not bm1.battle_over, "[场景一] 双方都存活 → battle_over 仍为 false")
	print("场景一 通过：双方都存活不结束")

	# ===== 场景二：玩家全灭 → 败北 =====
	var bm2 := _make_minimal_bm([
		_make_unit("敌人1", 5, 1),
		_make_unit("敌人2", 5, 1),
	])
	bm2.turn = 3
	bm2._check_battle_end()
	assert(bm2.battle_over, "[场景二] 玩家全灭 → battle_over = true")
	print("场景二 通过：玩家全灭判败北")

	# ===== 场景三：敌方全灭 → 胜利 =====
	var bm3 := _make_minimal_bm([
		_make_unit("玩家1", 5, 0),
		_make_unit("玩家2", 5, 0),
	])
	bm3.turn = 5
	bm3._check_battle_end()
	assert(bm3.battle_over, "[场景三] 敌方全灭 → battle_over = true")
	print("场景三 通过：敌方全灭判胜利")

	# ===== 场景四：battle_over 已 true → 不再打印/触发 =====
	var bm4 := _make_minimal_bm([
		_make_unit("玩家", 5, 0),
	])
	bm4.battle_over = true
	bm4.turn = 99
	bm4._check_battle_end()
	##不应报错，也不应改变 battle_over（已是 true）
	assert(bm4.battle_over, "[场景四] battle_over 锁定为 true 不再变")
	print("场景四 通过：battle_over 锁定")

	# ===== 场景五：未行动玩家存在 → 不进敌方回合 =====
	var bm5 := _make_minimal_bm([
		_make_unit("玩家1", 5, 0, true),  ##has_acted = true
		_make_unit("玩家2", 5, 0, false), ##has_acted = false（未行动）
		_make_unit("敌人", 5, 1, true),   ##has_acted = true（不会执行）
	])
	bm5.turn = 1
	bm5.phase = 0
	bm5.phases.check_player_phase_end()
	##不应进入敌方回合：phase 应保持 0
	assert(bm5.phase == 0, "[场景五] 有未行动玩家 → 仍在玩家回合 phase=0")
	assert(bm5.state != BattleManager.State.ENEMY_TURN, "[场景五] 状态未切到 ENEMY_TURN")
	print("场景五 通过：未行动玩家阻塞回合切换")

	# ===== 场景六：全部玩家已行动 → 进入敌方回合 =====
	var bm6 := _make_minimal_bm([
		_make_unit("玩家1", 5, 0, true),
		_make_unit("玩家2", 5, 0, true),
		_make_unit("玩家3", 5, 0, true),
	])
	bm6.turn = 2
	bm6.phase = 0
	bm6.phases.check_player_phase_end()
	##start_enemy_phase 第一行就是 phase = 1
	assert(bm6.phase == 1, "[场景六] 玩家全行动 → phase=1")
	assert(bm6.state == BattleManager.State.ENEMY_TURN, "[场景六] 状态=ENEMY_TURN")
	print("场景六 通过：全部行动进入敌方回合")

	# ===== 场景七：被救起的玩家不算"未行动" =====
	var bm7 := _make_minimal_bm([
		_make_unit("玩家1", 5, 0, false), ##未行动，应阻塞回合切换
	])
	bm7.turn = 1
	bm7.phase = 0
	bm7.phases.check_player_phase_end()
	assert(bm7.phase == 0, "[场景七] 未行动玩家 → 不进敌方回合")
	##现在把这个玩家设为被救起（carried_by != null），应视为"已行动"
	var carried := bm7.units[0]
	carried.carried_by = _make_unit("救援者", 5, 0)  ##随便一个单位做载体
	bm7.phase = 0
	bm7.phases.check_player_phase_end()
	assert(bm7.phase == 1, "[场景七] 被救玩家不算未行动 → 进入敌方回合")
	print("场景七 通过：被救起单位不算未行动")

	print("===== P1 回合/胜负测试全部通过 =====")
	for b in [bm1, bm2, bm3, bm4, bm5, bm6, bm7]:
		if is_instance_valid(b):
			b.queue_free()
	quit()


##"""构造最小 BattleManager（仅含 units）"""
func _make_minimal_bm(p_units: Array[Unit]) -> BattleManager:
	var bm := BattleManager.new()
	bm.units = p_units
	bm.cursor = Node2D.new()
	root.add_child(bm)
	root.add_child(bm.cursor)
	return bm


##"""构造测试 Unit（不入树，绕过 _ready）"""
func _make_unit(p_name: String, p_con: int, p_team: int = 0, p_has_acted: bool = false) -> Unit:
	var u := Unit.new()
	u.unit_name = p_name
	u.con = p_con
	u.max_hp = 20
	u.hp = 20
	u.team = p_team
	u.has_acted = p_has_acted
	return u