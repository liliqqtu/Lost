extends SceneTree

##P0-1 验证：Unit 统一攻击范围接口（get_weapon_ranges + get_attack_range）
##覆盖：
##  1. 单武器（剑/弓）→ 攻击范围 = 该武器射程
##  2. 多武器（剑 + 弓）→ 攻击范围 = 射程并集
##  3. 不连续射程（剑 1-1 + 弓 3-3）→ 取并集
##  4. 空背包 → 无攻击范围
##  5. 损坏武器（耐久 0）不计入
##  6. 技能"仿徨"（-1 射程）对背包所有武器生效
##  7. 站位列表剔除（移动范围与攻击范围不重叠显示）
##运行：godot --headless --path . -s res://tests/test_attack_range_union.gd

func _init() -> void:
	var tile_map := _build_test_tile_map()

	# ===== 场景一：单剑（1-1）=====
	var sword_only := _make_unit("剑客", Vector2i(5, 5))
	var sword := _make_weapon("铁剑", Weapon.WeaponType.SWORD, 1, 1)
	sword_only.inventory = [sword]
	sword_only.current_weapon = sword
	var r1 := sword_only.get_weapon_ranges()
	_assert_eq(r1.size(), 1, "剑客 get_weapon_ranges 数量")
	_assert_eq(int(r1[0]["min"]), 1, "剑客 min")
	_assert_eq(int(r1[0]["max"]), 1, "剑客 max")
	var atk1 := sword_only.get_attack_range(tile_map, [Vector2i(5, 5)])
	_assert_set_eq(atk1, [Vector2i(4, 5), Vector2i(6, 5), Vector2i(5, 4), Vector2i(5, 6)],
		"剑客 attack_range（距离 1 的四方向）")
	print("场景一 通过：单剑攻击范围 = 距离 1 四方向")

	# ===== 场景二：单弓（2-2）=====
	var bow_only := _make_unit("弓兵", Vector2i(5, 5))
	var bow := _make_weapon("铁弓", Weapon.WeaponType.BOW, 2, 2)
	bow_only.inventory = [bow]
	bow_only.current_weapon = bow
	var atk2 := bow_only.get_attack_range(tile_map, [Vector2i(5, 5)])
	_assert_set_eq(atk2, _cells_at_dist(5, 5, 2),
		"弓兵 attack_range（距离 2 一圈）")
	print("场景二 通过：单弓攻击范围 = 距离 2 一圈")

	# ===== 场景三：剑 + 弓 → 并集 = 距离 1 ∪ 距离 2 =====
	var mixed := _make_unit("剑弓手", Vector2i(5, 5))
	var mix_sword := _make_weapon("铁剑", Weapon.WeaponType.SWORD, 1, 1)
	var mix_bow := _make_weapon("铁弓", Weapon.WeaponType.BOW, 2, 2)
	mixed.inventory = [mix_sword, mix_bow]
	mixed.current_weapon = mix_sword
	var ranges3 := mixed.get_weapon_ranges()
	_assert_eq(ranges3.size(), 2, "剑弓手 get_weapon_ranges 数量")
	var atk3 := mixed.get_attack_range(tile_map, [Vector2i(5, 5)])
	var expected3: Array = {}
	for c in _cells_at_dist(5, 5, 1):
		expected3[c] = true
	for c in _cells_at_dist(5, 5, 2):
		expected3[c] = true
	_assert_set_eq(atk3, expected3.keys(),
		"剑弓手 attack_range = 距离 1 ∪ 距离 2 并集")
	print("场景三 通过：剑 + 弓攻击范围 = 并集（含不连通区间）")

	# ===== 场景四：不连续射程（剑 1-1 + 弓 3-3）→ 取并集 =====
	var gap := _make_unit("间隙", Vector2i(5, 5))
	var gap_sword := _make_weapon("铁剑", Weapon.WeaponType.SWORD, 1, 1)
	var gap_bow := _make_weapon("长弓", Weapon.WeaponType.BOW, 3, 3)
	gap.inventory = [gap_sword, gap_bow]
	gap.current_weapon = gap_sword
	var atk4 := gap.get_attack_range(tile_map, [Vector2i(5, 5)])
	var expected4: Array = {}
	for c in _cells_at_dist(5, 5, 1):
		expected4[c] = true
	for c in _cells_at_dist(5, 5, 3):
		expected4[c] = true
	_assert_set_eq(atk4, expected4.keys(),
		"不连续射程并集 = 距离 1 ∪ 距离 3（距离 2 不在内）")
	print("场景四 通过：不连续射程（1-1 + 3-3）取并集，距离 2 不在内")

	# ===== 场景五：空背包 → 无攻击范围 =====
	var empty := _make_unit("空手", Vector2i(5, 5))
	_assert_eq(empty.get_weapon_ranges().size(), 0, "空背包 weapon_ranges 数量")
	_assert_eq(empty.get_attack_range(tile_map, [Vector2i(5, 5)]).size(), 0,
		"空背包 attack_range 数量")
	print("场景五 通过：空背包 → 无攻击范围")

	# ===== 场景六：损坏武器（耐久 0）不计入 =====
	var broken := _make_unit("坏刀客", Vector2i(5, 5))
	var broken_sword := _make_weapon("断剑", Weapon.WeaponType.SWORD, 1, 1)
	broken_sword.durability = 0
	var good_sword := _make_weapon("好剑", Weapon.WeaponType.SWORD, 1, 1)
	broken.inventory = [broken_sword, good_sword]
	broken.current_weapon = good_sword
	var ranges6 := broken.get_weapon_ranges()
	_assert_eq(ranges6.size(), 1, "损坏武器被剔除后 ranges 数量")
	_assert_eq(ranges6[0]["weapon"].display_name, "好剑", "剩下的是好剑")
	print("场景六 通过：损坏武器（耐久 0）不计入 weapon_ranges")

	# ===== 场景七：技能"仿徨"（-1 射程）对背包所有武器生效 =====
	var lost_unit := _make_unit("仿徨者", Vector2i(5, 5))
	var lost_sword := _make_weapon("铁剑", Weapon.WeaponType.SWORD, 1, 1)
	var lost_bow := _make_weapon("铁弓", Weapon.WeaponType.BOW, 2, 2)
	lost_unit.inventory = [lost_sword, lost_bow]
	lost_unit.current_weapon = lost_sword
	lost_unit.personal_skills = [preload("res://scene/skill/lost.tres")]
	var ranges7 := lost_unit.get_weapon_ranges()
	_assert_eq(ranges7.size(), 2, "仿徨后 ranges 数量")
	_assert_eq(int(ranges7[0]["min"]), 1, "仿徨后剑 min（1-1 兜底为 1）")
	_assert_eq(int(ranges7[0]["max"]), 1, "仿徨后剑 max")
	_assert_eq(int(ranges7[1]["min"]), 1, "仿徨后弓 min（2-1=1）")
	_assert_eq(int(ranges7[1]["max"]), 1, "仿徨后弓 max")
	var atk7 := lost_unit.get_attack_range(tile_map, [Vector2i(5, 5)])
	_assert_set_eq(atk7, _cells_at_dist(5, 5, 1),
		"仿徨后 attack_range = 仅距离 1（弓也被压到 1）")
	print("场景七 通过：仿徨技能让弓射程也被压到 1")

	# ===== 场景八：攻击范围 = 射程并集 - 站位集合（移动范围 MOVE_TILE 与攻击范围 ATTACK_TILE 不重叠）=====
	var move_cells: Array = [Vector2i(5, 5), Vector2i(6, 5), Vector2i(4, 5)]
	var bower := _make_unit("弓骑", Vector2i(5, 5))
	var bower_bow := _make_weapon("铁弓", Weapon.WeaponType.BOW, 2, 2)
	bower.inventory = [bower_bow]
	bower.current_weapon = bower_bow
	var atk8 := bower.get_attack_range(tile_map, move_cells)
	##期望：三个站位各自距离 2 的并集，再减去站位本身
	var expected8 := {}
	for stand in move_cells:
		for c in _cells_at_dist(stand.x, stand.y, 2):
			expected8[c] = true
	for stand in move_cells:
		expected8.erase(stand)
	_assert_set_eq(atk8, expected8.keys(), "射程并集 - 站位差集")
	##站位一律不出现（它们由移动范围蓝色显示）
	for cell in move_cells:
		assert(not atk8.has(cell), "站位 %s 不应出现在 attack_range（属于移动范围）" % cell)
	print("场景八 通过：攻击范围 = 射程并集 - 站位集合（蓝红不重叠）")

	print("=== test_attack_range_union 全部通过 ===")

	for u in [sword_only, bow_only, mixed, gap, empty, broken, lost_unit, bower]:
		u.free()
	quit()


