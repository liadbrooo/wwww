import Foundation
import AVFoundation
import CoreImage
import AppKit

@main struct RenderTests {
    static func fixture(_ url: URL) async throws {
        let writer = try AVAssetWriter(outputURL:url,fileType:.mp4)
        let input = AVAssetWriterInput(mediaType:.video,outputSettings:[
            AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:320,AVVideoHeightKey:180
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[
            kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String:320,kCVPixelBufferHeightKey as String:180
        ])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? RenderError.invalid("fixture") }
        writer.startSession(atSourceTime:.zero)
        for i in 0..<30 {
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else { throw writer.error ?? RenderError.invalid("fixture") }
                try await Task.sleep(nanoseconds:1_000_000)
            }
            var buffer: CVPixelBuffer?
            guard let pool = adaptor.pixelBufferPool,
                  CVPixelBufferPoolCreatePixelBuffer(nil,pool,&buffer) == kCVReturnSuccess,
                  let pixel = buffer else { throw RenderError.invalid("pixel buffer") }
            CVPixelBufferLockBaseAddress(pixel,[])
            let stride = CVPixelBufferGetBytesPerRow(pixel)
            let ptr = CVPixelBufferGetBaseAddress(pixel)!.assumingMemoryBound(to:UInt8.self)
            for y in 0..<180 {
                for x in 0..<320 {
                    let pos = y*stride+x*4
                    ptr[pos]=30;ptr[pos+1]=70;ptr[pos+2]=220;ptr[pos+3]=255
                }
            }
            CVPixelBufferUnlockBaseAddress(pixel,[])
            guard adaptor.append(pixel,withPresentationTime:CMTime(value:Int64(i),timescale:30)) else { throw writer.error ?? RenderError.invalid("append") }
        }
        writer.endSession(atSourceTime:ct(1))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? RenderError.invalid("fixture finish") }
    }
    static func main() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:dir)}
        let source = dir.appendingPathComponent("source.mp4")
        let output = dir.appendingPathComponent("export.mp4")
        try await fixture(source)
        var p=Project()
        let m=Media(path:source.path,name:"Fixture",duration:1,kind:.video)
        p.media=[m]
        var c=Clip(mediaID:m.id,name:"Fixture",kind:.video,length:1)
        c.motion = .zoomIn
        var second=c;second.id=UUID();second.start=1;second.look = .monochrome
        let title=Clip(name:"Title",kind:.title,start:0.2,length:0.6,lane:2,title:"LYRO Cut")
        p.clips=[c,second,title]
        let graph=try await Renderer.build(p)
        try await Renderer.export(graph,to:output)
        let asset=AVURLAsset(url:output)
        let duration=try await asset.load(.duration).seconds
        guard abs(duration-2) < 0.12 else {throw RenderError.invalid("export duration")}
        let generator=AVAssetImageGenerator(asset:asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let ci=CIContext()
        for t in [0.4,1.4] {
            let frame=try generator.copyCGImage(at:ct(t),actualTime:nil)
            guard frame.width == 1920,frame.height == 1080 else {throw RenderError.invalid("export dimensions")}
            let image=CIImage(cgImage:frame)
            let avg=image.applyingFilter("CIAreaAverage",parameters:[kCIInputExtentKey:CIVector(cgRect:image.extent)])
            var rgba=[UInt8](repeating:0,count:4)
            rgba.withUnsafeMutableBytes {bytes in
                ci.render(avg,toBitmap:bytes.baseAddress!,rowBytes:4,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB())
            }
            guard Int(rgba[0])+Int(rgba[1])+Int(rgba[2])>45 else {throw RenderError.invalid("unexpected black output")}
            if t<1 { guard Int(rgba[0])>Int(rgba[2])+20 else {throw RenderError.invalid("source color")} }
            else {guard abs(Int(rgba[0])-Int(rgba[2]))<20 else {throw RenderError.invalid("monochrome effect")} }
        }
        p.canvas = .portrait
        p.fps = 25
        p.ultraHD = true
        let portrait=try await Renderer.build(p)
        guard portrait.video.renderSize==CGSize(width:2160,height:3840),
              abs(portrait.video.frameDuration.seconds-0.04)<0.000001 else {throw RenderError.invalid("UHD format / fps")}
        let uhdURL=dir.appendingPathComponent("uhd.mp4")
        try await Renderer.export(portrait,to:uhdURL)
        let uhdAsset=AVURLAsset(url:uhdURL)
        guard let uhdTrack=try await uhdAsset.loadTracks(withMediaType:.video).first else{throw RenderError.invalid("UHD output")}
        let uhdSize=try await uhdTrack.load(.naturalSize)
        let uhdFPS=try await uhdTrack.load(.nominalFrameRate)
        guard uhdSize==CGSize(width:2160,height:3840),abs(uhdFPS-25)<0.1 else{throw RenderError.invalid("UHD export metadata")}
        print("Actual UHD export passed")
        let fixture=CIImage(color:CIColor(red:0.3,green:0.6,blue:0.9)).cropped(to:CGRect(x:0,y:0,width:64,height:64))
        let ci=CIContext()
        for effect in Effect.allCases where effect != .none {
            let result=EffectRenderer.apply(EffectLayer(effect:effect,intensity:0.8),to:fixture)
            guard result.extent==fixture.extent,ci.createCGImage(result,from:fixture.extent) != nil else{throw RenderError.invalid("Effect "+effect.rawValue)}
        }
        print("Effect catalog render tests passed")
        print("Real AVFoundation import, composition, title, motion, color effect and MP4 export passed")
    }
}
