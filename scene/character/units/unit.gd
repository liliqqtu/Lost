extends Node2D
##所有单位父类
class_name Unit

##背包上限（FE 规则 5 槽；ItemMenu/TradeMenu/ConvoyPanel 共用此值，避免散落常量）
const BAG_LIMIT := 5

## 移动动画映射
const move_animation := {
	Vector2i.UP:    "move_up",
	Vector2i.DOWN:  "move_down",
	Vector2i.LEFT:  "move_left",
	Vector2i.RIGHT: "move_left"
}

##"""血条颜色阈值：血量比例 <= 0.5 变黄，<= 0.25 变红"""
const HP_BAR_YELLOW := 0.5
const HP_BAR_RED := 0.25

@export var move := 5
##武器类引用
@export var current_weapon: Weapon
##背包（上限 5，FE 规则）；Item 基类持有，具体类型（Weapon/Consumable/Key）由 is_*() 分流
@export var inventory: Array[Item] = []
##职业数据（人物面板读取：职业名/职业卡/能力上限/技能）
@export var class_data: ClassData
##个人技能（区别于职业技能——例如"仿徨"是"忒"独有，不属于弓骑/游牧民职业）
@export var personal_skills: Array[Skill] = []


@export var unit_name := ""
## 队伍 0是玩家 1是敌方 2是友军
@export var team := 0
## 是否携带运输队（主角忒等特定角色）
@export var has_convoy := false
## 等级
@export var lv := 5
## 经验值 只有玩家队伍拥有 每100经验升一级
@export var exp := 0
##"""等级上限（升级系统，GBA 未转职上限 20）：满级不再获得经验"""
const LEVEL_CAP := 20
##"""武器类型等级（升级系统）：决定职业可用的武器类型与等级上限（E..S）
##单位实际等级 = min(武器经验等级, 职业上限)，UNUSABLE=不可用该类型"""
## 剑武器等级
@export var rank_sword: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_lance: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_axe: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_bow: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_anima: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_dark: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_light: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export var rank_staff: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE

##"""武器类型 -> 人物等级上限（Weapon.WeaponRank，UNUSABLE=不可用）"""
func get_weapon_rank(type: int) -> int:
	match type:
		Weapon.WeaponType.SWORD: return rank_sword
		Weapon.WeaponType.LANCE: return rank_lance
		Weapon.WeaponType.AXE: return rank_axe
		Weapon.WeaponType.BOW: return rank_bow
		Weapon.WeaponType.ANIMA: return rank_anima
		Weapon.WeaponType.DARK: return rank_dark
		Weapon.WeaponType.LIGHT: return rank_light
		Weapon.WeaponType.STAFF: return rank_staff
	return Weapon.WeaponRank.UNUSABLE

##"""职业是否可用该武器类型"""
func can_use_weapon(type: int) -> bool:
	return get_weapon_rank(type) >= Weapon.WeaponRank.E
##"""武器经验（升级系统）：{武器类型(int): 累计经验}，惰性初始化到职业等级阈值
##只有玩家方结算（BattleCombat 判定），无职业数据的单位不积累"""
@export var weapon_xp: Dictionary = {}
## 最大hp
@export var max_hp := 20
## 当前hp
@export var hp := 20
## 力量
@export var str := 5
## 魔力
@export var mag := 0
## 技术
@export var skl := 5
## 速度
@export var spd := 5
## 守备
@export var def_h := 5
## 魔防
@export var res := 2
## 幸运
@export var luk := 0
## 体格 影响攻速（AS = 速度 - max(0, 武器重量 - 体格)）
@export var con := 5

#接下来的救出 状态 对话 指挥 目前仅作为角色信息面板需要的展示数据 暂不实现

## 救出
@export var rescue := false
## 状态
@export var status := 0
## 对话 要对话的人物
@export var talk := ""
## 指挥⭐ 每一点指挥为全队提供1命中1回避加成
@export var cmd := 0
## 战斗动画帧资源（阶段五 5A，战斗画面用；无资源时战斗画面跳过动画只结算）
@export var battle_frames: SpriteFrames


