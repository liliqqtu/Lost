class_name ShopPanel
extends Control
## 三类店铺共用的键盘交易界面。嵌入地图时可关闭 capture_input，由宿主转发。
signal closed
signal transaction_completed(kind: StringName, item: Item)
enum ShopType { ARMORY, VENDOR, SECRET }
enum Phase { CLOSED, DIALOGUE, MODE, BUY, SELL, CONFIRM_BUY, CONFIRM_SELL, CONVOY }
const ROW_SCENE := preload("res://scene/ui/itemrow.tscn")
const ROW_COUNT := 5
const ROW_HEIGHT := 16.0
@export var capture_input := true
@export var merchant_portrait: Texture2D
@export var background_texture: Texture2D
@onready var _talk = $Talk
@onready var _cursor: Control = $Cursor
@onready var _choices: Control = $Choices
@onready var _gold: Label = $Gold
@onready var _page: Label = $Page
var info_viewer: InfoViewer
var unit: Unit
var shop_type := ShopType.ARMORY
var _stock: Array[Item] = []
var _transactions: ShopTransactions
var _phase := Phase.CLOSED
var _after_dialogue := Phase.MODE
var _index := 0
var _top := 0
var _choice := 0
var _pending: Item
var _rows: Array[ItemRow] = []
var _prices: Array[Label] = []

func _ready() -> void:
	$Portrait.texture = merchant_portrait
	$Background.texture = background_texture
	_talk.closed.connect(_on_dialogue_closed)
	_build_rows()
	info_viewer = InfoViewer.new()
	add_child(info_viewer)
	visible = false

## stock 为只读模板；空钱包使用全军资金。空 unit 可用于准备阶段直接寄存。
func open(p_unit: Unit, stock: Array[Item], p_shop_type: int = ShopType.ARMORY, wallet: Dictionary = {}, convoy: Object = null) -> void:
	unit = p_unit
	_stock = stock.duplicate()
	shop_type = clampi(p_shop_type, 0, 2)
	_transactions = ShopTransactions.new(SaveManager.party_funds if wallet.is_empty() else wallet, ConvoyStore if convoy == null else convoy)
	_index = 0
	_top = 0
	_choice = 0
	_pending = null
	visible = true
	$ShopTitle.text = ShopCatalog.TITLES[shop_type]
	_say(ShopCatalog.dialogue("welcome", shop_type), Phase.MODE)
	_refresh()

func close() -> void:
	if info_viewer.active:
		info_viewer.close()
	_phase = Phase.CLOSED
	visible = false
	_talk.hide()
	unit = null
	_stock.clear()
	_pending = null
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if capture_input and visible and event.is_pressed():
		handle_input(event)
		get_viewport().set_input_as_handled()

func handle_input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if info_viewer.active:
		info_viewer.handle_input(event)
		return
	if _phase == Phase.DIALOGUE:
		_talk.handle_input(event)
		return
	if event.is_action_pressed("no"):
		_cancel()
		return
	if _phase == Phase.BUY or _phase == Phase.SELL:
		var direction := int(event.is_action_pressed("ui_down")) - int(event.is_action_pressed("ui_up"))
		if direction != 0:
			_move_selection(direction)
		elif event.is_action_pressed("R") and not _items().is_empty():
			info_viewer.open(_rows[_index - _top], _navigate_info)
		elif event.is_action_pressed("yes"):
			_select_item()
	else:
		var direction := int(event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down")) - int(event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"))
		if direction != 0:
			_choice = posmod(_choice + direction, 3 if _phase == Phase.MODE else 2)
			_refresh_choices()
		elif event.is_action_pressed("yes"):
			_accept_choice()

func _cancel() -> void:
	if _phase == Phase.MODE:
		_say(ShopCatalog.dialogue("bye", shop_type), Phase.CLOSED)
	elif _phase == Phase.BUY or _phase == Phase.SELL:
		_enter(Phase.MODE)
	else:
		_enter(Phase.SELL if _phase == Phase.CONFIRM_SELL else Phase.BUY)

func _accept_choice() -> void:
	match _phase:
		Phase.MODE:
			_index = 0
			_top = 0
			if _choice == 2:
				_say(ShopCatalog.dialogue("bye", shop_type), Phase.CLOSED)
			elif _choice == 1 and (unit == null or unit.inventory.is_empty()):
				_say(ShopCatalog.dialogue("empty", shop_type), Phase.MODE)
			else:
				_enter(Phase.BUY if _choice == 0 else Phase.SELL)
		Phase.CONFIRM_BUY:
			if _choice == 1:
				_enter(Phase.BUY)
			elif unit == null or unit.inventory.size() >= Unit.BAG_LIMIT:
				if _transactions.convoy == null:
					_say(ShopCatalog.dialogue("no_convoy", shop_type), Phase.BUY)
				else:
					_enter(Phase.CONVOY)
			else:
				_complete_purchase(false)
		Phase.CONFIRM_SELL:
			if _choice == 1:
				_enter(Phase.SELL)
			else:
				var result := _transactions.sell(unit, _pending)
				if result == &"ok":
					transaction_completed.emit(&"sell", _pending)
				_say(ShopCatalog.dialogue("sold" if result == &"ok" else "unsellable", shop_type), Phase.SELL if not unit.inventory.is_empty() else Phase.MODE)
		Phase.CONVOY:
			if _choice == 0:
				_complete_purchase(true)
			else:
				_enter(Phase.BUY)

