# Draws the app icon: a glass widget card showing the time on a soft mesh backdrop.
# Run from the project folder: python3 Scripts/make-app-icon.py GlassClock/Assets.xcassets/AppIcon.appiconset/AppIcon.png
import sys, numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
S=1024
out=sys.argv[1]
# Mesh-like backdrop: four corner colours blended, plus a soft glow.
c=np.array([[40,52,150],[120,70,200],[30,140,190],[230,120,170]],float)/255  # TL TR BL BR
y,x=np.mgrid[0:S,0:S]/(S-1)
bg=(c[0]*((1-x)*(1-y))[...,None]+c[1]*(x*(1-y))[...,None]+c[2]*((1-x)*y)[...,None]+c[3]*(x*y)[...,None])
g=np.exp(-(((x-0.3)**2+(y-0.25)**2)/0.08))[...,None]
bg=np.clip(bg+g*np.array([0.25,0.2,0.3]),0,1)
base=Image.fromarray((bg*255).astype('uint8'),'RGB').convert('RGBA')
# The glass card.
W,H,R=800,560,150
x0,y0=(S-W)//2,(S-H)//2+10
mask=Image.new('L',(S,S),0); ImageDraw.Draw(mask).rounded_rectangle([x0,y0,x0+W,y0+H],R,fill=255)
shadow=Image.new('RGBA',(S,S),(0,0,0,0)); ImageDraw.Draw(shadow).rounded_rectangle([x0,y0+30,x0+W,y0+H+30],R,fill=(10,10,40,110))
base=Image.alpha_composite(base,shadow.filter(ImageFilter.GaussianBlur(40)))
blur=base.filter(ImageFilter.GaussianBlur(30))
frost=Image.alpha_composite(blur,Image.new('RGBA',(S,S),(255,255,255,100)))
base=Image.composite(frost,base,mask)
# Rim: bright at the top left, fading round.
rim=Image.new('L',(S,S),0); ImageDraw.Draw(rim).rounded_rectangle([x0,y0,x0+W,y0+H],R,outline=255,width=6)
fade=Image.fromarray((np.clip(1.25-(x+y)*0.75,0.25,1)*255).astype('uint8'),'L')
rim=ImageChops.multiply(rim,fade)
base=Image.composite(Image.new('RGBA',(S,S),(255,255,255,255)),base,rim)
# The time: big, rounded and white, with a soft lift.
font=ImageFont.truetype('Shared/Fonts/Nunito.ttf',330)
try: font.set_variation_by_axes([900])
except Exception: pass
text='9:41'
d=ImageDraw.Draw(Image.new('L',(1,1)))
l,t,r,b=d.textbbox((0,0),text,font=font)
tx,ty=(S-(r-l))//2-l,y0+(H-(b-t))//2-t
tm=Image.new('L',(S,S),0); ImageDraw.Draw(tm).text((tx,ty),text,font=font,fill=255)
ts=Image.new('RGBA',(S,S),(20,20,60,0)); ts.putalpha(tm.filter(ImageFilter.GaussianBlur(14)).point(lambda v:v*0.35))
base=Image.alpha_composite(base,ts.transform((S,S),Image.AFFINE,(1,0,0,0,1,-10)))
grad=Image.fromarray((np.dstack([np.ones((S,S))*255,np.ones((S,S))*255,np.ones((S,S))*255,np.zeros((S,S))])).astype('uint8'),'RGBA')
grad.putalpha(tm.point(lambda v:int(v*0.96)))
base=Image.alpha_composite(base,grad)
base.convert('RGB').save(out)
