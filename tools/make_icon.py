from PIL import Image, ImageDraw, ImageFont
import os, math

size = 1024
img = Image.new("RGB", (size, size), (9, 9, 11))
d = ImageDraw.Draw(img)

# lime orb, inset for adaptive masks
r = 356
d.ellipse([size/2-r, size/2-r, size/2+r, size/2+r], fill=(212, 255, 58))
# coral progress arc
arc_box = [size/2-278, size/2-278, size/2+278, size/2+278]
d.arc(arc_box, start=-90, end=160, fill=(255, 107, 74), width=24)
# tick marks
for i in range(12):
    a = -math.pi/2 + i * 2*math.pi/12
    x1 = size/2 + math.cos(a) * 316
    y1 = size/2 + math.sin(a) * 316
    x2 = size/2 + math.cos(a) * 336
    y2 = size/2 + math.sin(a) * 336
    d.line([x1, y1, x2, y2], fill=(11, 13, 2), width=10)

font = ImageFont.truetype(r"assets/fonts/DMSans-SemiBold.ttf", 330)
text = "₹"
bbox = d.textbbox((0,0), text, font=font)
tw, th = bbox[2]-bbox[0], bbox[3]-bbox[1]
d.text((size/2 - tw/2 - bbox[0], size/2 - th/2 - bbox[1]), text, font=font, fill=(11, 13, 2))

os.makedirs("assets/branding", exist_ok=True)
img.save("assets/branding/app_icon.png")

sizes = {"mdpi":48, "hdpi":72, "xhdpi":96, "xxhdpi":144, "xxxhdpi":192}
for name, px in sizes.items():
    out = img.resize((px, px), Image.LANCZOS)
    out.save(f"android/app/src/main/res/mipmap-{name}/ic_launcher.png")
print("icons written", img.getpixel((0,0)))
