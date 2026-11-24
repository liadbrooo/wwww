import AppKit
import CoreGraphics
import Foundation
func render(_ w:Int,_ h:Int,_ path:String,_ draw:(CGContext)->Void) {
    let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(c)
    let image=c.makeImage()!
    let rep=NSBitmapImageRep(cgImage:image)
    try! rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
}
func col(_ r:CGFloat,_ g:CGFloat,_ b:CGFloat,_ a:CGFloat=1)->CGColor {CGColor(red:r,green:g,blue:b,alpha:a)}
func rounded(_ c:CGContext,_ rect:CGRect,_ radius:CGFloat,_ color:CGColor) {
    c.setFillColor(color);c.addPath(CGPath(roundedRect:rect,cornerWidth:radius,cornerHeight:radius,transform:nil));c.fillPath()
}
func text(_ c:CGContext,_ string:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ weight:NSFont.Weight,_ color:NSColor) {
    NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(cgContext:c,flipped:false)
    (string as NSString).draw(at:CGPoint(x:x,y:y),withAttributes:[.font:NSFont.systemFont(ofSize:size,weight:weight),.foregroundColor:color])
    NSGraphicsContext.restoreGraphicsState()
}
func gradient(_ c:CGContext,_ colors:[CGColor],_ start:CGPoint,_ end:CGPoint){
    let g=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors as CFArray,locations:nil)!
    c.drawLinearGradient(g,start:start,end:end,options:[.drawsBeforeStartLocation,.drawsAfterEndLocation])
}
func shape(_ c:CGContext,_ p:CGPath,_ colors:[CGColor],_ start:CGPoint,_ end:CGPoint){
    c.saveGState();c.addPath(p);c.clip();gradient(c,colors,start,end);c.restoreGState()
}
func logo(_ c:CGContext){
    let rect=CGRect(x:55,y:55,width:914,height:914)
    let outline=CGPath(roundedRect:rect,cornerWidth:210,cornerHeight:210,transform:nil)
    c.saveGState();c.addPath(outline);c.clip()
    gradient(c,[col(0.10,0.24,0.51),col(0.025,0.055,0.13),col(0.025,0.25,0.30)],CGPoint(x:40,y:1024),CGPoint(x:1000,y:50))
    let wave=CGMutablePath();wave.move(to:CGPoint(x:0,y:320));wave.addCurve(to:CGPoint(x:1024,y:710),control1:CGPoint(x:210,y:700),control2:CGPoint(x:730,y:470));wave.addLine(to:CGPoint(x:1024,y:0));wave.addLine(to:.zero);wave.closeSubpath()
    shape(c,wave,[col(0.06,0.40,0.82,0.85),col(0.015,0.06,0.15),col(0.03,0.25,0.29)],CGPoint(x:0,y:680),CGPoint(x:930,y:100))
    let l=CGMutablePath();l.move(to:CGPoint(x:270,y:465));l.addLine(to:CGPoint(x:423,y:822));l.addQuadCurve(to:CGPoint(x:486,y:858),control:CGPoint(x:442,y:858));l.addLine(to:CGPoint(x:630,y:858));l.addLine(to:CGPoint(x:476,y:465));l.closeSubpath()
    shape(c,l,[col(0.72,0.96,1),col(0.20,0.59,0.98),col(0.10,0.22,0.73)],CGPoint(x:485,y:860),CGPoint(x:420,y:460))
    let wing=CGMutablePath();wing.move(to:CGPoint(x:270,y:465));wing.addLine(to:CGPoint(x:466,y:585));wing.addLine(to:CGPoint(x:785,y:585));wing.addLine(to:CGPoint(x:737,y:503));wing.addQuadCurve(to:CGPoint(x:674,y:465),control:CGPoint(x:714,y:465));wing.closeSubpath()
    shape(c,wing,[col(0.10,0.39,0.91),col(0.25,0.91,0.91),col(0.72,1,0.98)],CGPoint(x:270,y:480),CGPoint(x:785,y:585))
    c.saveGState();c.setShadow(offset:.zero,blur:24,color:col(0.23,0.90,1));c.setStrokeColor(col(0.83,1,1));c.setLineWidth(7);c.setLineCap(.round)
    c.move(to:CGPoint(x:420,y:409));c.addLine(to:CGPoint(x:655,y:740));c.strokePath();c.restoreGState()
    c.setStrokeColor(col(0.38,0.63,0.91,0.6));c.setLineWidth(3)
    c.move(to:CGPoint(x:128,y:345));c.addLine(to:CGPoint(x:902,y:345));c.strokePath()
    for x in stride(from:158,through:900,by:73){c.move(to:CGPoint(x:x,y:349));c.addLine(to:CGPoint(x:x,y:364));c.strokePath()}
    let bars:[(CGFloat,CGFloat,CGFloat,CGFloat,CGColor,CGColor)] = [
        (135,250,388,67,col(0.03,0.38,0.82),col(0.34,0.76,0.99)),(535,250,360,67,col(0.10,0.53,0.92),col(0.035,0.18,0.38)),
        (250,175,273,52,col(0.03,0.52,0.53),col(0.30,0.93,0.81)),(535,175,300,52,col(0.08,0.64,0.63),col(0.03,0.26,0.33)),
        (393,114,130,40,col(0.26,0.35,0.93),col(0.42,0.56,1)),(535,114,290,40,col(0.28,0.32,0.89),col(0.05,0.10,0.28))]
    for (x,y,w,h,a,b) in bars {let p=CGPath(roundedRect:CGRect(x:x,y:y,width:w,height:h),cornerWidth:13,cornerHeight:13,transform:nil);shape(c,p,[a,b],CGPoint(x:x,y:y),CGPoint(x:x+w,y:y+h))}
    for i in 0..<47 {let x=270+CGFloat(i)*12;if abs(x-529)<12{continue};let h=7+abs(sin(Double(i)*1.7)*cos(Double(i)*0.47))*24;rounded(c,CGRect(x:x,y:201-h/2,width:4,height:h),2,col(0.75,1,0.95,0.85))}
    c.saveGState();c.setShadow(offset:.zero,blur:18,color:col(0.20,1,0.95));c.setStrokeColor(col(0.80,1,0.98));c.setLineWidth(5)
    c.move(to:CGPoint(x:529,y:100));c.addLine(to:CGPoint(x:529,y:385));c.strokePath()
    let p=CGMutablePath();p.move(to:CGPoint(x:511,y:392));p.addLine(to:CGPoint(x:547,y:392));p.addLine(to:CGPoint(x:529,y:364));p.closeSubpath();c.setFillColor(col(0.80,1,0.98));c.addPath(p);c.fillPath();c.restoreGState()
    c.restoreGState()
    c.addPath(outline);c.setStrokeColor(col(0.38,0.75,0.94,0.9));c.setLineWidth(4);c.strokePath()
}
let root=CommandLine.arguments[1]
render(1024,1024,root+"/icon.png"){logo($0)}
render(760,440,root+"/background.png"){c in
    gradient(c,[col(0.035,0.08,0.18),col(0.04,0.15,0.25),col(0.035,0.30,0.32)],CGPoint(x:0,y:440),CGPoint(x:760,y:0))
    let wave=CGMutablePath();wave.move(to:CGPoint(x:0,y:0));wave.addCurve(to:CGPoint(x:760,y:140),control1:CGPoint(x:260,y:40),control2:CGPoint(x:560,y:40));wave.addLine(to:CGPoint(x:760,y:0));wave.closeSubpath()
    shape(c,wave,[col(0.06,0.20,0.64),col(0.04,0.67,0.69)],CGPoint(x:0,y:0),CGPoint(x:760,y:100))
    c.saveGState();c.translateBy(x:33,y:234);c.scaleBy(x:0.15,y:0.15);logo(c);c.restoreGState()
    text(c,"LYRO Cut",42,193,34,.bold,.white)
    text(c,"Edit with flow.",43,162,17,.medium,NSColor(calibratedRed:0.60,green:0.88,blue:1,alpha:1))
    text(c,"Cut with precision.",43,141,17,.medium,.white)
    text(c,"Nativ für macOS  ·  4K  ·  Keyframes",43,103,11,.regular,NSColor(white:0.78,alpha:1))
    rounded(c,CGRect(x:293,y:104,width:425,height:253),25,col(0.08,0.18,0.26,0.78))
    c.setStrokeColor(col(0.36,0.76,0.90,0.35));c.setLineWidth(1);c.addPath(CGPath(roundedRect:CGRect(x:293,y:104,width:425,height:253),cornerWidth:25,cornerHeight:25,transform:nil));c.strokePath()
    c.setStrokeColor(col(0.65,0.98,1));c.setLineWidth(3);c.setLineCap(.round)
    c.move(to:CGPoint(x:478,y:240));c.addLine(to:CGPoint(x:535,y:240));c.move(to:CGPoint(x:522,y:253));c.addLine(to:CGPoint(x:535,y:240));c.addLine(to:CGPoint(x:522,y:227));c.strokePath()
    text(c,"Ziehe die App in den Programme-Ordner.",43,42,13,.medium,.white)
    text(c,"VERSION 0.6.1  /  UNIVERSAL",43,21,10,.medium,NSColor(white:0.7,alpha:1))
}
