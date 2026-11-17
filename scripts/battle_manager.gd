extends Node
class_name BattleManager

const SAVE_CODEC = preload("res://scripts/save_codec.gd")

##回合开始时广播（team 0 玩家 1 敌方），关卡脚本用于播放回合横幅
signal turn_started(team: int)
##地图系统菜单与全局交互请求
signal map_menu_requested
signal save_requested
signal return_to_title_requested
signal victory_achieved
signal defeat_occurred

enum State {
	CURSOR,
	UNIT_SELECTED,
	MOVING,
	WEAPON_SELECT,
	TARGET_SELECT,
	ACTION_MENU,
	ENEMY_TURN,
	BATTLE_ANIM,
	UNIT_INFO,
	CANTO_MOVING,
	CONVOY,
	ITEM_MENU,
	DIALOGUE,
	EVENT,
	##救援/放下/交接的目标选择（5F）
	RESCUE_SELECT,
	##交换界面（5F）
	TRADE,
}

var state := State.CURSOR

##当前回合方 0玩家 1敌方
var phase := 0
##回合数
var turn := 1
##战斗是否结束（一方全灭）
var battle_over := false
##敌方回合当前行动单位（相机跟随用）
var current_ai_unit: Unit = null

var tile_map: TileMapLayer
var high_light_layer: TileMapLayer
var cursor: Node2D
var camera: Camera2D
##所有的单位
var units: Array[Unit] = []
##选中的单位
var selected_unit: Unit
##移动范围
var move_range: Dictionary
##攻击范围
var attack_range: Array
##RangeDrawer的实例化
var range_drawer := RangeDrawer.new()
##选择的路径
var current_path: Array = []
var last_path_cursor: Vector2i

##过场焦点单位（事件演绎期间相机跟随，关卡脚本读取）
var cutscene_focus: Node2D = null
##移动前的格子（行动菜单取消时撤回移动）
var _pre_move_cell := Vector2i(-9999, -9999)
##移动后是否已执行过不可撤销的子行动（对话/交换）——此后行动菜单按 no 不再撤回移动，直接待机（原版行为）
var _menu_action_spent := false
##记录上一次行动是否为攻击（目标选择设为 true，_end_action 读取后清零）
var _last_action_was_attack := false

##单位指令流程（行动菜单/目标选择/战斗预览/子面板）
var movement: RefCounted
var commands: BattleUnitCommands
##地图交互（村庄/宝箱/对话，5E）
var interaction: BattleMapInteraction
##救援/放下/交接/交换（5F）
var rescue: BattleRescue
##敌人范围查看
var range_inspect: BattleRangeInspect
##再移动（焕发技能）
var canto: BattleCanto
##战斗结算执行
var combat: BattleCombat
##回合切换、敌方回合与地图事件
var phases: BattlePhases
##法杖管理（治愈/状态）
var staff_mgr: BattleStaff
##舞者/吟游诗人管理（跳舞/奏乐）
var dance_mgr: BattleDance

func _init() -> void:
	movement = preload("res://scripts/battle_movement.gd").new()
	movement.bm = self
	commands = BattleUnitCommands.new()
	commands.bm = self
	interaction = BattleMapInteraction.new()
	interaction.bm = self
	rescue = BattleRescue.new()
	rescue.bm = self
	range_inspect = BattleRangeInspect.new()
	range_inspect.bm = self
	canto = BattleCanto.new()
	canto.bm = self
	combat = BattleCombat.new()
	combat.bm = self
	phases = BattlePhases.new()
	phases.bm = self
	staff_mgr = BattleStaff.new()
	staff_mgr.bm = self
	dance_mgr = BattleDance.new()
	dance_mgr.bm = self

##初始化战斗地图
func setup(p_tile_map: TileMapLayer, p_highlight: TileMapLayer, p_cursor: Node2D, p_camera: Camera2D) -> void:
	tile_map = p_tile_map
	high_light_layer = p_highlight
	cursor = p_cursor
	camera = p_camera

##设置战斗预览面板
func set_forecast_panel(panel: Node) -> void:
	commands.forecast_panel = panel

##设置行动菜单
func set_action_menu(menu: Node) -> void:
	commands.action_menu = menu

##设置战斗动画场景（阶段五 5A）
func set_battle_scene(scene: Node) -> void:
	combat.battle_scene = scene

##设置人物信息面板（阶段五 5B）
func set_unit_info_panel(panel: Node) -> void:
	commands.unit_info_panel = panel

##设置运输队面板（阶段五 5C）
func set_convoy_panel(panel: Node) -> void:
	commands.set_convoy_panel(panel)

##设置物品菜单（阶段五 5D）
func set_item_menu(menu: Node) -> void:
	commands.set_item_menu(menu)

##设置武器选择界面
func set_weapon_select_menu(menu: Node) -> void:
	commands.set_weapon_select_menu(menu)

