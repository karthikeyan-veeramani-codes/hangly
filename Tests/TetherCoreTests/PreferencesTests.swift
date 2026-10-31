import XCTest
@testable import TetherCore

final class PreferencesTests: XCTestCase {
    func testRoundTripAndIndependentCharacters() throws {
        var prefs = Preferences()
        prefs.charms[0].size = 140; prefs.charms[1].ropeLength = 400; prefs.selectedID = "cloud"
        let restored = try Preferences.decode(JSONEncoder().encode(prefs))
        XCTAssertEqual(prefs, restored)
        XCTAssertEqual(restored.selected.size, 88)
        XCTAssertEqual(restored.charms[0].size, 140)
    }
    func testInvalidValuesAndPathsAreRepaired() {
        var prefs = Preferences()
        prefs.charms[0].size = .nan; prefs.charms[0].anchorX = 99
        prefs.charms[0].assetFilename = "../../secret.png"
        prefs.charms.append(prefs.charms[0]); prefs.selectedID = "missing"; prefs.damping = -5
        prefs.sanitize()
        XCTAssertEqual(prefs.charms.count, 3)
        XCTAssertEqual(prefs.selected.size, 88)
        XCTAssertEqual(prefs.selected.anchorX, 0.95)
        XCTAssertNil(prefs.selected.assetFilename)
        XCTAssertEqual(prefs.damping, 0.2)
    }
    func testCorruptionAndFutureSchemaRejected() throws {
        XCTAssertThrowsError(try Preferences.decode(Data("broken".utf8)))
        var p = Preferences(); p.schemaVersion = 100
        XCTAssertThrowsError(try Preferences.decode(JSONEncoder().encode(p)))
    }
    func testMissingCharactersRecover() {
        var p = Preferences(); p.charms = []; p.sanitize()
        XCTAssertEqual(p.charms.count, 3)
    }
    func testDisplayDisconnectReconnectAndHeadless() {
        XCTAssertEqual(Geometry.displayID(saved: "external", available: ["main", "external"], primary: "main"), "external")
        XCTAssertEqual(Geometry.displayID(saved: "external", available: ["main"], primary: "main"), "main")
        XCTAssertEqual(Geometry.displayID(saved: "external", available: ["main", "external"], primary: "main"), "external")
        XCTAssertNil(Geometry.displayID(saved: "external", available: [], primary: nil))
    }
}
