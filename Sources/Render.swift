import Foundation
import AVFoundation
import CoreImage
import CoreText
import AppKit

func ct(_ seconds: Double) -> CMTime { CMTime(seconds: seconds, preferredTimescale: 600) }
struct Layer {
    let clip: Clip
    let track: CMPersistentTrackID?
    let transform: CGAffineTransform
    let title: CIImage?
}
final class CutInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    let timeRange: CMTimeRange
    let enablePostProcessing = false
    let containsTweening = true
    let requiredSourceTrackIDs: [NSValue]?
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    let layers: [Layer]
    init(duration: Double, layers: [Layer]) {
        self.timeRange = CMTimeRange(start:.zero,duration:ct(duration))
        self.layers = layers
        self.requiredSourceTrackIDs = layers.compactMap { $0.track }.map { NSNumber(value:$0) as NSValue }
        super.init()
    }
}
final class CutCompositor: NSObject, AVVideoCompositing {
    var sourcePixelBufferAttributes: [String: Any]? { [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA] }
    var requiredPixelBufferAttributesForRenderContext: [String: Any] { [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA] }
    private let ci = CIContext()
    private let queue = DispatchQueue(label:"cut.render")
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}
    func cancelAllPendingVideoCompositionRequests() { queue.sync {} }
    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        queue.async {
            autoreleasepool {
                guard let instruction = request.videoCompositionInstruction as? CutInstruction,
                      let target = request.renderContext.newPixelBuffer() else {
                    request.finish(with:NSError(domain:"LYRO Cut",code:1)); return
                }
                let size = request.renderContext.size
                let frame = CGRect(origin:.zero,size:size)
                let time = request.compositionTime.seconds
                var output = CIImage(color:CIColor(red:0,green:0,blue:0,alpha:1)).cropped(to:frame)
                for layer in instruction.layers {
                    let c = layer.clip
                    guard time >= c.start, time < c.end else { continue }
                    var image: CIImage
                    if let title = layer.title { image = title }
                    else if let id = layer.track, let source = request.sourceFrame(byTrackID:id) {
                        image = CIImage(cvPixelBuffer:source).transformed(by:layer.transform)
                    } else { continue }
                    let extent = image.extent
                    guard extent.width > 0, extent.height > 0 else { continue }
                    image = image.transformed(by:CGAffineTransform(translationX:-extent.minX,y:-extent.minY))
                    if c.kind != .title {
                        image = image.applyingFilter("CIColorControls",parameters:[
                            kCIInputBrightnessKey:c.brightness,kCIInputContrastKey:c.contrast,kCIInputSaturationKey:c.saturation])
                        switch c.look {
                        case .original: break
                        case .monochrome: image = image.applyingFilter("CIPhotoEffectMono")
                        case .vintage: image = image.applyingFilter("CIPhotoEffectInstant")
                        case .vivid: image = image.applyingFilter("CIPhotoEffectProcess")
                        case .warm: image = image.applyingFilter("CISepiaTone",parameters:[kCIInputIntensityKey:0.3])
                        case .cool: image = image.applyingFilter("CIPhotoEffectTransfer").applyingFilter("CIColorControls",parameters:[kCIInputSaturationKey:0.75])
                        }
                    }
                    if c.kind != .title {
                        let amount = min(1,max(0,c.intensity ?? 0.5))
                        let bounds = image.extent
                        switch c.effect ?? .none {
                        case .none: break
                        case .blur: image=image.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:[kCIInputRadiusKey:amount*30]).cropped(to:bounds)
                        case .sharpen: image=image.applyingFilter("CISharpenLuminance",parameters:[kCIInputSharpnessKey:amount*2])
                        case .vignette: image=image.applyingFilter("CIVignette",parameters:[kCIInputIntensityKey:amount*3,kCIInputRadiusKey:1.5])
                        case .pixelate: image=image.applyingFilter("CIPixellate",parameters:[kCIInputScaleKey:2+amount*60]).cropped(to:bounds)
                        case .bloom: image=image.clampedToExtent().applyingFilter("CIBloom",parameters:[kCIInputIntensityKey:amount,kCIInputRadiusKey:20]).cropped(to:bounds)
                        case .edges: image=image.applyingFilter("CIEdges",parameters:[kCIInputIntensityKey:amount*8]).cropped(to:bounds)
                        case .noir: image=image.applyingFilter("CIPhotoEffectNoir")
                        }
                        let maskSize=max(0.05,min(1,c.maskSize ?? 0.8))
                        if c.mask == .rectangle || c.mask == .ellipse {
                            let box=bounds.insetBy(dx:bounds.width*(1-maskSize)/2,dy:bounds.height*(1-maskSize)/2)
                            if let context=CGContext(data:nil,width:Int(bounds.width),height:Int(bounds.height),bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) {
                                context.setFillColor(CGColor(gray:1,alpha:1))
                                if c.mask == .ellipse {context.fillEllipse(in:box)} else {context.fill(box)}
                                if let cg=context.makeImage() {
                                    let clear=CIImage(color:CIColor(red:0,green:0,blue:0,alpha:0)).cropped(to:bounds)
                                    image=image.applyingFilter("CIBlendWithAlphaMask",parameters:[kCIInputBackgroundImageKey:clear,kCIInputMaskImageKey:CIImage(cgImage:cg)]).cropped(to:bounds)
                                }
                            }
                        }
                    }
                    let pose=c.pose(at:time-c.start)
                    let p = min(1,max(0,(time-c.start)/max(c.length,0.01)))
                    var zoom = pose.scale
                    var dx = pose.x * size.width
                    switch c.motion {
                    case .none: break
                    case .zoomIn: zoom *= 1 + 0.25*p
                    case .zoomOut: zoom *= 1.25 - 0.25*p
                    case .slideLeft: dx += (0.5-p)*size.width*0.35
                    case .slideRight: dx += (p-0.5)*size.width*0.35
                    }
                    let fit = c.kind == .title ? size.width/1920 : (c.fill == true ? max(size.width/extent.width,size.height/extent.height) : min(size.width/extent.width,size.height/extent.height))
                    image = image.transformed(by:CGAffineTransform(translationX:-extent.width/2,y:-extent.height/2))
                    image = image.transformed(by:CGAffineTransform(scaleX:fit*zoom,y:fit*zoom))
                    image = image.transformed(by:CGAffineTransform(rotationAngle:pose.rotation*Double.pi/180))
                    image = image.transformed(by:CGAffineTransform(translationX:size.width/2+dx,y:size.height/2+pose.y*size.height))
                    var alpha = pose.opacity
                    if c.fadeIn > 0 { alpha *= min(1,max(0,(time-c.start)/c.fadeIn)) }
                    if c.fadeOut > 0 { alpha *= min(1,max(0,(c.end-time)/c.fadeOut)) }
                    image = image.applyingFilter("CIColorMatrix",parameters:["inputAVector":CIVector(x:0,y:0,z:0,w:alpha)])
                    output = image.composited(over:output).cropped(to:frame)
                }
                self.ci.render(output,to:target,bounds:frame,colorSpace:CGColorSpaceCreateDeviceRGB())
                request.finish(withComposedVideoFrame:target)
            }
        }
    }
}
struct RenderGraph {
    let composition: AVMutableComposition
    let video: AVMutableVideoComposition
    let audio: AVMutableAudioMix
    func playerItem() -> AVPlayerItem {
        let item = AVPlayerItem(asset:composition)
        item.videoComposition = video
        item.audioMix = audio
        return item
    }
}
enum RenderError: LocalizedError {
    case missing(String), noVideo, invalid(String)
    var errorDescription: String? {
        switch self {
        case .missing(let name): return "Medium fehlt: " + name
        case .noVideo: return "Füge zuerst einen Videoclip zur Timeline hinzu."
        case .invalid(let name): return "Medium kann nicht verarbeitet werden: " + name
        }
    }
}
enum Renderer {
    static func titleImage(_ clip: Clip) -> CIImage? {
        let text = NSAttributedString(string:clip.title,attributes:[
            .font:NSFont.systemFont(ofSize:clip.fontSize,weight:.bold),
            .foregroundColor:NSColor.white,
            .strokeColor:NSColor.black,
            .strokeWidth:-1.5
        ])
        let line = CTLineCreateWithAttributedString(text)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line,&ascent,&descent,nil))
        guard let context = CGContext(data:nil,width:max(1,Int(ceil(width+24))),height:max(1,Int(ceil(ascent+descent+24))),bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.textPosition = CGPoint(x:12,y:12+descent)
        CTLineDraw(line,context)
        return context.makeImage().map { CIImage(cgImage:$0) }
    }
    static func build(_ project: Project, preview: Bool = false) async throws -> RenderGraph {
        let comp = AVMutableComposition()
        var layers: [Layer] = []
        var audioParameters: [AVAudioMixInputParameters] = []
        var hasVideo = false
        for c in project.clips.sorted(by:{ $0.lane == $1.lane ? $0.start < $1.start : $0.lane < $1.lane }) {
            if c.kind == .title {
                layers.append(Layer(clip:c,track:nil,transform:.identity,title:titleImage(c)))
                continue
            }
            guard let media = project.asset(c), FileManager.default.fileExists(atPath:media.path) else { throw RenderError.missing(c.name) }
            let asset = AVURLAsset(url:URL(fileURLWithPath:media.path))
            let sourceLength = min(c.length*c.speed,media.duration-c.sourceIn)
            guard sourceLength > 0.02 else { continue }
            let range = CMTimeRange(start:ct(c.sourceIn),duration:ct(sourceLength))
            let at = ct(c.start)
            if c.kind == .video {
                guard let source = try await asset.loadTracks(withMediaType:.video).first,
                      let track = comp.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid) else { throw RenderError.invalid(c.name) }
                try track.insertTimeRange(range,of:source,at:at)
                track.scaleTimeRange(CMTimeRange(start:at,duration:range.duration),toDuration:ct(c.length))
                let transform = try await source.load(.preferredTransform)
                layers.append(Layer(clip:c,track:track.trackID,transform:transform,title:nil))
                hasVideo = true
            }
            if let source = try await asset.loadTracks(withMediaType:.audio).first,
               let track = comp.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid) {
                let sourceRange = try await source.load(.timeRange)
                let intersection = CMTimeRangeGetIntersection(range,otherRange:sourceRange)
                if intersection.duration.seconds > 0.01 {
                    let audioAt = ct(c.start + max(0,intersection.start.seconds-range.start.seconds)/c.speed)
                    try track.insertTimeRange(intersection,of:source,at:audioAt)
                    track.scaleTimeRange(CMTimeRange(start:audioAt,duration:intersection.duration),toDuration:ct(intersection.duration.seconds/c.speed))
                    let params = AVMutableAudioMixInputParameters(track:track)
                    params.setVolume(Float(c.volume),at:audioAt)
                    audioParameters.append(params)
                }
            }
        }
        guard hasVideo else { throw RenderError.noVideo }
        if comp.duration.seconds < project.duration {
            comp.insertEmptyTimeRange(CMTimeRange(start:comp.duration,duration:ct(project.duration-comp.duration.seconds)))
        }
        let video = AVMutableVideoComposition()
        video.customVideoCompositorClass = CutCompositor.self
        let outputSize=project.renderSize
        video.renderSize = preview && max(outputSize.width,outputSize.height)>1920 ? CGSize(width:(outputSize.width/4).rounded()*2,height:(outputSize.height/4).rounded()*2) : outputSize
        video.frameDuration = CMTime(value:1001,timescale:CMTimeScale((project.frameRate*1001).rounded()))
        video.instructions = [CutInstruction(duration:project.duration,layers:layers)]
        let audio = AVMutableAudioMix()
        audio.inputParameters = audioParameters
        return RenderGraph(composition:comp,video:video,audio:audio)
    }
    static func export(_ graph: RenderGraph,to url: URL) async throws {
        guard let session = AVAssetExportSession(asset:graph.composition,presetName:AVAssetExportPresetHighestQuality) else { throw RenderError.invalid("Export") }
        session.videoComposition = graph.video
        session.audioMix = graph.audio
        session.outputURL = url
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void,Never>) in
            session.exportAsynchronously { continuation.resume() }
        }
        guard session.status == .completed else { throw session.error ?? RenderError.invalid("Export") }
    }
}
