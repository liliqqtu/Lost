import os
import shutil
from PIL import Image

BASE_DIR = r"E:\Dream\Lost"
OUT_BASE = os.path.join(BASE_DIR, "assets", "graphics", "UI", "shops")
ART_DIR = r"C:\Users\明耀寒玥\.gemini\antigravity\brain\6a7807d3-fc79-40be-b050-d5f86aed01b7"

armory_dir = os.path.join(OUT_BASE, "armory")
vendor_dir = os.path.join(OUT_BASE, "vendor")
secret_dir = os.path.join(OUT_BASE, "secret_shop")
bg_dir = os.path.join(OUT_BASE, "backgrounds")

for d in [armory_dir, vendor_dir, secret_dir, bg_dir]:
    os.makedirs(d, exist_ok=True)

REPO_BASE = r"E:\Dream\资源\FE-Repo-main\FE-Repo-main"
VANILLA_MUGS = os.path.join(REPO_BASE, "Portrait Repository", "FE08 Mugs (Sacred Stones)", "Vanilla")
SHOP_MUGS = os.path.join(REPO_BASE, "Portrait Repository", "Generic Characters (Villagers, Goons, and Loons)", "Shopkeepers")
FE8_BGS = os.path.join(REPO_BASE, "BGs, Interface Elements", "Background CGs", "FE8 BG's")
FE9_BGS = os.path.join(REPO_BASE, "BGs, Interface Elements", "Background CGs", "FE9-10 CG Rips")

# 1. Armory
# Sheet
src_armory_sheet = os.path.join(VANILLA_MUGS, "Weapon Vendor.png")
im_armory_sheet = Image.open(src_armory_sheet).convert("RGBA")
# 48x48 Portrait Window
armory_clerk_48 = im_armory_sheet.crop((24, 0, 72, 48))
# 48x48 Empty Interior Background (Cygnus rip)
src_armory_bg = os.path.join(SHOP_MUGS, "Empty Blacksmith {Cygnus}.png")
im_armory_bg_sheet = Image.open(src_armory_bg).convert("RGBA")
armory_bg_48 = im_armory_bg_sheet.crop((24, 0, 72, 48))

# Save Armory
im_armory_sheet.save(os.path.join(armory_dir, "armory_clerk_sheet_128x112.png"))
armory_clerk_48.save(os.path.join(armory_dir, "armory_clerk_48x48.png"))
armory_bg_48.save(os.path.join(armory_dir, "armory_interior_bg_48x48.png"))

# 2. Vendor
src_vendor_sheet = os.path.join(VANILLA_MUGS, "Shop Vendor.png")
im_vendor_sheet = Image.open(src_vendor_sheet).convert("RGBA")
vendor_clerk_48 = im_vendor_sheet.crop((24, 0, 72, 48))

# Vendor Interior BG: Let's extract the shelf background from vendor sheet
# In vendor_clerk_48: the left column (x: 0..12) has the wooden shelf with potions.
# The right column has the wall and window.
# We also have the full 48x48 portrait with shelf background.
vendor_clerk_48.save(os.path.join(vendor_dir, "vendor_clerk_48x48.png"))
im_vendor_sheet.save(os.path.join(vendor_dir, "vendor_clerk_sheet_128x112.png"))

# 3. Secret Shop (Anna)
src_anna_sheet = os.path.join(SHOP_MUGS, "Anna (FE8 Colours) {HyperGammaSpaces} [F2E].png")
im_anna_sheet = Image.open(src_anna_sheet).convert("RGBA")
anna_clerk_48 = im_anna_sheet.crop((24, 0, 72, 48))
anna_clerk_48.save(os.path.join(secret_dir, "secret_shop_clerk_48x48.png"))
im_anna_sheet.save(os.path.join(secret_dir, "secret_shop_clerk_sheet_128x112.png"))

# 4. Fullscreen CG Backgrounds (240x160)
armory_cg = os.path.join(FE9_BGS, "Armory.png")
tavern_cg = os.path.join(FE8_BGS, "Tavern.png")
if os.path.exists(armory_cg):
    shutil.copy2(armory_cg, os.path.join(bg_dir, "armory_cg_240x160.png"))
if os.path.exists(tavern_cg):
    shutil.copy2(tavern_cg, os.path.join(bg_dir, "vendor_cg_240x160.png"))

# 5. Generate scaled 2x and 4x versions for crisp pixel art rendering in modern resolutions
def scale_files(folder):
    for f in os.listdir(folder):
        if f.endswith(".png") and not ("_2x" in f or "_4x" in f):
            base, ext = os.path.splitext(f)
            img = Image.open(os.path.join(folder, f))
            img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(os.path.join(folder, f"{base}_2x{ext}"))
            img.resize((img.width * 4, img.height * 4), Image.NEAREST).save(os.path.join(folder, f"{base}_4x{ext}"))

for d in [armory_dir, vendor_dir, secret_dir, bg_dir]:
    scale_files(d)

# 6. Copy key showcase images to artifact directory
to_copy = [
    (os.path.join(armory_dir, "armory_clerk_48x48_4x.png"), "armory_clerk_48x48_4x.png"),
    (os.path.join(armory_dir, "armory_interior_bg_48x48_4x.png"), "armory_interior_bg_48x48_4x.png"),
    (os.path.join(vendor_dir, "vendor_clerk_48x48_4x.png"), "vendor_clerk_48x48_4x.png"),
    (os.path.join(secret_dir, "secret_shop_clerk_48x48_4x.png"), "secret_shop_clerk_48x48_4x.png"),
    (os.path.join(bg_dir, "armory_cg_240x160_2x.png"), "armory_cg_240x160_2x.png"),
    (os.path.join(bg_dir, "vendor_cg_240x160_2x.png"), "vendor_cg_240x160_2x.png"),
]

for src, name in to_copy:
    if os.path.exists(src):
        shutil.copy2(src, os.path.join(ART_DIR, name))

print("All shop resources successfully organized and exported!")
