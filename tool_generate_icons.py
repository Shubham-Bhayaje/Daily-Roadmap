import os
import shutil
from PIL import Image, ImageDraw

src_path = r"C:\Users\shubham\.gemini\antigravity\brain\245c9b40-a6c2-4b9a-982d-18d43111c53a\.user_uploaded\media_1792852944917_2b8b7359.png"
base_dir = r"c:\LEARN\daily_roadmap"

# 1. Copy to assets/images/logo.png
assets_dir = os.path.join(base_dir, "assets", "images")
os.makedirs(assets_dir, exist_ok=True)
dest_asset = os.path.join(assets_dir, "logo.png")
shutil.copy2(src_path, dest_asset)
print(f"Copied logo to {dest_asset}")

# Open source image
img = Image.open(src_path).convert("RGBA")

# Densities for standard launcher icons
densities = {
    "mipmap-mdpi": (48, 108),
    "mipmap-hdpi": (72, 162),
    "mipmap-xhdpi": (96, 216),
    "mipmap-xxhdpi": (144, 324),
    "mipmap-xxxhdpi": (192, 432),
}

res_dir = os.path.join(base_dir, "android", "app", "src", "main", "res")

# Create colors.xml for launcher background
values_dir = os.path.join(res_dir, "values")
os.makedirs(values_dir, exist_ok=True)
with open(os.path.join(values_dir, "colors.xml"), "w", encoding="utf-8") as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_background">#FFFFFF</color>\n</resources>\n')

# Create adaptive icon xml files in mipmap-anydpi-v26
anydpi_dir = os.path.join(res_dir, "mipmap-anydpi-v26")
os.makedirs(anydpi_dir, exist_ok=True)

xml_content = '<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n    <background android:color="@color/ic_launcher_background"/>\n    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>\n</adaptive-icon>\n'

with open(os.path.join(anydpi_dir, "ic_launcher.xml"), "w", encoding="utf-8") as f:
    f.write(xml_content)

with open(os.path.join(anydpi_dir, "ic_launcher_round.xml"), "w", encoding="utf-8") as f:
    f.write(xml_content)

for folder, (std_size, adapt_size) in densities.items():
    target_folder = os.path.join(res_dir, folder)
    os.makedirs(target_folder, exist_ok=True)
    
    # 1. Standard launcher icon
    resized_std = img.resize((std_size, std_size), Image.Resampling.LANCZOS)
    launcher_path = os.path.join(target_folder, "ic_launcher.png")
    resized_std.save(launcher_path, "PNG")
    
    # 2. Round launcher icon (circular mask with white background)
    round_canvas = Image.new("RGBA", (std_size, std_size), (0, 0, 0, 0))
    mask = Image.new("L", (std_size, std_size), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, std_size, std_size), fill=255)
    round_canvas.paste(resized_std, (0, 0), mask)
    round_path = os.path.join(target_folder, "ic_launcher_round.png")
    round_canvas.save(round_path, "PNG")
    
    # 3. Adaptive foreground: safe zone is 66-72%
    foreground_canvas = Image.new("RGBA", (adapt_size, adapt_size), (255, 255, 255, 0))
    fg_logo_size = int(adapt_size * 0.70)
    resized_fg = img.resize((fg_logo_size, fg_logo_size), Image.Resampling.LANCZOS)
    offset = ((adapt_size - fg_logo_size) // 2, (adapt_size - fg_logo_size) // 2)
    foreground_canvas.paste(resized_fg, offset, resized_fg)
    
    fg_path = os.path.join(target_folder, "ic_launcher_foreground.png")
    foreground_canvas.save(fg_path, "PNG")
    print(f"Generated {folder}: std={std_size}x{std_size}, adapt={adapt_size}x{adapt_size}")

print("All Android launcher and round icons generated successfully!")
