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

##武器类型 -> 武器等级页的类型图标（魔法/杖暂无图标，隐藏）
const WEAPON_TYPE_ICONS := {
	Weapon.WeaponType.SWORD: preload("res://assets/graphics/UI/ItemIconClass/sword.png"), Weapon.WeaponType.LANCE: preload("res://assets/graphics/UI/ItemIconClass/lance.png"),
	Weapon.WeaponType.AXE: preload("res://assets/graphics/UI/ItemIconClass/axe.png"), Weapon.WeaponType.BOW: preload("res://assets/graphics/UI/ItemIconClass/bow.png"),
	Weapon.WeaponType.ANIMA: preload("res://assets/graphics/UI/ItemIconClass/anima.png"), Weapon.WeaponType.LIGHT: preload("res://assets/graphics/UI/ItemIconClass/light.png"),
	Weapon.WeaponType.DARK: preload("res://assets/graphics/UI/ItemIconClass/dark.png"), Weapon.WeaponType.STAFF: preload("res://assets/graphics/UI/ItemIconClass/staff.png"),
}

##武器类型 -> 中文名（信息查看用）
const WEAPON_TYPE_NAMES := {
	Weapon.WeaponType.SWORD: "剑", Weapon.WeaponType.LANCE: "枪",
	Weapon.WeaponType.AXE: "斧", Weapon.WeaponType.BOW: "弓",
	Weapon.WeaponType.ANIMA: "理（魔法）", Weapon.WeaponType.DARK: "暗（魔法）",
	Weapon.WeaponType.LIGHT: "光（魔法）", Weapon.WeaponType.STAFF: "杖",
}

##武器类型说明（信息查看用：三角相克等）
const WEAPON_TYPE_INFO := {
	Weapon.WeaponType.SWORD: "物理武器。克制斧，被枪克制。",
	Weapon.WeaponType.LANCE: "物理武器。克制剑，被斧克制。",
	Weapon.WeaponType.AXE: "物理武器。克制枪，被剑克制。",
	Weapon.WeaponType.BOW: "物理武器。基础射程 2，近距离无法反击。",
	Weapon.WeaponType.ANIMA: "魔法。克制光，被暗克制。",
	Weapon.WeaponType.DARK: "魔法。克制理，被光克制。",
	Weapon.WeaponType.LIGHT: "魔法。克制暗，被理克制。",
	Weapon.WeaponType.STAFF: "辅助武器（治疗等，效果未实现）。",
}

##手光标场景（光标跟随当前查看项，5F/UI 升级）
const CURSOR_HAND_SCENE := preload("res://scene/ui/cursorhand.tscn")
const FLAT_STYLE := preload("res://data/test_style_box_flat.tres")

##静态信息提供者节点路径（顺序即角色页导航顺序）
const STATIC_INFO_PATHS := [
	"BaseInfo/Info", "BaseInfo/Name", "BaseInfo/Class", "BaseInfo/LV", "BaseInfo/Exp",
	"BaseInfo/HP", "BaseInfo/AffinityIcon",
	"InfoData/VBoxData1/Str", "InfoData/VBoxData1/Mag", "InfoData/VBoxData1/Skl",
	"InfoData/VBoxData1/Spd", "InfoData/VBoxData1/Luk", "InfoData/VBoxData1/Def_H",
	"InfoData/VBoxData1/Res", "InfoData/VBoxData1/Move",
	"InfoData/VBoxData2/Con", "InfoData/VBoxData2/Rescue", "InfoData/VBoxData2/States",
	"InfoData/VBoxData2/Cmd", "InfoData/VBoxData2/Talk","InfoData/SkillInfo"
]

##当前显示的页：0 角色信息 1 物品 2 武器&支援等级
var _page_index := 0
var _pages: Array[Control] = []
##当前显示的单位（上下键切换同队伍单位用）
var current_unit: Unit = null

