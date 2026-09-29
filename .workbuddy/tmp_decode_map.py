##"""解码 level_0.tscn 的 tile_map_data，统计地形分布/边界/民居宝箱位置（一次性分析脚本）"""
import base64, re, struct, sys
from collections import Counter

path = r"E:\SDL_Game\Lost\scene\level\level_0\level_0.tscn"
text = open(path, encoding="utf-8").read()

# 1. atlas 坐标 -> 地形名
terrain = {}
for m in re.finditer(r'(\d+):(\d+)/0/custom_data_0 = "([^"]+)"', text):
    terrain[(int(m.group(1)), int(m.group(2)))] = m.group(3)

# 2. tile_map_data base64
m = re.search(r'tile_map_data = PackedByteArray\("([^"]+)"\)', text)
raw = base64.b64decode(m.group(1))

##前 2 字节可能是格式版本头（(len-2) 恰好整除 12）
offset = 0
while offset < 4 and (len(raw) - offset) % 12 != 0:
    offset += 1
print("跳过头部字节:", offset)
cells = []
for i in range(offset, len(raw), 12):
    x, y, src, ax, ay, alt = struct.unpack("<6h", raw[i:i+12])
    if src == -1:
        continue
    cells.append((x, y, src, ax, ay, alt))

print("有效格子数:", len(cells))
xs = [c[0] for c in cells]; ys = [c[1] for c in cells]
print("地图边界: x %d~%d, y %d~%d" % (min(xs), max(xs), min(ys), max(ys)))

cnt = Counter(terrain.get((c[3], c[4]), "??未登记") for c in cells)
print("地形分布:", dict(cnt))

for c in cells:
    t = terrain.get((c[3], c[4]), "??")
    if t in ("民居", "宝箱", "道具店", "武器店", "斗技场", "要塞"):
        print("%s -> 格子 (%d, %d)" % (t, c[0], c[1]))
