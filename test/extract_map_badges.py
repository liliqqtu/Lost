import os
from PIL import Image

ROM_PATH = r"E:\FFB\ROM\fire-emblem-sacred-stones-cn.gba"
OUT_DIR = r"E:\Dream\Lost\assets\graphics\UI\map_icons"
TEST_DIR = r"E:\Dream\Lost\test"
ART_DIR = r"C:\Users\明耀寒玥\.gemini\antigravity\brain\6a7807d3-fc79-40be-b050-d5f86aed01b7"

os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(TEST_DIR, exist_ok=True)
os.makedirs(ART_DIR, exist_ok=True)

with open(ROM_PATH, "rb") as f:
    rom = f.read()

# 1. LZ77 Decompressor
def lz77_decompress(data, offset):
    assert data[offset] == 0x10, f"Expected 0x10, got {hex(data[offset])}"
    decomp_size = int.from_bytes(data[offset+1:offset+4], "little")
    out = bytearray()
    pos = offset + 4
    while len(out) < decomp_size:
        flag = data[pos]
        pos += 1
        for i in range(8):
            if len(out) >= decomp_size:
                break
            if (flag & (0x80 >> i)) == 0:
                out.append(data[pos])
                pos += 1
            else:
                b1 = data[pos]
                b2 = data[pos+1]
                pos += 2
                length = (b1 >> 4) + 3
                disp = ((b1 & 0x0F) << 8) | b2
                copy_start = len(out) - (disp + 1)
                for _ in range(length):
                    out.append(out[copy_start])
                    copy_start += 1
    return bytes(out)

# 2. Palette decoder
def parse_gba_palette(offset):
    colors = []
    for i in range(16):
        val = int.from_bytes(rom[offset + i*2 : offset + i*2 + 2], "little")
        r = (val & 0x1F) * 255 // 31
        g = ((val >> 5) & 0x1F) * 255 // 31
        b = ((val >> 10) & 0x1F) * 255 // 31
        a = 0 if i == 0 else 255
        colors.append((r, g, b, a))
    return colors

sys_pal = parse_gba_palette(0x5C7290)
player_pal = parse_gba_palette(0x5C7340)
enemy_pal = parse_gba_palette(0x5C7360)
npc_pal = parse_gba_palette(0x5C7380)

# 3. Tile decoder
tiles_data = lz77_decompress(rom, 0xABBE40)

def render_tile(tile_index, palette):
    offset = tile_index * 32
    img = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    for y in range(8):
        for x in range(4):
            b = tiles_data[offset + y * 4 + x]
            p0 = b & 0x0F
            p1 = (b >> 4) & 0x0F
            img.putpixel((x * 2, y), palette[p0])
            img.putpixel((x * 2 + 1, y), palette[p1])
    return img

boss_shield = render_tile(0x10, sys_pal)
rescue_blue = render_tile(0x03, player_pal)
rescue_green = render_tile(0x03, npc_pal)
rescue_red = render_tile(0x03, enemy_pal)

# Map tile alignment: (x + 9, y + 7) inside 16x16 tile
def create_map_tile_aligned(icon_8x8):
    tile_16 = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    tile_16.paste(icon_8x8, (9, 7))
    return tile_16

boss_shield_16 = create_map_tile_aligned(boss_shield)
rescue_blue_16 = create_map_tile_aligned(rescue_blue)

# Blinking animation GIF: 20 frames on (333ms), 12 frames off (200ms)
def save_blinking_gif(icon_img, out_path):
    blank = Image.new("RGBA", icon_img.size, (0, 0, 0, 0))
    icon_img.save(
        out_path,
        save_all=True,
        append_images=[blank],
        duration=[333, 200],
        loop=0,
        disposal=2
    )

items = [
    ("boss_shield_icon", boss_shield),
    ("boss_shield_map_tile", boss_shield_16),
    ("rescue_icon_blue", rescue_blue),
    ("rescue_icon_blue_map_tile", rescue_blue_16),
    ("rescue_icon_green", rescue_green),
    ("rescue_icon_red", rescue_red),
]

target_dirs = [OUT_DIR, TEST_DIR, ART_DIR]

for name, img in items:
    for tdir in target_dirs:
        # 1x native
        img.save(os.path.join(tdir, f"{name}.png"))
        # scaled 2x, 4x, 8x
        for scale in [2, 4, 8]:
            s_img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
            s_img.save(os.path.join(tdir, f"{name}_{scale}x.png"))

for name, img in [
    ("boss_shield_blinking", boss_shield),
    ("rescue_icon_blue_blinking", rescue_blue)
]:
    img_4x = img.resize((img.width * 4, img.height * 4), Image.NEAREST)
    img_8x = img.resize((img.width * 8, img.height * 8), Image.NEAREST)
    for tdir in target_dirs:
        save_blinking_gif(img_4x, os.path.join(tdir, f"{name}_4x.gif"))
        save_blinking_gif(img_8x, os.path.join(tdir, f"{name}_8x.gif"))

print("Precise extraction from ROM complete!")
