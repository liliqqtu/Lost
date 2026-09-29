extends SceneTree

##5G 验证：支援系统（SupportStore / SupportPair / Affinity）
##覆盖：
##  1. 支援表查询：find_pair 按双方名字（未登记返回 null）、partner_of / affinity_of / lines_for_level
##  2. 门槛与升级：支援值不足不可升；达 C 门槛升 C 后，未达 B 门槛不能再升
##  3. 加成结算：属性贡献之和 × 等级倍率；3 格内生效、超 3 格 / 异队 / 未建立支援为 0
##  4. 章节积累：双方登场且胜利 +1 点；只有一方登场不加；封顶 A 级门槛
##运行：godot --headless --path . -s res://tests/test_support.gd

func _initialize() -> void:
	_run()


func _run() -> void:
	# ===== SupportStore 隔离（autoload 是全局单例，测试前清空避免污染）=====
	SupportStore.points.clear()
	SupportStore.levels.clear()
	SupportStore.on_chapter_failed()

	# ===== 场景一：支援表查询 =====
	var pair := SupportStore.find_pair("忒", "伊萨尔")
	assert(pair != null, "[场景一] 忒×伊萨尔 应在支援表中")
	assert(pair.partner_of("忒") == "伊萨尔", "[场景一] partner_of 正确")
	assert(pair.affinity_of("忒") != null and pair.affinity_of("忒").affinity_name == "炎", "[场景一] 忒=炎属性")
	assert(pair.affinity_of("伊萨尔") != null and pair.affinity_of("伊萨尔").affinity_name == "暗", "[场景一] 伊萨尔=暗属性")
	assert(not pair.lines_for_level(1).is_empty(), "[场景一] C 级支援对话非空")
	assert(SupportStore.find_pair("忒", "山贼") == null, "[场景一] 未登记的对返回 null")
	assert(SupportStore.get_level("忒", "伊萨尔") == 0, "[场景一] 初始无支援")
	print("场景一 通过：支援表查询")

	# ===== 场景二：门槛与升级 =====
	assert(not SupportStore.can_level_up("忒", "伊萨尔"), "[场景二] 0 点不可升 C")
	SupportStore.add_points("忒", "伊萨尔", 1)
	assert(SupportStore.get_points("忒", "伊萨尔") == 1, "[场景二] add_points 生效")
	assert(SupportStore.can_level_up("忒", "伊萨尔"), "[场景二] 1 点达 C 门槛（=1）")
	assert(SupportStore.level_up("忒", "伊萨尔"), "[场景二] 升级到 C 成功")
	assert(SupportStore.get_level("忒", "伊萨尔") == 1, "[场景二] 等级 = C")
	assert(not SupportStore.can_level_up("忒", "伊萨尔"), "[场景二] 1 点 < B 门槛（=2）不可再升")
	assert(not SupportStore.level_up("忒", "伊萨尔"), "[场景二] 未达门槛升级返回 false")
	print("场景二 通过：门槛与升级")

	# ===== 场景三：加成结算 =====
	##炎 {命中5 回避0 必杀5} + 暗 {命中0 回避10 必杀0}，B 级倍率 2.0
	SupportStore.add_points("忒", "伊萨尔", 1)
	assert(SupportStore.get_points("忒", "伊萨尔") == 2, "[场景三] 支援值累计到 2")
	assert(SupportStore.level_up("忒", "伊萨尔"), "[场景三] 升级到 B")
	var te := _make_unit("忒", Vector2i.ZERO)
	var isar := _make_unit("伊萨尔", Vector2i(2, 0))
	var bonus := SupportStore.get_support_bonus(te, [te, isar])
	assert(bonus["hit"] == 10, "[场景三] 命中加成 =（5+0）×2 = 10")
	assert(bonus["avoid"] == 20, "[场景三] 回避加成 =（0+10）×2 = 20")
	assert(bonus["crit"] == 10, "[场景三] 必杀加成 =（5+0）×2 = 10")
	##超过 3 格不加成
	isar.cell = Vector2i(4, 0)
	var far := SupportStore.get_support_bonus(te, [te, isar])
	assert(far["hit"] == 0 and far["avoid"] == 0 and far["crit"] == 0, "[场景三] 超过 3 格无加成")
	##异队不加成（支援对象被策反等异常情况兜底）
	isar.cell = Vector2i(1, 0)
	isar.team = 1
	var hostile := SupportStore.get_support_bonus(te, [te, isar])
	assert(hostile["hit"] == 0 and hostile["avoid"] == 0 and hostile["crit"] == 0, "[场景三] 异队无加成")
	##未登记支援关系的单位
	isar.team = 0
	var stranger := _make_unit("路人", Vector2i(1, 0))
	var none := SupportStore.get_support_bonus(stranger, [stranger, te, isar])
	assert(none["hit"] == 0 and none["avoid"] == 0 and none["crit"] == 0, "[场景三] 无支援关系无加成")
	##支援对象未登场（units 里没有）不加成
	var solo := SupportStore.get_support_bonus(te, [te])
	assert(solo["hit"] == 0 and solo["avoid"] == 0 and solo["crit"] == 0, "[场景三] 对象未登场无加成")
	print("场景三 通过：加成结算")

	# ===== 场景四：章节积累 =====
	SupportStore.points.clear()
	SupportStore.levels.clear()
	SupportStore.on_chapter_failed()
	##只有一方登场：不积累
	SupportStore.mark_deployed("忒")
	SupportStore.on_chapter_cleared()
	assert(SupportStore.get_points("忒", "伊萨尔") == 0, "[场景四] 单方登场不积累")
	##双方登场 + 胜利：+1 点
	SupportStore.mark_deployed("忒")
	SupportStore.mark_deployed("伊萨尔")
	SupportStore.on_chapter_cleared()
	assert(SupportStore.get_points("忒", "伊萨尔") == 1, "[场景四] 双方登场 +1 点")
	##封顶 A 级门槛（threshold_a=3）
	SupportStore.mark_deployed("忒")
	SupportStore.mark_deployed("伊萨尔")
	SupportStore.on_chapter_cleared()
	SupportStore.mark_deployed("忒")
	SupportStore.mark_deployed("伊萨尔")
	SupportStore.on_chapter_cleared()
	assert(SupportStore.get_points("忒", "伊萨尔") == 3, "[场景四] 支援值封顶 A 门槛")
	SupportStore.mark_deployed("忒")
	SupportStore.mark_deployed("伊萨尔")
	SupportStore.on_chapter_cleared()
	assert(SupportStore.get_points("忒", "伊萨尔") == 3, "[场景四] 封顶后不再增长")
	print("场景四 通过：章节积累")

	print("=== 支援系统测试全部通过 ===")
	quit()


##纯逻辑单位（headless 惯例：Unit.new() 手填字段，不挂场景树）
func _make_unit(name: String, cell: Vector2i) -> Unit:
	var u := Unit.new()
	u.unit_name = name
	u.cell = cell
	u.team = 0
	return u
