import XCTest
@testable import TetherCore

final class PhysicsTests: XCTestCase {
    func testFixedStepIndependentOfRenderRate() {
        var a = RopePhysics(anchor: Vector(500, 0), length: 220), b = a
        a.impulse(Vector(400, -100)); b.impulse(Vector(400, -100))
        for _ in 0..<180 { a.advance(1 / 60.0) }
        for _ in 0..<90 { b.advance(1 / 30.0) }
        XCTAssertEqual(a.position.x, b.position.x, accuracy: 0.0001)
        XCTAssertEqual(a.position.y, b.position.y, accuracy: 0.0001)
    }
    func testBoundedCatchUpAndInvalidTime() {
        var p = RopePhysics(anchor: Vector(), length: 100)
        XCTAssertEqual(p.advance(1000), 8)
        XCTAssertEqual(p.advance(.nan), 0)
        XCTAssertEqual(p.advance(-1), 0)
        XCTAssertLessThan(p.accumulator, RopePhysics.timestep)
    }
    func testConstraintAndSettling() {
        var p = RopePhysics(anchor: Vector(500, 0), length: 250)
        p.impulse(Vector(600, -100))
        for _ in 0..<12000 {
            p.advance(1 / 120.0)
            XCTAssertLessThanOrEqual((p.position - p.anchor).length, 250.0001)
            XCTAssertTrue(p.position.x.isFinite)
        }
        XCTAssertTrue(p.isResting)
        XCTAssertEqual(p.velocity, Vector())
    }
    func testDragVelocityBoundAndContainment() {
        var p = RopePhysics(anchor: Vector(100, 0), length: 200)
        p.drag(to: Vector(-5000, 5000), velocity: Vector(1e6, 1e6))
        XCTAssertLessThanOrEqual((p.position - p.anchor).length, 200.001)
        XCTAssertLessThanOrEqual(p.velocity.length, 1800.001)
        p.contain(width: 500, height: 500, radius: 50)
        XCTAssertGreaterThanOrEqual(p.position.x, 50)
        XCTAssertLessThanOrEqual(p.position.y, 450)
    }
    func testRestWakeAndWind() {
        var p = RopePhysics(anchor: Vector(500, 0), length: 200)
        for _ in 0..<200 { p.advance(1 / 120.0) }
        XCTAssertTrue(p.isResting)
        XCTAssertEqual(p.advance(1), 0)
        p.wind = 180; p.wake()
        for _ in 0..<500 { p.advance(1 / 120.0) }
        XCTAssertFalse(p.isResting)
        XCTAssertGreaterThan(abs(p.position.x - 500), 1)
    }
    func testClockResetAvoidsResumeJump() {
        var p = RopePhysics(anchor: Vector(), length: 200)
        p.advance(0.003); p.resetClock()
        XCTAssertEqual(p.accumulator, 0)
        XCTAssertEqual(p.advance(1 / 120.0), 1)
    }
    func testHitGeometry() {
        XCTAssertEqual(Geometry.distance(Vector(5, 4), toSegment: Vector(), Vector(10, 0)), 4, accuracy: 0.001)
        XCTAssertEqual(Geometry.distance(Vector(13, 4), toSegment: Vector(), Vector(10, 0)), 5, accuracy: 0.001)
    }
    func testPhysicsThroughput() {
        measure {
            var p = RopePhysics(anchor: Vector(500, 0), length: 220); p.wind = 170
            for _ in 0..<12000 { p.advance(1 / 120.0) }
            XCTAssertTrue(p.position.x.isFinite)
        }
    }
}
