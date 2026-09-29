extends SceneTree

##P0-2 验证：Unit 物品/装备实例生命周期统一接口
##不变量：`current_weapon == null` 或 `inventory.has(current_weapon)`
##覆盖：
##  1. add_item：容量满返回 false，不复制；当前 current_weapon 不被改动
##  2. remove_item：按引用移除；若该物品是 current_weapon 自动卸装
##  3. remove_item_at：按索引移除；同上同步卸装
##  4. equip_item：仅 inventory 内的 Weapon 可被装备；非背包实例/非武器返回 false
##  5. consume_weapon_durability：扣耐久；归零时移除背包并卸装；损坏后再调不重复扣
##  6. use_item 不变量：消耗品用尽后从背包移除，current_weapon（若是武器）不受影响
##  7. 模板 .tres 共享：add_item 不复制——多单位共享同一模板会污染耐久（这是已知契约）
##  8. 全场景组合：换装→攻击扣耐久→耐久归零→current_weapon 置空
##运行：godot --headless --path . -s res://tests/test_item_lifecycle.gd


func _init() -> void:
	# ===== 场景一：add_item 容量上限 =====
	var u1 := _make_unit("测试员")
	var w1 := _make_weapon("铁剑", 40)
	for i in Unit.BAG_LIMIT:
		assert(u1.add_item(w1.duplicate()), "[场景一] 第 %d 件应可加入" % i)
	var overflow := _make_weapon("溢出", 40)
	assert(not u1.add_item(overflow), "[场景一] 满背包应返回 false")
	assert(not u1.inventory.has(overflow), "[场景一] 失败时物品不入包")
	assert(u1.inventory.size() == Unit.BAG_LIMIT, "[场景一] 背包大小 = BAG_LIMIT")
	print("场景一 通过：add_item 容量上限")

	# ===== 场景二：remove_item 同步卸装 =====
	var u2 := _make_unit("测试员")
	var sword2 := _make_weapon("铁剑", 40)
	var bow2 := _make_weapon("铁弓", 40)
	u2.inventory = [sword2, bow2]
	u2.current_weapon = sword2
	assert(u2.remove_item(sword2), "[场景二] 移除背包内武器应成功")
	assert(u2.current_weapon == null, "[场景二] 移除 current_weapon 自动卸装")
	assert(not u2.inventory.has(sword2), "[场景二] sword2 已不在背包")
	##再移除已不在背包的物品
	assert(not u2.remove_item(sword2), "[场景二] 不在背包的物品返回 false")
	assert(not u2.remove_item(null), "[场景二] null 返回 false")
	print("场景二 通过：remove_item 同步 current_weapon")

	# ===== 场景三：remove_item_at 同步卸装 =====
	var u3 := _make_unit("测试员")
	var w31 := _make_weapon("铁剑", 40)
	var w32 := _make_weapon("铁弓", 40)
	var w33 := _make_weapon("铁斧", 40)
	u3.inventory = [w31, w32, w33]
	u3.current_weapon = w32
	##移除 w32（装备中）应自动卸装
	assert(u3.remove_item_at(1), "[场景三] 按索引 1 移除成功")
	assert(u3.current_weapon == null, "[场景三] 移除装备中武器 → current_weapon 置空")
	assert(u3.inventory == [w32, w33] as Array, "[场景三] 移除后顺序正确")
	##索引越界
	assert(not u3.remove_item_at(-1), "[场景三] 负索引返回 false")
	assert(not u3.remove_item_at(99), "[场景三] 越界返回 false")
	print("场景三 通过：remove_item_at 同步 current_weapon")

	# ===== 场景四：equip_item 仅 inventory 内 Weapon =====
	var u4 := _make_unit("测试员")
	var sword4 := _make_weapon("铁剑", 40)
	u4.inventory = [sword4]
	##不通过 add_item 直接赋值的当前武器（测试 setup 的"合法走捷径"）
	var outsider := _make_weapon("外来剑", 40)
	u4.current_weapon = outsider
	assert(not u4.equip_item(outsider), "[场景四] 不在背包的武器不能装备")
	assert(u4.current_weapon == outsider, "[场景四] 失败时不改 current_weapon")
	##装备背包内的武器
	assert(u4.equip_item(sword4), "[场景四] 装备背包内武器应成功")
	assert(u4.current_weapon == sword4, "[场景四] current_weapon 切换到 sword4")
	print("场景四 通过：equip_item 仅 inventory 内武器")

	# ===== 场景五：consume_weapon_durability 扣耐久与损坏 =====
	var u5 := _make_unit("测试员")
	var w5 := _make_weapon("铁剑", 3)  ##耐久 3，第 3 次扣完后损坏
	u5.inventory = [w5]
	u5.current_weapon = w5
	assert(not u5.consume_weapon_durability(), "[场景五] 第 1 次扣耐久：未损坏")
	assert(w5.durability == 2, "[场景五] 耐久 3→2")
	assert(u5.current_weapon == w5, "[场景五] 未损坏时 current_weapon 不变")
	assert(not u5.consume_weapon_durability(), "[场景五] 第 2 次扣耐久：未损坏")
	assert(w5.durability == 1, "[场景五] 耐久 2→1")
	assert(u5.consume_weapon_durability(), "[场景五] 第 3 次扣耐久：损坏")
	assert(w5.durability == 0, "[场景五] 耐久归零")
	assert(u5.current_weapon == null, "[场景五] 损坏后 current_weapon 置空")
	assert(not u5.inventory.has(w5), "[场景五] 损坏武器已从背包移除")
	##null weapon 不报错
	assert(not u5.consume_weapon_durability(), "[场景五] 无武器时安全返回 false")
	print("场景五 通过：consume_weapon_durability 扣耐久与损坏")

	# ===== 场景六：use_item 不影响 current_weapon =====
	var u6 := _make_unit("测试员", 30)
	u6.hp = 5  ##不触发 max_hp 钳位：5 + 15 = 20
	var w6 := _make_weapon("铁剑", 40)
	var potion_tres: Consumable = preload("res://scene/item/consumable_potion.tres") as Consumable
	var potion := potion_tres.duplicate() as Consumable
	u6.inventory = [w6, potion]
	u6.current_weapon = w6
	assert(u6.use_item(potion), "[场景六] 使用伤药成功")
	assert(u6.hp == 20, "[场景六] HP 5 + 15 = 20")
	assert(u6.current_weapon == w6, "[场景六] current_weapon 不被消耗品影响")
	print("场景六 通过：use_item 不影响 current_weapon")

	# ===== 场景七：模板不复制契约（add_item 不负责 duplicate）=====
	##P0-2 契约：add_item 不复制——调用方负责；共享模板的副作用由调用方承担
	var u7a := _make_unit("甲")
	var u7b := _make_unit("乙")
	var shared_template := _make_weapon("共享铁剑", 40)
	u7a.add_item(shared_template)
	u7b.add_item(shared_template)  ##按契约应复制后再加，避免共享——这里展示若不复制会污染
	##u7a 扣耐久
	u7a.consume_weapon_durability()
	assert(shared_template.durability == 39, "[场景七] 模板耐久被两边共享污染")
	##此场景是契约演示（add_item 不复制），非期望行为——文档已说明
	print("场景七 通过：add_item 不复制契约（模板非责任，需调用方 duplicate）")

	# ===== 场景八：全场景组合：换装→攻击扣耐久→损坏 =====
	var u8 := _make_unit("测试员")
	var sword8 := _make_weapon("铁剑", 2)  ##耐久 2：第 2 次后损坏
	var bow8 := _make_weapon("铁弓", 40)
	u8.inventory = [sword8, bow8]
	u8.current_weapon = sword8
	##换装到弓
	assert(u8.equip_item(bow8), "[场景八] 换装到弓成功")
	assert(u8.current_weapon == bow8, "[场景八] current_weapon = 弓")
	assert(u8.inventory.has(sword8), "[场景八] 剑仍在背包（仅换装未移除）")
	##切回剑并扣耐久
	assert(u8.equip_item(sword8), "[场景八] 切回剑成功")
	u8.consume_weapon_durability()
	assert(sword8.durability == 1, "[场景八] 第 1 次扣耐久 2→1")
	u8.consume_weapon_durability()  ##第 2 次：损坏
	assert(u8.current_weapon == null, "[场景八] 损坏后 current_weapon 置空")
	assert(not u8.inventory.has(sword8), "[场景八] 损坏剑已从背包移除")
	##背包还剩弓，可装备
	assert(u8.equip_item(bow8), "[场景八] 损坏后自动改用弓成功")
	assert(u8.current_weapon == bow8, "[场景八] current_weapon = 弓")
	print("场景八 通过：换装 → 攻击扣耐久 → 损坏 → 自动切换其他武器")

	print("===== P0-2 物品生命周期全部测试通过 =====")
	quit()


##"""构造测试 Unit（不入场景树，绕过 _ready/_own_inventory）"""
func _make_unit(p_name: String, hp: int = 20) -> Unit:
	var u := Unit.new()
	u.unit_name = p_name
	u.max_hp = hp
	u.hp = hp
	return u


##"""构造测试 Weapon（手工字段，不走 .tres duplicate）"""
func _make_weapon(p_name: String, dur: int = 40) -> Weapon:
	var w := Weapon.new()
	w.display_name = p_name
	w.weapon_type = Weapon.WeaponType.SWORD
	w.might = 5
	w.hit = 100
	w.crit = 0
	w.weight = 5
	w.min_range = 1
	w.max_range = 1
	w.durability = dur
	w.max_durability = dur
	return w