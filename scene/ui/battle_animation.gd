extends Node2D

const Actions = preload("res://scripts/battle_animation_actions.gd")
const Playback = preload("res://scene/ui/battle_animation_playback.gd")

##"""战斗动画场景脚本（阶段五 5A）：地图 -> 战斗画面切换的演出"""
##"""读取 BattleManager 传入的战斗序列数据渲染（与预览同源，禁止重新计算数值）"""

##==================== 可调演出参数（时间单位：秒） ====================
const INTRO_DELAY := 0.3 ##开场停留
const STRIKE_GAP := 0.15 ##每一击间隔
const NO_ANIM_STRIKE_DELAY := 0.4 ##无动画占位等待
const FLASH_INTERVAL := 0.06 ##受击闪白时长
const DEATH_FADE := 0.4 ##血量归零淡出
const CLOSE_FADE := 0.25 ##战斗结束淡出
const MISS_STAY := 0.35 ##MISS 标签停留
const MISS_SHAKE := 2.0 ##MISS 晃动幅度

##默认战斗背景与脚下地形图（目前只有草地，新地形在下面两张表补条目）
const DEFAULT_BG := preload("res://assets/graphics/Battle bg/草地.png")
const DEFAULT_TERRAIN := preload("res://assets/graphics/Battle bg/草地地形.png")
##"""地形名 -> 战斗背景图，按防御方所在瓦片选取"""
const TERRAIN_BG := {}
##"""地形名 -> 双方脚下地形小图"""
const TERRAIN_SPRITE := {}

## 兼容旧模块的武器名映射；实际动作选择集中在 BattleAnimationActions。
const WEAPON_ANIM := {
	Weapon.WeaponType.SWORD: "sword",
	Weapon.WeaponType.LANCE: "lance",
	Weapon.WeaponType.AXE: "axe",
	Weapon.WeaponType.BOW: "bow",
	Weapon.WeaponType.ANIMA: "anima",
	Weapon.WeaponType.DARK: "dark",
	Weapon.WeaponType.LIGHT: "light",
	Weapon.WeaponType.STAFF: "staff",
}

##"""魔法武器类型（ANIMA/DARK/LIGHT）：演出走 施法起手 -> 循环施法 + 特效/命中轨道 -> 收手 三段流程"""
const MAGIC_WEAPON_TYPES := [
	Weapon.WeaponType.ANIMA,
	Weapon.WeaponType.DARK,
	Weapon.WeaponType.LIGHT,
]
##"""武器名 -> 魔法特效动画名（Magic_frames 里的动画）"""
##"""新魔法两种接法：在这里加一行，或直接在 Magic_frames 里建与武器同名的动画"""
const MAGIC_EFFECT_ANIM := {
	"火炎": "fire", "火焰": "fire", "fire": "fire",
	"闪电": "thunder", "雷电": "thunder", "thunder": "thunder",
	"疾风": "wind", "暴风": "wind", "wind": "wind",
	"烈火": "elfire", "业火": "elfire", "elfire": "elfire",
	"熔流": "flux", "暗黑": "flux", "flux": "flux",
	"闪光": "lightning", "神圣": "lightning", "luce": "lightning", "lightning": "lightning",
	"回复之杖": "heal", "治愈之杖": "heal", "回复": "heal", "heal": "heal",
}

##魔法打击爆发帧定时（无 AnimationPlayer 函数轨道时的通用命中兜底时机，单位：秒）
const SPELL_IMPACT_TIMINGS := {
	"fire": 0.45, "thunder": 0.50, "wind": 0.40, "elfire": 0.55,
	"flux": 0.45, "lightning": 0.50, "luce": 0.50, "heal": 0.35,
}

##战斗动画调色着色器（敌方红色调色 + 受击闪白，参数由脚本按 unit.team 驱动）
const BATTLE_SHADER := preload("res://data/shader/battle_animation.gdshader")

##战斗特效与升级过场辅助（自 battle_animation_fx.gd 分包）
var fx := BattleAnimationFX.new()

