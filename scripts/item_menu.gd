extends Node
class_name ItemMenu

##"""物品菜单（阶段五 5D）：行动菜单选"物品"打开
##列出单位背包（5 槽 ItemRow），纯键盘操作：
##  ↑↓ 移动手光标（选中行高亮）
##  Z  消耗品=使用（回血扣耐久，结束行动）/ 武器=换装（不结束行动）
##  X  取消，回到行动菜单
##5F/UI 升级：背景用 scene/ui/itemsbox.tscn 九宫格，
##宽度按物品内容自适应（104 只是纹理原始宽度，不是固定面板宽），
##size.y 随背包物品数量动态调整（原版效果）；手光标 scene/ui/cursorhand.tscn 跟随选中行
##换装后 BattleManager 会重算攻击范围（武器射程可能变化）"""

signal closed
signal item_used

const ITEM_ROW_SCENE := preload("res://scene/ui/itemrow.tscn")
##手光标场景（与运输队面板同一实现模式）
const CURSOR_HAND_SCENE := preload("res://scene/ui/cursorhand.tscn")
##九宫格背景
const ITEMSBOX_SCENE := preload("res://scene/ui/itemsbox.tscn")
##背包槽位数（与 Unit 的 FE 上限 5 一致）
const BAG_SLOTS := 5
const ROW_HEIGHT := 16.0
##列表在面板内的起点（左侧留手光标位）
const LIST_OFFSET := Vector2(16, 13)
##换位时与屏幕左右边缘保留的间距（同行动菜单）
const PANEL_MARGIN := 2.0
##菜单纵向位置（屏幕固定高度，同行动菜单；面板过高时自动上移保持不出屏）
const MENU_Y := 56.0
##背景最小宽度（itemsbox 纹理的最小九宫格宽度）；实际宽度按物品内容自适应
const MIN_WIDTH := 48.0
##itemsbox 九宫格上下边距（patch_margin_top / patch_margin_bottom）
const PATCH_TOP := 13.0
const PATCH_BOTTOM := 14.0
##itemsbox 九宫格右边距（内容区右侧留白）
const PATCH_RIGHT := 13.0
##屏幕高度（GBA 240x160），面板底部不越界
const VIEW_HEIGHT := 160.0

const COLOR_SELECTED := Color(1, 0.95, 0.4)
const COLOR_NORMAL := Color(1, 1, 1)

##当前打开菜单的单位
var unit: Unit = null
##信息查看器（信息查看系统，Level 装配时注入；R 查看选中物品说明）
var info_viewer: Node = null
##当前选中项索引
var _index := 0
##当前面板宽度（open 时按物品内容自适应，update_side 换位用）
var _panel_width := MIN_WIDTH

var _panel: Control
var _bg: NinePatchRect
var _vbox: VBoxContainer
var _cursor: Control
var _rows: Array[ItemRow] = []


func _init() -> void:
	_build_panel()


##构建面板：Control 根 + itemsbox 九宫格背景 + VBox 列表 + 手光标
func _build_panel() -> void:
	_panel = Control.new()
	_panel.name = "Item Menu"
	_panel.visible = false

	_bg = ITEMSBOX_SCENE.instantiate()
	##解除 tscn 里的最小/最大尺寸限制，由代码控制大小
	##注意：Godot 4 的 custom_maximum_size "无限制"=(-1,-1)，(0,0) 是"上限 0×0"（会把背景钳没）
	_bg.custom_minimum_size = Vector2(0, 0)
	_bg.custom_maximum_size = Vector2(-1, -1)
	##锚点+偏移同时设置才能完整铺满根节点（仅设锚点会保留旧 offset）
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(_bg)

	_vbox = VBoxContainer.new()
	_vbox.position = LIST_OFFSET
	_vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(_vbox)
	for i in BAG_SLOTS:
		var row: ItemRow = ITEM_ROW_SCENE.instantiate()
		_vbox.add_child(row)
		_rows.append(row)

	##手光标（cursorhand.tscn，跟随选中行移动）
	_cursor = CURSOR_HAND_SCENE.instantiate()
	_panel.add_child(_cursor)

	##关键：面板必须挂到自身节点下，否则是孤儿节点
	##ItemMenu 进树时面板随之进树，ItemRow 的 @onready 才会生效（否则 _icon 为 null 导致 set_item 崩溃）
	add_child(_panel)


##打开菜单：先刷新列表（行内容决定宽度），再按物品数量/内容自适应面板尺寸
func open(p_unit: Unit) -> void:
	unit = p_unit
	_index = 0
	_refresh()
	_resize_panel()
	_panel.visible = true


