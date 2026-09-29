extends Node2D
##"""战斗动画场景脚本（阶段五 5A）：地图 -> 战斗画面切换的演出"""
##"""读取 BattleManager 传入的战斗序列数据渲染（与预览同源，禁止重新计算数值）"""

##==================== 可调演出参数（时间单位：秒） ====================
##开场：标签/资源就绪后到第一击前的停留
const INTRO_DELAY := 0.3
##每一击动画结束后的间隔
const STRIKE_GAP := 0.15
##无动画资源时每一击的占位等待
const NO_ANIM_STRIKE_DELAY := 0.4
##受击闪白的单次明灭时长
const FLASH_INTERVAL := 0.06
##血量归零后防御方淡出时长
const DEATH_FADE := 0.4
##战斗结束整场淡出时长
const CLOSE_FADE := 0.25
##MISS 标签停留时长（不含晃动与淡出）
const MISS_STAY := 0.35
##MISS 标签晃动幅度（像素）
const MISS_SHAKE := 2.0

##默认战斗背景与脚下地形图（目前只有草地，新地形在下面两张表补条目）
const DEFAULT_BG := preload("res://assets/graphics/Battle bg/草地.png")
const DEFAULT_TERRAIN := preload("res://assets/graphics/Battle bg/草地地形.png")
##"""地形名 -> 战斗背景图，按防御方所在瓦片选取"""
const TERRAIN_BG := {}
##"""地形名 -> 双方脚下地形小图"""
const TERRAIN_SPRITE := {}

##"""武器类型 -> 攻击动画名，帧资源里没有对应动画时退回第一个动画"""
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
	"火炎": "fire",
}

##战斗动画调色着色器（敌方红色调色 + 受击闪白，参数由脚本按 unit.team 驱动）
const BATTLE_SHADER := preload("res://data/shader/battle_animation.gdshader")

##==================== 经验/升级演出（升级系统） ====================
##经验条面板与升级面板（战斗结束后动态加载）
##注意：挂到父节点（CanvasLayer）下而不是自身——本场景是居中的 Node2D，
##Control 子节点会跟着位移半个屏幕，挂到 CanvasLayer 层级才能铺满视口
const EXP_BOX_SCENE := preload("res://scene/ui/exp_box.tscn")
const GRADE_UP_SCENE := preload("res://scene/ui/grade_up.tscn")
##经验条填充速度：每点经验秒数（总时长限制在 MIN..MAX 之间）
const EXP_FILL_PER_POINT := 0.04
const EXP_FILL_MIN := 0.3
const EXP_FILL_MAX := 1.2
##经验条播完后的停留
const EXP_STAY := 0.3

var _exp_box: Control = null
var _grade_up: Control = null

##交战双方（右侧恒为我方/友军视角，与场景节点布局一致）
var player_unit: Unit = null
var enemy_unit: Unit = null
##"""画面上显示的血量：动画播放结束后才更新（用户要求，伤害时机未在动画里标注）"""
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

	##敌方红色调色按单位队伍决定（team 1），而非固定节点；两侧都挂同一着色器以支持受击闪白
	_setup_palette(player_anim, player_unit.team == 1)
	_setup_palette(enemy_anim, enemy_unit.team == 1)

	##背景按防御方所在地形选取，脚下小图按各自地形
	var player_terrain_name := attacker_terrain if player_unit == attacker else defender_terrain
	var enemy_terrain_name := attacker_terrain if enemy_unit == attacker else defender_terrain
	back_ground.texture = TERRAIN_BG.get(defender_terrain, DEFAULT_BG)
	player_terrain.texture = TERRAIN_SPRITE.get(player_terrain_name, DEFAULT_TERRAIN)
	enemy_terrain.texture = TERRAIN_SPRITE.get(enemy_terrain_name, DEFAULT_TERRAIN)

	await get_tree().create_timer(INTRO_DELAY).timeout


##"""战斗调色：is_enemy=true（team 1 敌方）开启着色器红色调色；两侧都挂同一着色器以支持受击闪白"""
##"""我方精灵 tscn 里没配材质，运行时新建；敌方复用 tscn 已配的 ShaderMaterial"""
func _setup_palette(sprite: AnimatedSprite2D, is_enemy: bool) -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		mat = ShaderMaterial.new()
		mat.shader = BATTLE_SHADER
		sprite.material = mat
	mat.set_shader_parameter("enemy_palette", is_enemy)
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
	sprite.animation = _pick_anim_name(unit.battle_frames, unit)
	sprite.stop()
	sprite.frame = 0
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


