import SwiftUI
import AppKit
import TetherCore

@MainActor
final class SettingsController {
    private let store: PreferencesStore
    private let displays: DisplayManager
    let navigation = SettingsNavigation()
    var onPlay: (() -> Void)?
    let library: CharacterLibraryController
    private(set) var window: NSWindow?
    init(store: PreferencesStore, displays: DisplayManager, library: CharacterLibraryController? = nil) {
        self.store = store; self.displays = displays; self.library = library ?? CharacterLibraryController(store: store)
    }
    func show(section: SettingsPage? = nil) {
        if let section { navigation.page = section }
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 590), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Tether Settings"; window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 740, height: 530)
            window.contentView = NSHostingView(rootView: SettingsView(store: store, displays: displays, library: library, navigation: navigation, onPlay: { [weak self] in self?.onPlay?() }))
            window.center(); self.window = window
        }
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
}
enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "General", characters = "Characters", rope = "Rope & Physics", animation = "Animation", display = "Displays", performance = "Performance", about = "About"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .characters: "face.smiling"
        case .rope: "point.topleft.down.curvedto.point.bottomright.up"
        case .animation: "wind"
        case .display: "display.2"
        case .performance: "gauge.with.dots.needle.33percent"
        case .about: "info.circle"
        }
    }
}
@MainActor
final class SettingsNavigation: ObservableObject { @Published var page: SettingsPage? = .general }

