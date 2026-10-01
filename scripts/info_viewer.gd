class_name InfoViewer
extends Node
##"""信息查看系统：信息查看控制器（只管通用流程）
##职责（严格限定）：接收当前查看对象、获取描述、调用 textbox 显示、
##按方向键切换对象、处理进入/退出——不负责物品/角色/职业等具体数据逻辑，
##也不写 if item / if character 的类型判断。
##"有哪些可查看对象"与导航关系由当前界面提供：
##  open(provider, nav)：进入查看。provider 为当前对象（只需实现 get_info()）；
##  nav 为面板提供的方向回调 func(dir: Vector2i) -> provider
##  （上=(0,-1) 下=(0,1) 左=(-1,0) 右=(1,0)；返回 null 表示该方向无可切换对象，保持当前）
##输入由所属面板转发到 handle_input（各面板在 BattleManager 对应状态下持有输入权，
##InfoViewer 不自建输入监听、不改 BattleManager 状态机）：
##  方向键 → nav 切换对象；R / X → 退出查看
##描述显示复用 scene/ui/textbox.tscn（与对话系统同一文字框场景，不重复实现）"""

const TEXTBOX_SCENE := preload("res://scene/ui/textbox.tscn")

##是否处于信息查看中（面板据此接管输入）
var active := false

var _provider = null
var _nav: Callable
var _textbox: TextBox


func _ready() -> void:
	_textbox = TEXTBOX_SCENE.instantiate()
	add_child(_textbox)
	_textbox.hide_box()


##进入信息查看：provider 需实现 get_info()；返回 false 表示无可查看信息（面板不接管理由）
func open(provider, nav: Callable = Callable()) -> bool:
	if provider == null or not provider.has_method("get_info"):
		return false
	_provider = provider
	_nav = nav
	active = true
	_textbox.show_text(provider.get_info())
	return true


##退出信息查看，收起文字框
func close() -> void:
	active = false
	_provider = null
	_nav = Callable()
	_textbox.hide_box()


##外部输入入口（由当前面板在自己持有输入权时转发）
func handle_input(event: InputEvent) -> void:
	if not active or not event.is_pressed():
		return
	if event.is_action_pressed("R") or event.is_action_pressed("no"):
		close()
		return
	var dir := _direction_of(event)
	if dir != Vector2i.ZERO and _nav.is_valid():
		var next = _nav.call(dir)
		if next != null and next != _provider and next.has_method("get_info"):
			_provider = next
			_textbox.show_text(next.get_info())


##方向键 -> 方向向量（无方向键按下返回 ZERO）
func _direction_of(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("ui_up"):
		return Vector2i(0, -1)
	if event.is_action_pressed("ui_down"):
		return Vector2i(0, 1)
	if event.is_action_pressed("ui_left"):
		return Vector2i(-1, 0)
	if event.is_action_pressed("ui_right"):
		return Vector2i(1, 0)
	return Vector2i.ZERO
