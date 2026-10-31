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

## 人物名字
@export var unit_name := ""
## 人物描述
@export var info := ""
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

##"""武器经验（升级系统）：{武器类型(int): 累计经验}，惰性初始化到职业等级阈值"""
@export var weapon_xp: Dictionary = {}
## 最大hp
@export var max_hp := 20
## 当前hp
@export var hp := 20
## 力量 / 魔力 / 技巧 / 速度 / 守备 / 魔防 / 幸运 / 体格
@export var str := 5
@export var mag := 0
@export var skl := 5
@export var spd := 5
@export var def_h := 5
@export var res := 2
@export var luk := 0
@export var con := 5

## 救出 / 状态 / 对话 / 指挥 / 战斗动画帧
@export var rescue := false
@export var status := 0
@export var talk := ""
@export var cmd := 0
@export var battle_frames: SpriteFrames

## 瓦片坐标与行动状态
var cell: Vector2i = Vector2i.ZERO
var has_acted := false
var canto_remaining: int = 0
## 本回合是否已经触发过“笃行”（攻击后再次行动，每回合限一次）
var relentless_advance_triggered_this_turn := false

##被救援时脱离地图用的哨兵坐标（5F）
const OFF_MAP_CELL := Vector2i(9999, 9999)
var carried_unit: Unit = null
var carried_by: Unit = null

##救援力 Aid（5F，FE8 公式）：步行=体格-1，骑乘·男=25-体格，骑乘·女=20-体格
func get_aid() -> int:
	var mt := ClassData.MountType.FOOT
	if class_data != null:
		mt = class_data.mount_type
	match mt:
		ClassData.MountType.MOUNTED_MALE: return 25 - con
		ClassData.MountType.MOUNTED_FEMALE: return 20 - con
		_: return con - 1

##能否救起 other（5F，FE8 规则）
func can_rescue(other: Unit) -> bool:
	return carried_unit == null and other.carried_by == null \
		and other.carried_unit == null and get_aid() >= other.con

## 职业移动力消耗表（键与瓦片集自定义属性 Name 一致）
var move_table := {
	"道路": 1, "平原": 1, "桥": 1, "宝箱": 1, "森林": 2, "山": 3,
	"河": -1, "湖": -1, "民居": 1, "道具店": 1, "武器店": 1, "斗技场": 1, "要塞": 1
}

func get_min_attack_range() -> int: return get_effective_min_range()
func get_max_attack_range() -> int: return get_effective_max_range()

## 技能修正后的有效最小/最大射程
func get_effective_min_range() -> int:
	var base: int = current_weapon.min_range if current_weapon else 1
	for s in _all_skills():
		base += s.min_range_delta
	return maxi(base, 1)

func get_effective_max_range() -> int:
	var base: int = current_weapon.max_range if current_weapon else 1
	for s in _all_skills():
		base += s.max_range_delta
	return maxi(base, 1)

## 遍历背包中所有可用武器的射程区间（P0-1）
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

## 计算单位在 cells 上的并集攻击范围
func get_attack_range(tile_map: TileMapLayer, cells: Array) -> Array:
	return Pathfinder.get_attack_range_union(cells, get_weapon_ranges(), tile_map)

## 计算单位装备指定武器时在 cells 上的攻击范围
func get_attack_range_for_weapon(tile_map: TileMapLayer, cells: Array, weapon: Weapon) -> Array:
	if weapon == null or weapon.durability <= 0:
		return []
	var min_delta := 0
	var max_delta := 0
	for s in _all_skills():
		min_delta += s.min_range_delta
		max_delta += s.max_range_delta
	var range_dict: Array[Dictionary] = [{
		"min": maxi(1, weapon.min_range + min_delta),
		"max": maxi(1, weapon.max_range + max_delta),
		"weapon": weapon,
	}]
	return Pathfinder.get_attack_range_union(cells, range_dict, tile_map)

##==================== 统一技能体系与属性计算管道 ====================

## 合并查询当前生效的所有技能（职业技能 + 个人技能 + 装备武器附加技能）
func get_all_active_skills() -> Array[Skill]:
	var all: Array[Skill] = []
	if class_data:
		for s in class_data.skills:
			if s != null and not all.has(s):
				all.append(s)
	for s in personal_skills:
		if s != null and not all.has(s):
			all.append(s)
	if current_weapon != null:
		if current_weapon.has_method("get_skills"):
			for s in current_weapon.get_skills():
				if s != null and not all.has(s):
					all.append(s)
		elif "skills" in current_weapon:
			for s in current_weapon.skills:
				if s != null and not all.has(s):
					all.append(s)
	return all

