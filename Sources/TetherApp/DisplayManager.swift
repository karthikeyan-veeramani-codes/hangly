import AppKit
import Combine
import TetherCore

struct DisplayInfo: Identifiable {
    let id: String
    let name: String
    let screen: NSScreen
}
@MainActor
final class DisplayManager: ObservableObject {
    @Published private(set) var displays: [DisplayInfo] = []
    private var observer: NSObjectProtocol?
    init() {
        refresh()
        observer = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }
    func refresh() {
        displays = NSScreen.screens.map { screen in
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            let displayID = CGDirectDisplayID(number?.uint32Value ?? 0)
            let uuid = CGDisplayCreateUUIDFromDisplayID(displayID).map { CFUUIDCreateString(nil, $0.takeRetainedValue()) as String } ?? String(displayID)
            return DisplayInfo(id: uuid, name: screen.localizedName, screen: screen)
        }
    }
    func resolve(_ saved: String?) -> DisplayInfo? {
        let id = Geometry.displayID(saved: saved, available: displays.map(\.id), primary: displays.first?.id)
        return displays.first { $0.id == id }
    }
    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }
}