##信息查看器（信息查看系统，Level 装配时注入；R 查看当前页条目说明）
var info_viewer: Node = null
##信息查看：当前条目索引（按页面维护，R 打开时从该条目起）
var _info_index := 0
##手光标实例（信息查看中跟随当前聚焦项）
var _cursor: Control = null
##静态信息提供者（tscn 中挂在各 Label 下的 Info 子节点，_ready 收集）
var _static_providers: Array = []
##技能说明（动态：随当前单位的技能列表变化，追加在角色页末尾）
var _skill_providers: Array = []
## 角色信息面板的说明
var info_list: Array = []
## 物品栏的说明
var item_list: Array = []
##武器类型说明（动态：随当前单位 rank_* 变化，武器&支援页按此导航）
var _weapon_providers: Array = []

@onready var _stat_labels: Array[InfoProvider] = [
	$InfoData/VBoxData1/Str, $InfoData/VBoxData1/Mag, $InfoData/VBoxData1/Skl, $InfoData/VBoxData1/Spd,
	$InfoData/VBoxData1/Luk, $InfoData/VBoxData1/Def_H, $InfoData/VBoxData1/Res, $InfoData/VBoxData1/Move,
]
@onready var _stat_bars: Array[TextureProgressBar] = [
	$InfoData/VBoxData1Bar/StrBar, $InfoData/VBoxData1Bar/MagBar, $InfoData/VBoxData1Bar/SklBar, $InfoData/VBoxData1Bar/SpdBar,
	$InfoData/VBoxData1Bar/LukBar, $InfoData/VBoxData1Bar/Def_HBar, $InfoData/VBoxData1Bar/ResBar, $InfoData/VBoxData1Bar/MoveBar,
]
@onready var _con_label: InfoProvider = $InfoData/VBoxData2/Con
@onready var _con_bar: TextureProgressBar = $InfoData/VBoxData1Bar2/ConBar
@onready var _rescue_label: InfoProvider = $InfoData/VBoxData2/Rescue
@onready var _states_label: InfoProvider = $InfoData/VBoxData2/States
@onready var _cmd_label: InfoProvider = $InfoData/VBoxData2/Cmd
@onready var _talk_label: InfoProvider = $InfoData/VBoxData2/Talk
@onready var _skillinfo: InfoProvider = $InfoData/SkillInfo
@onready var _skill_flow: HFlowContainer = $InfoData/Skill

@onready var _name: InfoProvider = $BaseInfo/Name
@onready var _class: InfoProvider = $BaseInfo/Class
@onready var _lv: InfoProvider = $BaseInfo/LV
@onready var _exp: InfoProvider = $BaseInfo/Exp
@onready var _hp: InfoProvider = $BaseInfo/HP
@onready var _max_hp: Label = $BaseInfo/MAXHP
@onready var _class_card: TextureRect = $BaseInfo/ClassCard
@onready var _map_sprite: AnimatedSprite2D = $BaseInfo/MapSprite2D
##属性图标（5G：ClassData.affinity.icon，无属性留空隐藏）
@onready var _affinity_icon: InfoProvider = $BaseInfo/AffinityIcon
##支援列表容器与行模板（5G：Weapon&SupportLevel/SupportLevel，模板脱容器隐藏、填充时 duplicate）
@onready var _support_box: VBoxContainer = $"Weapon&SupportLevel/SupportLevel"
@onready var _support_row_template: HBoxContainer = $"Weapon&SupportLevel/SupportLevel/character"
##武器经验容器与模板（升级系统：WeaponClass 行 + WeaponLevel 等级字母，模板脱容器隐藏、填充时 duplicate）
@onready var _weapon_xp_box: HFlowContainer = $"Weapon&SupportLevel/WeaponXP"
@onready var _weapon_class_template: HBoxContainer = $"Weapon&SupportLevel/WeaponXP/WeaponClass"
@onready var _weapon_level_box: HFlowContainer = $"Weapon&SupportLevel/WeaponLevel"
@onready var _weapon_level_template: Label = $"Weapon&SupportLevel/WeaponLevel/Label"