##交战双方（右侧恒为我方/友军视角，与场景节点布局一致）
var player_unit: Unit = null
var enemy_unit: Unit = null
## 画面血量由命中事件更新；真实 HP 仍由 BattleCombat 提交。
var player_display_hp := 0
var enemy_display_hp := 0

@onready var back_ground: Sprite2D = $BackGround
@onready var player_terrain: Sprite2D = $PlayerTerrain
@onready var enemy_terrain: Sprite2D = $EnemyTerrain
@onready var player_anim: AnimatedSprite2D = $PlayTreamAnimation
@onready var enemy_anim: AnimatedSprite2D = $EnemyTreamAnimation
@onready var magic_anim: AnimatedSprite2D = $MagicAnimation
@onready var battle_screen: Sprite2D = $BattleScreen
@onready var player_name_label: Label = $BattleScreen/PlayerName
@onready var player_hit_label: Label = $BattleScreen/PlayerHIT
@onready var player_dmg_label: Label = $BattleScreen/PlayerDMG
@onready var player_crt_label: Label = $BattleScreen/PlayerCRT
@onready var player_weapon_name_label: Label = $BattleScreen/PlayerWeaponName
@onready var player_hp_label: Label = $BattleScreen/PlayerHP
@onready var player_health_bar: TextureProgressBar = $BattleScreen/PlayerHealthBar
@onready var player_weapon_icon: TextureRect = $BattleScreen/PlayerWeaponIcon
@onready var enemy_name_label: Label = $BattleScreen/EnemyName
@onready var enemy_hit_label: Label = $BattleScreen/EnemyHIT
@onready var enemy_dmg_label: Label = $BattleScreen/EnemyDMG
@onready var enemy_crt_label: Label = $BattleScreen/EnemyCRT
@onready var enemy_weapon_name_label: Label = $BattleScreen/EnemyWeaponName
@onready var enemy_hp_label: Label = $BattleScreen/EnemyHP
@onready var enemy_health_bar: TextureProgressBar = $BattleScreen/EnemyHealthBar
@onready var enemy_weapon_icon: TextureRect = $BattleScreen/EnemyWeaponIcon
@onready var player_miss_label: Label = $BattleScreen/PlayerMISS
@onready var enemy_miss_label: Label = $BattleScreen/EnemyMISS

##AnimationPlayer：函数轨道在武器挥击命中帧调用 on_impact（时机在 tscn 的动画库里标注）
@onready var anim_player: AnimationPlayer = $AnimationPlayer

##当前这一击的演出上下文：AnimationPlayer 命中回调与动画结束兜底结算共用
var _strike_attacker: Unit = null
var _strike_def_sprite: AnimatedSprite2D = null
var _strike_def_unit: Unit = null
var _strike_is_hit := false
var _strike_is_crit := false
var _strike_damage := 0
##该击是否已结算过（命中回调先触发；没配函数轨道时由 play_strike 播完动画后兜底）
var _impact_done := false
var _strike_serial := 0
var _reaction_tween: Tween

func _ready() -> void:
	##tscn 里 PlayTreamAnimation 开了 autoplay，进场先停住等 play() 安排
	player_anim.stop()
	enemy_anim.stop()
	anim_player.stop()
	##魔法特效节点默认隐藏，攻击时按武器选取特效动画播放
	magic_anim.stop()
	magic_anim.visible = false

