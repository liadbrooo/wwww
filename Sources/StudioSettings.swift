import SwiftUI
struct StudioSettings:View {
    @ObservedObject var e:Editor
    @State private var category="Allgemein"
    @State private var reset=false
    let categories=[("Allgemein","gearshape"),("Timeline","timeline.selection"),("Wiedergabe","play.rectangle"),("Export","square.and.arrow.up"),("Speicherung","externaldrive"),("Kurzbefehle","keyboard")]
    var body:some View {
        HStack(spacing:0){
            VStack(alignment:.leading,spacing:5){
                Text("Einstellungen").font(.title3.bold()).padding(.bottom,14)
                ForEach(categories,id:\.0){item in
                    Button{category=item.0}label:{
                        Label(item.0,systemImage:item.1).font(.system(size:13,weight:.medium)).frame(maxWidth:.infinity,alignment:.leading).padding(9)
                            .background(category==item.0 ? Color.white.opacity(0.10):Color.clear,in:RoundedRectangle(cornerRadius:6))
                    }.buttonStyle(.plain)
                }
                Spacer()
                Text("LYRO CUT 0.5.1").font(.caption2).foregroundStyle(.secondary)
            }.padding(16).frame(width:190).background(panel)
            Divider()
            VStack(alignment:.leading,spacing:14){
                Text(category).font(.title2.bold())
                ScrollView{Form{content}.formStyle(.grouped)}
                Divider()
                HStack{Text("Änderungen werden lokal gespeichert.").font(.caption).foregroundStyle(.secondary);Spacer();Button("Zurücksetzen…"){reset=true}}
            }.padding(18).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
        }.frame(width:720,height:490).background(bg)
        .confirmationDialog("Einstellungen zurücksetzen?",isPresented:$reset){Button("Zurücksetzen",role:.destructive){e.resetPreferences()};Button("Abbrechen",role:.cancel){}}
    }
    @ViewBuilder var content:some View {
        switch category {
        case "Allgemein":
            Section("Neue Projekte"){
                Picker("Standardformat",selection:$e.prefs.canvas){ForEach(Canvas.allCases,id:\.self){Text($0.rawValue).tag($0)}}
                Picker("Standardbildrate",selection:$e.prefs.fps){ForEach([24,25,30,50,60],id:\.self){Text("\($0) FPS").tag($0)}}
                Toggle("Format der ersten Videodatei übernehmen",isOn:$e.prefs.matchSource)
            }
        case "Timeline":
            Section("Schnittverhalten"){
                Toggle("Magnetisches Einrasten",isOn:$e.snapping)
                Toggle("Clips beim Verschieben tauschen",isOn:$e.swapping)
                HStack{Text("Magnetradius");Slider(value:$e.prefs.snapDistance,in:2...20,step:1);Text("\(Int(e.prefs.snapDistance)) px").monospacedDigit()}
                Picker("Rückgängig-Schritte",selection:$e.prefs.undoLimit){ForEach([30,80,150],id:\.self){Text("\($0)").tag($0)}}
            }
            Section("Darstellung"){
                Picker("Spurhöhe",selection:$e.prefs.trackHeight){Text("Kompakt").tag(36.0);Text("Normal").tag(47.0);Text("Groß").tag(64.0)}
                Toggle("Audiowellenformen anzeigen",isOn:$e.prefs.showWaveforms)
                Toggle("Clip-Vorschaubilder anzeigen",isOn:$e.prefs.showThumbnails)
            }
        case "Wiedergabe":
            Section("Vorschauauflösung"){
                Picker("Maximale Kantenlänge",selection:$e.prefs.previewLimit){Text("720 px · schnell").tag(720);Text("1280 px").tag(1280);Text("1920 px · ausgewogen").tag(1920);Text("Originalauflösung").tag(0)}
                Text("Die Vorschauqualität beeinflusst nicht den Export.").font(.caption).foregroundStyle(.secondary)
            }
        case "Export":
            Section("Standardwerte"){
                Picker("Dateiformat",selection:$e.prefs.exportFormat){ForEach(ExportFormat.allCases,id:\.rawValue){Text($0.title).tag($0.rawValue)}}
                Picker("Auflösung",selection:$e.prefs.exportResolution){Text("Projekt").tag("project");Text("HD").tag("hd");Text("4K").tag("uhd")}
                Picker("Bildrate",selection:$e.prefs.exportFPS){Text("Projekt").tag(0);ForEach([24,25,30,50,60],id:\.self){Text("\($0) FPS").tag($0)}}
                Toggle("Export im Finder anzeigen",isOn:$e.prefs.revealExport)
            }
        case "Speicherung":
            Section("Lokale Wiederherstellung"){
                Toggle("Projektänderungen automatisch sichern",isOn:$e.prefs.recoveryEnabled)
                Toggle("Letztes Projekt beim Start öffnen",isOn:$e.prefs.restoreLast).disabled(!e.prefs.recoveryEnabled)
                Text("Die Wiederherstellung ersetzt nicht das manuelle Speichern. Medien bleiben in ihren ursprünglichen Dateien. Beim Deaktivieren wird die bisherige Sicherung nicht gelöscht.").font(.caption).foregroundStyle(.secondary)
            }
        default:
            Section("Tastatur"){
                ForEach([("Projekt speichern","⌘ S"),("Projekt öffnen","⌘ O"),("Medien importieren","⌘ I"),("Rückgängig","⌘ Z"),("Clip teilen","⌘ B"),("Abspielen / Pause","Leertaste"),("Exportieren","⌘ E"),("Einstellungen","⌘ ,")],id:\.0){item in LabeledContent(item.0,value:item.1)}
                Text("Die Belegung ist in dieser Version noch fest.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
