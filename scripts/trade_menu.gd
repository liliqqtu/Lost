extends Node
class_name TradeMenu

##交换界面（阶段五 5F）：左右两侧各显示一方的物品栏 + 上方 class card
##卡片底部被物品栏遮挡（FE 原版交换界面的处理方式，物品栏贴屏幕底边）
##FE GBA 交互规则：
##  ↑↓   移动手光标（可停在空槽位上）
##  ←→   切换操作侧
##  Z    未拾取=拾取当前物品（光标跳到另一侧）/ 已拾取=放到目标行：
##       目标行有物品=交换、空槽位=转移到对方背包末尾、同侧=调换位置（整理背包）
##  X    已拾取=放回取消拾取 / 未拾取=关闭交换界面
##交换不消耗行动；装备中的武器被换走则卸下（current_weapon 置空），
##关闭后由 BattleManager 重算攻击范围并回到行动菜单
signal closed

const ITEM_ROW_SCENE := preload("res://scene/ui/itemrow.tscn")
##手光标场景（与物品栏/行动菜单同一实现模式）
const CURSOR_HAND_SCENE := preload("res://scene/ui/cursorhand.tscn")
##九宫格背景
const ITEMSBOX_SCENE := preload("res://scene/ui/itemsbox.tscn")
##背包槽位数（与 Unit 的 FE 上限 5 一致）
const BAG_SLOTS := 5
const ROW_HEIGHT := 16.0
##列表在各自面板内的起点（左侧留手光标位）
const LIST_OFFSET := Vector2(16, 13)
##itemsbox 九宫格边距（patch_margin_*）
const PATCH_TOP := 13.0
const PATCH_BOTTOM := 14.0
const PATCH_RIGHT := 13.0
##背景最小宽度（itemsbox 纹理的最小九宫格宽度）
const MIN_WIDTH := 48.0
##两侧与屏幕左右边缘的间距
const SIDE_MARGIN := 2.0
##class card 距屏幕顶边的位置（底部被贴底的物品栏压住一截）
const CARD_TOP := 2.0
##GBA 视口
const VIEW_WIDTH := 240.0
const VIEW_HEIGHT := 160.0
##交换界面两侧并排，240 宽放不下完整名称列：压缩物品名列宽度
const NAME_COLUMN_WIDTH := 44.0

const COLOR_SELECTED := Color(1, 0.95, 0.4)
const COLOR_NORMAL := Color(1, 1, 1)
##拾取中的物品行（半透明黄，提示"正在搬运"）
const COLOR_HELD := Color(1, 0.95, 0.4, 0.55)

##交换双方：0=左侧（行动单位）1=右侧（友军）
var _units: Array[Unit] = []
##当前操作侧（0/1）
var _side := 0
##各侧选中行索引（可停在空槽位上，用于转移落点）
var _index: Array[int] = [0, 0]
##拾取中的物品位置（-1=未拾取）
var _held_side := -1
var _held_index := -1

var _panel: Control
##每侧的节点与几何信息：{card, bg, vbox, rows, box_x, box_w}
var _sides: Array = []
##物品栏统一贴屏幕底边（_layout 计算）
var _box_y := 0.0
var _cursor: Control


func _init() -> void:
	_build_panel()


##构建面板：Control 根 + 两侧（card + itemsbox 背景 + VBox 列表）+ 手光标
func _build_panel() -> void:
	_panel = Control.new()
	_panel.name = "Trade Menu"
	_panel.visible = false
	for i in 2:
		_sides.append(_build_side())
	_cursor = CURSOR_HAND_SCENE.instantiate()
	_panel.add_child(_cursor)
	##关键：面板必须挂到自身节点下，否则是孤儿节点（ItemRow 的 @onready 不会生效）
	add_child(_panel)