## 兼容旧 _all_skills 调用
func _all_skills() -> Array[Skill]:
	return get_all_active_skills()

## 是否拥有“笃行”（攻击后再次行动）特技
func has_act_again_skill() -> bool:
	for s in get_all_active_skills():
		if s != null and s.is_act_again():
			return true
	return false

## 计算属性有效值（基础值 + 装备武器加成 + 被动技能加成 + 战场光环加成）
func get_effective_stat(stat_name: String, all_units: Array = []) -> int:
	var val: int = get(stat_name) if stat_name in self else 0
	if current_weapon != null and current_weapon.has_method("get_stat_bonus"):
		val += current_weapon.get_stat_bonus(stat_name)
	for s in get_all_active_skills():
		if s != null and s.aura_range == 0:
			val += s.get_stat_bonus(stat_name)
	val += get_aura_bonus(stat_name, all_units)
	return val

## 战场友军光环加成（如“公在”临近2格友军双防+2）
func get_aura_bonus(stat_name: String, all_units: Array) -> int:
	if all_units.is_empty():
		return 0
	var bonus := 0
	for other in all_units:
		if other == self or not (other is Unit) or other.team != team or other.carried_by != null:
			continue
		var dist: int = absi(cell.x - other.cell.x) + absi(cell.y - other.cell.y)
		for s in other.get_all_active_skills():
			if s != null and s.aura_range > 0 and dist <= s.aura_range:
				bonus += s.get_stat_bonus(stat_name)
	return bonus

func get_effective_str(all_units: Array = []) -> int: return get_effective_stat("str", all_units)
func get_effective_mag(all_units: Array = []) -> int: return get_effective_stat("mag", all_units)
func get_effective_skl(all_units: Array = []) -> int: return get_effective_stat("skl", all_units)
func get_effective_spd(all_units: Array = []) -> int: return get_effective_stat("spd", all_units)
func get_effective_def(all_units: Array = []) -> int: return get_effective_stat("def_h", all_units)
func get_effective_res(all_units: Array = []) -> int: return get_effective_stat("res", all_units)
func get_effective_luk(all_units: Array = []) -> int: return get_effective_stat("luk", all_units)
func get_effective_con(all_units: Array = []) -> int: return get_effective_stat("con", all_units)
func get_effective_move(all_units: Array = []) -> int: return get_effective_stat("move", all_units)

## 重置回合行动状态
func reset_turn_state() -> void:
	has_acted = false
	relentless_advance_triggered_this_turn = false
	remove_grayscale()

## 获取单位最强的再移动触发等级（ALL > NO_ATTACK > PASSIVE）
func get_canto_trigger() -> Skill.SkillTrigger:
	for s in _all_skills():
		if s.trigger == Skill.SkillTrigger.POST_ACTION_ALL:
			return Skill.SkillTrigger.POST_ACTION_ALL
	for s in _all_skills():
		if s.trigger == Skill.SkillTrigger.POST_ACTION_NO_ATTACK:
			return Skill.SkillTrigger.POST_ACTION_NO_ATTACK
	return Skill.SkillTrigger.PASSIVE

func can_canto_after_attack() -> bool:
	return get_canto_trigger() == Skill.SkillTrigger.POST_ACTION_ALL

func can_canto_after_non_attack() -> bool:
	var t := get_canto_trigger()
	return t == Skill.SkillTrigger.POST_ACTION_NO_ATTACK or t == Skill.SkillTrigger.POST_ACTION_ALL

## 灰度着色器操作
func apply_grayscale() -> void:
	_ensure_unique_material()
	$MapSprite2D.material.set("shader_parameter/grayscale", true)

func remove_grayscale() -> void:
	_ensure_unique_material()
	$MapSprite2D.material.set("shader_parameter/grayscale", false)

var _material_duplicated := false
func _ensure_unique_material() -> void:
	if not _material_duplicated and $MapSprite2D.material:
		$MapSprite2D.material = $MapSprite2D.material.duplicate()
		_material_duplicated = true

## 移动动画与步进
signal _end_move()

func _animate_step(path: Array, index: int) -> void:
	if path.is_empty():
		_end_move.emit()
		return
	if index >= path.size() - 1:
		play_idle_animation()
		$MapSprite2D.flip_h = false
		_end_move.emit()
		return
	var from = path[index]
	var to = path[index + 1]
	play_move_animation(to - from)
	var tween = create_tween()
	tween.tween_property(self, "global_position", Vector2(to) * Global.TILE_SIZE, 0.12)
	tween.finished.connect(func(): _animate_step(path, index + 1))

