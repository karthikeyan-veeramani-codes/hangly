import AppKit
import SwiftUI
import TetherCore

@main
struct TetherMain {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: PreferencesStore!
    var displays: DisplayManager!
    var overlay: OverlayManager!
    var menu: MenuBarController!
    var settings: SettingsController!
    private var diagnostics: Diagnostics?
    private var diagnosticSuite: String?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let diagnostic = CommandLine.arguments.contains("--smoke-test") || CommandLine.arguments.contains("--profile-test")
        if diagnostic {
            let suite = "in.tether.diagnostics." + UUID().uuidString
            diagnosticSuite = suite
            guard let defaults = UserDefaults(suiteName: suite) else { NSLog("Tether could not create isolated diagnostic preferences"); NSApp.terminate(nil); return }
            store = PreferencesStore(defaults: defaults)
        } else { store = PreferencesStore() }
        if !diagnostic { store.perform { $0.applyStartupPolicy() } }
        if diagnostic {
            if let index = CommandLine.arguments.firstIndex(of: "--profile-count"), CommandLine.arguments.indices.contains(index + 1), let count = Int(CommandLine.arguments[index + 1]) {
                store.perform { prefs in
                    prefs.maxActive = 12
                    for i in 1..<max(1, min(12, count)) { _ = try prefs.add(templateID: Preferences.builtins[i % Preferences.builtins.count].id) }
                }
            }
            if !CommandLine.arguments.contains("--profile-ambient") {
                store.value.idleReactions = false; store.value.sleepAfter = 0
            }
            store.value.wind = CommandLine.arguments.contains("--profile-wind")
            store.value.paused = CommandLine.arguments.contains("--profile-paused")
            store.value.visible = !CommandLine.arguments.contains("--profile-hidden")
        }
        if diagnostic && CommandLine.arguments.contains("--evidence-light") { NSApp.appearance = NSAppearance(named: .aqua) }
        displays = DisplayManager()
        overlay = OverlayManager(store: store, displays: displays)
        settings = SettingsController(store: store, displays: displays)
        menu = MenuBarController(store: store, settings: settings)
        menu.overlay = overlay
        settings.onPlay = { [weak overlay] in overlay?.play() }
        overlay.start()
        if diagnostic { diagnostics = Diagnostics(store: store, overlay: overlay, settings: settings) }
        if diagnostic && CommandLine.arguments.contains("--gallery-smoke") {
            settings.library.show(); settings.show()
            if let index = CommandLine.arguments.firstIndex(of: "--snapshot-dir"), CommandLine.arguments.indices.contains(index + 1) {
                let folder = URL(fileURLWithPath: CommandLine.arguments[index + 1], isDirectory: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                    do {
                        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        for (name, window) in [("gallery", self?.settings.library.window), ("settings", self?.settings.window), ("desktop", self?.overlay.panel)] {
                            guard let view = window?.contentView, let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                            view.effectiveAppearance.performAsCurrentDrawingAppearance { view.cacheDisplay(in: view.bounds, to: bitmap) }
                            try bitmap.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent(name + ".png"))
                        }
                    } catch { NSLog("Tether diagnostic snapshot failed: %@", error.localizedDescription) }
                }
            }
        }
        if diagnostic {
            let seconds = min(1800, max(2, Double(Diagnostics.value("--profile-seconds") ?? "") ?? (CommandLine.arguments.contains("--profile-test") ? 15 : 2)))
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { NSApp.terminate(nil) }
        }
    }
    func applicationWillTerminate(_ notification: Notification) {
        diagnostics?.stop(); diagnostics = nil
        menu?.stop(); overlay?.stop(); displays?.stop(); AssetCache.shared.clear(); store?.flush()
        if let diagnosticSuite { UserDefaults.standard.removePersistentDomain(forName: diagnosticSuite) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
