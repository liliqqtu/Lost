extends Control
##人物信息面板（阶段五 5B）：光标停在单位上按 R 开关，左右键切页
##数据全部从 Unit/ClassData/Weapon 实时读取，面板不复制任何数据
class_name UnitInfoPanel

##能力值顺序：力/魔/技/速/幸/守/防/移（与能力条列顺序一致）
const STAT_KEYS := ["str", "mag", "skl", "spd", "luk", "def_h", "res", "move"]
##能力值标签节点名（与 STAT_KEYS 一一对应）
const STAT_LABEL_NAMES := ["Str", "Mag", "Skl", "Spd", "Luk", "Def H", "Res", "Move"]
##能力条的绝对满刻度
const BAR_MAX_VALUE := 40

##武器类型 -> 武器&支援等级页的类型图标（魔法/杖暂无图标，隐藏）
const WEAPON_TYPE_ICONS := {
	Weapon.WeaponType.SWORD: preload("res://assets/graphics/UI/ItemIconClass/sword.png"),
	Weapon.WeaponType.LANCE: preload("res://assets/graphics/UI/ItemIconClass/lance.png"),
	Weapon.WeaponType.AXE: preload("res://assets/graphics/UI/ItemIconClass/axe.png"),
	Weapon.WeaponType.BOW: preload("res://assets/graphics/UI/ItemIconClass/bow.png"),
	Weapon.WeaponType.ANIMA: preload("res://assets/graphics/UI/ItemIconClass/anima.png"),
	Weapon.WeaponType.LIGHT: preload("res://assets/graphics/UI/ItemIconClass/light.png"),
	Weapon.WeaponType.DARK: preload("res://assets/graphics/UI/ItemIconClass/dark.png"),
	Weapon.WeaponType.STAFF: preload("res://assets/graphics/UI/ItemIconClass/staff.png"),
}

##当前显示的页：0 角色信息 1 物品 2 武器&支援等级
var _page_index := 0
var _pages: Array[Control] = []
##当前显示的单位（上下键切换同队伍单位用）
var current_unit: Unit = null

@onready var _stat_labels: Array[Label] = [
	$InfoData/VBoxData1/Str,
	$InfoData/VBoxData1/Mag,
	$InfoData/VBoxData1/Skl,
	$InfoData/VBoxData1/Spd,
	$InfoData/VBoxData1/Luk,
	$InfoData/VBoxData1/Def_H,
	$InfoData/VBoxData1/Res,
	$InfoData/VBoxData1/Move,
]
#@onready var _max_stat_bars: Array[TextureProgressBar] = [
	#$InfoData/VBoxData1Bar/MAXStrBar,
	#$InfoData/VBoxData1Bar/MAXMagBar,
	#$InfoData/VBoxData1Bar/MAXSklBar,
	#$InfoData/VBoxData1Bar/MAXSpdBar,
	#$InfoData/VBoxData1Bar/MAXLukBar,
	#$InfoData/VBoxData1Bar/"MAXDef HBar",
	#$InfoData/VBoxData1Bar/MAXResBar,
	#$InfoData/VBoxData1Bar/MAXMoveBar,
#]
@onready var _stat_bars: Array[TextureProgressBar] = [
	$InfoData/VBoxData1Bar/StrBar,
	$InfoData/VBoxData1Bar/MagBar,
	$InfoData/VBoxData1Bar/SklBar,
	$InfoData/VBoxData1Bar/SpdBar,
	$InfoData/VBoxData1Bar/LukBar,
	$InfoData/VBoxData1Bar/Def_HBar,
	$InfoData/VBoxData1Bar/ResBar,
	$InfoData/VBoxData1Bar/MoveBar,
]
@onready var _con_label: Label = $InfoData/VBoxData2/Con
#@onready var _max_con_bar: TextureProgressBar = $InfoData/VBoxData1Bar2/MAXConBar
@onready var _con_bar: TextureProgressBar = $InfoData/VBoxData1Bar2/ConBar
@onready var _rescue_label: Label = $InfoData/VBoxData2/Rescue
@onready var _states_label: Label = $InfoData/VBoxData2/States
@onready var _cmd_label: Label = $InfoData/VBoxData2/Cmd
@onready var _talk_label: Label = $InfoData/VBoxData2/Talk
@onready var _skill_flow: HFlowContainer = $InfoData/Skill

