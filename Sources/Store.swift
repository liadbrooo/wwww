import Foundation
import AVFoundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor final class Editor: ObservableObject {
    @Published var project = Project()
    @Published var selected: UUID? {didSet {if let id=selected,!selection.contains(id){selection=[id]} else if selected==nil {selection=[]}}}
    @Published var selection:Set<UUID> = []
    @Published var workspace="Schnitt"
    @Published var playhead: Double = 0
    @Published var playing = false
    @Published var error: String?
    @Published var busy = false
    @Published var exportOptions = false
    @Published var exportProgress: Double = 0
    @Published var snapping = true
    @Published var swapping = true
    private var exportSession: AVAssetExportSession?
    private var cancelRequested=false
    @Published var status = "Bereit"
    @Published var zoom: Double = 48
    @Published var waveforms: [UUID:[Double]] = [:]
    @Published var suggestions: [UUID:[Double]] = [:]
    @Published var analyzing = false
    private var waveformPending: Set<UUID> = []
    @Published var thumbnails: [UUID:NSImage] = [:]
    @Published private(set) var canUndo = false
    @Published private(set) var canRedo = false
    let player = AVPlayer()
    private var observer: Any?
    private var refreshTask: Task<Void,Never>?
    private var undoStack: [Project] = []
    private var redoStack: [Project] = []
    private var lastEdit: (UUID,Date)?
    private var fileURL: URL?
    private let recovery = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/LYRO Cut/Recovery.lyrocut")
    init() {
        observer = player.addPeriodicTimeObserver(forInterval:ct(1.0/30),queue:.main) { [weak self] time in
            Task { @MainActor in
                guard let self = self else { return }
                if self.player.currentItem != nil && self.player.rate != 0 {self.playhead = time.seconds.isFinite ? time.seconds : 0}
                self.playing = self.player.rate != 0
            }
        }
        if let data = try? Data(contentsOf:recovery), let saved = try? JSONDecoder().decode(Project.self,from:data) {
            project = saved
            refresh()
            Task { await makeThumbnails() }
        }
    }
    var current: Clip? { project.clips.first { $0.id == selected } }
    func selectClip(_ id:UUID,extend:Bool=false){
        if extend {
            if selection.contains(id){selection.remove(id);selected=selection.first}
            else{selection.insert(id);selected=id}
        }else{selection=[id];selected=id}
    }
    func record() {
        undoStack.append(project)
        if undoStack.count > 80 { undoStack.removeFirst() }
        redoStack.removeAll()
        canUndo = true; canRedo = false
    }
    func change(_ work: (inout Project)->Void) {
        record(); lastEdit = nil; work(&project); changed()
    }
    func edit(_ id: UUID,_ work: (inout Clip)->Void) {
        guard let index = project.clips.firstIndex(where:{$0.id == id}), !project.locked(project.clips[index].lane) else { return }
        if lastEdit?.0 != id || Date().timeIntervalSince(lastEdit?.1 ?? .distantPast) > 0.7 { record() }
        lastEdit = (id,Date())
        work(&project.clips[index])
        suggestions.removeValue(forKey:id)
        changed()
    }
    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(project); project = previous; canUndo = !undoStack.isEmpty; canRedo = true; lastEdit = nil; changed()
    }
    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(project); project = next; canUndo = true; canRedo = !redoStack.isEmpty; lastEdit = nil; changed()
    }
    func changed() {
        if let selected = selected, !project.clips.contains(where:{$0.id == selected}) { self.selected = nil }
        selection.formIntersection(Set(project.clips.map(\.id)))
        try? FileManager.default.createDirectory(at:recovery.deletingLastPathComponent(),withIntermediateDirectories:true)
        if let data = try? JSONEncoder().encode(project) {
            try? data.write(to:recovery,options:.atomic)
        }
        refresh()
    }
    func refresh() {
        refreshTask?.cancel()
        let snapshot = project
        refreshTask = Task {
            try? await Task.sleep(nanoseconds:180_000_000)
            guard !Task.isCancelled else { return }
            if !snapshot.clips.contains(where:{$0.kind == .video}) {
                player.replaceCurrentItem(with:nil); playing = false; return
            }
            do {
                let graph = try await Renderer.build(snapshot,preview:true)
                guard !Task.isCancelled else { return }
                let at = min(playhead,max(0,snapshot.duration-0.001))
                let resume = player.rate != 0
                player.replaceCurrentItem(with:graph.playerItem())
                _ = await player.seek(to:ct(at),toleranceBefore:.zero,toleranceAfter:.zero)
                guard !Task.isCancelled else { return }
                if resume { player.play() }
                status = "Bereit"
            } catch { if !Task.isCancelled { status = error.localizedDescription; player.replaceCurrentItem(with:nil); playing = false } }
        }
    }
    func seek(_ time: Double) {
        let value = max(0,min(project.duration,time))
        playhead = value
        player.seek(to:ct(value),toleranceBefore:.zero,toleranceAfter:.zero)
    }
    func toggle() {
        guard player.currentItem != nil else { return }
        if player.rate != 0 { player.pause(); playing = false }
        else { if playhead >= project.duration-0.04 { seek(0) }; player.play(); playing = true }
    }
    func importMedia() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie,.video,.audio]
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        Task { await importURLs(panel.urls) }
    }
    func importURLs(_ urls: [URL]) async {
        status = "Medien werden geladen…"
        var added: [Media] = []
        var failures: [String] = []
        for url in urls {
            do {
                let asset = AVURLAsset(url:url)
                let duration = try await asset.load(.duration).seconds
                let videos = try await asset.loadTracks(withMediaType:.video)
                let audios = try await asset.loadTracks(withMediaType:.audio)
                guard duration.isFinite, duration > 0.05, !videos.isEmpty || !audios.isEmpty else { throw RenderError.invalid(url.lastPathComponent) }
                var media=Media(path:url.path,name:url.lastPathComponent,duration:duration,kind:videos.isEmpty ? .audio : .video)
                if let track=videos.first {
                    let size=try await track.load(.naturalSize)
                    let transform=try await track.load(.preferredTransform)
                    let oriented=CGRect(origin:.zero,size:size).applying(transform)
                    media.width=abs(oriented.width);media.height=abs(oriented.height)
                    media.fps=Double(try await track.load(.nominalFrameRate))
                }
                added.append(media)
            } catch { failures.append(url.lastPathComponent) }
        }
        if !added.isEmpty { change { $0.media.append(contentsOf:added) }; await makeThumbnails() }
        status = "Bereit"
        if !failures.isEmpty { error = "Nicht unterstützte Medien: " + failures.joined(separator:", ") }
    }
    func makeThumbnails() async {
        for media in project.media where waveforms[media.id] == nil && !waveformPending.contains(media.id) {
            waveformPending.insert(media.id)
            let id=media.id
            let path=media.path
            let duration=media.duration
            Task {
                let peaks=await Task.detached(priority:.utility){await MediaAnalysis.waveform(path:path,duration:duration)}.value
                waveforms[id]=peaks;waveformPending.remove(id)
            }
        }
        for media in project.media where media.kind == .video && thumbnails[media.id] == nil {
            let asset = AVURLAsset(url:URL(fileURLWithPath:media.path))
            let generator = AVAssetImageGenerator(asset:asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width:240,height:144)
            if let image = try? generator.copyCGImage(at:ct(min(0.2,media.duration/2)),actualTime:nil) {
                thumbnails[media.id] = NSImage(cgImage:image,size:.zero)
            }
            await Task.yield()
        }
    }
    func add(_ media: Media, at position: Double? = nil, lane requested: Int? = nil) {
        let lane = media.kind == .audio ? max(project.lanes.last ?? -2,min(-1,requested ?? -1)) : max(0,min(project.lanes.first ?? 2,requested ?? 0))
        guard !project.locked(lane) else{status="Spur ist gesperrt";return}
        let start = position.map{max(0,project.snap($0))} ?? project.clips.filter{$0.lane == lane}.map(\.end).max() ?? 0
        let clip = Clip(mediaID:media.id,name:media.name,kind:media.kind,start:start,length:media.duration,lane:lane)
        change { p in
            if media.kind == .video && !p.clips.contains(where:{$0.kind == .video}) {p.useSource(media)}
            var inserted=clip
            // Same-track media drops insert into the sequence instead of silently hiding clips.
            if let overlap=p.clips.first(where:{$0.lane==lane && inserted.start>$0.start && inserted.start<$0.end}) {
                inserted.start=inserted.start-overlap.start<overlap.length/2 ? overlap.start:overlap.end
            }
            if position != nil {
                for i in p.clips.indices where p.clips[i].lane==lane && p.clips[i].start>=inserted.start-0.00001 {p.clips[i].start+=inserted.length}
            }
            p.clips.append(inserted)
        }; selected = clip.id
    }
    func addTitle() {
        guard !project.locked(2) else{status="Spur ist gesperrt";return}
        let clip = Clip(name:"Titel",kind:.title,start:playhead,length:3,lane:2)
        change { $0.clips.append(clip) }; selected = clip.id
    }
    func split() {
        if selection.count>1 {
            var p=project
            let rights=selection.compactMap{p.split($0,at:p.snap(playhead))}
            if !rights.isEmpty {change{$0=p};selection=Set(rights);selected=rights.first}
            return
        }
        guard let id = selected ?? project.clips.first(where:{$0.start < playhead && $0.end > playhead && $0.kind == .video})?.id else { return }
        var next = project
        guard let right = next.split(id,at:next.snap(playhead)) else { return }
        change { $0 = next }; selected = right
    }
    func duplicate() {
        guard var c = current,!project.locked(c.lane) else { return }
        c.id = UUID(); c.start = c.end
        change { p in
            for i in p.clips.indices where p.clips[i].lane==c.lane && p.clips[i].start>=c.start-0.00001 {p.clips[i].start+=c.length}
            p.clips.append(c)
        }; selectClip(c.id)
    }
    func remove(ripple:Bool=false){
        let ids=selection.isEmpty ? Set([selected].compactMap{$0}):selection
        guard !ids.isEmpty else{return}
        change{$0.removeGroup(ids,ripple:ripple)}
        selection=[];selected=nil
    }
    func move(_ id: UUID,to time: Double,lane: Int) {
        guard let c = project.clips.first(where:{$0.id == id}), !project.locked(c.lane) else { return }
        var destination = max(0,time)
        let edges: [Double] = project.clips.filter{$0.id != id && !selection.contains($0.id)}.flatMap{ (clip: Clip) -> [Double] in [clip.start,clip.end] } + [playhead,0.0]
        let candidates=edges.flatMap{[$0,$0-c.length]}.filter{$0>=0}
        if snapping,let edge = candidates.min(by:{abs($0-destination)<abs($1-destination)}), abs(edge-destination) < 8/zoom { destination = edge }
        else { destination = project.snap(destination) }
        let targetLane=c.kind == .audio ? max(project.lanes.last ?? -2,min(-1,lane)) : max(0,min(project.lanes.first ?? 2,lane))
        guard !project.locked(targetLane) else{status="Spur ist gesperrt";return}
        if selection.contains(id),selection.count>1 {
            var next=project
            if next.moveGroup(selection,delta:destination-c.start,laneDelta:targetLane-c.lane){change{$0=next}}
            else{status="Gruppenverschiebung blockiert: Spur oder Clip belegt"}
            return
        }
        let swap=project.clips.first{$0.id != id && $0.lane == targetLane && destination+c.length/2 >= $0.start && destination+c.length/2 < $0.end}
        change { p in
            if let i=p.clips.firstIndex(where:{$0.id==id}) {
                if swapping,let other=swap,c.lane==targetLane,let j=p.clips.firstIndex(where:{$0.id==other.id}) {
                    let left=min(c.start,other.start)
                    let right=max(c.start,other.start)
                    let gap=max(0,right-left-(c.start<other.start ? c.length:other.length))
                    if c.start<other.start {p.clips[j].start=left;p.clips[i].start=left+other.length+gap}
                    else {p.clips[i].start=left;p.clips[j].start=left+c.length+gap}
                    for k in p.clips.indices where k != i && k != j && p.clips[k].lane==targetLane && p.clips[k].start>left && p.clips[k].start<right {
                        p.clips[k].start=max(0,p.clips[k].start+(c.start<other.start ? other.length-c.length:c.length-other.length))
                    }
                } else {
                    guard !p.clips.contains(where:{$0.id != id && $0.lane==targetLane && $0.start<destination+c.length-0.00001 && $0.end>destination+0.00001}) else{return}
                    p.clips[i].start=destination;p.clips[i].lane=targetLane
                }
            }
        }
    }
    func professionalEdit(_ mode:EditMode,frames:Int) {
        guard let id=selected else{return}
        var next=project
        if next.professionalEdit(id,mode:mode,frames:frames){change{$0=next}}
        else{status="Schnitt nicht möglich: Nachbarclip, Quellreserve oder Spur prüfen"}
    }
    func crossDissolve(_ seconds:Double){
        guard let id=selected else{return}
        var next=project
        if next.dissolveInto(id,seconds:seconds){change{$0=next}}
        else{status="Überblendung benötigt zwei angrenzende Videoclips auf freier Spur"}
    }
    func trim(_ c: Clip, delta: Double, leading: Bool) {
        let frame=1/project.frameRate
        let amount=(delta/frame).rounded()*frame
        let media=project.asset(c)
        edit(c.id) { clip in
            if leading {
                let lower=max(-c.start,-c.sourceIn/c.speed)
                let d=max(lower,min(c.length-frame,amount))
                clip.start=c.start+d;clip.sourceIn=c.sourceIn+d*c.speed;clip.length=c.length-d
                if let points=c.keyframes,!points.isEmpty {
                    var boundary=c.pose(at:max(0,d));boundary.id=UUID();boundary.time=0
                    clip.keyframes=[boundary]+points.filter{$0.time>d}.map{p in var q=p;q.time-=d;return q}.filter{$0.time<=clip.length}
                }
            } else {
                let limit=media.map{max(frame,($0.duration-c.sourceIn)/c.speed)} ?? 3600
                clip.length=max(frame,min(limit,c.length+amount))
                if let points=c.keyframes,!points.isEmpty {
                    var boundary=c.pose(at:clip.length);boundary.id=UUID();boundary.time=clip.length
                    clip.keyframes=points.filter{$0.time<clip.length}+[boundary]
                }
            }
        }
    }
    func addKeyframe(_ c:Clip) {
        let time=min(c.length,max(0,playhead-c.start))
        edit(c.id) {clip in
            clip.setPose(clip.pose(at:time),at:time,fps:project.frameRate)
        }
    }
    func editPose(_ c:Clip,key:WritableKeyPath<Clip,Double>,value:Double) {
        let t=max(0,min(c.length,playhead-c.start))
        let rate=project.frameRate
        edit(c.id){clip in
            clip[keyPath:key]=value
            guard !(clip.keyframes ?? []).isEmpty else{return}
            var pose=clip.pose(at:t)
            if key == \.scale {pose.scale=value}
            else if key == \.x {pose.x=value}
            else if key == \.y {pose.y=value}
            else if key == \.rotation {pose.rotation=value}
            else if key == \.opacity {pose.opacity=value}
            else {return}
            clip.setPose(pose,at:t,fps:rate)
        }
    }
    func analyzeCuts(_ c:Clip) {
        guard !analyzing,let m=project.asset(c),c.kind == .video else {return}
        analyzing=true
        let path=m.path
        let start=c.sourceIn
        let length=c.length*c.speed
        Task {
            let times=await Task.detached(priority:.userInitiated){await MediaAnalysis.scenes(path:path,start:start,length:length)}.value
            suggestions[c.id]=times.map{($0-start)/c.speed}
            analyzing=false
        }
    }
    func newProject() {
        let alert = NSAlert(); alert.messageText = "Neues Projekt?"; alert.informativeText = "Speichere das aktuelle Projekt, falls du es behalten möchtest."; alert.addButton(withTitle:"Neu"); alert.addButton(withTitle:"Abbrechen")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        player.pause(); seek(0); fileURL = nil
        change { $0 = Project() }
    }
    func save(asNew: Bool = false) {
        if fileURL == nil || asNew {
            let panel = NSSavePanel(); panel.nameFieldStringValue = project.name + ".lyrocut"
            panel.allowedContentTypes = [UTType(filenameExtension:"lyrocut") ?? .json]
            guard panel.runModal() == .OK else { return }; fileURL = panel.url
        }
        guard let url = fileURL else { return }
        do {
            var data = project; data.schemaVersion=1; data.name = url.deletingPathExtension().lastPathComponent
            try JSONEncoder().encode(data).write(to:url,options:.atomic)
            project.name = data.name; changed(); status = "Gespeichert"
        } catch { self.error = error.localizedDescription }
    }
    func open() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension:"lyrocut") ?? .json]
        guard panel.runModal() == .OK,let url = panel.url else { return }
        do {
            var next = try JSONDecoder().decode(Project.self,from:Data(contentsOf:url))
            guard (next.schemaVersion ?? 1)==1 else{throw RenderError.invalid("Projektversion")}
            for i in next.media.indices where !FileManager.default.fileExists(atPath:next.media[i].path) {
                let relink=NSOpenPanel();relink.message="Quelldatei erneut auswählen: "+next.media[i].name
                relink.allowedContentTypes=[.movie,.video,.audio];relink.allowsMultipleSelection=false
                guard relink.runModal() == .OK,let file=relink.url else{return}
                guard file.lastPathComponent==next.media[i].name else{throw RenderError.invalid("Dateiname stimmt nicht überein")}
                next.media[i].path=file.path
            }
            guard next.fps >= 10 && next.fps <= 120, next.frameRate >= 10 && next.frameRate <= 120,
                  next.clips.allSatisfy({$0.start.isFinite && $0.start >= 0 && $0.length.isFinite && $0.length > 0 && $0.speed > 0 && $0.sourceIn >= 0 && (-12...11).contains($0.lane)}) else { throw RenderError.invalid("Projektdatei") }
            player.pause(); seek(0); fileURL = url; change { $0 = next }
            Task { await makeThumbnails() }
        } catch { self.error = error.localizedDescription }
    }
    func export() {
        guard !busy,project.clips.contains(where:{$0.kind == .video}) else{return}
        exportOptions=true
    }
    func cancelExport() {
        cancelRequested=true
        exportSession?.cancelExport()
        status="Export wird abgebrochen…"
    }
    func performExport(format:ExportFormat,uhd:Bool,fps:Int?) {
        guard !busy else{return}
        exportOptions=false
        var snapshot=project
        snapshot.ultraHD=uhd
        if let fps=fps {snapshot.setFPS(fps)}
        let panel=NSSavePanel()
        panel.allowedContentTypes=[format == .mp4 ? .mpeg4Movie:.quickTimeMovie]
        panel.nameFieldStringValue=project.name+"."+format.suffix
        guard panel.runModal() == .OK,let url=panel.url else{return}
        busy=true;exportProgress=0;cancelRequested=false;status="Export läuft…";player.pause()
        Task {
            let temp=url.deletingLastPathComponent().appendingPathComponent(".lyro-"+UUID().uuidString+"."+format.suffix)
            let monitor=Task {
                while !Task.isCancelled {
                    if let session=exportSession {exportProgress=Double(session.progress)}
                    try? await Task.sleep(nanoseconds:150_000_000)
                }
            }
            defer {monitor.cancel();exportSession=nil;busy=false;try? FileManager.default.removeItem(at:temp)}
            do {
                let graph=try await Renderer.build(snapshot)
                if cancelRequested {status="Export abgebrochen";return}
                try await Renderer.export(graph,to:temp,format:format,onSession:{session in self.exportSession=session})
                if cancelRequested {status="Export abgebrochen";return}
                if FileManager.default.fileExists(atPath:url.path) {_ = try FileManager.default.replaceItemAt(url,withItemAt:temp)}
                else {try FileManager.default.moveItem(at:temp,to:url)}
                exportProgress=1;status="Export abgeschlossen";NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {if cancelRequested {status="Export abgebrochen"} else {self.error=error.localizedDescription;status="Export fehlgeschlagen"}}
        }
    }
}
