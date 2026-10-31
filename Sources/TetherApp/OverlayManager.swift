import AppKit
import Combine
import QuartzCore
import TetherCore

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
@MainActor
final class CharmSession {
    var charm: Charm
    var engine: RopePhysics
    var animation = CharacterAnimation()
    var renderer: CharmRenderer?
    var screenFrame: NSRect = .zero
    var resolvedDisplayID: String?
    var backingScale: CGFloat = 0
    var dragging = false
    var accessibilityElement: CompanionAccessibilityElement?
    var targetLength: Double
    var nextIdle: Double = 6
    var idleIndex = 0
    init(charm: Charm) { self.charm = charm; targetLength = charm.ropeLength; engine = RopePhysics(anchor: Vector(300, 5), length: charm.ropeLength) }
    var center: Vector {
        if let renderer { return Vector(renderer.bodyCenter.x, screenFrame.height - renderer.bodyCenter.y) }
        return engine.position + Vector((0.5 - charm.attachmentX) * charm.size, (0.5 - charm.attachmentY) * charm.size)
    }
    func contains(_ point: Vector) -> Bool {
        renderer?.hitBody(CGPoint(x: point.x, y: screenFrame.height - point.y)) == true || Geometry.distance(point, toSegment: engine.anchor, engine.position) <= charm.ropeWidth / 2 + 2
    }
    func releaseRenderer() { accessibilityElement?.owner = nil; accessibilityElement?.setAccessibilityParent(nil); accessibilityElement = nil; renderer?.stopAmbient(); renderer?.root.removeFromSuperlayer(); renderer = nil }
}
@MainActor
private final class DisplayOverlay {
    let panel: PetPanel
    let view: InteractionController
    let inputPanel: PetPanel
    let inputView: InteractionController
    var scale: CGFloat
    init(display: DisplayInfo, owner: OverlayManager) {
        panel = PetPanel(contentRect: display.screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = false; panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false; panel.isFloatingPanel = true
        panel.ignoresMouseEvents = true; panel.animationBehavior = .none
        view = InteractionController(frame: NSRect(origin: .zero, size: display.screen.frame.size))
        view.owner = owner; view.wantsLayer = true
        view.setAccessibilityElement(false)
        panel.contentView = view
        scale = display.screen.backingScaleFactor
        inputPanel = PetPanel(contentRect: CGRect(x: 0, y: 0, width: 1 / scale, height: 1 / scale), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        inputPanel.isReleasedWhenClosed = false; inputPanel.isOpaque = false; inputPanel.backgroundColor = .clear
        inputPanel.hasShadow = false; inputPanel.hidesOnDeactivate = false; inputPanel.isFloatingPanel = true
        inputPanel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
        inputPanel.collectionBehavior = panel.collectionBehavior; inputPanel.animationBehavior = .none
        inputPanel.ignoresMouseEvents = true
        inputView = InteractionController(frame: CGRect(x: 0, y: 0, width: 1 / scale, height: 1 / scale)); inputView.owner = owner
        inputView.setAccessibilityElement(false); inputPanel.setAccessibilityElement(false); inputPanel.contentView = inputView
    }
    func refresh(_ display: DisplayInfo) {
        scale = display.screen.backingScaleFactor
        if panel.frame != display.screen.frame { panel.setFrame(display.screen.frame, display: true) }
    }
    func routeInput(at point: CGPoint?, captured: Bool = false) {
        guard let point else {
            if !inputPanel.ignoresMouseEvents { inputPanel.ignoresMouseEvents = true }
            if inputPanel.isVisible { inputPanel.orderOut(nil) }
            return
        }
        if !captured {
            let rect = CGRect(x: floor(point.x * scale) / scale, y: floor(point.y * scale) / scale, width: 1 / scale, height: 1 / scale)
            if inputPanel.frame != rect { inputPanel.setFrame(rect, display: false) }
        }
        if inputPanel.ignoresMouseEvents { inputPanel.ignoresMouseEvents = false }
        if !inputPanel.isVisible { inputPanel.orderFrontRegardless() }
    }
    func close() { view.owner = nil; inputView.owner = nil; routeInput(at: nil); inputPanel.close(); panel.ignoresMouseEvents = true; panel.close() }
}

/// Owns independent sessions and shares all panels and scheduling across them.
@MainActor
final class OverlayManager {
    let store: PreferencesStore
    let displays: DisplayManager
    private(set) var sessions: [String: CharmSession] = [:]
    private var overlays: [String: DisplayOverlay] = [:]
    private var simulation: Timer?
    private var pointer: Timer?
    private var ambient: Timer?
    private var subscriptions = Set<AnyCancellable>()
    private var observers: [NSObjectProtocol] = []
    private var lastTick: TimeInterval = 0
    private var ambientClock: TimeInterval = 0
    private var frameInterval: Double = 1 / 60.0
    private var capturedID: String?
    private var gesture = DragTracker()
    private var applicationHidden = false
    private var nativeInputProbe = false
    private var eventMonitors: [Any] = []
    private var systemSleeping = false
    private var displaySleeping = false
    private var sleeping: Bool { systemSleeping || displaySleeping }
    private var started = false
    private var pendingReconcile = false
    private var settings = Preferences()
    private let reduceMotionProvider: () -> Bool
    private(set) var renderCount = 0
    private(set) var totalSteps = 0
    private(set) var frameCallbacks = 0
    private(set) var maximumFrameGap: Double = 0
    private(set) var onBattery = false
    var panel: PetPanel? {
        guard let id = sessions[store.value.selectedID]?.resolvedDisplayID else { return overlays.values.first?.panel }
        return overlays[id]?.panel
    }
    var engine: RopePhysics { sessions[store.value.selectedID]?.engine ?? RopePhysics(anchor: Vector(300, 5), length: 220) }
    var dragging: Bool { capturedID != nil }
    var isSimulating: Bool { simulation != nil }
    var isSamplingPointer: Bool { pointer != nil }
    var schedulingSnapshot: [String: Int] { ["simulationTimers": simulation == nil ? 0 : 1, "pointerTimers": pointer == nil ? 0 : 1, "ambientTimers": ambient == nil ? 0 : 1, "eventMonitors": eventMonitors.count, "observers": observers.count, "subscriptions": subscriptions.count, "sessions": sessions.count, "renderers": sessions.values.filter { $0.renderer != nil }.count, "panels": overlays.count] }
    var panelCount: Int { overlays.count }
    var inputGateCount: Int { overlays.count }
    var visibleInputGateFrames: [NSRect] { overlays.values.filter { $0.inputPanel.isVisible }.map { $0.inputPanel.frame } }
    var activeSessionCount: Int { settings.activeIDs.filter { sessions[$0] != nil }.count }
    var reducedMotion: Bool { settings.respectReduceMotion && reduceMotionProvider() }
    init(store: PreferencesStore, displays: DisplayManager, reduceMotionProvider: @escaping () -> Bool = { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }) { self.store = store; self.displays = displays; self.reduceMotionProvider = reduceMotionProvider }
    func start() {
        guard !started else { return }; started = true
        store.$snapshot.dropFirst().sink { [weak self] _ in self?.scheduleReconcile() }.store(in: &subscriptions)
        displays.$displays.dropFirst().sink { [weak self] _ in self?.scheduleReconcile() }.store(in: &subscriptions)
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { guard let self else { return }
                    if name == NSWorkspace.willSleepNotification { self.systemSleeping = true } else { self.displaySleeping = true }
                    self.suspend(); self.overlays.values.forEach { $0.panel.orderOut(nil) } }
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { guard let self else { return }
                    if name == NSWorkspace.didWakeNotification { self.systemSleeping = false } else { self.displaySleeping = false }
                    if !self.sleeping { self.displays.refresh(); self.rebuild() } }
            })
        }
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.cancelGesture() }
            })
        }
        for name in [NSApplication.didHideNotification, NSApplication.didUnhideNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: NSApp, queue: .main) { [weak self] notification in
                let hidden = notification.name == NSApplication.didHideNotification
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.applicationHidden = hidden
                    if self.applicationHidden { self.suspend(); self.overlays.values.forEach { $0.panel.orderOut(nil) } }
                    else { self.reconcile() }
                }
            })
        }
        observers.append(center.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sessions.values.forEach { session in
                    session.renderer?.configure(charm: session.charm, image: AssetCache.shared.image(session.charm.assetFilename), scale: session.backingScale)
                }
                self?.reconcile()
            }
        })
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.updateHitRegion() }
        }) { eventMonitors.append(monitor) }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged], handler: { [weak self] event in
            MainActor.assumeIsolated { self?.updateHitRegion() }; return event
        }) { eventMonitors.append(monitor) }
        rebuild()
    }
    private func scheduleReconcile() {
        guard started, !pendingReconcile else { return }; pendingReconcile = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }; self.pendingReconcile = false
            if self.started { self.reconcile() }
        }
    }
    func stop() {
        started = false; pendingReconcile = false; suspend(); subscriptions.removeAll()
        eventMonitors.forEach { NSEvent.removeMonitor($0) }; eventMonitors.removeAll()
        for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer); NotificationCenter.default.removeObserver(observer) }
        observers.removeAll(); sessions.values.forEach { $0.releaseRenderer() }; sessions.removeAll()
        overlays.values.forEach { $0.close() }; overlays.removeAll()
    }
    func rebuild() {
        guard started else { return }
        suspend()
        sessions.values.forEach { $0.renderer?.root.removeFromSuperlayer() }
        overlays.values.forEach { $0.close() }; overlays.removeAll()
        reconcile()
    }
    /// Updates geometry and appearance in place; configuration changes never replace velocity.
    func reconcile() {
        guard started else { return }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let previous = settings; settings = store.value
        if (!previous.paused && settings.paused) || (previous.animationEnabled && !settings.animationEnabled) { cancelCapture() }
        onBattery = PowerState.onBattery
        let newInterval = 1 / Double(settings.reduceOnBattery && onBattery ? 30 : settings.quality.rawValue)
        if frameInterval != newInterval { stopSimulation(); frameInterval = newInterval }
        let validIDs = Set(settings.charms.map(\.id))
        for id in Array(sessions.keys) where !validIDs.contains(id) {
            if capturedID == id { capturedID = nil }
            sessions.removeValue(forKey: id)?.releaseRenderer()
        }
        var usedDisplays = Set<String>()
        for charm in settings.charms {
            let isNew = sessions[charm.id] == nil
            let session = sessions[charm.id] ?? CharmSession(charm: charm)
            sessions[charm.id] = session
            let oldCharm = session.charm
            session.charm = charm
            guard let display = displays.resolve(charm.displayID) else {
                session.resolvedDisplayID = nil; session.releaseRenderer(); continue
            }
            let oldFrame = session.screenFrame
            let scaleChanged = session.backingScale != display.screen.backingScaleFactor
            session.backingScale = display.screen.backingScaleFactor
            session.screenFrame = display.screen.frame
            session.resolvedDisplayID = display.id
            let radius = charm.size * 1.1
            let anchorY = max(5, display.screen.safeAreaInsets.top)
            let length = min(max(charm.ropeLength, radius), max(40, session.screenFrame.height - radius - anchorY - 8))
            let anchor = Vector(min(max(charm.anchorX * session.screenFrame.width, radius), max(radius, session.screenFrame.width - radius)), anchorY)
            if isNew {
                session.engine = RopePhysics(anchor: anchor, length: length); session.targetLength = length
            } else if session.engine.anchor != anchor || session.targetLength != length || oldFrame != session.screenFrame {
                // Shift anchor coordinates without resetting motion; ease length changes during updates.
                session.engine.position = anchor + (session.engine.position - session.engine.anchor)
                session.engine.anchor = anchor; session.targetLength = length; session.engine.wake()
            }
            let oldWind = session.engine.wind
            session.engine.gravity = charm.gravity; session.engine.damping = charm.damping
            session.engine.wind = reducedMotion ? 0 : (settings.wind ? max(170, charm.windIntensity) : charm.windIntensity)
            if oldWind != session.engine.wind { session.engine.wake() }
            session.engine.contain(width: session.screenFrame.width, height: session.screenFrame.height, radius: radius)
            let isActive = settings.activeIDs.contains(charm.id)
            if isActive {
                usedDisplays.insert(display.id)
                if overlays[display.id] == nil { overlays[display.id] = DisplayOverlay(display: display, owner: self) }
                overlays[display.id]?.refresh(display)
                let isNewRenderer = session.renderer == nil
                if isNewRenderer { session.renderer = CharmRenderer() }
                if isNewRenderer || oldCharm != charm || oldFrame != session.screenFrame || scaleChanged {
                    let image = AssetCache.shared.image(charm.assetFilename)
                    session.renderer?.configure(charm: charm, image: image, scale: display.screen.backingScaleFactor)
                    if charm.kind == .custom && image == nil && isNewRenderer { store.notice = "Artwork for \(charm.name) is missing or corrupt. A placeholder is shown; reimport it from the Character Library." }
                }
                if let renderer = session.renderer, renderer.root.superlayer !== overlays[display.id]?.view.layer {
                    renderer.root.removeFromSuperlayer(); overlays[display.id]?.view.layer?.addSublayer(renderer.root)
                }
                session.renderer?.root.frame = NSRect(origin: .zero, size: session.screenFrame.size)
                session.renderer?.root.isHidden = !charm.visible
                session.renderer?.root.zPosition = CGFloat(settings.activeIDs.firstIndex(of: charm.id) ?? 0)
                if isNewRenderer || oldCharm != charm || oldFrame != session.screenFrame || previous.paused != settings.paused || previous.animationEnabled != settings.animationEnabled {
                    updateAnimation(session, dt: 0); render(session)
                }
                if settings.paused || !settings.animationEnabled || reducedMotion { session.renderer?.stopAmbient() }
            } else { session.releaseRenderer() }
        }
        for id in Array(overlays.keys) where !usedDisplays.contains(id) { overlays.removeValue(forKey: id)?.close() }
        let visible = presentedSessions
        for (id, overlay) in overlays {
            if !sleeping && !applicationHidden && settings.visible && visible.contains(where: { $0.resolvedDisplayID == id }) { overlay.panel.orderFrontRegardless() }
            else { overlay.panel.orderOut(nil); overlay.panel.ignoresMouseEvents = true }
        }
        if !settings.activeIDs.contains(capturedID ?? "") || !settings.visible || capturedID.flatMap({ sessions[$0]?.charm.visible }) == false { cancelCapture() }
        updateAccessibility()
        reschedule()
    }
    private func updateAccessibility() {
        for (displayID, overlay) in overlays {
            var children: [CompanionAccessibilityElement] = []
            for session in presentedSessions where session.resolvedDisplayID == displayID {
                let element = session.accessibilityElement ?? CompanionAccessibilityElement()
                element.owner = self; element.charmID = session.charm.id
                element.setAccessibilityRole(.button); element.setAccessibilityLabel(session.charm.name)
                element.setAccessibilityEnabled(canPlay(id: session.charm.id))
                element.setAccessibilityHelp("Press to wake and swing. Use Tether Settings to change this companion.")
                element.setAccessibilityParent(overlay.view)
                element.setAccessibilityFrame(accessibilityFrame(for: session))
                session.accessibilityElement = element; children.append(element)
            }
            overlay.view.setAccessibilityChildren(children)
        }
    }
    private var activeSessions: [CharmSession] { settings.activeIDs.compactMap { sessions[$0] } }
    private var presentedSessions: [CharmSession] { activeSessions.filter { $0.charm.visible && $0.resolvedDisplayID != nil } }
    private var canRun: Bool { !sleeping && !applicationHidden && !settings.paused && settings.animationEnabled && (settings.visible || !settings.pauseWhenHidden) }
    private func wantsFrames(_ session: CharmSession) -> Bool {
        canRun && session.charm.visible && !session.dragging && (!session.engine.isResting || session.animation.needsFrames)
    }
    private func reschedule() {
        if activeSessions.contains(where: wantsFrames) { startSimulation() } else { stopSimulation() }
        let visible = !sleeping && !applicationHidden && settings.visible && !presentedSessions.isEmpty
        if visible && !nativeInputProbe { startPointer() } else { pointer?.invalidate(); pointer = nil }
        let wantsAmbient = visible && canRun && (settings.idleReactions || settings.sleepAfter > 0)
        if wantsAmbient && ambient == nil {
            ambientClock = ProcessInfo.processInfo.systemUptime
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.ambientTick() } }
            timer.tolerance = 0.1; RunLoop.main.add(timer, forMode: .common); ambient = timer
        } else if !wantsAmbient { ambient?.invalidate(); ambient = nil }
    }
    private func suspend() {
        cancelCapture(); stopSimulation(); pointer?.invalidate(); pointer = nil; ambient?.invalidate(); ambient = nil
        for overlay in overlays.values { overlay.panel.ignoresMouseEvents = true; overlay.routeInput(at: nil) }
        sessions.values.forEach { $0.renderer?.stopAmbient() }
    }
    private func cancelCapture() {
        if let capturedID, let session = sessions[capturedID] { session.dragging = false; session.engine.velocity = Vector(); session.engine.wake() }
        capturedID = nil
    }
    private func stopSimulation() { simulation?.invalidate(); simulation = nil; sessions.values.forEach { $0.engine.resetClock() } }
    private func startSimulation() {
        guard simulation == nil, canRun else { return }
        lastTick = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: frameInterval, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.tick() } }
        timer.tolerance = frameInterval * 0.12; RunLoop.main.add(timer, forMode: .common); simulation = timer
    }
    private func startPointer() {
        guard pointer == nil else { return }
        let timer = Timer(timeInterval: 1 / 30.0, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.updateHitRegion() } }
        timer.tolerance = 0.005; RunLoop.main.add(timer, forMode: .common); pointer = timer
        updateHitRegion()
    }
    func setNativeInputProbe(_ enabled: Bool) {
        nativeInputProbe = enabled
        pointer?.invalidate(); pointer = nil
        for overlay in overlays.values { overlay.routeInput(at: nil); overlay.panel.ignoresMouseEvents = enabled ? false : true }
        CATransaction.flush()
        if !enabled { reschedule() }
    }
    private func globalPoint(for event: NSEvent) -> CGPoint {
        event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
    }
    private func point(in session: CharmSession, global: CGPoint? = nil) -> Vector {
        let p = global ?? NSEvent.mouseLocation
        return Vector(p.x - session.screenFrame.minX, session.screenFrame.maxY - p.y)
    }
    func hitSession(at location: CGPoint? = nil) -> CharmSession? {
        let global = location ?? NSEvent.mouseLocation
        return presentedSessions.reversed().first { session in
            session.screenFrame.contains(global) && session.contains(Vector(global.x - session.screenFrame.minX, session.screenFrame.maxY - global.y))
        }
    }
    private func updateHitRegion() {
        guard !nativeInputProbe, started, !applicationHidden, !sleeping, settings.visible else { return }
        if capturedID != nil && NSEvent.pressedMouseButtons & 1 == 0 { finishDrag() }
        let global = NSEvent.mouseLocation
        let target = capturedID.flatMap { sessions[$0] } ?? hitSession(at: global)
        for (id, overlay) in overlays {
            // Visual surfaces never receive ordinary mouse input. A stale input gate
            // covers one physical pixel, so rapid departures cannot block the display.
            if !overlay.panel.ignoresMouseEvents { overlay.panel.ignoresMouseEvents = true }
            overlay.routeInput(at: overlay.panel.isVisible && target?.resolvedDisplayID == id ? global : nil, captured: capturedID != nil)
        }
    }
    private func updateAnimation(_ session: CharmSession, dt: Double) {
        session.animation.update(dt: dt, moving: !session.engine.isResting, dragging: session.dragging, paused: settings.paused || !settings.animationEnabled, sleepAfter: settings.sleepAfter, reducedMotion: reducedMotion)
    }
    private func tick() {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let now = ProcessInfo.processInfo.systemUptime
        let gap = max(0, now - lastTick)
        frameCallbacks += 1; maximumFrameGap = max(maximumFrameGap, gap)
        let dt = min(0.1, gap); lastTick = now
        for session in activeSessions where wantsFrames(session) {
            let lengthDelta = session.targetLength - session.engine.length
            if abs(lengthDelta) > 0.01 {
                session.engine.length += lengthDelta * min(1, dt * 10)
                session.engine.wake()
            } else { session.engine.length = session.targetLength }
            totalSteps += session.engine.advance(dt * settings.animationSpeed)
            session.engine.contain(width: session.screenFrame.width, height: session.screenFrame.height, radius: session.charm.size * 1.1)
            updateAnimation(session, dt: dt * settings.animationSpeed)
            if settings.visible { render(session) }
        }
        if !activeSessions.contains(where: wantsFrames) { stopSimulation() }
        updateHitRegion()
    }
    private func ambientTick() {
        let now = ProcessInfo.processInfo.systemUptime
        let dt = min(1, max(0, now - ambientClock)); ambientClock = now
        let battery = PowerState.onBattery
        if battery != onBattery { reconcile(); return }
        for session in presentedSessions where !wantsFrames(session) && !session.dragging {
            let previous = session.animation.phase
            updateAnimation(session, dt: dt)
            if previous != session.animation.phase { render(session) }
            session.nextIdle -= dt
            if session.nextIdle <= 0 && settings.idleReactions && session.animation.phase == .idle && !reducedMotion {
                session.renderer?.idleVariation(blink: settings.blinking && session.idleIndex.isMultiple(of: 2), reducedMotion: reducedMotion)
                session.idleIndex += 1; session.nextIdle = onBattery && settings.reduceOnBattery ? 20 : 7 + Double(session.idleIndex % 4)
            }
        }
    }
    private func accessibilityFrame(for session: CharmSession) -> NSRect {
        let rect = session.renderer?.artworkFrame ?? .zero
        return rect.offsetBy(dx: session.screenFrame.minX, dy: session.screenFrame.minY)
    }
    private func render(_ session: CharmSession) {
        guard session.renderer != nil else { return }
        renderCount += 1
        session.renderer?.render(engine: session.engine, height: session.screenFrame.height, dragging: session.dragging, animation: session.animation)
        if let element = session.accessibilityElement {
            element.setAccessibilityFrame(accessibilityFrame(for: session))
        }
    }
    func beginDrag(_ event: NSEvent) {
        let global = globalPoint(for: event)
        guard let session = hitSession(at: global) else { return }
        beginDrag(id: session.charm.id, pointer: point(in: session, global: global), time: event.timestamp)
    }
    func beginDrag(id: String, pointer: Vector, time: TimeInterval) {
        guard settings.activeIDs.contains(id), let session = sessions[id], session.charm.visible, settings.visible, !applicationHidden, !sleeping else { return }
        cancelCapture()
        store.value.selectedID = id
        capturedID = id; session.dragging = true
        gesture.begin(pointer: pointer, bob: session.engine.position, time: time)
        session.animation.interact(reaction: false, reducedMotion: reducedMotion)
        session.renderer?.stopAmbient(); updateAnimation(session, dt: 0); render(session); reschedule()
    }
    func drag(_ event: NSEvent) {
        guard let capturedID, let session = sessions[capturedID] else { return }
        drag(session, to: point(in: session, global: globalPoint(for: event)), now: event.timestamp)
    }
    func drag(_ session: CharmSession, to location: Vector, now: TimeInterval) {
        guard capturedID == session.charm.id, session.dragging else { return }
        session.engine.drag(to: gesture.target(for: location), velocity: Vector())
        session.engine.contain(width: session.screenFrame.width, height: session.screenFrame.height, radius: session.charm.size * 1.1)
        gesture.record(pointer: location, actual: session.engine.position, time: now)
        session.engine.velocity = gesture.releaseVelocity(at: now)
        updateAnimation(session, dt: 0); render(session)
    }
    func endDrag(_ event: NSEvent) { finishDrag(at: event.timestamp); updateHitRegion() }
    func finishDrag(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let id = capturedID, let session = sessions[id] else { return }
        capturedID = nil; session.dragging = false
        if !gesture.moved { play(id: id) }
        else {
            session.engine.velocity = gesture.releaseVelocity(at: time)
            session.engine.wake(); session.animation.interact(reaction: false, reducedMotion: reducedMotion)
            updateAnimation(session, dt: 0); render(session); reschedule()
        }
    }
    func cancelGesture() { cancelCapture(); if started { reschedule() } }
    func canPlay(id: String) -> Bool { started && !sleeping && !applicationHidden && settings.visible && !settings.paused && settings.animationEnabled && settings.activeIDs.contains(id) && sessions[id]?.charm.visible == true }
    func play() { play(id: store.value.selectedID) }
    func play(id: String) {
        // Programmatic play is also used to restore a session's independent
        // velocity while hidden or paused. UI and accessibility callers use
        // canPlay before invoking it.
        guard let session = sessions[id] else { return }
        session.animation.interact(reaction: true, reducedMotion: reducedMotion)
        session.engine.impulse(Vector(reducedMotion ? 65 : 320, reducedMotion ? -20 : -110) * session.charm.swingIntensity)
        updateAnimation(session, dt: 0); render(session); reschedule()
    }
    func contextMenu(_ event: NSEvent, in view: NSView) {
        guard let session = hitSession(at: globalPoint(for: event)) else { return }
        cancelGesture(); store.value.selectedID = session.charm.id
        let menu = NSMenu()
        for (title, selector) in [("Give a little swing", #selector(swing)), ("Duplicate companion", #selector(duplicate)), ("Remove from desktop", #selector(remove)), (settings.paused ? "Resume all animations" : "Pause all animations", #selector(togglePause))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: ""); item.target = self; menu.addItem(item)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }
    @objc private func togglePause() { store.value.paused.toggle() }
    @objc private func swing() { play() }
    @objc private func duplicate() { store.duplicate(store.value.selectedID) }
    @objc private func remove() { store.removeFromDesktop(store.value.selectedID) }
}
