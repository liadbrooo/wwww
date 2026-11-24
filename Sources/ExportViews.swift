import SwiftUI
struct ExportPanel:View {
    @ObservedObject var e:Editor
    @Environment(\.dismiss) var dismiss
    @State private var format:ExportFormat = .mp4
    @State private var uhd=false
    @State private var fps=0
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {
                Image(systemName:"square.and.arrow.up").font(.system(size:25,weight:.light)).foregroundStyle(accent)
                VStack(alignment:.leading) {Text("Video exportieren").font(.title2.bold());Text("Dein Projekt, fertig für die Welt.").font(.caption).foregroundStyle(.secondary)}
                Spacer()
            }
            Divider()
            Picker("Format",selection:$format){ForEach(ExportFormat.allCases,id:\.self){Text($0.title).tag($0)}}
            Picker("Auflösung",selection:$uhd){Text("HD / 1080p").tag(false);Text("UHD / 4K").tag(true)}.pickerStyle(.segmented)
            Picker("Bildrate",selection:$fps){Text("Projekt").tag(0);ForEach([24,25,30,50,60],id:\.self){Text("\($0) FPS").tag($0)}}
            let size=exportSize
            HStack {
                VStack(alignment:.leading){Text("Auflösung").font(.caption).foregroundStyle(.secondary);Text("\(Int(size.width)) × \(Int(size.height))").font(.headline.monospacedDigit())}
                Spacer()
                VStack(alignment:.leading){Text("Dauer").font(.caption).foregroundStyle(.secondary);Text(stamp(e.project.duration)).font(.headline.monospacedDigit())}
            }.padding(14).background(Color.white.opacity(0.05),in:RoundedRectangle(cornerRadius:8))
            HStack {
                Spacer()
                Button("Abbrechen"){dismiss()}
                Button("Exportieren…"){dismiss();DispatchQueue.main.async {e.performExport(format:format,uhd:uhd,fps:fps==0 ? nil:fps)}}.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
            }
        }.padding(24).frame(width:480).onAppear{
            format=ExportFormat(rawValue:e.prefs.exportFormat) ?? .mp4
            uhd=e.prefs.exportResolution=="project" ? (e.project.ultraHD ?? false):e.prefs.exportResolution=="uhd"
            fps=e.prefs.exportFPS
        }
    }
    var exportSize:CGSize {var p=e.project;p.ultraHD=uhd;return p.renderSize}
}
struct EffectStackPanel:View {
    @ObservedObject var e:Editor
    let c:Clip
    @State private var search=""
    @State private var showLibrary=false
    @State private var savedPresets:[FXPreset]=(try? JSONDecoder().decode([FXPreset].self,from:UserDefaults.standard.data(forKey:"LYRO.FXPresets") ?? Data())) ?? []
    @State private var presetName=""
    @State private var savePreset=false
    var stack:[EffectLayer]{c.effectStack}
    let groups=["Schärfe & Unschärfe","Licht & Farbe","Film & Stil","Verzerrung & Struktur"]
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Text("EFFEKTSTAPEL").font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button{showLibrary.toggle()}label:{Label("Effekte",systemImage:"plus.circle")}.buttonStyle(.bordered)
            }
            presetMenu
            if showLibrary {library}
            if stack.isEmpty {Text("Kombiniere Effekte in beliebiger Reihenfolge.").font(.caption).foregroundStyle(.secondary)}
            ForEach(Array(stack.enumerated()),id:\.offset){index,layer in
                EffectCard(e:e,c:c,index:index,layer:layer,total:stack.count)
            }
            if !stack.isEmpty{Button("Alle Effekte entfernen"){e.edit(c.id){$0.effects=[];$0.effect=nil}}.font(.caption)}
        }
    }
    var presetMenu:some View {
        VStack(alignment:.leading,spacing:5){
            Menu("Looks & Vorlagen"){
                ForEach(FXPreset.builtIn){preset in Button(preset.name){applyPreset(preset)}}
                if !savedPresets.isEmpty{Divider();ForEach(savedPresets){preset in Button(preset.name){applyPreset(preset)}}}
                Divider()
                Button("Aktuellen Stapel speichern…"){presetName="";savePreset=true}.disabled(stack.isEmpty)
                if !savedPresets.isEmpty{Menu("Eigene Vorlagen löschen"){ForEach(savedPresets){preset in Button(preset.name,role:.destructive){savedPresets.removeAll{$0.id==preset.id};persistPresets()}}}}
            }.menuStyle(.borderedButton)
        }.alert("Effektvorlage speichern",isPresented:$savePreset){TextField("Name",text:$presetName);Button("Speichern"){let name=presetName.trimmingCharacters(in:.whitespacesAndNewlines);if !name.isEmpty{savedPresets.append(FXPreset(name:name,layers:stack));persistPresets()}};Button("Abbrechen",role:.cancel){}}
    }
    func applyPreset(_ preset:FXPreset){e.edit(c.id){$0.effects=$0.effectStack+preset.freshLayers()}}
    func persistPresets(){if let data=try? JSONEncoder().encode(savedPresets){UserDefaults.standard.set(data,forKey:"LYRO.FXPresets")}}
    var library:some View {
        VStack(alignment:.leading,spacing:7){
            TextField("Effekte suchen",text:$search).textFieldStyle(.roundedBorder)
            ForEach(groups,id:\.self){group in
                let matching=Effect.allCases.filter{$0.category==group && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search))}
                if !matching.isEmpty {
                    Text(group.uppercased()).font(.system(size:9,weight:.semibold)).foregroundStyle(.secondary)
                    ForEach(matching,id:\.self){effect in
                        Button {
                            var layer=EffectLayer(effect:effect,intensity:e.prefs.defaultEffectStrength ?? 0.5)
                            layer.mix=e.prefs.defaultEffectMix ?? 1
                            e.edit(c.id){$0.effects=$0.effectStack+[layer]}
                            showLibrary=false
                        }label:{HStack{Text(effect.title);Spacer();Image(systemName:"plus")}.font(.caption).padding(4)}.buttonStyle(.plain)
                    }
                }
            }
        }.padding(8).background(Color.black.opacity(0.2),in:RoundedRectangle(cornerRadius:6))
    }
}
struct EffectCard:View {
    @ObservedObject var e:Editor
    let c:Clip
    let index:Int
    let layer:EffectLayer
    let total:Int
    func modify(_ change:(inout EffectLayer)->Void){e.edit(c.id){clip in var items=clip.effectStack;guard items.indices.contains(index) else{return};change(&items[index]);clip.effects=items}}
    func shift(_ offset:Int){e.edit(c.id){clip in var items=clip.effectStack;let j=index+offset;if items.indices.contains(index) && items.indices.contains(j){items.swapAt(index,j)};clip.effects=items}}
    var body:some View {
        VStack(alignment:.leading,spacing:6){
            HStack(spacing:6){
                Button{modify{$0.enabled = !($0.enabled ?? true)}}label:{Image(systemName:layer.enabled==false ? "eye.slash":"eye")}.buttonStyle(.plain)
                Text(layer.effect.title).font(.caption.bold())
                Spacer(minLength:0)
                Button{shift(-1)}label:{Image(systemName:"chevron.up")}.disabled(index==0).buttonStyle(.plain)
                Button{shift(1)}label:{Image(systemName:"chevron.down")}.disabled(index==total-1).buttonStyle(.plain)
                Button{e.edit(c.id){clip in var items=clip.effectStack;if items.indices.contains(index){items.remove(at:index)};clip.effects=items}}label:{Image(systemName:"xmark.circle")}.buttonStyle(.plain)
            }
            parameter("Stärke",layer.intensity,0...1){v in modify{$0.intensity=v}}
            parameter("Mischung",layer.mix ?? 1,0...1){v in modify{$0.mix=v}}
            if layer.effect.hasDetail {parameter("Detail / Radius",layer.detail ?? 0.5,0...1){v in modify{$0.detail=v}}}
            if layer.effect.hasAngle {parameter("Winkel",layer.angle ?? 0,-180...180){v in modify{$0.angle=v}}}
        }.padding(8).background(Color.white.opacity(0.06),in:RoundedRectangle(cornerRadius:6)).opacity(layer.enabled==false ? 0.6:1)
    }
    func parameter(_ title:String,_ value:Double,_ range:ClosedRange<Double>,_ set:@escaping(Double)->Void)->some View {
        VStack(spacing:2){HStack{Text(title);Spacer();Text(String(format:"%.2f",value)).monospacedDigit()}.font(.caption2).foregroundStyle(.secondary);Slider(value:Binding(get:{value},set:set),in:range)}
    }
}
