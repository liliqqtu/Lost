class_name BattleMapInteraction
extends RefCounted

##地图交互（自 battle_manager.gd 分包，阶段五 5E）：村庄/宝箱访问、人物对话。
##负责行动菜单附加项探测（访问/开启/对话）、交互执行（消耗钥匙/发放奖励）
##与对话播放（系统提示/人物对话/事件对话共用 talk 场景）。

var bm: BattleManager
##对话场景（5E 重构：talk.tscn 替代旧 dialogue_box，系统提示/人物对话/事件对话共用）
var talk_scene: Node = null
##人物对话数据提供者（5E）：关卡侧注入 func(unit, target) -> Dictionary
##返回 {"lines": [{"speaker","text","side"}...], "portraits": {说话人: Texture2D}}，空字典=无对话
var talk_provider: Callable
##当前可交互的村庄/宝箱（gather_menu_extras 探测，do_interaction 消费）
var _pending_interactable: Interactable = null


##行动菜单附加项探测：脚下村庄/宝箱（宝箱需背包有对应钥匙）+ 邻接对话目标 + 邻接支援目标
##返回顺序：访问 → 开启 → 对话 → 支援（与原 battle_manager._show_action_menu 一致）
func gather_menu_extras(unit: Unit) -> Array[String]:
	var extras: Array[String] = []
	if unit == null:
		return extras
	##村庄直接可访问（5E bugfix：脚下方块判定，不是邻接）；宝箱需要背包里有对应钥匙
	_pending_interactable = _standing_interactable(unit)
	if _pending_interactable != null:
		if _pending_interactable.kind == Interactable.Kind.VILLAGE:
			extras.append("访问")
		elif _pending_interactable.kind == Interactable.Kind.CHEST \
				and _find_key(unit, _pending_interactable.key_id) != null:
			extras.append("开启")
	##对话目标按 talk 字段互指
	if _adjacent_talk_target(unit) != null:
		extras.append("对话")
	##支援目标（5G）：邻接同队、支援表登记、支援值达下一级门槛
	if _adjacent_support_target(unit) != null:
		extras.append("支援")
	return extras


##脚下瓦片查找未使用的可交互物（村庄/宝箱，interactables 组）——单位必须站在民居/宝箱格上才能访问/开启
func _standing_interactable(unit: Unit) -> Interactable:
	for node in bm.get_tree().get_nodes_in_group("interactables"):
		var it := node as Interactable
		if it == null or it.used:
			continue
		if unit.cell == it.cell:
			return it
	return null


##单位背包里找能开指定宝箱的钥匙
func _find_key(unit: Unit, key_id: String) -> Key:
	if unit == null:
		return null
	for item in unit.inventory:
		var k := item as Key
		if k != null and k.key_id == key_id:
			return k
	return null


##四邻接查找可对话单位（双方 talk 字段互指对方名字即触发）
func _adjacent_talk_target(unit: Unit) -> Unit:
	for d in Global.directions:
		var other := bm.get_unit_at(unit.cell + d)
		if other == null or other == unit:
			continue
		if unit.talk != "" and unit.talk == other.unit_name:
			return other
		if other.talk != "" and other.talk == unit.unit_name:
			return other
	return null


##四邻接查找可支援单位（5G）：同队 + 支援表登记 + 支援值达下一级门槛（SupportStore 查表）
func _adjacent_support_target(unit: Unit) -> Unit:
	for d in Global.directions:
		var other := bm.get_unit_at(unit.cell + d)
		if other == null or other == unit or other.team != unit.team:
			continue
		if SupportStore.can_level_up(unit.unit_name, other.unit_name):
			return other
	return null