##"""开场：填充全部标签/图标/动画资源/地形背景，居中显示后短暂停留"""
##"""attacker_terrain / defender_terrain：交战双方所在地形名（由 BattleManager 传入）"""
func play(attacker: Unit, defender: Unit, sequence: Array, attacker_terrain: String, defender_terrain: String) -> void:
	##右侧恒为我方（team 0）或者友军（team 2），敌方（team 1）在左
	player_unit = attacker if attacker.team != 1 else defender
	enemy_unit = defender if attacker.team != 1 else attacker

	player_display_hp = player_unit.hp
	enemy_display_hp = enemy_unit.hp

	##挂在 CanvasLayer 下即屏幕坐标，居中铺满 GBA 视口
	position = get_viewport().get_visible_rect().size / 2.0
	modulate = Color.WHITE
	visible = true

	_fill_side(player_unit, sequence, true)
	_fill_side(enemy_unit, sequence, false)

	##阵营调色按单位队伍决定（team 0蓝 / 1红 / 2绿），而非固定节点；两侧都挂同一着色器以支持受击闪白
	_setup_palette(player_anim, player_unit.team)
	_setup_palette(enemy_anim, enemy_unit.team)

	##背景按防御方所在地形选取，脚下小图按各自地形
	var player_terrain_name := attacker_terrain if player_unit == attacker else defender_terrain
	var enemy_terrain_name := attacker_terrain if enemy_unit == attacker else defender_terrain
	back_ground.texture = TERRAIN_BG.get(defender_terrain, DEFAULT_BG)
	player_terrain.texture = TERRAIN_SPRITE.get(player_terrain_name, DEFAULT_TERRAIN)
	enemy_terrain.texture = TERRAIN_SPRITE.get(enemy_terrain_name, DEFAULT_TERRAIN)

	await get_tree().create_timer(INTRO_DELAY).timeout

##"""战斗调色：按队伍阵营（0我方蓝 / 1敌方红 / 2友军绿）驱动着色器，兼容布尔入参"""
func _setup_palette(sprite: AnimatedSprite2D, team_arg: Variant) -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = BATTLE_SHADER
		sprite.material = mat
	var t: int = (1 if team_arg else 0) if typeof(team_arg) == TYPE_BOOL else int(team_arg)
	mat.set_shader_parameter("team", t)
	mat.set_shader_parameter("enemy_palette", t == 1)
	mat.set_shader_parameter("ally_palette", t == 2)
	mat.set_shader_parameter("flash_amount", 0.0)

##"""填充一侧的标签/血条/图标/动画资源（is_player=true 右侧我方视角）"""
func _fill_side(unit: Unit, sequence: Array, is_player: bool) -> void:
	var weapon: Weapon = unit.current_weapon

	if is_player:
		player_name_label.text = unit.unit_name
		player_weapon_name_label.text = _weapon_text(weapon)
		player_weapon_icon.texture = weapon.icon if weapon else null
		player_hp_label.text = str(unit.hp)
		player_health_bar.max_value = unit.max_hp
		player_health_bar.value = unit.hp
	else:
		enemy_name_label.text = unit.unit_name
		enemy_weapon_name_label.text = _weapon_text(weapon)
		enemy_weapon_icon.texture = weapon.icon if weapon else null
		enemy_hp_label.text = str(unit.hp)
		enemy_health_bar.max_value = unit.max_hp
		enemy_health_bar.value = unit.hp

	##命中/伤害/必杀直接读战斗序列里该方的第一击，无打击机会显示"——"
	var strike := _find_strike(sequence, unit)
	var hit_text := str(strike["hit"]) if not strike.is_empty() else "——"
	var dmg_text := str(strike["damage"]) if not strike.is_empty() else "——"
	var crt_text := str(strike["crit"]) if not strike.is_empty() else "——"
	if is_player:
		player_hit_label.text = hit_text
		player_dmg_label.text = dmg_text
		player_crt_label.text = crt_text
	else:
		enemy_hit_label.text = hit_text
		enemy_dmg_label.text = dmg_text
		enemy_crt_label.text = crt_text

	##动画资源：右侧不翻转（面向左），左侧翻转（面向右）
	var sprite := player_anim if is_player else enemy_anim
	if unit.battle_frames == null:
		sprite.visible = false
		sprite.sprite_frames = null
		return
	sprite.visible = true
	sprite.sprite_frames = unit.battle_frames
	Actions.restore_idle(sprite, unit,
		Actions.distance_is_ranged(player_unit, enemy_unit))
	sprite.flip_h = not is_player

