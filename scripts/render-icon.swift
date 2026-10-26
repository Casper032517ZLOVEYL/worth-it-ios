import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let side = 1024
let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor {
    CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}
let background = color(247, 241, 232)
let lime = color(165, 94, 66)
let lilac = color(230, 188, 139)
context.setFillColor(background)
context.fill(CGRect(x: 0, y: 0, width: side, height: side))
context.setStrokeColor(color(210, 189, 163))
context.setLineWidth(2)
context.strokeEllipse(in: CGRect(x: 138, y: 138, width: 748, height: 748))
context.saveGState()
context.addEllipse(in: CGRect(x: 235, y: 235, width: 554, height: 554))
context.clip()
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [color(255, 233, 201), lilac, color(172, 119, 85)] as CFArray,
                          locations: [0, 0.4, 1])!
context.drawRadialGradient(gradient, startCenter: CGPoint(x: 395, y: 670), startRadius: 0,
                          endCenter: CGPoint(x: 395, y: 670), endRadius: 620, options: .drawsAfterEndLocation)
context.restoreGState()
context.saveGState()
context.translateBy(x: 512, y: 512)
context.rotate(by: .pi * 32 / 180)
context.setStrokeColor(lime)
context.setLineWidth(5)
context.strokeEllipse(in: CGRect(x: -398, y: -136, width: 796, height: 272))
context.restoreGState()
context.setStrokeColor(background)
context.setLineWidth(13)
context.setLineCap(.round)
for i in 0..<3 {
    let angle = Double(i) * .pi / 3
    context.move(to: CGPoint(x: 512 - cos(angle) * 142, y: 512 - sin(angle) * 142))
    context.addLine(to: CGPoint(x: 512 + cos(angle) * 142, y: 512 + sin(angle) * 142))
    context.strokePath()
}
context.setFillColor(lime)
context.fillEllipse(in: CGRect(x: 162, y: 319, width: 30, height: 30))
context.move(to: CGPoint(x: 815, y: 824))
context.addQuadCurve(to: CGPoint(x: 848, y: 791), control: CGPoint(x: 821, y: 797))
context.addQuadCurve(to: CGPoint(x: 815, y: 758), control: CGPoint(x: 821, y: 785))
context.addQuadCurve(to: CGPoint(x: 782, y: 791), control: CGPoint(x: 809, y: 785))
context.addQuadCurve(to: CGPoint(x: 815, y: 824), control: CGPoint(x: 809, y: 797))
context.fillPath()
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination))
