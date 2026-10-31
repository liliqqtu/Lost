class_name WeaponSelectMenu extends Control

##"""战斗前武器选择界面（复刻 GBA 火焰纹章）：
##在行动菜单选择“攻击”后、进入目标选择之前弹出。
##左上角：当前角色可用武器列表，带手光标与耐久显示；
##右下角：当前候选武器下的战斗属性预览（攻击/必杀/命中/回避），带升降提示。
##操作：
##  ↑↓ 切换武器并实时刷新右下角属性
##  Z  确认武器 -> 装备该武器（移至首位）并进入目标选择
##  X  取消 -> 返回行动菜单"""

signal weapon_confirmed(weapon: Weapon)
signal cancelled

const ITEMSBOX_SCENE := preload("res://scene/ui/itemsbox.tscn")
const CURSOR_HAND_SCENE := preload("res://scene/ui/cursorhand.tscn")
const ITEM_ROW_SCENE := preload("res://scene/ui/itemrow.tscn")

const COLOR_NORMAL := Color(1, 1, 1)
const COLOR_DISABLED := Color(0.5, 0.5, 0.5)
const COLOR_LABEL := Color(0.9, 0.85, 0.6)
const COLOR_UP := Color(0.3, 0.8, 1.0)
const COLOR_DOWN := Color(1.0, 0.4, 0.3)

var unit: Unit = null
var tile_map: TileMapLayer = null
var all_units: Array = []
var weapons: Array[Weapon] = []
var _index := 0
var _orig_stats: Dictionary = {}

var _weapons_panel: Control
var _weapons_bg: NinePatchRect
var _vbox: VBoxContainer
var _cursor: Control
var _rows: Array[ItemRow] = []

var _stats_panel: Control
var _stats_bg: NinePatchRect
var _unit_name_label: Label
var _weapon_icon_rect: TextureRect
var _atk_val_label: Label
var _atk_arrow: StatArrow
var _crit_val_label: Label
var _crit_arrow: StatArrow
var _hit_val_label: Label
var _hit_arrow: StatArrow
var _avoid_val_label: Label
var _avoid_arrow: StatArrow


func _init() -> void:
	name = "WeaponSelectMenu"
	visible = false
	_build_ui()


func _build_ui() -> void:
	## 1. 左上角武器列表面板
	_weapons_panel = Control.new()
	_weapons_panel.position = Vector2(8, 8)
	_weapons_panel.size = Vector2(136, 60)

	_weapons_bg = ITEMSBOX_SCENE.instantiate()
	_weapons_bg.custom_minimum_size = Vector2(0, 0)
	_weapons_bg.custom_maximum_size = Vector2(-1, -1)
	_weapons_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_weapons_panel.add_child(_weapons_bg)

	_vbox = VBoxContainer.new()
	_vbox.position = Vector2(16, 12)
	_vbox.add_theme_constant_override("separation", 0)
	_weapons_panel.add_child(_vbox)

	for i in 5:
		var row: ItemRow = ITEM_ROW_SCENE.instantiate()
		_vbox.add_child(row)
		_rows.append(row)

	_cursor = CURSOR_HAND_SCENE.instantiate()
	_weapons_panel.add_child(_cursor)
	add_child(_weapons_panel)

	## 2. 右下角战斗属性预览面板
	_stats_panel = Control.new()
	_stats_panel.position = Vector2(118, 96)
	_stats_panel.size = Vector2(116, 56)

	_stats_bg = ITEMSBOX_SCENE.instantiate()
	_stats_bg.custom_minimum_size = Vector2(0, 0)
	_stats_bg.custom_maximum_size = Vector2(-1, -1)
	_stats_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stats_panel.add_child(_stats_bg)

	_unit_name_label = _make_label(Vector2(12, 6), Vector2(50, 14), COLOR_NORMAL)
	_stats_panel.add_child(_unit_name_label)

	_weapon_icon_rect = TextureRect.new()
	_weapon_icon_rect.position = Vector2(86, 5)
	_weapon_icon_rect.size = Vector2(16, 16)
	_weapon_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_stats_panel.add_child(_weapon_icon_rect)

	# 攻击 & 必杀
	_stats_panel.add_child(_make_label(Vector2(10, 22), Vector2(24, 14), COLOR_LABEL, "攻击"))
	_atk_val_label = _make_label(Vector2(32, 22), Vector2(18, 14), COLOR_NORMAL)
	_stats_panel.add_child(_atk_val_label)
	_atk_arrow = StatArrow.new()
	_atk_arrow.set_base_pos(Vector2(48, 24))
	_stats_panel.add_child(_atk_arrow)

	_stats_panel.add_child(_make_label(Vector2(64, 22), Vector2(24, 14), COLOR_LABEL, "必杀"))
	_crit_val_label = _make_label(Vector2(84, 22), Vector2(18, 14), COLOR_NORMAL)
	_stats_panel.add_child(_crit_val_label)
	_crit_arrow = StatArrow.new()
	_crit_arrow.set_base_pos(Vector2(97, 24))
	_stats_panel.add_child(_crit_arrow)

	# 命中 & 回避
	_stats_panel.add_child(_make_label(Vector2(10, 38), Vector2(24, 14), COLOR_LABEL, "命中"))
	_hit_val_label = _make_label(Vector2(30, 38), Vector2(20, 14), COLOR_NORMAL)
	_stats_panel.add_child(_hit_val_label)
	_hit_arrow = StatArrow.new()
	_hit_arrow.set_base_pos(Vector2(48, 40))
	_stats_panel.add_child(_hit_arrow)

	_stats_panel.add_child(_make_label(Vector2(64, 38), Vector2(24, 14), COLOR_LABEL, "回避"))
	_avoid_val_label = _make_label(Vector2(84, 38), Vector2(18, 14), COLOR_NORMAL)
	_stats_panel.add_child(_avoid_val_label)
	_avoid_arrow = StatArrow.new()
	_avoid_arrow.set_base_pos(Vector2(97, 40))
	_stats_panel.add_child(_avoid_arrow)

	add_child(_stats_panel)


