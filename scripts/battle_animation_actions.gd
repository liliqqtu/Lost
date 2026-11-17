class_name BattleAnimationActions
extends RefCounted

## Canonical action selection. Legacy names are resolved here, never duplicated
## into SpriteFrames. This module does not calculate damage or mutate equipment.
const PREFIXES := ["sword", "lance", "axe", "bow", "magic", "staff", "refresh", "dragonstone"]
const WEAPONS := {Weapon.WeaponType.SWORD: "sword", Weapon.WeaponType.LANCE: "lance",
	Weapon.WeaponType.AXE: "axe", Weapon.WeaponType.BOW: "bow", Weapon.WeaponType.STAFF: "staff",
	Weapon.WeaponType.ANIMA: "magic", Weapon.WeaponType.DARK: "magic", Weapon.WeaponType.LIGHT: "magic"}

static func resolve(frames: SpriteFrames, name: String) -> StringName:
	if frames == null:
		return &""
	if frames.has_animation(name):
		return StringName(name)
	var aliases: Dictionary = frames.get_meta("battle_animation_aliases", {})
	var target: String = aliases.get(name, "")
	if frames.has_animation(target):
		return StringName(target)
	# Resources authored before the normalization tool remain supported.
	for legacy in [name.replace("_crit", "_critical") if name.ends_with("_crit") else "",
		name.trim_suffix("_idle") + "_stand" if name.ends_with("_idle") else ""]:
		if frames.has_animation(legacy):
			return StringName(legacy)
	return &""

static func prefix(frames: SpriteFrames, unit: Unit) -> String:
	if unit.current_weapon != null:
		var preferred: String = WEAPONS.get(unit.current_weapon.weapon_type, "")
		for suffix in ["", "_start", "_ranged", "_idle"]:
			if resolve(frames, preferred + suffix) != &"":
				return preferred
	for candidate in PREFIXES:
		for suffix in ["", "_start", "_ranged", "_idle"]:
			if resolve(frames, candidate + suffix) != &"":
				return candidate
	return ""

static func attack(frames: SpriteFrames, unit: Unit, critical := false,
		hit := true, ranged := false) -> StringName:
	var base := prefix(frames, unit)
	var candidates: Array[String] = []
	if not hit:
		candidates.append(base + "_miss")
	if ranged:
		if critical:
			candidates.append(base + "_ranged_crit")
		candidates.append(base + "_ranged")
	if critical:
		candidates.append(base + "_crit")
	candidates.append_array([base, base + "_start", base + "_ranged"])
	for name in candidates:
		var found := resolve(frames, name)
		if found != &"":
			return found
	return &""

static func idle(frames: SpriteFrames, unit: Unit, ranged := false) -> StringName:
	var base := prefix(frames, unit)
	var candidates: Array[String] = []
	if ranged:
		candidates.append(base + "_idle_ranged")
	candidates.append_array([base + "_idle", base + "_start", base, base + "_ranged"])
	for name in candidates:
		var found := resolve(frames, name)
		if found != &"":
			return found
	return &""

static func restore_idle(sprite: AnimatedSprite2D, unit: Unit, ranged := false) -> void:
	var name := idle(sprite.sprite_frames, unit, ranged)
	if name == &"":
		return
	sprite.stop()
	sprite.animation = name
	sprite.frame = 0
	if str(name).contains("_idle") or str(name).ends_with("_stand"):
		if sprite.sprite_frames.get_animation_loop(name):
			sprite.play()

static func dodge(frames: SpriteFrames, unit: Unit, ranged := false) -> StringName:
	var base := prefix(frames, unit)
	var name := resolve(frames, base + "_dodge_ranged") if ranged else &""
	return name if name != &"" else resolve(frames, base + "_dodge")

static func distance_is_ranged(a: Unit, b: Unit) -> bool:
	var difference := a.cell - b.cell
	return absi(difference.x) + absi(difference.y) > 1
