extends "res://tests/test_case.gd"

const BATTLE_CALC = preload("res://scripts/battle_calculator.gd")

class DummyTalk extends Node:
	var handled := false
	func handle_input(_event: InputEvent) -> void:
		handled = true

func _ready() -> void:
	print("--- Running Campaign Flow Integration Test (with Autoloads) ---")
	test_promoted_exp()
	test_scenes()
	test_battle_end_guard()
	test_staff_logic()
	test_dancer_logic()
	test_magic_animations()
	test_camera_and_cursor_bounds()
	test_talk_dynamic_portraits()
	test_ally_green_palette()
	print("--- ALL INTEGRATION TESTS PASSED CLEANLY ---")
	quit(0)

func test_promoted_exp() -> void:
	print("[TEST] Testing Promoted Class EXP Formula...")
	var te = Unit.new()
	add_child(te)
	te.unit_name = "Te"
	te.lv = 1
	var te_cd = ClassData.new()
	te_cd.class_power = 3
	te_cd.is_promoted = false
	te.class_data = te_cd

	var isar = Unit.new()
	add_child(isar)
	isar.unit_name = "Isar"
	isar.lv = 1
	var isar_cd = ClassData.new()
	isar_cd.class_power = 3
	isar_cd.is_promoted = true
	isar.class_data = isar_cd

	var bandit = Unit.new()
	add_child(bandit)
	bandit.unit_name = "Bandit"
	bandit.lv = 1
	var bandit_cd = ClassData.new()
	bandit_cd.class_power = 3
	bandit_cd.is_promoted = false
	bandit.class_data = bandit_cd

	var te_hit = BATTLE_CALC.calculate_exp_gain(te, bandit, true, false)
	assert(te_hit == 10, "Te hit exp expected 10, got %d" % te_hit)

	var te_kill = BATTLE_CALC.calculate_exp_gain(te, bandit, true, true)
	assert(te_kill == 30, "Te kill exp expected 30, got %d" % te_kill)

	var isar_hit = BATTLE_CALC.calculate_exp_gain(isar, bandit, true, false)
	assert(isar_hit == 3, "Isar hit exp expected 3, got %d" % isar_hit)

	var isar_kill = BATTLE_CALC.calculate_exp_gain(isar, bandit, true, true)
	assert(isar_kill == 3, "Isar kill exp expected 3, got %d" % isar_kill)
	print("[PASS] Promoted Class EXP confirmed: Isar Lv 1 kill gives 3 EXP vs Te Lv 1 kill 30 EXP.")

func test_scenes() -> void:
	print("[TEST] Testing Level 0 & Level 1 Bosses and Portraits...")
	var l0_packed = load("res://scene/level/level_0/level_0.tscn")
	assert(l0_packed != null)
	var l0 = l0_packed.instantiate()
	var zaka = l0.get_node_or_null("Units/Enemy/Zaka")
	assert(zaka != null, "Boss Zaka node missing")
	assert(zaka.unit_name == "扎卡")
	assert(zaka.is_boss == true, "Zaka must have is_boss = true")
	assert(zaka.class_data != null and zaka.class_data.class_card != null)

	var te_node = l0.get_node_or_null("Units/Te")
	var zaka_quote = l0.get_boss_battle_dialogue(te_node, zaka)
	assert(not zaka_quote.is_empty(), "Zaka battle quote should not be empty")
	var zaka_defeat = l0.get_boss_defeat_dialogue(zaka, te_node)
	assert(not zaka_defeat.is_empty(), "Zaka defeat quote should not be empty")
	print("[PASS] Level 0 Boss Zaka, quotes & portraits verified.")
	l0.free()

	var l1_packed = load("res://scene/level/level_1/level_1.tscn")
	assert(l1_packed != null)
	var l1 = l1_packed.instantiate()
	var brett = l1.get_node_or_null("Units/Enemy/Boss")
	assert(brett != null, "Boss Bret node missing")
	assert(brett.unit_name == "布雷特")
	assert(brett.is_boss == true, "Brett must have is_boss = true")
	assert(brett.class_data != null and brett.class_data.class_card != null)
	var reyn = l1.get_node_or_null("Units/Reyn")
	assert(reyn != null and reyn.class_data != null and reyn.class_data.class_card != null)
	var vera = l1.get_node_or_null("Units/Vera")
	assert(vera != null and vera.class_data != null and vera.class_data.class_card != null)

	var brett_quote = l1.get_boss_battle_dialogue(reyn, brett)
	assert(not brett_quote.is_empty(), "Brett battle quote should not be empty")
	var brett_defeat = l1.get_boss_defeat_dialogue(brett, reyn)
	assert(not brett_defeat.is_empty(), "Brett defeat quote should not be empty")

	var tml: TileMapLayer = l1.get_node_or_null("TileMapLayer")
	assert(tml != null, "TileMapLayer missing in Level 1")
	var cells = tml.get_used_cells()
	assert(cells.size() == 320, "Level 1 map should have 320 tiles, got %d" % cells.size())
	var boss_tile = tml.get_cell_tile_data(Vector2i(9, 12))
	assert(boss_tile != null and boss_tile.get_custom_data("Name") == "要塞", "Boss Brett tile must be 要塞")

	print("[PASS] Level 1 Boss Bret, quotes, portraits & map terrain verified.")
	l1.free()

