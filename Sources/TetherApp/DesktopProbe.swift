import AppKit
import ApplicationServices
import ScreenCaptureKit
import TetherCore

@MainActor
private final class ClickProbeView: NSView {
    var clicks = 0
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { clicks += 1 }
}
@MainActor
enum DesktopProbe {
    static func captureOwnWindows(_ windows: [(String, NSWindow?)], in folder: URL) async throws {
        guard CGPreflightScreenCaptureAccess() else { return }
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        for (name, window) in windows {
            guard let window, let source = content.windows.first(where: { $0.windowID == CGWindowID(window.windowNumber) && $0.owningApplication?.processID == ProcessInfo.processInfo.processIdentifier }) else { continue }
            let config = SCStreamConfiguration()
            config.width = Int(window.frame.width * (window.backingScaleFactor)); config.height = Int(window.frame.height * window.backingScaleFactor)
            config.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: source), configuration: config)
            let bitmap = NSBitmapImageRep(cgImage: image)
            let appearance = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua ? "light" : "dark"
            try bitmap.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent(name + "-" + appearance + "-composited.png"))
        }
    }
    static func run(overlay: OverlayManager, settings: SettingsController, folder: URL) async throws {
        guard let session = overlay.sessions["sprout"], let renderer = session.renderer, let panel = overlay.panel else { return }
        let originalPointer = NSEvent.mouseLocation
        let originalApplication = NSWorkspace.shared.frontmostApplication
        let view = ClickProbeView(frame: CGRect(x: 0, y: 0, width: 500, height: 500))
        let window = NSWindow(contentRect: CGRect(x: session.screenFrame.minX + renderer.bodyCenter.x - 250, y: session.screenFrame.minY + renderer.bodyCenter.y - 250, width: 500, height: 500), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Tether — temporary click-through check"; window.isReleasedWhenClosed = false; window.backgroundColor = .windowBackgroundColor; window.contentView = view
        NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil)
        defer { window.close(); move(originalPointer); _ = originalApplication?.activate(options: []) }
        try await Task.sleep(for: .milliseconds(400))
        let frame = renderer.artworkFrame.offsetBy(dx: session.screenFrame.minX, dy: session.screenFrame.minY)
        let body = CGPoint(x: session.screenFrame.minX + renderer.bodyCenter.x, y: session.screenFrame.minY + renderer.bodyCenter.y)
        let corner = CGPoint(x: frame.minX + 1, y: frame.minY + 1)
        let outside = CGPoint(x: frame.maxX + 25, y: body.y)
        let native = CommandLine.arguments.contains("--native-transparency")
        let previous = panel.ignoresMouseEvents
        if native { overlay.setNativeInputProbe(true); try await Task.sleep(for: .milliseconds(200)) }
        panel.ignoresMouseEvents = false
        let bodyTarget = NSWindow.windowNumber(at: body, belowWindowWithWindowNumber: 0)
        let cornerTarget = NSWindow.windowNumber(at: corner, belowWindowWithWindowNumber: 0)
        let outsideTarget = NSWindow.windowNumber(at: outside, belowWindowWithWindowNumber: 0)
        if !native { panel.ignoresMouseEvents = previous }
        var counts: [String: Int] = [:]
        if AXIsProcessTrusted() {
            for (name, point) in [("outside", outside), ("transparentCorner", corner), ("body", body)] {
                move(point); try await Task.sleep(for: .milliseconds(120)); click(point)
                try await Task.sleep(for: .milliseconds(150)); counts[name] = view.clicks
            }
            move(body); try await Task.sleep(for: .milliseconds(120)); move(outside); click(outside)
            try await Task.sleep(for: .milliseconds(150)); counts["rapidBodyToOutside"] = view.clicks
            let beforeRapid = view.clicks
            for _ in 0..<20 {
                move(body); try await Task.sleep(for: .milliseconds(80)); move(outside); click(outside)
                try await Task.sleep(for: .milliseconds(80))
            }
            counts["rapid20Delivered"] = view.clicks - beforeRapid
        }
        if native { overlay.setNativeInputProbe(false) }
        var dragResult: [String: Any] = [:]
        if !native && AXIsProcessTrusted() {
            session.engine = RopePhysics(anchor: session.engine.anchor, length: session.engine.length)
            overlay.store.value.paused = false; overlay.reconcile()
            try await Task.sleep(for: .seconds(1))
            let start = CGPoint(x: session.screenFrame.minX + renderer.bodyCenter.x, y: session.screenFrame.minY + renderer.bodyCenter.y)
            let before = session.engine.position, underlayBefore = view.clicks
            move(start); try await Task.sleep(for: .milliseconds(120))
            CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: quartz(start), mouseButton: .left)?.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(80))
            dragResult["capturedAfterMouseDown"] = overlay.dragging
            for step in 1...6 {
                let point = CGPoint(x: start.x + Double(step) * 7, y: start.y + Double(step) * 4)
                CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: quartz(point), mouseButton: .left)?.post(tap: .cghidEventTap)
                try await Task.sleep(for: .milliseconds(20))
            }
            let end = CGPoint(x: start.x + 42, y: start.y + 24)
            CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: quartz(end), mouseButton: .left)?.post(tap: .cghidEventTap)
            try await Task.sleep(for: .milliseconds(100))
            dragResult["releasedWithoutStuckCapture"] = !overlay.dragging
            dragResult["bobDisplacement"] = (session.engine.position - before).length
            dragResult["releaseSpeed"] = session.engine.velocity.length
            dragResult["underlayReceivedDragDown"] = view.clicks != underlayBefore
            dragResult["finitePosition"] = session.engine.position.x.isFinite && session.engine.position.y.isFinite
            overlay.store.value.paused = true; overlay.reconcile()
        }
        if CommandLine.arguments.contains("--workspace-check") {
            let workspace = try await workspaceCheck(window: window)
            try JSONSerialization.data(withJSONObject: workspace, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("workspace-integration.json"))
        }
        settings.library.show(); settings.show(section: .characters)
        try await Task.sleep(for: .milliseconds(300))
        try await captureOwnWindows([("gallery", settings.library.window), ("settings", settings.window), ("desktop", panel)], in: folder)
        let result: [String: Any] = ["nativeMode": native, "bodyTarget": bodyTarget, "panelNumber": panel.windowNumber, "underlayNumber": window.windowNumber, "nativeBodyHitsOverlay": bodyTarget == panel.windowNumber,
            "nativeTransparentCornerHitsUnderlay": cornerTarget == window.windowNumber, "nativeOutsideHitsUnderlay": outsideTarget == window.windowNumber,
            "actualUnderlayClickCounts": counts, "generatedDrag": dragResult, "accessibilityTrusted": AXIsProcessTrusted(), "screenCaptureAllowed": CGPreflightScreenCaptureAccess(),
            "scope": "Native WindowServer hit queries with interception enabled; actual generated clicks only inside an owned underlay window. Pointer/focus restored. No other app content captured."]
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent(native ? "native-transparency.json" : "input-routing.json"))
    }
    private static func quartz(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x, y: (NSScreen.screens.first?.frame.maxY ?? 0) - point.y) }
    private static func move(_ point: CGPoint) { CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: quartz(point), mouseButton: .left)?.post(tap: .cghidEventTap) }
    private static func click(_ point: CGPoint) {
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: quartz(point), mouseButton: .left)?.post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: quartz(point), mouseButton: .left)?.post(tap: .cghidEventTap)
    }
}

