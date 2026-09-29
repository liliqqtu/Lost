extends "res://scene/character/units/unit.gd"

##伊萨尔 暗之贤者  装备 理光暗杖 

##"""战斗动画帧"""
const BATTLE_FRAMES := preload("E:/SDL_Game/Lost/data/battle_animation_tres/Isar.tres")

func _init() -> void:
	battle_frames = BATTLE_FRAMES
