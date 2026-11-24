import Foundation
import AVFoundation
import CoreImage
import CoreText
import AppKit

func ct(_ seconds: Double) -> CMTime { CMTime(seconds: seconds, preferredTimescale: 60000) }
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
                        let bounds = image.extent
                        for effect in c.effectStack {image=EffectRenderer.apply(effect,to:image)}
                        let maskSize=max(0.05,min(1,c.maskSize ?? 0.8))
                        if c.mask == .rectangle || c.mask == .ellipse {
                            let aspect=max(0.1,min(3,c.maskAspect ?? 1))
                            let mw=min(bounds.width,bounds.width*maskSize*aspect)
                            let mh=min(bounds.height,bounds.height*maskSize)
                            let box=CGRect(x:bounds.midX-mw/2+(c.maskX ?? 0)*bounds.width,y:bounds.midY-mh/2+(c.maskY ?? 0)*bounds.height,width:mw,height:mh)
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
enum EffectRenderer {
    static func apply(_ effect:EffectLayer,to image:CIImage)->CIImage {
        guard effect.enabled != false,effect.effect != .none else{return image}
        let a=min(1,max(0,effect.intensity)),mix=min(1,max(0,effect.mix ?? 1)),d=min(1,max(0,effect.detail ?? 0.5))
        let angle=(effect.angle ?? 0)*Double.pi/180
        guard mix>0 else{return image}
        let b=image.extent,center=CIVector(x:b.midX,y:b.midY)
        guard !b.isEmpty,!b.isInfinite else{return image}
        var name="", params:[String:Any]=[:],clamp=false
        switch effect.effect {
        case .none:return image
        case .falseColor:name="CIFalseColor";params=["inputColor0":CIColor(red:0.05,green:0.08,blue:0.22),"inputColor1":CIColor(red:1,green:0.64,blue:0.32)]
        case .threshold:name="CIColorThreshold";params=["inputThreshold":a]
        case .solarize:name="CIColorPolynomial";params=["inputRedCoefficients":CIVector(x:0,y:1+3*a,z:-3*a,w:0),"inputGreenCoefficients":CIVector(x:0,y:1+3*a,z:-3*a,w:0),"inputBlueCoefficients":CIVector(x:0,y:1+3*a,z:-3*a,w:0)]
        case .mirrorX:
            let flipped=image.transformed(by:CGAffineTransform(a:-1,b:0,c:0,d:1,tx:b.minX+b.maxX,ty:0))
            return image.applyingFilter("CIDissolveTransition",parameters:["inputTargetImage":flipped,"inputTime":mix*a]).cropped(to:b)
        case .mirrorY:
            let flipped=image.transformed(by:CGAffineTransform(a:1,b:0,c:0,d:-1,tx:0,ty:b.minY+b.maxY))
            return image.applyingFilter("CIDissolveTransition",parameters:["inputTargetImage":flipped,"inputTime":mix*a]).cropped(to:b)
        case .kaleidoscope:name="CIKaleidoscope";params=["inputCount":3+round(a*9),"inputCenter":center]
        case .blur:name="CIGaussianBlur";params=["inputRadius":a*50];clamp=true
        case .sharpen:name="CISharpenLuminance";params=["inputSharpness":a*2]
        case .motionBlur:name="CIMotionBlur";params=["inputRadius":a*60,"inputAngle":angle];clamp=true
        case .zoomBlur:name="CIZoomBlur";params=["inputAmount":a*40,"inputCenter":center];clamp=true
        case .median:name="CIMedianFilter"
        case .unsharp:name="CIUnsharpMask";params=["inputRadius":1+d*15,"inputIntensity":a*2];clamp=true
        case .exposure:name="CIExposureAdjust";params=["inputEV":(a-0.5)*4]
        case .gamma:name="CIGammaAdjust";params=["inputPower":0.3+a*2]
        case .temperature:name="CITemperatureAndTint";params=["inputNeutral":CIVector(x:6500,y:0),"inputTargetNeutral":CIVector(x:3500+a*6500,y:0)]
        case .hue:name="CIHueAdjust";params=["inputAngle":(a-0.5)*2*Double.pi]
        case .saturation:name="CIColorControls";params=["inputSaturation":a*2]
        case .contrast:name="CIColorControls";params=["inputContrast":0.5+a*1.5]
        case .highlightShadow:name="CIHighlightShadowAdjust";params=["inputShadowAmount":a,"inputHighlightAmount":1-d]
        case .invert:name="CIColorInvert"
        case .monochrome:name="CIPhotoEffectMono"
        case .sepia:name="CISepiaTone";params=["inputIntensity":a]
        case .vignette:name="CIVignette";params=["inputIntensity":a*3,"inputRadius":0.2+d*2]
        case .noir:name="CIPhotoEffectNoir"
        case .chrome:name="CIPhotoEffectChrome"
        case .fade:name="CIPhotoEffectFade"
        case .instant:name="CIPhotoEffectInstant"
        case .process:name="CIPhotoEffectProcess"
        case .transfer:name="CIPhotoEffectTransfer"
        case .posterize:name="CIColorPosterize";params=["inputLevels":2+round((1-a)*18)]
        case .comic:name="CIComicEffect"
        case .edges:name="CIEdges";params=["inputIntensity":a*8]
        case .bloom:name="CIBloom";params=["inputIntensity":a,"inputRadius":2+d*40];clamp=true
        case .gloom:name="CIGloom";params=["inputIntensity":a,"inputRadius":2+d*40];clamp=true
        case .pixelate:name="CIPixellate";params=["inputScale":2+a*70,"inputCenter":center]
        case .hexPixelate:name="CIHexagonalPixellate";params=["inputScale":2+a*70,"inputCenter":center]
        case .crystallize:name="CICrystallize";params=["inputRadius":2+a*55,"inputCenter":center]
        case .dotScreen:name="CIDotScreen";params=["inputWidth":2+d*25,"inputSharpness":a,"inputAngle":angle,"inputCenter":center]
        case .lineScreen:name="CILineScreen";params=["inputWidth":2+d*25,"inputSharpness":a,"inputAngle":angle,"inputCenter":center]
        case .twirl:name="CITwirlDistortion";params=["inputRadius":min(b.width,b.height)*(0.1+d*0.6),"inputAngle":(a-0.5)*8+angle,"inputCenter":center]
        case .bump:name="CIBumpDistortion";params=["inputRadius":min(b.width,b.height)*(0.1+d*0.6),"inputScale":a,"inputCenter":center]
        case .pinch:name="CIPinchDistortion";params=["inputRadius":min(b.width,b.height)*(0.1+d*0.6),"inputScale":a,"inputCenter":center]
        }
        guard let filter=CIFilter(name:name) else{return image}
        filter.setDefaults();filter.setValue(clamp ? image.clampedToExtent():image,forKey:kCIInputImageKey)
        for (key,value) in params where filter.inputKeys.contains(key){filter.setValue(value,forKey:key)}
        guard let raw=filter.outputImage else{return image}
        let result=raw.cropped(to:b)
        let fixed:[Effect]=[.falseColor,.median,.invert,.monochrome,.noir,.chrome,.fade,.instant,.process,.transfer,.comic]
        let opacity=mix*(fixed.contains(effect.effect) ? a:1)
        if opacity>=0.9999{return result}
        return image.applyingFilter("CIDissolveTransition",parameters:["inputTargetImage":result,"inputTime":opacity]).cropped(to:b)
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
    static func build(_ project: Project, preview: Bool = false, previewLimit:Int = 1920) async throws -> RenderGraph {
        let comp = AVMutableComposition()
        var layers: [Layer] = []
        var audioParameters: [AVAudioMixInputParameters] = []
        var hasVideo = false
        for c in project.clips.sorted(by:{ $0.lane == $1.lane ? $0.start < $1.start : $0.lane < $1.lane }) {
            if c.kind == .title {
                if !project.hidden(c.lane){layers.append(Layer(clip:c,track:nil,transform:.identity,title:titleImage(c)))}
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
                if !project.hidden(c.lane){layers.append(Layer(clip:c,track:track.trackID,transform:transform,title:nil))}
                hasVideo = true
            }
            if !project.muted(c.lane),let source = try await asset.loadTracks(withMediaType:.audio).first,
               let track = comp.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid) {
                let sourceRange = try await source.load(.timeRange)
                let intersection = CMTimeRangeGetIntersection(range,otherRange:sourceRange)
                if intersection.duration.seconds > 0.01 {
                    let audioAt = ct(c.start + max(0,intersection.start.seconds-range.start.seconds)/c.speed)
                    try track.insertTimeRange(intersection,of:source,at:audioAt)
                    track.scaleTimeRange(CMTimeRange(start:audioAt,duration:intersection.duration),toDuration:ct(intersection.duration.seconds/c.speed))
                    let params = AVMutableAudioMixInputParameters(track:track)
                    let audioLength=intersection.duration.seconds/c.speed
                    let fi=max(0,min(audioLength/2,c.audioFadeIn ?? 0))
                    let fo=max(0,min(audioLength/2,c.audioFadeOut ?? 0))
                    let level=Float(c.volume)
                    params.setVolume(fi>0 ? 0:level,at:audioAt)
                    if fi>0 {params.setVolumeRamp(fromStartVolume:0,toEndVolume:level,timeRange:CMTimeRange(start:audioAt,duration:ct(fi)))}
                    if fo>0 {params.setVolumeRamp(fromStartVolume:level,toEndVolume:0,timeRange:CMTimeRange(start:CMTimeAdd(audioAt,ct(audioLength-fo)),duration:ct(fo)))}
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
        let scale = preview && previewLimit>0 ? min(1,Double(previewLimit)/max(outputSize.width,outputSize.height)):1
        video.renderSize = CGSize(width:max(2,(outputSize.width*scale/2).rounded()*2),height:max(2,(outputSize.height*scale/2).rounded()*2))
        video.frameDuration = CMTime(value:1001,timescale:CMTimeScale((project.frameRate*1001).rounded()))
        video.instructions = [CutInstruction(duration:project.duration,layers:layers)]
        let audio = AVMutableAudioMix()
        audio.inputParameters = audioParameters
        return RenderGraph(composition:comp,video:video,audio:audio)
    }
    static func export(_ graph: RenderGraph,to url: URL,format:ExportFormat = .mp4,networkOptimized:Bool = true,onSession:((AVAssetExportSession)->Void)? = nil) async throws {
        let preset=format == .proRes ? AVAssetExportPresetAppleProRes422LPCM : AVAssetExportPresetHighestQuality
        guard let session = AVAssetExportSession(asset:graph.composition,presetName:preset) else { throw RenderError.invalid("Export") }
        session.videoComposition = graph.video
        session.audioMix = graph.audio
        session.outputURL = url
        session.outputFileType = format == .mp4 ? .mp4 : .mov
        guard session.supportedFileTypes.contains(session.outputFileType!) else {throw RenderError.invalid("Exportformat")}
        onSession?(session)
        session.shouldOptimizeForNetworkUse = networkOptimized
        await withCheckedContinuation { (continuation: CheckedContinuation<Void,Never>) in
            session.exportAsynchronously { continuation.resume() }
        }
        guard session.status == .completed else { throw session.error ?? RenderError.invalid("Export") }
    }
}