##构建一侧：class card（先加，绘制在物品栏之下）+ itemsbox 背景 + VBox 物品行
func _build_side() -> Dictionary:
	var card := TextureRect.new()
	card.stretch_mode = TextureRect.STRETCH_KEEP
	_panel.add_child(card)

	var bg: NinePatchRect = ITEMSBOX_SCENE.instantiate()
	##注意：custom_maximum_size "无限制"=(-1,-1)，(0,0) 是"上限 0×0"（会把背景钳没）
	bg.custom_minimum_size = Vector2(0, 0)
	bg.custom_maximum_size = Vector2(-1, -1)
	_panel.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	_panel.add_child(vbox)

	var rows: Array[ItemRow] = []
	for i in BAG_SLOTS:
		var row: ItemRow = ITEM_ROW_SCENE.instantiate()
		##两侧并排放不下完整名称列：压缩名称列宽度
		(row.get_node("ItemName") as Label).custom_minimum_size = Vector2(NAME_COLUMN_WIDTH, 0)
		vbox.add_child(row)
		rows.append(row)
	return {"card": card, "bg": bg, "vbox": vbox, "rows": rows, "box_x": 0.0, "box_w": MIN_WIDTH}


##打开交换界面：填充两侧列表、布局、光标停在左侧第一行
func open(unit_a: Unit, unit_b: Unit) -> void:
	_units = [unit_a, unit_b]
	_side = 0
	_index = [0, 0]
	_held_side = -1
	_held_index = -1
	##class card：无职业数据的一侧不显示卡片
	for side in 2:
		var cd: ClassData = _units[side].class_data
		(_sides[side]["card"] as TextureRect).texture = cd.class_card if cd != null else null
	_fill_rows()
	_layout()
	_refresh()
	_panel.visible = true


##关闭交换界面（通知 BattleManager 重算攻击范围并回行动菜单）
func close() -> void:
	_panel.visible = false
	_units = []
	closed.emit()


##外部输入入口（由 BattleManager 转发）
func handle_input(event: InputEvent) -> void:
	if not event.is_pressed() or _units.is_empty():
		return
	if event.is_action_pressed("ui_up"):
		_move(-1)
	elif event.is_action_pressed("ui_down"):
		_move(1)
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_switch_side()
	elif event.is_action_pressed("yes"):
		_confirm()
	elif event.is_action_pressed("no"):
		if _held_side >= 0:
			##放回：取消拾取，光标回到拾取侧
			_held_side = -1
			_held_index = -1
			_refresh()
		else:
			close()


##移动选择（可在全部 5 个槽位间移动，空槽位是转移落点）
func _move(dir: int) -> void:
	_index[_side] = wrapi(_index[_side] + dir, 0, BAG_SLOTS)
	_refresh()


##切换操作侧（仅两侧，左右键都是切换）
func _switch_side() -> void:
	_side = 1 - _side
	_refresh()


##确认：拾取 / 交换 / 转移 / 同侧调换
func _confirm() -> void:
	var inv := _units[_side].inventory
	var row := _index[_side]
	if _held_side < 0:
		##拾取当前物品（空槽位不可拾取），光标跳到另一侧
		if row < inv.size() and inv[row] != null:
			_held_side = _side
			_held_index = row
			_side = 1 - _side
			_refresh()
		return
	if row >= inv.size() or inv[row] == null:
		##目标空槽位：把拾取的物品转移到对方背包末尾
		if _held_side != _side:
			_transfer_append(_held_side, _held_index, _side)
		return
	if _held_side == _side:
		##同侧：调换两件物品位置（整理背包）
		_swap_within(_side, _held_index, row)
	else:
		##跨侧落到已有物品上：交换
		_transfer_swap(_held_side, _held_index, _side, row)


##跨侧转移：拾取的物品追加到目标方背包末尾（目标背包满则不动）
func _transfer_append(from_side: int, from_idx: int, to_side: int) -> void:
	var from_unit := _units[from_side]
	var to_unit := _units[to_side]
	if from_idx >= from_unit.inventory.size() or to_unit.inventory.size() >= BAG_SLOTS:
		return
	var item: Item = from_unit.inventory[from_idx]
	if item == null:
		return
	##P0-2：通过 Unit 接口移除与添加，自动同步 current_weapon
	if not from_unit.remove_item_at(from_idx):
		return
	if not to_unit.add_item(item):
		##理论上容量已检查过，不会到这里；防御性还原
		from_unit.inventory.insert(from_idx, item)
		return
	_side = to_side
	_index[to_side] = maxi(to_unit.inventory.size() - 1, 0)
	_clear_held_and_refresh()


