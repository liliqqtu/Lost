extends RefCounted
class_name Pathfinder

## Dijkstra算法 — 计算所有可到达的格子
## 返回 Dictionary[Vector2i, {remain_move: int, parent: Vector2i}]
## 参数说明：
##   tile_map: 地形图块层
##   start: 起始格子坐标
##   move: 总移动力
##   move_table: 地形移动力消耗表 {地形名称: 消耗值}
##   blocked_cells: 障碍物格子数组
static func get_move_range(
	tile_map: TileMapLayer,
	start: Vector2i,
	move: int,
	move_table: Dictionary,
	blocked_cells: Array
) -> Dictionary:
	## 存储所有可到达格子的信息  剩余移动力, 父格的坐标
	var result := {}
	## 待探索的格子队列（优先队列），每个元素包含格子坐标和剩余移动力
	var frontier: Array[Dictionary] = []

	# 初始化起点 remaining_move为剩余移动力
	result[start] = {"remain_move": move, "parent": start}
	frontier.append({"cell": start, "remain_move": move})

	## 四个方向（上下左右）
	var directions := [
		Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, 0), Vector2i(1, 0)
	]

	# 当还有格子需要探索时继续循环
	while not frontier.is_empty():
		# 在优先队列中找出剩余移动力最多的格子（贪心策略，类似Dijkstra）idx：索引
		var best_idx := 0
		var best_remain: int = frontier[0].remain_move
		for i in range(1, frontier.size()):
			if frontier[i].remain_move > best_remain:
				best_remain = frontier[i].remain_move
				best_idx = i

		# 取出当前要探索的格子
		var current: Dictionary = frontier.pop_at(best_idx)
		var cur_cell: Vector2i = current.cell
		var cur_remain: int = current.remain_move

		# 如果剩余移动力为0，无法继续移动
		if cur_remain <= 0:
			continue

		# 遍历四个方向的相邻格子
		for dir in directions:
			var next_cell: Vector2i = cur_cell + dir

			# 检查是否是障碍物
			if next_cell in blocked_cells:
				continue

			# 获取进入该格子的移动力消耗
			var cost := _get_terrain_cost(tile_map, next_cell, move_table)
			if cost < 0:  # 无法通行的地形
				continue

			# 计算剩余移动力
			var new_remain := cur_remain - cost
			if new_remain < 0:  # 移动力不足以进入该格子
				continue

			# 如果该格子已被访问且新的剩余移动力不比之前多，则跳过
			# 这保证了我们总是保留到达某格子的最优路径（剩余移动力最多）
			if result.has(next_cell) and result[next_cell].remain_move >= new_remain:
				continue

			# 记录格子信息并加入待探索队列
			result[next_cell] = {"remain_move": new_remain, "parent": cur_cell}
			frontier.append({"cell": next_cell, "remain_move": new_remain})

	return result


## A*算法 — 寻路
## 返回 Array[Vector2i] 从 start 到 end（含两端）
## 参数说明：
##   tile_map: 地形图块层
##   start: 起始格子坐标
##   end: 目标格子坐标
##   move_table: 地形移动力消耗表
##   blocked_cells: 障碍物格子数组
static func find_path(
	tile_map: TileMapLayer,
	start: Vector2i,
	end: Vector2i,
	move_table: Dictionary,
	blocked_cells: Array
) -> Array:
	# 开放列表，存储待探索的格子及其f值
	var open_set: Array[Dictionary] = []
	## 记录每个格子的父节点，用于路径重构
	var came_from := {}
	## 记录从起点到每个格子的实际代价（g值）
	var g_score := {}

	# 初始化起点
	g_score[start] = 0
	came_from[start] = start
	## 计算起点到终点的启发式估计代价（h值）
	var estimated_cost :int = _heuristic(start, end)
	open_set.append({"cell": start, "f": estimated_cost})

	# 四个方向
	var directions := [
		Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, 0), Vector2i(1, 0)
	]

	# 当还有格子需要探索时继续循环
	while not open_set.is_empty():
		# 在开放列表中找出f值最小的格子（f = g + h）
		var best_idx := 0
		var best_f: int = open_set[0].f
		for i in range(1, open_set.size()):
			if open_set[i].f < best_f:
				best_f = open_set[i].f
				best_idx = i

		# 取出当前要探索的格子
		var current: Vector2i = open_set.pop_at(best_idx).cell

		# 如果到达终点，重构路径
		if current == end:
			return _reconstruct_path(came_from, start, end)

		# 遍历四个方向的相邻格子
		for dir in directions:
			var next_cell: Vector2i = current + dir

			# 如果不是终点且是障碍物，跳过
			if next_cell != end and next_cell in blocked_cells:
				continue

			# 获取进入该格子的移动力消耗
			var cost := _get_terrain_cost(tile_map, next_cell, move_table)
			if cost < 0:  # 无法通行的地形
				continue

			# 计算通过当前格子到达下一格子的总代价
			var tentative_g: int = g_score[current] + cost

			# 如果这个路径更好（代价更小），则更新
			if not g_score.has(next_cell) or tentative_g < g_score[next_cell]:
				g_score[next_cell] = tentative_g
				came_from[next_cell] = current
				# f = g + h（h为下一格到终点的启发式估计距离）
				var f: int = tentative_g + _heuristic(next_cell, end)
				open_set.append({"cell": next_cell, "f": f})

	# 没有找到路径
	return []