@onready var _item_rows: Array[ItemRow] = [
	$Items/VBoxItems/itemrow, $Items/VBoxItems/itemrow2, $Items/VBoxItems/itemrow3,
	$Items/VBoxItems/itemrow4, $Items/VBoxItems/itemrow5,
]


func _ready() -> void:
	_pages = [$InfoData, $Items, $"Weapon&SupportLevel"]
	visible = false
	## 手光标（cursorhand.tscn，信息查看时跟随当前项）
	_cursor = CURSOR_HAND_SCENE.instantiate()
	_cursor.name = "Cursor"
	_cursor.visible = false
	add_child(_cursor)
	move_child(_cursor, -1)
	##收集静态信息提供者（tscn 中挂在各 Label 下的 Info 子节点，缺节点自动跳过）
	for path in STATIC_INFO_PATHS:
		var node := get_node_or_null(path)
		if node != null:
			_static_providers.append(node)
		else :
			print(path)

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
	if _cursor != null:
		_cursor.visible = false
	##信息查看条目从头开始
	_info_index = 0


##关闭面板（信息查看中一并收起）
func hide_panel() -> void:
	if _cursor != null:
		_cursor.visible = false
	if info_viewer != null and info_viewer.active:
		info_viewer.close()
	visible = false


##注入信息查看器（Level 装配）
func set_info_viewer(viewer: Node) -> void:
	info_viewer = viewer
	if info_viewer != null:
		if not info_viewer.focused_changed.is_connected(_on_info_focused):
			info_viewer.focused_changed.connect(_on_info_focused)
		if not info_viewer.viewer_closed.is_connected(_on_info_closed):
			info_viewer.viewer_closed.connect(_on_info_closed)

func _on_info_focused(target: Control) -> void:
	_update_cursor(target)

func _on_info_closed() -> void:
	if _cursor != null:
		_cursor.visible = false

##更新手光标位置：紧贴目标左侧居中；支持 InfoProvider 自定义 cursor_offset
func _update_cursor(target: Control) -> void:
	if _cursor == null or target == null:
		return
	_cursor.visible = true
	var offset := Vector2(-12.0, (target.size.y - 16.0) / 2.0)
	if target is InfoProvider and (target as InfoProvider).cursor_offset != Vector2.ZERO:
		offset = (target as InfoProvider).cursor_offset
	var pos := target.global_position + offset
	pos.x = maxf(pos.x, 0.0)
	_cursor.global_position = pos

##切页：dir -1 上一页 / 1 下一页，索引回绕
func cycle_page(dir: int) -> void:
	if _cursor != null:
		_cursor.visible = false
	if info_viewer != null and info_viewer.active:
		info_viewer.close()
	_page_index = wrapi(_page_index + dir, 0, _pages.size())
	_apply_page()

##只显示当前页
func _apply_page() -> void:
	for i in _pages.size():
		_pages[i].visible = i == _page_index

##填充全部数据（每次打开都重新读取，保证与 Unit 当前状态一致）
func _fill(unit: Unit) -> void:
	#基本信息
	_name.text = unit.unit_name
	_name.description = unit.info
	_lv.text = str(unit.lv)
	_exp.text = str(unit.exp % 100)
	_hp.text = str(unit.hp)
	_max_hp.text = str(unit.max_hp)

	#职业名/职业卡/技能（ClassData）
	var cd: ClassData = unit.class_data
	if cd != null:
		_class.text = cd.job_name
		_class.description = cd.job_info
		_class_card.texture = cd.class_card
	else:
		_class.text = "——"
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
	#信息查看：静态 + 技能
	if not _static_providers.is_empty():
		info_list = _static_providers.duplicate()
		info_list.append_array(_skill_providers)
	for info in info_list:
		if info_viewer != null:
			var callable: Callable = info_viewer._on_button_focus_entered.bind(info)
			if not info.focus_entered.is_connected(callable):
				info.focus_entered.connect(callable)


