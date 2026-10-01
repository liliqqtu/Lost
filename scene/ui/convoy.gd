extends Control
##"""运输队面板（阶段五 5D）
##纯键盘操作：方向键移动，Z 确认，X 取消。
##
##流程：
##  MODE_SELECT：选择"取出"或"寄存"，方向键切换，Z 进入，X 关闭面板
##  TAKE：右侧仓库列表 ↑↓ 移动光标（滚动窗口），←→ 切换 9 类，Z 取回物品
##  DEPOSIT：左侧背包 ↑↓ 移动光标，Z 寄存物品，无 ←→ 操作
##"""
class_name ConvoyPanel

signal closed
## 模式选择，取出，寄存
enum Phase { MODE_SELECT, TAKE, DEPOSIT }
## 模式选择（寄存 取出）
enum Mode { TAKE, DEPOSIT }
## 模式相应的描述
const MODE_DESCRIPTIONS := ["可以做些什么吗？", "要取出什么？","要寄存什么？"]
## 物品通用场景
const ITEM_ROW_SCENE := preload("res://scene/ui/itemrow.tscn")
## 人物角色的背包
const BAG_SLOTS := 5
## 运输队里显示的物品数量
const VISIBLE_ROWS := 7
const ROW_HEIGHT := 16.0

## 模式按钮位置（左侧面板标题区，两个 Label）
const MODE_BUTTON_POS := [Vector2(74, 39), Vector2(74, 54)]
const MODE_BUTTON_SIZE := Vector2(36, 12)
const MODE_CURSOR_OFFSET_X := -14.0

@onready var current_items: Label = $MG/CurrentItems
@onready var prompt_label: Label = $PromptLabel

## 当前打开面板的单位（运输队主人，默认=忒）
var unit: Unit = null

## 信息查看器（信息查看系统，Level 装配时注入；R 查看光标处物品说明）
var info_viewer: Node = null

## 打开默认 进行模式选择 取出 / 寄存
var _phase := Phase.MODE_SELECT
var _mode_index := 0

## 仓库侧滚动状态(物品类图标) 
var _category := ConvoyStore.Category.SWORD
var _cursor_index := 0
var _top_index := 0
var _current_items: Array[Item] = []

## 背包侧状态
var _bag_index := 0

## 视图实例
var _bag_rows: Array[ItemRow] = []
var _list_rows: Array[ItemRow] = []
var _mode_labels: Array[Label] = []
var _message_label: Label = null
var _message_timer: Timer = null


func _ready() -> void:
	## 保持背景横向滚动
	var tween_bg := create_tween()
	tween_bg.set_loops()
	tween_bg.tween_property($BG, "position", Vector2(-240, 0), 12.0)
	tween_bg.tween_callback(_reset_position)

	## 列表行高必须紧密排列
	$Bag.add_theme_constant_override("separation", 0)
	$ConvoyBag.add_theme_constant_override("separation", 0)

	_build_bag_rows()
	_build_convoy_rows()
	_build_mode_buttons()
	_build_message_label()
	## 让两个光标始终显示在最上层（动态添加的标签可能覆盖它们）
	move_child($Cursor, -1)
	move_child($ItemIconClassCursor, -1)

	
	visible = false


## 构建左侧 5 行背包
func _build_bag_rows() -> void:
	for i in BAG_SLOTS:
		var row: ItemRow = ITEM_ROW_SCENE.instantiate()
		$Bag.add_child(row)
		_bag_rows.append(row)


## 构建右侧 7 行运输队列表（只维护可见窗口）
func _build_convoy_rows() -> void:
	for i in VISIBLE_ROWS:
		var row: ItemRow = ITEM_ROW_SCENE.instantiate()
		$ConvoyBag.add_child(row)
		_list_rows.append(row)


## 构建"取出"/"寄存"模式按钮
func _build_mode_buttons() -> void:
	var texts := ["取出", "寄存"]
	for i in texts.size():
		var label := Label.new()
		label.text = texts[i]
		label.position = MODE_BUTTON_POS[i]
		label.custom_minimum_size = MODE_BUTTON_SIZE
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
		_mode_labels.append(label)


## 底部消息提示（错误时闪一下）
func _build_message_label() -> void:
	_message_label = Label.new()
	_message_label.position = Vector2(5, 140)
	_message_label.custom_minimum_size = Vector2(120, 12)
	_message_label.add_theme_font_size_override("font_size", 9)
	_message_label.add_theme_constant_override("outline_size", 3)
	_message_label.add_theme_color_override("font_color", Color.YELLOW)
	_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_message_label.visible = false
	add_child(_message_label)

	_message_timer = Timer.new()
	_message_timer.one_shot = true
	_message_timer.timeout.connect(func(): _message_label.visible = false)
	add_child(_message_timer)


func _reset_position() -> void:
	$BG.position = Vector2.ZERO


## 打开面板
func show_panel(p_unit: Unit) -> void:
	unit = p_unit
	visible = true
	_phase = Phase.MODE_SELECT
	_mode_index = 0
	_category = ConvoyStore.Category.SWORD
	_cursor_index = 0
	_top_index = 0
	_bag_index = 0
	_refresh_all()
	_update_mode_cursor()
	_update_class_cursor()


