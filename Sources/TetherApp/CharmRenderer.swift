import AppKit
import QuartzCore
import TetherCore

@MainActor
final class CharmRenderer {
    let root = CALayer()
    private let rope = CAShapeLayer()
    private let pin = CAShapeLayer()
    private let body = CALayer()
    private var pinAnchor: CGPoint?
    private var sleepingEyes: Bool?
    private var size: Double = 88
    private var attachment = CGPoint(x: 0.5, y: 0.12)
    private var eyes: [CALayer] = []
    private var artworkKey: String?
    private var outlineLayers: [CAShapeLayer] = []
    private var alphaPixels: [UInt8] = []
    private let alphaSide = 256
    private(set) var bodyCenter = CGPoint.zero
    var artworkFrame: CGRect { body.convert(body.bounds, to: root) }
    func localPoint(_ point: CGPoint) -> CGPoint { body.convert(point, from: root) }
    func attachmentLocation() -> CGPoint { body.convert(CGPoint(x: attachment.x * 100, y: (1 - attachment.y) * 100), to: root) }
    func layerScales() -> [CGFloat] {
        func collect(_ layer: CALayer) -> [CGFloat] { [layer.contentsScale] + (layer.sublayers ?? []).flatMap(collect) + (layer.mask.map(collect) ?? []) }
        return collect(root)
    }
    init() {
        root.addSublayer(rope); root.addSublayer(pin); root.addSublayer(body)
        rope.strokeColor = NSColor(calibratedRed: 0.57, green: 0.49, blue: 0.38, alpha: 0.9).cgColor
        rope.fillColor = nil; rope.lineWidth = 2.5; rope.lineCap = .round
        pin.fillColor = NSColor.systemOrange.cgColor
    }
    func configure(charm: Charm, image: NSImage?, scale: CGFloat, highContrast: Bool = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        size = charm.size
        attachment = CGPoint(x: charm.attachmentX, y: charm.attachmentY)
        root.opacity = Float(charm.opacity)
        rope.lineWidth = charm.ropeWidth
        rope.strokeColor = NSColor(calibratedRed: charm.ropeColor.red, green: charm.ropeColor.green, blue: charm.ropeColor.blue, alpha: charm.ropeColor.alpha).cgColor
        body.anchorPoint = CGPoint(x: attachment.x, y: 1 - attachment.y)
        setScale(scale, on: root)
        let key = charm.kind.rawValue + (charm.assetFilename ?? "")
        if key == artworkKey { applyContrast(highContrast); return }
        artworkKey = key; sleepingEyes = nil; eyes.removeAll(); outlineLayers.removeAll(); alphaPixels.removeAll()
        body.sublayers?.forEach { $0.removeFromSuperlayer() }
        body.contents = nil; body.bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        body.contentsScale = scale
        body.shadowColor = NSColor.black.cgColor; body.shadowOpacity = 0.2
        body.shadowRadius = 5; body.shadowOffset = CGSize(width: 0, height: -2)
        if let image {
            var rect = CGRect(origin: .zero, size: image.size)
            let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
            body.contents = cg
            if let cg { makeAlphaMask(cg) }
            body.contentsGravity = .resizeAspect
        } else { draw(charm.kind) }
        setScale(scale, on: root); applyContrast(highContrast)
    }
    private func applyContrast(_ enabled: Bool) {
        if outlineLayers.isEmpty { outlineLayers = (body.sublayers ?? []).compactMap { $0 as? CAShapeLayer }.filter { $0.strokeColor == nil && !eyes.contains($0) } }
        for layer in outlineLayers { layer.strokeColor = enabled ? NSColor.labelColor.withAlphaComponent(0.65).cgColor : nil; layer.lineWidth = enabled ? 1.2 : 0 }
    }
    private func shape(_ path: CGPath, _ color: NSColor, parent: CALayer? = nil) {
        let layer = CAShapeLayer(); layer.path = path; layer.fillColor = color.cgColor
        (parent ?? body).addSublayer(layer)
    }
    private func ellipse(_ rect: CGRect, _ color: NSColor) { shape(CGPath(ellipseIn: rect, transform: nil), color) }
    private func draw(_ kind: CharmKind) {
        switch kind {
        case .sprout:
            shape(CGPath(roundedRect: CGRect(x: 18, y: 10, width: 64, height: 65), cornerWidth: 28, cornerHeight: 28, transform: nil), NSColor(calibratedRed: 0.65, green: 0.81, blue: 0.48, alpha: 1))
            let stem = CGMutablePath(); stem.move(to: CGPoint(x: 50, y: 67)); stem.addQuadCurve(to: CGPoint(x: 51, y: 91), control: CGPoint(x: 42, y: 82))
            let leaf = CAShapeLayer(); leaf.path = stem; leaf.strokeColor = NSColor.systemGreen.cgColor; leaf.lineWidth = 5; body.addSublayer(leaf)
            ellipse(CGRect(x: 48, y: 80, width: 27, height: 14), .systemGreen)
            ellipse(CGRect(x: 27, y: 78, width: 23, height: 12), NSColor(calibratedRed: 0.39, green: 0.65, blue: 0.33, alpha: 1))
        case .cloud:
            let color = NSColor(calibratedRed: 0.79, green: 0.85, blue: 1, alpha: 1)
            shape(CGPath(roundedRect: CGRect(x: 6, y: 20, width: 88, height: 43), cornerWidth: 21, cornerHeight: 21, transform: nil), color)
            ellipse(CGRect(x: 19, y: 40, width: 40, height: 40), color)
            ellipse(CGRect(x: 44, y: 41, width: 35, height: 32), color)
        case .moon:
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(x: 10, y: 7, width: 80, height: 86))
            path.addEllipse(in: CGRect(x: 47, y: 48, width: 51, height: 53))
            let crescent = CAShapeLayer(); crescent.path = path; crescent.fillRule = .evenOdd
            crescent.fillColor = NSColor(calibratedRed: 0.98, green: 0.86, blue: 0.63, alpha: 1).cgColor
            let mask = CAShapeLayer(); mask.path = CGPath(ellipseIn: CGRect(x: 10, y: 7, width: 80, height: 86), transform: nil)
            crescent.mask = mask; body.addSublayer(crescent)
            ellipse(CGRect(x: 22, y: 58, width: 9, height: 11), NSColor.systemOrange.withAlphaComponent(0.2))
        case .jelly:
            let color = NSColor(calibratedRed: 0.4, green: 0.8, blue: 0.78, alpha: 1)
            for x in [25, 42, 59, 76] {
                let path = CGMutablePath(); path.move(to: CGPoint(x: x, y: 40)); path.addCurve(to: CGPoint(x: x - 5, y: 7), control1: CGPoint(x: x + 12, y: 25), control2: CGPoint(x: x - 15, y: 20))
                let leg = CAShapeLayer(); leg.path = path; leg.fillColor = nil; leg.strokeColor = color.cgColor; leg.lineWidth = 9; leg.lineCap = .round; body.addSublayer(leg)
            }
            shape(CGPath(roundedRect: CGRect(x: 10, y: 30, width: 80, height: 58), cornerWidth: 36, cornerHeight: 36, transform: nil), color)
            ellipse(CGRect(x: 23, y: 65, width: 19, height: 10), NSColor.white.withAlphaComponent(0.4))
        case .comet, .custom:
            let path = CGMutablePath()
            for i in 0..<10 {
                let angle = Double(i) * .pi / 5 + .pi / 2
                let radius: Double = i.isMultiple(of: 2) ? 45 : 31
                let p = CGPoint(x: 50 + cos(angle) * radius, y: 50 + sin(angle) * radius)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath(); shape(path, NSColor(calibratedRed: 1, green: 0.76, blue: 0.33, alpha: 1))
        }
        for x in [34.0, 61.0] {
            let eye = CAShapeLayer(); eye.path = CGPath(ellipseIn: CGRect(x: -2.5, y: -4, width: 5, height: 8), transform: nil)
            eye.position = CGPoint(x: x + 2.5, y: 47); eye.fillColor = NSColor.darkGray.cgColor
            body.addSublayer(eye); eyes.append(eye)
        }
        ellipse(CGRect(x: 25, y: 34, width: 13, height: 6), NSColor.systemPink.withAlphaComponent(0.35))
        ellipse(CGRect(x: 63, y: 34, width: 13, height: 6), NSColor.systemPink.withAlphaComponent(0.35))
        let smile = CGMutablePath(); smile.move(to: CGPoint(x: 44, y: 37)); smile.addQuadCurve(to: CGPoint(x: 56, y: 37), control: CGPoint(x: 50, y: 30))
        let mouth = CAShapeLayer(); mouth.path = smile; mouth.strokeColor = NSColor.darkGray.cgColor; mouth.fillColor = nil; mouth.lineWidth = 2; mouth.lineCap = .round; body.addSublayer(mouth)
    }
    func render(engine: RopePhysics, height: Double, dragging: Bool, animation: CharacterAnimation = CharacterAnimation()) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        let a = CGPoint(x: engine.anchor.x, y: height - engine.anchor.y)
        let b = CGPoint(x: engine.position.x, y: height - engine.position.y)
        let path = CGMutablePath(); path.move(to: a); path.addLine(to: b); rope.path = path
        if pinAnchor != a {
            pin.path = CGPath(ellipseIn: CGRect(x: a.x - 4, y: a.y - 4, width: 8, height: 8), transform: nil)
            pinAnchor = a
        }
        let sleeping = animation.phase == .sleeping
        if sleepingEyes != sleeping {
            for eye in eyes { eye.transform = CATransform3DMakeScale(1, sleeping ? 0.12 : 1, 1) }
            sleepingEyes = sleeping
        }
        let angle = atan2(engine.position.x - engine.anchor.x, max(1, engine.position.y - engine.anchor.y))
        let factor = size / 100 * animation.reactionScale
        body.position = b
        body.transform = CATransform3DScale(CATransform3DMakeRotation(angle * 0.4, 0, 0, 1), factor, factor, 1)
        bodyCenter = body.convert(CGPoint(x: 50, y: 50), to: root)
        CATransaction.commit()
    }
    private func setScale(_ scale: CGFloat, on layer: CALayer) {
        layer.contentsScale = scale
        for child in layer.sublayers ?? [] { setScale(scale, on: child) }
        if let mask = layer.mask { setScale(scale, on: mask) }
    }
    private func makeAlphaMask(_ image: CGImage) {
        var rgba = [UInt8](repeating: 0, count: alphaSide * alphaSide * 4)
        rgba.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(data: bytes.baseAddress, width: alphaSide, height: alphaSide, bitsPerComponent: 8, bytesPerRow: alphaSide * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else { return }
            let ratio = min(Double(alphaSide) / Double(image.width), Double(alphaSide) / Double(image.height))
            let width = Double(image.width) * ratio, height = Double(image.height) * ratio
            context.draw(image, in: CGRect(x: (Double(alphaSide) - width) / 2, y: (Double(alphaSide) - height) / 2, width: width, height: height))
        }
        alphaPixels = stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
    }
    /// Tests visible fill/stroke geometry, excluding shadows and transparent image pixels.
    func hitBody(_ rootPoint: CGPoint) -> Bool {
        let point = body.convert(rootPoint, from: root)
        guard body.bounds.contains(point) else { return false }
        if !alphaPixels.isEmpty {
            let x = min(alphaSide - 1, Int(point.x / 100 * Double(alphaSide)))
            let y = min(alphaSide - 1, Int(point.y / 100 * Double(alphaSide)))
            return alphaPixels[y * alphaSide + x] >= 16
        }
        func hit(_ layer: CALayer, _ local: CGPoint) -> Bool {
            if let mask = layer.mask, !hit(mask, mask.convert(local, from: layer)) { return false }
            if let shape = layer as? CAShapeLayer, let path = shape.path {
                if shape.fillColor != nil && path.contains(local, using: shape.fillRule == .evenOdd ? .evenOdd : .winding) { return true }
                if shape.strokeColor != nil && path.copy(strokingWithWidth: shape.lineWidth, lineCap: .round, lineJoin: .round, miterLimit: 10).contains(local) { return true }
            }
            return (layer.sublayers ?? []).contains { hit($0, $0.convert(local, from: layer)) }
        }
        return hit(body, point)
    }
    func stopAmbient() { body.removeAllAnimations(); eyes.forEach { $0.removeAllAnimations() } }
    func idleVariation(blink: Bool, reducedMotion: Bool) {
        guard !reducedMotion else { return }
        if blink {
            for eye in eyes {
                let animation = CABasicAnimation(keyPath: "transform.scale.y")
                animation.fromValue = 1; animation.toValue = 0.1; animation.duration = 0.11; animation.autoreverses = true
                eye.add(animation, forKey: "blink")
            }
        } else {
            let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            animation.values = [0, -0.025, 0.025, 0]; animation.duration = 1.1; animation.isAdditive = true
            body.add(animation, forKey: "idle")
        }
    }

}
