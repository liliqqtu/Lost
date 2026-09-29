extends SceneTree

##P1 验证：救援/放下/交接（BattleRescue + Unit.can_rescue + Aid）
##覆盖：
##  1. Unit.Aid 公式：步行=con-1 / 骑乘男=25-con / 骑乘女=20-con
##  2. Unit.can_rescue：未携带 + 目标未被救 + Aid ≥ 对方 con
##  3. BattleRescue._execute_rescue：被救者脱离地图挂在救援者身上
##  4. BattleRescue._execute_drop：解除救援关系 + 放回空格 + 灰度 + has_acted
##  5. BattleRescue._execute_give：救援关系从 giver 转移到 receiver
##  6. BattleRescue._rescue_candidates：仅邻接 + 同队 + Aid 足够
##  7. BattleRescue._trade_candidates：邻接同队 + 未被救
##运行：godot --headless --path . -s res://tests/test_rescue.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	# ===== 场景一：Aid 公式（无职业数据兜底为步行）=====
	var u_foot := _make_unit("步行", 7)
	assert(u_foot.get_aid() == 6, "[场景一] 步行 Aid = con-1 = 6")

	# 有 ClassData（骑乘男/骑乘女）
	var class_male := _make_class_data(ClassData.MountType.MOUNTED_MALE)
	var class_female := _make_class_data(ClassData.MountType.MOUNTED_FEMALE)
	var u_male := _make_unit("骑男", 10)
	u_male.class_data = class_male
	assert(u_male.get_aid() == 15, "[场景一] 骑乘男 Aid = 25-con = 15")
	var u_female := _make_unit("骑女", 10)
	u_female.class_data = class_female
	assert(u_female.get_aid() == 10, "[场景一] 骑乘女 Aid = 20-con = 10")
	print("场景一 通过：Aid 公式（步行/骑男/骑女）")

	# ===== 场景二：can_rescue =====
	var rescuer := _make_unit("救援者", 10)  ##Aid = 9
	var target := _make_unit("被救者", 5)    ##con = 5
	target.cell = Vector2i(6, 5)
	rescuer.cell = Vector2i(5, 5)
	assert(rescuer.can_rescue(target), "[场景二] Aid 9 ≥ con 5，可救")

	##已被救则不可再救
	var rescuer_b := _make_unit("救援者B", 10)
	rescuer_b.cell = Vector2i(7, 5)
	target.carried_by = rescuer_b
	assert(not rescuer.can_rescue(target), "[场景二] 目标已被救 → 不可救")
	target.carried_by = null

	##Aid 不足
	var weak_rescuer := _make_unit("弱救援", 5)  ##Aid = 4
	weak_rescuer.cell = Vector2i(5, 5)
	assert(not weak_rescuer.can_rescue(target), "[场景二] Aid 4 < con 5 → 不可救")
	print("场景二 通过：can_rescue 条件")

	# ===== 场景三：_execute_rescue（状态变更；_end_action 在测试环境下安全）=====
	##最小 BattleManager + tile_map + cursor；救援通过 BM.get_unit_at 查邻接（P2 公开接口）
	var bm := _make_minimal_bm([rescuer, target])
	rescuer.cell = Vector2i(5, 5)
	target.cell = Vector2i(6, 5)
	bm.selected_unit = rescuer
	bm.rescue._execute_rescue(target)
	assert(rescuer.carried_unit == target, "[场景三] 救援者 carrying target")
	assert(target.carried_by == rescuer, "[场景三] target.carried_by = 救援者")
	assert(target.rescue == true, "[场景三] target.rescue = true（人物面板状态）")
	assert(target.visible == false, "[场景三] 被救者隐藏")
	assert(target.cell == Unit.OFF_MAP_CELL, "[场景三] 哨兵坐标 OFF_MAP_CELL")
	assert(bm.units.has(target), "[场景三] 仍在 units 列表（仅脱离地图，未移除）")
	print("场景三 通过：_execute_rescue")

	# ===== 场景四：_execute_drop =====
	##(7,5) 是道路地形，放下后回到地图
	bm.rescue._execute_drop(Vector2i(7, 5))
	assert(rescuer.carried_unit == null, "[场景四] 救援关系解除")
	assert(target.carried_by == null, "[场景四] target 不再被携带")
	assert(target.rescue == false, "[场景四] rescue 状态清空")
	assert(target.cell == Vector2i(7, 5), "[场景四] 放回指定格")
	assert(target.visible == true, "[场景四] 重新可见")
	assert(target.has_acted == true, "[场景四] 放下后本回合不可行动（FE8）")
	print("场景四 通过：_execute_drop")

	# ===== 场景五：_execute_give（不调用 _end_action）=====
	##复位：再次救援并脱离
	rescuer.carried_unit = target
	target.carried_by = rescuer
	target.cell = Unit.OFF_MAP_CELL
	target.visible = false
	target.has_acted = false
	target.rescue = true
	var receiver := _make_unit("交接方", 10)  ##Aid = 9，足够救起 con=5
	receiver.cell = Vector2i(6, 5)
	var bm2 := _make_minimal_bm([rescuer, target, receiver])
	bm2.selected_unit = rescuer
	bm2.rescue._execute_give(receiver)
	assert(rescuer.carried_unit == null, "[场景五] 交接方（原救援者）卸下")
	assert(receiver.carried_unit == target, "[场景五] 交接方接管 target")
	assert(target.carried_by == receiver, "[场景五] target.carried_by 更新为 receiver")
	assert(target.cell == Unit.OFF_MAP_CELL, "[场景五] 仍脱离地图")
	print("场景五 通过：_execute_give")

	# ===== 场景六：_rescue_candidates（邻接+同队+Aid 足够）=====
	var host := _make_unit("主", 10)
	host.cell = Vector2i(5, 5)
	var f1 := _make_unit("友军1", 5, 0, Vector2i(6, 5))  ##邻接友军
	var f2 := _make_unit("友军2", 5, 0, Vector2i(8, 5))  ##不邻接
	var e := _make_unit("敌人", 5, 1, Vector2i(5, 6))    ##邻接但不同队
	var bm3 := _make_minimal_bm([host, f1, f2, e])
	var cands: Array[Unit] = bm3.rescue._rescue_candidates(host)
	assert(cands.size() == 1, "[场景六] 仅 1 个候选（f1）")
	assert(cands[0] == f1, "[场景六] 候选 = 友军1")
	##Aid 不足：另一个友军 con=15 > Aid=9
	var heavy_friend := _make_unit("重装", 15, 0, Vector2i(4, 6))  ##邻接但 Aid<con
	var bm4 := _make_minimal_bm([host, heavy_friend])
	var cands2: Array[Unit] = bm4.rescue._rescue_candidates(host)
	assert(cands2.is_empty(), "[场景六] Aid 不足 → 不在候选")
	print("场景六 通过：_rescue_candidates 过滤")

	# ===== 场景七：_trade_candidates（邻接同队+未被救）=====
	var trade_cands: Array[Unit] = bm3.rescue._trade_candidates(host)
	assert(trade_cands.has(f1), "[场景七] trade_candidates 含邻接友军 f1")
	assert(not trade_cands.has(f2), "[场景七] trade_candidates 不含非邻接")
	assert(not trade_cands.has(e), "[场景七] trade_candidates 不含敌方")
	print("场景七 通过：_trade_candidates 过滤")

	print("===== P1 救援测试全部通过 =====")
	for u in [rescuer, target, u_foot, u_male, u_female, rescuer_b, weak_rescuer,
			receiver, host, f1, f2, e, heavy_friend]:
		if is_instance_valid(u):
			u.queue_free()
	for b in [bm, bm2, bm3, bm4]:
		if is_instance_valid(b):
			b.queue_free()
	quit()


