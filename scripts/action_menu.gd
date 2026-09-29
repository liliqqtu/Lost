extends Node
class_name ActionMenu

##行动菜单（阶段四）：单位移动后弹出 物品 / 待机 / 运输队
##阶段五 5E：动态附加项（访问/开启/对话）追加在固定项之上
##阶段五 5A 升级：攻击也归入动态附加项（仅在攻击范围内有敌人时显示），
##实际菜单顺序 = 攻击 / 访问 / 开启 / 对话 / 救援 / 放下 / 交接 / 物品 / 待机 / 运输队
##5F/UI 升级：背景用 scene/ui/itemsbox.tscn 九宫格（宽 48），
##size.y 随可见选项数量动态调整（原版效果）；手光标 scene/ui/cursorhand.tscn 跟随选中项
##绑定模式与 BattleForecast 一致：按名称绑定面板子节点，节点可由代码或编辑器创建

##手光标场景（与运输队面板同一实现模式）
const CURSOR_HAND_SCENE := preload("res://scene/ui/cursorhand.tscn")
##字体资源
const LABEL_SETTING_TRES := preload("res://assets/graphics/UI/label_settings.tres")
##字体副本，可自由修改
var label_setting = LABEL_SETTING_TRES.duplicate()
##菜单背景宽度（itemsbox 作为行动菜单背景时固定 48）
const PANEL_WIDTH := 48.0
##itemsbox 九宫格上下边距（patch_margin_top / patch_margin_bottom）
const PATCH_TOP := 13.0
const PATCH_BOTTOM := 13.0
##单行高度（Label 设置字体大小为9，但label行高为13）
const ROW_HEIGHT := 13

##换位时与屏幕左右边缘保留的间距（同战斗预览面板）
const PANEL_MARGIN := 2.0
##菜单纵向位置（屏幕固定高度）
const MENU_Y := 24.0

const COLOR_SELECTED := Color(1, 0.95, 0.4)
const COLOR_NORMAL := Color(1, 1, 1)
const COLOR_DISABLED := Color(0.45, 0.45, 0.45)

##菜单面板根节点（itemsbox 九宫格）
var _panel: Control
##固定菜单项 Label 列表（顺序即选项顺序：物品 / 待机 / 运输队）——注意攻击已不在这里
var _labels: Array[Label] = []
##动态附加项 Label 缓存（攻击 / 访问 / 开启 / 对话 / 救援 / 放下 / 交接），按需创建重复利用
var _extra_labels: Array[Label] = []
##当前选中项索引
var _selected := 0
##攻击项是否可用（决定"攻击"是否加入动态项）
var _attack_enabled := true
##运输队项是否可用（只有特定单位，如忒）
var _convoy_enabled := false
##手光标实例（挂在面板下，绘制在 VBox 之上）
var _hand: Control = null


##由外部传入面板根节点（itemsbox 九宫格，含 "VBox" 子节点），收集其下的 Label 作为菜单项
func setup(panel: Control) -> void:
	_panel = panel
	_panel.visible = false
	_panel.position.y = MENU_Y
	##高度按选项数动态调整
	##手光标放在 VBox 之后添加，保证绘制在最上层
	_hand = CURSOR_HAND_SCENE.instantiate()
	_panel.add_child(_hand)
	for child in panel.get_node("VBox").get_children():
		if child is Label:
			_labels.append(child)


##打开菜单：attack_enabled 为攻击范围内是否有敌方单位；convoy_enabled 决定是否显示"运输队"
##extra_items 为动态附加项文本（5E：访问/开启/对话；5F：救援/放下/交接），排在固定项之上
##注意："攻击"由 attack_enabled 单独控制，extra_items 里不应再包含"攻击"
func open(attack_enabled: bool, convoy_enabled: bool = false, extra_items: Array[String] = []) -> void:
	_attack_enabled = attack_enabled
	_convoy_enabled = convoy_enabled
	_selected = 0
	## 隐藏或显示"运输队"选项（固定项索引 2：物品=0 待机=1 运输队=2）
	if _labels.size() >= 3:
		_labels[2].visible = convoy_enabled
		_labels[2].custom_minimum_size = Vector2(22, 10) if convoy_enabled else Vector2.ZERO
	## 组装完整动态项：攻击（若可用） + 附加项，索引 0 起
	var full_extras: Array[String] = []
	if attack_enabled:
		full_extras.append("攻击")
	for item in extra_items:
		full_extras.append(item)
	## 附加项 Label：不足则创建，多余则隐藏
	var vbox: VBoxContainer = _panel.get_node("VBox")
	while _extra_labels.size() < full_extras.size():
		var label := Label.new()
		label.label_settings = label_setting
		label.custom_minimum_size = Vector2(22, 10)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(label)
		_extra_labels.append(label)
	for i in _extra_labels.size():
		_extra_labels[i].visible = i < full_extras.size()
		if i < full_extras.size():
			_extra_labels[i].text = full_extras[i]
			_extra_labels[i].custom_minimum_size = Vector2(22, 10)
		else:
			_extra_labels[i].custom_minimum_size = Vector2.ZERO
	## 动态项排到固定项之上：按顺序插到 VBox 顶部
	for i in full_extras.size():
		vbox.move_child(_extra_labels[i], i)
	## 强制刷新容器布局
	vbox.queue_sort()
	## 背景高度随可见选项数量动态调整（原版效果）：上边距 + 行数 + 下边距
	var visible_count := _visible_labels().size()
	var height := PATCH_TOP + visible_count * ROW_HEIGHT + PATCH_BOTTOM
	_panel.size = Vector2(PANEL_WIDTH, height)
	_refresh()
	_panel.visible = true


##关闭菜单
func close() -> void:
	_panel.visible = false


##移动选中项，dir 为 -1（上）或 1（下）；边界=最后一个可见项（运输队可隐藏、附加项可变）
func move_selection(dir: int) -> void:
	_selected = clampi(_selected + dir, 0, _max_visible_index())
	_refresh()


##按显示顺序返回当前可见的菜单项 Label（动态项在前、固定项在后）
func _visible_labels() -> Array[Label]:
	var out: Array[Label] = []
	for label in _extra_labels:
		if label.visible:
			out.append(label)
	for label in _labels:
		if label.visible:
			out.append(label)
	return out


##最后一个可见菜单项的索引（= 可见项数 - 1）
func _max_visible_index() -> int:
	return _visible_labels().size() - 1


##当前选中项索引
func get_selected() -> int:
	return _selected


##左右换位：单位在屏幕左半边时菜单放右侧，右半边时放左侧，避免遮挡单位
##逻辑与 BattleForecast.update_side 一致
func update_side(unit: Unit, camera: Camera2D) -> void:
	var view_width: float = _panel.get_viewport().get_visible_rect().size.x
	var screen_x: float = unit.global_position.x - camera.get_screen_center_position().x + view_width * 0.5
	##背景宽度固定 48
	if screen_x < view_width * 0.5:
		_panel.position.x = view_width - PANEL_WIDTH - PANEL_MARGIN
	else:
		_panel.position.x = PANEL_MARGIN


##刷新菜单项高亮与手光标位置
func _refresh() -> void:
	var labels := _visible_labels()
	for i in labels.size():
		labels[i].add_theme_color_override("font_color",
				COLOR_SELECTED if i == _selected else COLOR_NORMAL)
	## 手光标跟随选中项（行 y = 上边距 + 行序 * 行高，手光标 16px 高于 10px 行高，上移 3px 居中）
	if _hand != null:
		_hand.visible = true
		_hand.position = Vector2(-3.0, PATCH_TOP + _selected * ROW_HEIGHT - 3.0)