##关闭菜单（信息查看中一并收起）
func close() -> void:
	if info_viewer != null and info_viewer.active:
		info_viewer.close()
	_panel.visible = false
	unit = null


##注入信息查看器（Level 装配）
func set_info_viewer(viewer: Node) -> void:
	info_viewer = viewer


##外部输入入口（由 BattleManager 转发）
func handle_input(event: InputEvent) -> void:
	##信息查看中：输入全部转给 InfoViewer（R/X 退出、方向键切换物品）
	if info_viewer != null and info_viewer.active:
		info_viewer.handle_input(event)
		return
	if not event.is_pressed() or unit == null:
		return
	if event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("yes"):
		_confirm()
	elif event.is_action_pressed("no"):
		close()
		closed.emit()
	elif event.is_action_pressed("R"):
		_open_info()


##==================== 信息查看（信息查看系统） ====================

##R 查看当前选中物品的说明（空背包不打开）
func _open_info() -> void:
	if info_viewer == null or unit == null or unit.inventory.is_empty():
		return
	info_viewer.open(_rows[_index], _nav_info)


##信息查看导航（本面板的导航规则）：上下=背包内移动物品光标；左右无切换
func _nav_info(dir: Vector2i) -> ItemRow:
	if dir.y != 0 and unit != null and not unit.inventory.is_empty():
		_move(dir.y)
		return _rows[_index]
	return null


##左右换位：单位在屏幕左半边时菜单放右侧，右半边时放左侧（同行动菜单）
func update_side(p_unit: Unit, p_camera: Camera2D) -> void:
	var view_width: float = _panel.get_viewport().get_visible_rect().size.x
	var screen_x: float = p_unit.global_position.x - p_camera.get_screen_center_position().x + view_width * 0.5
	if screen_x < view_width * 0.5:
		_panel.position.x = view_width - _panel_width - PANEL_MARGIN
	else:
		_panel.position.x = PANEL_MARGIN


##背景尺寸按物品内容自适应（原版效果）：
##宽度 = 手光标位 + 最宽物品行 + 右边距（不小于九宫格最小宽度 48，104 只是纹理原始宽度）
##高度 = 上边距 + 物品行数 + 下边距；面板过高时上移位置保证底部不出屏
func _resize_panel() -> void:
	var n := maxi(unit.inventory.size(), 1)
	var height := PATCH_TOP + n * ROW_HEIGHT + PATCH_BOTTOM
	var row_width := 0.0
	for i in mini(unit.inventory.size(), BAG_SLOTS):
		row_width = maxf(row_width, _rows[i].get_combined_minimum_size().x)
	_panel_width = maxf(LIST_OFFSET.x + row_width + PATCH_RIGHT, MIN_WIDTH)
	_panel.size = Vector2(_panel_width, height)
	_panel.position.y = minf(MENU_Y, VIEW_HEIGHT - height - 2.0)


##移动选择（空背包不动）
func _move(dir: int) -> void:
	if unit.inventory.is_empty():
		return
	_index = wrapi(_index + dir, 0, unit.inventory.size())
	_refresh()


##确认：消耗品使用 / 武器换装
func _confirm() -> void:
	if _index >= unit.inventory.size():
		return
	var item: Item = unit.inventory[_index]
	if item.is_consumable():
		##使用消耗品：由 Unit 结算（回血/扣耐久/耗尽移除），成功后通知 BattleManager 结束行动
		if unit.use_item(item):
			item_used.emit()
	elif item.is_weapon():
		##换装：通过 Unit.equip_item 保证 current_weapon 一定来自 inventory
		##武器等级不足时 equip_item 返回 false（升级系统），提示后不换装
		if not unit.equip_item(item):
			print("%s 武器等级不足，无法装备 %s" % [unit.unit_name, item.display_name])
		_refresh()


##刷新列表 / 手光标 / 选中高亮（多余行隐藏，背景随行数收缩）
func _refresh() -> void:
	_index = clampi(_index, 0, maxi(unit.inventory.size() - 1, 0))
	for i in BAG_SLOTS:
		var has_item: bool = i < unit.inventory.size() and unit.inventory[i] != null
		_rows[i].visible = has_item
		if has_item:
			_rows[i].set_item(unit.inventory[i])
		_rows[i].modulate = COLOR_SELECTED if i == _index else COLOR_NORMAL
	_cursor.visible = not unit.inventory.is_empty()
	_cursor.position = Vector2(0, LIST_OFFSET.y + _index * ROW_HEIGHT)
