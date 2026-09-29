extends RefCounted
class_name RangeDrawer

const SOURCE_ID := 0
const MOVE_TILE := Vector2i(0, 1)
const ATTACK_TILE := Vector2i(1, 0)
const PATH_TILE := Vector2i(0, 0)


func draw_move_range(cells: Dictionary, layer: TileMapLayer) -> void:
	for cell in cells.keys():
		layer.set_cell(cell, SOURCE_ID, MOVE_TILE)


func draw_attack_range(cells: Array, layer: TileMapLayer) -> void:
	for cell in cells:
		layer.set_cell(cell, SOURCE_ID, ATTACK_TILE)


func draw_path(cells: Array, layer: TileMapLayer) -> void:
	for cell in cells:
		layer.set_cell(cell, SOURCE_ID, PATH_TILE)


func clear_all(layer: TileMapLayer) -> void:
	layer.clear()