##技能栏：合并职业技能 + 个人技能，动态创建 InfoProvider 并编排 3x2 网格焦点
func _fill_skills(unit: Unit) -> void:
	for child in _skill_flow.get_children():
		child.queue_free()
	_skill_providers.clear()
	if unit.class_data == null and unit.personal_skills.is_empty():
		_link_skill_focus([])
		return
	var skills: Array[Skill] = []
	if unit.class_data != null:
		skills.append_array(unit.class_data.skills)
	skills.append_array(unit.personal_skills)
	for skill in skills:
		if skill == null:
			continue
		var provider := _create_info_provider(
			Vector2(16, 16),
			"技能：%s\n%s" % [skill.display_name, skill.description],
			Vector2(-120, -50),
			Vector2(-12, 0)
		)
		provider.icon = skill.icon
		_skill_flow.add_child(provider)
		_skill_providers.append(provider)
	_link_skill_focus(_skill_providers)


##技能焦点连接：3列网格，上接 Talk，左接 Res / Move
func _link_skill_focus(skill_items: Array) -> void:
	_link_grid_focus(skill_items, 3, _skillinfo, null, [_stat_labels[6], _stat_labels[7]])
	if skill_items.is_empty():
		_skillinfo.focus_neighbor_bottom = _stat_labels[7].get_path()
		_stat_labels[6].focus_neighbor_right = _skillinfo.get_path()
		_stat_labels[7].focus_neighbor_right = _skillinfo.get_path()
	else:
		_skillinfo.focus_neighbor_bottom = skill_items[0].get_path()
		_stat_labels[6].focus_neighbor_right = skill_items[0].get_path()
		_stat_labels[7].focus_neighbor_right = skill_items[mini(3, skill_items.size() - 1)].get_path()


##通用 2D 网格焦点编排函数：将 items 列表排成 cols 列，自动连接内部上下左右与边界
func _link_grid_focus(items: Array, cols: int, top_b: Node = null, bottom_b: Node = null, left_b: Array = [], right_b: Array = []) -> void:
	var count := items.size()
	for i in count:
		var item := items[i] as InfoProvider
		var r := i / cols
		var c := i % cols
		item.focus_neighbor_top = items[i - cols].get_path() if r > 0 else (top_b.get_path() if top_b != null else item.get_path())
		item.focus_neighbor_bottom = items[i + cols].get_path() if i + cols < count else (bottom_b.get_path() if bottom_b != null else item.get_path())
		var lb = left_b[mini(r, left_b.size() - 1)] if not left_b.is_empty() else null
		item.focus_neighbor_left = items[i - 1].get_path() if c > 0 else (lb.get_path() if lb != null else item.get_path())
		var rb = right_b[mini(r, right_b.size() - 1)] if not right_b.is_empty() else null
		item.focus_neighbor_right = items[i + 1].get_path() if (c < cols - 1 and i + 1 < count) else (rb.get_path() if rb != null else item.get_path())


##快速构造透明焦点 InfoProvider 按钮
func _create_info_provider(size: Vector2, desc: String, info_pos: Vector2, cursor_off: Vector2) -> InfoProvider:
	var p := InfoProvider.new()
	p.custom_minimum_size = size
	p.flat = true
	p.description = desc
	p.info_position = info_pos
	p.cursor_offset = cursor_off
	p.expand_icon = true
	p.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	for state in ["focus", "normal", "hover", "pressed", "disabled"]:
		p.add_theme_stylebox_override(state, FLAT_STYLE)
	return p


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
	item_list.clear()
	for i in _item_rows.size():
		var row: ItemRow = _item_rows[i]
		if i < items.size() and items[i] != null:
			row.set_item(items[i])
		else:
			row.clear()
	for row in _item_rows:
		if row.visible:
			item_list.append(row)


