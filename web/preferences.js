"use strict";
const StudioPreferences=(()=>{
const defaults={ratio:"16:9",fps:30,matchSource:true,snapping:true,swapping:true,snapDistance:8,undoLimit:80,trackHeight:48,showWaveforms:true,showThumbnails:true,previewLimit:1280,exportFormat:"auto",exportResolution:1080,exportFPS:0,bitrate:0,recoveryEnabled:true,restoreLast:true};
const choices={ratio:["16:9","9:16","1:1","4:3"],fps:[24,25,30,50,60],undoLimit:[30,80,150],trackHeight:[36,48,64],previewLimit:[720,1280,1920],exportFormat:["auto","mp4","webm"],exportResolution:[720,1080,2160],exportFPS:[0,24,25,30,50,60],bitrate:[0,4000000,8000000,16000000,32000000]};
function normalize(raw){const result={...defaults};for(const k of Object.keys(defaults)){const v=raw?.[k];if(choices[k]?.includes(v))result[k]=v;else if(typeof defaults[k]==="boolean"&&typeof v==="boolean")result[k]=v;else if(k==="snapDistance"&&Number.isFinite(v))result[k]=Math.round(Math.max(2,Math.min(20,v)))}return result}
function load(){try{return normalize(JSON.parse(localStorage.getItem("lyro-preferences-v1")))}catch{return {...defaults}}}
function save(p){try{localStorage.setItem("lyro-preferences-v1",JSON.stringify(normalize(p)));return true}catch{return false}}
return {defaults,normalize,load,save};
})();if(typeof module!=="undefined")module.exports=StudioPreferences;