## 瓦片坐标
var cell: Vector2i = Vector2i.ZERO
## 本回合是否已行动
var has_acted := false
## 再移动阶段剩余力（仅 CANTO 状态期间有效）
var canto_remaining: int = 0

##被救援时脱离地图用的哨兵坐标（远离真实地图，不可被选中/攻击/寻路；5F）
const OFF_MAP_CELL := Vector2i(9999, 9999)
##正在携带的单位（5F 救援：被救单位脱离地图挂在救援者身上）
var carried_unit: Unit = null
##被谁携带（5F 救援：非空时本单位不在地图上）
var carried_by: Unit = null

##救援力 Aid（5F，FE8 公式）：步行=体格-1，骑乘·男=25-体格，骑乘·女=20-体格
##无职业数据按步行处理
func get_aid() -> int:
	var mt := ClassData.MountType.FOOT
	if class_data != null:
		mt = class_data.mount_type
	match mt:
		ClassData.MountType.MOUNTED_MALE:
			return 25 - con
		ClassData.MountType.MOUNTED_FEMALE:
			return 20 - con
		_:
			return con - 1

##能否救起 other（5F，FE8 规则）：自己未携带、对方未被救且未携带、Aid ≥ 对方体格
func can_rescue(other: Unit) -> bool:
	return carried_unit == null \
		and other.carried_by == null and other.carried_unit == null \
		and get_aid() >= other.con

## 职业移动力消耗表（键与瓦片集自定义属性 Name 的值一致）
var move_table := {
	"道路": 1,
	"平原": 1,
	"桥": 1,
	"宝箱": 1,
	"森林": 2,
	"山": 3,
	"河": -1,
	"湖": -1,
	"民居": 1,
	"道具店": 1,
	"武器店": 1,
	"斗技场": 1,
	"要塞": 1
}

## 获取武器攻击范围，无武器时返回默认值
##"""旧接口（兼容）：仅返回当前装备武器的有效射程（min/max），不含背包其他武器。
##新代码请用 Unit 替代：get_weapon_ranges() / get_attack_range() —— 会遍历背包所有可用武器。"""
func get_min_attack_range() -> int:
	return get_effective_min_range()

## 获取武器最大攻击范围，无武器时返回默认值
##"""旧接口（兼容）：仅返回当前装备武器的有效射程。"""
func get_max_attack_range() -> int:
	return get_effective_max_range()

## 仿徨等被动技能生效后的最小射程（叠加所有技能的 min_range_delta，兜底 ≥1）
func get_effective_min_range() -> int:
	var base: int = current_weapon.min_range if current_weapon else 1
	for s in _all_skills():
		base += s.min_range_delta
	return maxi(base, 1)

## 仿徨等被动技能生效后的最大射程（叠加所有技能的 max_range_delta，兜底 ≥1）
func get_effective_max_range() -> int:
	var base: int = current_weapon.max_range if current_weapon else 1
	for s in _all_skills():
		base += s.max_range_delta
	return maxi(base, 1)

##"""遍历背包中所有可用武器，返回各自的（技能修正后的）射程区间（P0-1 统一接口）
##每项：{min: int, max: int, weapon: Weapon}
##"可用"= Weapon 子类 + 耐久 > 0；空背包/无可用武器返回空数组
##技能 min/max_range_delta 对背包内所有武器同时生效（仿徨让弓射程也-1）
##此为统一攻击范围来源——玩家菜单/目标选择/战斗预览/敌方 AI/敌人范围查看共用
##（不再各自只读 current_weapon）"""
func get_weapon_ranges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if inventory.is_empty():
		return result
	var min_delta := 0
	var max_delta := 0
	for s in _all_skills():
		min_delta += s.min_range_delta
		max_delta += s.max_range_delta
	for item in inventory:
		var w := item as Weapon
		if w == null or w.durability <= 0:
			continue
		result.append({
			"min": maxi(1, w.min_range + min_delta),
			"max": maxi(1, w.max_range + max_delta),
			"weapon": w,
		})
	return result

