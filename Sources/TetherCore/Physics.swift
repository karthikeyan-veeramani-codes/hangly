import Foundation

public struct Vector: Equatable, Codable, Sendable {
    public var x: Double
    public var y: Double
    public init(_ x: Double = 0, _ y: Double = 0) { self.x = x; self.y = y }
    public static func + (a: Self, b: Self) -> Self { .init(a.x + b.x, a.y + b.y) }
    public static func - (a: Self, b: Self) -> Self { .init(a.x - b.x, a.y - b.y) }
    public static func * (a: Self, b: Double) -> Self { .init(a.x * b, a.y * b) }
    public var length: Double { hypot(x, y) }
    public func dot(_ other: Self) -> Double { x * other.x + y * other.y }
}

public struct RopePhysics: Sendable {
    public var anchor: Vector
    public var position: Vector
    public var velocity = Vector()
    public var length: Double
    public var gravity: Double = 1100
    public var damping: Double = 0.9
    public var wind: Double = 0
    public private(set) var elapsed: Double = 0
    public private(set) var isResting = false
    public private(set) var accumulator: Double = 0
    private var quietTime: Double = 0
    public static let timestep = 1.0 / 120.0
    public init(anchor: Vector, length: Double) {
        self.anchor = anchor; self.length = max(40, length)
        self.position = anchor + Vector(0, max(40, length))
    }
    public mutating func wake() { isResting = false; quietTime = 0 }
    public mutating func impulse(_ impulse: Vector) { velocity = velocity + impulse; wake() }
    public mutating func resetClock() { accumulator = 0 }
    public mutating func drag(to point: Vector, velocity: Vector) {
        let delta = point - anchor
        position = anchor + delta * min(1, length / max(delta.length, 0.001))
        self.velocity = velocity * min(1, 1800 / max(velocity.length, 0.001))
        wake()
    }
    @discardableResult public mutating func advance(_ delta: Double) -> Int {
        guard delta.isFinite, delta > 0, !isResting else { return 0 }
        accumulator = min(accumulator + delta, Self.timestep * 8)
        var steps = 0
        while accumulator + 1e-12 >= Self.timestep, steps < 8 {
            step(Self.timestep); accumulator = max(0, accumulator - Self.timestep); steps += 1
        }
        return steps
    }
    private mutating func step(_ dt: Double) {
        elapsed += dt
        let gust = wind * (sin(elapsed * 1.7) + 0.4 * sin(elapsed * 3.1))
        velocity = (velocity + Vector(gust, gravity) * dt) * exp(-max(0, damping) * dt)
        position = position + velocity * dt
        let delta = position - anchor
        if delta.length > length {
            let normal = delta * (1 / delta.length)
            position = anchor + normal * length
            let outward = velocity.dot(normal)
            if outward > 0 { velocity = velocity - normal * outward }
        }
        let bottom = anchor + Vector(0, length)
        if wind == 0 && velocity.length < 1.5 && (position - bottom).length < 0.75 {
            quietTime += dt
            if quietTime > 0.75 { position = bottom; velocity = Vector(); isResting = true }
        } else { quietTime = 0 }
    }
    public mutating func contain(width: Double, height: Double, radius: Double) {
        let minX = min(radius, width / 2), maxX = max(minX, width - radius)
        let minY = min(radius, height / 2), maxY = max(minY, height - radius)
        let next = Vector(min(max(position.x, minX), maxX), min(max(position.y, minY), maxY))
        if next.x != position.x { velocity.x *= -0.25 }
        if next.y != position.y { velocity.y *= -0.25 }
        position = next
    }
}

public enum Geometry {
    public static func distance(_ p: Vector, toSegment a: Vector, _ b: Vector) -> Double {
        let ab = b - a
        let t = max(0, min(1, (p - a).dot(ab) / max(0.001, ab.dot(ab))))
        return (p - (a + ab * t)).length
    }
    public static func displayID(saved: String?, available: [String], primary: String?) -> String? {
        if let saved, available.contains(saved) { return saved }
        if let primary, available.contains(primary) { return primary }
        return available.first
    }
}
