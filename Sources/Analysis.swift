import Foundation
import AVFoundation
import CoreGraphics
import SwiftUI
enum MediaAnalysis {
    static func waveform(path:String,duration:Double) async -> [Double] {
        guard duration.isFinite,duration>0 else{return []}
        do {
            let asset=AVURLAsset(url:URL(fileURLWithPath:path))
            guard let track=try await asset.loadTracks(withMediaType:.audio).first else{return []}
            let reader=try AVAssetReader(asset:asset)
            let output=AVAssetReaderTrackOutput(track:track,outputSettings:[
                AVFormatIDKey:kAudioFormatLinearPCM,AVLinearPCMBitDepthKey:16,
                AVLinearPCMIsFloatKey:false,AVLinearPCMIsBigEndianKey:false,AVLinearPCMIsNonInterleaved:false
            ])
            guard reader.canAdd(output) else{return []}
            reader.add(output);guard reader.startReading() else{return []}
            let bins=512
            var peaks=[Double](repeating:0,count:bins)
            while let sample=output.copyNextSampleBuffer() {
                guard let block=CMSampleBufferGetDataBuffer(sample) else{continue}
                let count=CMBlockBufferGetDataLength(block)/2
                guard count>0 else{continue}
                var pcm=[Int16](repeating:0,count:count)
                let status=pcm.withUnsafeMutableBytes{CMBlockBufferCopyDataBytes(block,atOffset:0,dataLength:count*2,destination:$0.baseAddress!)}
                guard status==kCMBlockBufferNoErr else{continue}
                let t=CMSampleBufferGetPresentationTimeStamp(sample).seconds
                let d=CMSampleBufferGetDuration(sample).seconds
                guard t.isFinite else{continue}
                for i in stride(from:0,to:count,by:2) {
                    let time=t+(d.isFinite ? d*Double(i)/Double(count):0)
                    let bucket=max(0,min(bins-1,Int(time/duration*Double(bins))))
                    peaks[bucket]=max(peaks[bucket],abs(Double(pcm[i]))/32768)
                    if i+1<count {peaks[bucket]=max(peaks[bucket],abs(Double(pcm[i+1]))/32768)}
                }
            }
            return reader.status == .completed ? peaks : []
        } catch{return []}
    }
    static func scenes(path:String,start:Double,length:Double) async -> [Double] {
        guard length>1 else{return []}
        let asset=AVURLAsset(url:URL(fileURLWithPath:path))
        let generator=AVAssetImageGenerator(asset:asset)
        generator.appliesPreferredTrackTransform=true
        generator.maximumSize=CGSize(width:128,height:128)
        generator.requestedTimeToleranceBefore=ct(0.08)
        generator.requestedTimeToleranceAfter=ct(0.08)
        var previous:[UInt8]?
        var results:[Double]=[]
        let step=max(0.25,length/600)
        for time in stride(from:start+0.1,to:start+length-0.05,by:step) {
            guard let image=try? generator.copyCGImage(at:ct(time),actualTime:nil) else{continue}
            var data=[UInt8](repeating:0,count:16*16*4)
            let ok=data.withUnsafeMutableBytes{raw -> Bool in
                guard let c=CGContext(data:raw.baseAddress,width:16,height:16,bitsPerComponent:8,bytesPerRow:64,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return false}
                c.draw(image,in:CGRect(x:0,y:0,width:16,height:16));return true
            }
            guard ok else{continue}
            if let p=previous {
                var total=0.0
                for i in stride(from:0,to:data.count,by:4) {
                    total += abs(Double(data[i])-Double(p[i]))+abs(Double(data[i+1])-Double(p[i+1]))+abs(Double(data[i+2])-Double(p[i+2]))
                }
                let score=total/(16*16*3*255)
                if score>0.23 && time-(results.last ?? start)>0.7 {results.append(time)}
            }
            previous=data
        }
        return results
    }
}
struct WaveformStrip: View {
    let peaks:[Double]
    let sourceIn:Double
    let sourceLength:Double
    let mediaDuration:Double
    var body:some View {
        GeometryReader{g in
            Path{p in
                let bars=max(1,min(512,Int(g.size.width/2)))
                for i in 0..<bars {
                    let t=sourceIn+sourceLength*Double(i)/Double(bars)
                    let index=max(0,min(peaks.count-1,Int(t/max(0.01,mediaDuration)*Double(peaks.count))))
                    let h=max(0.7,CGFloat(peaks[index])*g.size.height*0.47)
                    let x=CGFloat(i)*g.size.width/CGFloat(bars)
                    let mid=g.size.height/2
                    p.move(to:CGPoint(x:x,y:mid-h));p.addLine(to:CGPoint(x:x,y:mid+h))
                }
            }.stroke(Color.white.opacity(0.63),lineWidth:0.8)
        }.clipped()
    }
}