##设置交换界面（5F）
func set_trade_menu(menu: Node) -> void:
	commands.set_trade_menu(menu)

##设置信息查看器（信息查看系统）：分发给物品菜单/运输队/人物面板
func set_info_viewer(viewer: Node) -> void:
	commands.set_info_viewer(viewer)

##设置对话场景（阶段五 5E 重构）
func set_talk_scene(scene: Node) -> void:
	interaction.talk_scene = scene

##设置人物对话数据提供者（阶段五 5E 重构）：cb 签名 func(unit, target) -> Dictionary
##返回 {"lines": [{"speaker","text","side"}...], "portraits": {说话人: Texture2D}}，空字典=无对话
func set_talk_provider(cb: Callable) -> void:
	interaction.talk_provider = cb

var boss_battle_dialogue_provider: Callable
var boss_defeat_dialogue_provider: Callable
var _boss_quotes_played: Dictionary = {}

##设置 Boss 专属交战与阵亡台词提供者
func set_boss_dialogue_provider(battle_cb: Callable, defeat_cb: Callable) -> void:
	boss_battle_dialogue_provider = battle_cb
	boss_defeat_dialogue_provider = defeat_cb

##获取 Boss 首次交战对话（仅触发一次）
func get_boss_battle_dialogue(attacker: Unit, defender: Unit) -> Dictionary:
	var boss: Unit = defender if (defender != null and defender.is_boss) else (attacker if (attacker != null and attacker.is_boss) else null)
	if boss == null or _boss_quotes_played.has(boss.unit_name):
		return {}
	if not boss_battle_dialogue_provider.is_valid():
		return {}
	var data: Dictionary = boss_battle_dialogue_provider.call(attacker, defender)
	if not data.is_empty() and data.has("lines") and not data["lines"].is_empty():
		_boss_quotes_played[boss.unit_name] = true
		return data
	return {}

##获取 Boss 阵亡遗言
func get_boss_defeat_dialogue(boss: Unit, killer: Unit) -> Dictionary:
	if not boss_defeat_dialogue_provider.is_valid():
		return {}
	return boss_defeat_dialogue_provider.call(boss, killer)

##设置地图事件与执行器（阶段五 5E）：runner 签名 func(event: MapEvent) -> void（可 async）
func set_map_events(events: Array[MapEvent], runner: Callable) -> void:
	phases.set_map_events(events, runner)

##战斗开始：广播玩家回合（播放开局横幅），横幅后检查回合事件（阶段五 5E）
func begin_battle() -> void:
	await phases.begin_battle()

##添加单位
func add_unit(unit: Unit) -> void:
	units.append(unit)
	##5G 支援：记录我方登场（章节结算"共同出战一章 +1 支援值"用；增援登场也走此入口）
	if unit.team == 0:
		SupportStore.mark_deployed(unit.unit_name)

##处理输入
func handle_input(event: InputEvent) -> void:
	if battle_over and state != State.DIALOGUE:
		return
	match state:
		State.CURSOR:
			_handle_cursor_input(event)
		State.UNIT_SELECTED:
			_handle_unit_selected_input(event)
		State.MOVING:
			pass
		State.WEAPON_SELECT:
			commands.handle_weapon_select_input(event)
		State.TARGET_SELECT:
			commands.handle_target_select_input(event)
		State.ACTION_MENU:
			commands.handle_action_menu_input(event)
		State.ENEMY_TURN:
			pass
		State.BATTLE_ANIM:
			pass
		State.UNIT_INFO:
			commands.handle_unit_info_input(event)
		State.CANTO_MOVING:
			canto.handle_input(event)
		State.CONVOY:
			if commands.convoy_panel != null:
				commands.convoy_panel.handle_input(event)
		State.ITEM_MENU:
			if commands.item_menu != null:
				commands.item_menu.handle_input(event)
		State.DIALOGUE:
			if interaction.talk_scene != null:
				interaction.talk_scene.handle_input(event)
		State.EVENT:
			pass
		State.RESCUE_SELECT:
			rescue.handle_input(event)
		State.TRADE:
			if commands.trade_menu != null:
				commands.trade_menu.handle_input(event)

## 通行阻挡查询；传入移动者时仅敌对单位阻路，未传入时返回所有占用格。
func _get_blocked_cells(exclude_unit: Unit = null) -> Array:
	return Pathfinder.get_unit_blockers(exclude_unit, units)

##获取指定格子的单位
func _get_unit_at(cell: Vector2i) -> Unit:
	for unit in units:
		if unit.cell == cell:
			return unit
	return null