##"""武器名 + 当前耐久（如 铁弓 40/40），无武器显示 ——"""
##"""开场时读一次（战斗序列开战前生成，战斗中途损坏不影响本场打击，显示同理）"""
func _weapon_text(weapon: Weapon) -> String:
	if weapon == null:
		return "——"
	return "%s %d/%d" % [weapon.display_name, weapon.durability, weapon.max_durability]

##"""取该单位在序列中的第一击（作为面板数值），无则返回空字典"""
func _find_strike(sequence: Array, unit: Unit) -> Dictionary:
	for strike in sequence:
		if strike["attacker"] == unit:
			return strike
	return {}

## 兼容旧调用：返回该武器的基础攻击名；待机统一由 Actions.restore_idle 处理。
func _pick_anim_name(frames: SpriteFrames, unit: Unit) -> StringName:
	return Actions.attack(frames, unit)

##"""单次打击演出：物理武器播放攻击动画 + AnimationPlayer 同名函数轨道；"""
##"""魔法武器走三段流程（起手 -> 循环施法 + 特效/命中轨道 -> 收手），见 _play_magic_strike"""
##"""命中/未命中的结算由 AnimationPlayer 在命中帧回调 on_impact() 触发（闪白+扣血 / MISS）；"""
##"""没配对应函数轨道（或命中帧晚于动画播完）时，播完动画后兜底结算一次"""
func play_strike(attacker: Unit, is_hit: bool, is_crit: bool, damage: int) -> void:
	_strike_serial += 1
	anim_player.stop()
	_reaction_tween = null
	##先记录本击上下文，供 on_impact() 命中回调读取
	_strike_attacker = attacker
	_strike_def_unit = enemy_unit if attacker == player_unit else player_unit
	_strike_def_sprite = enemy_anim if attacker == player_unit else player_anim
	_strike_is_hit = is_hit
	_strike_is_crit = is_crit
	_strike_damage = damage
	_impact_done = false
	var atk_sprite := player_anim if attacker == player_unit else enemy_anim
	if _is_magic_strike(attacker, atk_sprite):
		await _play_magic_strike(atk_sprite, is_crit)
	elif atk_sprite.sprite_frames != null:
		var action := Actions.attack(atk_sprite.sprite_frames, attacker,
			is_crit, is_hit, Actions.distance_is_ranged(player_unit, enemy_unit))
		if action != &"":
			atk_sprite.stop()
			atk_sprite.play(action)
			_play_impact_timeline(atk_sprite)
			await atk_sprite.animation_finished

	else:
		##无动画资源占位：固定等待
		await get_tree().create_timer(NO_ANIM_STRIKE_DELAY).timeout

	##动画播完还没被命中回调结算（无函数轨道/命中帧晚于播完）则兜底一次
	if not _impact_done:
		on_impact()

	anim_player.stop()
	await Playback.finish_reaction(self)
	if _reaction_tween != null and _reaction_tween.is_running():
		await _reaction_tween.finished
	Actions.restore_idle(atk_sprite, attacker,
		Actions.distance_is_ranged(player_unit, enemy_unit))
	_strike_serial += 1

	##被打方血量归零：整击动画结束后淡出（非 Boss 立即淡出，Boss 留给临终台词与专属击破动画）
	if _strike_is_hit and _strike_def_sprite != null and _get_display_hp(_strike_def_unit) <= 0:
		if not _strike_def_unit.is_boss:
			var tween := create_tween()
			tween.tween_property(_strike_def_sprite, "modulate:a", 0.0, DEATH_FADE)
			await tween.finished

	##清空上下文，防止迟到的回调串到下一击
	_strike_attacker = null
	_strike_def_sprite = null
	_strike_def_unit = null
	await get_tree().create_timer(STRIKE_GAP).timeout

