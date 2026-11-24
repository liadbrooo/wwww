import SwiftUI
import AVKit
import AppKit
import UniformTypeIdentifiers

let bg = Color(red:0.075,green:0.080,blue:0.095)
let panel = Color(red:0.105,green:0.112,blue:0.130)
let edge = Color.white.opacity(0.09)
let accent = Color(red:0.52,green:0.71,blue:1)
func stamp(_ seconds: Double) -> String {
    let v = max(0,seconds.isFinite ? seconds : 0)
    let s = Int(v)
    return String(format:"%02d:%02d.%02d",s/60,s%60,Int((v-Double(s))*100))
}
func laneColor(_ lane: Int) -> Color { lane < 0 ? Color(red:0.22,green:0.66,blue:0.52) : lane == 2 ? Color(red:0.72,green:0.47,blue:0.87) : Color(red:0.34,green:0.52,blue:0.83) }

@main struct LyroCut: App {
    @StateObject private var editor = Editor()
    var body: some Scene {
        WindowGroup("LYRO Cut") {
            Workspace(e:editor).frame(minWidth:1000,minHeight:680).preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width:1400,height:900)
        .commands {
            CommandGroup(replacing:.newItem) {
                Button("Neues Projekt") { editor.newProject() }.keyboardShortcut("n")
                Button("Projekt öffnen") { editor.open() }.keyboardShortcut("o")
                Button("Medien importieren") { editor.importMedia() }.keyboardShortcut("i")
                Divider()
                Button("Speichern") { editor.save() }.keyboardShortcut("s")
                Button("Speichern unter") { editor.save(asNew:true) }.keyboardShortcut("s",modifiers:[.command,.shift])
                Button("Video exportieren") { editor.export() }.keyboardShortcut("e")
            }
            CommandGroup(replacing:.undoRedo) {
                Button("Rückgängig") { editor.undo() }.keyboardShortcut("z").disabled(!editor.canUndo)
                Button("Wiederholen") { editor.redo() }.keyboardShortcut("z",modifiers:[.command,.shift]).disabled(!editor.canRedo)
            }
            CommandMenu("Schnitt") {
                Button("Abspielen / Pause") { editor.toggle() }.keyboardShortcut(.space,modifiers:[])
                Button("Clip teilen") { editor.split() }.keyboardShortcut("b")
                Button("Duplizieren") { editor.duplicate() }.keyboardShortcut("d")
                Button("Löschen") { editor.remove() }.keyboardShortcut(.delete,modifiers:[])
                Button("Löschen und Lücke schließen") { editor.remove(ripple:true) }.keyboardShortcut(.delete,modifiers:[.shift])
                Button("Titel hinzufügen") { editor.addTitle() }.keyboardShortcut("t")
            }
        }
        Settings {StudioSettings(e:editor).preferredColorScheme(.dark)}
    }
}
struct PlayerSurface: NSViewRepresentable {
    let player: AVPlayer
    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.controlsStyle = .none
        v.videoGravity = .resizeAspect
        v.player = player
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.black.cgColor
        return v
    }
    func updateNSView(_ nsView: AVPlayerView,context: Context) { if nsView.player !== player { nsView.player = player } }
}
struct Tool: View {
    let symbol: String
    let help: String
    var enabled: Bool = true
    let action: () -> Void
    var body: some View {
        Button(action:action) {
            Image(systemName:symbol).font(.system(size:14,weight:.medium)).frame(width:30,height:30).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.4)).disabled(!enabled).help(help)
    }
}
struct Workspace: View {
    @ObservedObject var e: Editor
    @State private var inspector = true
    @State private var library = true
    var body: some View {
        VStack(spacing:0) {
            header
            Divider()
            HStack(spacing:4){
                ForEach(["Medien","Schnitt","Motion","Farbe","Audio"],id:\.self){mode in
                    Button(mode){e.workspace=mode;library=mode=="Medien" || mode=="Schnitt";inspector=mode != "Medien"}
                        .buttonStyle(.plain).padding(.horizontal,16).padding(.vertical,7)
                        .background(e.workspace==mode ? Color.white.opacity(0.1):Color.clear,in:RoundedRectangle(cornerRadius:5))
                }
            }.frame(maxWidth:.infinity).padding(5).background(panel)
            VSplitView {
                HSplitView {
                    if library { MediaLibrary(e:e).frame(minWidth:185,idealWidth:245,maxWidth:360) }
                    viewer.frame(minWidth:320,minHeight:210)
                    if inspector { Inspector(e:e).frame(minWidth:245,idealWidth:285,maxWidth:360) }
                }.frame(minHeight:240)
                Timeline(e:e).frame(minHeight:280,idealHeight:330)
            }
            HStack(spacing:8) {
                Circle().fill(e.busy ? Color.orange : Color.green).frame(width:6,height:6)
                Text(e.status).lineLimit(1)
                if e.busy {
                    ProgressView(value:e.exportProgress).frame(width:100)
                    Button("Abbrechen"){e.cancelExport()}.buttonStyle(.plain)
                }
                Spacer()
                Text("LOKAL  ·  " + e.project.canvas.rawValue + "  ·  " + String(e.project.fps) + " FPS")
                Text("v0.6.0").foregroundStyle(.tertiary)
            }.font(.system(size:11,weight:.medium)).foregroundStyle(.secondary).padding(.horizontal,14).frame(height:27).background(panel)
        }.background(bg)
        .tint(accent)
        .sheet(isPresented:$e.exportOptions){ExportPanel(e:e)}
        .alert("LYRO Cut",isPresented:Binding(get:{e.error != nil},set:{if !$0 {e.error = nil}})) {
            Button("OK") {e.error = nil}
        } message: { Text(e.error ?? "") }
    }
    var header: some View {
        HStack(spacing:13) {
            HStack(spacing:8) {
                Image(systemName:"film.stack").font(.system(size:19,weight:.semibold)).foregroundStyle(accent)
                Text("LYRO").font(.system(size:15,weight:.heavy,design:.rounded)) + Text(" Cut").font(.system(size:15,weight:.medium))
            }.padding(.leading,75)
            Divider().frame(height:22)
            Tool(symbol:"sidebar.left",help:"Medien ein-/ausblenden") {library.toggle()}
            Tool(symbol:"arrow.uturn.backward",help:"Rückgängig",enabled:e.canUndo) {e.undo()}
            Tool(symbol:"arrow.uturn.forward",help:"Wiederholen",enabled:e.canRedo) {e.redo()}
            Spacer()
            Text(e.project.name).font(.system(size:13,weight:.semibold)).lineLimit(1)
            Spacer()
            Tool(symbol:"sidebar.right",help:"Eigenschaften ein-/ausblenden") {inspector.toggle()}
            SettingsLink {Image(systemName:"gearshape").font(.system(size:15)).frame(width:30,height:30)}.buttonStyle(.plain).help("Einstellungen (⌘, )")
            Button {e.export()} label: {
                HStack(spacing:7) {
                    if e.busy {ProgressView().controlSize(.small)}
                    else {Image(systemName:"square.and.arrow.up")}
                    Text(e.busy ? "Export läuft" : "Exportieren").fontWeight(.semibold)
                }.padding(.horizontal,14).padding(.vertical,8).background(accent,in:RoundedRectangle(cornerRadius:7)).foregroundStyle(Color.black)
            }.buttonStyle(.plain).disabled(e.busy || !e.project.clips.contains{$0.kind == .video})
        }.padding(.horizontal,13).padding(.top,10).frame(height:58).background(panel)
    }
    var viewer: some View {
        VStack(spacing:0) {
            HStack {
                Label("Vorschau",systemImage:"play.rectangle").font(.system(size:12,weight:.semibold))
                Spacer()
                Picker("Format",selection:Binding(get:{e.project.canvas},set:{v in e.change{$0.setCanvas(v)}})) {
                    ForEach(Canvas.allCases,id:\.self) {Text($0.rawValue).tag($0)}
                }.labelsHidden().frame(width:90)
            }.padding(10)
            ZStack {
                Color.black
                PlayerSurface(player:e.player)
                if !e.project.clips.contains(where:{$0.kind == .video}) {
                    VStack(spacing:12) {
                        Image(systemName:"film").font(.system(size:39,weight:.ultraLight)).foregroundStyle(.secondary)
                        Text("Deine Geschichte beginnt hier").font(.system(size:17,weight:.semibold))
                        Text("Importiere Medien und füge sie zur Timeline hinzu.").font(.caption).foregroundStyle(.secondary)
                        Button("Medien importieren") {e.importMedia()}.buttonStyle(.bordered)
                    }
                }
            }.clipShape(RoundedRectangle(cornerRadius:5)).padding(.horizontal,12)
            HStack(spacing:14) {
                Text(stamp(e.playhead)).font(.system(size:12,design:.monospaced)).foregroundStyle(accent)
                Spacer()
                Tool(symbol:"backward.end.fill",help:"Anfang") {e.seek(0)}
                Tool(symbol:"backward.frame",help:"Ein Frame zurück") {e.seek(e.playhead-Double(e.prefs.seekFrames ?? 1)/e.project.frameRate)}
                Tool(symbol:e.playing ? "pause.fill":"play.fill",help:"Abspielen / Pause") {e.toggle()}
                Tool(symbol:"forward.frame",help:"Ein Frame vor") {e.seek(e.playhead+Double(e.prefs.seekFrames ?? 1)/e.project.frameRate)}
                Tool(symbol:"forward.end.fill",help:"Ende") {e.seek(e.project.duration)}
                Spacer()
                Text(stamp(e.project.duration)).font(.system(size:12,design:.monospaced)).foregroundStyle(.secondary)
            }.padding(.horizontal,14).frame(height:43)
        }.background(bg)
    }
}
struct MediaLibrary: View {
    @ObservedObject var e: Editor
    @State private var search = ""
    var items: [Media] {e.project.media.filter{search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)}}
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            HStack {Text("Medien").font(.system(size:13,weight:.semibold)); Spacer(); Tool(symbol:"plus",help:"Importieren"){e.importMedia()}}
            TextField("Medien suchen",text:$search).textFieldStyle(.roundedBorder)
            if items.isEmpty {
                VStack(spacing:9) {
                    Image(systemName:"tray.and.arrow.down").font(.system(size:28,weight:.light))
                    Text("Dateien hier ablegen").font(.caption)
                    Button("Importieren") {e.importMedia()}
                }.foregroundStyle(.secondary).frame(maxWidth:.infinity,maxHeight:.infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:86),spacing:9)],spacing:13) {
                        ForEach(items) {m in
                            VStack(alignment:.leading,spacing:5) {
                                ZStack(alignment:.bottomTrailing) {
                                    RoundedRectangle(cornerRadius:5).fill(Color.white.opacity(0.06))
                                    if let thumb=e.thumbnails[m.id] {Image(nsImage:thumb).resizable().aspectRatio(contentMode:.fill)}
                                    else {Image(systemName:m.kind == .audio ? "waveform":"film").font(.title2).frame(maxWidth:.infinity,maxHeight:.infinity)}
                                    Text(stamp(m.duration)).font(.system(size:9,design:.monospaced)).padding(3).background(.black.opacity(0.75),in:RoundedRectangle(cornerRadius:3)).padding(3)
                                }.frame(height:65).clipped().clipShape(RoundedRectangle(cornerRadius:5))
                                Text(m.name).font(.system(size:11)).lineLimit(1)
                                Button {e.add(m)} label: {Label("Timeline",systemImage:"plus.circle").font(.system(size:10)).foregroundStyle(accent)}.buttonStyle(.plain)
                            }.contentShape(Rectangle()).onTapGesture(count:2){e.add(m)}.onDrag{NSItemProvider(object:("lyro-media:"+m.id.uuidString) as NSString)}
                        }
                    }
                }
            }
            Spacer(minLength:0)
            Divider()
            Button {e.addTitle()} label: {Label("Titel hinzufügen",systemImage:"textformat").frame(maxWidth:.infinity,alignment:.leading)}.buttonStyle(.plain)
            Text("Doppelklick fügt Medien zur Timeline hinzu.").font(.system(size:10)).foregroundStyle(.secondary)
        }.padding(12).background(panel)
        .onDrop(of:[UTType.fileURL.identifier],isTargeted:nil) {providers in
            for p in providers {
                _ = p.loadObject(ofClass:NSURL.self) {object,_ in
                    if let url = object as? URL {Task {@MainActor in await e.importURLs([url])}}
                }
            }; return true
        }
    }
}
struct Inspector: View {
    @ObservedObject var e: Editor
    @State private var tab = "Video"
    let tabs = ["Video","Farbe","Motion","Audio","FX"]
    func bind<T>(_ key: WritableKeyPath<Clip,T>,_ c: Clip) -> Binding<T> {
        Binding(get:{e.current?[keyPath:key] ?? c[keyPath:key]},set:{v in e.edit(c.id){$0[keyPath:key]=v}})
    }
    func control(_ name:String,_ key:WritableKeyPath<Clip,Double>,_ c:Clip,_ range:ClosedRange<Double>,_ step:Double = 0.01) -> some View {
        VStack(alignment:.leading,spacing:4) {
            HStack {Text(name); Spacer(); Text(String(format:"%.2f",e.current?[keyPath:key] ?? c[keyPath:key])).monospacedDigit().foregroundStyle(.secondary)}
            Slider(value:Binding<Double>(get:{
                let clip=e.current ?? c
                let pose=clip.pose(at:max(0,e.playhead-clip.start))
                if key == \.scale {return pose.scale}
                if key == \.x {return pose.x}
                if key == \.y {return pose.y}
                if key == \.rotation {return pose.rotation}
                if key == \.opacity {return pose.opacity}
                return clip[keyPath:key]
            },set:{v in e.editPose(c,key:key,value:v)}),in:range,step:step)
        }.font(.system(size:11))
    }
    func heading(_ text:String) -> some View {Text(text.uppercased()).font(.system(size:10,weight:.semibold)).tracking(0.8).foregroundStyle(.secondary).padding(.top,7)}
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text("Eigenschaften").font(.system(size:13,weight:.semibold))
            panelContent()
        }.padding(13).background(panel)
        .onChange(of:e.workspace){_,mode in
            tab=["Motion":"Motion","Farbe":"Farbe","Audio":"Audio"][mode] ?? "Video"
        }
    }
    func panelContent() -> AnyView {
        if let c=e.current {return AnyView(clipPanel(c))}
        return AnyView(projectPanel())
    }
    func clipPanel(_ c:Clip) -> some View {
        VStack(alignment:.leading,spacing:12) {
            Text(c.name).font(.system(size:12)).lineLimit(1).foregroundStyle(.secondary)
            Picker("",selection:$tab) {ForEach(tabs,id:\.self){Text($0).tag($0)}}.pickerStyle(.segmented)
            ScrollView {
                VStack(alignment:.leading,spacing:12) {activeControls(c)}.padding(.trailing,5)
            }
        }
    }
    func activeControls(_ c:Clip) -> AnyView {
        switch tab {
        case "Video":return AnyView(videoControls(c))
        case "Farbe":return AnyView(colorControls(c))
        case "Motion":return AnyView(motionControls(c))
        case "FX":return AnyView(effectControls(c))
        default:return AnyView(audioControls(c))
        }
    }
    func projectPanel() -> some View {
        let dimensions = e.project.renderSize
        let outputLabel = String(format:"%.0f × %.0f px",Double(dimensions.width),Double(dimensions.height))
        let sourceLabel = String(format:"Originalformat %.0f × %.0f",e.project.sourceCanvasWidth ?? 0,e.project.sourceCanvasHeight ?? 0)
        let uhd = Binding<Bool>(get:{e.project.ultraHD ?? false},set:{v in e.change{$0.ultraHD=v}})
        let format = Binding<Canvas>(get:{e.project.canvas},set:{v in e.change{$0.setCanvas(v)}})
        let fps = Binding<Int>(get:{e.project.fps},set:{v in e.change{$0.setFPS(v)}})
        return VStack(alignment:.leading,spacing:12) {
            Text("Projekteinstellungen").font(.headline)
            if e.project.sourceCanvasWidth != nil {Text(sourceLabel).font(.caption).foregroundStyle(.secondary)}
            if let rate=e.project.sourceFPS {Text(String(format:"Originalbildrate %.3f FPS",rate)).font(.caption).foregroundStyle(.secondary)}
            Toggle("4K / UHD Export",isOn:uhd)
            Text(outputLabel).font(.caption).foregroundStyle(.secondary)
            Button("Quellformat wiederherstellen"){e.change{$0.setSourceFormat()}}.disabled(e.project.media.isEmpty)
            Picker("Bildformat",selection:format) {ForEach(Canvas.allCases,id:\.self){Text($0.rawValue).tag($0)}}
            Picker("Bildrate",selection:fps) {ForEach([24,25,30,50,60],id:\.self){Text("\($0) fps").tag($0)}}
            Text("Wähle einen Clip aus, um seine Eigenschaften zu bearbeiten.").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
    }
    @ViewBuilder func videoControls(_ c:Clip) -> some View {
        heading("Clip")
        if c.kind == .video {
            Button {e.analyzeCuts(c)} label:{Label(e.analyzing ? "Analysiere…" : "Schnittvorschläge",systemImage:"wand.and.stars")}.disabled(e.analyzing)
            if let times=e.suggestions[c.id] {
                if times.isEmpty {Text("Keine deutlichen Szenenwechsel erkannt.").font(.caption).foregroundStyle(.secondary)}
                ForEach(times,id:\.self){t in
                    HStack {
                        Button(stamp(t)){e.seek(c.start+t)}.buttonStyle(.plain)
                        Spacer()
                        Button("Teilen"){e.seek(c.start+t);e.selected=c.id;e.split()}.buttonStyle(.bordered)
                    }.font(.caption)
                }
            }
        }
        if c.kind == .title {
            TextField("Titeltext",text:bind(\.title,c))
            control("Schriftgröße",\.fontSize,c,20...200,1)
        }
        if let m=e.project.asset(c) {
            let maxIn=max(0.01,m.duration-c.length*c.speed)
            control("Quellstart (s)",\.sourceIn,c,0...maxIn)
            let maxLength=max(0.05,(m.duration-c.sourceIn)/c.speed)
            control("Dauer (s)",\.length,c,0.04...maxLength)
            VStack(alignment:.leading) {
                Text("Geschwindigkeit").font(.caption)
                Picker("",selection:Binding(get:{c.speed},set:{v in e.edit(c.id){$0.length=$0.length*$0.speed/v;$0.speed=v}})) {
                    ForEach([0.25,0.5,0.75,1.0,1.25,1.5,2.0,3.0,4.0],id:\.self){Text(String(format:"%g×",$0)).tag($0)}
                }.labelsHidden()
            }
        } else {control("Dauer (s)",\.length,c,0.1...60)}
        transformControls(c)
    }
    @ViewBuilder func transformControls(_ c:Clip) -> some View {
        heading("Transformation")
        Toggle("Bild füllend",isOn:Binding(get:{c.fill ?? false},set:{v in e.edit(c.id){$0.fill=v}}))
        control("Skalierung",\.scale,c,0.1...4)
        control("Horizontal",\.x,c,-1...1)
        control("Vertikal",\.y,c,-1...1)
        control("Drehung",\.rotation,c,-180...180,1)
        control("Deckkraft",\.opacity,c,0...1)
        Button("Transformation zurücksetzen") {e.edit(c.id){$0.scale=1;$0.x=0;$0.y=0;$0.rotation=0;$0.opacity=1}}
    }
    @ViewBuilder func colorControls(_ c:Clip) -> some View {
        heading("Looks")
        Picker("Filter",selection:bind(\.look,c)) {ForEach(Look.allCases,id:\.self){Text($0.rawValue.capitalized).tag($0)}}
        heading("Korrektur")
        control("Helligkeit",\.brightness,c,-0.5...0.5)
        control("Kontrast",\.contrast,c,0.2...3)
        control("Sättigung",\.saturation,c,0...2)
        Button("Farben zurücksetzen"){e.edit(c.id){$0.look = .original;$0.brightness=0;$0.contrast=1;$0.saturation=1}}
    }
    @ViewBuilder func motionControls(_ c:Clip) -> some View {
        heading("Animation")
        Picker("Bewegung",selection:bind(\.motion,c)) {ForEach(Motion.allCases,id:\.self){Text($0.rawValue).tag($0)}}
        control("Einblenden (s)",\.fadeIn,c,0...max(0.01,c.length/2))
        control("Ausblenden (s)",\.fadeOut,c,0...max(0.01,c.length/2))
        KeyframeEditor(e:e,c:c)
        Text("Überlappe Clips auf V1 und V2 und blende V2 ein, um eine Überblendung zu erzeugen.").font(.caption).foregroundStyle(.secondary)
    }
    @ViewBuilder func effectControls(_ c:Clip) -> some View {
        EffectStackPanel(e:e,c:c)
        heading("Maske")
        Picker("Form",selection:Binding<Mask>(get:{c.mask ?? Mask.none},set:{v in e.edit(c.id){$0.mask=v}})){
            ForEach(Mask.allCases,id:\.self){Text($0.rawValue.capitalized).tag($0)}
        }
        if c.mask != nil && c.mask != Mask.none {
            Text("Größe").font(.caption)
            Slider(value:Binding(get:{c.maskSize ?? 0.8},set:{v in e.edit(c.id){$0.maskSize=v}}),in:0.05...1)
            Text("Horizontal").font(.caption)
            Slider(value:Binding(get:{c.maskX ?? 0},set:{v in e.edit(c.id){$0.maskX=v}}),in:-0.5...0.5)
            Text("Vertikal").font(.caption)
            Slider(value:Binding(get:{c.maskY ?? 0},set:{v in e.edit(c.id){$0.maskY=v}}),in:-0.5...0.5)
            Text("Breite").font(.caption)
            Slider(value:Binding(get:{c.maskAspect ?? 1},set:{v in e.edit(c.id){$0.maskAspect=v}}),in:0.1...3)
        }
    }
    @ViewBuilder func audioControls(_ c:Clip) -> some View {
        heading("Lautstärke")
        control("Pegel",\.volume,c,0...1)
        Text("Audio einblenden").font(.caption)
        Slider(value:Binding(get:{c.audioFadeIn ?? 0},set:{v in e.edit(c.id){$0.audioFadeIn=v}}),in:0...max(0.01,c.length/2))
        Text("Audio ausblenden").font(.caption)
        Slider(value:Binding(get:{c.audioFadeOut ?? 0},set:{v in e.edit(c.id){$0.audioFadeOut=v}}),in:0...max(0.01,c.length/2))
        Button("Stummschalten"){e.edit(c.id){$0.volume=0}}
        Button("Originalpegel"){e.edit(c.id){$0.volume=1}}
    }
}
struct Timeline: View {
    @ObservedObject var e: Editor
    var lanes:[Int]{e.project.lanes}
    var rowHeight: CGFloat {CGFloat(e.prefs.trackHeight)}
    var width: CGFloat {max(600,(e.project.duration+6)*e.zoom)}
    var body: some View {
        VStack(spacing:0) {
            HStack(spacing:8) {
                Text("Timeline").font(.system(size:13,weight:.semibold)).padding(.trailing,8)
                Tool(symbol:"scissors",help:"Am Abspielkopf teilen"){e.split()}
                Tool(symbol:"plus.square.on.square",help:"Duplizieren",enabled:e.current != nil){e.duplicate()}
                Tool(symbol:"trash",help:"Löschen",enabled:e.current != nil){e.remove()}
                Tool(symbol:"arrow.left.to.line",help:"Löschen & Lücke schließen",enabled:e.current != nil){e.remove(ripple:true)}
                Divider().frame(height:19)
                Tool(symbol:"textformat",help:"Titel"){e.addTitle()}
                ProfessionalTools(e:e)
                Menu {Button("Videospur hinzufügen"){e.change{$0.addTrack(audio:false)}};Button("Audiospur hinzufügen"){e.change{$0.addTrack(audio:true)}};Button("Marker setzen"){e.change{$0.markers=($0.markers ?? [])+[TimelineMarker(time:e.playhead,name:"Marker")]}};Button("Marker löschen"){e.change{$0.markers=[]}}} label:{Image(systemName:"plus")}.menuStyle(.borderlessButton).frame(width:32)
                Spacer()
                Toggle("Magnet",isOn:$e.snapping).toggleStyle(.button).help("Magnetisches Einrasten")
                Toggle("Tauschen",isOn:$e.swapping).toggleStyle(.button).help("Clips beim Verschieben tauschen")
                Image(systemName:"minus.magnifyingglass").foregroundStyle(.secondary)
                Slider(value:$e.zoom,in:12...160).frame(width:100)
                Image(systemName:"plus.magnifyingglass").foregroundStyle(.secondary)
            }.padding(.horizontal,12).frame(height:42).background(panel)
            ScrollView(.vertical){
            HStack(alignment:.top,spacing:0) {
                VStack(spacing:0) {
                    Text("SPUREN").font(.system(size:9,weight:.semibold)).foregroundStyle(.secondary).frame(width:128,height:26)
                    ForEach(lanes,id:\.self){lane in
                        TrackHeader(e:e,lane:lane,height:rowHeight)
                    }
                }.background(panel)
                ScrollView(.horizontal) {
                    VStack(alignment:.leading,spacing:0) {
                        ZStack(alignment:.topLeading) {
                            Rectangle().fill(panel)
                            ForEach(0...Int(width/e.zoom),id:\.self){second in
                                if e.zoom >= 35 || second%5 == 0 {
                                    VStack(alignment:.leading,spacing:3) {
                                        Text(stamp(Double(second)).prefix(5)).font(.system(size:9,design:.monospaced)).foregroundStyle(.secondary)
                                        Rectangle().fill(Color.white.opacity(0.25)).frame(width:1,height:5)
                                    }.offset(x:CGFloat(second)*e.zoom+3,y:3)
                                }
                            }
                            ForEach(e.project.markers ?? []){marker in
                                Button {e.seek(marker.time)} label:{Image(systemName:"bookmark.fill").foregroundStyle(Color.orange).font(.system(size:10))}
                                    .buttonStyle(.plain).offset(x:marker.time*e.zoom,y:11)
                            }
                        }.frame(width:width,height:26).contentShape(Rectangle())
                         .gesture(DragGesture(minimumDistance:0).onChanged{e.seek(Double($0.location.x)/e.zoom)})
                        ZStack(alignment:.topLeading) {
                            VStack(spacing:0) {
                                ForEach(lanes,id:\.self){lane in
                                    Rectangle().fill(lane%2==0 ? Color.white.opacity(0.025):Color.white.opacity(0.045))
                                        .frame(width:width,height:rowHeight).overlay(alignment:.bottom){Divider()}
                                        .contentShape(Rectangle()).onTapGesture{e.selected=nil}
                                }
                            }
                            ForEach(0...Int(width/e.zoom),id:\.self){second in
                                if second%5==0 {Rectangle().fill(edge).frame(width:1,height:rowHeight*CGFloat(lanes.count)).offset(x:CGFloat(second)*e.zoom).allowsHitTesting(false)}
                            }
                            ForEach(e.project.clips){c in
                                if let row=lanes.firstIndex(of:c.lane) {
                                    ClipTile(e:e,c:c,row:row,rowHeight:rowHeight)
                                }
                            }
                            Rectangle().fill(accent).frame(width:1.5,height:rowHeight*CGFloat(lanes.count)).offset(x:e.playhead*e.zoom).allowsHitTesting(false)
                        }.frame(width:width,height:rowHeight*CGFloat(lanes.count),alignment:.topLeading).onDrop(of:[UTType.text.identifier],delegate:MediaDrop(e:e,lanes:lanes,rowHeight:rowHeight))
                    }.overlay(alignment:.topLeading){
                        Image(systemName:"triangle.fill").rotationEffect(.degrees(180)).font(.system(size:9)).foregroundStyle(accent).offset(x:e.playhead*e.zoom-4,y:20).allowsHitTesting(false)
                    }
                }
            }
            }
            Spacer(minLength:0)
        }.background(bg)
    }
}
struct ClipTile: View {
    @ObservedObject var e: Editor
    let c: Clip
    let row: Int
    let rowHeight: CGFloat
    @GestureState private var drag: CGSize = .zero
    var body: some View {
        let w = max(8,c.length*e.zoom)
        HStack(spacing:5) {
            if e.prefs.showThumbnails,c.kind == .video,let id=c.mediaID,let thumb=e.thumbnails[id],w>55 {
                Image(nsImage:thumb).resizable().aspectRatio(contentMode:.fill).frame(width:42,height:32).clipped()
            } else if w>25 {Image(systemName:c.kind == .title ? "textformat":c.kind == .audio ? "waveform":"film").font(.caption)}
            if w>38 {Text(c.kind == .title ? c.title:c.name).font(.system(size:10,weight:.semibold)).lineLimit(1)}
            Spacer(minLength:0)
        }.padding(.horizontal,5).frame(width:w,height:rowHeight-7).clipped()
        .background(laneColor(c.lane).opacity(e.selection.contains(c.id) ? 0.83:0.49),in:RoundedRectangle(cornerRadius:4))
        .overlay(alignment:.bottom) {
            if e.prefs.showWaveforms,let id=c.mediaID,let peaks=e.waveforms[id],!peaks.isEmpty {
                WaveformStrip(peaks:peaks,sourceIn:c.sourceIn,sourceLength:c.length*c.speed,mediaDuration:e.project.asset(c)?.duration ?? c.length)
                    .frame(height:c.kind == .audio ? rowHeight-10 : 12).padding(.horizontal,4).allowsHitTesting(false)
            }
        }
        .overlay(RoundedRectangle(cornerRadius:4).strokeBorder(e.selection.contains(c.id) ? Color.white:laneColor(c.lane),lineWidth:e.selection.contains(c.id) ? 1.5:0.7))
        .onTapGesture{e.selectClip(c.id,extend:NSEvent.modifierFlags.contains(.command) || NSEvent.modifierFlags.contains(.shift))}
        .gesture(DragGesture(minimumDistance:4).updating($drag){value,state,_ in state=value.translation}.onEnded{value in
            if !e.selection.contains(c.id){e.selectClip(c.id)}
            e.move(c.id,to:c.start+Double(value.translation.width)/e.zoom,lane:c.lane-Int((value.translation.height/rowHeight).rounded()))
        })
        .overlay(alignment:.leading) { trimHandle(leading:true) }
        .overlay(alignment:.trailing) { trimHandle(leading:false) }
        .offset(x:c.start*e.zoom+drag.width,y:CGFloat(row)*rowHeight+3+drag.height)
        .opacity(e.project.hidden(c.lane) || e.project.locked(c.lane) ? 0.5:1)
        .contextMenu {
            Button("Teilen"){e.selected=c.id;e.split()}
            Button("Duplizieren"){e.selected=c.id;e.duplicate()}
            Button("Löschen"){e.selected=c.id;e.remove()}
            Button("Lücke schließen"){e.selected=c.id;e.remove(ripple:true)}
        }
    }
    func trimHandle(leading:Bool)->some View {
        Rectangle().fill(e.selection.contains(c.id) ? Color.white.opacity(0.85):Color.white.opacity(0.18))
            .frame(width:5,height:rowHeight-12)
            .contentShape(Rectangle().inset(by:-3))
            .highPriorityGesture(DragGesture(minimumDistance:2).onEnded{v in
                e.selected=c.id;e.trim(c,delta:Double(v.translation.width)/e.zoom,leading:leading)
            })
    }
}
