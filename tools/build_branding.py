"""Render original 4 Players Game Offline branding for boot and Android system splash."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets'
S = 3
PALETTE = ['#b3a0ff', '#6ce5bc', '#ffb276', '#73c9ff']
FONT = '/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf'

def avatar(draw, x, y, radius, color):
    draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=color)
    for side in [-1, 1]:
        ex, ey = x + side * radius * .32, y - radius * .1
        r = radius * .1
        draw.ellipse((ex-r, ey-r, ex+r, ey+r), fill='#151e34')
    draw.arc((x-radius*.3, y, x+radius*.3, y+radius*.4), 0, 180, fill='#151e34', width=max(2, int(radius*.07)))

im = Image.new('RGBA', (480*S, 320*S))
d = ImageDraw.Draw(im)
d.rounded_rectangle((20*S, 95*S, 460*S, 297*S), radius=30*S, fill='#151e34')
for i, color in enumerate(PALETTE):
    avatar(d, (87+i*102)*S, 78*S, 37*S, color)
for title, y, font_size, color in [('4 PLAYERS', 141, 48, '#ffffff'), ('GAME OFFLINE', 229, 38, '#ffd577')]:
    f = ImageFont.truetype(FONT, font_size*S)
    d.text((240*S, y*S), title, font=f, anchor='mm', fill=color)
f = ImageFont.truetype(FONT, 16*S)
d.text((240*S, 278*S), 'ONE SCREEN. EVERYONE PLAYS.', font=f, anchor='mm', fill='#b3a0ff')
im.resize((480, 320), Image.Resampling.LANCZOS).save(OUT / 'boot_logo.png')

# Android 12+ shows the launcher/adaptive icon before the engine's boot image.
for size, name, adaptive in [(192, 'launcher_icon.png', False), (432, 'adaptive_foreground.png', True)]:
    image = Image.new('RGBA', (size*S, size*S))
    dr = ImageDraw.Draw(image)
    if not adaptive:
        dr.rounded_rectangle((0, 0, size*S-1, size*S-1), radius=size*.23*S, fill='#151e34')
    spacing = size * (.11 if adaptive else .19)
    radius = size * (.095 if adaptive else .15)
    for i, color in enumerate(PALETTE):
        x = size / 2 + (-spacing if i % 2 == 0 else spacing)
        y = size / 2 + (-spacing if i < 2 else spacing)
        avatar(dr, x*S, y*S, radius*S, color)
    image.resize((size, size), Image.Resampling.LANCZOS).save(OUT / name)
Image.new('RGB', (432, 432), '#151e34').save(OUT / 'adaptive_background.png')