##"""计算单位在 cells（站位列表）上的并集攻击范围（P0-1 统一接口）
##底层调 Pathfinder.get_attack_range_union——遍历背包所有可用武器的射程取并集
##cells 通常为 move_range.keys()（移动预览）或 [unit.cell]（移动后单格）
##返回 Array[Vector2i]，已去重并剔除 cells 中的格子（移动范围内不重叠显示）"""
func get_attack_range(tile_map: TileMapLayer, cells: Array) -> Array:
	return Pathfinder.get_attack_range_union(cells, get_weapon_ranges(), tile_map)

## 合并查询所有技能（职业技能 + 个人技能）
func _all_skills() -> Array[Skill]:
	var all: Array[Skill] = []
	if class_data:
		all.append_array(class_data.skills)
	all.append_array(personal_skills)
	return all

## 获取单位最强的再移动触发等级（ALL > NO_ATTACK > PASSIVE）
func get_canto_trigger() -> Skill.SkillTrigger:
	for s in _all_skills():
		if s.trigger == Skill.SkillTrigger.POST_ACTION_ALL:
			return Skill.SkillTrigger.POST_ACTION_ALL
	for s in _all_skills():
		if s.trigger == Skill.SkillTrigger.POST_ACTION_NO_ATTACK:
			return Skill.SkillTrigger.POST_ACTION_NO_ATTACK
	return Skill.SkillTrigger.PASSIVE

## 攻击后是否还能再移动（POST_ACTION_ALL 才行）
func can_canto_after_attack() -> bool:
	return get_canto_trigger() == Skill.SkillTrigger.POST_ACTION_ALL

## 非攻击行动后是否还能再移动（POST_ACTION_NO_ATTACK 或 POST_ACTION_ALL）
func can_canto_after_non_attack() -> bool:
	var t := get_canto_trigger()
	return t == Skill.SkillTrigger.POST_ACTION_NO_ATTACK \
		or t == Skill.SkillTrigger.POST_ACTION_ALL

## 转换为灰度效果（已行动）
func apply_grayscale() -> void:
	_ensure_unique_material()
	$MapSprite2D.material.set("shader_parameter/grayscale", true)

## 移除灰度效果
func remove_grayscale() -> void:
	_ensure_unique_material()
	$MapSprite2D.material.set("shader_parameter/grayscale", false)

## 材料是否已复制
var _material_duplicated := false

## 确保材料唯一
func _ensure_unique_material() -> void:
	if _material_duplicated:
		return
	if $MapSprite2D.material:
		$MapSprite2D.material = $MapSprite2D.material.duplicate()
	_material_duplicated = true
	
##动画结束信号
signal _end_move()

##播放动画
func _animate_step(path:Array, index:int):
	if path.is_empty():
		_end_move.emit()
		return
	if index >= path.size()-1:
		play_idle_animation()
		$MapSprite2D.flip_h = false
		_end_move.emit()
		return

	var from = path[index]
	var to = path[index+1]

	var dir = to - from

	play_move_animation(dir)

	var tween = create_tween()

	tween.tween_property(
		self,
		"global_position",
		Vector2(to) * Global.TILE_SIZE,
		0.12
	)

	tween.finished.connect(func():
		_animate_step(path, index + 1)
	)

## 播放移动动画
func play_move_animation(direction: Vector2i):
	$MapSprite2D.play(move_animation[direction])
	if direction.x > 0 :
		$MapSprite2D.flip_h = true
	else :
		$MapSprite2D.flip_h = false

## 播放空闲动画
func play_idle_animation():
	$MapSprite2D.play("idle")

## 播放选中动画
func play_selected_animation():
	$MapSprite2D.play("idle_selected")


##血条节点（场景里名为 "hp" 的 ProgressBar；unit.tscn 未放置时为 null）
@onready var hp_bar: ProgressBar = get_node_or_null("hp")
##"""血条填充样式，运行时创建用于变色"""
var _hp_fill_style: StyleBoxFlat


func _ready() -> void:
	_own_inventory()
	_setup_hp_bar()
	update_hp_bar()


