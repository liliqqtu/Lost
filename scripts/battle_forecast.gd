extends Node
## 战斗预览面板

##战斗预览面板：GBA 风格，布局节点在 level_0.tscn 的 CanvasLayer/Battle Preview 下用编辑器摆放
##直接读取 BattleCalculator.generate_battle_sequence() 的数据渲染，不重复计算
##HP 与 PowerAccuracyCriticalHit 是固定文字（HP 威力 命中 必杀），无需脚本更新

##换位时与屏幕左右边缘保留的间距
const PANEL_MARGIN := 2.0

##玩家方节点
@onready var _player_name: Label = $PlayerName
@onready var _player_dph: Label = $PlayerDPH
@onready var _player_weapon: TextureRect = $PlayerWeapon

##敌方节点
@onready var _enemy_name: Label = $EnemyName
@onready var _enemy_dph: Label = $EnemyDPH
@onready var _enemy_weapon: TextureRect = $EnemyWeapon
@onready var _enemy_weapon_name: Label = $EnemyWeaponName

##追击指示节点（Chase/TextureRect）
@onready var _chase: Control = get_node_or_null("Chase")
@onready var _chase_sprite = get_node_or_null("Chase/TextureRect")


##由外部传入面板根节点，按名称绑定子节点
func setup(panel: TextureRect = null) -> void:
	if panel != null and panel != self:
		_player_name = panel.get_node_or_null("PlayerName")
		_player_dph = panel.get_node_or_null("PlayerDPH")
		_player_weapon = panel.get_node_or_null("PlayerWeapon")
		_enemy_name = panel.get_node_or_null("EnemyName")
		_enemy_dph = panel.get_node_or_null("EnemyDPH")
		_enemy_weapon = panel.get_node_or_null("EnemyWeapon")
		_enemy_weapon_name = panel.get_node_or_null("EnemyWeaponName")
		_chase = panel.get_node_or_null("Chase")
		_chase_sprite = panel.get_node_or_null("Chase/TextureRect")
	self.visible = false
	if _chase != null:
		_chase.visible = false


##显示预览：attacker 为玩家操作单位，sequence 由 BattleCalculator 生成
func show_forecast(attacker: Unit, sequence: Array[Dictionary]) -> void:
	if sequence.is_empty():
		hide_forecast()
		return
	var defender: Unit = sequence[0]["defender"]

	var player_doubles := _has_double(sequence, attacker)
	var enemy_doubles := _has_double(sequence, defender)

	set_player_name(attacker)
	set_player_dph(_get_first_strike(sequence, attacker), attacker, player_doubles)
	set_player_weapon(attacker)

	set_enemy_name(defender)
	set_enemy_dph(_get_first_strike(sequence, defender), defender, enemy_doubles)
	set_enemy_weapon(defender)

	_update_chase(player_doubles, enemy_doubles, sequence, attacker, defender)

	self.visible = true


##隐藏预览面板
func hide_forecast() -> void:
	if _chase_sprite != null and _chase_sprite.has_method("stop_animation"):
		_chase_sprite.stop_animation()
	if _chase != null:
		_chase.visible = false
	self.visible = false


##左右换位：攻击方在屏幕左半边时面板放右侧，右半边时放左侧，避免遮挡攻击范围内的其他目标
##面板在 CanvasLayer 下，其坐标系即屏幕坐标系，不受游戏相机影响，只改 X 即可
func update_side(attacker: Unit, camera: Camera2D) -> void:
	var view_width: float = self.get_viewport().get_visible_rect().size.x
	var screen_x: float = attacker.global_position.x - camera.get_screen_center_position().x + view_width * 0.5
	if screen_x < view_width * 0.5:
		self.position.x = view_width - self.size.x - PANEL_MARGIN
	else:
		self.position.x = PANEL_MARGIN


##玩家方名字
func set_player_name(unit: Unit) -> void:
	_player_name.text = unit.unit_name


##玩家方四行数值：HP / 威力 / 命中 / 必杀，无打击时后三行显示 ——，追击在威力后加 ×2
func set_player_dph(strike: Dictionary, unit: Unit, doubles: bool) -> void:
	_player_dph.text = _dph_text(strike, unit, doubles)


##玩家方武器物品图片
func set_player_weapon(unit: Unit) -> void:
	_player_weapon.texture = _weapon_icon(unit.current_weapon)


##敌方名字
func set_enemy_name(unit: Unit) -> void:
	_enemy_name.text = unit.unit_name


##敌方四行数值：HP / 威力 / 命中 / 必杀，无法反击时后三行显示 ——，追击在威力后加 ×2
func set_enemy_dph(strike: Dictionary, unit: Unit, doubles: bool) -> void:
	_enemy_dph.text = _dph_text(strike, unit, doubles)


##敌方武器物品图片与武器名字
func set_enemy_weapon(unit: Unit) -> void:
	_enemy_weapon.texture = _weapon_icon(unit.current_weapon)
	_enemy_weapon_name.text = _weapon_name(unit.current_weapon)


##四行文本：HP 只显示当前值；命中/必杀不带 %；无打击（无法反击/已被击杀）时威力/命中/必杀显示 ——；追击由 Chase/TextureRect 浮动图标呈现
func _dph_text(strike: Dictionary, unit: Unit, _doubles: bool) -> String:
	var hp_line := str(unit.hp)
	if strike.is_empty():
		return "%s\n——\n——\n——" % hp_line
	var power_line := str(strike["damage"])
	return "%s\n%s\n%d\n%d" % [hp_line, power_line, strike["hit"], strike["crit"]]


##更新追击指示图标（Chase/TextureRect）：我方追击在右侧(64,48)，敌方追击在左侧(21,48)
func _update_chase(player_doubles: bool, enemy_doubles: bool, sequence: Array[Dictionary], attacker: Unit, defender: Unit) -> void:
	if _chase == null or _chase_sprite == null:
		return
	if player_doubles:
		_chase.position = Vector2(64, 48)
		_chase.visible = true
		var strikes := _count_strikes(sequence, attacker)
		var times := 4 if strikes >= 4 else 2
		if _chase_sprite.has_method("set_chase"):
			_chase_sprite.set_chase(times)
		else:
			_chase_sprite.visible = true
	elif enemy_doubles:
		_chase.position = Vector2(21, 48)
		_chase.visible = true
		var strikes := _count_strikes(sequence, defender)
		var times := 4 if strikes >= 4 else 2
		if _chase_sprite.has_method("set_chase"):
			_chase_sprite.set_chase(times)
		else:
			_chase_sprite.visible = true
	else:
		if _chase_sprite.has_method("stop_animation"):
			_chase_sprite.stop_animation()
		else:
			_chase_sprite.visible = false
		_chase.visible = false


func _count_strikes(sequence: Array[Dictionary], unit: Unit) -> int:
	var count := 0
	for strike in sequence:
		if strike["attacker"] == unit:
			count += 1
	return count


##从序列中找出该单位的第一次打击，找不到返回空字典
func _get_first_strike(sequence: Array[Dictionary], unit: Unit) -> Dictionary:
	for strike in sequence:
		if strike["attacker"] == unit:
			return strike
	return {}


##该单位在序列中是否有追击打击
func _has_double(sequence: Array[Dictionary], unit: Unit) -> bool:
	for strike in sequence:
		if strike["attacker"] == unit and strike["is_double"]:
			return true
	return false


func _weapon_name(weapon: Weapon) -> String:
	return weapon.display_name if weapon else "——"


func _weapon_icon(weapon: Weapon) -> Texture2D:
	return weapon.icon if weapon else null
