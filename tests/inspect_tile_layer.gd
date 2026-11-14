extends SceneTree

func _init() -> void:
	var l0_packed = load("res://scene/level/level_0/level_0.tscn")
	var l0 = l0_packed.instantiate()
	var tml: TileMapLayer = l0.get_node("TileMapLayer")
	var cells = tml.get_used_cells()
	print("L0 used cells count: ", cells.size())
	var min_x = 9999
	var max_x = -9999
	var min_y = 9999
	var max_y = -9999
	for c in cells:
		min_x = min(min_x, c.x)
		max_x = max(max_x, c.x)
		min_y = min(min_y, c.y)
		max_y = max(max_y, c.y)
	print("L0 Cell bounds: X=[%d, %d], Y=[%d, %d]" % [min_x, max_x, min_y, max_y])
	for i in range(min(10, cells.size())):
		var c = cells[i]
		var src = tml.get_cell_source_id(c)
		var atlas = tml.get_cell_atlas_coords(c)
		var alt = tml.get_cell_alternative_tile(c)
		var data = tml.get_cell_tile_data(c)
		var tname = data.get_custom_data("Name") if data else ""
		print("  cell %s -> src=%d, atlas=%s, alt=%d, Name='%s'" % [c, src, atlas, alt, tname])
	quit(0)
