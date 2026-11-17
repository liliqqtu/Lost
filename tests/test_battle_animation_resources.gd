extends "res://tests/test_case.gd"

const Actions = preload("res://scripts/battle_animation_actions.gd")


const DIRECTORY := "res://data/battle_animation_tres/"
var _failures := 0
var _units: Array[Unit] = []

func _ready() -> void:
	_run()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _unit(resource: String, type: int, cell: Vector2i, team: int) -> Unit:
	var unit := Unit.new()
	unit.unit_name = resource
	unit.battle_frames = load(DIRECTORY + resource + ".tres")
	unit.cell = cell
	unit.team = team
	unit.max_hp = 100
	unit.hp = 100
	var weapon := Weapon.new()
	weapon.weapon_type = type
	weapon.display_name = "火炎" if type == Weapon.WeaponType.ANIMA else "测试武器"
	unit.add_item(weapon)
	unit.equip_item(weapon)
	add_child(unit)
	_units.append(unit)
	return unit

func _run() -> void:
	var count := 0
	for file in DirAccess.get_files_at(DIRECTORY):
		if not file.ends_with(".tres"):
			continue
		count += 1
		var frames := load(DIRECTORY + file) as SpriteFrames
		if count % 10 == 0:
			print("Resource validation progress: ", count)
		await get_tree().process_frame
		_check(frames != null, "Cannot load " + file)
		if frames == null:
			continue
		for name in frames.get_animation_names():
			_check(frames.get_frame_count(name) > 0, file + "/" + name + " empty")
			for i in frames.get_frame_count(name):
				_check(frames.get_frame_texture(name, i) != null, file + "/" + name + " texture missing")
		if file == "Magic_frames.tres":
			continue
		_check(frames.get_meta("battle_animation_version", 0) == 1, file + " not normalized")
		var aliases: Dictionary = frames.get_meta("battle_animation_aliases", {})
		for alias in aliases:
			_check(frames.has_animation(aliases[alias]), file + " dangling alias " + alias)
		for name in frames.get_animation_names():
			_check(not str(name).contains("_mode_"), file + " unnamed mode " + name)
			_check(not str(name).ends_with("_critical"), file + " noncanonical critical " + name)
			if str(name).contains("_idle"):
				_check(frames.get_animation_loop(name), file + " idle must loop")
		if frames.has_animation("magic_start"):
			_check(frames.has_animation("magic_idle"), file + " missing magic idle")
			_check(frames.has_animation("magic_end"), file + " missing magic end")
			_check(frames.has_animation("magic_loop"), file + " missing magic loop")
			_check(frames.get_animation_loop("magic_loop"), file + " casting must loop")
	print("Loaded and validated %d battle resources" % count)

	var ba = preload("res://scene/ui/battle_animation.tscn").instantiate()
	add_child(ba)
	await get_tree().process_frame
	var mercenary := _unit("Mercenary_M_frames", Weapon.WeaponType.SWORD, Vector2i(1, 1), 0)
	var target := _unit("Brigand_M_frames", Weapon.WeaponType.AXE, Vector2i(2, 1), 1)
	ba.player_anim.speed_scale = 30.0
	ba.enemy_anim.speed_scale = 30.0
	await ba.play(mercenary, target, [], "平原", "平原")
	_check(ba.player_anim.animation == &"sword_idle", "Mercenary intro must stand")
	var played: Array[StringName] = []
	ba.player_anim.animation_changed.connect(func(): played.append(ba.player_anim.animation))
	await ba.play_strike(mercenary, true, true, 3)
	_check(played.has(&"sword_crit"), "Critical action did not play")
	_check(ba.enemy_display_hp == 97, "Critical impact must apply once")
	_check(ba.player_anim.animation == &"sword_idle", "Critical must return to idle")
	played.clear()
	await ba.play_strike(mercenary, true, false, 2)
	_check(played.has(&"sword"), "Normal strike following critical must select sword")
	_check(not played.has(&"sword_crit"), "Normal strike inherited critical")
	_check(ba.enemy_display_hp == 95, "Second strike impact incorrect")
	var dodged := [false]
	ba.enemy_anim.animation_changed.connect(func():
		if str(ba.enemy_anim.animation).contains("_dodge"):
			dodged[0] = true)
	await ba.play_strike(mercenary, false, false, 0)
	_check(dodged[0], "Miss must play defender dodge")
	_check(ba.enemy_display_hp == 95, "Miss changed HP")
	_check(ba.enemy_anim.animation == &"axe_idle", "Dodge must return to idle")
	_check(Actions.resolve(target.battle_frames, "axe_critical") == &"axe_crit",
		"Legacy critical alias no longer resolves")

	# Three-phase imported magic and hand-authored Isar both complete and return idle.
	for resource in ["Mage_M_frames", "Mage_Knight_F_frames", "Isar"]:
		var caster := _unit(resource, Weapon.WeaponType.ANIMA, Vector2i(0, 1), 0)
		await ba.play(caster, target, [], "平原", "平原")
		for critical in [false, true]:
			var before: int = ba.enemy_display_hp
			await ba.play_strike(caster, true, critical, 1)
			_check(ba.enemy_display_hp == before - 1, resource + " spell impact must apply once")
			_check(ba.player_anim.animation == &"magic_idle", resource + " must return to idle")
			_check(not ba.magic_anim.visible, resource + " spell remained visible")
	# Ranged selection is independent of damage type; legacy Te clips remain usable.
	var archer := _unit("Te", Weapon.WeaponType.BOW, Vector2i(0, 1), 0)
	_check(Actions.attack(archer.battle_frames, archer, true, true, true) == &"bow_crit",
		"Te ranged critical fallback broken")
	_check(Actions.attack(mercenary.battle_frames, mercenary, false, true, true) == &"sword_ranged",
		"Ranged sword action not selected")
	await ba.close()
	ba.free()
	for unit in _units:
		unit.free()
	print("Battle animation normalization and playback: ", "PASS" if _failures == 0 else "FAIL")
	quit(0 if _failures == 0 else 1)
