class_name BattleAnimationFX
extends RefCounted

const Actions = preload("res://scripts/battle_animation_actions.gd")


## 战斗画面附加特效与辅助特写（自 battle_animation.gd 分包，严格保持单文件 500 行以内）：
## 负责 Boss 击破消灭震颤/光芒消散、战后经验条缓动填充、升级面板加点、法杖治愈与跳舞再动特写。

const EXP_BOX_SCENE := preload("res://scene/ui/exp_box.tscn")
const GRADE_UP_SCENE := preload("res://scene/ui/grade_up.tscn")

const EXP_FILL_PER_POINT := 0.04
const EXP_FILL_MIN := 0.3
const EXP_FILL_MAX := 1.2
const EXP_STAY := 0.3

var _exp_box: Control = null
var _grade_up: Control = null


## 挂载全屏 UI 覆盖层到 CanvasLayer
func attach_overlay(parent: Node2D, node: Control) -> void:
	if parent.get_parent() != null:
		parent.get_parent().add_child(node)
	else:
		parent.add_child(node)


## 战后经验条演出：经验从 old_exp 填到 new_exp（按 mod 100 显示）
func show_exp(parent: Node2D, old_exp: int, new_exp: int) -> void:
	if _exp_box == null:
		_exp_box = EXP_BOX_SCENE.instantiate()
		attach_overlay(parent, _exp_box)
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
	var tween := parent.create_tween()
	tween.tween_method(func(val: float):
		if _exp_box != null:
			bar.value = val
			label.text = str(int(val)), float(old_v), float(new_v), fill_time)
	await tween.finished
	await parent.get_tree().create_timer(EXP_STAY).timeout
	_exp_box.visible = false


## 升级演出：加载 grade_up 场景显示加点动画
func show_level_up(parent: Node2D, unit: Unit, gains: Dictionary) -> void:
	if _grade_up == null:
		_grade_up = GRADE_UP_SCENE.instantiate()
		attach_overlay(parent, _grade_up)
	await _grade_up.play_for(unit, gains)


## Boss 专属消灭/击破动画演出：剧烈震颤、持续明灭白光、红白交替、最后化为光芒消散
func play_boss_defeat_fx(parent: Node2D, sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		return
	var orig_pos := sprite.position
	var mat := sprite.material as ShaderMaterial

	for i in range(14):
		sprite.position = orig_pos + Vector2(randf_range(-3.0, 3.0), randf_range(-1.5, 1.5))
		if mat != null:
			mat.set_shader_parameter("flash_amount", 1.0 if (i % 2 == 0) else 0.0)
		await parent.get_tree().create_timer(0.04).timeout

	sprite.position = orig_pos
	if mat != null:
		mat.set_shader_parameter("flash_amount", 0.0)

	var tween := parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.7)
	tween.tween_property(sprite, "scale", sprite.scale * Vector2(1.15, 0.85), 0.7)
	await tween.finished
	sprite.visible = false
	sprite.scale = Vector2.ONE
	await parent.get_tree().create_timer(0.3).timeout


## 播放法杖治愈特写（神职人员举杖施法 -> 治愈光环升腾 -> 同伴生命回复）
func play_staff_heal(ba: Node2D, caster: Unit, target: Unit, _staff: Weapon, heal_amount: int) -> void:
	ba.player_unit = caster
	ba.enemy_unit = target
	ba.player_display_hp = caster.hp
	ba.enemy_display_hp = target.hp
	ba.position = ba.get_viewport().get_visible_rect().size / 2.0
	ba.modulate = Color.WHITE
	ba.visible = true

	ba._fill_side(caster, [], true)
	ba._fill_side(target, [], false)
	ba._setup_palette(ba.player_anim, caster.team)
	ba._setup_palette(ba.enemy_anim, target.team)

	ba.back_ground.texture = ba.DEFAULT_BG
	ba.player_terrain.texture = ba.DEFAULT_TERRAIN
	ba.enemy_terrain.texture = ba.DEFAULT_TERRAIN
	await ba.get_tree().create_timer(ba.INTRO_DELAY).timeout

	# 1. 施法者播放 staff 动作
	if ba.player_anim.sprite_frames != null and ba.player_anim.sprite_frames.has_animation(&"staff"):
		ba.player_anim.animation = &"staff"
		ba.player_anim.frame = 0
		ba.player_anim.play()
	elif ba.player_anim.sprite_frames != null and ba.player_anim.sprite_frames.has_animation(&"magic_start"):
		ba.player_anim.animation = &"magic_start"
		ba.player_anim.frame = 0
		ba.player_anim.play()

	# 2. 目标处播放治愈光效
	if ba.magic_anim.sprite_frames != null and ba.magic_anim.sprite_frames.has_animation(&"heal"):
		ba.magic_anim.animation = &"heal"
		ba.magic_anim.frame = 0
		ba.magic_anim.visible = true
		ba.magic_anim.play()
		await ba.get_tree().create_timer(0.35).timeout

	# 3. 目标血量增长与受击闪白明灭
	var new_hp := mini(target.hp + heal_amount, target.max_hp)
	ba._set_display_hp(target, new_hp)
	ba._flash_white(ba.enemy_anim, 2)

	if ba.magic_anim.visible and ba.magic_anim.is_playing():
		await ba.magic_anim.animation_finished
	ba.magic_anim.visible = false

	if ba.player_anim.is_playing() and not ba.player_anim.sprite_frames.get_animation_loop(ba.player_anim.animation):
		await ba.player_anim.animation_finished
	Actions.restore_idle(ba.player_anim, caster)
	await ba.get_tree().create_timer(0.2).timeout


## 播放舞者/诗人跳舞再动特写（舞姿翩跹 -> 灵光微闪 -> 唤醒同伴再次行动）
func play_dance_refresh(ba: Node2D, dancer: Unit, target: Unit, _action_label: String) -> void:
	ba.player_unit = dancer
	ba.enemy_unit = target
	ba.player_display_hp = dancer.hp
	ba.enemy_display_hp = target.hp
	ba.position = ba.get_viewport().get_visible_rect().size / 2.0
	ba.modulate = Color.WHITE
	ba.visible = true

	ba._fill_side(dancer, [], true)
	ba._fill_side(target, [], false)
	ba._setup_palette(ba.player_anim, dancer.team)
	ba._setup_palette(ba.enemy_anim, target.team)

	ba.back_ground.texture = ba.DEFAULT_BG
	ba.player_terrain.texture = ba.DEFAULT_TERRAIN
	ba.enemy_terrain.texture = ba.DEFAULT_TERRAIN
	await ba.get_tree().create_timer(ba.INTRO_DELAY).timeout

	var anim := &"refresh"
	if ba.player_anim.sprite_frames != null:
		if ba.player_anim.sprite_frames.has_animation(&"dance"):
			anim = &"dance"
		elif ba.player_anim.sprite_frames.has_animation(&"play"):
			anim = &"play"
		ba.player_anim.animation = anim
		ba.player_anim.frame = 0
		ba.player_anim.play()

	ba._flash_white(ba.enemy_anim, 2)

	if ba.player_anim.is_playing() and not ba.player_anim.sprite_frames.get_animation_loop(ba.player_anim.animation):
		await ba.player_anim.animation_finished
	Actions.restore_idle(ba.player_anim, dancer)
	await ba.get_tree().create_timer(0.2).timeout
