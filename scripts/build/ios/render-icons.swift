// GeneralsX @build Codex 20/11/2026 Derive local app artwork from user files; no retail pixels ship in source.
import AppKit
import ImageIO
let config=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))) as! [[String:Any]]
for item in config {
 let output=item["output"] as! String
 let context=CGContext(data:nil,width:1024,height:1024,bitsPerComponent:8,bytesPerRow:4096,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue)!
 context.setFillColor(CGColor(gray:0.025,alpha:1));context.fill(CGRect(x:0,y:0,width:1024,height:1024));context.interpolationQuality = .high
 if let path=item["source"] as? String,let ns=NSImage(contentsOfFile:path),var image=ns.cgImage(forProposedRect:nil,context:nil,hints:nil) {
  if let crop=item["crop"] as? [Int],let cropped=image.cropping(to:CGRect(x:crop[0],y:crop[1],width:crop[2],height:crop[3])){image=cropped}
  let pad=item["padding"] as? Int ?? 70
  context.draw(image,in:CGRect(x:pad,y:pad,width:1024-pad*2,height:1024-pad*2))
 } else {
  let ns=NSGraphicsContext(cgContext:context,flipped:false);NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=ns
  let text=item["fallback"] as? String ?? "GX";let attrs:[NSAttributedString.Key:Any]=[.font:NSFont.boldSystemFont(ofSize:260),.foregroundColor:NSColor.white];let size=text.size(withAttributes:attrs)
  text.draw(at:NSPoint(x:(1024-size.width)/2,y:(1024-size.height)/2),withAttributes:attrs);NSGraphicsContext.restoreGraphicsState()
 }
 let destination=CGImageDestinationCreateWithURL(URL(fileURLWithPath:output) as CFURL,"public.png" as CFString,1,nil)!
 CGImageDestinationAddImage(destination,context.makeImage()!,nil)
 if !CGImageDestinationFinalize(destination){fatalError("Unable to write icon")}
}
