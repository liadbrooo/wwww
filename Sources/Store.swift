import Foundation
import AVFoundation
import SwiftUI
import AppKit
import UniformTypeIdentifiers

@MainActor final class Editor: ObservableObject {
    @Published var project = Project()
    @Published var selected: UUID?
    @Published var playhead: Double = 0
    @Published var playing = false
    @Published var error: String?
    @Published var busy = false
    @Published var status = "Bereit"
    @Published var zoom: Double = 48
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
                self.playhead = time.seconds.isFinite ? time.seconds : 0
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
        guard let index = project.clips.firstIndex(where:{$0.id == id}) else { return }
        if lastEdit?.0 != id || Date().timeIntervalSince(lastEdit?.1 ?? .distantPast) > 0.7 { record() }
        lastEdit = (id,Date())
        work(&project.clips[index])
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
                let graph = try await Renderer.build(snapshot)
                guard !Task.isCancelled else { return }
                let at = min(playhead,max(0,snapshot.duration-0.001))
                let resume = player.rate != 0
                player.replaceCurrentItem(with:graph.playerItem())
                player.seek(to:ct(at),toleranceBefore:.zero,toleranceAfter:.zero)
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
                added.append(Media(path:url.path,name:url.lastPathComponent,duration:duration,kind:videos.isEmpty ? .audio : .video))
            } catch { failures.append(url.lastPathComponent) }
        }
        if !added.isEmpty { change { $0.media.append(contentsOf:added) }; await makeThumbnails() }
        status = "Bereit"
        if !failures.isEmpty { error = "Nicht unterstützte Medien: " + failures.joined(separator:", ") }
    }
    func makeThumbnails() async {
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
    func add(_ media: Media) {
        let lane = media.kind == .audio ? -1 : 0
        let start = project.clips.filter{$0.lane == lane}.map(\.end).max() ?? 0
        let clip = Clip(mediaID:media.id,name:media.name,kind:media.kind,start:start,length:media.duration,lane:lane)
        change { $0.clips.append(clip) }; selected = clip.id
    }
    func addTitle() {
        let clip = Clip(name:"Titel",kind:.title,start:playhead,length:3,lane:2)
        change { $0.clips.append(clip) }; selected = clip.id
    }
    func split() {
        guard let id = selected ?? project.clips.first(where:{$0.start < playhead && $0.end > playhead && $0.kind == .video})?.id else { return }
        var next = project
        guard let right = next.split(id,at:playhead) else { return }
        change { $0 = next }; selected = right
    }
    func duplicate() {
        guard var c = current else { return }
        c.id = UUID(); c.start = c.end
        change { $0.clips.append(c) }; selected = c.id
    }
    func remove(ripple: Bool = false) {
        guard let c = current else { return }
        change { p in
            p.clips.removeAll{$0.id == c.id}
            if ripple {
                for i in p.clips.indices where p.clips[i].lane == c.lane && p.clips[i].start >= c.end-0.001 { p.clips[i].start -= c.length }
            }
        }
    }
    func move(_ id: UUID,to time: Double,lane: Int) {
        guard let c = project.clips.first(where:{$0.id == id}) else { return }
        var destination = max(0,time)
        let edges = project.clips.filter{$0.id != id}.flatMap{[$0.start,$0.end]} + [playhead,0]
        if let edge = edges.min(by:{abs($0-destination)<abs($1-destination)}), abs(edge-destination) < 8/zoom { destination = edge }
        else { destination = (destination*Double(project.fps)).rounded()/Double(project.fps) }
        edit(id) { $0.start = destination; $0.lane = c.kind == .audio ? min(-1,lane) : max(0,lane) }
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
            var data = project; data.name = url.deletingPathExtension().lastPathComponent
            try JSONEncoder().encode(data).write(to:url,options:.atomic)
            project.name = data.name; changed(); status = "Gespeichert"
        } catch { self.error = error.localizedDescription }
    }
    func open() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension:"lyrocut") ?? .json]
        guard panel.runModal() == .OK,let url = panel.url else { return }
        do {
            let next = try JSONDecoder().decode(Project.self,from:Data(contentsOf:url))
            guard [24,25,30,50,60].contains(next.fps),
                  next.clips.allSatisfy({$0.start.isFinite && $0.start >= 0 && $0.length.isFinite && $0.length > 0 && $0.speed > 0 && $0.sourceIn >= 0 && (-2...2).contains($0.lane)}) else { throw RenderError.invalid("Projektdatei") }
            player.pause(); seek(0); fileURL = url; change { $0 = next }
            Task { await makeThumbnails() }
        } catch { self.error = error.localizedDescription }
    }
    func export() {
        guard !busy else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.mpeg4Movie]; panel.nameFieldStringValue = project.name + ".mp4"
        guard panel.runModal() == .OK,let url = panel.url else { return }
        let snapshot = project
        busy = true; status = "Export läuft…"; player.pause()
        Task {
            let temp = url.deletingLastPathComponent().appendingPathComponent(".lyro-" + UUID().uuidString + ".mp4")
            defer { busy = false; try? FileManager.default.removeItem(at:temp) }
            do {
                let graph = try await Renderer.build(snapshot)
                try await Renderer.export(graph,to:temp)
                if FileManager.default.fileExists(atPath:url.path) {
                    _ = try FileManager.default.replaceItemAt(url,withItemAt:temp)
                } else { try FileManager.default.moveItem(at:temp,to:url) }
                status = "Export abgeschlossen"; NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch { self.error = error.localizedDescription; status = "Export fehlgeschlagen" }
        }
    }
}