##"""背包实例唯一化 + 默认装备（5D 耐久显示修复）：
##te.tscn 里 inventory 直接引用 .tres（ExtResource 是共享模板），不 duplicate 的话
##多个实例会共享耐久状态互相污染；current_weapon 必须指向背包内的同一实例，
##"攻击扣耐久"与"物品行显示耐久"才是同一把武器"""
func _own_inventory() -> void:
	##装备是否原本就在背包里（duplicate 后要映射到新实例，避免凭空多出一件）
	var equipped_in_bag := current_weapon != null and inventory.has(current_weapon)
	for i in inventory.size():
		if inventory[i] != null:
			inventory[i] = (inventory[i] as Item).duplicate() as Item
	if current_weapon == null:
		##未装备：默认装上背包第一件可装备的武器（武器等级限制，升级系统）
		for item in inventory:
			if item is Weapon and can_equip(item):
				current_weapon = item
				break
	elif not equipped_in_bag and not inventory.has(current_weapon):
		##装备了不在背包的武器（关卡脚本赋值/场景直配）：复制一份入包，面板可见
		current_weapon = current_weapon.duplicate() as Weapon
		inventory.append(current_weapon)


##"""使用消耗品：恢复 HP 并扣 1 点使用次数，次数归零从背包移除；返回是否成功使用"""
func use_item(item: Item) -> bool:
	var c := item as Consumable
	if c == null or not inventory.has(item):
		return false
	hp = mini(hp + c.heal_hp, max_hp)
	update_hp_bar()
	if c.consume_durability():
		inventory.erase(item)
	return true


##==================== 物品转移统一接口（P0-2） ====================
## 不变量：`current_weapon == null` 或 `inventory.has(current_weapon)`
## 任何代码修改 inventory / current_weapon 都应通过以下方法，UI 只读 inventory 不做修改。
## 模板 .tres 不会直接作为运行时消耗对象；调用方需先 duplicate() 再 add_item()。
## 转移前若目标是 current_weapon，由本类统一卸装（调用方不需要手动置空）。

##"""添加物品到背包：满返回 false（不复制——调用方负责 duplicate）；不修改 current_weapon"""
func add_item(item: Item) -> bool:
	if item == null or inventory.size() >= BAG_LIMIT:
		return false
	inventory.append(item)
	return true


##"""按引用移除物品：若该物品是 current_weapon 则同步卸装"""
func remove_item(item: Item) -> bool:
	if item == null or not inventory.has(item):
		return false
	inventory.erase(item)
	if current_weapon == item:
		current_weapon = null
	return true


##"""按索引移除物品：用于交换界面/运输队面板；同步 current_weapon"""
func remove_item_at(index: int) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	var item := inventory[index]
	inventory.remove_at(index)
	if current_weapon == item:
		current_weapon = null
	return true


##"""装备物品：必须是 inventory 内的 Weapon 且满足武器等级限制（升级系统），返回是否成功"""
func equip_item(item: Item) -> bool:
	if item == null or not inventory.has(item):
		return false
	if item is Weapon:
		if not can_equip(item):
			##打印失败原因：职业等级限制导致装备被拒时立刻可见（避免静默失败难排查）
			print("%s 无法装备 %s：职业不可用该武器类型，或武器等级不足（当前 %s）" % [
				unit_name, item.display_name, Weapon.rank_to_text(get_weapon_ex(item.weapon_type))])
			return false
		current_weapon = item
		return true
	return false


##"""武器耐久归零的统一路径：扣当前武器耐久，归零则从背包移除并卸装，返回是否损坏。
##由 BattleCombat 每次打击（含未命中）后调用，UI 不需要关心耐久与库存同步。"""
func consume_weapon_durability() -> bool:
	if current_weapon == null:
		return false
	var w := current_weapon
	var broken := w.consume_durability()
	if broken:
		print("%s 的%s耐久耗尽，武器损坏！" % [unit_name, w.display_name])
		inventory.erase(w)
		current_weapon = null
	return broken


##"""直接令当前武器损坏并从背包移除（FE：耐久扣完立刻消失，与 _consume_weapon 等价）"""
func break_current_weapon() -> bool:
	if current_weapon == null:
		return false
	var w := current_weapon
	inventory.erase(w)
	current_weapon = null
	return true


