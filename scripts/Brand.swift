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
let root=CommandLine.arguments[1]
render(1024,1024,root+"/icon.png"){c in
    let rect=CGRect(x:72,y:72,width:880,height:880)
    c.saveGState()
    c.addPath(CGPath(roundedRect:rect,cornerWidth:205,cornerHeight:205,transform:nil));c.clip()
    let grad=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[col(0.19,0.25,0.39),col(0.06,0.08,0.13)] as CFArray,locations:[0,1])!
    c.drawLinearGradient(grad,start:CGPoint(x:140,y:930),end:CGPoint(x:880,y:100),options:[])
    c.restoreGState()
    rounded(c,CGRect(x:245,y:310,width:534,height:404),78,col(0.10,0.14,0.23))
    // Three offset timeline blades, joined by a precise cut.
    rounded(c,CGRect(x:270,y:570,width:330,height:103),34,col(0.63,0.76,1))
    rounded(c,CGRect(x:424,y:460,width:330,height:89),30,col(0.46,0.89,0.85))
    rounded(c,CGRect(x:270,y:350,width:330,height:89),30,col(0.63,0.76,1))
    c.setStrokeColor(col(0.94,0.98,1));c.setLineWidth(23);c.setLineCap(.round)
    c.move(to:CGPoint(x:620,y:710));c.addLine(to:CGPoint(x:392,y:314));c.strokePath()
}
render(660,400,root+"/background.png"){c in
    let grad=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:[col(0.12,0.17,0.26),col(0.055,0.07,0.11)] as CFArray,locations:[0,1])!
    c.drawLinearGradient(grad,start:CGPoint(x:0,y:400),end:CGPoint(x:660,y:0),options:[])
    text(c,"LYRO Cut",44,324,31,.bold,.white)
    text(c,"DEIN SCHNITT. DEIN FLOW.",46,299,12,.medium,NSColor(calibratedRed:0.63,green:0.76,blue:1,alpha:1))
    c.setStrokeColor(col(0.63,0.76,1,0.8));c.setLineWidth(2);c.setLineCap(.round)
    c.move(to:CGPoint(x:286,y:208));c.addLine(to:CGPoint(x:374,y:208));c.move(to:CGPoint(x:361,y:221));c.addLine(to:CGPoint(x:374,y:208));c.addLine(to:CGPoint(x:361,y:195));c.strokePath()
    text(c,"Ziehe LYRO Cut in den Programme-Ordner.",44,52,15,.medium,.white)
    text(c,"Version 0.2.0   ·   macOS 14+   ·   Universal",44,28,11,.regular,NSColor(white:0.65,alpha:1))
}
