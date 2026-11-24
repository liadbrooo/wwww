#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]
mod engine;
mod updater;
use serde::Serialize;
use tauri::Emitter;
use std::sync::atomic::{AtomicBool,Ordering};
static EXPORT_ACTIVE:AtomicBool=AtomicBool::new(false);
static EXPORT_CANCEL:AtomicBool=AtomicBool::new(false);
struct ExportGuard;
impl Drop for ExportGuard{fn drop(&mut self){EXPORT_ACTIVE.store(false,Ordering::Release)}}
#[derive(Clone,Serialize)]struct ExportProgress{done:usize,total:usize,encoder:String}
#[tauri::command]async fn detect_encoders()->Result<Vec<engine::EncoderInfo>,String>{tauri::async_runtime::spawn_blocking(engine::encoder_info).await.map_err(|e|e.to_string())}
#[tauri::command]fn cancel_native_export(){if EXPORT_ACTIVE.load(Ordering::Acquire){EXPORT_CANCEL.store(true,Ordering::Release)}}
use std::{collections::HashMap,path::PathBuf};
#[derive(Serialize)]
struct EngineStatus {ready:bool,message:String}
#[tauri::command]
fn engine_status()->EngineStatus {
    let ready=engine::available();
    EngineStatus{ready,message:if ready{"FFmpeg / FFprobe verfügbar".into()}else{"FFmpeg / FFprobe nicht gefunden".into()}}
}
#[tauri::command]
async fn native_export(app:tauri::AppHandle,request:engine::ExportRequest)->Result<String,String>{
    tauri::async_runtime::spawn_blocking(move||{
        if EXPORT_ACTIVE.swap(true,Ordering::AcqRel){return Err("Ein Export läuft bereits.".into())}
        let _guard=ExportGuard;EXPORT_CANCEL.store(false,Ordering::Release);
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
        if let Ok(real)=std::fs::canonicalize(&output){if paths.values().any(|p|std::fs::canonicalize(p).ok().as_ref()==Some(&real)){return Err("Ausgabedatei darf keine Quelldatei überschreiben.".into())}}
        let encoder=engine::export_with_progress(&request,&paths,&output,&EXPORT_CANCEL,|done,total,encoder|{let _=app.emit("native-export-progress",ExportProgress{done,total,encoder:encoder.into()});})?;
        Ok(format!("Export abgeschlossen ({encoder}): {}",output.display()))
    }).await.map_err(|e|e.to_string())?
}
fn main(){
    tauri::Builder::default().invoke_handler(tauri::generate_handler![engine_status,native_export,detect_encoders,cancel_native_export,updater::check_update,updater::install_update])
      .run(tauri::generate_context!()).expect("LYRO Cut konnte nicht gestartet werden");
}
