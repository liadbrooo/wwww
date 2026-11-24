"use strict";
(()=>{const invoke=window.__TAURI__?.core?.invoke;if(!invoke)return;
const button=document.getElementById("nativeExport"),panel=document.getElementById("progress"),cancel=document.getElementById("cancelExport");
function incompatible(c){return c.kind!=="video"||c.lane!==0||c.speed!==1||c.scale!==1||c.x!==0||c.y!==0||c.rotation!==0||c.opacity!==1||c.fadeIn||c.fadeOut||c.audioFadeIn||c.audioFadeOut||c.keys?.length||c.effects?.some(e=>e.enabled!==false&&(e.mix??1)>0)||c.mask!=="none"||c.blur||c.grayscale||c.sepia||c.fill}
button.onclick=async()=>{
 if(exporting)return;
 const clips=[...project.clips].sort((a,b)=>a.start-b.start);
 if(!clips.length)return tell("Füge Videoclips zur Timeline hinzu.");
 let end=0;for(const c of clips){if(incompatible(c)||Math.abs(c.start-end)>.002||hidden(c.lane))return tell("Native Export 0.7.0 unterstützt lückenlose, unveränderte Videoclips auf V1 mit Trimmen, Grundfarben und Lautstärke. Für Titel, Effekte, Animationen oder mehrere Spuren nutze den normalen Export.");end=c.start+c.length}
 const details=await invoke("engine_status").catch(e=>({ready:false,message:String(e)}));
 if(!details.ready)return tell("FFmpeg und FFprobe fehlen. Installiere FFmpeg z. B. mit winget install Gyan.FFmpeg, starte LYRO Cut neu und versuche es erneut. Alternativ: normaler Export.");
 const choice=prompt("Native Export: Auflösung wählen (1080 oder 2160)", "1080");if(choice===null)return;if(!["1080","2160"].includes(choice))return tell("Wähle 1080 oder 2160.");
 const encoder=prompt("Encoder: software (CPU) oder nvenc (NVIDIA, experimentell)", "software");if(encoder===null)return;if(!["software","nvenc"].includes(encoder))return tell("Unbekannter Encoder.");
 let [w,h]=project.sourceWidth&&project.sourceHeight?[project.sourceWidth,project.sourceHeight]:project.ratio.split(":").map(Number);const edge=choice==="2160"?3840:1920,scale=edge/Math.max(w,h);w=Math.max(2,Math.round(w*scale/2)*2);h=Math.max(2,Math.round(h*scale/2)*2);
 if(!confirm("Native Export: Quelldateien erneut auswählen. Der Export verwendet lokale Dateien und läuft unabhängig vom Browser-Encoder."))return;
 pause();exporting=true;panel.hidden=false;cancel.hidden=true;document.getElementById("bar").removeAttribute("value");document.getElementById("progressText").textContent="Quelldateien auswählen und nativ rendern …";
 try{const request={width:w,height:h,fps:project.fps,encoder,clips:clips.map(c=>({id:c.media,name:media.get(c.media)?.name||c.name,source_in:c.in,length:c.length,volume:muted(c.lane)?0:c.volume,brightness:c.brightness-1,contrast:c.contrast,saturation:c.saturation}))};const result=await invoke("native_export",{request});status(result);alert(result)}
 catch(e){tell("Native Export: "+String(e))}
 finally{exporting=false;panel.hidden=true;cancel.hidden=false;document.getElementById("bar").value=0;render()}
};
const nav=document.getElementById("settingsNav");document.getElementById("settings").addEventListener("click",async()=>{const d=await invoke("engine_status").catch(e=>({ready:false,message:String(e)}));const old=document.getElementById("desktopEngineInfo");if(old)old.remove();const info=document.createElement("div");info.id="desktopEngineInfo";info.className="desktopInfo";info.textContent="Windows 0.7.0 · Rust / Tauri · "+(d.ready?"FFmpeg verfügbar":"FFmpeg optional installieren");document.querySelector(".settingsShell>aside").append(info)});
})();