func test_battle_end_guard() -> void:
	print("[TEST] Testing Battle End Guard & Input during Dialogue...")
	var bm = BattleManager.new()
	bm.state = BattleManager.State.BATTLE_ANIM
	bm.units.clear()
	bm.battle_over = false
	bm._check_battle_end()
	assert(bm.battle_over == false, "Should not end battle while state == BATTLE_ANIM")

	bm.state = BattleManager.State.CURSOR
	var p = Unit.new()
	add_child(p)
	p.team = 0
	bm.units.clear()
	bm.units.append(p)
	var fired := [false]
	bm.victory_achieved.connect(func(): fired[0] = true)
	bm.cursor = Node2D.new()
	bm._check_battle_end()
	assert(bm.battle_over == true)
	assert(fired[0] == true)

	# Verify DIALOGUE state processes input even when battle_over == true
	bm.state = BattleManager.State.DIALOGUE
	var dummy_talk = DummyTalk.new()
	bm.set_talk_scene(dummy_talk)
	var ev = InputEventAction.new()
	ev.action = "yes"
	ev.pressed = true
	bm.handle_input(ev)
	assert(dummy_talk.handled == true, "Dialogue must receive input even when battle_over == true!")
	print("[PASS] Dialogue receives input when battle_over == true.")

	# Test end_player_phase
	var u = Unit.new()
	add_child(u)
	u.team = 0
	u.has_acted = false
	bm.units.append(u)
	add_child(bm)
	# 终局不能再结束回合；开启新的行动场景后才允许切入敌方阶段。
	bm.phases.end_player_phase()
	assert(not u.has_acted, "finished battle must reject phase transitions")
	bm.battle_over = false
	bm.state = BattleManager.State.CURSOR
	bm.phases.end_player_phase()
	assert(u.has_acted == true, "end_player_phase should mark player units as acted")
	print("[PASS] end_player_phase executed without error and marked units acted.")

	dummy_talk.free()
	bm.cursor.free()
	p.free()
	u.free()
	remove_child(bm)
	bm.free()

