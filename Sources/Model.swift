import Foundation
import CoreGraphics

enum ClipKind: String, Codable, CaseIterable { case video, audio, title }
enum Look: String, Codable, CaseIterable { case original, monochrome, warm, cool, vivid, vintage }
enum Motion: String, Codable, CaseIterable { case none, zoomIn, zoomOut, slideLeft, slideRight }
enum Effect: String, Codable, CaseIterable {
    case falseColor, threshold, solarize, mirrorX, mirrorY, kaleidoscope
    case none, blur, sharpen, motionBlur, zoomBlur, median, unsharp, exposure, gamma, temperature, hue, saturation, contrast, highlightShadow, invert, monochrome, sepia, vignette, noir, chrome, fade, instant, process, transfer, posterize, comic, edges, bloom, gloom, pixelate, hexPixelate, crystallize, dotScreen, lineScreen, twirl, bump, pinch
    var title:String {switch self {case .none:return "Keine";case .falseColor:return "Duotone";case .threshold:return "Schwellenwert";case .solarize:return "Solarisation";case .mirrorX:return "Horizontal spiegeln";case .mirrorY:return "Vertikal spiegeln";case .kaleidoscope:return "Kaleidoskop";case .blur:return "Gaußsche Unschärfe";case .sharpen:return "Schärfen";case .motionBlur:return "Bewegungsunschärfe";case .zoomBlur:return "Zoom-Unschärfe";case .median:return "Median";case .unsharp:return "Unscharf maskieren";case .exposure:return "Belichtung";case .gamma:return "Gamma";case .temperature:return "Farbtemperatur";case .hue:return "Farbton";case .saturation:return "Sättigung";case .contrast:return "Kontrast";case .highlightShadow:return "Lichter & Schatten";case .invert:return "Negativ";case .monochrome:return "Schwarzweiß";case .sepia:return "Sepia";case .vignette:return "Vignette";case .noir:return "Noir";case .chrome:return "Chrome";case .fade:return "Fade Film";case .instant:return "Instant Film";case .process:return "Process Film";case .transfer:return "Transfer Film";case .posterize:return "Posterisation";case .comic:return "Comic";case .edges:return "Kanten";case .bloom:return "Bloom";case .gloom:return "Gloom";case .pixelate:return "Mosaik";case .hexPixelate:return "Hexagon-Mosaik";case .crystallize:return "Kristall";case .dotScreen:return "Rasterpunkte";case .lineScreen:return "Linienraster";case .twirl:return "Wirbel";case .bump:return "Wölbung";case .pinch:return "Pinch"}}
    var category:String {switch self {case .none:return "Andere";case .falseColor,.threshold,.solarize:return "Licht & Farbe";case .mirrorX,.mirrorY,.kaleidoscope:return "Verzerrung & Struktur";case .blur,.sharpen,.motionBlur,.zoomBlur,.median,.unsharp:return "Schärfe & Unschärfe";case .exposure,.gamma,.temperature,.hue,.saturation,.contrast,.highlightShadow,.invert,.monochrome,.sepia:return "Licht & Farbe";case .vignette,.noir,.chrome,.fade,.instant,.process,.transfer,.posterize,.comic,.edges,.bloom,.gloom:return "Film & Stil";case .pixelate,.hexPixelate,.crystallize,.dotScreen,.lineScreen,.twirl,.bump,.pinch:return "Verzerrung & Struktur"}}
    var hasDetail:Bool{[.motionBlur,.zoomBlur,.unsharp,.bloom,.gloom,.vignette,.dotScreen,.lineScreen,.twirl,.bump,.pinch,.highlightShadow].contains(self)}
    var hasAngle:Bool{[.motionBlur,.dotScreen,.lineScreen,.twirl].contains(self)}
}
enum Mask: String, Codable, CaseIterable { case none, rectangle, ellipse }
enum ExportFormat: String, CaseIterable { case mp4, mov, proRes
    var suffix:String { self == .mp4 ? "mp4":"mov" }
    var title:String { switch self {case .mp4:return "MP4 · H.264 / kompatibel";case .mov:return "MOV · hohe Qualität";case .proRes:return "MOV · Apple ProRes 422"} }
}
struct EffectLayer: Identifiable, Codable, Equatable {
    var id=UUID()
    var effect:Effect
    var intensity:Double=0.5
    var enabled:Bool? = nil
    var mix:Double? = nil
    var detail:Double? = nil
    var angle:Double? = nil
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
enum EditMode:String,CaseIterable {case ripple,roll,slip,slide}
struct TimelineMarker:Identifiable,Codable,Equatable {
    var id=UUID()
    var time:Double
    var name:String
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
    var schemaVersion: Int? = nil
    var videoTrackCount: Int? = nil
    var audioTrackCount: Int? = nil
    var lockedTracks: [Int]? = nil
    var mutedTracks: [Int]? = nil
    var hiddenTracks: [Int]? = nil
    var markers: [TimelineMarker]? = nil
    var lanes: [Int] {
        let v=min(12,max(3,videoTrackCount ?? 3,(clips.map(\.lane).max() ?? 0)+1))
        let a=min(12,max(2,audioTrackCount ?? 2,-(clips.map(\.lane).min() ?? 0)))
        return Array((-a...v-1).reversed())
    }
    func locked(_ lane:Int)->Bool{lockedTracks?.contains(lane) ?? false}
    func muted(_ lane:Int)->Bool{mutedTracks?.contains(lane) ?? false}
    func hidden(_ lane:Int)->Bool{hiddenTracks?.contains(lane) ?? false}
    mutating func toggleTrack(_ lane:Int,_ key:WritableKeyPath<Project,[Int]?>){
        var items=self[keyPath:key] ?? []
        if items.contains(lane){items.removeAll{$0==lane}}else{items.append(lane)}
        self[keyPath:key]=items
    }
    mutating func addTrack(audio:Bool){
        if audio {audioTrackCount=min(12,abs(lanes.last ?? -2)+1)}
        else {videoTrackCount=min(12,(lanes.first ?? 2)+2)}
    }
    mutating func moveGroup(_ ids:Set<UUID>,delta:Double,laneDelta:Int)->Bool{
        let moving=clips.filter{ids.contains($0.id)}
        guard !moving.isEmpty else{return false}
        let minimum=moving.map(\.start).min() ?? 0
        let shift=max(-minimum,delta)
        for c in moving {
            let lane=c.lane+laneDelta
            guard lanes.contains(lane),!locked(c.lane),!locked(lane),(c.kind == .audio ? lane<0:lane>=0) else{return false}
            let start=c.start+shift
            guard !clips.contains(where:{!ids.contains($0.id) && $0.lane==lane && $0.start<start+c.length-0.00001 && $0.end>start+0.00001}) else{return false}
        }
        for i in clips.indices where ids.contains(clips[i].id){clips[i].start+=shift;clips[i].lane+=laneDelta}
        return true
    }
    mutating func removeGroup(_ ids:Set<UUID>,ripple:Bool){
        let removing=clips.filter{ids.contains($0.id) && !locked($0.lane)}
        let actual=Set(removing.map(\.id))
        clips.removeAll{actual.contains($0.id)}
        if ripple {
            for i in clips.indices {
                let c=clips[i]
                let ranges=removing.filter{$0.lane==c.lane && $0.end<=c.start+0.00001}.sorted{$0.start<$1.start}
                var total=0.0, end = -Double.infinity
                for x in ranges {total+=max(0,x.end-max(end,x.start));end=max(end,x.end)}
                clips[i].start=max(0,c.start-total)
            }
        }
    }
    var media: [Media] = []
    var clips: [Clip] = []
    var duration: Double { clips.map(\.end).max() ?? 0 }
    // Professional operations are atomic: reject a change when any source handle or neighbor is invalid.
    mutating func professionalEdit(_ id:UUID,mode:EditMode,frames:Int)->Bool {
        guard let i=clips.firstIndex(where:{$0.id==id}),frames != 0 else{return false}
        let c=clips[i], d=Double(frames)/frameRate, epsilon=0.00001, minimum=1/frameRate
        guard !locked(c.lane) else{return false}
        let same=clips.indices.filter{$0 != i && clips[$0].lane==c.lane}
        // Operations require a non-overlapping lane; transitions are edited separately.
        guard !same.contains(where:{clips[$0].start<c.end-epsilon && clips[$0].end>c.start+epsilon}) else{return false}
        let previous=same.filter{abs(clips[$0].end-c.start)<epsilon}.max(by:{clips[$0].start<clips[$1].start})
        let next=same.filter{abs(clips[$0].start-c.end)<epsilon}.min(by:{clips[$0].start<clips[$1].start})
        func valid(_ x:Clip)->Bool {
            guard x.start>=(-epsilon),x.length>=minimum-epsilon,x.sourceIn>=(-epsilon) else{return false}
            if let asset=asset(x){return x.sourceIn+x.length*x.speed<=asset.duration+epsilon}
            return x.kind == .title
        }
        func adjusted(_ original:Clip,head:Double=0,tail:Double=0)->Clip {
            var x=original
            x.start+=head;x.sourceIn+=head*x.speed;x.length+=tail-head
            if x.kind == .title {x.sourceIn=0}
            if let keys=original.keyframes,!keys.isEmpty {
                var first=original.pose(at:head);first.id=UUID();first.time=0
                var last=original.pose(at:head+x.length);last.id=UUID();last.time=x.length
                x.keyframes=[first]+keys.filter{$0.time>head && $0.time<head+x.length}.map{key in var k=key;k.time-=head;return k}+[last]
            }
            x.fadeIn=min(x.fadeIn,max(0,x.length/2));x.fadeOut=min(x.fadeOut,max(0,x.length/2))
            return x
        }
        var changes:[Int:Clip]=[:]
        switch mode {
        case .ripple:
            changes[i]=adjusted(c,tail:d)
            for j in same where clips[j].start>=c.end-epsilon {var x=clips[j];x.start+=d;changes[j]=x}
        case .roll:
            guard let j=next else{return false}
            changes[i]=adjusted(c,tail:d);changes[j]=adjusted(clips[j],head:d)
        case .slip:
            guard c.kind != .title else{return false}
            var x=c;x.sourceIn+=d*x.speed;changes[i]=x
        case .slide:
            guard let p=previous,let n=next else{return false}
            var x=c;x.start+=d
            changes[p]=adjusted(clips[p],tail:d);changes[i]=x;changes[n]=adjusted(clips[n],head:d)
        }
        guard changes.values.allSatisfy(valid) else{return false}
        for (j,x) in changes {clips[j]=x}
        return true
    }
    mutating func dissolveInto(_ id:UUID,seconds:Double)->Bool {
        guard let i=clips.firstIndex(where:{$0.id==id}) else{return false}
        let c=clips[i], d=snap(seconds)
        guard c.kind == .video,!locked(c.lane),d>=1/frameRate,d<c.length/2 else{return false}
        guard let j=clips.indices.first(where:{$0 != i && clips[$0].lane==c.lane && clips[$0].kind == .video && abs(clips[$0].end-c.start)<0.00001}),d<clips[j].length/2 else{return false}
        guard !clips.indices.contains(where:{$0 != i && $0 != j && clips[$0].lane==c.lane && clips[$0].start<c.end-0.00001 && clips[$0].end>c.start-d+0.00001}) else{return false}
        clips[i].start-=d;clips[i].fadeIn=d;clips[i].audioFadeIn=d;clips[j].audioFadeOut=d
        // Move following same-lane clips as a unit to keep the sequence contiguous.
        for k in clips.indices where k != i && k != j && clips[k].lane==c.lane && clips[k].start>=c.end-0.00001 {clips[k].start-=d}
        return true
    }
    func asset(_ clip: Clip) -> Media? { media.first { $0.id == clip.mediaID } }
    mutating func split(_ id: UUID, at time: Double) -> UUID? {
        guard let index = clips.firstIndex(where: {$0.id == id}) else { return nil }
        var right = clips[index]
        guard !locked(right.lane) else{return nil}
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

struct StudioPreferences: Codable, Equatable {
    var canvas:Canvas = .landscape
    var fps=30
    var matchSource=true
    var snapping=true
    var swapping=true
    var snapDistance=8.0
    var undoLimit=80
    var trackHeight=47.0
    var showWaveforms=true
    var showThumbnails=true
    var previewLimit=1920
    var recoveryEnabled=true
    var restoreLast=true
    var exportFormat="mp4"
    var exportResolution="project"
    var exportFPS=0
    var revealExport=true
    var defaultVideoTracks:Int? = nil
    var defaultAudioTracks:Int? = nil
    var defaultTitleDuration:Double? = nil
    var defaultFill:Bool? = nil
    var defaultZoom:Double? = nil
    var previewEffects:Bool? = nil
    var monitorVolume:Double? = nil
    var seekFrames:Int? = nil
    var defaultEffectMix:Double? = nil
    var defaultEffectStrength:Double? = nil
    var refreshDelay:Int? = nil
    var defaultDissolve:Double? = nil
    var defaultExportFolder:String? = nil
    var networkOptimized:Bool? = nil
    var autoAnalyzeAudio:Bool? = nil
    var recoveryDelay:Int? = nil
    var autoCheckUpdates:Bool? = nil
    var updateCheckHours:Int? = nil
    func newProject()->Project {
        var p=Project();p.canvas=canvas;p.fps=fps;p.videoTrackCount=defaultVideoTracks;p.audioTrackCount=defaultAudioTracks;return p
    }
}

struct FXPreset:Identifiable,Codable {
    var id=UUID()
    var name:String
    var layers:[EffectLayer]
    static let builtIn:[FXPreset] = [
        FXPreset(name:"Cinematic Teal",layers:[EffectLayer(effect:.temperature,intensity:0.24),EffectLayer(effect:.contrast,intensity:0.63),EffectLayer(effect:.vignette,intensity:0.24)]),
        FXPreset(name:"Golden Hour",layers:[EffectLayer(effect:.temperature,intensity:0.78),EffectLayer(effect:.bloom,intensity:0.23),EffectLayer(effect:.saturation,intensity:0.58)]),
        FXPreset(name:"Analog Film",layers:[EffectLayer(effect:.fade,intensity:0.7),EffectLayer(effect:.sepia,intensity:0.15),EffectLayer(effect:.vignette,intensity:0.35)]),
        FXPreset(name:"Urban Noir",layers:[EffectLayer(effect:.noir,intensity:1),EffectLayer(effect:.sharpen,intensity:0.3),EffectLayer(effect:.vignette,intensity:0.32)]),
        FXPreset(name:"Dream Glow",layers:[EffectLayer(effect:.bloom,intensity:0.5),EffectLayer(effect:.blur,intensity:0.1),EffectLayer(effect:.fade,intensity:0.25)]),
        FXPreset(name:"Cool Night",layers:[EffectLayer(effect:.temperature,intensity:0.2),EffectLayer(effect:.exposure,intensity:0.42),EffectLayer(effect:.contrast,intensity:0.68)]),
        FXPreset(name:"Clean Detail",layers:[EffectLayer(effect:.unsharp,intensity:0.3),EffectLayer(effect:.highlightShadow,intensity:0.25),EffectLayer(effect:.saturation,intensity:0.54)]),
        FXPreset(name:"Vintage 70s",layers:[EffectLayer(effect:.instant,intensity:0.7),EffectLayer(effect:.sepia,intensity:0.3),EffectLayer(effect:.fade,intensity:0.28)]),
        FXPreset(name:"High Contrast",layers:[EffectLayer(effect:.contrast,intensity:0.85),EffectLayer(effect:.sharpen,intensity:0.25)]),
        FXPreset(name:"Graphic Poster",layers:[EffectLayer(effect:.posterize,intensity:0.7),EffectLayer(effect:.saturation,intensity:0.8),EffectLayer(effect:.edges,intensity:0.15)]),
        FXPreset(name:"Soft Portrait",layers:[EffectLayer(effect:.blur,intensity:0.08),EffectLayer(effect:.bloom,intensity:0.17),EffectLayer(effect:.temperature,intensity:0.57)]),
        FXPreset(name:"Dark Drama",layers:[EffectLayer(effect:.exposure,intensity:0.35),EffectLayer(effect:.gloom,intensity:0.3),EffectLayer(effect:.vignette,intensity:0.45)]),
        FXPreset(name:"Duotone Studio",layers:[EffectLayer(effect:.falseColor,intensity:0.8),EffectLayer(effect:.contrast,intensity:0.65)]),
        FXPreset(name:"Retro Raster",layers:[EffectLayer(effect:.dotScreen,intensity:0.65),EffectLayer(effect:.monochrome,intensity:0.65)]),
        FXPreset(name:"Neon Shift",layers:[EffectLayer(effect:.hue,intensity:0.72),EffectLayer(effect:.bloom,intensity:0.4),EffectLayer(effect:.saturation,intensity:0.8)]),
        FXPreset(name:"Dream Zoom",layers:[EffectLayer(effect:.zoomBlur,intensity:0.28),EffectLayer(effect:.bloom,intensity:0.25)])
    ]
    func freshLayers()->[EffectLayer]{layers.map{var e=$0;e.id=UUID();return e}}
}
