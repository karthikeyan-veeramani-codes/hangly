import AppKit
import QuartzCore
import TetherCore

@MainActor
enum EvidenceExporter {
    /// App-owned vector test sheets, never a screen capture or compositor assertion.
    static func artworkSheets(in folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for dark in [false, true] {
            for scale in [1, 2] {
                let width = 1100, height = 780
                guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * scale, pixelsHigh: height * scale, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0), let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { throw ImportFailure(message: "Could not allocate artwork evidence sheet.") }
                NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = graphics
                graphics.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
                (dark ? NSColor(calibratedWhite: 0.13, alpha: 1) : NSColor(calibratedWhite: 0.97, alpha: 1)).setFill()
                graphics.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
                for (row, size) in [44.0, 88, 160].enumerated() {
                    for (column, original) in Preferences.builtins.enumerated() {
                        var charm = original; charm.size = size
                        let renderer = CharmRenderer(); renderer.root.frame = CGRect(x: 0, y: 0, width: width, height: height)
                        renderer.configure(charm: charm, image: nil, scale: CGFloat(scale))
                        let x = Double(column * 220 + 110), top = Double(row * 260 + 10)
                        var physics = RopePhysics(anchor: Vector(x, top + 8), length: 90)
                        physics.position = Vector(x, top + 42 + charm.attachmentY * size)
                        renderer.render(engine: physics, height: Double(height), dragging: false)
                        renderer.root.render(in: graphics.cgContext)
                        let label = "\(charm.name) · \(Int(size)) pt"
                        (label as NSString).draw(at: CGPoint(x: column * 220 + 16, y: height - row * 260 - 250), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: dark ? NSColor.white : NSColor.black])
                    }
                }
                NSGraphicsContext.restoreGraphicsState()
                let url = folder.appendingPathComponent("artwork-\(dark ? "dark" : "light")-\(scale)x.png")
                try bitmap.representation(using: .png, properties: [:])?.write(to: url)
            }
        }
    }
}