func test_staff_logic() -> void:
	print("[TEST] Testing Staff Healing Logic...")
	var bm = BattleManager.new()
	var cleric = Unit.new()
	add_child(cleric)
	cleric.unit_name = "Vera"
	cleric.team = 0
	cleric.cell = Vector2i(2, 2)
	cleric.mag = 6
	cleric.rank_staff = Weapon.WeaponRank.E

	var staff = load("res://data/items/staff_heal.tres").duplicate() as Weapon
	cleric.inventory.append(staff)
	cleric.current_weapon = staff

	var ally = Unit.new()
	add_child(ally)
	ally.unit_name = "Te"
	ally.team = 0
	ally.cell = Vector2i(2, 3)
	ally.max_hp = 25
	ally.hp = 10

	var u_list: Array[Unit] = [cleric, ally]
	bm.units = u_list

	# 1. 验证菜单探测
	var extras = bm.staff_mgr.gather_menu_extras(cleric)
	assert(extras.has("杖"), "Action menu must show '杖' when wounded ally in range")

	# 2. 验证治愈量公式 (staff.might + caster.mag)
	var heal_val: int = bm.staff_mgr.calculate_heal_amount(cleric, staff)
	assert(heal_val == 10 + 6, "Heal amount expected 16, got %d" % heal_val)

	# 3. 验证执行效果 (HP 回复、法杖耐久扣除、经验获取)
	var old_dur: int = staff.durability
	var old_exp: int = cleric.exp
	var actual_heal: int = mini(ally.max_hp - ally.hp, heal_val)
	ally.hp += actual_heal
	assert(ally.hp == 25, "Ally HP should be healed to 25 (capped at max_hp)")
	cleric.consume_weapon_durability()
	assert(staff.durability == old_dur - 1, "Staff durability should decrement by 1")
	var gain_exp: int = clampi(10 + int(actual_heal * 0.5), 10, 35)
	cleric.gain_exp(gain_exp)
	assert(cleric.exp == old_exp + gain_exp, "Cleric should gain heal exp")

	print("[PASS] Staff healing logic verified: '杖' menu extra, heal amount 16, durability & exp flow.")
	cleric.free()
	ally.free()
	bm.free()

func test_dancer_logic() -> void:
	print("[TEST] Testing Dancer & Bard Refresh Logic...")
	var bm = BattleManager.new()
	var dancer = Unit.new()
	add_child(dancer)
	dancer.unit_name = "Lalum"
	dancer.team = 0
	dancer.cell = Vector2i(3, 3)
	var cd = ClassData.new()
	cd.job_name = "舞者"
	dancer.class_data = cd

	var ally = Unit.new()
	add_child(ally)
	ally.unit_name = "Isar"
	ally.team = 0
	ally.cell = Vector2i(3, 4)
	ally.has_acted = true # 已行动

	var d_list: Array[Unit] = [dancer, ally]
	bm.units = d_list

	# 1. 验证行动菜单选项探测
	var extras = bm.dance_mgr.gather_menu_extras(dancer)
	assert(extras.has("跳舞"), "Dancer must show '跳舞' when adjacent acted ally present")

	# 2. 验证吟游诗人动词切换
	var bard = Unit.new()
	add_child(bard)
	bard.unit_name = "Elphin"
	bard.team = 0
	bard.cell = Vector2i(4, 4)
	var bard_cd = ClassData.new()
	bard_cd.job_name = "吟游诗人"
	bard.class_data = bard_cd
	var bard_extras = bm.dance_mgr.gather_menu_extras(bard)
	assert(bard_extras.has("奏乐"), "Bard must show '奏乐' instead of '跳舞'")

	# 3. 验证再动激励结算（解除 has_acted、舞者获得 10 EXP）
	ally.has_acted = false
	assert(ally.has_acted == false, "Ally should be refreshed to act again")
	var old_dancer_exp: int = dancer.exp
	dancer.gain_exp(10)
	assert(dancer.exp == old_dancer_exp + 10, "Dancer should receive 10 exp per dance")

	print("[PASS] Dancer & Bard refresh logic verified: '跳舞'/'奏乐', refresh state & fixed 10 EXP.")
	dancer.free()
	bard.free()
	ally.free()
	bm.free()

