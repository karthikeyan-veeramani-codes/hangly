import XCTest
@testable import TetherCore

final class InteractionPolishTests: XCTestCase {
    func testGrabOffsetAndMeasuredLinearVelocity() {
        var drag = DragTracker()
        drag.begin(pointer: Vector(80, 100), bob: Vector(100, 120), time: 1)
        XCTAssertEqual(drag.target(for: Vector(90, 110)), Vector(110, 130))
        for i in 1...5 { drag.record(pointer: Vector(80 + Double(i) * 10, 100), actual: Vector(100 + Double(i) * 10, 120), time: 1 + Double(i) * 0.02) }
        XCTAssertTrue(drag.moved)
        XCTAssertEqual(drag.releaseVelocity(at: 1.1).x, 500, accuracy: 0.01)
        XCTAssertEqual(drag.releaseVelocity(at: 1.1).y, 0, accuracy: 0.01)
    }
    func testConstrainedCursorMotionDoesNotInventThrow() {
        var drag = DragTracker()
        drag.begin(pointer: Vector(), bob: Vector(100, 200), time: 1)
        for i in 1...8 { drag.record(pointer: Vector(Double(i) * 1000, 500), actual: Vector(100, 200), time: 1 + Double(i) * 0.01) }
        XCTAssertEqual(drag.releaseVelocity(at: 1.08), Vector())
    }
    func testHeldAndDuplicateTimestampsAreSafeAndVelocityBounded() {
        var drag = DragTracker()
        drag.begin(pointer: Vector(), bob: Vector(), time: 1)
        drag.record(pointer: Vector(10, 0), actual: Vector(10, 0), time: 1)
        XCTAssertEqual(drag.releaseVelocity(at: 1), Vector())
        drag.record(pointer: Vector(1e6, 0), actual: Vector(1e6, 0), time: 1.01)
        XCTAssertLessThanOrEqual(drag.releaseVelocity(at: 1.01).length, 1800.001)
        XCTAssertEqual(drag.releaseVelocity(at: 1.2), Vector())
        XCTAssertEqual(drag.releaseVelocity(at: .nan), Vector())
    }
}