@onready var _name_label: Label = $BaseInfo/Name
@onready var _class_label: Label = $BaseInfo/Class
@onready var _lv_label: Label = $BaseInfo/LV
@onready var _exp_label: Label = $BaseInfo/E
@onready var _hp_label: Label = $BaseInfo/HP
@onready var _max_hp_label: Label = $BaseInfo/MAXHP
@onready var _class_card: TextureRect = $ClassCard
@onready var _map_sprite: AnimatedSprite2D = $MapSprite2D
##属性图标（5G：ClassData.affinity.icon，无属性留空隐藏）
@onready var _affinity_icon: TextureRect = $BaseInfo/AffinityIcon
##支援列表容器与行模板（5G：Weapon&SupportLevel/SupportLevel，模板脱容器隐藏、填充时 duplicate）
@onready var _support_box: VBoxContainer = $"Weapon&SupportLevel/SupportLevel"
@onready var _support_row_template: HBoxContainer = $"Weapon&SupportLevel/SupportLevel/character"
##武器经验容器与模板（升级系统：WeaponClass 行 + WeaponLevel 等级字母，模板脱容器隐藏、填充时 duplicate）
@onready var _weapon_xp_box: HFlowContainer = $"Weapon&SupportLevel/WeaponXP"
@onready var _weapon_class_template: HBoxContainer = $"Weapon&SupportLevel/WeaponXP/WeaponClass"
@onready var _weapon_level_box: HFlowContainer = $"Weapon&SupportLevel/WeaponLevel"
@onready var _weapon_level_template: Label = $"Weapon&SupportLevel/WeaponLevel/Label"

@onready var _item_rows: Array[ItemRow] = [
	$Items/VBoxItems/itemrow,
	$Items/VBoxItems/itemrow2,
	$Items/VBoxItems/itemrow3,
	$Items/VBoxItems/itemrow4,
	$Items/VBoxItems/itemrow5,
]


func _ready() -> void:
	_pages = [$InfoData, $Items, $"Weapon&SupportLevel"]
	visible = false
	##支援行模板脱离容器并隐藏（避免空槽占布局；填充时 duplicate 生成真实行）
	_support_row_template.get_parent().remove_child(_support_row_template)
	_support_row_template.visible = false
	add_child(_support_row_template)
	##武器经验行/等级字母模板同样脱离容器隐藏（升级系统）
	_weapon_class_template.get_parent().remove_child(_weapon_class_template)
	_weapon_class_template.visible = false
	add_child(_weapon_class_template)
	_weapon_level_template.get_parent().remove_child(_weapon_level_template)
	_weapon_level_template.visible = false
	add_child(_weapon_level_template)


##显示面板并填充 unit 的当前数据（keep_page 为 true 时保持当前页，切换单位用）
func show_panel(unit: Unit, keep_page := false) -> void:
	current_unit = unit
	_fill(unit)
	if not keep_page:
		_page_index = 0
	_apply_page()
	visible = true


##关闭面板
func hide_panel() -> void:
	visible = false


##切页：dir -1 上一页 / 1 下一页，索引回绕
func cycle_page(dir: int) -> void:
	_page_index = wrapi(_page_index + dir, 0, _pages.size())
	_apply_page()


##只显示当前页
func _apply_page() -> void:
	for i in _pages.size():
		_pages[i].visible = i == _page_index


##填充全部数据（每次打开都重新读取，保证与 Unit 当前状态一致）
func _fill(unit: Unit) -> void:
	#基本信息
	_name_label.text = unit.unit_name
	_lv_label.text = str(unit.lv)
	_exp_label.text = str(unit.exp % 100)
	_hp_label.text = str(unit.hp)
	_max_hp_label.text = str(unit.max_hp)

	#职业名/职业卡/技能（ClassData）
	var cd: ClassData = unit.class_data
	if cd != null:
		_class_label.text = cd.job_name
		_class_card.texture = cd.class_card
	else:
		_class_label.text = "——"
		_class_card.texture = null

	#八项能力值
	for i in STAT_KEYS.size():
		var key: String = STAT_KEYS[i]
		_stat_labels[i].text = str(unit.get(key))
		_stat_bars[i].custom_maximum_size.x = _get_cap(unit, key)
		_stat_bars[i].value = unit.get(key)

	_con_label.text = str(unit.con)
	_con_bar.custom_maximum_size.x = _get_cap(unit, "con")
	_con_bar.value = unit.con

	#救出（5E 实现救援时填真值）/ 状态异常（未实现）/ 指挥⭐ / 对话对象
	_rescue_label.text = "——"
	_states_label.text = "——"
	_cmd_label.text = "%d⭐" % unit.cmd if unit.cmd > 0 else "——"
	_talk_label.text = unit.talk if unit.talk != "" else "——"

	_fill_skills(unit)
	_fill_map_sprite(unit)
	_fill_items(unit)
	_fill_affinity(unit)
	_fill_weapon_page(unit)
	_fill_support_list(unit)


