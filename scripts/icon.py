# Draws the Midfold icon (1024x1024, no alpha) and copies it into the asset catalog (AppIcon + Logo).
# An open foldable seen from the front: a blue half and an orange half, a dashed fold line, a paper glider crossing it.
# Usage: python scripts/icon.py
from PIL import Image, ImageDraw, ImageFilter
import json, os

S = 1024
img = Image.new('RGB', (S, S))
d = ImageDraw.Draw(img)
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=(int(28 - 14 * t), int(32 - 14 * t), int(72 - 30 * t)))

glow = Image.new('RGBA', (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([160, 180, 880, 880], fill=(120, 140, 255, 70))
glow = glow.filter(ImageFilter.GaussianBlur(110))
img.paste(glow, (0, 0), glow)

halves = Image.new('RGBA', (S, S), (0, 0, 0, 0))
h = ImageDraw.Draw(halves)
top, bottom, gap = 250, 790, 14
h.rounded_rectangle([196, top, S // 2 - gap, bottom], 54, fill=(52, 133, 255, 255))
h.rounded_rectangle([S // 2 + gap, top, 828, bottom], 54, fill=(255, 140, 41, 255))
# square off the inner corners so the halves meet at the fold like a book spine
h.rectangle([S // 2 - gap - 60, top, S // 2 - gap, bottom], fill=(52, 133, 255, 255))
h.rectangle([S // 2 + gap, top, S // 2 + gap + 60, bottom], fill=(255, 140, 41, 255))
# soft shading toward the fold
shade = Image.new('RGBA', (S, S), (0, 0, 0, 0))
sd = ImageDraw.Draw(shade)
for i in range(70):
    a = int(70 * (1 - i / 70))
    sd.line([(S // 2 - gap - i, top), (S // 2 - gap - i, bottom)], fill=(0, 0, 0, a // 2))
    sd.line([(S // 2 + gap + i, top), (S // 2 + gap + i, bottom)], fill=(0, 0, 0, a // 2))
halves.alpha_composite(Image.composite(shade, Image.new('RGBA', (S, S)), halves.split()[3]))
img.paste(halves, (0, 0), halves)
d = ImageDraw.Draw(img)

# dashed fold line
y = top - 40
while y < bottom + 40:
    d.rounded_rectangle([S // 2 - 6, y, S // 2 + 6, min(y + 44, bottom + 40)], 6, fill=(255, 255, 255))
    y += 72

# paper glider crossing the fold
plane = [(640, 420), (380, 500), (450, 540), (420, 610)]
d.polygon(plane, fill=(255, 255, 255))
d.line([(640, 420), (450, 540)], fill=(40, 60, 140), width=8)

os.makedirs('assets', exist_ok=True)
img.save('assets/icon-1024.png')
base = 'Midfold/Assets.xcassets'
os.makedirs(f'{base}/AppIcon.appiconset', exist_ok=True)
os.makedirs(f'{base}/Logo.imageset', exist_ok=True)
img.save(f'{base}/AppIcon.appiconset/icon-1024.png')
img.resize((256, 256), Image.LANCZOS).save(f'{base}/Logo.imageset/logo.png')
json.dump({'images': [{'filename': 'icon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}],
           'info': {'author': 'xcode', 'version': 1}}, open(f'{base}/AppIcon.appiconset/Contents.json', 'w'), indent=2)
json.dump({'images': [{'filename': 'logo.png', 'idiom': 'universal'}], 'info': {'author': 'xcode', 'version': 1}},
          open(f'{base}/Logo.imageset/Contents.json', 'w'), indent=2)
json.dump({'info': {'author': 'xcode', 'version': 1}}, open(f'{base}/Contents.json', 'w'), indent=2)
os.makedirs(f'{base}/AccentColor.colorset', exist_ok=True)
json.dump({'colors': [{'color': {'color-space': 'srgb', 'components': {'red': '0.204', 'green': '0.522', 'blue': '1.000', 'alpha': '1.000'}}, 'idiom': 'universal'}],
           'info': {'author': 'xcode', 'version': 1}}, open(f'{base}/AccentColor.colorset/Contents.json', 'w'), indent=2)
print('icon written')
