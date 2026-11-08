import AppKit

// Run With app icon: two lanes sweeping up and to the right on track orange.
// The solid lane is you; the dashed lane beside it is whoever you run with.
let size: CGFloat = 1024
let out = CommandLine.arguments[1]
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// Background: warm orange, slightly deeper at the bottom.
let space = CGColorSpaceCreateDeviceRGB()
let top = CGColor(red: 1.0, green: 0.55, blue: 0.16, alpha: 1)
let bottom = CGColor(red: 0.93, green: 0.36, blue: 0.10, alpha: 1)
let grad = CGGradient(colorsSpace: space, colors: [bottom, top] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size), options: [])

// Nudged up and slightly left so the pair sits centred inside the rounded mask.
let dx: CGFloat = -14, dy: CGFloat = 58
func lane(offset: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 150 + offset + dx, y: 170 - offset + dy))
    p.addCurve(to: CGPoint(x: 780 + offset + dx, y: 800 - offset + dy),
               control1: CGPoint(x: 520 + offset + dx, y: 170 - offset + dy),
               control2: CGPoint(x: 420 + offset + dx, y: 800 - offset + dy))
    return p
}

ctx.setLineCap(.round)
ctx.setLineJoin(.round)

// The companion's lane: dashed, softer, a little behind and to the right.
// Drawn opaque inside one transparency layer so the dot and the last dash
// merge instead of doubling up where they overlap.
ctx.saveGState()
ctx.setAlpha(0.55)
ctx.beginTransparencyLayer(auxiliaryInfo: nil)
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.setLineWidth(46)
ctx.setLineDash(phase: 0, lengths: [70, 62])
ctx.addPath(lane(offset: 92))
ctx.strokePath()
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fillEllipse(in: CGRect(x: 780 + 92 - 44 + dx, y: 800 - 92 - 44 + dy, width: 88, height: 88))
ctx.endTransparencyLayer()
ctx.restoreGState()

// Your lane: solid white, ending in the runner's dot.
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.setLineWidth(58)
ctx.addPath(lane(offset: 0))
ctx.strokePath()
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
ctx.fillEllipse(in: CGRect(x: 780 - 64 + dx, y: 800 - 64 + dy, width: 128, height: 128))

NSGraphicsContext.restoreGraphicsState()
// App Store icons must be opaque: drop the alpha channel on export.
let cg = rep.cgImage!
let opaque = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                       space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
opaque.draw(cg, in: CGRect(x: 0, y: 0, width: size, height: size))
let final = NSBitmapImageRep(cgImage: opaque.makeImage()!)
try! final.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote", out)
