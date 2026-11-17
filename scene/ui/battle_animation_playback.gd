class_name BattleAnimationPlayback
extends RefCounted

const Actions = preload("res://scripts/battle_animation_actions.gd")


## Synchronizes actor clips, spell effects and per-resource impact markers.
## The scene retains its public methods and owns the strike result/context.
static func magic_strike(ba: Node2D, sprite: AnimatedSprite2D, critical: bool) -> void:
	var frames := sprite.sprite_frames
	var suffix := "_crit" if critical else ""
	var start := Actions.resolve(frames, "magic_start" + suffix)
	if start == &"":
		start = &"magic_start"
	sprite.play(start)
	sprite.set_frame_and_progress(0, 0.0)
	await sprite.animation_finished
	var loop := Actions.resolve(frames, "magic_loop" + suffix)
	if loop == &"":
		loop = &"magic_loop"
	sprite.play(loop)
	sprite.set_frame_and_progress(0, 0.0)
	var effect: StringName = ba._magic_effect_name()
	if ba.magic_anim.sprite_frames != null and ba.magic_anim.sprite_frames.has_animation(effect):
		ba.magic_anim.stop()
		ba.magic_anim.flip_h = sprite.flip_h
		ba.magic_anim.speed_scale = sprite.speed_scale
		ba.magic_anim.visible = true
		ba.magic_anim.play(effect)
		magic_timeline(ba, effect)
		await ba.magic_anim.animation_finished
		ba.magic_anim.visible = false
	var end := Actions.resolve(frames, "magic_end" + suffix)
	if end == &"":
		end = &"magic_end"
	sprite.play(end)
	sprite.set_frame_and_progress(0, 0.0)
	await sprite.animation_finished

static func schedule_impact(ba: Node2D, seconds: float, speed: float) -> void:
	var serial: int = ba._strike_serial
	ba.get_tree().create_timer(maxf(seconds / maxf(absf(speed), 0.001), 0.001)).timeout.connect(func():
		if is_instance_valid(ba) and serial == ba._strike_serial and not ba._impact_done:
			ba.on_impact())

static func magic_timeline(ba: Node2D, effect: StringName) -> void:
	var name := "Magic/%s" % effect
	if ba.anim_player != null and ba.anim_player.has_animation(name):
		ba.anim_player.speed_scale = ba.magic_anim.speed_scale
		ba.anim_player.play(name)
		return
	var timings: Dictionary = ba.SPELL_IMPACT_TIMINGS
	schedule_impact(ba, float(timings.get(str(effect), 0.45)), ba.magic_anim.speed_scale)

static func impact_timeline(ba: Node2D, sprite: AnimatedSprite2D) -> void:
	var frames := sprite.sprite_frames
	if frames == null:
		return
	var impacts: Dictionary = frames.get_meta("battle_animation_impacts", {})
	if impacts.has(str(sprite.animation)):
		schedule_impact(ba, float(impacts[str(sprite.animation)]), sprite.speed_scale)
		return
	# Hand-authored timelines are matched to this resource's own library only.
	# Borrowing another class's same-named track gives incorrect impact timing.
	var name := "%s/%s" % [ba._frames_library_name(frames), sprite.animation]
	if ba.anim_player != null and ba.anim_player.has_animation(name):
		ba.anim_player.speed_scale = sprite.speed_scale
		ba.anim_player.play(name)

static func finish_reaction(ba: Node2D) -> void:
	var sprite: AnimatedSprite2D = ba._strike_def_sprite
	if sprite == null or ba._strike_def_unit == null:
		return
	if str(sprite.animation).contains("_dodge") and sprite.is_playing():
		await sprite.animation_finished
	Actions.restore_idle(sprite, ba._strike_def_unit,
		Actions.distance_is_ranged(ba.player_unit, ba.enemy_unit))
