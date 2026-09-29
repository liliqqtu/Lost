extends SceneTree

##升级系统验证：经验公式 / 武器经验与等级 / 装备限制 / 升级掷骰 / 等级上限
##覆盖：
##  1. FE8 经验公式：同级伤害=(31)/职业强度、未命中=1、击杀加成（负值取0）、封顶 100
##  2. 武器经验阈值（E=1/D=31/C=71/B=121/A=181/S=251）与等级文字
##  3. Unit 武器经验积累：可用类型从 E 起步、封顶职业上限、不可用类型不积累
##  4. 装备限制：类型不可用/等级不足不能装备，无职业数据不限制（敌人兜底）
##  5. 升级掷骰：成长率 100 必加、0 不加、到职业上限不加；level_up 应用与经验扣除
##  6. 满级（20）不再获得经验
##运行：godot --headless --path . -s res://tests/test_level_system.gd

func _initialize() -> void:
	_run()


func _run() -> void:
	# ===== 场景一：FE8 经验公式 =====
	var player := _make_unit("测试者", 5)
	var enemy := _make_unit("敌人", 5)
	##同级同强度（3）：伤害经验 = (31+5-5)/3 = 10；未命中 = 1
	assert(BattleCalculator.calculate_exp_gain(player, enemy, true, false) == 10, "[场景一] 同级伤害经验 = 10")
	assert(BattleCalculator.calculate_exp_gain(player, enemy, false, false) == 1, "[场景一] 未命中经验 = 1")
	##击杀：10 + max(0, 5*3-5*3+20) = 30
	assert(BattleCalculator.calculate_exp_gain(player, enemy, true, true) == 30, "[场景一] 同级击杀经验 = 30")
	##低级打高级：伤害 = (31+15-5)/3 = 13；击杀 = 13 + max(0, 45-15+20) = 63
	enemy.lv = 15
	assert(BattleCalculator.calculate_exp_gain(player, enemy, true, false) == 13, "[场景一] 低打高伤害经验 = 13")
	assert(BattleCalculator.calculate_exp_gain(player, enemy, true, true) == 63, "[场景一] 低打高击杀经验 = 63")
	##高级打低级：伤害下取整，击杀加成按公式
	player.lv = 19
	assert(BattleCalculator.calculate_exp_gain(player, enemy, true, false) == 9, "[场景一] 高打低伤害经验 = 9")
	assert(BattleCalculator.calculate_exp_gain(player, enemy, true, true) == 17, "[场景一] 击杀加成 = max(0, 45-57+20) = 8")
	##击杀加成为负取 0：击杀经验 = 伤害经验
	enemy.lv = 1
	assert(BattleCalculator.calculate_exp_gain(player, enemy, true, false) == 4, "[场景一] 伤害经验下取整 = 4")
	assert(BattleCalculator.calculate_exp_gain(player, enemy, true, true) == 4, "[场景一] 击杀加成为负取 0")
	##封顶 100：弱职业强度 1 打强职业强度 5 的高等级敌人
	player.lv = 1
	enemy.lv = 20
	var weak_cd := ClassData.new()
	weak_cd.class_power = 1
	var strong_cd := ClassData.new()
	strong_cd.class_power = 5
	player.class_data = weak_cd
	enemy.class_data = strong_cd
	var capped := BattleCalculator.calculate_exp_gain(player, enemy, true, true)
	assert(capped == 100, "[场景一] 击杀经验封顶 100，实际 %d" % capped)
	print("场景一 通过：FE8 经验公式")

	# ===== 场景二：武器经验阈值与等级文字 =====
	assert(Weapon.WEXP_THRESHOLDS == [1, 31, 71, 121, 181, 251], "[场景二] FE8 武器经验阈值")
	assert(Weapon.wexp_to_rank(0) == Weapon.WeaponRank.UNUSABLE, "[场景二] 0 经验未入门")
	assert(Weapon.wexp_to_rank(1) == Weapon.WeaponRank.E, "[场景二] 1 = E")
	assert(Weapon.wexp_to_rank(30) == Weapon.WeaponRank.E, "[场景二] 30 = E")
	assert(Weapon.wexp_to_rank(31) == Weapon.WeaponRank.D, "[场景二] 31 = D")
	assert(Weapon.wexp_to_rank(250) == Weapon.WeaponRank.A, "[场景二] 250 = A")
	assert(Weapon.wexp_to_rank(251) == Weapon.WeaponRank.S, "[场景二] 251 = S")
	assert(Weapon.wexp_to_rank(9999) == Weapon.WeaponRank.S, "[场景二] 超 S 封顶 S")
	assert(Weapon.rank_to_text(Weapon.WeaponRank.E) == "E", "[场景二] 等级文字 E")
	assert(Weapon.rank_to_text(Weapon.WeaponRank.S) == "S", "[场景二] 等级文字 S")
	assert(Weapon.rank_to_text(Weapon.WeaponRank.UNUSABLE) == "——", "[场景二] 等级文字 ——")
	print("场景二 通过：武器经验阈值与等级文字")

	# ===== 场景三：Unit 武器经验积累 =====
	var archer := _make_unit("弓手", 5)
	var cd := ClassData.new()
	cd.job_name = "弓骑"
	cd.rank_bow = Weapon.WeaponRank.C
	cd.rank_sword = Weapon.WeaponRank.E
	archer.class_data = cd
	##可用类型从 E（经验 1）起步，上限取职业等级
	assert(archer.get_weapon_xp(Weapon.WeaponType.BOW) == 1, "[场景三] 弓起始经验 = E 阈值 1")
	assert(archer.get_weapon_rank(Weapon.WeaponType.BOW) == Weapon.WeaponRank.E, "[场景三] 弓初始等级 = E")
	##积累：命中铁弓一次 +1
	var bow := Weapon.new()
	bow.weapon_type = Weapon.WeaponType.BOW
	bow.weapon_exp = 1
	archer.gain_weapon_exp(bow)
	assert(archer.get_weapon_xp(Weapon.WeaponType.BOW) == 2, "[场景三] 命中一次 +1")
	##累计到 31 升 D
	for i in 29:
		archer.gain_weapon_exp(bow)
	assert(archer.get_weapon_xp(Weapon.WeaponType.BOW) == 31, "[场景三] 累计 31")
	assert(archer.get_weapon_rank(Weapon.WeaponType.BOW) == Weapon.WeaponRank.D, "[场景三] 升到 D")
	##封顶职业上限 C（71）
	for i in 100:
		archer.gain_weapon_exp(bow)
	assert(archer.get_weapon_xp(Weapon.WeaponType.BOW) == 71, "[场景三] 经验封顶 C 阈值 71")
	assert(archer.get_weapon_rank(Weapon.WeaponType.BOW) == Weapon.WeaponRank.C, "[场景三] 等级 = 职业上限 C")
	##职业上限 E 的类型：封顶 1 不再增长
	var sword := Weapon.new()
	sword.weapon_type = Weapon.WeaponType.SWORD
	sword.weapon_exp = 5
	archer.gain_weapon_exp(sword)
	assert(archer.get_weapon_xp(Weapon.WeaponType.SWORD) == 1, "[场景三] 剑封顶职业上限 E（1）")
	##不可用类型（杖）不积累
	var staff := Weapon.new()
	staff.weapon_type = Weapon.WeaponType.STAFF
	archer.gain_weapon_exp(staff)
	assert(archer.get_weapon_xp(Weapon.WeaponType.STAFF) == 0, "[场景三] 不可用类型不积累")
	assert(archer.get_weapon_rank(Weapon.WeaponType.STAFF) == Weapon.WeaponRank.UNUSABLE, "[场景三] 不可用等级 = -1")
	print("场景三 通过：武器经验积累")

	# ===== 场景四：装备限制 =====
	var equiper := _make_unit("装备者", 5)
	var cd2 := ClassData.new()
	cd2.job_name = "游牧民"
	cd2.rank_bow = Weapon.WeaponRank.C
	equiper.class_data = cd2
	##可用类型 + 等级足够：可装备
	var iron_bow := Weapon.new()
	iron_bow.weapon_type = Weapon.WeaponType.BOW
	iron_bow.required_rank = Weapon.WeaponRank.E
	assert(equiper.can_equip(iron_bow), "[场景四] 弓职业可装 E 级弓")
	##类型不可用：不能装备
	var lance := Weapon.new()
	lance.weapon_type = Weapon.WeaponType.LANCE
	assert(not equiper.can_equip(lance), "[场景四] 职业不可用枪不能装")
	##等级不足：E 级单位装 B 级弓
	var silver_bow := Weapon.new()
	silver_bow.weapon_type = Weapon.WeaponType.BOW
	silver_bow.required_rank = Weapon.WeaponRank.B
	assert(not equiper.can_equip(silver_bow), "[场景四] E 级不能装 B 级弓")
	##equip_item 走限制
	equiper.inventory.append(silver_bow)
	assert(not equiper.equip_item(silver_bow), "[场景四] equip_item 拒绝超等级武器")
	equiper.inventory.append(iron_bow)
	assert(equiper.equip_item(iron_bow), "[场景四] equip_item 接受合格武器")
	assert(equiper.current_weapon == iron_bow, "[场景四] 装备生效")
	##无职业数据：不限制（敌人兜底）
	var brute := _make_unit("无职业敌人", 5)
	assert(brute.can_equip(silver_bow), "[场景四] 无职业数据不限制装备")
	print("场景四 通过：装备限制")

	# ===== 场景五：升级掷骰与升级应用 =====
	var hero := _make_unit("主角", 5)
	var cd3 := ClassData.new()
	cd3.job_name = "测试职业"
	cd3.growths_hp = 100
	cd3.growths_str = 100
	cd3.growths_spd = 0
	cd3.cap_str = hero.str  ##力量已到上限：不再加
	hero.class_data = cd3
	var gains := BattleCalculator.roll_level_up(hero)
	assert(gains["hp"] == 1, "[场景五] 成长 100 必加 HP")
	assert(gains["str"] == 0, "[场景五] 到上限的力量不加")
	assert(gains["spd"] == 0, "[场景五] 成长 0 不加")
	var old_max_hp := hero.max_hp
	var old_hp := hero.hp
	hero.exp = 100
	hero.level_up(gains)
	assert(hero.lv == 6, "[场景五] 等级 +1")
	assert(hero.exp == 0, "[场景五] 经验 -100")
	assert(hero.max_hp == old_max_hp + 1, "[场景五] HP 加点应用到上限")
	assert(hero.hp == mini(old_hp + 1, hero.max_hp), "[场景五] 当前 HP 随上限提升")
	##无职业数据：全 0 加点（空升级，GBA 无保底）
	var plain := _make_unit("平民", 5)
	var none := BattleCalculator.roll_level_up(plain)
	var total := 0
	for key in none:
		total += none[key]
	assert(total == 0, "[场景五] 无职业数据不加点")
	print("场景五 通过：升级掷骰与应用")

	# ===== 场景六：满级不再获得经验 =====
	var veteran := _make_unit("老兵", 20)
	veteran.gain_exp(50)
	assert(veteran.exp == 0, "[场景六] 满级不获得经验")
	veteran.lv = 19
	veteran.gain_exp(50)
	assert(veteran.exp == 50, "[场景六] 未满级正常获得")
	print("场景六 通过：等级上限")

	print("=== 升级系统测试全部通过 ===")
	quit()


##纯逻辑单位（headless 惯例：Unit.new() 手填字段，不挂场景树）
func _make_unit(name: String, level: int) -> Unit:
	var u := Unit.new()
	u.unit_name = name
	u.lv = level
	u.team = 0
	return u
