import Foundation

/// Fits actual constrained bob positions over a bounded event-time window.
/// It never estimates a throw from cursor movement the tether did not permit.
public struct DragTracker: Sendable {
    private struct Sample: Sendable { let position: Vector; let time: Double }
    private var samples: [Sample] = []
    public private(set) var offset = Vector()
    private var start = Vector()
    public private(set) var moved = false
    public init() {}
    public mutating func begin(pointer: Vector, bob: Vector, time: Double) {
        offset = bob - pointer; start = pointer; moved = false
        samples = time.isFinite ? [Sample(position: bob, time: time)] : []
    }
    public func target(for pointer: Vector) -> Vector { pointer + offset }
    public mutating func record(pointer: Vector, actual: Vector, time: Double) {
        guard time.isFinite, actual.x.isFinite, actual.y.isFinite else { return }
        moved = moved || (pointer - start).length > 4
        if let last = samples.last, time <= last.time { return }
        samples.append(Sample(position: actual, time: time))
        samples.removeAll { time - $0.time > 0.1 }
        if samples.count > 16 { samples.removeFirst(samples.count - 16) }
    }
    public func releaseVelocity(at time: Double) -> Vector {
        guard time.isFinite, let last = samples.last, time >= last.time, time - last.time <= 0.1, samples.count >= 2 else { return Vector() }
        let origin = samples[0].time
        let meanTime = samples.reduce(0) { $0 + $1.time - origin } / Double(samples.count)
        let mean = samples.reduce(Vector()) { $0 + $1.position } * (1 / Double(samples.count))
        var numerator = Vector(), denominator = 0.0
        for sample in samples {
            let dt = sample.time - origin - meanTime
            numerator = numerator + (sample.position - mean) * dt; denominator += dt * dt
        }
        guard denominator > 1e-8 else { return Vector() }
        let velocity = numerator * (1 / denominator)
        return velocity * min(1, 1800 / max(velocity.length, 0.001))
    }
}