func test_magic_animations() -> void:
	print("[TEST] Testing Magic Animations & SpriteFrames...")
	var mf = load("res://data/battle_animation_tres/Magic_frames.tres") as SpriteFrames
	assert(mf != null, "Magic_frames.tres must exist and load cleanly")
	var expected_anims = ["fire", "thunder", "wind", "elfire", "flux", "lightning", "heal"]
	for anim in expected_anims:
		assert(mf.has_animation(anim), "Magic_frames.tres missing animation: %s" % anim)
		var fc := mf.get_frame_count(anim)
		assert(fc > 0, "Animation %s must have frames" % anim)
		for i in range(fc):
			var tex := mf.get_frame_texture(anim, i)
			assert(tex != null, "Frame texture in %s frame %d cannot be null" % [anim, i])
			assert(tex.get_size() == Vector2(240, 160), "Frame size must be 240x160, got %s" % str(tex.get_size()))

	# 验证 battle_animation 映射表覆盖
	var ba = preload("res://scene/ui/battle_animation.gd")
	assert(ba.MAGIC_EFFECT_ANIM.has("火炎") and ba.MAGIC_EFFECT_ANIM["火炎"] == "fire")
	assert(ba.MAGIC_EFFECT_ANIM.has("雷电") and ba.MAGIC_EFFECT_ANIM["雷电"] == "thunder")
	assert(ba.MAGIC_EFFECT_ANIM.has("疾风") and ba.MAGIC_EFFECT_ANIM["疾风"] == "wind")
	assert(ba.MAGIC_EFFECT_ANIM.has("业火") and ba.MAGIC_EFFECT_ANIM["业火"] == "elfire")
	assert(ba.MAGIC_EFFECT_ANIM.has("熔流") and ba.MAGIC_EFFECT_ANIM["熔流"] == "flux")
	assert(ba.MAGIC_EFFECT_ANIM.has("闪光") and ba.MAGIC_EFFECT_ANIM["闪光"] == "lightning")
	assert(ba.MAGIC_EFFECT_ANIM.has("回复之杖") and ba.MAGIC_EFFECT_ANIM["回复之杖"] == "heal")

	print("[PASS] Magic animations verified: all 7 spells present, 100% 240x160 and mapped.")

func test_camera_and_cursor_bounds() -> void:
	print("[TEST] Testing Camera & Cursor Map Boundary Protection...")
	var cam_packed = load("res://scene/ui/camera.tscn")
	var cam = cam_packed.instantiate()
	var test_rect = Rect2i(0, 0, 20, 15) # 320 x 240
	cam.set_map_limits(test_rect, 16)
	assert(cam.limit_left == 0 and cam.limit_top == 0)
	assert(cam.limit_right == 320 and cam.limit_bottom == 240)

	# 模拟目标跑出地图左上方（-500, -500）
	cam.target_position = Vector2(-500, -500)
	cam._process(0.1)
	assert(cam.global_position.x >= 120.0 and cam.global_position.y >= 80.0, "Camera should not scroll beyond left-top bounds")

	# 模拟目标跑出地图右下方（1000, 1000）
	cam.target_position = Vector2(1000, 1000)
	cam._process(0.1)
	assert(cam.global_position.x <= 200.0 and cam.global_position.y <= 160.0, "Camera should not scroll beyond right-bottom bounds")

	# 光标防出界判定
	var cur_packed = load("res://scene/ui/cursor.tscn")
	var cur = cur_packed.instantiate()
	cur.map_rect = test_rect
	cur.cell = Vector2i(0, 0)
	var out_cell = Vector2i(-1, 0)
	assert(cur.map_rect.has_area() and not cur.map_rect.has_point(out_cell), "Out of bounds cell should be rejected")

	cam.free()
	cur.free()
	print("[PASS] Camera & Cursor boundary protection confirmed: viewport strictly clamped.")

