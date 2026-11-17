extends Node2D
class_name Unit
const BAG_LIMIT := 5
const move_animation := {
	Vector2i.UP:    "move_up",
	Vector2i.DOWN:  "move_down",
	Vector2i.LEFT:  "move_left",
	Vector2i.RIGHT: "move_left"
}
const HP_BAR_YELLOW := 0.5
const HP_BAR_RED := 0.25

@export_group("身份与阵营")
## 角色显示名：用于人物面板、对话匹配和支援表。
@export var unit_name := ""
## 跨章节存档的稳定角色 ID；主角团应填写唯一值，勿随显示名一起修改。
@export var unit_id: StringName = &""
## 角色简介：人物面板的信息查看文字。
@export var info := ""
## 阵营编号：0＝玩家蓝军，1＝敌方红军，2＝友方绿军；同步地图精灵配色。
@export var team := 0:
	set(value):
		team = value
		update_team_palette()
## 是否为 Boss：用于专属交战台词及死亡演出。
@export var is_boss := false
## 是否可提供运输队入口；当前由该单位的行动菜单开放运输队。
@export var has_convoy := false
## 职业资源：职业名、成长率、属性上限、职业技能和骑乘类型。
@export var class_data: ClassData
@export_group("等级与基础能力")
## 当前等级；等级上限为 20，上位职业结算经验时另计等效等级。
@export var lv := 5
## 当前升级经验：每满 100 点升一级；与武器熟练经验分开计算。
@export var exp := 0
const LEVEL_CAP := 20
## 移动力：本次行动可消耗的地形移动点；技能可另加修正，并非固定走几格。
@export var move := 5
## 最大生命值：满血上限，升级增加 HP 时增长此值。
@export var max_hp := 20
## 当前生命值：受伤/治疗改变此值；初始配置通常与 Max Hp 一致。
@export var hp := 20
## 力量（STR）：物理武器的攻击力基础值；不含武器威力和技能加成。
@export var str := 5
## 魔力（MAG）：魔法武器攻击力及治疗杖恢复量的基础值。
@export var mag := 0
## 技术（SKL）：参与命中和必杀计算；基础命中加技术×2，必杀加技术÷2。
@export var skl := 5
## 速度（SPD）：攻速基础值；攻速影响回避，攻速领先 4 点可追击。
@export var spd := 5
## 守备（DEF）：抵消物理伤害；在技能加成字典中也使用 def_h 这个键。
@export var def_h := 5
## 魔防（RES）：抵消魔法伤害。
@export var res := 2
## 幸运（LUK）：参与命中、回避和必杀回避计算。
@export var luk := 0
## 体格（CON）：抵消武器重量造成的攻速惩罚，也影响救援能力及能否被救援。
@export var con := 5
@export_group("装备与个人技能")
## 初始背包：最多 5 件，运行时会复制物品以隔离耐久；代码改包请使用 Unit 接口。
@export var inventory: Array[Item] = []
## 初始装备：应引用背包中的同一武器；留空时入场自动选择可装备武器。
@export var current_weapon: Weapon
## 角色固有技能：与职业技能、当前装备武器技能共同生效。
@export var personal_skills: Array[Skill] = []
@export_group("武器等级上限")
## 剑的可成长等级上限；UNUSABLE＝不可用。当前等级由 Weapon Xp 决定。
@export var rank_sword: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
## 枪的可成长等级上限；UNUSABLE＝不可用，并非当前熟练等级。
@export var rank_lance: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
## 斧的可成长等级上限；UNUSABLE＝不可用，并非当前熟练等级。
@export var rank_axe: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
## 弓的可成长等级上限；UNUSABLE＝不可用，并非当前熟练等级。
@export var rank_bow: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
## 理魔法的可成长等级上限；UNUSABLE＝不可用，并非当前熟练等级。
@export var rank_anima: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
## 暗魔法的可成长等级上限；UNUSABLE＝不可用，并非当前熟练等级。
@export var rank_dark: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
## 光魔法的可成长等级上限；UNUSABLE＝不可用，并非当前熟练等级。
@export var rank_light: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
## 杖的可成长等级上限；UNUSABLE＝不可用，并非当前熟练等级。
@export var rank_staff: Weapon.WeaponRank = Weapon.WeaponRank.UNUSABLE
@export_group("当前武器熟练度")
## 键为整数武器类型（0剑/1枪/2斧/3弓/4理/5暗/6光/7杖），值为累计经验。
## E/D/C/B/A/S 门槛依次为 1/31/71/121/181/251；未填写的可用类型从 E 开始。
@export var weapon_xp: Dictionary = {}
@export_group("对话与战斗演出")
## 可说得/对话的对象名字，需与目标 Unit Name 完全一致；空字符串表示无对象。
@export var talk := ""
## 指挥星数量：目前仅供人物面板显示，尚未提供全军战斗加成。
@export var cmd := 0
## 战斗特写使用的 SpriteFrames；地图精灵动画另在 MapSprite2D 节点配置。
@export var battle_frames: SpriteFrames
@export_group("运行状态与预留字段")
## 是否正被救援携带的运行标记；由救援流程维护，初始通常保持 false。
@export var rescue := false
## 异常状态预留编号：当前没有对应效果结算，初始保持 0。
@export var status := 0
@export_group("")
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

