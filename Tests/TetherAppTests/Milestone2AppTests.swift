import XCTest
import AppKit
@testable import TetherApp
import TetherCore

final class Milestone2AppTests: XCTestCase {
    @MainActor
    private func fixture(_ label: String) -> (PreferencesStore, DisplayManager, UserDefaults, String) {
        _ = NSApplication.shared
        let suite = "Tether.m2." + label + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        return (PreferencesStore(defaults: defaults), DisplayManager(), defaults, suite)
    }
    @MainActor
    func testMultipleSessionsShareOneDisplayPanelAndPreserveVelocity() async throws {
        let (store, displays, defaults, suite) = fixture("multiple")
        defer { defaults.removePersistentDomain(forName: suite); displays.stop() }
        guard !displays.displays.isEmpty else { throw XCTSkip("Requires WindowServer") }
        store.perform { prefs in _ = try prefs.add(templateID: "cloud"); _ = try prefs.add(templateID: "jelly") }
        let overlay = OverlayManager(store: store, displays: displays)
        overlay.start(); defer { overlay.stop() }
        XCTAssertEqual(overlay.activeSessionCount, 3)
        XCTAssertEqual(overlay.panelCount, 1)
        let first = try XCTUnwrap(overlay.sessions["sprout"])
        let second = try XCTUnwrap(overlay.sessions["cloud"])
        overlay.play(id: first.charm.id)
        let velocity = first.engine.velocity
        XCTAssertGreaterThan(velocity.length, 0)
        XCTAssertEqual(second.engine.velocity, Vector())
        let panel = overlay.panel
        store.value.selectedID = "sprout"
        store.editCharm { $0.opacity = 0.6; $0.ropeColor = RGBA(1, 0, 0); $0.ropeWidth = 6 }
        overlay.reconcile()
        XCTAssertEqual(first.engine.velocity, velocity)
        XCTAssertTrue(panel === overlay.panel)
        XCTAssertEqual(second.charm.opacity, 1)
        try await Task.sleep(for: .milliseconds(80))
        XCTAssertGreaterThan(first.engine.velocity.length, 0)
        XCTAssertEqual(second.engine.position.x, second.engine.anchor.x, accuracy: 0.001)
        XCTAssertEqual(overlay.panelCount, 1)
    }
    @MainActor
    func testRemovalReleasesLayersAndSessionWithoutReplacingOtherPanel() throws {
        let (store, displays, defaults, suite) = fixture("remove")
        defer { defaults.removePersistentDomain(forName: suite); displays.stop() }
        guard !displays.displays.isEmpty else { throw XCTSkip("Requires WindowServer") }
        store.perform { _ = try $0.add(templateID: "moon") }
        let id = store.value.selectedID
        let overlay = OverlayManager(store: store, displays: displays)
        overlay.start(); defer { overlay.stop() }
        weak var renderer = overlay.sessions[id]?.renderer
        let panel = overlay.panel
        store.removeFromDesktop(id); overlay.reconcile()
        XCTAssertNil(renderer)
        XCTAssertEqual(overlay.activeSessionCount, 1)
        XCTAssertTrue(panel === overlay.panel)
        weak var session = overlay.sessions[id]
        store.perform { $0.deleteInstance(id) }; overlay.reconcile()
        XCTAssertNil(session)
        store.removeFromDesktop("sprout"); overlay.reconcile()
        XCTAssertEqual(overlay.panelCount, 0)
        XCTAssertFalse(overlay.isSimulating); XCTAssertFalse(overlay.isSamplingPointer)
    }
    @MainActor
    func testArrangementPersistenceAndMigrationBackup() throws {
        let (store, displays, defaults, suite) = fixture("persist")
        defer { defaults.removePersistentDomain(forName: suite); displays.stop() }
        store.perform { prefs in _ = try prefs.add(templateID: "moon"); _ = try prefs.duplicate(prefs.selectedID) }
        store.editCharm { $0.displayID = "saved-external"; $0.ropeWidth = 7; $0.gravity = 600; $0.attachmentY = 0.3 }
        let restored = PreferencesStore(defaults: defaults)
        XCTAssertEqual(restored.value, store.value)
        let legacy = Data("{\"schemaVersion\":1}".utf8)
        defaults.set(legacy, forKey: PreferencesStore.key)
        let migrated = PreferencesStore(defaults: defaults)
        XCTAssertEqual(migrated.value.schemaVersion, 2)
        XCTAssertEqual(defaults.data(forKey: PreferencesStore.key + ".migrationBackup"), legacy)
    }
    @MainActor
    func testMissingDisplayFallsBackWithoutOverwritingSavedID() throws {
        let (store, displays, defaults, suite) = fixture("fallback")
        defer { defaults.removePersistentDomain(forName: suite); displays.stop() }
        guard let primary = displays.displays.first else { throw XCTSkip("Requires WindowServer") }
        store.editCharm { $0.displayID = "disconnected-uuid"; $0.anchorX = 0.2 }
        let overlay = OverlayManager(store: store, displays: displays)
        overlay.start(); defer { overlay.stop() }
        XCTAssertEqual(overlay.sessions["sprout"]?.resolvedDisplayID, primary.id)
        XCTAssertEqual(store.value.selected.displayID, "disconnected-uuid")
        XCTAssertEqual(store.value.selected.anchorX, 0.2)
    }
    @MainActor
    func testRopeLengthEasesAndDoesNotResetVelocity() async throws {
        let (store, displays, defaults, suite) = fixture("rope")
        defer { defaults.removePersistentDomain(forName: suite); displays.stop() }
        guard !displays.displays.isEmpty else { throw XCTSkip("Requires WindowServer") }
        let overlay = OverlayManager(store: store, displays: displays)
        overlay.start(); defer { overlay.stop() }
        overlay.play()
        let old = overlay.engine
        store.editCharm { $0.ropeLength = 450 }; overlay.reconcile()
        XCTAssertEqual(overlay.engine.position, old.position)
        XCTAssertEqual(overlay.engine.velocity, old.velocity)
        XCTAssertEqual(overlay.engine.length, old.length)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertGreaterThan(overlay.engine.length, old.length)
        XCTAssertLessThan(overlay.engine.length, 450)
        XCTAssertTrue(overlay.engine.position.x.isFinite)
    }
    @MainActor
    func testImportedAssetsCacheRejectCorruptionAndDeleteAllReferences() throws {
        let (store, displays, defaults, suite) = fixture("assets")
        defer { defaults.removePersistentDomain(forName: suite); displays.stop() }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 24, pixelsHigh: 24, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        let data = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let input = folder.appendingPathComponent("pretend.webp")
        try data.write(to: input)
        // Decoded content, rather than extension, determines the type.
        let a = try AssetImporter.importImage(input, into: folder)
        let b = try AssetImporter.importImage(input, into: folder)
        XCTAssertNotEqual(a.assetFilename, b.assetFilename)
        let cache = AssetCache()
        XCTAssertNotNil(cache.image(a.assetFilename, folder: folder))
        XCTAssertNotNil(cache.image(a.assetFilename, folder: folder))
        XCTAssertEqual(cache.decodeCount, 1)
        XCTAssertNil(cache.image("../../escape.png", folder: folder))
        let broken = folder.appendingPathComponent("broken.png")
        try Data([137,80,78,71,13,10,26,10]).write(to: broken)
        XCTAssertThrowsError(try AssetImporter.validate(broken))
        XCTAssertNil(cache.image("broken.png", folder: folder))
        store.perform { prefs in prefs.library.append(a); _ = try prefs.add(templateID: a.id); _ = try prefs.duplicate(prefs.selectedID) }
        try AssetImporter.deleteArtwork(a.id, from: store, folder: folder)
        XCTAssertFalse(store.value.charms.contains { $0.sourceID == a.id })
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent(a.assetFilename!).path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent(b.assetFilename!).path))
    }
    @MainActor
    func testMenuLibraryAndSettingsReuseWindows() async throws {
        let (store, displays, defaults, suite) = fixture("windows")
        defer { defaults.removePersistentDomain(forName: suite); displays.stop() }
        guard !displays.displays.isEmpty else { throw XCTSkip("Requires WindowServer") }
        let settings = SettingsController(store: store, displays: displays)
        let controller = MenuBarController(store: store, settings: settings)
        defer { controller.stop() }
        let menu = NSMenu()
        controller.menuNeedsUpdate(menu)
        let index = menu.indexOfItem(withTitle: "Character Library…")
        XCTAssertGreaterThanOrEqual(index, 0)
        menu.performActionForItem(at: index)
        let firstLibrary = try XCTUnwrap(settings.library.window)
        menu.performActionForItem(at: index)
        XCTAssertTrue(firstLibrary === settings.library.window)
        settings.show(); let firstSettings = try XCTUnwrap(settings.window)
        settings.show(); XCTAssertTrue(firstSettings === settings.window)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertNotNil(firstLibrary.contentView)
        XCTAssertTrue(firstLibrary.isVisible)
        XCTAssertTrue(firstSettings.isVisible)
        firstLibrary.close(); firstSettings.close()
    }
    @MainActor
    func testAllSessionsPauseHideAndTeardown() async throws {
        let (store, displays, defaults, suite) = fixture("cleanup")
        defer { defaults.removePersistentDomain(forName: suite); displays.stop() }
        guard !displays.displays.isEmpty else { throw XCTSkip("Requires WindowServer") }
        store.perform { prefs in for id in ["moon", "jelly", "cloud", "comet"] { _ = try prefs.add(templateID: id) } }
        let overlay = OverlayManager(store: store, displays: displays)
        overlay.start()
        XCTAssertEqual(overlay.activeSessionCount, 5)
        for id in store.value.activeIDs { overlay.play(id: id) }
        store.value.paused = true; overlay.reconcile()
        XCTAssertFalse(overlay.isSimulating)
        let renders = overlay.renderCount
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(renders, overlay.renderCount)
        store.value.visible = false; overlay.reconcile()
        XCTAssertFalse(overlay.isSamplingPointer)
        weak var panel: PetPanel?
        weak var session: CharmSession?
        autoreleasepool {
            panel = overlay.panel; session = overlay.sessions["sprout"]
            overlay.stop()
        }
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertFalse(panel?.isVisible ?? false)
        XCTAssertNil(session); XCTAssertEqual(overlay.panelCount, 0)
    }
    @MainActor
    func testNativeWebPDecodeAndNormalization() throws {
        guard AssetImporter.supportsWebP else { throw XCTSkip("Native ImageIO WebP decoding unavailable") }
        // Original 1×1 semi-transparent teal pixel, losslessly encoded as WebP.
        let data = try XCTUnwrap(Data(base64Encoded: "UklGRh4AAABXRUJQVlA4TBEAAAAvAAAAEAdQ4AIVtICBiOh/AAA="))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("pixel.webp")
        try data.write(to: url)
        let normalized = try AssetImporter.validate(url)
        XCTAssertEqual(normalized.prefix(8), Data([137,80,78,71,13,10,26,10]))
        let charm = try AssetImporter.importImage(url, into: folder)
        XCTAssertEqual(URL(fileURLWithPath: charm.assetFilename ?? "").pathExtension, "png")
        XCTAssertNotNil(AssetCache().image(charm.assetFilename, folder: folder))
    }

}