##"""武器类型对应的动画名，资源里没有时退回第一个动画"""
##"""魔法单位待机/收场姿态用 magic_start 第 0 帧（站立姿势），与三段演出的起手帧无缝衔接"""
func _pick_anim_name(frames: SpriteFrames, unit: Unit) -> StringName:
	var anim_name := ""
	var weapon := unit.current_weapon
	if weapon:
		if MAGIC_WEAPON_TYPES.has(weapon.weapon_type):
			if frames.has_animation(&"magic_start"):
				return &"magic_start"
			if frames.has_animation(&"magic_loop"):
				return &"magic_loop"
		anim_name = WEAPON_ANIM.get(weapon.weapon_type, "")
	if frames.has_animation(anim_name):
		return StringName(anim_name)
	return frames.get_animation_names()[0]


##"""单次打击演出：物理武器播放攻击动画 + AnimationPlayer 同名函数轨道；"""
##"""魔法武器走三段流程（起手 -> 循环施法 + 特效/命中轨道 -> 收手），见 _play_magic_strike"""
##"""命中/未命中的结算由 AnimationPlayer 在命中帧回调 on_impact() 触发（闪白+扣血 / MISS）；"""
##"""没配对应函数轨道（或命中帧晚于动画播完）时，播完动画后兜底结算一次"""
func play_strike(attacker: Unit, is_hit: bool, is_crit: bool, damage: int) -> void:
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
		atk_sprite.frame = 0
		if is_crit:
			var base = str(atk_sprite.animation)
			var crit_anim = base + "_crit"               
			if atk_sprite.sprite_frames.has_animation(crit_anim):
				atk_sprite.animation = crit_anim
		atk_sprite.play()
		_play_impact_timeline(atk_sprite)
		await atk_sprite.animation_finished
	else:
		##无动画资源占位：固定等待
		await get_tree().create_timer(NO_ANIM_STRIKE_DELAY).timeout

	##动画播完还没被命中回调结算（无函数轨道/命中帧晚于播完）则兜底一次
	if not _impact_done:
		on_impact()

	##被打方血量归零：整击动画结束后淡出
	if _strike_is_hit and _strike_def_sprite != null and _get_display_hp(_strike_def_unit) <= 0:
		var tween := create_tween()
		tween.tween_property(_strike_def_sprite, "modulate:a", 0.0, DEATH_FADE)
		await tween.finished

	##清空上下文，防止迟到的回调串到下一击
	_strike_attacker = null
	_strike_def_sprite = null
	_strike_def_unit = null
	await get_tree().create_timer(STRIKE_GAP).timeout


##"""是否走魔法三段演出：魔法武器类型 + 施法者帧资源里有 magic_start 动画（缺任一则退回物理流程）"""
func _is_magic_strike(attacker: Unit, atk_sprite: AnimatedSprite2D) -> bool:
	var weapon := attacker.current_weapon
	if weapon == null or atk_sprite.sprite_frames == null:
		return false
	if not MAGIC_WEAPON_TYPES.has(weapon.weapon_type):
		return false
	return atk_sprite.sprite_frames.has_animation(&"magic_start")


##"""魔法三段演出：起手 -> 循环施法 + 魔法特效/命中轨道 -> 收手"""
##"""施法者 PlayTreamAnimation：magic_start 播完进 magic_loop 循环，特效播完切 magic_end 收手"""
##"""MagicAnimation 播放武器对应特效（火炎 -> fire），AnimationPlayer 同名函数轨道在命中帧回调 on_impact"""
func _play_magic_strike(atk_sprite: AnimatedSprite2D,is_crit: bool) -> void:
	##1 起手：magic_start 播完才进入施法循环
	if is_crit:
		atk_sprite.animation = &"magic_start_crit"
	else:
		atk_sprite.animation = &"magic_start"
	atk_sprite.frame = 0
	atk_sprite.play()
	await atk_sprite.animation_finished

	##2 循环施法：magic_loop 循环播放（不等它结束，等特效）
	atk_sprite.animation = &"magic_loop"
	atk_sprite.frame = 0
	atk_sprite.play()

	##3 魔法特效：按武器选取特效动画，特效随攻击方向镜像
	var effect_name := _magic_effect_name()
	if magic_anim.sprite_frames != null and magic_anim.sprite_frames.has_animation(effect_name):
		magic_anim.animation = effect_name
		magic_anim.frame = 0
		magic_anim.flip_h = atk_sprite.flip_h
		magic_anim.visible = true
		magic_anim.play()
		##命中轨道：Magic 库下与特效同名的函数轨道（Magic/fire 在 0.45s 回调 on_impact）
		_play_magic_timeline(effect_name)
		await magic_anim.animation_finished
		magic_anim.visible = false

	##4 收手：magic_end 播完本击演出结束
	atk_sprite.animation = &"magic_end"
	atk_sprite.frame = 0
	atk_sprite.play()
	await atk_sprite.animation_finished
	##收手播完回到待机姿态：切回 magic_start 第 0 帧（站立）
	##不能只 stop()：Godot 4 的 stop() 会把当前动画复位到第 0 帧（= magic_end 起手姿势），造成"闪现"
	atk_sprite.animation = &"magic_start"
	atk_sprite.stop()
	atk_sprite.frame = 0


