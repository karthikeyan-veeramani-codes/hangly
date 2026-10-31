import XCTest
import AppKit
import TetherCore
@testable import TetherApp

@MainActor
private final class FullscreenProbe: NSObject, NSWindowDelegate {
    var entered = false
    var exited = false
    func windowDidEnterFullScreen(_ notification: Notification) { entered = true }
    func windowDidExitFullScreen(_ notification: Notification) { exited = true }
}
final class DesktopIntegrationTests: XCTestCase {
    @MainActor
    func testOwnedFullscreenAndApplicationHideShow() async throws {
        _ = NSApplication.shared
        let suite = "Tether.m21.desktop." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults), displays = DisplayManager()
        defer { displays.stop() }
        guard let display = displays.displays.first else { throw XCTSkip("Requires WindowServer") }
        let overlay = OverlayManager(store: store, displays: displays); overlay.start(); defer { overlay.stop() }
        let window = NSWindow(contentRect: NSRect(x: display.screen.visibleFrame.midX - 200, y: display.screen.visibleFrame.midY - 150, width: 400, height: 300), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.title = "Tether — temporary desktop verification"
        window.collectionBehavior = [.fullScreenPrimary]
        let probe = FullscreenProbe(); window.delegate = probe
        defer { window.close() }
        NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
        window.toggleFullScreen(nil)
        for _ in 0..<100 where !probe.entered { try await Task.sleep(for: .milliseconds(80)) }
        let entered = probe.entered
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        let onScreen = windows.contains { ($0[kCGWindowNumber as String] as? Int) == overlay.panel?.windowNumber }
        if window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
        for _ in 0..<100 where entered && !probe.exited { try await Task.sleep(for: .milliseconds(80)) }
        let exited = !window.styleMask.contains(.fullScreen)
        NSApp.hide(nil); try await Task.sleep(for: .milliseconds(150))
        let hideStopsTimers = !overlay.isSamplingPointer && !overlay.isSimulating
        NSApp.unhide(nil); try await Task.sleep(for: .milliseconds(150))
        let showRestoresPointer = overlay.isSamplingPointer
        let evidence: [String: Any] = ["ownedReferenceEnteredFullscreen": entered, "ownedReferenceExitedFullscreen": exited,
            "overlayWindowServerOnScreenDuringFullscreen": onScreen, "appHideStoppedTimers": hideStopsTimers,
            "appUnhideRestoredPointer": showRestoresPointer, "screens": displays.displays.count,
            "scope": "Actual owned NSWindow fullscreen and WindowServer metadata, not visual verification of third-party fullscreen or Mission Control."]
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appendingPathComponent("docs/test-evidence/milestone-2.1")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: evidence, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("desktop-integration.json"))
        XCTAssertTrue(entered, "Native reference window did not enter fullscreen")
        XCTAssertTrue(exited, "Native reference window did not exit fullscreen")
        XCTAssertTrue(hideStopsTimers); XCTAssertTrue(showRestoresPointer)
    }
}