##移除单位，并检查是否有一方全灭
func _remove_unit(unit: Unit) -> void:
	rescue.on_unit_removed(unit)
	if unit.team == 0 and unit.unit_id != &"" and not SaveManager.fallen_units.has(str(unit.unit_id)):
		SaveManager.fallen_units.append(str(unit.unit_id))
	units.erase(unit)
	unit.queue_free()
	_check_battle_end()

##查询：指定格子上是否有单位（rescue / interaction / commands 等子模块统一走此入口）
func get_unit_at(cell: Vector2i) -> Unit:
	return _get_unit_at(cell)

## 查询移动通行障碍；可穿过友军，落点另由 Pathfinder.can_stop_at 校验。
func get_blocked_cells(exclude_unit: Unit = null) -> Array:
	return _get_blocked_cells(exclude_unit)

##移除单位（阵亡结算）并触发胜负检查（combat 等子模块统一走此入口）
func remove_unit(unit: Unit) -> void:
	_remove_unit(unit)

##通用移动演出（敌方回合 / 增援走位复用），结束返回后单位坐标已更新
func move_unit(unit: Unit, destination: Vector2i) -> void:
	await _move_unit(unit, destination)

##胜负判定：任一阵营全灭则结束战斗
##注意：战斗动画（State.BATTLE_ANIM）期间不直接触发结算，待战后完全返回地图后再结算
func _check_battle_end() -> void:
	if battle_over or state == State.BATTLE_ANIM:
		return
	var has_player := false
	var has_enemy := false
	for unit in units:
		if unit.team == 0:
			has_player = true
		elif unit.team == 1:
			has_enemy = true
	if not has_enemy:
		battle_over = true
		cursor.set_process(false)
		##5G 支援：章节胜利结算——双方都登场过的支援对 +1 支援值
		SupportStore.on_chapter_cleared()
		print("=== 我方胜利！敌方全灭（回合 %d）===" % turn)
		victory_achieved.emit()
	elif not has_player:
		battle_over = true
		cursor.set_process(false)
		##5G 支援：章节失败，登场记录作废
		SupportStore.on_chapter_failed()
		print("=== 我方败北…（回合 %d）===" % turn)
		defeat_occurred.emit()

func check_battle_end() -> void:
	_check_battle_end()

##处理光标输入
func _handle_cursor_input(event: InputEvent) -> void:
	if event.is_action_pressed("yes"):
		for unit in units:
			if unit.cell == cursor.cell and unit.team == 0 and not unit.has_acted:
				range_inspect.clear_display()
				_select_unit(unit)
				return
		##光标停在敌人上（测试问题2）：显示其移动范围（蓝）+最外围攻击范围（红），再按一次取消
		var enemy := _get_unit_at(cursor.cell)
		if enemy != null and enemy.team == 1 and enemy.carried_by == null:
			range_inspect.toggle_single(enemy)
			return
		##空地点击：触发地图系统菜单
		map_menu_requested.emit()
	elif event.is_action_pressed("no"):
		##查看中的敌人范围随取消键关闭
		range_inspect.clear_display()
	elif event.is_action_pressed("start"):
		##按菜单键：若未在查看单体威胁，唤出地图系统菜单
		map_menu_requested.emit()
	elif event.is_action_pressed("R"):
		##光标停在任意单位上（不分敌我）打开人物信息面板
		var unit := _get_unit_at(cursor.cell)
		if unit != null and commands.unit_info_panel != null:
			commands.unit_info_panel.show_panel(unit, false, units)
			state = State.UNIT_INFO
			cursor.set_process(false)

func _handle_unit_selected_input(event: InputEvent) -> void:
	movement._handle_unit_selected_input(event)

func _select_unit(unit: Unit) -> void:
	movement._select_unit(unit)

func _cancel_selection() -> void:
	movement._cancel_selection()

func _start_move(destination: Vector2i) -> void:
	movement._start_move(destination)

func _on_move_complete() -> void:
	movement._on_move_complete()

func _finish_move(destination: Vector2i) -> void:
	movement._finish_move(destination)

func _move_unit(unit: Unit, destination: Vector2i) -> void:
	await movement._move_unit(unit, destination)

##行动结束公开入口（P2）：子模块统一经此结束行动，不再调用 _end_action
##allow_canto=false 时跳过再移动（待机=主动放弃，测试问题3）
func end_action(allow_canto := true) -> void:
	_end_action(allow_canto)

##标记已执行不可撤销的子行动（对话/交换/开启宝箱后调用；此后行动菜单按 no 不再撤回移动）
func mark_action_spent() -> void:
	_menu_action_spent = true

##是否已执行不可撤销的子行动（行动菜单按 no 时判断撤回还是待机）
func is_action_spent() -> bool:
	return _menu_action_spent

##标记本次行动为攻击（_end_action 据此选择 Canto 触发等级，读取后自动清零）
func mark_attack_action() -> void:
	_last_action_was_attack = true

