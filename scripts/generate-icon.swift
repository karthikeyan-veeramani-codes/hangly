import AppKit
let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
func draw(_ pixels: Int) -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = AffineTransform(scale: CGFloat(pixels) / 1024); (transform as NSAffineTransform).concat()
    let bg = NSBezierPath(roundedRect: NSRect(x: 50, y: 50, width: 924, height: 924), xRadius: 210, yRadius: 210)
    NSGradient(starting: NSColor(calibratedRed: 0.13, green: 0.22, blue: 0.22, alpha: 1), ending: NSColor(calibratedRed: 0.23, green: 0.37, blue: 0.32, alpha: 1))!.draw(in: bg, angle: 80)
    let rope = NSBezierPath(); rope.move(to: NSPoint(x: 512, y: 975)); rope.line(to: NSPoint(x: 512, y: 630)); rope.lineWidth = 13
    NSColor(calibratedRed: 0.89, green: 0.78, blue: 0.59, alpha: 1).setStroke(); rope.stroke()
    NSColor(calibratedRed: 0.69, green: 0.84, blue: 0.49, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: 288, y: 240, width: 448, height: 440), xRadius: 185, yRadius: 185).fill()
    NSColor(calibratedRed: 0.39, green: 0.68, blue: 0.37, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 490, y: 660, width: 180, height: 85)).fill()
    NSBezierPath(ovalIn: NSRect(x: 366, y: 662, width: 130, height: 65)).fill()
    NSColor(calibratedRed: 0.15, green: 0.25, blue: 0.22, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 407, y: 460, width: 27, height: 42)).fill()
    NSBezierPath(ovalIn: NSRect(x: 590, y: 460, width: 27, height: 42)).fill()
    let smile = NSBezierPath(); smile.move(to: NSPoint(x: 472, y: 415)); smile.curve(to: NSPoint(x: 552, y: 415), controlPoint1: NSPoint(x: 487, y: 385), controlPoint2: NSPoint(x: 537, y: 385)); smile.lineWidth = 12; smile.lineCapStyle = .round; NSColor.darkGray.setStroke(); smile.stroke()
    NSColor.systemPink.withAlphaComponent(0.4).setFill()
    NSBezierPath(ovalIn: NSRect(x: 350, y: 405, width: 70, height: 32)).fill()
    NSBezierPath(ovalIn: NSRect(x: 604, y: 405, width: 70, height: 32)).fill()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)" + (scale == 2 ? "@2x" : "") + ".png"
        try draw(points * scale).write(to: folder.appendingPathComponent(name))
    }
}