##==================== 经验与武器等级（升级系统） ====================

##"""累计武器经验（惰性初始化）：可用类型从 E（经验 1）起步
##rank_* 是该类型的等级上限（挂在 Unit 上，ClassData 只存职业静态数据），从 E 逐步积累到上限
##初始更高的单位（转职/预转职角色）可在 tscn 里直接预填 weapon_xp"""
func get_weapon_xp(type: int) -> int:
	if  not can_use_weapon(type):
		return 0
	if not weapon_xp.has(type):
		weapon_xp[type] = Weapon.WEXP_THRESHOLDS[Weapon.WeaponRank.E]
	return weapon_xp[type]


##"""当前武器等级 = min(武器经验等级, rank_* 上限)；-1=不可用"""
func get_weapon_ex(type: int) -> int:
	if not can_use_weapon(type):
		return Weapon.WeaponRank.UNUSABLE
	return mini(Weapon.wexp_to_rank(get_weapon_xp(type)), get_weapon_rank(type))


##"""获得武器经验（每次命中的打击结算）：不可用的类型不积累，封顶在等级上限阈值
##（get_weapon_rank = rank_* 上限；用 get_weapon_ex 会把封顶锁死在当前等级，经验永远不涨）"""
func gain_weapon_exp(weapon: Weapon) -> void:
	if weapon == null :
		return
	var type := weapon.weapon_type
	if not can_use_weapon(type):
		return
	var cap_xp := Weapon.WEXP_THRESHOLDS[get_weapon_rank(type)] as int
	weapon_xp[type] = mini(get_weapon_xp(type) + weapon.weapon_exp, cap_xp)


##"""能否装备该武器：类型可用且**当前**等级（get_weapon_ex）达到武器需求等级
##无职业数据不限制（敌人兜底：_create_enemy 造的单位不设 rank_*，见 level.gd）"""
func can_equip(weapon: Weapon) -> bool:
	if weapon == null:
		return false
	if class_data == null:
		return true
	if not can_use_weapon(weapon.weapon_type):
		return false
	return get_weapon_ex(weapon.weapon_type) >= weapon.required_rank


##"""获得经验：满级（LEVEL_CAP）不再累积"""
func gain_exp(amount: int) -> void:
	if lv >= LEVEL_CAP:
		return
	exp += amount


##"""升级：等级+1、经验-100、按加点结果提升能力（加点由 BattleCalculator.roll_level_up 掷骰）"""
func level_up(gains: Dictionary) -> void:
	lv += 1
	exp -= 100
	var hp_up: int = gains.get("hp", 0)
	if hp_up > 0:
		max_hp += hp_up
		hp = mini(hp + hp_up, max_hp)
	str += gains.get("str", 0)
	mag += gains.get("mag", 0)
	skl += gains.get("skl", 0)
	spd += gains.get("spd", 0)
	luk += gains.get("luk", 0)
	def_h += gains.get("def_h", 0)
	res += gains.get("res", 0)
	update_hp_bar()


##"""初始化血条：黑色背景、不显示百分比文字"""
func _setup_hp_bar() -> void:
	if hp_bar == null:
		return
	hp_bar.min_value = 0
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	hp_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color.BLACK
	hp_bar.add_theme_stylebox_override("background", bg)
	_hp_fill_style = StyleBoxFlat.new()
	hp_bar.add_theme_stylebox_override("fill", _hp_fill_style)


##"""刷新血条：满血隐藏；>一半绿色，<=一半黄色，<=1/4红色"""
func update_hp_bar() -> void:
	if hp_bar == null:
		return
	hp_bar.max_value = max_hp
	hp_bar.value = hp
	if hp >= max_hp:
		hp_bar.visible = false
		return
	hp_bar.visible = true
	var ratio := float(hp) / float(max_hp)
	if ratio <= HP_BAR_RED:
		_hp_fill_style.bg_color = Color(0.9, 0.1, 0.1)
	elif ratio <= HP_BAR_YELLOW:
		_hp_fill_style.bg_color = Color(1, 0.85, 0.2)
	else:
		_hp_fill_style.bg_color = Color(0, 0.75, 0)