## 隐藏面板（信息查看中一并收起）
func hide_panel() -> void:
	if info_viewer != null and info_viewer.active:
		info_viewer.close()
	visible = false
	unit = null


## 注入信息查看器（Level 装配）
func set_info_viewer(viewer: Node) -> void:
	info_viewer = viewer


## 外部输入入口（由 BattleManager 转发）
func handle_input(event: InputEvent) -> void:
	## 信息查看中：输入全部转给 InfoViewer（R/X 退出、方向键切换物品）
	if info_viewer != null and info_viewer.active:
		info_viewer.handle_input(event)
		return
	if not event.is_pressed():
		return
	match _phase:
		Phase.MODE_SELECT:
			_handle_mode_input(event)
		Phase.TAKE:
			_handle_take_input(event)
		Phase.DEPOSIT:
			_handle_deposit_input(event)


## 模式选择：方向键切换，Z 确认，X 关闭
func _handle_mode_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") \
		or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		_mode_index = 1 - _mode_index
		_update_mode_cursor()
	elif event.is_action_pressed("yes"):
		if _mode_index == Mode.TAKE:
			_enter_take_phase()
		else:
			_enter_deposit_phase()
	elif event.is_action_pressed("no"):
		hide_panel()
		closed.emit()


## 取出模式：↑↓移动，←→切类，Z 取出，X 回模式，R 查看物品说明
func _handle_take_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_move_cursor(-1)
	elif event.is_action_pressed("ui_down"):
		_move_cursor(1)
	elif event.is_action_pressed("ui_left"):
		_switch_category(-1)
	elif event.is_action_pressed("ui_right"):
		_switch_category(1)
	elif event.is_action_pressed("yes"):
		_take_item()
	elif event.is_action_pressed("no"):
		_enter_mode_select()
	elif event.is_action_pressed("R"):
		_open_info()


## 寄存模式：↑↓移动背包光标，Z 寄存，X 回模式，R 查看物品说明
func _handle_deposit_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_up"):
		_move_bag_cursor(-1)
	elif event.is_action_pressed("ui_down"):
		_move_bag_cursor(1)
	elif event.is_action_pressed("yes"):
		_deposit_item()
	elif event.is_action_pressed("no"):
		_enter_mode_select()
	elif event.is_action_pressed("R"):
		_open_info()


##==================== 信息查看（信息查看系统） ====================

## R 查看当前光标处物品的说明
## TAKE=仓库列表当前项 / DEPOSIT=背包当前项 / MODE_SELECT 无可查看对象
func _open_info() -> void:
	if info_viewer == null:
		return
	if _phase == Phase.TAKE and not _current_items.is_empty():
		info_viewer.open(_list_rows[_cursor_index - _top_index], _nav_info)
	elif _phase == Phase.DEPOSIT and unit != null and not unit.inventory.is_empty():
		info_viewer.open(_bag_rows[_bag_index], _nav_info)


## 信息查看导航（本面板的导航规则）：
## 上下=当前列表内移动光标；取出模式的左右=切换物品类别
func _nav_info(dir: Vector2i) -> ItemRow:
	if dir.y != 0:
		if _phase == Phase.TAKE:
			_move_cursor(dir.y)
			##_move_cursor 仅滚动窗口时刷新，这里统一刷新保证手光标跟随
			_refresh_all()
		elif _phase == Phase.DEPOSIT:
			_move_bag_cursor(dir.y)
		return _current_info_row()
	elif dir.x != 0 and _phase == Phase.TAKE:
		_switch_category(dir.x)
		return _current_info_row()
	return null


## 当前信息查看的 ItemRow（列表为空返回 null）
func _current_info_row() -> ItemRow:
	if _phase == Phase.TAKE:
		if _current_items.is_empty():
			return null
		return _list_rows[_cursor_index - _top_index]
	if _phase == Phase.DEPOSIT:
		if unit == null or unit.inventory.is_empty():
			return null
		return _bag_rows[_bag_index]
	return null


## 进入取出模式
func _enter_take_phase() -> void:
	_phase = Phase.TAKE
	prompt_label.text = MODE_DESCRIPTIONS[_phase]
	_category = ConvoyStore.Category.SWORD
	_cursor_index = 0
	_top_index = 0
	_refresh_all()


## 进入寄存模式
func _enter_deposit_phase() -> void:
	_phase = Phase.DEPOSIT
	prompt_label.text = MODE_DESCRIPTIONS[_phase]
	_bag_index = 0
	_refresh_all()


## 返回模式选择
func _enter_mode_select() -> void:
	_phase = Phase.MODE_SELECT
	prompt_label.text = MODE_DESCRIPTIONS[_phase]
	_refresh_all()
	_update_mode_cursor()


