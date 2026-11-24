import SwiftUI
struct ProfessionalTools:View {
    @ObservedObject var e:Editor
    @State private var mode:EditMode = .ripple
    @State private var frames=1
    var body:some View {
        Menu {
            Picker("Schnittmodus",selection:$mode){ForEach(EditMode.allCases,id:\.self){Text($0.rawValue.capitalized).tag($0)}}
            Picker("Schrittweite",selection:$frames){ForEach([1,5,10,30],id:\.self){Text("\($0) Frames").tag($0)}}
            Divider()
            Button("− \(frames) Frames"){e.professionalEdit(mode,frames:-frames)}
            Button("+ \(frames) Frames"){e.professionalEdit(mode,frames:frames)}
            Divider()
            Button("Überblendung 0,25 s"){e.crossDissolve(0.25)}
            Button("Überblendung 0,5 s"){e.crossDissolve(0.5)}
            Button("Überblendung 1 s"){e.crossDissolve(1)}
        } label:{Label("Pro Trim",systemImage:"slider.horizontal.3")}
        .menuStyle(.borderlessButton).fixedSize().disabled(e.current==nil)
        .help("Ripple: Ende und Folgeclips. Roll: Schnittkante. Slip: Quellzeit. Slide: Clip zwischen Nachbarn.")
    }
}
