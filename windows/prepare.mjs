import fs from "node:fs";import path from "node:path";import {fileURLToPath} from "node:url";
const root=path.dirname(fileURLToPath(import.meta.url));const dest=path.join(root,"dist");fs.mkdirSync(dest,{recursive:true});
for(const file of ["index.html","style.css","app.js","core.js","preferences.js","effects.js","logo.svg"])fs.copyFileSync(path.join(root,"..","web",file),path.join(dest,file));
let html=fs.readFileSync(path.join(dest,"index.html"),"utf8").replace("Web Studio","Windows Studio").replace("WEB STUDIO","WINDOWS STUDIO").replaceAll("0.6.1","0.7.1").replace("Browser-Engine","Desktop Engine").replace('<button class="primary" id="export">','<button id="nativeExport" title="Nativer FFmpeg-Export">Native Export</button><button class="primary" id="export">').replace('</body>','<script src="./desktop.js" defer></script></body>');
html=html.replace('<button id="settings"','<button id="updateShortcut" title="Softwareupdates">Updates</button><button id="settings"').replace('</body>','<script src="./updates.js" defer></script></body>');
fs.copyFileSync(path.join(root,"updates.js"),path.join(dest,"updates.js"));
fs.writeFileSync(path.join(dest,"index.html"),html);fs.copyFileSync(path.join(root,"desktop.js"),path.join(dest,"desktop.js"));
fs.appendFileSync(path.join(dest,"style.css"),"\n#nativeExport{border:1px solid #a2caff45;color:#a2caff}.desktopInfo{padding:10px;font-size:11px;color:#a4b4c8;line-height:1.5}body{min-width:1000px}");

const appPath=path.join(dest,"app.js");fs.writeFileSync(appPath,fs.readFileSync(appPath,"utf8").replace('["⚙","▤","▷","↥","▣","✧","♫","◴","⌨"]','["⚙","▤","▷","↥","▣","✧","♫","◴","⌨","↻"]'));
fs.appendFileSync(path.join(dest,"style.css"),"\n#updateShortcut{color:#a2caff;font-size:11px}.desktopUpdateCard{margin:12px 0;padding:12px;background:#1d2838;border-radius:6px}.desktopUpdateCard p{white-space:pre-wrap;max-height:150px;overflow:auto}");
