import AppKit
import Combine
import TetherCore

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private let store: PreferencesStore
    private let settings: SettingsController
    weak var overlay: OverlayManager?
    private var subscription: AnyCancellable?
    init(store: PreferencesStore, settings: SettingsController) {
        self.store = store; self.settings = settings
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        item.button?.image = NSImage(systemSymbolName: "leaf", accessibilityDescription: "Tether companions")
        let menu = NSMenu(); menu.delegate = self; item.menu = menu
        subscription = store.$snapshot.sink { [weak self] value in
            self?.item.button?.title = value.statusShowsCount ? " \(value.activeIDs.count)" : ""
        }
    }
    func stop() { subscription?.cancel(); subscription = nil; item.menu?.delegate = nil; NSStatusBar.system.removeStatusItem(item) }
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.autoenablesItems = false
        menu.removeAllItems()
        add("Tether · \(store.value.activeIDs.count) companions", nil, to: menu)
        menu.addItem(.separator())
        add(store.value.visible ? "Hide All" : "Show All", #selector(toggleVisibility), to: menu)
        add(store.value.paused ? "Resume All" : "Pause All", #selector(togglePause), to: menu)
        menu.addItem(.separator())
        add("Add Character…", #selector(openLibrary), key: "n", to: menu)
        add("Character Library…", #selector(openLibrary), key: "l", to: menu)
        let active = NSMenuItem(title: "Active Characters", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        if store.value.active.isEmpty { add("No companions on desktop", nil, to: submenu) }
        for charm in store.value.active {
            let row = add(charm.name + (charm.visible ? "" : " (hidden)"), #selector(selectCharacter(_:)), to: submenu)
            row.representedObject = charm.id; row.state = charm.id == store.value.selectedID ? .on : .off
        }
        active.submenu = submenu; active.isEnabled = true; menu.addItem(active)
        let swing = add("Wake & Swing Selected Companion", #selector(swingSelected), to: menu)
        swing.isEnabled = overlay?.canPlay(id: store.value.selectedID) == true
        menu.addItem(.separator())
        add("Settings…", #selector(openSettings), key: ",", to: menu)
        add("About Tether", #selector(about), to: menu)
        add("Quit Tether", #selector(quit), key: "q", to: menu)
    }
    @discardableResult private func add(_ title: String, _ action: Selector?, key: String = "", to menu: NSMenu) -> NSMenuItem {
        let row = NSMenuItem(title: title, action: action, keyEquivalent: key); row.target = self; row.isEnabled = action != nil; menu.addItem(row); return row
    }
    @objc private func toggleVisibility() { store.value.visible.toggle() }
    @objc private func togglePause() { store.value.paused.toggle() }
    @objc private func selectCharacter(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String { store.value.selectedID = id; settings.show(section: .characters) }
    }
    @objc private func swingSelected() { overlay?.play() }
    @objc private func openLibrary() { settings.library.show() }
    @objc private func openSettings() { settings.show() }
    @objc private func about() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Tether", .applicationVersion: "2.1.0", .credits: NSAttributedString(string: "Pip, Mallow, Sol, Luna and Nori: original artwork for Tether.\nLocal-only. No telemetry.")])
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
