import AppKit
import SwiftUI
import TetherCore
import UniformTypeIdentifiers

@MainActor
final class CharacterLibraryController {
    let store: PreferencesStore
    private(set) var window: NSWindow?
    init(store: PreferencesStore) { self.store = store }
    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 840, height: 650), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Character Library"; window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 660, height: 530)
            window.contentView = NSHostingView(rootView: CharacterLibraryView(store: store))
            window.center(); self.window = window
        }
        NSApp.activate(ignoringOtherApps: true); window?.makeKeyAndOrderFront(nil)
    }
}
private struct ImportDraft: Identifiable {
    let id = UUID()
    let data: Data
    let name: String
    let image: NSImage
}
private enum LibraryCollection: String, CaseIterable { case all = "All", builtIn = "Built-in", custom = "Custom" }
struct CharacterLibraryView: View {
    @ObservedObject var store: PreferencesStore
    @State private var search = ""
    @State private var collection = LibraryCollection.all
    @State private var draft: ImportDraft?
    @State private var isImporting = false
    @State private var pendingDeletion: Charm?
    private var filtered: [Charm] {
        store.value.library.filter {
            (collection == .all || ($0.kind == .custom ? collection == .custom : collection == .builtIn)) &&
            (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("A little company").font(.largeTitle.bold())
                    Text("Make room for a few new friends.").foregroundStyle(.secondary)
                }
                Spacer()
                if isImporting { ProgressView("Preparing artwork…").controlSize(.small) }
                Button { chooseImage() } label: { Label("Add Character…", systemImage: "plus") }.buttonStyle(.borderedProminent).keyboardShortcut("n").disabled(isImporting)
            }.padding(24)
            if !store.value.active.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(store.value.active) { charm in
                            HStack {
                                Button { store.value.selectedID = charm.id } label: {
                                    HStack { Image(systemName: store.value.selectedID == charm.id ? "checkmark.circle.fill" : "circle.fill").foregroundStyle(charm.visible ? .green : .secondary).font(.caption2); Text(charm.name).lineLimit(1) }
                                }.buttonStyle(.plain).accessibilityLabel("Select " + charm.name).accessibilityValue(store.value.selectedID == charm.id ? "Selected" : "")
                                Button { store.duplicate(charm.id) } label: { Image(systemName: "plus.square.on.square") }.help("Duplicate \(charm.name)").accessibilityLabel("Duplicate " + charm.name).disabled(store.value.activeIDs.count >= store.value.maxActive || store.value.charms.count >= 64)
                                Button { store.removeFromDesktop(charm.id) } label: { Image(systemName: "xmark.circle.fill") }.help("Remove \(charm.name) from desktop").accessibilityLabel("Remove " + charm.name + " from desktop")
                            }.padding(10).background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                        }
                    }.padding(.horizontal, 24)
                }.padding(.bottom, 18)
            }
            HStack {
                Picker("Collection", selection: $collection) { ForEach(LibraryCollection.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).frame(maxWidth: 300)
                TextField("Search characters", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                Spacer()
                Text("\(store.value.activeIDs.count) of \(store.value.maxActive) on desktop").font(.callout).foregroundStyle(.secondary)
            }.padding(.horizontal, 24).padding(.bottom, 16)
            Divider()
            ScrollView {
                if filtered.isEmpty { ContentUnavailableView("No characters found", systemImage: "magnifyingglass", description: Text("Try another search or add your own artwork.")) }
                VStack(alignment: .leading, spacing: 24) {
                    gallerySection("Made for Tether", items: filtered.filter { $0.kind != .custom })
                    gallerySection("Your artwork", items: filtered.filter { $0.kind == .custom })
                }.padding(24)
            }
            Divider()
            HStack {
                Button("Restore Built-in Collection") { store.perform { $0.restoreBuiltins() } }
                Spacer()
                Text("Original artwork. Always local.").font(.caption).foregroundStyle(.secondary)
            }.padding(16)
        }
        .sheet(item: $draft) { draft in ImportEditor(draft: draft, store: store) }
        .safeAreaInset(edge: .bottom) { NoticeBanner(store: store) }
        .confirmationDialog("Delete artwork and its companions?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }), titleVisibility: .visible) {
            Button("Delete Artwork", role: .destructive) { if let charm = pendingDeletion { delete(charm) }; pendingDeletion = nil }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: { Text("This removes the copied artwork and all of its desktop arrangements. Your original image is untouched.") }
    }
    @ViewBuilder private func gallerySection(_ title: String, items: [Charm]) -> some View {
        if !items.isEmpty {
            Text(title).font(.title3.bold()).accessibilityAddTraits(.isHeader)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 16)], spacing: 16) {
                ForEach(items) { charm in card(charm) }
            }
        }
    }
    private func delete(_ charm: Charm) {
        do { try AssetImporter.deleteArtwork(charm.id, from: store) } catch { store.notice = error.localizedDescription }
    }

    private func card(_ charm: Charm) -> some View {
        let instances = store.value.active.filter { $0.sourceID == charm.id }
        return VStack(alignment: .leading, spacing: 12) {
            CharacterPreview(charm: charm).frame(height: 150).frame(maxWidth: .infinity).background(.quinary, in: RoundedRectangle(cornerRadius: 12))
            Text(charm.name).font(.headline).lineLimit(1)
            HStack {
                Text(instances.isEmpty ? (charm.kind == .custom ? "Your artwork" : "Made for Tether") : "\(instances.count) on desktop").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Add") { store.addToDesktop(charm.id) }.disabled(store.value.activeIDs.count >= store.value.maxActive).help("Add \(charm.name) to desktop")
            }
        }.padding(14).background(.background, in: RoundedRectangle(cornerRadius: 16)).overlay { RoundedRectangle(cornerRadius: 16).stroke(.quaternary) }
        .contextMenu {
            Button("Add to Desktop") { store.addToDesktop(charm.id) }
            if let first = instances.first {
                Button("Select on Desktop") { store.value.selectedID = first.id }
                Button("Duplicate on Desktop") { store.duplicate(first.id) }
                Button(instances.count > 1 ? "Remove All \(instances.count) from Desktop" : "Remove from Desktop") { store.perform { prefs in for instance in instances { prefs.removeFromDesktop(instance.id) } } }
            }
            if charm.kind == .custom {
                Divider()
                Button("Delete Artwork and Its Companions", role: .destructive) {
                    if instances.isEmpty { delete(charm) } else { pendingDeletion = charm }
                }
            }
        }
    }
    private func chooseImage() {
        let picker = NSOpenPanel()
        picker.allowedContentTypes = AssetImporter.supportsWebP ? [.png, .webP] : [.png]
        picker.allowsMultipleSelection = false
        picker.message = "Choose artwork you own. Preview and adjust it before adding."
        picker.begin { response in
            MainActor.assumeIsolated {
                guard response == .OK, let url = picker.url else { return }
                let access = url.startAccessingSecurityScopedResource()
                isImporting = true
                Task { @MainActor in
                    defer { isImporting = false; if access { url.stopAccessingSecurityScopedResource() } }
                    do {
                        let data = try await Task.detached(priority: .userInitiated) { try AssetImporter.validate(url) }.value
                        guard let image = NSImage(data: data) else { throw ImportFailure(message: "Artwork could not be previewed.") }
                        draft = ImportDraft(data: data, name: url.deletingPathExtension().lastPathComponent, image: image)
                    } catch { store.notice = error.localizedDescription }
                }
            }
        }
    }
}
private struct ImportEditor: View {
    let draft: ImportDraft
    @ObservedObject var store: PreferencesStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var size: Double = 88
    @State private var attachmentX: Double = 0.5
    @State private var attachmentY: Double = 0.12
    @State private var error: String?
    init(draft: ImportDraft, store: PreferencesStore) { self.draft = draft; self.store = store; _name = State(initialValue: draft.name) }
    private var charm: Charm {
        var charm = Charm(id: "preview", name: name, kind: .custom)
        charm.size = size; charm.attachmentX = attachmentX; charm.attachmentY = attachmentY
        return charm
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Make it yours").font(.title.bold())
            Text("The rope attaches at the selected point. Your original file stays untouched.").foregroundStyle(.secondary)
            CharacterPreview(charm: charm, overrideImage: draft.image).frame(height: 220).background {
                Canvas { context, dimensions in
                    for y in stride(from: 0.0, to: dimensions.height, by: 14) {
                        for x in stride(from: 0.0, to: dimensions.width, by: 14) {
                            context.fill(Path(CGRect(x: x, y: y, width: 14, height: 14)), with: .color((Int(x / 14) + Int(y / 14)).isMultiple(of: 2) ? .gray.opacity(0.15) : .clear))
                        }
                    }
                }
            }.clipShape(RoundedRectangle(cornerRadius: 12))
            TextField("Character name", text: $name)
            Slider(value: $size, in: 44...160) { Text("Size · \(Int(size)) pt") }
            Slider(value: $attachmentX, in: 0...1) { Text("Attachment · horizontal") }
            Slider(value: $attachmentY, in: 0...1) { Text("Attachment · vertical") }
            if let error { Text(error).foregroundStyle(.red).font(.callout) }
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save & Add to Desktop") { save() }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(26).frame(width: 460)
    }
    private func save() {
        do {
            guard store.value.activeIDs.count < store.value.maxActive, store.value.library.count < 100, store.value.charms.count < 64 else { throw LibraryError.limit }
            var imported = try AssetImporter.save(draft.data, name: name)
            imported.size = size; imported.attachmentX = attachmentX; imported.attachmentY = attachmentY
            var next = store.value; next.library.append(imported)
            _ = try next.add(templateID: imported.id)
            store.value = next; dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