struct SettingsView: View {
    @ObservedObject var store: PreferencesStore
    @ObservedObject var displays: DisplayManager
    let library: CharacterLibraryController
    @StateObject private var login = LoginItem()
    @ObservedObject var navigation: SettingsNavigation
    var onPlay: () -> Void
    private var page: SettingsPage? { navigation.page }
    private func charmBinding<T>(_ keyPath: WritableKeyPath<Charm, T>) -> Binding<T> {
        Binding(get: { store.value.selected[keyPath: keyPath] }, set: { value in store.editCharm { $0[keyPath: keyPath] = value } })
    }
    private var colorBinding: Binding<Color> {
        Binding(get: { let c = store.value.selected.ropeColor; return Color(red: c.red, green: c.green, blue: c.blue, opacity: c.alpha) }, set: { value in
            guard let c = NSColor(value).usingColorSpace(.deviceRGB) else { return }
            store.editCharm { $0.ropeColor = RGBA(c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent) }
        })
    }
    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 16) {
                Label("Tether", systemImage: "leaf.fill").font(.title2.bold()).foregroundStyle(.green).padding(.horizontal, 14).padding(.top, 20)
                List(SettingsPage.allCases, selection: $navigation.page) { item in Label(item.rawValue, systemImage: item.symbol).tag(item) }.listStyle(.sidebar)
                Text("A little company.\nA little more delight.").font(.caption).foregroundStyle(.secondary).padding(16)
            }.navigationSplitViewColumnWidth(185)
        } detail: {
            Form {
                switch page ?? .general {
                case .general: general
                case .characters: characters
                case .rope: rope
                case .animation: animation
                case .display: display
                case .performance: performance
                case .about: about
                }
            }.formStyle(.grouped).navigationTitle((page ?? .general).rawValue)
        }
        .safeAreaInset(edge: .bottom) { NoticeBanner(store: store) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in login.refresh() }
    }
    private var general: some View {
        Group {
            Section("Make yourself at home") {
                Toggle("Show companions now", isOn: $store.value.visible)
                Toggle("Show on startup", isOn: $store.value.showOnStartup)
                Toggle("Restore previous arrangement", isOn: $store.value.restoreSession)
                Toggle("Show companion count in menu bar", isOn: $store.value.statusShowsCount)
                Toggle("Launch at login", isOn: Binding(get: { login.enabled }, set: { login.setEnabled($0) }))
                if let message = login.message { Text(message).font(.caption).foregroundStyle(.secondary) }
            }
            Section("Your rhythm") {
                Toggle("Pause all animations", isOn: $store.value.paused)
                Stepper("Desktop limit · \(store.value.maxActive)", value: $store.value.maxActive, in: 1...12)
                Text("Drag and release to swing. Click for a reaction. Right-click for companion controls. Lowering the limit removes excess companions from the desktop but keeps their arrangements.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var characterPicker: some View {
        Picker("Edit companion", selection: $store.value.selectedID) {
            ForEach(store.value.charms) { charm in Text(charm.name + (store.value.activeIDs.contains(charm.id) ? "" : " · off desktop")).tag(charm.id) }
        }
    }
    private var characters: some View {
        Group {
            Section("Your companions") {
                Button("Open Character Library…") { library.show() }
                characterPicker
                Button("Wake & Swing Selected Companion", action: onPlay).disabled(!store.value.activeIDs.contains(store.value.selectedID) || store.value.paused || !store.value.animationEnabled || !store.value.visible || !store.value.selected.visible)
                CharacterPreview(charm: store.value.selected).frame(height: 160).frame(maxWidth: .infinity)
                TextField("Name", text: charmBinding(\.name))
                Toggle("Visible on desktop", isOn: charmBinding(\.visible))
                Slider(value: charmBinding(\.size), in: 44...160) { Text("Size · \(Int(store.value.selected.size)) pt") }
                Slider(value: charmBinding(\.opacity), in: 0.2...1) { Text("Opacity") }
                Slider(value: charmBinding(\.anchorX), in: 0.05...0.95) { Text("Horizontal position") }
                HStack {
                    Button("Duplicate") { store.duplicate(store.value.selectedID) }
                    Button("Remove from Desktop") { store.removeFromDesktop(store.value.selectedID) }.disabled(!store.value.activeIDs.contains(store.value.selectedID))
                }
                if !store.value.activeIDs.contains(store.value.selectedID) {
                    HStack {
                        Button("Return to Desktop") { store.perform { prefs in guard prefs.activeIDs.count < prefs.maxActive else { throw LibraryError.limit }; prefs.activeIDs.append(prefs.selectedID) } }
                        Button("Forget Arrangement", role: .destructive) { store.perform { $0.deleteInstance($0.selectedID) } }
                    }
                }
            }
        }
    }
    private var rope: some View {
        Group {
            Section("Hanging just right") {
                characterPicker
                Slider(value: charmBinding(\.ropeLength), in: 80...600) { Text("Length · \(Int(store.value.selected.ropeLength)) pt") }
                Slider(value: charmBinding(\.ropeWidth), in: 1...8) { Text("Thickness · \(store.value.selected.ropeWidth, specifier: "%.1f") pt") }
                ColorPicker("Rope color", selection: colorBinding)
                Slider(value: charmBinding(\.attachmentX), in: 0...1) { Text("Artwork attachment · horizontal") }
                Slider(value: charmBinding(\.attachmentY), in: 0...1) { Text("Artwork attachment · vertical") }
            }
            Section("A natural rhythm") {
                Slider(value: charmBinding(\.gravity), in: 100...2500) { Text("Gravity · \(Int(store.value.selected.gravity))") }
                Slider(value: charmBinding(\.damping), in: 0.2...3) { Text("Damping · \(store.value.selected.damping, specifier: "%.1f")") }
                Slider(value: charmBinding(\.windIntensity), in: 0...400) { Text("Wind strength") }
                Slider(value: charmBinding(\.swingIntensity), in: 0.1...2) { Text("Click swing intensity") }
                Button("Reset Appearance & Physics") { store.perform { prefs in
                    guard let index = prefs.charms.firstIndex(where: { $0.id == prefs.selectedID }) else { return }
                    let previous = prefs.charms[index]
                    var restored = prefs.library.first(where: { $0.id == previous.sourceID }) ?? Charm(id: previous.id, name: previous.name, kind: previous.kind, assetFilename: previous.assetFilename)
                    restored.id = previous.id; restored.templateID = previous.templateID; restored.name = previous.name
                    restored.anchorX = previous.anchorX; restored.displayID = previous.displayID; restored.visible = previous.visible
                    prefs.charms[index] = restored
                } }
                Text("Settings belong to this companion. Wind keeps physics awake; turn it off for a quieter desktop.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var animation: some View {
        Group {
            Section("A little personality") {
                Toggle("Enable animation", isOn: $store.value.animationEnabled)
                Toggle("Pause all animations", isOn: $store.value.paused)
                Slider(value: $store.value.animationSpeed, in: 0.25...2) { Text("Animation speed") }
                Toggle("Occasional idle reactions", isOn: $store.value.idleReactions)
                Toggle("Blink during idle reactions", isOn: $store.value.blinking)
                Picker("Sleep after inactivity", selection: $store.value.sleepAfter) {
                    Text("Never").tag(0.0); Text("30 seconds").tag(30.0); Text("2 minutes").tag(120.0); Text("5 minutes").tag(300.0)
                }
                Toggle("Respect macOS Reduce Motion", isOn: $store.value.respectReduceMotion)
                Button("Reset Animation Settings") { store.perform { prefs in
                    let defaults = Preferences()
                    prefs.animationEnabled = defaults.animationEnabled; prefs.animationSpeed = defaults.animationSpeed
                    prefs.idleReactions = defaults.idleReactions; prefs.blinking = defaults.blinking
                    prefs.sleepAfter = defaults.sleepAfter; prefs.respectReduceMotion = defaults.respectReduceMotion
                } }
                Text("Sleeping companions wake when you interact. Imported artwork uses safe whole-image movement; Tether never invents facial layers for it.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var display: some View {
        Group {
            Section("A place to hang") {
                characterPicker
                Picker("Display", selection: Binding(get: { store.value.selected.displayID ?? "" }, set: { value in store.editCharm { $0.displayID = value.isEmpty ? nil : value } })) {
                    Text("Primary display").tag("")
                    ForEach(displays.displays) { display in Text(display.name).tag(display.id) }
                    if let saved = store.value.selected.displayID, !displays.displays.contains(where: { $0.id == saved }) { Text("Disconnected display · using primary").tag(saved) }
                }
                Slider(value: charmBinding(\.anchorX), in: 0.05...0.95) { Text("Anchor position") }
                Text("A disconnected display falls back to an available display. Its saved placement returns when the display is recognized again. Display identifiers can change with hardware configurations.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Spaces & fullscreen") {
                Text("Tether uses public macOS window APIs. Some fullscreen apps, Mission Control and system screens can hide companions. Menus, the menu bar and system UI take priority.").foregroundStyle(.secondary)
            }
        }
    }
    private var performance: some View {
        Group {
            Section("Light on its feet") {
                Picker("Animation quality", selection: $store.value.quality) { Text("Smooth · 60 Hz").tag(AnimationQuality.smooth); Text("Economical · 30 Hz").tag(AnimationQuality.economical) }
                Toggle("Pause physics while all companions are hidden", isOn: $store.value.pauseWhenHidden)
                Toggle("Reduce activity on battery", isOn: $store.value.reduceOnBattery)
                LabeledContent("Active companions", value: "\(store.value.activeIDs.count) / \(store.value.maxActive)")
                LabeledContent("Power source", value: PowerState.onBattery ? "Battery" : "External power")
                LabeledContent("Simulation", value: "120 Hz fixed step · 8-step cap")
                LabeledContent("Scheduling", value: "Shared across companions")
                LabeledContent("At rest", value: "No continuous redraws")
                Text("One overlay per display. One pointer sampler while visible. Idle variations are occasional; hidden companions stop rendering. Battery mode lowers frame frequency and idle activity.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var about: some View {
        Section {
            Label("Tether", systemImage: "leaf.fill").font(.largeTitle.bold()).foregroundStyle(.green)
            Text("A small companion for your Mac.").font(.title3)
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0") · Build \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1")")
            Text("Pip, Mallow, Sol, Luna and Nori are original vector characters. Imported artwork belongs to its owner. Tether stays on this Mac: no accounts, analytics, network services or background helpers.").foregroundStyle(.secondary)
        }
    }
}
@MainActor
final class PreviewHost: NSView {
    private let renderer = CharmRenderer()
    private var charm = Preferences.builtins[0]
    private var image: NSImage?
    override init(frame frameRect: NSRect) { super.init(frame: frameRect); wantsLayer = true; layer?.addSublayer(renderer.root) }
    required init?(coder: NSCoder) { nil }
    func configure(_ charm: Charm, image: NSImage?) {
        self.charm = charm; self.image = image ?? AssetCache.shared.image(charm.assetFilename)
        needsLayout = true
    }
    override func layout() {
        super.layout(); renderer.root.frame = bounds
        var preview = charm; preview.size = min(charm.size, max(24, bounds.height - 44))
        renderer.configure(charm: preview, image: image, scale: window?.backingScaleFactor ?? 2)
        let attachmentY = 22 + preview.attachmentY * preview.size
        var physics = RopePhysics(anchor: Vector(bounds.midX, 0), length: max(40, attachmentY))
        physics.position = Vector(bounds.midX, attachmentY)
        renderer.render(engine: physics, height: bounds.height, dragging: false)
    }
}
struct CharacterPreview: NSViewRepresentable {
    let charm: Charm
    var overrideImage: NSImage? = nil
    func makeNSView(context: Context) -> PreviewHost { PreviewHost(frame: .zero) }
    func updateNSView(_ view: PreviewHost, context: Context) { view.configure(charm, image: overrideImage) }
}

struct NoticeBanner: View {
    @ObservedObject var store: PreferencesStore
    var body: some View {
        if let notice = store.notice {
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.circle").accessibilityHidden(true)
                Text(notice).font(.callout).textSelection(.enabled)
                Spacer()
                Button("Dismiss") { store.notice = nil }
            }.padding(12).background(.regularMaterial).accessibilityElement(children: .contain)
        }
    }
}
