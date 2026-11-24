"use strict";
const StudioFX=(()=>{
const groups=[["Schärfe & Unschärfe",[["blur","Gaußsche Unschärfe"],["sharpen","Schärfen"],["motionBlur","Bewegungsunschärfe"],["zoomBlur","Zoom-Unschärfe"],["unsharp","Unscharf maskieren"]]],["Licht & Farbe",[["exposure","Belichtung"],["gamma","Gamma"],["temperature","Farbtemperatur"],["hue","Farbton"],["saturation","Sättigung"],["contrast","Kontrast"],["highlightShadow","Lichter & Schatten"],["invert","Negativ"],["monochrome","Schwarzweiß"],["sepia","Sepia"]]],["Film & Stil",[["vignette","Vignette"],["noir","Noir"],["chrome","Chrome"],["fade","Fade Film"],["instant","Instant Film"],["process","Process Film"],["transfer","Transfer Film"],["posterize","Posterisation"],["edges","Kanten"],["bloom","Bloom"],["gloom","Gloom"]]],["Verzerrung & Struktur",[["pixelate","Mosaik"],["dotScreen","Rasterpunkte"],["lineScreen","Linienraster"]]]], ids=groups.flatMap(g=>g[1].map(x=>x[0]));
const names=Object.fromEntries(groups.flatMap(g=>g[1]));
const detail=["unsharp","highlightShadow","vignette","bloom","gloom","dotScreen","lineScreen"], angles=["motionBlur","dotScreen","lineScreen"];
const cap=(n,a=0,b=1)=>Math.max(a,Math.min(b,n)),num=(v,f)=>Number.isFinite(v)?v:f;
let buffers;
function getBuffers(w,h){if(!buffers)buffers=Array.from({length:4},()=>document.createElement("canvas"));for(const c of buffers){if(c.width!==w)c.width=w;if(c.height!==h)c.height=h}return buffers}
function reset(c){const g=c.getContext("2d",{willReadFrequently:true});g.setTransform(1,0,0,1,0,0);g.globalAlpha=1;g.globalCompositeOperation="source-over";g.filter="none";g.clearRect(0,0,c.width,c.height);return g}
function pixelOperation(g,src,kind,a,d){const w=src.width,h=src.height;g.drawImage(src,0,0);const image=g.getImageData(0,0,w,h),p=image.data,old=new Uint8ClampedArray(p);const levels=2+Math.round((1-a)*18),step=255/(levels-1);
for(let y=0;y<h;y++)for(let x=0;x<w;x++){const i=(y*w+x)*4;
for(let c=0;c<3;c++){let v=old[i+c];if(kind==="gamma")v=255*Math.pow(v/255,0.3+a*2);else if(kind==="posterize")v=Math.round(v/step)*step;else if(kind==="highlightShadow"){const n=v/255;v=255*cap(n+a*(1-n)*(1-n)*.4-d*n*n*.3)}else if(kind==="temperature")v+=((a-.5)*70)*(c===0?1:c===2?-1:0);else{const l=(y*w+Math.max(0,x-1))*4+c,r=(y*w+Math.min(w-1,x+1))*4+c,u=(Math.max(0,y-1)*w+x)*4+c,b=(Math.min(h-1,y+1)*w+x)*4+c;const lap=4*v-old[l]-old[r]-old[u]-old[b];v=kind==="edges"?Math.abs(lap)*a*3:v+lap*a*(kind==="unsharp"?.5+d:1)}p[i+c]=v}
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
case "sharpen":case "unsharp":case "edges":case "posterize":case "gamma":case "temperature":case "highlightShadow":pixelOperation(g,src,m,a,d);return;
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
for(const layer of stack||[]){if(layer.enabled===false||!ids.includes(layer.effect))continue;let mix=cap(num(layer.mix,1));if(["noir","chrome","fade","instant","process","transfer"].includes(layer.effect))mix*=cap(num(layer.intensity,.5));if(!mix)continue;one(src,dst,layer,small);if(mix<1){const g=reset(tmp);g.drawImage(src,0,0);g.globalAlpha=mix;g.drawImage(dst,0,0);[src,dst,tmp]=[tmp,src,dst]}else [src,dst]=[dst,src]}
return src}
return {groups,ids,names,detail,angles,render};
})();
