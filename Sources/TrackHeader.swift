import SwiftUI
struct TrackHeader:View {
    @ObservedObject var e:Editor
    let lane:Int
    let height:CGFloat
    var body:some View {
        HStack(spacing:5){
            Text(lane<0 ? "A\(-lane)" : "V\(lane+1)").font(.system(size:11,weight:.semibold)).foregroundStyle(laneColor(lane))
            Spacer(minLength:0)
            Button{e.change{$0.toggleTrack(lane,\.lockedTracks)}}label:{Image(systemName:e.project.locked(lane) ? "lock.fill":"lock.open")}.help("Spur sperren")
            Button{e.change{$0.toggleTrack(lane,\.mutedTracks)}}label:{Image(systemName:e.project.muted(lane) ? "speaker.slash.fill":"speaker.wave.1")}.help("Audio stummschalten")
            if lane>=0 {Button{e.change{$0.toggleTrack(lane,\.hiddenTracks)}}label:{Image(systemName:e.project.hidden(lane) ? "eye.slash":"eye")}.help("Video ausblenden")}
        }.buttonStyle(.plain).font(.system(size:11)).padding(.horizontal,8).frame(width:128,height:height).overlay(alignment:.bottom){Divider()}
    }
}