func can_use_weapon(type: int) -> bool:
	return get_weapon_rank(type) >= Weapon.WeaponRank.E
var cell: Vector2i = Vector2i.ZERO
var has_acted := false
var canto_remaining: int = 0
var relentless_advance_triggered_this_turn := false
const OFF_MAP_CELL := Vector2i(9999, 9999)
var carried_unit: Unit = null
var carried_by: Unit = null

func get_aid() -> int:
	var mt := ClassData.MountType.FOOT
	if class_data != null:
		mt = class_data.mount_type
	match mt:
		ClassData.MountType.MOUNTED_MALE: return 25 - con
		ClassData.MountType.MOUNTED_FEMALE: return 20 - con
		_: return con - 1

func can_rescue(other: Unit) -> bool:
	return carried_unit == null and other.carried_by == null \
		and other.carried_unit == null and get_aid() >= other.con
var move_table := {
	"道路": 1, "平原": 1, "桥": 1, "宝箱": 1, "森林": 2, "山": 3,
	"河": -1, "湖": -1, "民居": 1, "道具店": 1, "武器店": 1, "斗技场": 1, "要塞": 1
}

func get_min_attack_range() -> int: return get_effective_min_range()
func get_max_attack_range() -> int: return get_effective_max_range()

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

func get_weapon_ranges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if inventory.is_empty():
		return result
	for item in inventory:
		var weapon := item as Weapon
		if BattleCalculator.can_attack_with(self, weapon):
			var ranges := get_range_for_weapon(weapon)
			ranges["weapon"] = weapon
			result.append(ranges)
	return result

func get_range_for_weapon(weapon: Weapon) -> Dictionary:
	var min_r := weapon.min_range
	var max_r := weapon.max_range
	for skill in get_skills_with_weapon(weapon):
		min_r += skill.min_range_delta
		max_r += skill.max_range_delta
	return {"min": maxi(1, min_r), "max": maxi(1, max_r)}

func get_attack_range(tile_map: TileMapLayer, cells: Array) -> Array:
	return Pathfinder.get_attack_range_union(cells, get_weapon_ranges(), tile_map)

func get_attack_range_for_weapon(tile_map: TileMapLayer, cells: Array, weapon: Weapon) -> Array:
	if not BattleCalculator.can_attack_with(self, weapon):
		return []
	var ranges := get_range_for_weapon(weapon)
	return Pathfinder.get_attack_range_union(cells, [ranges] as Array[Dictionary], tile_map)

func get_all_active_skills() -> Array[Skill]:
	return get_skills_with_weapon(current_weapon)

func get_skills_with_weapon(weapon: Weapon) -> Array[Skill]:
	var all: Array[Skill] = []
	if class_data:
		for s in class_data.skills:
			if s != null and not all.has(s):
				all.append(s)
	for s in personal_skills:
		if s != null and not all.has(s):
			all.append(s)
	if weapon != null:
		if weapon.has_method("get_skills"):
			for s in weapon.get_skills():
				if s != null and not all.has(s):
					all.append(s)
		elif "skills" in weapon:
			for s in weapon.skills:
				if s != null and not all.has(s):
					all.append(s)
	return all

func _all_skills() -> Array[Skill]:
	return get_all_active_skills()

func has_act_again_skill() -> bool:
	for s in get_all_active_skills():
		if s != null and s.is_act_again():
			return true
	return false

