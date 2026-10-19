"""Rasterize the project's original vector-style four-player icon for Google Play."""
from pathlib import Path
from PIL import Image, ImageDraw
S=3
im=Image.new('RGBA',(512*S,512*S),'#151e34')
d=ImageDraw.Draw(im)
for i,color in enumerate(['#b3a0ff','#6ce5bc','#ffb276','#73c9ff']):
 x=(256+(-98 if i%2==0 else 98))*S
 y=(256+(-98 if i<2 else 98))*S
 radius=77*S
 d.ellipse((x-radius,y-radius,x+radius,y+radius),fill=color)
 for side in [-1,1]:
  ex=x+side*radius*.32;ey=y-radius*.1;r=radius*.1
  d.ellipse((ex-r,ey-r,ex+r,ey+r),fill='#151e34')
 d.arc((x-radius*.3,y,x+radius*.3,y+radius*.4),0,180,fill='#151e34',width=16)
path=Path(__file__).resolve().parents[1]/'builds/google-play/graphics/app-icon-512.png'
im.resize((512,512),Image.Resampling.LANCZOS).save(path,optimize=True)
print(path.name)
