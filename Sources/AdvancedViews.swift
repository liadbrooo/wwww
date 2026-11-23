import SwiftUI
import UniformTypeIdentifiers

struct MediaDrop: DropDelegate {
    let e: Editor
    let lanes:[Int]
    let rowHeight:CGFloat
    func performDrop(info:DropInfo)->Bool {
        let location=info.location
        let lane=lanes[max(0,min(lanes.count-1,Int(location.y/rowHeight)))]
        guard let provider=info.itemProviders(for:[UTType.text]).first else {return false}
        provider.loadObject(ofClass:NSString.self){value,_ in
            guard let value=value as? String,value.hasPrefix("lyro-media:"),let id=UUID(uuidString:String(value.dropFirst(11))) else {return}
            Task {@MainActor in
                if let m=e.project.media.first(where:{$0.id==id}) {e.add(m,at:Double(location.x)/e.zoom,lane:lane)}
            }
        }
        return true
    }
}
struct KeyframeEditor: View {
    @ObservedObject var e:Editor
    let c:Clip
    @State var property="Zoom"
    var points:[Keyframe]{(c.keyframes ?? []).sorted{$0.time<$1.time}}
    func value(_ k:Keyframe)->Double {
        switch property {case "X":return k.x;case "Y":return k.y;case "Rotation":return k.rotation/180;case "Opacity":return k.opacity;default:return k.scale/4}
    }
    func setValue(_ k:inout Keyframe,_ v:Double) {
        switch property {case "X":k.x=max(-1,min(1,v));case "Y":k.y=max(-1,min(1,v));case "Rotation":k.rotation=max(-180,min(180,v*180));case "Opacity":k.opacity=max(0,min(1,v));default:k.scale=max(0.1,min(4,v*4))}
    }
    var bipolar:Bool{["X","Y","Rotation"].contains(property)}
    func point(_ k:Keyframe,_ w:CGFloat,_ h:CGFloat)->CGPoint {
        CGPoint(x:8+max(0,min(1,k.time/max(c.length,0.01)))*(w-16),y:8+(1-(bipolar ? (value(k)+1)/2:value(k)))*(h-16))
    }
    var body:some View {
        VStack(alignment:.leading,spacing:8) {
            Text("KEYFRAMES").font(.system(size:10,weight:.semibold)).foregroundStyle(.secondary)
            Button {e.addKeyframe(c)} label:{Label("Keyframe am Abspielkopf",systemImage:"diamond")}
            Picker("Kurve",selection:$property){ForEach(["Zoom","X","Y","Rotation","Opacity"],id:\.self){Text($0).tag($0)}}
            GeometryReader {g in
                ZStack {
                    RoundedRectangle(cornerRadius:6).fill(Color.black.opacity(0.35))
                    Path{p in for i in 1...3 {let y=CGFloat(i)*g.size.height/4;p.move(to:CGPoint(x:0,y:y));p.addLine(to:CGPoint(x:g.size.width,y:y))}}.stroke(edge,lineWidth:1)
                    Path {p in
                        guard let first=points.first else {return}
                        p.move(to:point(first,g.size.width,g.size.height))
                        if points.count>1 {
                            for i in 1..<points.count {
                                let a=points[i-1],b=points[i]
                                for sample in 1...32 {
                                    let t=a.time+(b.time-a.time)*Double(sample)/32
                                    p.addLine(to:point(c.pose(at:t),g.size.width,g.size.height))
                                }
                            }
                        }
                    }.stroke(accent,lineWidth:1.8)
                    ForEach(points){k in
                        Circle().fill(accent).frame(width:9,height:9).position(point(k,g.size.width,g.size.height))
                            .gesture(DragGesture(minimumDistance:0,coordinateSpace:.named("keygraph")).onEnded{v in
                                let t=max(0,min(c.length,Double((v.location.x-8)/max(1,g.size.width-16))*c.length))
                                let normalized=max(0,min(1,Double(1-(v.location.y-8)/max(1,g.size.height-16))))
                                e.edit(c.id){clip in
                                    guard let i=clip.keyframes?.firstIndex(where:{$0.id==k.id}) else{return}
                                    var q=k;q.time=t;setValue(&q,bipolar ? normalized*2-1:normalized)
                                    clip.keyframes?[i]=q
                                }
                            })
                    }
                }.coordinateSpace(name:"keygraph")
            }.frame(height:110)
            ForEach(points){k in
                HStack {
                    Button(stamp(k.time)){e.seek(c.start+k.time)}.buttonStyle(.plain)
                    Picker("",selection:Binding(get:{k.ease},set:{v in e.edit(c.id){clip in
                        if let i=clip.keyframes?.firstIndex(where:{$0.id==k.id}){clip.keyframes?[i].ease=v}
                    }})){ForEach(Ease.allCases,id:\.self){Text($0.rawValue).tag($0)}}.labelsHidden()
                    Button {e.edit(c.id){$0.keyframes?.removeAll{$0.id==k.id}}} label:{Image(systemName:"xmark.circle")}.buttonStyle(.plain)
                }.font(.caption)
            }
            Text("Kurvenpunkte verschieben, um Zeit und Wert zu ändern.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