@MainActor
private final class WorkspaceProbeState: NSObject, NSWindowDelegate {
    var entered = false
    var exited = false
    var changes = 0
    func windowDidEnterFullScreen(_ notification: Notification) { entered = true }
    func windowDidExitFullScreen(_ notification: Notification) { exited = true }
}
extension DesktopProbe {
    static func workspaceCheck(window: NSWindow) async throws -> [String: Any] {
        guard AXIsProcessTrusted() else { return ["status": "BLOCKED", "reason": "Existing Accessibility access unavailable; no prompt requested"] }
        let state = WorkspaceProbeState()
        window.styleMask.insert(.resizable); window.collectionBehavior = [.fullScreenPrimary]; window.delegate = state
        let observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in MainActor.assumeIsolated { state.changes += 1 } }
        defer { NSWorkspace.shared.notificationCenter.removeObserver(observer); window.delegate = nil }
        window.makeKeyAndOrderFront(nil); window.toggleFullScreen(nil)
        for _ in 0..<100 where !state.entered { try await Task.sleep(for: .milliseconds(80)) }
        var result: [String: Any] = ["enteredOwnedFullscreen": state.entered]
        if state.entered {
            result["fullscreenAutoHidesMenuBar"] = NSApp.presentationOptions.contains(.autoHideMenuBar)
            key(123, flags: .maskControl); try await Task.sleep(for: .seconds(1))
            let leftOwnedSpace = !window.isOnActiveSpace
            result["controlLeftLeftOwnedSpace"] = leftOwnedSpace
            if leftOwnedSpace { key(124, flags: .maskControl); try await Task.sleep(for: .seconds(1)) }
            result["controlRightReturnedToOwnedSpace"] = window.isOnActiveSpace
            let before = missionIdentifiers()
            let missionURL = URL(fileURLWithPath: "/System/Applications/Mission Control.app")
            var launched = false
            if FileManager.default.fileExists(atPath: missionURL.path) {
                do { _ = try await NSWorkspace.shared.openApplication(at: missionURL, configuration: NSWorkspace.OpenConfiguration()); launched = true }
                catch { result["missionControlLaunchError"] = error.localizedDescription }
            } else { key(126, flags: .maskControl) }
            result["missionControlApplicationLaunched"] = launched
            try await Task.sleep(for: .seconds(1))
            let during = missionIdentifiers()
            result["missionControlIdentifiersBefore"] = before
            result["missionControlIdentifiersDuring"] = during
            result["missionControlObservedThroughAccessibility"] = !during.isEmpty && during != before
            key(53); try await Task.sleep(for: .seconds(1))
            result["missionControlIdentifiersAfterEscape"] = missionIdentifiers()
            if window.styleMask.contains(.fullScreen) { window.toggleFullScreen(nil) }
            for _ in 0..<100 where !state.exited && window.styleMask.contains(.fullScreen) { try await Task.sleep(for: .milliseconds(80)) }
        }
        result["activeSpaceNotifications"] = state.changes
        result["exitedOwnedFullscreen"] = !window.styleMask.contains(.fullScreen)
        result["scope"] = "Actual controlled keyboard commands and owned fullscreen Space; no Stage Manager or preference changes. Only Dock Mission-Control identifiers retained, no other app titles/content."
        return result
    }
    private static func key(_ code: CGKeyCode, flags: CGEventFlags = []) {
        if flags.contains(.maskControl) { CGEvent(keyboardEventSource: nil, virtualKey: 59, keyDown: true)?.post(tap: .cghidEventTap) }
        for down in [true, false] { let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down); event?.flags = flags; event?.post(tap: .cghidEventTap) }
        if flags.contains(.maskControl) { CGEvent(keyboardEventSource: nil, virtualKey: 59, keyDown: false)?.post(tap: .cghidEventTap) }
    }
    private static func missionIdentifiers() -> [String] {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return [] }
        var found = Set<String>()
        func walk(_ node: AXUIElement, _ depth: Int) {
            guard depth < 6 else { return }
            for key in [kAXIdentifierAttribute, kAXRoleAttribute, kAXSubroleAttribute] {
                var value: CFTypeRef?
                if AXUIElementCopyAttributeValue(node, key as CFString, &value) == .success, let text = value as? String, text.localizedCaseInsensitiveContains("mission") || text.localizedCaseInsensitiveContains("expose") { found.insert(text) }
            }
            var children: CFTypeRef?
            if AXUIElementCopyAttributeValue(node, kAXChildrenAttribute as CFString, &children) == .success, let array = children as? [AXUIElement] { for child in array { walk(child, depth + 1) } }
        }
        walk(AXUIElementCreateApplication(dock.processIdentifier), 0)
        return found.sorted()
    }
}