func _make_label(pos: Vector2, sz: Vector2, col: Color, text_content: String = "") -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.text = text_content
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 2)
	return l


func open(p_unit: Unit, p_tile_map: TileMapLayer, p_units: Array) -> void:
	unit = p_unit
	tile_map = p_tile_map
	all_units = p_units
	weapons.clear()
	for it in unit.inventory:
		if it is Weapon:
			weapons.append(it)

	if unit.current_weapon != null and weapons.has(unit.current_weapon):
		_index = weapons.find(unit.current_weapon)
	else:
		_index = 0

	_orig_stats = _calc_stats_for_weapon(unit.current_weapon if unit.current_weapon != null else (weapons[0] if not weapons.is_empty() else null))
	_refresh_list()
	visible = true


func close() -> void:
	visible = false


func handle_input(event: InputEvent) -> void:
	if weapons.is_empty():
		cancelled.emit()
		return
	if event.is_action_pressed("ui_up"):
		_cycle_index(-1)
	elif event.is_action_pressed("ui_down"):
		_cycle_index(1)
	elif event.is_action_pressed("yes"):
		_confirm()
	elif event.is_action_pressed("no"):
		cancelled.emit()


func _cycle_index(dir: int) -> void:
	if weapons.is_empty():
		return
	_index = wrapi(_index + dir, 0, weapons.size())
	_cursor.position = Vector2(0, 12 + _index * 16)
	_update_preview_stats()


func _confirm() -> void:
	if _index < 0 or _index >= weapons.size():
		return
	var selected_weapon := weapons[_index]
	if not _can_weapon_attack(selected_weapon):
		print("该武器无法攻击任何目标！")
		return
	weapon_confirmed.emit(selected_weapon)


func _refresh_list() -> void:
	_weapons_panel.size.y = 12 + weapons.size() * 16 + 12
	_cursor.position = Vector2(0, 12 + _index * 16)
	for i in 5:
		if i < weapons.size():
			var w := weapons[i]
			_rows[i].visible = true
			_rows[i].set_item(w)
			var can_atk := _can_weapon_attack(w)
			_set_row_color(_rows[i], COLOR_NORMAL if can_atk else COLOR_DISABLED)
		else:
			_rows[i].visible = false
	_update_preview_stats()


func _set_row_color(row: ItemRow, col: Color) -> void:
	var name_lbl = row.get_node_or_null("ItemName") as Label
	var dur_lbl = row.get_node_or_null("ItemDurability") as Label
	var icon_rect = row.get_node_or_null("ItemIcon") as TextureRect
	if name_lbl: name_lbl.add_theme_color_override("font_color", col)
	if dur_lbl: dur_lbl.add_theme_color_override("font_color", col)
	if icon_rect: icon_rect.modulate = Color(1, 1, 1, 1) if col == COLOR_NORMAL else Color(0.6, 0.6, 0.6, 0.8)


