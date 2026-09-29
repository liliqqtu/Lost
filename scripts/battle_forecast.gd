extends Node
## 战斗预览面板
class_name BattleForecast

##战斗预览面板：GBA 风格，布局节点在 level_0.tscn 的 CanvasLayer/Battle Preview 下用编辑器摆放
##直接读取 BattleCalculator.generate_battle_sequence() 的数据渲染，不重复计算
##HP 与 PowerAccuracyCriticalHit 是固定文字（HP 威力 命中 必杀），无需脚本更新

##面板根节点（Battle Preview）
var _panel: TextureRect

##换位时与屏幕左右边缘保留的间距
const PANEL_MARGIN := 2.0

##玩家方节点
var _player_name: Label
var _player_dph: Label
var _player_weapon: TextureRect

##敌方节点
var _enemy_name: Label
var _enemy_dph: Label
var _enemy_weapon: TextureRect
var _enemy_weapon_name: Label


##由外部传入面板根节点，按名称绑定子节点
func setup(panel: TextureRect) -> void:
	_panel = panel
	_panel.visible = false
	_player_name = panel.get_node("PlayerName") as Label
	_player_dph = panel.get_node("PlayerDPH") as Label
	_player_weapon = panel.get_node("PlayerWeapon") as TextureRect
	_enemy_name = panel.get_node("EnemyName") as Label
	_enemy_dph = panel.get_node("EnemyDPH") as Label
	_enemy_weapon = panel.get_node("EnemyWeapon") as TextureRect
	_enemy_weapon_name = panel.get_node("EnemyWeaponName") as Label


##显示预览：attacker 为玩家操作单位，sequence 由 BattleCalculator 生成
func show_forecast(attacker: Unit, sequence: Array[Dictionary]) -> void:
	if sequence.is_empty():
		hide_forecast()
		return
	var defender: Unit = sequence[0]["defender"]

	set_player_name(attacker)
	set_player_dph(_get_first_strike(sequence, attacker), attacker, _has_double(sequence, attacker))
	set_player_weapon(attacker)

	set_enemy_name(defender)
	set_enemy_dph(_get_first_strike(sequence, defender), defender, _has_double(sequence, defender))
	set_enemy_weapon(defender)

	_panel.visible = true


##隐藏预览面板
func hide_forecast() -> void:
	_panel.visible = false


##左右换位：攻击方在屏幕左半边时面板放右侧，右半边时放左侧，避免遮挡攻击范围内的其他目标
##面板在 CanvasLayer 下，其坐标系即屏幕坐标系，不受游戏相机影响，只改 X 即可
func update_side(attacker: Unit, camera: Camera2D) -> void:
	var view_width: float = _panel.get_viewport().get_visible_rect().size.x
	var screen_x: float = attacker.global_position.x - camera.get_screen_center_position().x + view_width * 0.5
	if screen_x < view_width * 0.5:
		_panel.position.x = view_width - _panel.size.x - PANEL_MARGIN
	else:
		_panel.position.x = PANEL_MARGIN


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


##四行文本：HP 只显示当前值；命中/必杀不带 %；无打击（无法反击/已被击杀）时威力/命中/必杀显示 ——；追击在威力后加 ×2
func _dph_text(strike: Dictionary, unit: Unit, doubles: bool) -> String:
	var hp_line := str(unit.hp)
	if strike.is_empty():
		return "%s\n——\n——\n——" % hp_line
	var power_line := str(strike["damage"])
	if doubles:
		power_line += "×2"
	return "%s\n%s\n%d\n%d" % [hp_line, power_line, strike["hit"], strike["crit"]]


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
