extends Node

##瓦片大小设置
const TILE_SIZE = 16
## 四个方向（上下左右）
const directions := [
		Vector2i(0, -1), Vector2i(0, 1),
		Vector2i(-1, 0), Vector2i(1, 0)
]

##"""地形加成表，键为瓦片集自定义属性 Name 的值，数值取自GBA圣魔之光石"""
const TERRAIN_BONUS := {
	"平原":  {"def": 0, "avoid": 0},
	"道路":  {"def": 0, "avoid": 0},
	"桥":    {"def": 0, "avoid": 0},
	"宝箱":  {"def": 0, "avoid": 0},
	"森林":  {"def": 1, "avoid": 20},
	"山":    {"def": 1, "avoid": 30},
	"峰":    {"def": 2, "avoid": 40},
	"河":    {"def": 0, "avoid": 10},
	"湖":    {"def": 0, "avoid": 10},
	"民居":  {"def": 0, "avoid": 10},
	"道具店": {"def": 0, "avoid": 10},
	"武器店": {"def": 0, "avoid": 10},
	"斗技场": {"def": 0, "avoid": 10},
	"要塞":  {"def": 2, "avoid": 20},
}

##"""取地形加成 {def, avoid}，未登记的地形一律按 0/0 处理"""
static func get_terrain_bonus(terrain_name: String) -> Dictionary:
	return TERRAIN_BONUS.get(terrain_name, {"def": 0, "avoid": 0})
