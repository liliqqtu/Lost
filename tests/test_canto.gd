extends SceneTree

##P1 验证：Canto 技能等级与行动收尾决策
##覆盖：
##  1. Unit.get_canto_trigger() 优先级：POST_ACTION_ALL > POST_ACTION_NO_ATTACK > PASSIVE
##  2. Unit.can_canto_after_attack：仅 POST_ACTION_ALL 触发
##  3. Unit.can_canto_after_non_attack：POST_ACTION_NO_ATTACK 或 POST_ACTION_ALL
##  4. ClassData.skills 与 personal_skills 合并
##  5. 空技能列表 → can_canto_after_* 均为 false
##  6. end_action 决策：mark_attack_action + Canto 触发 → 进 Canto
##  7. end_action 决策：allow_canto=false 跳过 Canto（待机主动放弃）
##  8. end_action：selected_unit 被反击击杀 → 不崩
##  9. finalize_action 统一收尾：清空选中上下文并回 CURSOR（P2 单一收尾入口）
##运行：godot --headless --path . -s res://tests/test_canto.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	# ===== 场景一：trigger 优先级 =====
	var s_all := _make_skill("焕发-全", Skill.SkillTrigger.POST_ACTION_ALL)
	var s_noatk := _make_skill("焕发-非攻击", Skill.SkillTrigger.POST_ACTION_NO_ATTACK)
	var s_passive := _make_skill("被动", Skill.SkillTrigger.PASSIVE)

	var u1 := _make_unit("甲")
	u1.personal_skills = [s_all, s_noatk, s_passive]
	assert(u1.get_canto_trigger() == Skill.SkillTrigger.POST_ACTION_ALL,
		"[场景一] POST_ACTION_ALL 优先级最高")

	var u2 := _make_unit("乙")
	u2.personal_skills = [s_noatk, s_passive]
	assert(u2.get_canto_trigger() == Skill.SkillTrigger.POST_ACTION_NO_ATTACK,
		"[场景一] 无 POST_ACTION_ALL 时取 POST_ACTION_NO_ATTACK")

	var u3 := _make_unit("丙")
	u3.personal_skills = [s_passive]
	assert(u3.get_canto_trigger() == Skill.SkillTrigger.PASSIVE,
		"[场景一] 仅 PASSIVE → 返回 PASSIVE")

	var u4 := _make_unit("丁")
	u4.personal_skills = []
	assert(u4.get_canto_trigger() == Skill.SkillTrigger.PASSIVE,
		"[场景一] 空技能列表 → PASSIVE")
	print("场景一 通过：get_canto_trigger 优先级")

	# ===== 场景二：can_canto_after_attack =====
	assert(u1.can_canto_after_attack(), "[场景二] POST_ACTION_ALL → 攻击后可 Canto")
	assert(not u2.can_canto_after_attack(), "[场景二] POST_ACTION_NO_ATTACK → 攻击后不可 Canto")
	assert(not u3.can_canto_after_attack(), "[场景二] PASSIVE → 攻击后不可 Canto")
	print("场景二 通过：can_canto_after_attack")

	# ===== 场景三：can_canto_after_non_attack =====
	assert(u1.can_canto_after_non_attack(), "[场景三] POST_ACTION_ALL → 非攻击后可 Canto")
	assert(u2.can_canto_after_non_attack(), "[场景三] POST_ACTION_NO_ATTACK → 非攻击后可 Canto")
	assert(not u3.can_canto_after_non_attack(), "[场景三] PASSIVE → 非攻击后不可 Canto")
	print("场景三 通过：can_canto_after_non_attack")

	# ===== 场景四：ClassData.skills 与 personal_skills 合并 =====
	var u5 := _make_unit("戊")
	var class_data := ClassData.new()
	class_data.skills = [s_noatk]
	u5.class_data = class_data
	u5.personal_skills = []
	assert(u5.can_canto_after_non_attack(), "[场景四] 职业技能触发 Canto")

	var u6 := _make_unit("己")
	var cd6 := ClassData.new()
	cd6.skills = [s_noatk]
	u6.class_data = cd6
	u6.personal_skills = [s_all]
	assert(u6.get_canto_trigger() == Skill.SkillTrigger.POST_ACTION_ALL,
		"[场景四] 个人技能 ALL 覆盖职业 NO_ATTACK")
	print("场景四 通过：ClassData + personal 合并查询")

	# ===== 场景五：end_action 触发 Canto（P2：走公开接口）=====
	var bm := _make_minimal_bm([u1])
	bm.selected_unit = u1
	u1.canto_remaining = 3
	bm.mark_attack_action()
	bm.end_action(true)
	assert(bm.state == BattleManager.State.CANTO_MOVING, "[场景五] 攻击后 + Canto 技能 → CANTO_MOVING")
	assert(u1.canto_remaining == 3, "[场景五] canto_remaining 未被消耗（消耗在 _on_canto_move_complete）")
	print("场景五 通过：end_action 触发 Canto")

	# ===== 场景六：end_action(allow_canto=false) 跳过 Canto（待机）=====
	bm.selected_unit = u1
	u1.has_acted = false
	bm.mark_attack_action()
	bm.end_action(false)
	assert(bm.state == BattleManager.State.CURSOR, "[场景六] allow_canto=false → 直接 CURSOR")
	assert(u1.has_acted == true, "[场景六] selected_unit.has_acted = true")
	print("场景六 通过：allow_canto=false 跳过 Canto")

	# ===== 场景七：selected_unit 被反击击杀 → 不崩 =====
	##构造一个被 queue_free 的单位模拟"死于反击"
	var dying_unit := _make_unit("濒死")
	dying_unit.queue_free()
	bm.selected_unit = dying_unit
	bm.mark_attack_action()
	bm.end_action(true)
	assert(bm.selected_unit == null, "[场景七] 失效 selected_unit → 直接清空")
	print("场景七 通过：end_action 对失效 selected_unit 安全")

	# ===== 场景八：mark_action_spent / is_action_spent 标记读写（P2 公开接口）=====
	assert(not bm.is_action_spent(), "[场景八] 初始未标记")
	bm.mark_action_spent()
	assert(bm.is_action_spent(), "[场景八] mark_action_spent 后可读取")
	print("场景八 通过：子行动标记公开读写")

	# ===== 场景九：finalize_action 统一收尾（P2：单一收尾入口）=====
	##模拟 Canto 收尾路径：填脏上下文后调 finalize_action，验证全部清理
	bm.selected_unit = u1
	bm.move_range = {Vector2i(0, 0): true}
	bm.attack_range = [Vector2i(1, 0)]
	bm.current_path = [Vector2i(0, 0), Vector2i(1, 0)]
	bm.cursor.restrict_to = bm.move_range
	bm.state = BattleManager.State.CANTO_MOVING
	bm.finalize_action()
	assert(bm.selected_unit == null, "[场景九] selected_unit 清空")
	assert(bm.move_range.is_empty(), "[场景九] move_range 清空")
	assert(bm.attack_range.is_empty(), "[场景九] attack_range 清空")
	assert(bm.current_path.is_empty(), "[场景九] current_path 清空")
	assert(bm.cursor.restrict_to.is_empty(), "[场景九] cursor.restrict_to 清空")
	assert(bm.state == BattleManager.State.CURSOR, "[场景九] 状态回 CURSOR")
	print("场景九 通过：finalize_action 单一收尾入口")

	print("===== P1/P2 Canto 与行动收尾测试全部通过 =====")
	for u in [u1, u2, u3, u4, u5, u6, dying_unit, class_data, cd6]:
		if is_instance_valid(u):
			u.free()
	if is_instance_valid(bm):
		bm.queue_free()
	quit()


##"""构造最小 BattleManager（含 tile_map 给 Pathfinder 用；cursor 用真实脚本节点——
##enter_phase 会调 cursor.set_cell/restrict_to，裸 Node2D 没有这些成员会崩）"""
func _make_minimal_bm(p_units: Array[Unit]) -> BattleManager:
	var bm := BattleManager.new()
	bm.units = p_units
	bm.tile_map = _build_test_tile_map()
	bm.high_light_layer = _build_test_tile_map()
	bm.cursor = load("res://scene/ui/cursor.gd").new()
	root.add_child(bm)
	root.add_child(bm.cursor)
	return bm


##"""构造测试 Unit（用 unit.tscn 提供完整节点，apply_grayscale 需要）"""
func _make_unit(p_name: String) -> Unit:
	var u := preload("res://scene/character/unit.tscn").instantiate() as Unit
	u.unit_name = p_name
	u.con = 5
	u.max_hp = 20
	u.hp = 20
	u.canto_remaining = 0
	return u


##"""构造测试 Skill"""
func _make_skill(p_name: String, trigger: int) -> Skill:
	var s := Skill.new()
	s.display_name = p_name
	s.trigger = trigger
	return s


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