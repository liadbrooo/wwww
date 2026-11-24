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
        }.padding(24).frame(width:480).onAppear{uhd=e.project.ultraHD ?? false}
    }
    var exportSize:CGSize {var p=e.project;p.ultraHD=uhd;return p.renderSize}
}
struct EffectStackPanel:View {
    @ObservedObject var e:Editor
    let c:Clip
    var stack:[EffectLayer]{c.effectStack}
    var body:some View {
        VStack(alignment:.leading,spacing:9) {
            HStack {
                Text("EFFEKTSTAPEL").font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach(Effect.allCases.filter{$0 != .none},id:\.self){effect in
                        Button(effect.rawValue.capitalized){e.edit(c.id){clip in clip.effects=clip.effectStack+[EffectLayer(effect:effect)]}}
                    }
                } label:{Image(systemName:"plus.circle")}.menuStyle(.borderlessButton).frame(width:28)
            }
            if stack.isEmpty {Text("Effekte hinzufügen und kombinieren.").font(.caption).foregroundStyle(.secondary)}
            ForEach(Array(stack.enumerated()),id:\.offset){index,layer in
                VStack(alignment:.leading,spacing:5) {
                    HStack {
                        Text(layer.effect.rawValue.capitalized).font(.caption.bold())
                        Spacer()
                        Button{shift(index,-1)} label:{Image(systemName:"chevron.up")}.buttonStyle(.plain).disabled(index==0)
                        Button{shift(index,1)} label:{Image(systemName:"chevron.down")}.buttonStyle(.plain).disabled(index==stack.count-1)
                        Button{e.edit(c.id){clip in var items=clip.effectStack;if items.indices.contains(index){items.remove(at:index)};clip.effects=items}} label:{Image(systemName:"xmark.circle")}.buttonStyle(.plain)
                    }
                    Slider(value:Binding<Double>(get:{layer.intensity},set:{v in e.edit(c.id){clip in var items=clip.effectStack;if items.indices.contains(index){items[index].intensity=v};clip.effects=items}}),in:0...1)
                }.padding(8).background(Color.white.opacity(0.06),in:RoundedRectangle(cornerRadius:6))
            }
        }
    }
    func shift(_ i:Int,_ offset:Int){e.edit(c.id){clip in var items=clip.effectStack;let j=i+offset;if items.indices.contains(i) && items.indices.contains(j){items.swapAt(i,j)};clip.effects=items}}
}
