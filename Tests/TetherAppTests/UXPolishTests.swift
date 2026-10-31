import XCTest
import AppKit
import QuartzCore
import TetherCore
@testable import TetherApp

final class UXPolishTests: XCTestCase {
    @MainActor
    func testAttachmentStaysFixedAcrossSizeRotationAndReaction() {
        for original in Preferences.builtins {
            for size in [44.0, 88, 160] {
                var charm = original; charm.size = size
                let renderer = CharmRenderer(); renderer.configure(charm: charm, image: nil, scale: 2)
                var physics = RopePhysics(anchor: Vector(200, 5), length: 220)
                physics.drag(to: Vector(310, 170), velocity: Vector())
                var reaction = CharacterAnimation(); reaction.interact(reaction: true, reducedMotion: false)
                reaction.update(dt: 0.2, moving: true, dragging: false, paused: false, sleepAfter: 120, reducedMotion: false)
                renderer.render(engine: physics, height: 500, dragging: false, animation: reaction)
                let point = renderer.attachmentLocation()
                XCTAssertEqual(point.x, physics.position.x, accuracy: 0.001)
                XCTAssertEqual(point.y, 500 - physics.position.y, accuracy: 0.001)
                XCTAssertTrue(renderer.layerScales().allSatisfy { $0 == 2 })
                renderer.idleVariation(blink: false, reducedMotion: false)
                // Idle rotation now uses the same attachment anchorPoint as the model transform.
                XCTAssertEqual(renderer.attachmentLocation(), point)
            }
        }
    }
    @MainActor
    func testPreciseBuiltinAndImportedTransparencyHits() throws {
        let renderer = CharmRenderer()
        let charm = Preferences.builtins[0]
        let physics = RopePhysics(anchor: Vector(200, 0), length: 180)
        renderer.configure(charm: charm, image: nil, scale: 2); renderer.render(engine: physics, height: 500, dragging: false)
        let center = renderer.bodyCenter
        XCTAssertTrue(renderer.hitBody(center))
        XCTAssertFalse(renderer.hitBody(CGPoint(x: renderer.artworkFrame.minX + 1, y: renderer.artworkFrame.minY + 1)))
        let context = try XCTUnwrap(CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8, bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(NSColor.green.cgColor); context.fill(CGRect(x: 25, y: 25, width: 50, height: 50))
        let image = NSImage(cgImage: try XCTUnwrap(context.makeImage()), size: NSSize(width: 100, height: 100))
        renderer.configure(charm: Charm(id: "custom", name: "Alpha", kind: .custom), image: image, scale: 2)
        renderer.render(engine: physics, height: 500, dragging: false)
        XCTAssertTrue(renderer.hitBody(renderer.bodyCenter))
        XCTAssertFalse(renderer.hitBody(CGPoint(x: renderer.artworkFrame.minX + 4, y: renderer.bodyCenter.y)))
    }
    @MainActor
    func testPauseAndFocusCancelCapturedGesture() throws {
        _ = NSApplication.shared
        let suite = "Tether.m21.gestures." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults), displays = DisplayManager()
        defer { displays.stop() }
        guard !displays.displays.isEmpty else { throw XCTSkip("Requires WindowServer") }
        let overlay = OverlayManager(store: store, displays: displays); overlay.start(); defer { overlay.stop() }
        overlay.beginDrag(id: "sprout", pointer: overlay.engine.position, time: 1)
        XCTAssertTrue(overlay.dragging)
        XCTAssertFalse(overlay.isSimulating)
        store.value.paused = true; overlay.reconcile()
        XCTAssertFalse(overlay.dragging)
        store.value.paused = false; overlay.reconcile()
        overlay.beginDrag(id: "sprout", pointer: overlay.engine.position, time: 2)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didActivateApplicationNotification, object: nil)
        XCTAssertFalse(overlay.dragging)
        overlay.beginDrag(id: "sprout", pointer: overlay.engine.position, time: 3)
        NotificationCenter.default.post(name: NSApplication.didHideNotification, object: NSApp)
        XCTAssertFalse(overlay.dragging); XCTAssertFalse(overlay.isSamplingPointer)
        NotificationCenter.default.post(name: NSApplication.didUnhideNotification, object: NSApp)
        XCTAssertTrue(overlay.isSamplingPointer)
    }
    @MainActor
    func testOverlappingTargetsTransparentCornersAndReduceMotionPolicy() throws {
        _ = NSApplication.shared
        let suite = "Tether.m21.hits." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults), displays = DisplayManager()
        defer { displays.stop() }
        guard !displays.displays.isEmpty else { throw XCTSkip("Requires WindowServer") }
        store.duplicate("sprout")
        store.editCharm { $0.anchorX = 0.75 }
        let id = store.value.selectedID
        let overlay = OverlayManager(store: store, displays: displays, reduceMotionProvider: { true })
        overlay.start(); defer { overlay.stop() }
        let session = try XCTUnwrap(overlay.sessions[id]), renderer = try XCTUnwrap(session.renderer)
        let center = renderer.bodyCenter
        XCTAssertEqual(overlay.hitSession(at: CGPoint(x: center.x + session.screenFrame.minX, y: center.y + session.screenFrame.minY))?.charm.id, id)
        XCTAssertNil(overlay.hitSession(at: CGPoint(x: renderer.artworkFrame.minX + 1 + session.screenFrame.minX, y: renderer.artworkFrame.minY + 1 + session.screenFrame.minY)))
        overlay.play(id: id)
        XCTAssertLessThan(overlay.engine.velocity.length, 100)
        XCTAssertFalse(session.animation.needsFrames)
        store.editCharm { $0.windIntensity = 400 }; overlay.reconcile()
        XCTAssertEqual(overlay.engine.wind, 0)
        store.value.respectReduceMotion = false; overlay.reconcile()
        XCTAssertEqual(overlay.engine.wind, 400)
    }
    @MainActor
    func testKeyboardMenuActionAndNamedAccessibilityPress() throws {
        _ = NSApplication.shared
        let suite = "Tether.m21.accessibility." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults), displays = DisplayManager()
        defer { displays.stop() }
        guard !displays.displays.isEmpty else { throw XCTSkip("Requires WindowServer") }
        let overlay = OverlayManager(store: store, displays: displays); overlay.start(); defer { overlay.stop() }
        let settings = SettingsController(store: store, displays: displays)
        let controller = MenuBarController(store: store, settings: settings); controller.overlay = overlay
        defer { controller.stop(); settings.window?.close(); settings.library.window?.close() }
        let menu = NSMenu(); controller.menuNeedsUpdate(menu)
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command], timestamp: 1, windowNumber: 0, context: nil, characters: "l", charactersIgnoringModifiers: "l", isARepeat: false, keyCode: 37))
        XCTAssertTrue(menu.performKeyEquivalent(with: event))
        XCTAssertTrue(settings.library.window?.isVisible == true)
        let element = try XCTUnwrap(overlay.sessions["sprout"]?.accessibilityElement)
        XCTAssertEqual(element.accessibilityLabel(), "Pip the Sprout")
        XCTAssertTrue(element.accessibilityPerformPress())
        XCTAssertGreaterThan(overlay.engine.velocity.length, 0)
        store.value.paused = true; overlay.reconcile()
        XCTAssertFalse(element.accessibilityPerformPress())
        controller.menuNeedsUpdate(menu)
        XCTAssertEqual(menu.item(withTitle: "Wake & Swing Selected Companion")?.isEnabled, false)
        settings.show(section: .characters)
        XCTAssertEqual(settings.navigation.page, .characters)
    }

    @MainActor
    func testVisualSurfaceNeverCapturesAndDisplayFrameRefreshesInPlace() throws {
        _ = NSApplication.shared
        let suite = "Tether.m21.gate." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PreferencesStore(defaults: defaults), displays = DisplayManager()
        defer { displays.stop() }
        guard let display = displays.displays.first else { throw XCTSkip("Requires WindowServer") }
        let overlay = OverlayManager(store: store, displays: displays); overlay.start(); defer { overlay.stop() }
        let panel = try XCTUnwrap(overlay.panel)
        XCTAssertTrue(panel.ignoresMouseEvents)
        XCTAssertEqual(overlay.inputGateCount, 1)
        panel.setFrame(CGRect(x: 10, y: 10, width: 400, height: 300), display: false)
        overlay.reconcile()
        XCTAssertTrue(panel === overlay.panel)
        XCTAssertEqual(panel.frame, display.screen.frame)
        XCTAssertTrue(panel.ignoresMouseEvents)
        store.value.visible = false; overlay.reconcile()
        XCTAssertTrue(overlay.visibleInputGateFrames.isEmpty)
        XCTAssertFalse(overlay.isSamplingPointer)
    }

}