func _can_weapon_attack(w: Weapon) -> bool:
	if w == null or w.durability <= 0:
		return false
	if not unit.can_equip(w):
		return false
	return not get_targets_for_weapon(w).is_empty()


func get_targets_for_weapon(w: Weapon) -> Array[Unit]:
	var result: Array[Unit] = []
	if w == null or unit == null:
		return result
	var min_delta := 0
	var max_delta := 0
	for s in unit._all_skills():
		min_delta += s.min_range_delta
		max_delta += s.max_range_delta
	var r_min: int = maxi(1, w.min_range + min_delta)
	var r_max: int = maxi(1, w.max_range + max_delta)
	for u in all_units:
		if u != null and u is Unit and u.team != unit.team and u.carried_by == null:
			var d: int = absi(unit.cell.x - u.cell.x) + absi(unit.cell.y - u.cell.y)
			if d >= r_min and d <= r_max:
				result.append(u)
	return result


func _update_preview_stats() -> void:
	if _index < 0 or _index >= weapons.size():
		return
	var w := weapons[_index]
	var stats := _calc_stats_for_weapon(w)
	_unit_name_label.text = unit.unit_name
	_weapon_icon_rect.texture = w.icon

	_atk_val_label.text = str(stats["atk"])
	_crit_val_label.text = str(stats["crit"])
	_hit_val_label.text = str(stats["hit"])
	_avoid_val_label.text = str(stats["avoid"])

	_atk_arrow.set_comparison(stats["atk"], _orig_stats.get("atk", stats["atk"]))
	_crit_arrow.set_comparison(stats["crit"], _orig_stats.get("crit", stats["crit"]))
	_hit_arrow.set_comparison(stats["hit"], _orig_stats.get("hit", stats["hit"]))
	_avoid_arrow.set_comparison(stats["avoid"], _orig_stats.get("avoid", stats["avoid"]))


func _calc_stats_for_weapon(w: Weapon) -> Dictionary:
	if w == null or unit == null:
		return {"atk": 0, "crit": 0, "hit": 0, "avoid": 0}
	var is_magic := w.weapon_type == Weapon.WeaponType.ANIMA or w.weapon_type == Weapon.WeaponType.DARK or w.weapon_type == Weapon.WeaponType.LIGHT

	var cur_w := unit.current_weapon
	var cur_stat_bonus := func(stat_k: String) -> int:
		return cur_w.get_stat_bonus(stat_k) if (cur_w != null and cur_w != w) else 0
	var new_stat_bonus := func(stat_k: String) -> int:
		return w.get_stat_bonus(stat_k) if (cur_w != w) else 0

	var str_val: int = (unit.get_effective_mag(all_units) if is_magic else unit.get_effective_str(all_units)) - cur_stat_bonus.call("mag" if is_magic else "str") + new_stat_bonus.call("mag" if is_magic else "str")
	var atk: int = str_val + w.might

	var skl_val: int = unit.get_effective_skl(all_units) - cur_stat_bonus.call("skl") + new_stat_bonus.call("skl")
	var luk_val: int = unit.get_effective_luk(all_units) - cur_stat_bonus.call("luk") + new_stat_bonus.call("luk")
	var spd_val: int = unit.get_effective_spd(all_units) - cur_stat_bonus.call("spd") + new_stat_bonus.call("spd")
	var con_val: int = unit.get_effective_con(all_units) - cur_stat_bonus.call("con") + new_stat_bonus.call("con")

	var support: Dictionary = SupportStore.get_support_bonus(unit, all_units)
	var crit: int = w.crit + skl_val / 2 + (support.get("crit", 0) as int)
	var hit: int = w.hit + skl_val * 2 + luk_val / 2 + (support.get("hit", 0) as int)

	var as_val: int = spd_val - maxi(0, w.weight - con_val)
	var terrain_avoid: int = 0
	if tile_map != null and unit != null:
		var t_name: String = Pathfinder.get_terrain_name(tile_map, unit.cell)
		terrain_avoid = Global.get_terrain_bonus(t_name)["avoid"]
	var avoid: int = as_val * 2 + luk_val + terrain_avoid + (support.get("avoid", 0) as int)

	return {
		"atk": atk,
		"crit": max(0, crit),
		"hit": hit,
		"avoid": max(0, avoid),
	}