## 魔法三段演出必须具备完整 start/loop/end，旧的完整动作可走单段流程。
func _is_magic_strike(attacker: Unit, atk_sprite: AnimatedSprite2D) -> bool:
	var weapon := attacker.current_weapon
	if weapon == null or atk_sprite.sprite_frames == null:
		return false
	if not MAGIC_WEAPON_TYPES.has(weapon.weapon_type):
		return false
	return (atk_sprite.sprite_frames.has_animation(&"magic_start")
		and atk_sprite.sprite_frames.has_animation(&"magic_loop")
		and atk_sprite.sprite_frames.has_animation(&"magic_end"))

##"""魔法三段演出：起手 -> 循环施法 + 魔法特效/命中轨道 -> 收手"""
##"""施法者 PlayTreamAnimation：magic_start 播完进 magic_loop 循环，特效播完切 magic_end 收手"""
##"""MagicAnimation 播放武器对应特效（火炎 -> fire），AnimationPlayer 同名函数轨道在命中帧回调 on_impact"""
func _play_magic_strike(atk_sprite: AnimatedSprite2D, is_crit: bool) -> void:
	await Playback.magic_strike(self, atk_sprite, is_crit)

##"""武器 -> 魔法特效动画名：MAGIC_EFFECT_ANIM 表 -> 与武器同名的特效动画 -> 特效帧第一个动画"""
func _magic_effect_name() -> StringName:
	var frames := magic_anim.sprite_frames
	if frames == null or frames.get_animation_names().is_empty():
		return &""
	if _strike_attacker != null:
		var weapon: Weapon = _strike_attacker.current_weapon
		if weapon != null:
			var mapped: String = MAGIC_EFFECT_ANIM.get(weapon.display_name, "")
			if frames.has_animation(StringName(mapped)):
				return StringName(mapped)
			##特效动画直接用武器名命名时也能命中（新魔法免加表）
			if frames.has_animation(StringName(weapon.display_name)):
				return StringName(weapon.display_name)
	return frames.get_animation_names()[0]

##"""启动魔法命中的 AnimationPlayer 函数轨道：Magic 库下与特效同名的动画"""
func _play_magic_timeline(effect_name: StringName) -> void:
	Playback.magic_timeline(self, effect_name)

##"""启动与攻击帧动画同步的 AnimationPlayer 函数轨道（命中帧回调 on_impact）"""
##"""动画库名取帧资源文件名去 _frames 后缀：Ranger_M_frames -> Ranger_M"""
func _play_impact_timeline(atk_sprite: AnimatedSprite2D) -> void:
	Playback.impact_timeline(self, atk_sprite)

##"""由帧资源路径推导 AnimationPlayer 动画库名"""
func _frames_library_name(frames: SpriteFrames) -> String:
	return frames.resource_path.get_file().trim_suffix(".tres").trim_suffix("_frames")

##"""打击命中帧回调（由 AnimationPlayer 函数轨道调用，命中与未命中都走这里）"""
##"""命中：受击闪白 + 画面血条开始扣减；未命中：显示攻击方 MISS 标签并晃动"""
func on_impact() -> void:
	if _impact_done or _strike_def_sprite == null:
		return
	_impact_done = true
	if _strike_is_hit:
		var new_hp := maxi(_get_display_hp(_strike_def_unit) - _strike_damage, 0)
		_set_display_hp(_strike_def_unit, new_hp)
		##受击闪白：必杀闪更多次
		_reaction_tween = _flash_white(_strike_def_sprite, 2)
	else:
		var dodge := Actions.dodge(_strike_def_sprite.sprite_frames, _strike_def_unit,
			Actions.distance_is_ranged(player_unit, enemy_unit))
		if dodge != &"":
			_strike_def_sprite.stop()
			_strike_def_sprite.play(dodge)
		_reaction_tween = _show_miss(_strike_attacker)

##"""受击闪白：Tween 驱动材质 flash_amount 明灭，times 为明灭次数（非阻塞）"""
func _flash_white(sprite: AnimatedSprite2D, times: int) -> Tween:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return null
	var tween := create_tween()
	for i in range(times):
		tween.tween_callback(mat.set_shader_parameter.bind("flash_amount", 1.0))
		tween.tween_interval(FLASH_INTERVAL)
		tween.tween_callback(mat.set_shader_parameter.bind("flash_amount", 0.0))
		tween.tween_interval(FLASH_INTERVAL)
	return tween