##"""武器 -> 魔法特效动画名：MAGIC_EFFECT_ANIM 表 -> 与武器同名的特效动画 -> 特效帧第一个动画"""
func _magic_effect_name() -> StringName:
	var frames := magic_anim.sprite_frames
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
	if anim_player == null:
		return
	var full_name := "Magic/%s" % effect_name
	if anim_player.has_animation(full_name):
		anim_player.play(full_name)
		return
	##兜底：按动画名匹配任意库
	for anim_name in anim_player.get_animation_list():
		if String(anim_name).ends_with("/" + String(effect_name)):
			anim_player.play(anim_name)
			return


##"""启动与攻击帧动画同步的 AnimationPlayer 函数轨道（命中帧回调 on_impact）"""
##"""动画库名取帧资源文件名去 _frames 后缀：Ranger_M_frames -> Ranger_M"""
func _play_impact_timeline(atk_sprite: AnimatedSprite2D) -> void:
	if anim_player == null or atk_sprite.sprite_frames == null:
		return
	var frames: SpriteFrames = atk_sprite.sprite_frames
	var full_name := "%s/%s" % [_frames_library_name(frames), atk_sprite.animation]
	if anim_player.has_animation(full_name):
		anim_player.play(full_name)
		return
	##库里没有同名动画时退回：按动画名匹配任意库（动画名=武器名时最可靠）
	for anim_name in anim_player.get_animation_list():
		if String(anim_name).ends_with("/" + String(atk_sprite.animation)):
			anim_player.play(anim_name)
			return


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
		_flash_white(_strike_def_sprite, 2)
	else:
		_show_miss(_strike_attacker)


##"""受击闪白：Tween 驱动材质 flash_amount 明灭，times 为明灭次数（非阻塞）"""
func _flash_white(sprite: AnimatedSprite2D, times: int) -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return
	var tween := create_tween()
	for i in range(times):
		tween.tween_callback(mat.set_shader_parameter.bind("flash_amount", 1.0))
		tween.tween_interval(FLASH_INTERVAL)
		tween.tween_callback(mat.set_shader_parameter.bind("flash_amount", 0.0))
		tween.tween_interval(FLASH_INTERVAL)


##"""未命中演出：显示攻击方对应的 MISS 标签（玩家攻击 miss 显示 PlayerMISS），短暂停留并轻微晃动"""
func _show_miss(attacker: Unit) -> void:
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


##"""收尾：整场淡出隐藏，复位到下一场可用状态"""
func close() -> void:
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


##"""战后经验条演出：经验从 old_exp 填到 new_exp（按 mod 100 显示），条与数字同步填充
##跨级时本段先填满 100（升级面板播放后由调用方继续下一段）"""
func show_exp(old_exp: int, new_exp: int) -> void:
	if _exp_box == null:
		_exp_box = EXP_BOX_SCENE.instantiate()
		_attach_overlay(_exp_box)
	_exp_box.visible = true
	var bar: TextureProgressBar = _exp_box.get_node("ExpBar")
	var label: Label = _exp_box.get_node("Exp")
	var old_v := old_exp % 100
	var new_v := new_exp % 100
	if new_exp >= 100 or new_v < old_v:
		new_v = 100
	bar.max_value = 100
	bar.value = old_v
	label.text = str(old_v)
	var fill_time := clampf((new_v - old_v) * EXP_FILL_PER_POINT, EXP_FILL_MIN, EXP_FILL_MAX)
	var tween := create_tween()
	tween.tween_method(_set_exp_display, float(old_v), float(new_v), fill_time)
	await tween.finished
	await get_tree().create_timer(EXP_STAY).timeout
	_exp_box.visible = false


##"""经验条填充回调：同步更新进度条与数字"""
func _set_exp_display(value: float) -> void:
	if _exp_box == null:
		return
	(_exp_box.get_node("ExpBar") as TextureProgressBar).value = value
	(_exp_box.get_node("Exp") as Label).text = str(int(value))


##"""升级演出：加载 grade_up 场景显示加点动画（gains 为 BattleCalculator.roll_level_up 结果）"""
func show_level_up(unit: Unit, gains: Dictionary) -> void:
	if _grade_up == null:
		_grade_up = GRADE_UP_SCENE.instantiate()
		_attach_overlay(_grade_up)
	await _grade_up.play_for(unit, gains)


##"""全屏 UI 挂到父节点（CanvasLayer）下：挂自身会被居中的 Node2D 位移"""
func _attach_overlay(node: Control) -> void:
	if get_parent() != null:
		get_parent().add_child(node)
	else:
		add_child(node)


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
