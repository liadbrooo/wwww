import Foundation
import AppKit
import SwiftUI
import CryptoKit

struct CutRelease: Decodable {
    let tag_name:String
    let draft:Bool
    let prerelease:Bool
    let body:String?
    let assets:[Asset]
    struct Asset:Decodable {let name:String;let size:Int}
    var version:String {String(tag_name.dropFirst("lyro-cut-v".count))}
    var zip:String {"LYRO-Cut-"+version+"-macOS.zip"}
    var base:URL {URL(string:"https://github.com/liadbrooo/wwww/releases/download/"+tag_name+"/")!}
    var valid:Bool {tag_name.hasPrefix("lyro-cut-v") && StudioUpdater.versionParts(version) != nil && !draft && !prerelease && assets.contains{$0.name==zip && $0.size>0 && $0.size<200_000_000} && assets.contains{$0.name==zip+".sha256" && $0.size>0 && $0.size<4096}}
}
@MainActor final class StudioUpdater:ObservableObject {
    static let shared=StudioUpdater()
    @Published var status="Noch nicht geprüft"
    @Published var available:CutRelease?
    @Published var busy=false
    static var current:String{Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "0.0.0"}
    nonisolated static func versionParts(_ v:String)->[Int]? {
        let parts=v.split(separator:".",omittingEmptySubsequences:false)
        guard parts.count==3,parts.allSatisfy({!$0.isEmpty && $0.allSatisfy{$0.isASCII && $0.isNumber}}) else{return nil}
        let numbers=parts.compactMap{Int($0)};return numbers.count==3 ? numbers:nil
    }
    nonisolated static func newer(_ a:String,_ b:String)->Bool {
        guard let x=versionParts(a),let y=versionParts(b) else{return false}
        return y.lexicographicallyPrecedes(x)
    }
    func checkAutomatically(_ e:Editor) async {
        guard e.prefs.autoCheckUpdates != false else{return}
        let last=UserDefaults.standard.double(forKey:"LYRO.LastUpdateCheck")
        if Date().timeIntervalSince1970-last>=Double(e.prefs.updateCheckHours ?? 24)*3600 {await check(e,manual:false)}
    }
    func check(_ e:Editor,manual:Bool) async {
        guard !busy else{return};busy=true;status="Suche nach Updates…"
        do {
            var request=URLRequest(url:URL(string:"https://api.github.com/repos/liadbrooo/wwww/releases?per_page=30")!)
            request.timeoutInterval=20;request.setValue("application/vnd.github+json",forHTTPHeaderField:"Accept")
            let (data,response)=try await URLSession.shared.data(for:request)
            guard (response as? HTTPURLResponse)?.statusCode==200 else{throw UpdateError.message("GitHub nicht erreichbar.")}
            let releases=try JSONDecoder().decode([CutRelease].self,from:data)
            let next=releases.filter{$0.valid && Self.newer($0.version,Self.current)}.sorted{Self.newer($0.version,$1.version)}.first
            UserDefaults.standard.set(Date().timeIntervalSince1970,forKey:"LYRO.LastUpdateCheck")
            available=next;status=next.map{"Version "+$0.version+" verfügbar"} ?? "Du verwendest die aktuelle Version."
            busy=false
            if let next=next {let alert=NSAlert();alert.messageText="LYRO Cut "+next.version+" ist verfügbar";alert.informativeText="Installiert: "+Self.current+"\n\n"+String((next.body ?? "Neue Version verfügbar.").prefix(1200))+"\n\nDein Projekt wird vor dem Neustart gespeichert. Die App wird aus dem offiziellen GitHub-Release aktualisiert.";alert.addButton(withTitle:"Speichern und installieren");alert.addButton(withTitle:"Später");if alert.runModal() == .alertFirstButtonReturn{await install(next,e)}}
            else if manual {let alert=NSAlert();alert.messageText=status;alert.runModal()}
        } catch {status="Updateprüfung fehlgeschlagen: "+error.localizedDescription;busy=false}
    }
    func install(_ release:CutRelease,_ e:Editor) async {
        guard !busy,release.valid,Self.newer(release.version,Self.current) else{return}
        guard !e.busy else{status="Bitte zuerst den Export beenden.";return}
        let app=Bundle.main.bundleURL.standardizedFileURL
        let fm=FileManager.default
        guard app.pathExtension=="app",!app.path.hasPrefix("/Volumes/"),!app.path.contains("/AppTranslocation/"),fm.isWritableFile(atPath:app.deletingLastPathComponent().path) else{status="Installiere die App zuerst in einem beschreibbaren Programme-Ordner.";return}
        guard e.saveBeforeUpdate() else{status="Update abgebrochen: Projekt nicht gespeichert.";return}
        busy=true;status="Update wird heruntergeladen…"
        let folder=fm.temporaryDirectory.appendingPathComponent("lyro-update-"+UUID().uuidString,isDirectory:true)
        do {
            try fm.createDirectory(at:folder,withIntermediateDirectories:false,attributes:[.posixPermissions:0o700])
            let (checksum,hashResponse)=try await URLSession.shared.data(from:release.base.appendingPathComponent(release.zip+".sha256"))
            guard (hashResponse as? HTTPURLResponse)?.statusCode==200,checksum.count<4096,
                  let expected=String(data:checksum,encoding:.utf8)?.split(whereSeparator:{$0.isWhitespace}).first?.lowercased(),expected.count==64,expected.allSatisfy({"0123456789abcdef".contains($0)}) else{throw UpdateError.message("Prüfsumme fehlt oder ist ungültig.")}
            let (download,response)=try await URLSession.shared.download(from:release.base.appendingPathComponent(release.zip))
            guard (response as? HTTPURLResponse)?.statusCode==200 else{throw UpdateError.message("Download fehlgeschlagen.")}
            let zip=folder.appendingPathComponent("update.zip");try fm.moveItem(at:download,to:zip)
            let size=(try fm.attributesOfItem(atPath:zip.path)[.size] as? NSNumber)?.intValue ?? 0
            guard size>0,size<200_000_000 else{throw UpdateError.message("Unzulässige Paketgröße.")}
            status="Paket wird geprüft…"
            let actual=try await Task.detached(priority:.utility){try Self.hash(zip)}.value
            guard actual==expected else{throw UpdateError.message("SHA-256 stimmt nicht überein.")}
            let unpack=folder.appendingPathComponent("unpack",isDirectory:true);try fm.createDirectory(at:unpack,withIntermediateDirectories:false)
            try await Task.detached(priority:.utility){try Self.run("/usr/bin/ditto",["-x","-k",zip.path,unpack.path])}.value
            let candidate=unpack.appendingPathComponent("LYRO Cut.app",isDirectory:true)
            guard let bundle=Bundle(url:candidate),bundle.bundleIdentifier=="gd.lyro.cut",bundle.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String == release.version else{throw UpdateError.message("Falsche App oder Version im Paket.")}
            try await Task.detached(priority:.utility){try Self.run("/usr/bin/codesign",["--verify","--deep","--strict",candidate.path])}.value
            // The app is ad-hoc signed, so this verifies package integrity, not a Developer ID.
            let helper=folder.appendingPathComponent("install.sh")
            try Self.helper.write(to:helper,atomically:true,encoding:.utf8)
            let task=Process();task.executableURL=URL(fileURLWithPath:"/bin/bash");task.arguments=[helper.path,String(ProcessInfo.processInfo.processIdentifier),app.path,candidate.path,folder.path]
            try task.run()
            status="Neustart zur Installation…";NSApp.terminate(nil)
        } catch {try? fm.removeItem(at:folder);status="Update fehlgeschlagen: "+error.localizedDescription;busy=false}
    }
    nonisolated static func hash(_ url:URL)throws->String {
        let handle=try FileHandle(forReadingFrom:url);defer{try? handle.close()}
        var sha=SHA256()
        while let data=try handle.read(upToCount:1024*1024),!data.isEmpty{sha.update(data:data)}
        return sha.finalize().map{String(format:"%02x",$0)}.joined()
    }
    nonisolated static func run(_ executable:String,_ args:[String])throws {
        let p=Process();p.executableURL=URL(fileURLWithPath:executable);p.arguments=args;p.standardOutput=FileHandle.nullDevice;p.standardError=FileHandle.nullDevice;try p.run();p.waitUntilExit();guard p.terminationStatus==0 else{throw UpdateError.message("Paketprüfung fehlgeschlagen.")}
    }
    nonisolated static let helper="""
    set -eu
    pid="$1"; target="$2"; candidate="$3"; temp="$4"
    for i in $(/usr/bin/seq 1 60); do
      if ! /bin/kill -0 "$pid" 2>/dev/null; then break; fi
      /bin/sleep 1
    done
    if /bin/kill -0 "$pid" 2>/dev/null; then exit 1; fi
    stage="$(/usr/bin/mktemp -d "$( /usr/bin/dirname "$target" )/.lyro-update.XXXXXX")"
    /usr/bin/ditto "$candidate" "$stage/new.app" || { /bin/rm -rf "$stage"; /usr/bin/open "$target"; exit 1; }
    /usr/bin/codesign --verify --deep --strict "$stage/new.app" || { /bin/rm -rf "$stage"; /usr/bin/open "$target"; exit 1; }
    /bin/mv "$target" "$stage/old.app" || { /bin/rm -rf "$stage"; /usr/bin/open "$target"; exit 1; }
    if /bin/mv "$stage/new.app" "$target"; then
      if /usr/bin/open "$target"; then /bin/rm -rf "$stage" "$temp"; else /bin/mv "$target" "$stage/failed.app"; /bin/mv "$stage/old.app" "$target"; /usr/bin/open "$target"; fi
    else
      /bin/mv "$stage/old.app" "$target"
      /usr/bin/open "$target"
    fi
    """
}
enum UpdateError:LocalizedError {case message(String);var errorDescription:String?{if case .message(let value)=self{return value};return nil}}
struct UpdateSettings:View {
    @ObservedObject var e:Editor
    @ObservedObject var updater=StudioUpdater.shared
    var body:some View {
        Section("Softwareupdates"){
            LabeledContent("Installierte Version",value:StudioUpdater.current)
            Toggle("Automatisch nach Updates suchen",isOn:Binding(get:{e.prefs.autoCheckUpdates ?? true},set:{e.prefs.autoCheckUpdates=$0}))
            Picker("Prüfintervall",selection:Binding(get:{e.prefs.updateCheckHours ?? 24},set:{e.prefs.updateCheckHours=$0})){Text("6 Stunden").tag(6);Text("Täglich").tag(24);Text("Wöchentlich").tag(168)}
            Text(updater.status).font(.caption)
            if updater.busy{ProgressView().controlSize(.small)}
            Button("Nach Updates suchen…"){Task{await updater.check(e,manual:true)}}.disabled(updater.busy)
            if let next=updater.available{Button("Version "+next.version+" installieren…"){Task{await updater.install(next,e)}}.disabled(updater.busy)}
            Text("Downloads stammen aus den GitHub-Releases. Installation erfolgt nur nach Bestätigung und Prüfung der Prüfsumme. Die App ist derzeit nicht Developer-ID-notarisiert.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
