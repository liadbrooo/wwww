from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
p=Path(__file__).parent/"src-tauri"/"icons";p.mkdir(parents=True,exist_ok=True)
def gradient(w,h):
 im=Image.new("RGB",(w,h))
 pix=im.load()
 for y in range(h):
  for x in range(w):
   t=(x/w+y/h)/2;pix[x,y]=(int(16+10*t),int(28+57*t),int(50+40*t))
 return im
im=gradient(512,512).convert("RGBA");d=ImageDraw.Draw(im)
d.rounded_rectangle((14,14,498,498),radius=110,outline="#86c9ef",width=5,fill="#14253e")
d.polygon([(110,293),(217,65),(321,65),(215,225),(403,225),(363,293)],fill="#90d9ff")
d.line((185,316,354,105),fill="#b9fff4",width=6)
for a,b,c,e in [(70,352,245,382),(255,352,440,382),(110,394,245,418),(255,394,398,418)]:d.rounded_rectangle((a,b,c,e),radius=6,fill="#67b9ed")
d.line((250,331,250,449),fill="#cafff7",width=4)
im.save(p/"icon.png");im.save(p/"icon.ico",sizes=[(16,16),(32,32),(48,48),(64,64),(128,128),(256,256)])
side=gradient(164,314);sd=ImageDraw.Draw(side);logo=im.resize((95,95));side.paste(logo,(34,58),logo)
try: font=ImageFont.truetype("arial.ttf",22);small=ImageFont.truetype("arial.ttf",11)
except:font=small=ImageFont.load_default()
sd.text((82,180),"LYRO Cut",font=font,anchor="mm",fill="white");sd.text((82,203),"WINDOWS STUDIO",font=small,anchor="mm",fill="#afd9ed")
side.save(p/"sidebar.bmp")
head=gradient(150,57);hd=ImageDraw.Draw(head);logo=im.resize((45,45));head.paste(logo,(100,6),logo);hd.text((8,20),"LYRO Cut",font=small,fill="white");head.save(p/"header.bmp")