##武器&支援等级页：按 Unit rank_* 可用武器类型逐行显示（升级系统）
func _fill_weapon_page(unit: Unit) -> void:
	for child in _weapon_xp_box.get_children():
		_weapon_xp_box.remove_child(child)
		child.queue_free()
	for child in _weapon_level_box.get_children():
		_weapon_level_box.remove_child(child)
		child.queue_free()
	_weapon_providers.clear()
	for type in Weapon.WeaponType.values():
		if not unit.can_use_weapon(type):
			continue
		##武器经验行：图标 + 当前等级内进度条
		var row: HBoxContainer = _weapon_class_template.duplicate()
		row.visible = true
		var icon_rect: TextureRect = row.get_node("Icon")
		icon_rect.texture = WEAPON_TYPE_ICONS.get(type)
		var rank: int = unit.get_weapon_ex(type)
		var cap: int = unit.get_weapon_rank(type)
		var xp: int = unit.get_weapon_xp(type)
		var bar: TextureProgressBar = row.get_node("XP bar")
		if rank >= Weapon.WeaponRank.S or rank >= cap:
			bar.max_value = 1
			bar.value = 1
		else:
			var cur_t: int = Weapon.WEXP_THRESHOLDS[rank]
			var next_t: int = Weapon.WEXP_THRESHOLDS[rank + 1]
			bar.max_value = next_t - cur_t
			bar.value = clampi(xp - cur_t, 0, next_t - cur_t)

		##信息查看提供者挂在 Icon 上（覆盖 Button），位置与图标重合
		var weapon_idx := _weapon_providers.size()
		var desc := "%s 等级 %s（上限 %s） 经验 %d\n%s" % [
			WEAPON_TYPE_NAMES.get(type, "武器"),
			Weapon.rank_to_text(rank), Weapon.rank_to_text(cap), xp,
			WEAPON_TYPE_INFO.get(type, ""),
		]
		var provider := _create_info_provider(
			Vector2(16, 16), desc,
			Vector2(-40, 20 if weapon_idx < 2 else -40),
			Vector2(-12, 0)
		)
		provider.name = "Info"
		icon_rect.add_child(provider)
		_weapon_providers.append(provider)
		_weapon_xp_box.add_child(row)

		##等级字母（与经验行一一对应）
		var lv_label: Label = _weapon_level_template.duplicate()
		lv_label.visible = true
		lv_label.text = Weapon.WeaponRank.find_key(rank)
		_weapon_level_box.add_child(lv_label)

	##编排武器等级 2x2 网格焦点
	_link_grid_focus(_weapon_providers, 2)
	for wp in _weapon_providers:
		if info_viewer != null:
			var callable: Callable = info_viewer._on_button_focus_entered.bind(wp)
			if not wp.focus_entered.is_connected(callable):
				wp.focus_entered.connect(callable)


##属性图标（5G）：ClassData.affinity，普通敌人无属性留空
func _fill_affinity(unit: Unit) -> void:
	var tex: Texture2D = null
	if unit.class_data != null and unit.class_data.affinity != null:
		tex = unit.class_data.affinity.icon
	_affinity_icon.icon = tex
	_affinity_icon.visible = tex != null


##支援列表（5G，Weapon&SupportLevel/SupportLevel）：每条支援一行
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
	return 10 if key == "move" else (20 if key == "con" else unit.get("max_" + key))

##==================== 信息查看（信息查看系统） ====================

##信息查看输入（由 BattleUnitCommands.handle_unit_info_input 最先调用）
func handle_info_input(event: InputEvent) -> bool:
	if info_viewer == null:
		return false
	if info_viewer.active:
		info_viewer.handle_input(event)
		return true
	if event.is_action_pressed("R"):
		var providers := _page_providers(_page_index)
		if providers.is_empty():
			return false
		_info_index = clampi(_info_index, 0, providers.size() - 1)
		if info_viewer.open(providers[_info_index], _nav_info):
			return true
	return false

##信息查看导航（本面板的导航规则，InfoViewer 只透传方向）
func _nav_info(dir: Vector2i) -> Node:
	var providers := _page_providers(_page_index)
	if dir.y != 0 and not providers.is_empty():
		_info_index = wrapi(_info_index + dir.y, 0, providers.size())
		return providers[_info_index]
	return null

##当前页的可查看对象列表
func _page_providers(page: int) -> Array:
	match page:
		0: return info_list
		1: return item_list
		2: return _weapon_providers
	return []
