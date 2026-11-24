use serde::{Deserialize,Serialize};
use std::{sync::atomic::{AtomicBool,Ordering},time::Duration,thread,process::Stdio};
use std::{collections::HashMap,fs,io::Write,path::{Path,PathBuf},process::{Command,Output}};
#[cfg(windows)] use std::os::windows::process::CommandExt;
#[derive(Deserialize,Clone,Debug)]
pub struct ExportClip {pub id:String,pub name:String,pub source_in:f64,pub length:f64,pub volume:f64,pub brightness:f64,pub contrast:f64,pub saturation:f64}
#[derive(Deserialize,Clone,Debug)]
pub struct ExportRequest {pub width:u32,pub height:u32,pub fps:f64,pub encoder:String,pub clips:Vec<ExportClip>,#[serde(default)] pub quality:Option<u32>,#[serde(default)] pub audio_bitrate:Option<u32>}
fn bounded(v:f64,lo:f64,hi:f64)->bool{v.is_finite()&&v>=lo&&v<=hi}
impl ExportRequest {
 pub fn validate(&self)->Result<(),String>{
  if self.width<2||self.height<2||self.width>3840||self.height>3840||self.width%2!=0||self.height%2!=0||!bounded(self.fps,1.,60.)||!["software","nvenc","qsv","amf","auto"].contains(&self.encoder.as_str())||self.quality.is_some_and(|v|v<15||v>32)||self.audio_bitrate.is_some_and(|v|![96,128,192,256,320].contains(&v))||self.clips.is_empty()||self.clips.len()>1000{return Err("Ungültige Exportparameter.".into())}
  let mut total=0.;
  for c in &self.clips{
   if c.id.is_empty()||c.id.len()>128||c.name.is_empty()||c.name.len()>260||!bounded(c.source_in,0.,86400.)||!bounded(c.length,1./self.fps,14400.)||!bounded(c.volume,0.,1.)||!bounded(c.brightness,-1.,1.)||!bounded(c.contrast,0.,3.)||!bounded(c.saturation,0.,3.) {return Err("Ungültige Clipparameter.".into())}
   total+=c.length;
  }
  if total>14400.{return Err("Projekt zu lang für diese Engine-Version.".into())} Ok(())
 }
}
fn command(name:&str)->Command{let mut c=Command::new(name);#[cfg(windows)]{c.creation_flags(0x08000000);}c}
fn run(c:&mut Command)->Result<Output,String>{let out=c.output().map_err(|e|e.to_string())?;if !out.status.success(){let err=String::from_utf8_lossy(&out.stderr);return Err(err.chars().take(1800).collect())}Ok(out)}
pub fn available()->bool{run(command("ffmpeg").arg("-version")).is_ok()&&run(command("ffprobe").arg("-version")).is_ok()}
#[derive(Serialize,Clone,Debug)]
pub struct EncoderInfo {pub id:String,pub label:String,pub usable:bool,pub detail:String}
const ENCODERS:[(&str,&str,&str);4]=[("software","CPU · H.264","libx264"),("nvenc","NVIDIA · NVENC","h264_nvenc"),("qsv","Intel · Quick Sync","h264_qsv"),("amf","AMD · AMF","h264_amf")];
fn codec(id:&str)->Option<&'static str>{ENCODERS.iter().find(|x|x.0==id).map(|x|x.2)}
fn run_cancel(c:&mut Command,cancel:&AtomicBool)->Result<(),String>{
 let log=tempfile::NamedTempFile::new().map_err(|e|e.to_string())?;
 let mut child=c.stdout(Stdio::null()).stderr(Stdio::from(log.reopen().map_err(|e|e.to_string())?)).spawn().map_err(|e|e.to_string())?;
 loop {
  if cancel.load(Ordering::Acquire){let _=child.kill();let _=child.wait();return Err("Export abgebrochen.".into())}
  match child.try_wait(){Ok(Some(s))=>{if s.success(){return Ok(())}return Err(fs::read_to_string(log.path()).unwrap_or_default().chars().take(1800).collect())},Ok(None)=>thread::sleep(Duration::from_millis(100)),Err(e)=>{let _=child.kill();let _=child.wait();return Err(e.to_string())}}
 }
}
fn test_encoder(id:&str)->Result<(),String>{
 let name=codec(id).ok_or("Unbekannter Encoder")?;
 let mut c=command("ffmpeg");
 c.args(["-hide_banner","-loglevel","error","-nostdin","-f","lavfi","-i","testsrc2=size=128x128:rate=30","-frames:v","3","-pix_fmt","yuv420p","-c:v",name,"-f","null","-"]);
 let cancel=AtomicBool::new(false);
 // Isolated probe, bounded to 12 seconds even for broken GPU drivers.
 thread::scope(|scope|{let (tx,rx)=std::sync::mpsc::channel();let flag=&cancel;scope.spawn(move||{let result=run_cancel(&mut c,flag);let _=tx.send(result);});match rx.recv_timeout(Duration::from_secs(12)){Ok(r)=>r,Err(_)=>{cancel.store(true,Ordering::Release);Err("Encoder-Zeitlimit überschritten".into())}}})
}
pub fn encoder_info()->Vec<EncoderInfo>{
 ENCODERS.iter().map(|(id,label,_)|{let result=test_encoder(id);EncoderInfo{id:(*id).into(),label:(*label).into(),usable:result.is_ok(),detail:result.err().unwrap_or("Test-Encoding erfolgreich".into())}}).collect()
}
fn select_encoder(id:&str)->Result<String,String>{
 if id=="auto"{for id in ["nvenc","qsv","amf","software"]{if test_encoder(id).is_ok(){return Ok(id.into())}}return Err("Kein funktionsfähiger H.264-Encoder gefunden.".into())}
 test_encoder(id).map_err(|e|format!("Encoder {id} nicht verfügbar: {e}"))?;Ok(id.into())
}
fn probe(path:&Path,selector:&str,entry:&str)->Result<String,String>{
 let o=run(command("ffprobe").args(["-v","error","-select_streams",selector,"-show_entries",entry,"-of","csv=p=0"]).arg(path))?;
 Ok(String::from_utf8_lossy(&o.stdout).trim().to_string())
}
pub fn export(req:&ExportRequest,paths:&HashMap<String,PathBuf>,output:&Path)->Result<(),String>{
 export_with_progress(req,paths,output,&AtomicBool::new(false),|_,_,_|{}).map(|_|())
}
pub fn export_with_progress(req:&ExportRequest,paths:&HashMap<String,PathBuf>,output:&Path,cancel:&AtomicBool,progress:impl Fn(usize,usize,&str))->Result<String,String>{
 req.validate()?;
 let encoder=select_encoder(&req.encoder)?;
 let quality=req.quality.unwrap_or(19).to_string();let bitrate=format!("{}k",req.audio_bitrate.unwrap_or(192));
 let tmp=tempfile::tempdir().map_err(|e|e.to_string())?;
 let mut list=String::new();
 for (i,c) in req.clips.iter().enumerate(){
  if cancel.load(Ordering::Acquire){return Err("Export abgebrochen.".into())}
  progress(i,req.clips.len()+1,&encoder);
  let path=paths.get(&c.id).ok_or("Quelldatei fehlt")?;
  if !path.is_file()||probe(path,"v:0","stream=index")?.is_empty(){return Err("Keine gültige Videospur.".into())}
  let has_audio=!probe(path,"a:0","stream=index")?.is_empty();
  let file=format!("segment{:05}.mp4",i);
  let dest=tmp.path().join(&file);
  let fps=format!("{:.6}",req.fps);
  let filter=format!("scale={}:{}:force_original_aspect_ratio=decrease:force_divisible_by=2,pad={}:{}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps={},eq=brightness={:.6}:contrast={:.6}:saturation={:.6},format=yuv420p",req.width,req.height,req.width,req.height,fps,c.brightness,c.contrast,c.saturation);
  let mut cmd=command("ffmpeg");
  cmd.args(["-hide_banner","-loglevel","error","-nostdin","-y","-ss",&format!("{:.6}",c.source_in),"-i"]).arg(path);
  if !has_audio{cmd.args(["-f","lavfi","-i","anullsrc=channel_layout=stereo:sample_rate=48000"]);}
  cmd.args(["-t",&format!("{:.6}",c.length),"-map","0:v:0","-map",if has_audio{"0:a:0"}else{"1:a:0"},"-vf",&filter,"-af",&format!("volume={:.6},apad",c.volume),"-ar","48000","-ac","2","-c:a","aac","-b:a",&bitrate,"-c:v",codec(&encoder).ok_or("Unbekannter Encoder")?]);
  match encoder.as_str(){
   "nvenc"=>{cmd.args(["-preset","p4","-rc","vbr","-cq",&quality]);}
   "qsv"=>{cmd.args(["-global_quality",&quality]);}
   "amf"=>{cmd.args(["-rc","cqp","-qp_i",&quality,"-qp_p",&quality]);}
   _=>{cmd.args(["-preset","veryfast","-crf",&quality]);}
  }
  cmd.args(["-movflags","+faststart"]).arg(&dest);run_cancel(&mut cmd,cancel)?;
  list.push_str(&format!("file '{}'\n",file));
 }
 let listpath=tmp.path().join("concat.txt");fs::write(&listpath,list).map_err(|e|e.to_string())?;
 let finalpath=tmp.path().join("final.mp4");
 progress(req.clips.len(),req.clips.len()+1,&encoder);
 run_cancel(command("ffmpeg").args(["-hide_banner","-loglevel","error","-nostdin","-y","-f","concat","-safe","1","-i"]).arg(listpath).args(["-c","copy","-movflags","+faststart"]).arg(&finalpath),cancel)?;
 let parent=output.parent().ok_or("Ungültiges Ziel")?;
 let mut stage=tempfile::NamedTempFile::new_in(parent).map_err(|e|e.to_string())?;
 let mut file=fs::File::open(finalpath).map_err(|e|e.to_string())?;std::io::copy(&mut file,&mut stage).map_err(|e|e.to_string())?;stage.flush().map_err(|e|e.to_string())?;
 if cancel.load(Ordering::Acquire){return Err("Export abgebrochen.".into())}
 stage.persist(output).map_err(|e|e.to_string())?;progress(req.clips.len()+1,req.clips.len()+1,&encoder);Ok(encoder)
}
#[cfg(test)]
mod tests{
 use super::*;
 #[test]fn native_render(){
  assert!(available(),"FFmpeg required for native render test");
  let tmp=tempfile::tempdir().unwrap();let src=tmp.path().join("sample.mp4");
  run(command("ffmpeg").args(["-hide_banner","-loglevel","error","-y","-f","lavfi","-i","testsrc2=size=320x180:rate=30","-t","2","-c:v","libx264","-pix_fmt","yuv420p"]).arg(&src)).unwrap();
  let c=ExportClip{id:"source".into(),name:"sample.mp4".into(),source_in:0.25,length:0.75,volume:1.,brightness:0.,contrast:1.,saturation:1.};
  let mut req=ExportRequest{width:640,height:360,fps:30.,encoder:"software".into(),clips:vec![c.clone(),c],quality:Some(20),audio_bitrate:Some(192)};
  let mut paths=HashMap::new();paths.insert("source".into(),src);
  let out=tmp.path().join("out.mp4");export(&req,&paths,&out).unwrap();
  assert_eq!(probe(&out,"v:0","stream=width,height").unwrap(),"640,360");
  assert!(!probe(&out,"a:0","stream=index").unwrap().is_empty());
  req.width=3840;req.height=2160;req.clips.truncate(1);
  let uhd=tmp.path().join("uhd.mp4");export(&req,&paths,&uhd).unwrap();
  assert_eq!(probe(&uhd,"v:0","stream=width,height").unwrap(),"3840,2160");
  let cancel=AtomicBool::new(true);let missing=tmp.path().join("cancelled.mp4");
  assert!(export_with_progress(&req,&paths,&missing,&cancel,|_,_,_|{}).is_err());assert!(!missing.exists());
  assert!(test_encoder("software").is_ok());assert!(test_encoder("unknown").is_err());
  req.width=99999;assert!(req.validate().is_err());
 }
}
