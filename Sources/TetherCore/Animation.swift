import Foundation

public enum AnimationPhase: String, Sendable { case idle, swinging, dragging, reacting, sleeping, waking, paused }
public struct CharacterAnimation: Sendable {
    public private(set) var phase: AnimationPhase = .idle
    public private(set) var phaseTime: Double = 0
    public private(set) var inactivity: Double = 0
    private var reactionRemaining: Double = 0
    private var reactionElapsed: Double = 0
    private var wakeRemaining: Double = 0
    public init() {}
    public var needsFrames: Bool { phase == .reacting || phase == .waking }
    public var reactionScale: Double { reactionRemaining > 0 ? 1 + 0.08 * sin(min(1, reactionElapsed / 0.45) * .pi) : 1 }
    public mutating func interact(reaction: Bool, reducedMotion: Bool) {
        inactivity = 0
        if phase == .sleeping { wakeRemaining = reducedMotion ? 0 : 0.35 }
        if reaction { reactionRemaining = reducedMotion ? 0 : 0.45; reactionElapsed = 0 }
    }
    public mutating func update(dt: Double, moving: Bool, dragging: Bool, paused: Bool, sleepAfter: Double, reducedMotion: Bool) {
        let delta = dt.isFinite ? max(0, min(dt, 1)) : 0
        if !paused {
            inactivity += delta
            if reducedMotion { reactionRemaining = 0; wakeRemaining = 0 }
            if !dragging { wakeRemaining = max(0, wakeRemaining - delta); if wakeRemaining == 0 { reactionRemaining = max(0, reactionRemaining - delta); reactionElapsed += delta } }
        }
        let next: AnimationPhase
        if paused { next = .paused }
        else if dragging { next = .dragging }
        else if wakeRemaining > 0 { next = .waking }
        else if reactionRemaining > 0 { next = .reacting }
        else if !moving && sleepAfter > 0 && inactivity >= sleepAfter { next = .sleeping }
        else { next = moving ? .swinging : .idle }
        if phase == next { phaseTime += paused ? 0 : delta } else { phase = next; phaseTime = 0 }
    }
}
