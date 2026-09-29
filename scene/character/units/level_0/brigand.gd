extends "res://scene/character/units/unit.gd"

##序章的山贼

##"""战斗动画帧（山贼 斧）"""
const BATTLE_FRAMES := preload("res://data/battle_animation_tres/Brigand_M_frames.tres")

func _init() -> void:
	battle_frames = BATTLE_FRAMES