## 仓库列表移动光标（带动滚动窗口）
func _move_cursor(delta: int) -> void:
	if _current_items.is_empty():
		return
	_cursor_index = clampi(_cursor_index + delta, 0, _current_items.size() - 1)
	if _cursor_index < _top_index:
		_top_index = _cursor_index
	elif _cursor_index >= _top_index + VISIBLE_ROWS:
		_top_index = _cursor_index - VISIBLE_ROWS + 1
	_refresh_all()


## 切换类别（9 类循环）
func _switch_category(delta: int) -> void:
	var n := $ItemIconClass.get_child_count()
	_category = wrapi(_category + delta, 0, n)
	_cursor_index = 0
	_top_index = 0
	_refresh_all()


## 背包光标移动
func _move_bag_cursor(delta: int) -> void:
	if unit == null or unit.inventory.is_empty():
		return
	_bag_index = clampi(_bag_index + delta, 0, unit.inventory.size() - 1)
	_refresh_all()


## 执行取出
func _take_item() -> void:
	if _current_items.is_empty():
		return
	if unit == null:
		return
	if unit.inventory.size() >= BAG_SLOTS:
		_flash_message("背包已满")
		return
	var item := _current_items[_cursor_index]
	##P0-2：通过 Unit.add_item 加入背包，自动应用 BAG_LIMIT
	if not unit.add_item(item):
		_flash_message("背包已满")
		return
	ConvoyStore.remove_item(item)
	_refresh_after_change()


## 执行寄存（装备中的武器也可寄存：寄存后 current_weapon 由 remove_item_at 内部置空）
func _deposit_item() -> void:
	if unit == null or _bag_index >= unit.inventory.size():
		return
	var item := unit.inventory[_bag_index]
	if not ConvoyStore.add(item):
		_flash_message("运输队已满")
		return
	##P0-2：remove_item_at 自动卸装装备中的武器
	unit.remove_item_at(_bag_index)
	_refresh_after_change()


## 数据变动后：重新过滤、修正光标、刷新显示
func _refresh_after_change() -> void:
	current_items.text = str(ConvoyStore.get_current_items())
	_current_items = ConvoyStore.items_in(_category)
	_cursor_index = clampi(_cursor_index, 0, maxi(_current_items.size() - 1, 0))
	_top_index = clampi(_top_index, 0, maxi(_current_items.size() - VISIBLE_ROWS, 0))
	if _cursor_index < _top_index:
		_top_index = _cursor_index
	elif _cursor_index >= _top_index + VISIBLE_ROWS:
		_top_index = _cursor_index - VISIBLE_ROWS + 1
	_bag_index = clampi(_bag_index, 0, maxi(unit.inventory.size() - 1, 0))
	_refresh_all()


## 刷新全部显示
func _refresh_all() -> void:
	## 背包
	for i in BAG_SLOTS:
		if unit != null and i < unit.inventory.size():
			_bag_rows[i].set_item(unit.inventory[i])
		else:
			_bag_rows[i].clear()

	## 仓库列表
	_current_items = ConvoyStore.items_in(_category)
	for i in VISIBLE_ROWS:
		var idx := _top_index + i
		if idx < _current_items.size():
			_list_rows[i].set_item(_current_items[idx])
		else:
			_list_rows[i].clear()

	_update_item_cursor()
	_update_class_cursor()


## 更新手指光标位置
func _update_item_cursor() -> void:
	$Cursor.visible = (_phase == Phase.TAKE or _phase == Phase.DEPOSIT)
	if _phase == Phase.TAKE:
		var row := _cursor_index - _top_index
		$Cursor.position = Vector2(
			$ConvoyBag.position.x - 16,
			$ConvoyBag.position.y + row * ROW_HEIGHT
		)
	elif _phase == Phase.DEPOSIT:
		$Cursor.position = Vector2(
			$Bag.position.x - 16,
			$Bag.position.y + _bag_index * ROW_HEIGHT
		)


## 更新模式按钮高亮 + 手指光标
func _update_mode_cursor() -> void:
	for i in _mode_labels.size():
		var color := Color.YELLOW if i == _mode_index else Color.WHITE
		_mode_labels[i].add_theme_color_override("font_color", color)
	$Cursor.visible = true
	$Cursor.position = Vector2(
		MODE_BUTTON_POS[_mode_index].x + MODE_CURSOR_OFFSET_X,
		MODE_BUTTON_POS[_mode_index].y
	)


## 更新类别图标高亮 + 类光标位置
func _update_class_cursor() -> void:
	var icon_box: HBoxContainer = $ItemIconClass
	if _category < 0 or _category >= icon_box.get_child_count():
		return
	var icon: TextureRect = icon_box.get_child(_category)
	$ItemIconClassCursor.position = icon_box.position + icon.position
	for i in icon_box.get_child_count():
		var tex: TextureRect = icon_box.get_child(i)
		var mat: ShaderMaterial = tex.material
		if i != _category :
			mat.set_shader_parameter("dark", true)
			tex.z_index = 0
		else :
			mat.set_shader_parameter("dark", false)
			tex.z_index = 1
			pass


## 底部消息闪一下
func _flash_message(text: String) -> void:
	_message_label.text = text
	_message_label.visible = true
	_message_timer.start(1.0)
