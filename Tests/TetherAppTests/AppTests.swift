import XCTest
import AppKit
@testable import TetherApp
import TetherCore

final class AppTests: XCTestCase {
    func testPersistenceAndCorruptRecovery() async throws {
        await MainActor.run {
            let suite = "Tether.tests." + UUID().uuidString
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = PreferencesStore(defaults: defaults)
            store.editCharm { $0.size = 130 }; store.value.paused = true
            let restored = PreferencesStore(defaults: defaults)
            XCTAssertEqual(restored.value.selected.size, 130)
            XCTAssertTrue(restored.value.paused)
            defaults.set(Data("invalid".utf8), forKey: PreferencesStore.key)
            XCTAssertNotNil(PreferencesStore(defaults: defaults).notice)
        }
    }
    func testPNGImportCopiesAndRejectsInvalidData() async throws {
        try await MainActor.run {
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: folder) }
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 32, pixelsHigh: 32, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            let input = folder.appendingPathComponent("original.png")
            try bitmap.representation(using: .png, properties: [:])!.write(to: input)
            let output = folder.appendingPathComponent("copied")
            let charm = try AssetImporter.importImage(input, into: output)
            XCTAssertEqual(charm.kind, .custom)
            XCTAssertTrue(FileManager.default.fileExists(atPath: output.appendingPathComponent(charm.assetFilename!).path))
            try Data("not png".utf8).write(to: input)
            XCTAssertThrowsError(try AssetImporter.validate(input))
            let oversized = folder.appendingPathComponent("oversized.png")
            try Data(repeating: 0, count: 20 * 1024 * 1024 + 1).write(to: oversized)
            XCTAssertThrowsError(try AssetImporter.validate(oversized))
        }
    }
    func testOverlayLifecycleRebuildAndTeardown() async {
        await MainActor.run {
            _ = NSApplication.shared
            let suite = "Tether.lifecycle." + UUID().uuidString
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = PreferencesStore(defaults: defaults); store.value.visible = false
            let displays = DisplayManager()
            let overlay = OverlayManager(store: store, displays: displays)
            overlay.start()
            if !displays.displays.isEmpty {
                XCTAssertNotNil(overlay.panel)
                let first = overlay.panel
                overlay.rebuild(); XCTAssertFalse(first === overlay.panel)
            }
            overlay.stop(); overlay.stop(); XCTAssertNil(overlay.panel)
        }
    }
    func testOverlayOwnerReleases() async {
        await MainActor.run {
            let suite = "Tether.release." + UUID().uuidString
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }
            let store = PreferencesStore(defaults: defaults); store.value.visible = false
            let display = DisplayManager()
            weak var weakOverlay: OverlayManager?
            autoreleasepool {
                let overlay = OverlayManager(store: store, displays: display)
                weakOverlay = overlay; overlay.start(); overlay.stop()
            }
            XCTAssertNil(weakOverlay)
        }
    }
    @MainActor
    func testPauseResumeHideStopsTimersAndRendering() async throws {
        _ = NSApplication.shared
        let suite = "Tether.scheduling." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults)
        let displays = DisplayManager()
        guard !displays.displays.isEmpty else { throw XCTSkip("Requires a WindowServer display") }
        let overlay = OverlayManager(store: store, displays: displays)
        overlay.start(); defer { overlay.stop() }
        XCTAssertTrue(overlay.isSimulating)
        XCTAssertTrue(overlay.isSamplingPointer)
        store.value.paused = true
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertFalse(overlay.isSimulating)
        let renders = overlay.renderCount
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertEqual(overlay.renderCount, renders)
        store.value.paused = false
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertTrue(overlay.isSimulating)
        store.value.visible = false
        try await Task.sleep(for: .milliseconds(40))
        XCTAssertFalse(overlay.isSimulating)
        XCTAssertFalse(overlay.isSamplingPointer)
        XCTAssertFalse(overlay.panel?.isVisible ?? true)
    }
    @MainActor
    func testSwitchingPreservesIndependentMotion() throws {
        let suite = "Tether.motion." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults); store.value.paused = true; store.value.visible = false
        let displays = DisplayManager()
        guard !displays.displays.isEmpty else { throw XCTSkip("Requires a WindowServer display") }
        let overlay = OverlayManager(store: store, displays: displays)
        overlay.start(); defer { overlay.stop() }
        overlay.play()
        let velocity = overlay.engine.velocity
        XCTAssertGreaterThan(velocity.length, 0)
        store.value.selectedID = "cloud"; overlay.rebuild()
        XCTAssertEqual(overlay.engine.velocity, Vector())
        store.value.selectedID = "sprout"; overlay.rebuild()
        XCTAssertEqual(overlay.engine.velocity, velocity)
    }

    @MainActor
    func testSettledOverlaySuspendsSimulation() async throws {
        _ = NSApplication.shared
        let suite = "Tether.rest." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults)
        let displays = DisplayManager()
        guard !displays.displays.isEmpty else { throw XCTSkip("Requires a WindowServer display") }
        let overlay = OverlayManager(store: store, displays: displays)
        overlay.start(); defer { overlay.stop() }
        try await Task.sleep(for: .seconds(1.2))
        XCTAssertTrue(overlay.engine.isResting)
        XCTAssertFalse(overlay.isSimulating)
        XCTAssertTrue(overlay.isSamplingPointer)
        let renders = overlay.renderCount
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertEqual(overlay.renderCount, renders)
    }

    @MainActor
    func testDisplaySleepNotificationsSuspendAndWake() throws {
        _ = NSApplication.shared
        let suite = "Tether.sleep." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults)
        let displays = DisplayManager()
        guard !displays.displays.isEmpty else { throw XCTSkip("Requires a WindowServer display") }
        let overlay = OverlayManager(store: store, displays: displays)
        overlay.start(); defer { overlay.stop() }
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        XCTAssertFalse(overlay.isSimulating)
        XCTAssertFalse(overlay.isSamplingPointer)
        XCTAssertFalse(overlay.panel?.isVisible ?? true)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
        XCTAssertTrue(overlay.isSamplingPointer)
        XCTAssertTrue(overlay.panel?.isVisible ?? false)
    }

    @MainActor
    func testSystemAndDisplaySleepRequireBothWakeNotifications() throws {
        _ = NSApplication.shared
        let suite = "Tether.combined-sleep." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let displays = DisplayManager()
        defer { displays.stop() }
        guard !displays.displays.isEmpty else { throw XCTSkip("Requires a WindowServer display") }
        let overlay = OverlayManager(store: PreferencesStore(defaults: defaults), displays: displays)
        overlay.start(); defer { overlay.stop() }
        let center = NSWorkspace.shared.notificationCenter
        center.post(name: NSWorkspace.willSleepNotification, object: nil)
        center.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
        center.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
        XCTAssertFalse(overlay.isSamplingPointer)
        XCTAssertFalse(overlay.panel?.isVisible ?? true)
        center.post(name: NSWorkspace.didWakeNotification, object: nil)
        XCTAssertTrue(overlay.isSamplingPointer)
        XCTAssertTrue(overlay.panel?.isVisible ?? false)
    }

}