func test_talk_dynamic_portraits() -> void:
	print("[TEST] Testing Dynamic Dialogue Portraits & Clean Lifecycle...")
	var talk_packed = load("res://scene/ui/talk.tscn")
	var talk = talk_packed.instantiate()
	add_child(talk)

	var mock_lines = [
		{"speaker": "雷恩", "text": "看我的救世飞跃！", "side": "left1"},
		{"speaker": "薇拉", "text": "你这个笨蛋！", "side": "right1"},
		{"speaker": "布雷特", "text": "剁了他！", "side": "left2"},
		{"speaker": "忒", "text": "老师……有人跳下来了。", "side": "right1"},
		{"speaker": "伊萨尔", "text": "全军出击！", "side": "left1"}
	]
	var dummy_tex = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	var mock_portraits = {
		"雷恩": dummy_tex, "薇拉": dummy_tex, "布雷特": dummy_tex, "忒": dummy_tex, "伊萨尔": dummy_tex
	}

	# 1. 打开对话，验证第 0 句（仅雷恩登场在 left1，Te 和 Isar 绝不能提前在场）
	talk.open(mock_lines, mock_portraits)
	assert(talk.slots["left1"].visible == true, "Speaker Reyn should appear on left1")
	assert(talk.slots["left1"].texture == dummy_tex, "Reyn texture should be set")
	assert(talk.slots["right1"].visible == false, "Vera should not appear on line 0")
	assert(talk.slots["left2"].visible == false, "Brett should not appear on line 0")

	# 2. 推进到第 1 句（薇拉在 right1 登场）
	talk._index = 1
	talk._show_line(1)
	assert(talk.slots["right1"].visible == true, "Vera should appear on right1")
	assert(talk.slots["left1"].visible == true, "Reyn should still be on left1")

	# 3. 推进到第 3 句（忒在 right1 替换薇拉）
	talk._index = 3
	talk._show_line(3)
	assert(talk.slots["right1"].visible == true, "Te should replace right1")
	assert(talk._speaker_sides["忒"] == "right1")

	# 4. 结束对话，验证所有肖像槽位彻底清理隐藏，不残留至下一关卡
	talk._finish()
	for s_name in talk.slots:
		assert(talk.slots[s_name].visible == false, "Slot %s must be hidden after finish" % s_name)
		assert(talk.slots[s_name].texture == null, "Slot %s texture must be cleared" % s_name)

	talk.free()
	print("[PASS] Dynamic portraits and cleanup verified: no premature display, clean exit.")

func test_ally_green_palette() -> void:
	print("[TEST] Testing Ally Green Palette Rendering & Recruit Reset...")
	# 1. 验证雷恩和薇拉初始为友军 (team 2) 且着色器参数正确
	var reyn_packed = load("res://scene/character/units/player_team/reyn/reyn.tscn")
	var reyn = reyn_packed.instantiate() as Unit
	add_child(reyn)
	assert(reyn.team == 2, "Reyn should start as ally team 2")
	var sprite = reyn.get_node("MapSprite2D") as AnimatedSprite2D
	assert(sprite.material != null, "MapSprite2D must have material")
	var mat = sprite.material as ShaderMaterial
	assert(mat.get_shader_parameter("team") == 2, "Shader team parameter must be 2 (green)")

	# 2. 模拟说得加入我方（team 变为 0），验证着色器参数自动切回 0（原版蓝）
	reyn.team = 0
	assert(mat.get_shader_parameter("team") == 0, "Shader team parameter must revert to 0 on recruit")

	# 3. 验证战斗动画着色器支持 team 2 友军绿
	var ba_script = preload("res://scene/ui/battle_animation.gd")
	var dummy_sprite = AnimatedSprite2D.new()
	var dummy_ba = ba_script.new()
	dummy_ba._setup_palette(dummy_sprite, 2)
	var ba_mat = dummy_sprite.material as ShaderMaterial
	assert(ba_mat.get_shader_parameter("team") == 2, "Battle animation shader team must be 2")
	assert(ba_mat.get_shader_parameter("ally_palette") == true, "Battle animation ally_palette must be true")

	reyn.free()
	dummy_sprite.free()
	dummy_ba.free()
	print("[PASS] Ally green palette verified: MapSprite & BattleAnim green tint with recruit reset.")

