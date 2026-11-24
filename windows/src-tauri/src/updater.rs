use reqwest::blocking::Client;
use serde::{Deserialize,Serialize};
use sha2::{Digest,Sha256};
use semver::Version;
use std::{fs,io::{Read,Write},path::Path,process::Command,time::Duration};
#[cfg(windows)] use std::os::windows::process::CommandExt;
const API:&str="https://api.github.com/repos/liadbrooo/wwww/releases?per_page=50";
const BASE:&str="https://github.com/liadbrooo/wwww/releases/download/";
const PREFIX:&str="lyro-cut-windows-v";
const CURRENT:&str=env!("CARGO_PKG_VERSION");
const MAX_INSTALLER:u64=250*1024*1024;
#[derive(Deserialize)]
struct Asset {name:String,size:u64}
#[derive(Deserialize)]
struct Release {tag_name:String,draft:bool,prerelease:bool,body:Option<String>,assets:Vec<Asset>}
#[derive(Clone,Serialize)]
pub struct Update {version:String,notes:String,bytes:u64}
fn version(tag:&str)->Option<Version>{
    let v=Version::parse(tag.strip_prefix(PREFIX)?).ok()?;
    if !v.pre.is_empty()||!v.build.is_empty(){return None} Some(v)
}
fn installer(v:&str)->String{format!("LYRO-Cut-{v}-Windows-x64-Setup.exe")}
fn select(releases:&[Release],current:&Version)->Option<Update>{
    releases.iter().filter_map(|r|{
        let v=version(&r.tag_name)?;
        if r.draft||r.prerelease||&v<=current{return None}
        let file=installer(&v.to_string());
        let a=r.assets.iter().find(|a|a.name==file&&a.size>0&&a.size<=MAX_INSTALLER)?;
        r.assets.iter().find(|a|a.name=="SHA256SUMS.txt"&&a.size>0&&a.size<16384)?;
        Some((v.clone(),Update{version:v.to_string(),notes:r.body.as_deref().unwrap_or("").chars().take(4000).collect(),bytes:a.size}))
    }).max_by(|a,b|a.0.cmp(&b.0)).map(|v|v.1)
}
fn client()->Result<Client,String>{Client::builder().user_agent("LYRO-Cut-Windows-Updater/0.7").connect_timeout(Duration::from_secs(15)).timeout(Duration::from_secs(180)).build().map_err(|e|e.to_string())}
fn fetch(c:&Client)->Result<Option<Update>,String>{
    let releases:Vec<Release>=c.get(API).header("Accept","application/vnd.github+json").send().and_then(|r|r.error_for_status()).and_then(|r|r.json()).map_err(|e|format!("Updateprüfung fehlgeschlagen: {e}"))?;
    let current=Version::parse(CURRENT).map_err(|e|e.to_string())?;
    Ok(select(&releases,&current))
}
fn expected_hash(s:&str,name:&str)->Result<String,String>{
    let mut matches=s.lines().filter_map(|line|{
        let mut parts=line.split_whitespace();
        let hash=parts.next()?;
        let filename=parts.next()?.trim_start_matches('*');
        if filename!=name||parts.next().is_some()||hash.len()!=64||!hash.bytes().all(|b|b.is_ascii_hexdigit()){return None}
        Some(hash.to_ascii_lowercase())
    });
    let result=matches.next().ok_or("Keine gültige SHA-256-Prüfsumme für das Setup.")?;
    if matches.next().is_some(){return Err("Mehrdeutige Prüfsumme.".into())}
    Ok(result)
}
fn download(c:&Client,u:&Update,dir:&Path)->Result<std::path::PathBuf,String>{
    let name=installer(&u.version);
    let root=format!("{BASE}{PREFIX}{}/",u.version);
    let mut manifest=c.get(format!("{root}SHA256SUMS.txt")).send().and_then(|r|r.error_for_status()).map_err(|e|e.to_string())?.take(16385);
    let mut checksum=String::new();manifest.read_to_string(&mut checksum).map_err(|e|e.to_string())?;
    if checksum.len()>16384{return Err("Prüfsummendatei zu groß.".into())}
    let expected=expected_hash(&checksum,&name)?;
    let mut response=c.get(format!("{root}{name}")).send().and_then(|r|r.error_for_status()).map_err(|e|e.to_string())?;
    let file=dir.join(name);
    let mut out=fs::OpenOptions::new().write(true).create_new(true).open(&file).map_err(|e|e.to_string())?;
    let mut sha=Sha256::new();let mut size=0u64;let mut buf=[0u8;65536];
    loop{let n=response.read(&mut buf).map_err(|e|e.to_string())?;if n==0{break}size+=n as u64;
        if size>MAX_INSTALLER||size>u.bytes{return Err("Unerwartete Paketgröße.".into())}
        sha.update(&buf[..n]);out.write_all(&buf[..n]).map_err(|e|e.to_string())?;
    }
    out.sync_all().map_err(|e|e.to_string())?;
    if size!=u.bytes||format!("{:x}",sha.finalize())!=expected{return Err("Integritätsprüfung fehlgeschlagen. Es wird nichts installiert.".into())}
    Ok(file)
}
#[tauri::command]
pub async fn check_update()->Result<Option<Update>,String>{
    tauri::async_runtime::spawn_blocking(||fetch(&client()?)).await.map_err(|e|e.to_string())?
}
#[tauri::command]
pub async fn install_update(app:tauri::AppHandle,requested_version:String,project_backup:Option<String>)->Result<(),String>{
    tauri::async_runtime::spawn_blocking(move||{
        let c=client()?;let u=fetch(&c)?.ok_or("Kein neueres Update verfügbar.")?;
        if u.version!=requested_version{return Err("Updateangebot hat sich geändert. Bitte erneut prüfen.".into())}
        if let Some(backup)=project_backup {
            if backup.len()>32*1024*1024{return Err("Projektdatei zu groß.".into())}
            let p:serde_json::Value=serde_json::from_str(&backup).map_err(|_|"Ungültige Projektsicherung.")?;
            if !p.is_object(){return Err("Ungültige Projektsicherung.".into())}
            let target=rfd::FileDialog::new().set_title("Projekt vor Update sichern").set_file_name("LYRO-Cut-Backup.lyroweb").add_filter("LYRO Web Projekt",&["lyroweb"]).save_file().ok_or("Update abgebrochen: Projekt nicht gesichert.")?.with_extension("lyroweb");
            let parent=target.parent().ok_or("Ungültiges Sicherungsziel.")?;
            let mut file=tempfile::NamedTempFile::new_in(parent).map_err(|e|e.to_string())?;
            file.write_all(backup.as_bytes()).map_err(|e|e.to_string())?;
            file.as_file().sync_all().map_err(|e|e.to_string())?;
            file.persist(target).map_err(|e|e.to_string())?;
        }
        let dir=tempfile::Builder::new().prefix("lyro-cut-update-").tempdir().map_err(|e|e.to_string())?;
        let setup=download(&c,&u,dir.path())?;
        // Only the exact versioned installer from the repository, validated by SHA-256.
        // Not Authenticode or independent release signing. Do not bypass OS warnings.
        let mut command=Command::new(&setup);
        #[cfg(windows)] command.creation_flags(0x00000200);
        command.spawn().map_err(|e|format!("Setup konnte nicht gestartet werden: {e}"))?;
        let _kept=dir.keep();
        app.exit(0);
        Ok(())
    }).await.map_err(|e|e.to_string())?
}
#[cfg(test)]
mod tests {
    use super::*;
    fn release(tag:&str,draft:bool)->Release{
        let v=tag.trim_start_matches(PREFIX);
        Release{tag_name:tag.into(),draft,prerelease:false,body:None,assets:vec![Asset{name:installer(v),size:99},Asset{name:"SHA256SUMS.txt".into(),size:99}]}
    }
    #[test]fn newest_windows_release(){
        let rs=vec![release("lyro-cut-windows-v0.7.2",false),release("lyro-cut-v9.0.0",false),release("lyro-cut-windows-v0.7.10",false),release("lyro-cut-windows-v9.0.0",true),release("lyro-cut-windows-v10.0.0-rc.1",false)];
        assert_eq!(select(&rs,&Version::parse("0.7.1").unwrap()).unwrap().version,"0.7.10");
        assert!(select(&rs,&Version::parse("0.7.10").unwrap()).is_none());
    }
    #[test]fn strict_hash(){
        let name=installer("0.7.2");let hash="a".repeat(64);
        assert_eq!(expected_hash(&format!("{hash}  {name}\r\n"),&name).unwrap(),hash);
        assert!(expected_hash(&format!("{hash}  other.exe"),&name).is_err());
        assert!(expected_hash(&format!("{hash} {name}\n{hash} {name}"),&name).is_err());
    }
}