##"""构造测试单位（占位 Vector2i.cell + 默认 move_table）"""
func _make_unit(p_name: String, p_cell: Vector2i) -> Unit:
	var unit := Unit.new()
	unit.unit_name = p_name
	unit.cell = p_cell
	unit.team = 0
	unit.move = 5
	return unit


##"""构造武器（display_name/weapon_type/min_range/max_range/durability）"""
func _make_weapon(p_name: String, p_type, p_min: int, p_max: int) -> Weapon:
	var w := Weapon.new()
	w.display_name = p_name
	w.weapon_type = p_type
	w.min_range = p_min
	w.max_range = p_max
	w.durability = 40
	w.max_durability = 40
	return w


##"""返回 (cx,cy) 周围恰好距离 d 的所有格子（曼哈顿距离）"""
func _cells_at_dist(cx: int, cy: int, d: int) -> Array:
	var result: Array = []
	for dx in range(-d, d + 1):
		for dy in range(-d, d + 1):
			if abs(dx) + abs(dy) != d:
				continue
			if dx == 0 and dy == 0:
				continue
			result.append(Vector2i(cx + dx, cy + dy))
	return result


##"""断言两个数组视为集合相等（顺序无关）"""
func _assert_set_eq(actual: Array, expected: Array, label: String) -> void:
	var a := {}
	for c in actual:
		a[c] = true
	var e := {}
	for c in expected:
		e[c] = true
	assert(a.size() == e.size(), "[%s] 数量不等 actual=%d expected=%d" % [label, a.size(), e.size()])
	for c in a:
		assert(e.has(c), "[%s] 实际多出 %s" % [label, c])
	for c in e:
		assert(a.has(c), "[%s] 缺少 %s" % [label, c])


##"""断言相等（int/string 通用）"""
func _assert_eq(actual, expected, label: String) -> void:
	assert(actual == expected,
		"[%s] 期望 %s 实际 %s" % [label, str(expected), str(actual)])


##"""构造 20x20 全道路测试地图（足够大，避免距离 2-3 越界）"""
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
	for x in range(20):
		for y in range(20):
			tile_map.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))
	return tile_map