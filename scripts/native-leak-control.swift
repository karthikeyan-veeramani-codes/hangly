// Minimal AppKit + SwiftUI control for runtime leak attribution, not the Tether app.
import AppKit
import SwiftUI
@main struct LeakControlMain {
    @MainActor static func main() {
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let delegate = LeakControl(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
@MainActor final class LeakControl: NSObject, NSApplicationDelegate {
    var status: NSStatusItem?
    var windows: [NSWindow] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status?.button?.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "Temporary native leak control")
        DispatchQueue.main.asyncAfter(deadline: .now() + 9) { [weak self] in
            guard let self else { return }
            for i in 0..<2 {
                let window = NSWindow(contentRect: NSRect(x: 150 + i * 30, y: 150 + i * 30, width: 500, height: 400), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false; window.title = "Temporary native leak control"
                window.contentView = NSHostingView(rootView: NavigationSplitView { List { Text("General"); Text("About") } } detail: { Form { Text("AppKit / SwiftUI control only"); Toggle("Example", isOn: .constant(false)) }.formStyle(.grouped) })
                window.orderFrontRegardless(); windows.append(window)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 22) { NSApp.terminate(nil) }
    }
    func applicationWillTerminate(_ notification: Notification) { if let status { NSStatusBar.system.removeStatusItem(status) }; windows.forEach { $0.close() } }
}
