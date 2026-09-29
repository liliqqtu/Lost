extends SceneTree

##P2 批次2 验证：BattleManager 公开查询/操作接口
##覆盖：
##  1. get_unit_at：命中返回单位，空格返回 null
##  2. get_blocked_cells：排除 exclude_unit，包含其余单位
##  3. remove_unit：从 units 移除 + 进入删除队列
##  4. remove_unit：移除最后一个敌人 → 触发胜负判定 battle_over
##  5. undo_move：坐标还原到移动前 + 重新选中（UNIT_SELECTED + move_range 重算 + 子行动标记重置）
##  6. undo_move：selected_unit 为空 → 安全返回
##  7. undo_move：selected_unit 已失效（queue_free）→ 安全返回
##运行：godot --headless --path . -s res://tests/test_bm_public_api.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	# ===== 场景一：get_unit_at =====
	var u1 := _make_unit("玩家甲")
	u1.cell = Vector2i(1, 1)
	var u2 := _make_unit("敌人乙")
	u2.cell = Vector2i(3, 2)
	u2.team = 1
	var bm1 := _make_minimal_bm([u1, u2])
	assert(bm1.get_unit_at(Vector2i(1, 1)) == u1, "[场景一] (1,1) 返回玩家甲")
	assert(bm1.get_unit_at(Vector2i(3, 2)) == u2, "[场景一] (3,2) 返回敌人乙")
	assert(bm1.get_unit_at(Vector2i(0, 0)) == null, "[场景一] 空格返回 null")
	print("场景一 通过：get_unit_at 查询正确")

	# ===== 场景二：get_blocked_cells =====
	var blocked := bm1.get_blocked_cells(u1)
	assert(blocked.has(Vector2i(3, 2)), "[场景二] 遮挡列表包含他人格子")
	assert(not blocked.has(Vector2i(1, 1)), "[场景二] 排除 exclude_unit 自身格子")
	var blocked_all := bm1.get_blocked_cells()
	assert(blocked_all.has(Vector2i(1, 1)) and blocked_all.has(Vector2i(3, 2)),
		"[场景二] 不传排除单位时全部单位格子都在遮挡列表")
	print("场景二 通过：get_blocked_cells 排除规则正确")

	# ===== 场景三：remove_unit 移除 + 删除队列 =====
	var bm3 := _make_minimal_bm([
		u1,
		_make_unit("敌人丙", 1, Vector2i(2, 2)),
		_make_unit("敌人丁", 1, Vector2i(2, 3)),
	])
	var enemy3: Unit = bm3.units[1]
	bm3.remove_unit(enemy3)
	assert(not bm3.units.has(enemy3), "[场景三] 敌人丙已从 units 移除")
	assert(enemy3.is_queued_for_deletion(), "[场景三] 敌人丙进入删除队列")
	assert(bm3.units.size() == 2, "[场景三] 其余单位不受影响")
	assert(not bm3.battle_over, "[场景三] 仍有敌人丁存活，不触发胜负")
	print("场景三 通过：remove_unit 移除单位")

	# ===== 场景四：remove_unit 触发胜负判定 =====
	##只放一个玩家和一个敌人，移除敌人 → 敌方全灭 → battle_over
	var u4 := _make_unit("玩家丁", 0, Vector2i(0, 0))
	var e4 := _make_unit("敌人戊", 1, Vector2i(2, 0))
	var bm4 := _make_minimal_bm([u4, e4])
	bm4.remove_unit(e4)
	assert(bm4.battle_over, "[场景四] 最后一个敌人被移除 → battle_over = true")
	print("场景四 通过：remove_unit 触发胜负判定")

	# ===== 场景五：undo_move 还原 + 重新选中 =====
	var u5 := _make_unit("玩家己", 0, Vector2i(1, 1))
	var bm5 := _make_minimal_bm([u5])
	bm5.selected_unit = u5
	##模拟"已移动"：记录移动前位置 (1,1)，单位现在站到 (2,2)
	bm5._pre_move_cell = Vector2i(1, 1)
	u5.cell = Vector2i(2, 2)
	bm5.mark_action_spent()
	bm5.undo_move()
	assert(u5.cell == Vector2i(1, 1), "[场景五] 单位撤回到移动前位置 (1,1)")
	assert(bm5.selected_unit == u5, "[场景五] 重新进入选中状态")
	assert(bm5.state == BattleManager.State.UNIT_SELECTED, "[场景五] 状态 = UNIT_SELECTED")
	assert(not bm5.move_range.is_empty(), "[场景五] 移动范围已重算")
	assert(bm5.cursor.restrict_to == bm5.move_range, "[场景五] 光标限制 = 新移动范围")
	assert(not bm5.is_action_spent(), "[场景五] 子行动标记被重置为 false")
	print("场景五 通过：undo_move 还原并重新选中")

	# ===== 场景六：undo_move selected_unit 为空 =====
	var bm6 := _make_minimal_bm([])
	bm6.selected_unit = null
	bm6.undo_move()  ##不应崩溃
	print("场景六 通过：undo_move 对空 selected_unit 安全")

	# ===== 场景七：undo_move selected_unit 已失效 =====
	var u7 := _make_unit("阵亡者", 0, Vector2i(1, 1))
	var bm7 := _make_minimal_bm([])
	u7.queue_free()
	bm7.selected_unit = u7
	bm7.undo_move()  ##不应崩溃
	assert(bm7.selected_unit == u7, "[场景七] 不修改失效单位，交由后续收尾清空")
	print("场景七 通过：undo_move 对失效 selected_unit 安全")

	print("===== P2 批次2 公开接口测试全部通过 =====")
	for b in [bm1, bm3, bm4, bm5, bm6, bm7]:
		if is_instance_valid(b):
			b.queue_free()
	quit()


##"""构造最小 BattleManager（tile_map/high_light_layer 给 Pathfinder 与范围绘制，cursor 用真实脚本节点）"""
func _make_minimal_bm(p_units: Array[Unit]) -> BattleManager:
	var bm := BattleManager.new()
	bm.units = p_units
	bm.tile_map = _build_test_tile_map()
	bm.high_light_layer = _build_test_tile_map()
	bm.cursor = load("res://scene/ui/cursor.gd").new()
	root.add_child(bm)
	root.add_child(bm.cursor)
	return bm


##"""构造测试 Unit（用 unit.tscn 提供完整节点，play_selected_animation 需要）"""
func _make_unit(p_name: String, p_team: int = 0, p_cell: Vector2i = Vector2i.ZERO) -> Unit:
	var u := preload("res://scene/character/unit.tscn").instantiate() as Unit
	u.unit_name = p_name
	u.team = p_team
	u.cell = p_cell
	u.max_hp = 20
	u.hp = 20
	return u


##"""构造 4x4 全道路测试地图"""
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
	for x in range(4):
		for y in range(4):
			tile_map.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	return tile_map
