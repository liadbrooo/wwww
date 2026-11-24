#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
mod engine;
mod updater;
use serde::Serialize;
use std::{collections::HashMap,path::PathBuf};
#[derive(Serialize)]
struct EngineStatus {ready:bool,message:String}
#[tauri::command]
fn engine_status()->EngineStatus {
    let ready=engine::available();
    EngineStatus{ready,message:if ready{"FFmpeg / FFprobe verfügbar".into()}else{"FFmpeg / FFprobe nicht gefunden".into()}}
}
#[tauri::command]
async fn native_export(request:engine::ExportRequest)->Result<String,String>{
    tauri::async_runtime::spawn_blocking(move||{
        request.validate()?;
        if !engine::available(){return Err("FFmpeg und FFprobe nicht verfügbar.".into())}
        let mut paths=HashMap::<String,PathBuf>::new();
        for clip in &request.clips{
            if paths.contains_key(&clip.id){continue}
            let path=rfd::FileDialog::new().set_title(&format!("Quelle auswählen: {}",clip.name)).pick_file().ok_or("Export abgebrochen.")?;
            if path.file_name().and_then(|n|n.to_str())!=Some(clip.name.as_str()){return Err("Dateiname stimmt nicht mit der Projektquelle überein.".into())}
            paths.insert(clip.id.clone(),path);
        }
        let output=rfd::FileDialog::new().set_title("LYRO Cut · Video exportieren").add_filter("MP4 Video",&["mp4"]).set_file_name("LYRO Cut.mp4").save_file().ok_or("Export abgebrochen.")?.with_extension("mp4");
        if paths.values().any(|p|p==&output){return Err("Ausgabedatei darf keine Quelldatei überschreiben.".into())}
        engine::export(&request,&paths,&output)?;
        Ok(format!("Export abgeschlossen: {}",output.display()))
    }).await.map_err(|e|e.to_string())?
}
fn main(){
    tauri::Builder::default().invoke_handler(tauri::generate_handler![engine_status,native_export,updater::check_update,updater::install_update])
      .run(tauri::generate_context!()).expect("LYRO Cut konnte nicht gestartet werden");
}