##技能栏：合并职业技能 + 个人技能，按 Skill.view_scene 实例化（无 view_scene 跳过）
func _fill_skills(unit: Unit) -> void:
	for child in _skill_flow.get_children():
		child.queue_free()
	if unit.class_data == null and unit.personal_skills.is_empty():
		return
	var skills: Array[Skill] = []
	if unit.class_data != null:
		skills.append_array(unit.class_data.skills)
	skills.append_array(unit.personal_skills)
	for skill in skills:
		if skill == null or skill.view_scene == null:
			continue
		_skill_flow.add_child(skill.view_scene.instantiate())


##地图立绘：复制单位的地图精灵帧并播放选中动画
func _fill_map_sprite(unit: Unit) -> void:
	var src: AnimatedSprite2D = unit.get_node_or_null("MapSprite2D")
	if src == null or src.sprite_frames == null:
		return
	_map_sprite.sprite_frames = src.sprite_frames
	if _map_sprite.sprite_frames.has_animation("idle_selected"):
		_map_sprite.play("idle_selected")


##物品页：遍历 unit.inventory 填充 ItemRow；空槽位 clear() 隐藏
func _fill_items(unit: Unit) -> void:
	var items: Array[Item] = unit.inventory
	for i in _item_rows.size():
		var row: ItemRow = _item_rows[i]
		if i < items.size() and items[i] != null:
			row.set_item(items[i])
		else:
			row.clear()


##武器&支援等级页：按 ClassData 可用武器类型逐行显示（升级系统）
##WeaponXP/WeaponClass 行 = 类型图标 + 武器经验条（当前等级内的进度）
##WeaponLevel 行 = 对应武器等级字母 E..S（两个容器子节点一一对应）
##魔法/杖暂无类型图标（图标隐藏，经验条与等级照常显示）；无职业数据整页留空
func _fill_weapon_page(unit: Unit) -> void:
	for child in _weapon_xp_box.get_children():
		_weapon_xp_box.remove_child(child)
		child.queue_free()
	for child in _weapon_level_box.get_children():
		_weapon_level_box.remove_child(child)
		child.queue_free()
	var cd: ClassData = unit.class_data
	if cd == null:
		return
	for type in Weapon.WeaponType.values():
		if not cd.can_use_weapon(type):
			continue
		##武器经验行：图标 + 当前等级内进度条（到职业上限/S 级直接填满）
		var row: HBoxContainer = _weapon_class_template.duplicate()
		row.visible = true
		(row.get_node("Icon") as TextureRect).texture = WEAPON_TYPE_ICONS.get(type)
		var rank: int = unit.get_weapon_rank(type)
		var xp: int = unit.get_weapon_xp(type)
		var bar: TextureProgressBar = row.get_node("XP bar")
		if rank >= cd.get_weapon_rank(type) or rank >= Weapon.WeaponRank.S:
			bar.max_value = 1
			bar.value = 1
		else:
			var cur_t: int = Weapon.WEXP_THRESHOLDS[rank]
			var next_t: int = Weapon.WEXP_THRESHOLDS[rank + 1]
			bar.max_value = next_t - cur_t
			bar.value = clampi(xp - cur_t, 0, next_t - cur_t)
		_weapon_xp_box.add_child(row)
		##等级字母（与经验行一一对应）
		var lv_label: Label = _weapon_level_template.duplicate()
		lv_label.visible = true
		lv_label.text = Weapon.rank_to_text(rank)
		_weapon_level_box.add_child(lv_label)


##属性图标（5G）：ClassData.affinity，普通敌人无属性留空
func _fill_affinity(unit: Unit) -> void:
	var tex: Texture2D = null
	if unit.class_data != null and unit.class_data.affinity != null:
		tex = unit.class_data.affinity.icon
	_affinity_icon.texture = tex
	_affinity_icon.visible = tex != null


##支援列表（5G，Weapon&SupportLevel/SupportLevel）：每条支援一行
##icon=对方属性图标 / Name=对方名字 / Level=支援等级（未建立显示"——"）
func _fill_support_list(unit: Unit) -> void:
	for child in _support_box.get_children():
		_support_box.remove_child(child)
		child.queue_free()
	for info in SupportStore.get_supports_of(unit.unit_name):
		var row: HBoxContainer = _support_row_template.duplicate()
		row.visible = true
		var aff: Affinity = info["affinity"]
		(row.get_node("Icon") as TextureRect).texture = aff.icon if aff != null else null
		(row.get_node("Name") as Label).text = info["partner"]
		(row.get_node("Level") as Label).text = SupportStore.LEVEL_TEXT.get(info["level"], "——")
		_support_box.add_child(row)


##取能力上限：优先 ClassData，无职业数据时回落到 Unit 自身的 max_* 字段
func _get_cap(unit: Unit, key: String) -> int:
	if unit.class_data != null:
		return unit.class_data.get("cap_" + key)
	match key:
		"move":
			return 10
		"con":
			return 20
	return unit.get("max_" + key)