func get_effective_stat(stat_name: String, all_units: Array = []) -> int:
	var val: int = get(stat_name) if stat_name in self else 0
	if current_weapon != null and current_weapon.has_method("get_stat_bonus"):
		val += current_weapon.get_stat_bonus(stat_name)
	for s in get_all_active_skills():
		if s != null and s.aura_range == 0:
			val += s.get_stat_bonus(stat_name)
	val += get_aura_bonus(stat_name, all_units)
	return val

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

func reset_turn_state() -> void:
	has_acted = false
	relentless_advance_triggered_this_turn = false
	remove_grayscale()

func get_canto_trigger() -> Skill.SkillTrigger:
	for s in _all_skills():
		if s.trigger == Skill.SkillTrigger.POST_ACTION_ALL:
			return Skill.SkillTrigger.POST_ACTION_ALL
	for s in _all_skills():
		if s.trigger == Skill.SkillTrigger.POST_ACTION_NO_ATTACK:
			return Skill.SkillTrigger.POST_ACTION_NO_ATTACK
	return Skill.SkillTrigger.PASSIVE

func can_canto_after_attack() -> bool: return get_canto_trigger() == Skill.SkillTrigger.POST_ACTION_ALL
func can_canto_after_non_attack() -> bool:
	var t := get_canto_trigger()
	return t == Skill.SkillTrigger.POST_ACTION_NO_ATTACK or t == Skill.SkillTrigger.POST_ACTION_ALL

func apply_grayscale() -> void:
	if not has_node("MapSprite2D"): return
	_ensure_unique_material()
	$MapSprite2D.material.set("shader_parameter/grayscale", true)

func remove_grayscale() -> void:
	if not has_node("MapSprite2D"): return
	_ensure_unique_material()
	$MapSprite2D.material.set("shader_parameter/grayscale", false)

func update_team_palette() -> void:
	if not has_node("MapSprite2D"): return
	_ensure_unique_material()
	var mat := $MapSprite2D.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("team", team)
var _material_duplicated := false
func _ensure_unique_material() -> void:
	if not has_node("MapSprite2D"): return
	if not _material_duplicated and $MapSprite2D.material:
		$MapSprite2D.material = $MapSprite2D.material.duplicate()
		_material_duplicated = true
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
	update_team_palette()

func _own_inventory() -> void:
	var equipped_index := inventory.find(current_weapon)
	for i in inventory.size():
		if inventory[i] != null:
			inventory[i] = (inventory[i] as Item).duplicate() as Item
	if current_weapon == null:
		for item in inventory:
			if item is Weapon and can_equip(item):
				current_weapon = item
				break
	elif equipped_index >= 0:
		current_weapon = inventory[equipped_index] as Weapon
	elif not inventory.has(current_weapon):
		if inventory.size() < BAG_LIMIT:
			current_weapon = current_weapon.duplicate() as Weapon
			inventory.append(current_weapon)
		else:
			current_weapon = null

func restore_inventory(items: Array, equipped_index: int) -> void:
	for item in inventory.duplicate():
		remove_item(item)
	for item in items:
		add_item(item)
	# 恢复原顺序，不能调用会移到首位的手动换装接口。
	current_weapon = inventory[equipped_index] as Weapon if equipped_index >= 0 and equipped_index < inventory.size() else null

func use_item(item: Item) -> bool:
	var c := item as Consumable
	if c == null or not inventory.has(item):
		return false
	hp = mini(hp + c.heal_hp, max_hp)
	update_hp_bar()
	if c.consume_durability():
		inventory.erase(item)
	return true

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

func get_weapon_xp(type: int) -> int:
	if not can_use_weapon(type):
		return 0
	if not weapon_xp.has(type):
		weapon_xp[type] = Weapon.WEXP_THRESHOLDS[Weapon.WeaponRank.E]
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
	if weapon == null: return false
	if class_data == null: return true
	if not can_use_weapon(weapon.weapon_type): return false
	return get_weapon_ex(weapon.weapon_type) >= weapon.required_rank

func preview_with_weapon(weapon: Weapon) -> Unit:
	var preview := Unit.new()
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_STORAGE and property.name not in ["inventory", "current_weapon"]:
			var value: Variant = get(property.name)
			preview.set(property.name, value.duplicate() if value is Array or value is Dictionary else value)
	for item in inventory:
		preview.add_item(item)
	preview.equip_item(weapon)
	preview.cell = cell
	return preview

func gain_exp(amount: int) -> void:
	if lv < LEVEL_CAP:
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
