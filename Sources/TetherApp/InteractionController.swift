import AppKit

@MainActor
final class InteractionController: NSView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    weak var owner: OverlayManager?
    override func mouseDown(with event: NSEvent) { owner?.beginDrag(event) }
    override func mouseDragged(with event: NSEvent) { owner?.drag(event) }
    override func mouseUp(with event: NSEvent) { owner?.endDrag(event) }
    override func rightMouseDown(with event: NSEvent) { owner?.contextMenu(event, in: self) }
    override func accessibilityPerformPress() -> Bool { owner?.play(); return true }
}


@MainActor
final class CompanionAction {
    weak var owner: OverlayManager?
    var charmID = ""
    func press() -> Bool { guard let owner, owner.canPlay(id: charmID) else { return false }; owner.play(id: charmID); return true }
}
@MainActor
final class CompanionAccessibilityElement: NSAccessibilityElement {
    nonisolated let action = CompanionAction()
    var owner: OverlayManager? { get { action.owner } set { action.owner = newValue } }
    var charmID: String { get { action.charmID } set { action.charmID = newValue } }
    nonisolated override func accessibilityPerformPress() -> Bool {
        let action = action
        if Thread.isMainThread { return MainActor.assumeIsolated { action.press() } }
        Task { @MainActor in _ = action.press() }
        return true
    }
}
