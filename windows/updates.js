"use strict";
(()=>{
const invoke=window.__TAURI__?.core?.invoke;if(!invoke)return;
const key="lyro-windows-updates-v1",current="0.7.1";
let options={auto:true,hours:24,last:0};
try{const o=JSON.parse(localStorage.getItem(key)||"{}");options={auto:o.auto!==false,hours:[6,24,168].includes(o.hours)?o.hours:24,last:Number.isFinite(o.last)?o.last:0}}catch{}
let busy=false,available=null,message="Noch nicht geprüft";
function persist(){try{localStorage.setItem(key,JSON.stringify(options))}catch{}}
function make(tag,text){const el=document.createElement(tag);if(text!==undefined)el.textContent=text;return el}
function refreshUpdatePane(){
 if(settingsCategory!=="Updates")return;
 const body=$("settingsBody");body.replaceChildren();const group=make("div");group.className="settingsGroup";
 group.append(make("h3","SOFTWAREUPDATES"));const version=make("div","Installierte Version: "+current);version.className="settingRow";group.append(version);
 const row=make("label","Automatische Suche");row.className="settingRow";const toggle=make("input");toggle.type="checkbox";toggle.checked=options.auto;toggle.onchange=()=>{options.auto=toggle.checked;persist();refreshUpdatePane()};row.append(toggle);group.append(row);
 const interval=make("label","Prüfintervall");interval.className="settingRow";const select=make("select");for(const [v,l] of [[6,"Alle 6 Stunden"],[24,"Täglich"],[168,"Wöchentlich"]]){const o=make("option",l);o.value=v;select.append(o)}select.value=options.hours;select.disabled=!options.auto;select.onchange=()=>{options.hours=+select.value;persist()};interval.append(select);group.append(interval);
 const line=make("p",message);line.id="updateStatus";group.append(line);
 const check=make("button",busy?"Bitte warten …":"Nach Updates suchen");check.id="checkUpdate";check.disabled=busy||exporting;check.className="primary";check.onclick=()=>checkUpdates(true);group.append(check);
 if(available){const card=make("div");card.className="desktopUpdateCard";card.append(make("h3","LYRO Cut "+available.version),make("p",available.notes||"Neue Windows-Version verfügbar."));const install=make("button","Projekt sichern und Update installieren");install.className="primary";install.disabled=busy||exporting;install.onclick=installUpdate;card.append(install);group.append(card)}
 group.append(make("p","Updates stammen aus den offiziellen Windows-GitHub-Releases. SHA-256 wird vor dem Start des Setups geprüft. Die Setup-Dateien sind derzeit nicht Authenticode-signiert. Die portable Ausgabe wird über das Setup installiert, nicht direkt überschrieben."));
 body.append(group)
}
const original=renderSettings;
renderSettings=function(){original();if(settingsCategory==="Updates")refreshUpdatePane()};
settingsSections.push("Updates");
const shortcut=$("updateShortcut");shortcut.onclick=()=>{if(exporting)return;settingsCategory="Updates";openSettings()};
async function checkUpdates(manual){
 if(busy||exporting)return;
 busy=true;message="Suche nach Windows-Updates …";refreshUpdatePane();
 try{available=await invoke("check_update");options.last=Date.now();persist();message=available?"Version "+available.version+" verfügbar":"Du verwendest die aktuelle Version.";if(available)shortcut.textContent="Update verfügbar";else shortcut.textContent="Updates";if(available&&!manual)status(message)}
 catch(e){message=String(e)}finally{busy=false;refreshUpdatePane()}
}
async function installUpdate(){
 if(!available||busy||exporting)return;
 if(!confirm("LYRO Cut "+available.version+" herunterladen und Setup starten? Das aktuelle Projekt wird zuvor gesichert. Das Windows-Setup wird interaktiv geöffnet."))return;
 pause();busy=true;exporting=true;message="Projekt sichern und Update herunterladen …";refreshUpdatePane();
 try{
  let backup=null;
  if(project.clips.length||media.size){
   clearTimeout(saveTimer);
   backup=JSON.stringify({project,media:[...media.values()].map(m=>({id:m.id,name:m.name}))});
   if(prefs.recoveryEnabled){try{const d=await db;await new Promise((resolve,reject)=>{const tx=d.transaction("projects","readwrite");tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error);tx.objectStore("projects").put({project:copy(project),media:[...media.values()].map(m=>({id:m.id,blob:m.blob,name:m.name}))},"current")})}catch{status("Autosave nicht verfügbar; separate Projektsicherung erforderlich.")}}
  }
  await invoke("install_update",{requestedVersion:available.version,projectBackup:backup});
 }catch(e){message=String(e);status(message)}finally{busy=false;exporting=false;refreshUpdatePane()}
}
function automatic(){if(options.auto&&Date.now()-options.last>=options.hours*3600000&&!document.hidden&&!exporting&&!busy)checkUpdates(false)}
setTimeout(automatic,2500);setInterval(automatic,60000);
})();
