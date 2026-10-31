import XCTest
@testable import TetherCore

final class Milestone2Tests: XCTestCase {
    func testFiveOriginalLibraryCharactersAndIndependentInstances() throws {
        var p = Preferences()
        XCTAssertEqual(p.library.count, 5)
        let cloud = try p.add(templateID: "cloud")
        let copy = try p.duplicate(cloud)
        XCTAssertNotEqual(cloud, copy)
        XCTAssertEqual(p.activeIDs.count, 3)
        let index = try XCTUnwrap(p.charms.firstIndex { $0.id == copy })
        p.charms[index].size = 150
        XCTAssertEqual(p.charms.first { $0.id == cloud }?.size, 88)
        p.removeFromDesktop(cloud)
        XCTAssertFalse(p.activeIDs.contains(cloud))
        XCTAssertTrue(p.activeIDs.contains(copy))
        let restored = try Preferences.decode(JSONEncoder().encode(p))
        XCTAssertEqual(restored, p)
    }
    func testLimitAndSafeDeletion() throws {
        var p = Preferences(); p.maxActive = 2
        _ = try p.add(templateID: "moon")
        XCTAssertThrowsError(try p.add(templateID: "jelly"))
        XCTAssertThrowsError(try p.duplicate("sprout"))
        XCTAssertThrowsError(try p.deleteArtwork("sprout"))
        p.activeIDs = []; p.charms = []; p.sanitize()
        XCTAssertTrue(p.activeIDs.isEmpty)
        XCTAssertEqual(p.charms.count, 3)
        p.maxActive = Int.max; p.sanitize()
        XCTAssertEqual(p.maxActive, 12)
        p.maxActive = 1; p.activeIDs = ["sprout"]
        while p.charms.count < 64 {
            p.maxActive = 12
            let id = try p.duplicate("sprout")
            p.removeFromDesktop(id)
        }
        XCTAssertThrowsError(try p.duplicate("sprout"))
    }
    func testDeleteCustomArtworkRemovesAllItsInstances() throws {
        var p = Preferences()
        let template = Charm(id: "art", name: "My Art", kind: .custom, assetFilename: "owned.png")
        p.library.append(template)
        let first = try p.add(templateID: "art")
        _ = try p.duplicate(first)
        try p.deleteArtwork("art")
        XCTAssertFalse(p.charms.contains { $0.sourceID == "art" })
        XCTAssertFalse(p.library.contains { $0.id == "art" })
        XCTAssertEqual(p.activeIDs, ["sprout"])
    }
    func testVersionOneMigrationPreservesArrangementAndArtwork() throws {
        let json = """
        {"schemaVersion":1,"charms":[{"id":"my-art","name":"Art","kind":"custom","assetFilename":"owned.png","size":126,"ropeLength":300,"anchorX":0.33,"displayID":"external"}],"selectedID":"my-art","visible":false,"paused":true,"wind":false,"damping":1.7,"respectReduceMotion":true}
        """
        let p = try Preferences.decode(Data(json.utf8))
        XCTAssertEqual(p.schemaVersion, 2)
        XCTAssertEqual(p.activeIDs, ["my-art"])
        XCTAssertEqual(p.selected.size, 126)
        XCTAssertEqual(p.selected.displayID, "external")
        XCTAssertEqual(p.selected.damping, 1.7)
        XCTAssertEqual(p.library.count, 6)
        XCTAssertFalse(p.showOnStartup)
    }
    func testStartupPolicyAndRestoreBuiltins() {
        var p = Preferences(); p.restoreSession = false; p.selectedID = "cloud"; p.showOnStartup = false
        p.applyStartupPolicy()
        XCTAssertEqual(p.activeIDs, ["cloud"]); XCTAssertFalse(p.visible)
        p.library.removeAll(); p.restoreBuiltins()
        XCTAssertEqual(p.library.count, 5)
    }
    func testRopeAndAppearanceSanitization() {
        var c = Charm(id: "test", name: "  ", kind: .jelly)
        c.gravity = .nan; c.damping = .infinity; c.ropeWidth = -4; c.opacity = .nan
        c.attachmentX = 20; c.ropeColor.red = .infinity
        c.sanitize()
        XCTAssertEqual(c.gravity, 1100); XCTAssertEqual(c.damping, 0.9)
        XCTAssertEqual(c.ropeWidth, 1); XCTAssertEqual(c.opacity, 1)
        XCTAssertEqual(c.attachmentX, 1); XCTAssertEqual(c.ropeColor.red, 0.57)
    }
    func testAnimationTransitionsAndReduceMotion() {
        var a = CharacterAnimation()
        a.update(dt: 1, moving: true, dragging: false, paused: false, sleepAfter: 15, reducedMotion: false)
        XCTAssertEqual(a.phase, .swinging)
        a.update(dt: 0.1, moving: true, dragging: true, paused: false, sleepAfter: 15, reducedMotion: false)
        XCTAssertEqual(a.phase, .dragging)
        a.interact(reaction: true, reducedMotion: false)
        a.update(dt: 0, moving: false, dragging: false, paused: false, sleepAfter: 15, reducedMotion: false)
        XCTAssertEqual(a.phase, .reacting)
        a.update(dt: 0.12, moving: false, dragging: false, paused: false, sleepAfter: 15, reducedMotion: false)
        let scaleBeforePause = a.reactionScale
        a.update(dt: 0.3, moving: false, dragging: false, paused: true, sleepAfter: 15, reducedMotion: false)
        XCTAssertEqual(a.reactionScale, scaleBeforePause)
        a.update(dt: 0, moving: false, dragging: false, paused: true, sleepAfter: 15, reducedMotion: false)
        XCTAssertEqual(a.phase, .paused)
        for _ in 0..<20 { a.update(dt: 1, moving: false, dragging: false, paused: false, sleepAfter: 15, reducedMotion: false) }
        XCTAssertEqual(a.phase, .sleeping)
        a.interact(reaction: true, reducedMotion: false)
        a.update(dt: 0, moving: false, dragging: false, paused: false, sleepAfter: 15, reducedMotion: false)
        XCTAssertEqual(a.phase, .waking)
        a.update(dt: 0.1, moving: false, dragging: false, paused: false, sleepAfter: 15, reducedMotion: true)
        XCTAssertFalse(a.needsFrames); XCTAssertEqual(a.reactionScale, 1)
    }
}