##跨侧交换：双方各取一件物品互换（装备中的武器被换走则卸下）
func _transfer_swap(from_side: int, from_idx: int, to_side: int, to_idx: int) -> void:
	var from_unit := _units[from_side]
	var to_unit := _units[to_side]
	var from_inv := from_unit.inventory
	var to_inv := to_unit.inventory
	if from_idx >= from_inv.size() or to_idx >= to_inv.size():
		return
	var item: Item = from_inv[from_idx]
	var other: Item = to_inv[to_idx]
	if item == null:
		return
	if other == null:
		##目标行异常空位：退化为转移
		_transfer_append(from_side, from_idx, to_side)
		return
	##P0-2：remove_item 同步 current_weapon；为保持原索引，移除后再 insert 回原位
	from_unit.remove_item_at(from_idx)
	to_unit.remove_item_at(to_idx)
	from_inv.insert(from_idx, other)
	to_inv.insert(to_idx, item)
	_side = to_side
	_index[to_side] = to_idx
	_clear_held_and_refresh()


##同侧调换两件物品位置（整理背包）
func _swap_within(side: int, a: int, b: int) -> void:
	var inv := _units[side].inventory
	if a == b or a >= inv.size() or b >= inv.size():
		_clear_held_and_refresh()
		return
	var tmp: Item = inv[a]
	inv[a] = inv[b]
	inv[b] = tmp
	_index[side] = b
	_clear_held_and_refresh()


##结束拾取并全量刷新（物品变动后宽度可能变化，需要重新布局）
func _clear_held_and_refresh() -> void:
	_held_side = -1
	_held_index = -1
	_fill_rows()
	_layout()
	_refresh()


##填充两侧物品行（空槽位由 ItemRow.clear 隐藏）
func _fill_rows() -> void:
	for side in 2:
		var inv: Array[Item] = _units[side].inventory
		var rows: Array = _sides[side]["rows"]
		for i in BAG_SLOTS:
			(rows[i] as ItemRow).set_item(inv[i] if i < inv.size() else null)


##布局：物品栏贴屏幕底边、宽度按各自内容自适应、卡片居中于物品栏上方
func _layout() -> void:
	var box_h := PATCH_TOP + BAG_SLOTS * ROW_HEIGHT + PATCH_BOTTOM
	_box_y = VIEW_HEIGHT - box_h
	for side in 2:
		var s: Dictionary = _sides[side]
		var row_width := 0.0
		for row in s["rows"]:
			row_width = maxf(row_width, (row as ItemRow).get_combined_minimum_size().x)
		var box_w := maxf(LIST_OFFSET.x + row_width + PATCH_RIGHT, MIN_WIDTH)
		var box_x := SIDE_MARGIN if side == 0 else VIEW_WIDTH - box_w - SIDE_MARGIN
		(s["bg"] as NinePatchRect).position = Vector2(box_x, _box_y)
		(s["bg"] as NinePatchRect).size = Vector2(box_w, box_h)
		(s["vbox"] as VBoxContainer).position = Vector2(box_x + LIST_OFFSET.x, _box_y + PATCH_TOP)
		var card := s["card"] as TextureRect
		if card.texture != null:
			var card_w: float = card.texture.get_size().x
			card.position = Vector2(box_x + (box_w - card_w) * 0.5, CARD_TOP)
		s["box_x"] = box_x
		s["box_w"] = box_w


##刷新行高亮与手光标位置（拾取中的行半透明提示）
func _refresh() -> void:
	for side in 2:
		var rows: Array = _sides[side]["rows"]
		for i in BAG_SLOTS:
			var color := COLOR_NORMAL
			if side == _side and i == _index[side]:
				color = COLOR_SELECTED
			if _held_side == side and _held_index == i:
				color = COLOR_HELD
			(rows[i] as ItemRow).modulate = color
	_update_cursor()


##手光标跟随当前操作侧的选中行（行 x = 所在物品栏左缘，行 y = 上边距 + 行序*行高）
func _update_cursor() -> void:
	if _cursor == null or _sides.is_empty():
		return
	_cursor.visible = true
	var box_x: float = _sides[_side]["box_x"]
	_cursor.position = Vector2(box_x, _box_y + PATCH_TOP + _index[_side] * ROW_HEIGHT)
