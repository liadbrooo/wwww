"use strict";
const StudioFX=(()=>{
const groups=[["Schärfe & Unschärfe",[["blur","Gaußsche Unschärfe"],["sharpen","Schärfen"],["motionBlur","Bewegungsunschärfe"],["zoomBlur","Zoom-Unschärfe"],["unsharp","Unscharf maskieren"]]],["Licht & Farbe",[["exposure","Belichtung"],["gamma","Gamma"],["temperature","Farbtemperatur"],["hue","Farbton"],["saturation","Sättigung"],["contrast","Kontrast"],["highlightShadow","Lichter & Schatten"],["invert","Negativ"],["monochrome","Schwarzweiß"],["sepia","Sepia"]]],["Film & Stil",[["vignette","Vignette"],["noir","Noir"],["chrome","Chrome"],["fade","Fade Film"],["instant","Instant Film"],["process","Process Film"],["transfer","Transfer Film"],["posterize","Posterisation"],["edges","Kanten"],["bloom","Bloom"],["gloom","Gloom"]]],["Verzerrung & Struktur",[["pixelate","Mosaik"],["dotScreen","Rasterpunkte"],["lineScreen","Linienraster"]]],["Kreativ & Transformation",[["falseColor","Duotone"],["threshold","Schwellenwert"],["solarize","Solarisation"],["mirrorX","Horizontal spiegeln"],["mirrorY","Vertikal spiegeln"],["kaleidoscope","Kaleidoskop"]]]], ids=groups.flatMap(g=>g[1].map(x=>x[0]));
const presets=[["Cinematic Teal",[["temperature",0.24],["contrast",0.63],["vignette",0.24]]],["Golden Hour",[["temperature",0.78],["bloom",0.23],["saturation",0.58]]],["Analog Film",[["fade",0.7],["sepia",0.15],["vignette",0.35]]],["Urban Noir",[["noir",1],["sharpen",0.3],["vignette",0.32]]],["Dream Glow",[["bloom",0.5],["blur",0.1],["fade",0.25]]],["Cool Night",[["temperature",0.2],["exposure",0.42],["contrast",0.68]]],["Clean Detail",[["unsharp",0.3],["highlightShadow",0.25],["saturation",0.54]]],["Vintage 70s",[["instant",0.7],["sepia",0.3],["fade",0.28]]],["High Contrast",[["contrast",0.85],["sharpen",0.25]]],["Graphic Poster",[["posterize",0.7],["saturation",0.8],["edges",0.15]]],["Soft Portrait",[["blur",0.08],["bloom",0.17],["temperature",0.57]]],["Dark Drama",[["exposure",0.35],["gloom",0.3],["vignette",0.45]]],["Duotone Studio",[["falseColor",0.8],["contrast",0.65]]],["Retro Raster",[["dotScreen",0.65],["monochrome",0.65]]],["Neon Shift",[["hue",0.72],["bloom",0.4],["saturation",0.8]]],["Dream Zoom",[["zoomBlur",0.28],["bloom",0.25]]]];
const names=Object.fromEntries(groups.flatMap(g=>g[1]));
const detail=["unsharp","highlightShadow","vignette","bloom","gloom","dotScreen","lineScreen"], angles=["motionBlur","dotScreen","lineScreen"];
const cap=(n,a=0,b=1)=>Math.max(a,Math.min(b,n)),num=(v,f)=>Number.isFinite(v)?v:f;
let buffers;
function getBuffers(w,h){if(!buffers)buffers=Array.from({length:4},()=>document.createElement("canvas"));for(const c of buffers){if(c.width!==w)c.width=w;if(c.height!==h)c.height=h}return buffers}
function reset(c){const g=c.getContext("2d",{willReadFrequently:true});g.setTransform(1,0,0,1,0,0);g.globalAlpha=1;g.globalCompositeOperation="source-over";g.filter="none";g.clearRect(0,0,c.width,c.height);return g}
function pixelOperation(g,src,kind,a,d){const w=src.width,h=src.height;g.drawImage(src,0,0);const image=g.getImageData(0,0,w,h),p=image.data,old=new Uint8ClampedArray(p);const levels=2+Math.round((1-a)*18),step=255/(levels-1);
for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=(y*w+x)*4;
for(let c=0;c<3;c++){let v=old[i+c];if(kind==="gamma")v=255*Math.pow(v/255,0.3+a*2);else if(kind==="posterize")v=Math.round(v/step)*step;else if(kind==="highlightShadow"){const n=v/255;v=255*cap(n+a*(1-n)*(1-n)*.4-d*n*n*.3)}else if(kind==="threshold"){v=(old[i]*.2126+old[i+1]*.7152+old[i+2]*.0722)>=a*255?255:0}else if(kind==="falseColor"){const l=(old[i]*.2126+old[i+1]*.7152+old[i+2]*.0722)/255;v=[13,20,56][c]+l*([255,163,82][c]-[13,20,56][c])}else if(kind==="solarize"){const n=v/255;v=255*cap((1+3*a)*n-3*a*n*n)}else if(kind==="temperature")v+=((a-.5)*70)*(c===0?1:c===2?-1:0);else{const l=(y*w+Math.max(0,x-1))*4+c,r=(y*w+Math.min(w-1,x+1))*4+c,u=(Math.max(0,y-1)*w+x)*4+c,b=(Math.min(h-1,y+1)*w+x)*4+c;const lap=4*v-old[l]-old[r]-old[u]-old[b];v=kind==="edges"?Math.abs(lap)*a*3:v+lap*a*(kind==="unsharp"?.5+d:1)}p[i+c]=v}
}g.putImageData(image,0,0)}
function one(src,out,layer,small){const w=src.width,h=src.height,g=reset(out),a=cap(num(layer.intensity,.5)),d=cap(num(layer.detail,.5)),angle=num(layer.angle,0)*Math.PI/180,m=layer.effect,s=Math.max(1,Math.max(w,h)/1920);let filter="";
switch(m){
case "blur":filter="blur("+a*50*s+"px)";break;
case "exposure":filter="brightness("+Math.pow(2,(a-.5)*4)+")";break;
case "hue":filter="hue-rotate("+((a-.5)*360)+"deg)";break;
case "saturation":filter="saturate("+a*2+")";break;
case "contrast":filter="contrast("+(.5+a*1.5)+")";break;
case "invert":filter="invert("+a+")";break;
case "monochrome":filter="grayscale("+a+")";break;
case "sepia":filter="sepia("+a+")";break;
case "noir":filter="grayscale(1) contrast(1.55)";break;
case "chrome":filter="saturate(1.6) contrast(1.2)";break;
case "fade":filter="contrast(.76) saturate(.75) brightness(1.08)";break;
case "instant":filter="sepia(.45) contrast(.9) saturate(1.2)";break;
case "process":filter="saturate(1.3) hue-rotate(12deg) contrast(1.18)";break;
case "transfer":filter="sepia(.23) saturate(.75) hue-rotate(-12deg)";break;
case "threshold":case "falseColor":case "solarize":case "sharpen":case "unsharp":case "edges":case "posterize":case "gamma":case "temperature":case "highlightShadow":pixelOperation(g,src,m,a,d);return;
case "mirrorX":case "mirrorY":{g.translate(m==="mirrorX"?w:0,m==="mirrorY"?h:0);g.scale(m==="mirrorX"?-1:1,m==="mirrorY"?-1:1);g.drawImage(src,0,0);return}
case "kaleidoscope":{const n=3+Math.round(a*9),slice=Math.PI*2/n,rad=Math.hypot(w,h);for(let i=0;i<n;i++){g.save();g.translate(w/2,h/2);g.rotate(i*slice);g.beginPath();g.moveTo(0,0);g.arc(0,0,rad,-slice/2-.002,slice/2+.002);g.closePath();g.clip();if(i%2)g.scale(1,-1);g.drawImage(src,-w/2,-h/2);g.restore()}return}
case "pixelate":{const ratio=2+a*70;small.width=Math.max(1,Math.round(w/ratio));small.height=Math.max(1,Math.round(h/ratio));const q=reset(small);q.drawImage(src,0,0,small.width,small.height);g.imageSmoothingEnabled=false;g.drawImage(small,0,0,w,h);g.imageSmoothingEnabled=true;return}
case "vignette":{g.drawImage(src,0,0);const rad=Math.max(w,h)*.65,grad=g.createRadialGradient(w/2,h/2,rad*d*.6,w/2,h/2,rad);grad.addColorStop(0,"transparent");grad.addColorStop(1,"rgba(0,0,0,"+a+")");g.fillStyle=grad;g.fillRect(0,0,w,h);return}
case "bloom":case "gloom":{g.drawImage(src,0,0);g.globalCompositeOperation=m==="bloom"?"screen":"multiply";g.globalAlpha=a;g.filter="blur("+(2+d*40)*s+"px)";g.drawImage(src,0,0);return}
case "motionBlur":case "zoomBlur":{g.drawImage(src,0,0);for(let i=1;i<=8;i++){g.globalAlpha=1/(i+1);if(m==="motionBlur"){const z=(i-4.5)*a*10*s;g.drawImage(src,Math.cos(angle)*z,Math.sin(angle)*z)}else{const z=1+i*a*.012;g.drawImage(src,w*(1-z)/2,h*(1-z)/2,w*z,h*z)}}return}
case "dotScreen":case "lineScreen":{g.drawImage(src,0,0);g.save();g.translate(w/2,h/2);g.rotate(angle);g.fillStyle="rgba(0,0,0,"+a*.8+")";const q=Math.max(3,(2+d*25)*s),rad=Math.hypot(w,h)/2;for(let y=-rad;y<rad;y+=q){if(m==="lineScreen")g.fillRect(-rad,y,rad*2,Math.max(1,q*.22));else for(let x=-rad;x<rad;x+=q){g.beginPath();g.arc(x,y,q*.24,0,Math.PI*2);g.fill()}}g.restore();return}
default:g.drawImage(src,0,0);return
}
g.filter=filter||"none";g.drawImage(src,0,0);g.filter="none";
}
function render(source,w,h,stack){w=Math.max(2,Math.round(w));h=Math.max(2,Math.round(h));const [a,b,c,small]=getBuffers(w,h);reset(a).drawImage(source,0,0,w,h);let src=a,dst=b,tmp=c;
for(const layer of stack||[]){if(layer.enabled===false||!ids.includes(layer.effect))continue;let mix=cap(num(layer.mix,1));if(["noir","chrome","fade","instant","process","transfer","falseColor","mirrorX","mirrorY"].includes(layer.effect))mix*=cap(num(layer.intensity,.5));if(!mix)continue;one(src,dst,layer,small);if(mix<1){const g=reset(tmp);g.drawImage(src,0,0);g.globalAlpha=mix;g.drawImage(dst,0,0);[src,dst,tmp]=[tmp,src,dst]}else [src,dst]=[dst,src]}
return src}
return {groups,ids,names,detail,angles,render,presets};
})();