##"""未命中演出：显示攻击方对应的 MISS 标签（玩家攻击 miss 显示 PlayerMISS），短暂停留并轻微晃动"""
func _show_miss(attacker: Unit) -> Tween:
	var label := player_miss_label if attacker == player_unit else enemy_miss_label
	var base_x := label.position.x
	label.visible = true
	label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.08)
	tween.tween_property(label, "position:x", base_x + MISS_SHAKE, 0.05)
	tween.tween_property(label, "position:x", base_x - MISS_SHAKE, 0.05)
	tween.tween_property(label, "position:x", base_x + MISS_SHAKE * 0.5, 0.05)
	tween.tween_property(label, "position:x", base_x, 0.05)
	tween.tween_interval(MISS_STAY)
	tween.tween_property(label, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func():
		label.visible = false
		label.modulate.a = 1.0)
	return tween

##"""收尾：整场淡出隐藏，复位到下一场可用状态"""
func close() -> void:
	_strike_serial += 1
	anim_player.stop()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, CLOSE_FADE)
	await tween.finished
	visible = false
	modulate = Color.WHITE
	player_anim.modulate = Color.WHITE
	enemy_anim.modulate = Color.WHITE
	player_miss_label.visible = false
	player_miss_label.modulate.a = 1.0
	enemy_miss_label.visible = false
	enemy_miss_label.modulate.a = 1.0
	##魔法特效节点复位：隐藏并停帧，下一场从特效第一帧播起
	magic_anim.visible = false
	magic_anim.stop()
	_reset_flash(player_anim)
	_reset_flash(enemy_anim)

##"""复位受击闪白参数（材质可能未创建，安全调用）"""
func _reset_flash(sprite: AnimatedSprite2D) -> void:
	var mat := sprite.material as ShaderMaterial
	if mat != null:
		mat.set_shader_parameter("flash_amount", 0.0)

func _get_display_hp(unit: Unit) -> int:
	return player_display_hp if unit == player_unit else enemy_display_hp

##"""战后经验条演出（委托 fx）"""
func show_exp(old_exp: int, new_exp: int) -> void:
	await fx.show_exp(self, old_exp, new_exp)

##"""升级演出（委托 fx）"""
func show_level_up(unit: Unit, gains: Dictionary) -> void:
	await fx.show_level_up(self, unit, gains)

##"""更新画面血量：HP 标签 + TextureProgressBar"""
func _set_display_hp(unit: Unit, value: int) -> void:
	if unit == player_unit:
		player_display_hp = value
		player_hp_label.text = str(value)
		player_health_bar.value = value
	else:
		enemy_display_hp = value
		enemy_hp_label.text = str(value)
		enemy_health_bar.value = value

##"""Boss 专属消灭/击破动画演出（委托 fx）"""
func play_boss_defeat_fx(boss_unit: Unit) -> void:
	var sprite: AnimatedSprite2D = player_anim if boss_unit == player_unit else enemy_anim
	await fx.play_boss_defeat_fx(self, sprite)

##==================== 辅助特写：法杖治愈与跳舞再动（委托 fx） ====================

##"""播放法杖治愈特写（神职人员举杖施法 -> 治愈光环升腾 -> 同伴生命回复）"""
func play_staff_heal(caster: Unit, target: Unit, staff: Weapon, heal_amount: int) -> void:
	await fx.play_staff_heal(self, caster, target, staff, heal_amount)

##"""播放舞者/诗人跳舞再动特写（舞姿翩跹 -> 灵光微闪 -> 唤醒同伴再次行动）"""
func play_dance_refresh(dancer: Unit, target: Unit, action_label: String) -> void:
	await fx.play_dance_refresh(self, dancer, target, action_label)