func _select_item() -> void:
	var items := _items()
	if items.is_empty():
		return
	_pending = items[_index]
	if _phase == Phase.SELL:
		if ShopTransactions.sell_price(_pending) <= 0:
			_say(ShopCatalog.dialogue("unsellable", shop_type), Phase.SELL)
		else:
			_enter(Phase.CONFIRM_SELL)
	else:
		if ShopTransactions.buy_price(_pending) <= 0:
			_say(ShopCatalog.dialogue("unavailable", shop_type), Phase.BUY)
		elif _transactions.gold() < ShopTransactions.buy_price(_pending):
			_say(ShopCatalog.dialogue("funds", shop_type), Phase.BUY)
		else:
			_enter(Phase.CONFIRM_BUY)

func _complete_purchase(send_to_convoy: bool) -> void:
	var result := _transactions.purchase(unit, _pending, send_to_convoy)
	var key := String(result)
	if result == &"ok":
		key = "sent" if send_to_convoy else "bought"
		transaction_completed.emit(&"buy", _pending)
	_say(ShopCatalog.dialogue(key, shop_type), Phase.BUY)

func _say(text: String, next_phase: Phase) -> void:
	_phase = Phase.DIALOGUE
	_after_dialogue = next_phase
	_choices.hide()
	_cursor.hide()
	_talk.open([{"text": text}])
	_refresh()

func _on_dialogue_closed() -> void:
	if _after_dialogue == Phase.CLOSED:
		close()
	else:
		_enter(_after_dialogue)

func _enter(phase: Phase) -> void:
	_phase = phase
	_choice = 0
	var key := "again"
	if phase == Phase.BUY:
		key = "buy"
	elif phase == Phase.SELL:
		key = "sell"
	elif phase == Phase.CONVOY:
		key = "bag_full"
	var text := ShopCatalog.dialogue(key, shop_type)
	if phase == Phase.CONFIRM_BUY:
		text = "%d 金币，要买下吗？" % ShopTransactions.buy_price(_pending)
	elif phase == Phase.CONFIRM_SELL:
		text = "%d 金币，确定卖出吗？" % ShopTransactions.sell_price(_pending)
	_talk.show_prompt(text)
	_refresh()

func _items() -> Array[Item]:
	if _phase == Phase.SELL or _phase == Phase.CONFIRM_SELL:
		return unit.inventory if unit != null else []
	return _stock

func _move_selection(direction: int) -> void:
	var count := _items().size()
	if count > 0:
		_index = posmod(_index + direction, count)
	_refresh()

func _navigate_info(direction: Vector2i):
	if direction.y != 0:
		_move_selection(direction.y)
	return _rows[_index - _top] if not _items().is_empty() else null

func _build_rows() -> void:
	for i in ROW_COUNT:
		var row := ROW_SCENE.instantiate() as ItemRow
		add_child(row)
		row.focus_mode = Control.FOCUS_CLICK
		row.position = Vector2(28, 66 + i * ROW_HEIGHT)
		row.size = Vector2(142, 16)
		row.get_node("ItemName").custom_minimum_size.x = 82
		row.get_node("ItemName").horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.get_node("ItemName").add_theme_font_size_override("font_size", 9)
		row.get_node("ItemDurability").add_theme_font_size_override("font_size", 9)
		_rows.append(row)
		var price := Label.new()
		price.position = Vector2(174, 66 + i * ROW_HEIGHT)
		price.size = Vector2(48, 16)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price.add_theme_font_size_override("font_size", 10)
		add_child(price)
		_prices.append(price)
	move_child(_cursor, -1)

func _refresh() -> void:
	if _transactions == null:
		return
	_gold.text = "%d G" % _transactions.gold()
	var items := _items()
	_index = clampi(_index, 0, maxi(items.size() - 1, 0))
	_top = clampi(_top, maxi(_index - ROW_COUNT + 1, 0), _index)
	for i in ROW_COUNT:
		var item: Item = items[_top + i] if _top + i < items.size() else null
		_rows[i].set_item(item)
		_prices[i].text = ""
		if item == null:
			continue
		var price := ShopTransactions.sell_price(item) if _phase == Phase.SELL or _phase == Phase.CONFIRM_SELL else ShopTransactions.buy_price(item)
		_prices[i].text = str(price) if price > 0 else "—"
		var usable := unit == null or not item is Weapon or unit.can_equip(item as Weapon)
		_rows[i].modulate = Color.WHITE if usable else Color(0.65, 0.65, 0.65)
		_prices[i].modulate = Color.WHITE if price > 0 and (_phase == Phase.SELL or _transactions.gold() >= price) else Color(0.65, 0.65, 0.65)
	_page.text = "%d/%d   ↑↓选择  Z确定 X返回 R说明" % [mini(_index + 1, items.size()), items.size()]
	_refresh_choices()

func _refresh_choices() -> void:
	_choices.visible = _phase in [Phase.MODE, Phase.CONFIRM_BUY, Phase.CONFIRM_SELL, Phase.CONVOY]
	if _choices.visible:
		_choices.get_node("First").text = "买入" if _phase == Phase.MODE else "确定"
		_choices.get_node("Second").text = "卖出" if _phase == Phase.MODE else "取消"
		_choices.get_node("Third").visible = _phase == Phase.MODE
		_cursor.position = Vector2(76 + _choice * 46, 41)
		_cursor.show()
	elif _phase == Phase.BUY or _phase == Phase.SELL:
		_cursor.position = Vector2(12, 66 + (_index - _top) * ROW_HEIGHT)
		_cursor.visible = not _items().is_empty()
	else:
		_cursor.hide()