##支援对话（5G）：两人相邻且支援值达下一级门槛时行动菜单出现"支援"项
##播放对应等级的支援对话（数据在支援表 SupportPair 的 c/b/a_lines）后支援等级 +1
##不结束行动（同"对话"行为修正）：播完回到行动菜单可继续选择；talk 字段不动（支援与人物对话互不影响）
func do_support() -> void:
	bm.commands.action_menu.close()
	var target := _adjacent_support_target(bm.selected_unit)
	if target == null:
		bm.commands.show_action_menu()
		return
	var pair := SupportStore.find_pair(bm.selected_unit.unit_name, target.unit_name)
	if pair == null:
		bm.commands.show_action_menu()
		return
	##先升级再播对话（对话内容取升级后等级的 c/b/a_lines）
	var next_level := SupportStore.get_level(bm.selected_unit.unit_name, target.unit_name) + 1
	SupportStore.level_up(bm.selected_unit.unit_name, target.unit_name)
	var lines: Array = pair.lines_for_level(next_level)
	if not lines.is_empty():
		var portraits := {
			bm.selected_unit.unit_name: pair.card_of(bm.selected_unit.unit_name),
			target.unit_name: pair.card_of(target.unit_name),
		}
		await play_dialogue(lines, portraits)
	##回到行动菜单继续行动（支援值已消费在等级上，门槛未到前"支援"项不再出现）
	bm.mark_action_spent()
	bm.commands.show_action_menu()


##访问村庄 / 开启宝箱：消耗钥匙（宝箱）、发放奖励（背包满进运输队）、对话框提示、结束行动
func do_interaction() -> void:
	if _pending_interactable == null or bm.selected_unit == null:
		return
	bm.commands.action_menu.close()
	var it := _pending_interactable
	_pending_interactable = null
	if it.kind == Interactable.Kind.CHEST:
		var key := _find_key(bm.selected_unit, it.key_id)
		if key == null:
			return
		bm.selected_unit.remove_item(key)
	it.used = true
	var got := ""
	if it.reward != null:
		var reward: Item = it.reward.duplicate() as Item
		if not bm.selected_unit.add_item(reward):
			ConvoyStore.add(reward)
		got = reward.display_name
	if got != "":
		await open_dialogue("", ["获得了%s！" % got])
	else:
		await open_dialogue("", ["空无一物……"])
	bm.end_action()


##人物对话（5E 重构）：从关卡注入的 provider 取对话数据（lines+portraits）播放
##对话过一次后清空双方 talk 字段（FE 惯例防重复触发；要反复测试就恢复 tscn 里的 talk 值）
##测试问题1 修复：对话不消耗行动——播完回到行动菜单，单位可继续选择（攻击/物品/待机）；
##非焕发单位本来就无法再次移动，焕发单位在攻击/用物品等行动结束后才按规则再移动
func do_talk() -> void:
	bm.commands.action_menu.close()
	var target := _adjacent_talk_target(bm.selected_unit)
	if target == null:
		bm.end_action()
		return
	bm.selected_unit.talk = ""
	target.talk = ""
	# talk_provider 该函数是否存在且可调用
	if talk_provider.is_valid():
		var data: Dictionary = talk_provider.call(bm.selected_unit, target)
		if data != null and data.has("lines") and not data["lines"].is_empty():
			await play_dialogue(data["lines"], data.get("portraits", {}))
	##回到行动菜单继续行动（talk 已清空，"对话"项不会再出现）
	##已执行过对话：此后行动菜单按 no 不再撤回移动，直接待机
	bm.mark_action_spent()
	bm.commands.show_action_menu()


##简单对话/系统提示（无肖像）：转成 talk 场景格式播放（村庄宝箱发奖提示、事件对话用）
func open_dialogue(speaker: String, lines: Array[String]) -> void:
	var data: Array = []
	for line in lines:
		data.append({"speaker": speaker, "text": line})
	await play_dialogue(data)


##正式对话（5E 重构）：lines 每项 {"speaker","text","side"}，portraits 说话人->肖像，bg 背景CG
##DIALOGUE 状态阻塞输入，播完恢复原状态
func play_dialogue(lines: Array, portraits: Dictionary = {}, bg_texture: Texture2D = null) -> void:
	if talk_scene == null:
		return
	var prev := bm.state
	bm.state = BattleManager.State.DIALOGUE
	bm.cursor.set_process(false)
	talk_scene.open(lines, portraits, bg_texture)
	await talk_scene.closed
	bm.state = prev