##"""构造最小 BattleManager（带 cursor/tile_map 让 _end_action 不崩）"""
func _make_minimal_bm(p_units: Array[Unit]) -> BattleManager:
	var bm := BattleManager.new()
	bm.units = p_units
	bm.tile_map = _build_test_tile_map()
	bm.high_light_layer = _build_test_tile_map()
	bm.cursor = Node2D.new()
	root.add_child(bm)
	root.add_child(bm.cursor)
	return bm


##"""构造测试 Unit（用 unit.tscn 提供完整节点结构，apply_grayscale 等需要）"""
func _make_unit(p_name: String, p_con: int, p_team: int = 0, p_cell: Vector2i = Vector2i.ZERO) -> Unit:
	var u := preload("res://scene/character/unit.tscn").instantiate() as Unit
	u.unit_name = p_name
	u.con = p_con
	u.max_hp = 20
	u.hp = 20
	u.team = p_team
	u.cell = p_cell
	return u


##"""构造 ClassData（仅填 MountType）"""
func _make_class_data(mt: int) -> ClassData:
	var c := ClassData.new()
	c.mount_type = mt
	return c


##"""构造 8x8 全道路测试地图（道路 move_table = 1）"""
func _build_test_tile_map() -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "Name")
	tile_set.set_custom_data_layer_type(0, TYPE_STRING)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(Image.create_empty(16, 16, false, Image.FORMAT_RGBA8))
	tile_set.add_source(source, 0)
	source.create_tile(Vector2i(0, 0))
	source.get_tile_data(Vector2i(0, 0), 0).set_custom_data("Name", "道路")
	var tile_map := TileMapLayer.new()
	tile_map.tile_set = tile_set
	for x in range(8):
		for y in range(8):
			tile_map.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	return tile_map