extends SceneTree
## 统一技能与武器技能体系测试：
## 1. 勇者之弓（连续攻击：普通2击，追击4击）
## 2. 断弦（S级弓：+10技 +10速，附加特技【笃行】）
## 3. 笃行（攻击后再次行动，每回合限1次）
## 4. 公在（光环：2格内友军双防+2）

func _initialize() -> void:
	_run()

func _run() -> void:
	print("=== 测试1：断弦属性加成 (+10技 +10速) ===")
	var unit := Unit.new()
	unit.unit_name = "忒"
	unit.skl = 12
	unit.spd = 12
	unit.rank_bow = Weapon.WeaponRank.S
	var s_bow = load("res://data/items/weapon_snapped_string_bow.tres").duplicate() as Weapon
	unit.add_item(s_bow)
	unit.equip_item(s_bow)

	var eff_skl := unit.get_effective_skl()
	var eff_spd := unit.get_effective_spd()
	print("装备断弦后 - 基础技:%d 有效技:%d, 基础速:%d 有效速:%d" % [unit.skl, eff_skl, unit.spd, eff_spd])
	assert(eff_skl == 22, "断弦应提供+10技术加成")
	assert(eff_spd == 22, "断弦应提供+10速度加成")

	print("=== 测试2：断弦附带特技【笃行】===")
	var active_skills := unit.get_all_active_skills()
	var skill_names := []
	for s in active_skills:
		skill_names.append(s.display_name)
	print("单位当前激活的所有技能: ", skill_names)
	assert(unit.has_act_again_skill(), "装备断弦应获得【笃行】特技")

	print("=== 测试3：光环技能【公在】(2格内友军双防+2) ===")
	var ally := Unit.new()
	ally.unit_name = "友军"
	ally.team = 0
	ally.cell = Vector2i(0, 0)
	ally.def_h = 5
	ally.res = 2

	var aura_unit := Unit.new()
	aura_unit.unit_name = "持公在者"
	aura_unit.team = 0
	aura_unit.cell = Vector2i(1, 1) # 距离 (1-0)+(1-0)=2格
	var mitsein = load("res://data/skills/mitsein.tres")
	aura_unit.personal_skills.append(mitsein)

	var all_units := [ally, aura_unit]
	var in_range_def := ally.get_effective_def(all_units)
	var in_range_res := ally.get_effective_res(all_units)
	print("2格内友军 - 守备:%d(原5), 魔防:%d(原2)" % [in_range_def, in_range_res])
	assert(in_range_def == 7, "2格内友军守备应+2")
	assert(in_range_res == 4, "2格内友军魔防应+2")

	# 移到3格外
	aura_unit.cell = Vector2i(2, 2) # 距离 (2-0)+(2-0)=4格
	var out_range_def := ally.get_effective_def(all_units)
	print("4格外友军 - 守备:%d(原5)" % out_range_def)
	assert(out_range_def == 5, "超出光环范围不应获得加成")

	print("=== 测试4：勇者之弓（连续攻击与x2/x4判定） ===")
	var brave_bow = load("res://data/items/weapon_brave_bow.tres").duplicate() as Weapon
	assert(brave_bow.is_brave_weapon(), "勇者之弓应具备勇者武器特性")

	var brave_user := Unit.new()
	brave_user.unit_name = "勇者使用者"
	brave_user.spd = 15
	brave_user.con = 10
	brave_user.current_weapon = brave_bow

	var enemy := Unit.new()
	enemy.unit_name = "山贼"
	enemy.team = 1
	enemy.spd = 5 # 攻速差 15 - 5 = 10 >= 4，可追击
	enemy.con = 10

	var seq_quad := BattleCalculator.generate_battle_sequence(brave_user, enemy, null)
	var user_strikes := 0
	for st in seq_quad:
		if st["attacker"] == brave_user:
			user_strikes += 1
	print("追击时勇者打击次数: %d（期望4次）" % user_strikes)
	assert(user_strikes == 4, "勇者追击应打4次（2轮各2击）")

	enemy.spd = 14 # 攻速差 1 < 4，不可追击
	var seq_double := BattleCalculator.generate_battle_sequence(brave_user, enemy, null)
	user_strikes = 0
	for st in seq_double:
		if st["attacker"] == brave_user:
			user_strikes += 1
	print("不追击时勇者打击次数: %d（期望2次）" % user_strikes)
	assert(user_strikes == 2, "勇者不追击应打2次")

	print(">>> 所有统一技能与武器测试通过！<<<")
	quit()