func play_move_animation(direction: Vector2i) -> void:
	$MapSprite2D.play(move_animation[direction])
	$MapSprite2D.flip_h = direction.x > 0

func play_idle_animation() -> void: $MapSprite2D.play("idle")
func play_selected_animation() -> void: $MapSprite2D.play("idle_selected")

@onready var hp_bar: ProgressBar = get_node_or_null("hp")
var _hp_fill_style: StyleBoxFlat

func _ready() -> void:
	_own_inventory()
	_setup_hp_bar()
	update_hp_bar()

## 背包实例唯一化与默认装备
func _own_inventory() -> void:
	var equipped_in_bag := current_weapon != null and inventory.has(current_weapon)
	for i in inventory.size():
		if inventory[i] != null:
			inventory[i] = (inventory[i] as Item).duplicate() as Item
	if current_weapon == null:
		for item in inventory:
			if item is Weapon and can_equip(item):
				current_weapon = item
				break
	elif not equipped_in_bag and not inventory.has(current_weapon):
		current_weapon = current_weapon.duplicate() as Weapon
		inventory.append(current_weapon)

## 使用消耗品
func use_item(item: Item) -> bool:
	var c := item as Consumable
	if c == null or not inventory.has(item):
		return false
	hp = mini(hp + c.heal_hp, max_hp)
	update_hp_bar()
	if c.consume_durability():
		inventory.erase(item)
	return true

## 物品转移统一接口（P0-2）
func add_item(item: Item) -> bool:
	if item == null or inventory.size() >= BAG_LIMIT:
		return false
	inventory.append(item)
	return true

func remove_item(item: Item) -> bool:
	if item == null or not inventory.has(item):
		return false
	inventory.erase(item)
	if current_weapon == item:
		current_weapon = null
	return true

func remove_item_at(index: int) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	var item := inventory[index]
	inventory.remove_at(index)
	if current_weapon == item:
		current_weapon = null
	return true

func equip_item(item: Item) -> bool:
	if item == null or not inventory.has(item):
		return false
	if item is Weapon:
		if not can_equip(item):
			print("%s 无法装备 %s：职业不可用该武器类型，或武器等级不足（当前 %s）" % [
				unit_name, item.display_name, Weapon.rank_to_text(get_weapon_ex(item.weapon_type))])
			return false
		current_weapon = item
		# GBA FE 规则：手动/换装武器后将其移至物品栏首位 (index 0)
		var idx := inventory.find(item)
		if idx > 0:
			inventory.remove_at(idx)
			inventory.insert(0, item)
		return true
	return false

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

func break_current_weapon() -> bool:
	if current_weapon == null:
		return false
	var w := current_weapon
	inventory.erase(w)
	current_weapon = null
	return true

## 经验与武器等级（升级系统）
func get_weapon_xp(type: int) -> int:
	if not can_use_weapon(type):
		return 0
	if not weapon_xp.has(type):
		weapon_xp[type] = Weapon.WEXP_THRESHOLDS[get_weapon_rank(type)]
	return weapon_xp[type]

func get_weapon_ex(type: int) -> int:
	if not can_use_weapon(type):
		return Weapon.WeaponRank.UNUSABLE
	return mini(Weapon.wexp_to_rank(get_weapon_xp(type)), get_weapon_rank(type))

func gain_weapon_exp(weapon: Weapon) -> void:
	if weapon == null:
		return
	var type := weapon.weapon_type
	if not can_use_weapon(type):
		return
	var cap_xp := Weapon.WEXP_THRESHOLDS[get_weapon_rank(type)] as int
	weapon_xp[type] = mini(get_weapon_xp(type) + weapon.weapon_exp, cap_xp)

func can_equip(weapon: Weapon) -> bool:
	if weapon == null:
		return false
	if class_data == null:
		return true
	if not can_use_weapon(weapon.weapon_type):
		return false
	return get_weapon_ex(weapon.weapon_type) >= weapon.required_rank

func gain_exp(amount: int) -> void:
	if lv >= LEVEL_CAP:
		return
	exp += amount

func level_up(gains: Dictionary) -> void:
	lv += 1
	exp -= 100
	var hp_up: int = gains.get("hp", 0)
	if hp_up > 0:
		max_hp += hp_up
		hp = mini(hp + hp_up, max_hp)
	for k in ["str", "mag", "skl", "spd", "luk", "def_h", "res"]:
		set(k, get(k) + gains.get(k, 0))
	update_hp_bar()

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
