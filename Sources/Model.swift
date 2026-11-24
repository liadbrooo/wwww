import Foundation
import CoreGraphics

enum ClipKind: String, Codable, CaseIterable { case video, audio, title }
enum Look: String, Codable, CaseIterable { case original, monochrome, warm, cool, vivid, vintage }
enum Motion: String, Codable, CaseIterable { case none, zoomIn, zoomOut, slideLeft, slideRight }
enum Effect: String, Codable, CaseIterable { case none, blur, sharpen, vignette, pixelate, bloom, edges, noir }
enum Mask: String, Codable, CaseIterable { case none, rectangle, ellipse }
enum ExportFormat: String, CaseIterable { case mp4, mov, proRes
    var suffix:String { self == .mp4 ? "mp4":"mov" }
    var title:String { switch self {case .mp4:return "MP4 · H.264 / kompatibel";case .mov:return "MOV · hohe Qualität";case .proRes:return "MOV · Apple ProRes 422"} }
}
struct EffectLayer: Identifiable, Codable, Equatable {
    var id=UUID()
    var effect:Effect
    var intensity:Double=0.5
}
enum Ease: String, Codable, CaseIterable { case linear, smooth, easeIn, easeOut }
struct Keyframe: Identifiable, Codable, Equatable {
    var id = UUID()
    var time: Double
    var scale: Double
    var x: Double
    var y: Double
    var rotation: Double
    var opacity: Double
    var ease: Ease = .smooth
}
enum Canvas: String, Codable, CaseIterable {
    case landscape = "16:9", portrait = "9:16", square = "1:1"
    var size: CGSize {
        switch self { case .landscape: return CGSize(width:1920,height:1080)
        case .portrait: return CGSize(width:1080,height:1920)
        case .square: return CGSize(width:1080,height:1080) }
    }
}
struct Media: Identifiable, Codable, Equatable {
    var id = UUID()
    var path: String
    var name: String
    var duration: Double
    var kind: ClipKind
    var width: Double? = nil
    var height: Double? = nil
    var fps: Double? = nil
}
struct Clip: Identifiable, Codable, Equatable {
    var id = UUID()
    var mediaID: UUID? = nil
    var name: String
    var kind: ClipKind
    var start: Double = 0
    var sourceIn: Double = 0
    var length: Double = 5
    var speed: Double = 1
    var lane: Int = 0
    var volume: Double = 1
    var opacity: Double = 1
    var scale: Double = 1
    var x: Double = 0
    var y: Double = 0
    var rotation: Double = 0
    var brightness: Double = 0
    var contrast: Double = 1
    var saturation: Double = 1
    var look: Look = .original
    var motion: Motion = .none
    var fadeIn: Double = 0
    var fadeOut: Double = 0
    var title: String = "Dein Text"
    var fontSize: Double = 80
    var effect: Effect? = nil
    var intensity: Double? = nil
    var mask: Mask? = nil
    var maskSize: Double? = nil
    var fill: Bool? = nil
    var keyframes: [Keyframe]? = nil
    var effects: [EffectLayer]? = nil
    var maskX: Double? = nil
    var maskY: Double? = nil
    var maskAspect: Double? = nil
    var audioFadeIn: Double? = nil
    var audioFadeOut: Double? = nil
    var effectStack: [EffectLayer] { effects ?? ((effect ?? Effect.none) == Effect.none ? [] : [EffectLayer(effect:effect ?? Effect.none,intensity:intensity ?? 0.5)]) }
    mutating func setPose(_ pose:Keyframe,at time:Double,fps:Double) {
        var points=keyframes ?? []
        var next=pose
        next.time=max(0,min(length,time))
        if let i=points.firstIndex(where:{abs($0.time-next.time)<0.5/fps}) {next.id=points[i].id;next.ease=points[i].ease;points[i]=next}
        else {points.append(next)}
        keyframes=points.sorted{$0.time<$1.time}
    }
    var end: Double { start + length }
    func pose(at time: Double) -> Keyframe {
        let base = Keyframe(time:0,scale:scale,x:x,y:y,rotation:rotation,opacity:opacity)
        let points = (keyframes ?? []).sorted{$0.time < $1.time}
        guard let first=points.first,let last=points.last else {return base}
        if time <= first.time {return first}
        if time >= last.time {return last}
        guard let i=points.firstIndex(where:{$0.time > time}),i>0 else {return base}
        let a=points[i-1], b=points[i]
        var t=(time-a.time)/max(0.00001,b.time-a.time)
        switch a.ease {
        case .linear: break
        case .smooth: t=t*t*(3-2*t)
        case .easeIn: t=t*t
        case .easeOut: t=1-(1-t)*(1-t)
        }
        func lerp(_ x:Double,_ y:Double)->Double{x+(y-x)*t}
        return Keyframe(time:time,scale:lerp(a.scale,b.scale),x:lerp(a.x,b.x),y:lerp(a.y,b.y),rotation:lerp(a.rotation,b.rotation),opacity:lerp(a.opacity,b.opacity))
    }
}
struct Project: Codable, Equatable {
    var name = "Unbenannt"
    var canvas: Canvas = .landscape
    var fps: Int = 30
    var ultraHD: Bool? = nil
    var sourceCanvasWidth: Double? = nil
    var sourceCanvasHeight: Double? = nil
    var sourceFPS: Double? = nil
    var renderSize: CGSize {
        let original = canvas.size
        let ratio = (sourceCanvasWidth ?? original.width) / max(1,sourceCanvasHeight ?? original.height)
        let long: Double = ultraHD == true ? 3840 : 1920
        if ratio >= 1 { return CGSize(width:long,height:max(2,(long/ratio/2).rounded()*2)) }
        return CGSize(width:max(2,(long*ratio/2).rounded()*2),height:long)
    }
    var frameRate: Double { sourceFPS ?? Double(fps) }
    func snap(_ seconds:Double)->Double { (seconds*frameRate).rounded()/frameRate }
    mutating func setSourceFormat() {
        if let media=media.first(where:{$0.kind == .video}) {useSource(media)}
    }
    mutating func useSource(_ media: Media) {
        if let w=media.width,let h=media.height,w>0,h>0 {
            sourceCanvasWidth=w;sourceCanvasHeight=h
            canvas = w/h > 1.1 ? .landscape : w/h < 0.9 ? .portrait : .square
        }
        if let rate=media.fps,rate>=10,rate<=120 {sourceFPS=rate;fps=Int(rate.rounded())}
    }
    mutating func setCanvas(_ value:Canvas) {canvas=value;sourceCanvasWidth=nil;sourceCanvasHeight=nil}
    mutating func setFPS(_ value:Int) {fps=value;sourceFPS=nil}
    var media: [Media] = []
    var clips: [Clip] = []
    var duration: Double { clips.map(\.end).max() ?? 0 }
    func asset(_ clip: Clip) -> Media? { media.first { $0.id == clip.mediaID } }
    mutating func split(_ id: UUID, at time: Double) -> UUID? {
        guard let index = clips.firstIndex(where: {$0.id == id}) else { return nil }
        var right = clips[index]
        let offset = time - right.start
        let minimum=0.5/frameRate
        guard offset > minimum, offset < right.length - minimum else { return nil }
        right.id = UUID()
        right.start = time
        right.sourceIn += offset * right.speed
        right.length -= offset
        if let points=right.keyframes,!points.isEmpty {
            let boundary=right.pose(at:offset)
            var leftEnd=boundary;leftEnd.id=UUID()
            var rightStart=boundary;rightStart.time=0;rightStart.id=UUID()
            clips[index].keyframes=points.filter{$0.time<offset}+[leftEnd]
            right.keyframes=[rightStart]+points.filter{$0.time>offset}.map{p in var q=p;q.time-=offset;return q}
        }
        right.fadeIn = 0
        clips[index].length = offset
        clips[index].fadeOut = 0
        clips.append(right)
        return right.id
    }
}