## 攻击范围计算：对所有移动范围内的格子，计算武器射程内的格子并集，再减去与移动范围的交集
## 参数说明：
##   move_range: 移动范围（由get_move_range返回）
##   min_range: 武器最小攻击距离（曼哈顿距离）
##   max_range: 武器最大攻击距离（曼哈顿距离）
##   tile_map: 地形图块层
static func get_attack_range(
	move_range: Dictionary,
	min_range: int,
	max_range: int,
	tile_map: TileMapLayer
) -> Array:
	var result := {}

	# 遍历所有可移动到的格子
	for move_cell in move_range.keys():
		# 在最大射程范围内遍历所有可能的攻击目标
		for dx in range(-max_range, max_range + 1):
			for dy in range(-max_range, max_range + 1):
				# 计算曼哈顿距离
				var dist: int = abs(dx) + abs(dy)
				# 检查是否在武器射程范围内
				if dist < min_range or dist > max_range:
					continue
				# 不能攻击自己所在的格子
				if dx == 0 and dy == 0:
					continue

				var target: Vector2i = move_cell + Vector2i(dx, dy)
				# 去重
				if result.has(target) or move_range.has(target):
					continue

				# 检查目标格子是否存在（有地形数据）
				var tile_data = tile_map.get_cell_tile_data(target)
				if tile_data == null:
					continue

				result[target] = true

	return result.keys()


## 攻击范围计算：从单个格子出发（用于移动后计算）
static func get_attack_range_from_cell(
	cell: Vector2i,
	min_range: int,
	max_range: int,
	tile_map: TileMapLayer
) -> Array:
	var result: Array = []
	for dx in range(-max_range, max_range + 1):
		for dy in range(-max_range, max_range + 1):
			var dist: int = abs(dx) + abs(dy)
			if dist < min_range or dist > max_range:
				continue
			if dx == 0 and dy == 0:
				continue
			var target: Vector2i = cell + Vector2i(dx, dy)
			var tile_data = tile_map.get_cell_tile_data(target)
			if tile_data == null:
				continue
			result.append(target)
	return result


##"""多武器射程并集攻击范围（P0-1 统一接口）
##cells: 站位列表（通常 move_range.keys() 或 [unit.cell]）
##ranges: Array[Dictionary]，每项 {min:int, max:int}（来自 Unit.get_weapon_ranges）
##返回 Array[Vector2i]，已去重 + 剔除 cells 内的格子（与移动范围做差集）+ 剔除无地形的格子
##range 跨多个不相连区间（如剑 1-1 ∪ 弓 2-2）也能正确合并"""
static func get_attack_range_union(
	cells: Array,
	ranges: Array,
	tile_map: TileMapLayer
) -> Array:
	if cells.is_empty() or ranges.is_empty():
		return []
	##站位集合：攻击范围要与其做差集（FE 显示规则：蓝色=移动范围 MOVE_TILE，红色=移动范围之外的攻击范围 ATTACK_TILE）
	var stand := {}
	for cell in cells:
		stand[cell] = true
	var max_max := 0
	for r in ranges:
		if int(r["max"]) > max_max:
			max_max = int(r["max"])
	var result := {}
	for cell in cells:
		for dx in range(-max_max, max_max + 1):
			for dy in range(-max_max, max_max + 1):
				var target: Vector2i = cell + Vector2i(dx, dy)
				##站位自身的格子也归移动范围（蓝），不重复画成红色
				if stand.has(target):
					continue
				var dist: int = abs(dx) + abs(dy)
				var in_any := false
				for r in ranges:
					if dist >= int(r["min"]) and dist <= int(r["max"]):
						in_any = true
						break
				if not in_any:
					continue
				if tile_map.get_cell_tile_data(target) == null:
					continue
				result[target] = true
	return result.keys()


##"""获取地形名称（瓦片集自定义属性 Name），无瓦片或无数据返回空字符串"""
static func get_terrain_name(tile_map: TileMapLayer, cell: Vector2i) -> String:
	var tile_data = tile_map.get_cell_tile_data(cell)
	if tile_data == null:
		return ""
	return tile_data.get_custom_data("Name")


## 获取地形移动力消耗
## 参数说明：
##   tile_map: 地形图块层
##   cell: 要检查的格子坐标
##   move_table: 地形移动力消耗表
## 返回值：移动力消耗值，-1表示无法通行
static func _get_terrain_cost(tile_map: TileMapLayer, cell: Vector2i, move_table: Dictionary) -> int:
	var terrain := get_terrain_name(tile_map, cell)
	if terrain == null or terrain == "":
		return -1
	# 从消耗表中查找对应的消耗值
	return move_table.get(terrain, -1)


## 启发式函数：计算两个格子之间的曼哈顿距离
## A*算法中使用，用于估计从当前格到目标格的代价
static func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## 重构路径
## 从终点反向遍历came_from字典，重建从起点到终点的路径
static func _reconstruct_path(came_from: Dictionary, start: Vector2i, end: Vector2i) -> Array:
	var path: Array = []
	var current := end
	while current != start:
		path.push_front(current)  # 从后往前添加节点
		current = came_from.get(current, start)  # 获取父节点
	path.push_front(start)  # 最后添加起点
	return path