##行动收尾唯一出口（P2）：清空选中上下文/范围层/光标限制并回 CURSOR，
##再检查胜负与玩家回合是否结束；_end_action 与 BattleCanto._finish_canto 共用
func finalize_action() -> void:
	selected_unit = null
	move_range = {}
	attack_range = []
	current_path = []
	cursor.restrict_to = {}
	range_drawer.clear_all(high_light_layer)
	state = State.CURSOR
	if not battle_over:
		_check_battle_end()
		if not battle_over:
			cursor.set_process(true)
			if phase == 0:
				phases.check_player_phase_end()

func save_game() -> void:
	save_requested.emit()

func save_selection_context(unit_key: String) -> Dictionary:
	return {"unit": unit_key,
		"pre_move": SAVE_CODEC.encode(_pre_move_cell), "spent": _menu_action_spent}

func restore_selection_context(data: Dictionary, restored: Dictionary) -> void:
	phase = 0
	state = State.CURSOR
	cursor.restrict_to = {}
	cursor.set_process(true)
	selected_unit = restored.get(data.get("unit", ""))
	if selected_unit != null:
		_pre_move_cell = SAVE_CODEC.decode(data.pre_move)
		_menu_action_spent = data.get("spent", false)
		attack_range = selected_unit.get_attack_range(tile_map, [selected_unit.cell])
		commands.show_action_menu()

func prompt_return_to_title() -> void:
	return_to_title_requested.emit()

##行动结束（selected_unit 可能已死于反击被移除，需判空）
##若单位拥有再移动技能且有剩余力，根据行动类型（攻击/非攻击）判断是否进入 CANTO 阶段
##allow_canto=false 时跳过再移动（待机：测试问题3，选择待机=主动放弃再移动）
func _end_action(allow_canto := true) -> void:
	commands.hide_forecast()
	commands.reset_forecast_cache()
	if commands.action_menu != null:
		commands.action_menu.close()
	var has_enemy := false
	for u in units:
		if u.team == 1:
			has_enemy = true
			break
	if not has_enemy:
		allow_canto = false
	var was_attack := _last_action_was_attack
	_last_action_was_attack = false
	if selected_unit != null and is_instance_valid(selected_unit) and not selected_unit.is_queued_for_deletion():

		##【笃行】特技判定：攻击后可以再次行动并攻击，每回合限一次
		if was_attack and selected_unit.has_method("has_act_again_skill") and selected_unit.has_act_again_skill() \
				and not selected_unit.relentless_advance_triggered_this_turn:
			selected_unit.relentless_advance_triggered_this_turn = true
			selected_unit.has_acted = false
			selected_unit.remove_grayscale()
			selected_unit.play_idle_animation()
			selected_unit.canto_remaining = selected_unit.get_effective_move()
			print("%s 触发【笃行】：本回合获得再次行动机会！" % selected_unit.unit_name)
			finalize_action()
			return

		var can_canto := false
		if was_attack:
			can_canto = selected_unit.can_canto_after_attack()
		else:
			can_canto = selected_unit.can_canto_after_non_attack()
		if allow_canto and can_canto and selected_unit.canto_remaining > 0:
			canto.enter_phase()
			return
		selected_unit.has_acted = true
		selected_unit.apply_grayscale()
		selected_unit.play_idle_animation()
	finalize_action()

##撤回移动：单位回到移动前位置并重新进入选中状态（行动菜单按 no 且未执行子行动时）
##坐标还原 + 重新选中（重算移动/攻击范围、重置子行动标记）收进 BM，外部不再触碰 _pre_move_cell / _select_unit
##调用方负责先关闭行动菜单
func undo_move() -> void:
	if selected_unit == null or not is_instance_valid(selected_unit) \
			or selected_unit.is_queued_for_deletion():
		return
	selected_unit.cell = _pre_move_cell
	selected_unit.global_position = Vector2(_pre_move_cell) * Global.TILE_SIZE
	_select_unit(selected_unit)

##简单对话/系统提示（无肖像）：村庄宝箱发奖提示、事件对话用（action_dialogue 经此调用）
func open_dialogue(speaker: String, lines: Array[String]) -> void:
	await interaction.open_dialogue(speaker, lines)

##正式对话（5E 重构）：lines 每项 {"speaker","text","side"}，portraits 说话人->肖像，bg 背景CG
##DIALOGUE 状态阻塞输入，播完恢复原状态
func play_dialogue(lines: Array, portraits: Dictionary = {}, bg_texture: Texture2D = null) -> void:
	await interaction.play_dialogue(lines, portraits, bg_texture)

func _process(_delta: float) -> void:
	if state == State.UNIT_SELECTED and selected_unit != null:
		_update_path_preview()
	elif state == State.TARGET_SELECT and selected_unit != null:
		commands.update_forecast()

func _update_path_preview() -> void:
	movement._update_path_preview()
