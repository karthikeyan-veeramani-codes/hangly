import AppKit
import ApplicationServices
import TetherCore

/// Isolated diagnostic modes. No user preferences, permissions or OS settings are changed.
@MainActor
final class Diagnostics {
    private let store: PreferencesStore
    private let overlay: OverlayManager
    private let settings: SettingsController
    private let arguments = CommandLine.arguments
    private var stimulus: Timer?
    private var churn: Timer?
    private var folder: URL?
    private var warm: [String: Any] = [:]
    private var cycles = 0
    private var enduranceCycles = 0
    private var enduranceActions: [String: Int] = [:]
    private var errors: [String] = []
    private let cache = AssetCache()
    private var pixelData: Data?
    static func value(_ name: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: name), CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }
    init(store: PreferencesStore, overlay: OverlayManager, settings: SettingsController) {
        self.store = store; self.overlay = overlay; self.settings = settings
        if arguments.contains("--profile-settings") { settings.show() }
        if arguments.contains("--profile-library") { settings.library.show() }
        if arguments.contains("--profile-swing") {
            swing()
            let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.swing() } }
            RunLoop.main.add(timer, forMode: .common); stimulus = timer
        }
        if arguments.contains("--profile-churn") {
            do {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent("Tether-diagnostic-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                folder = directory; AssetImporter.storageOverride = directory
                let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 64, pixelsHigh: 64, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
                if let bitmap, let data = bitmap.bitmapData { data.initialize(repeating: 0, count: bitmap.bytesPerRow * bitmap.pixelsHigh) }
                pixelData = bitmap?.representation(using: .png, properties: [:])
                let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in MainActor.assumeIsolated { self?.churnOnce() } }
                RunLoop.main.add(timer, forMode: .common); churn = timer
            } catch { errors.append(error.localizedDescription) }
        }
        if arguments.contains("--profile-endurance") {
            let timer = Timer(timeInterval: 0.12, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.enduranceOnce() }
            }
            RunLoop.main.add(timer, forMode: .common)
            churn = timer
        }
        if arguments.contains("--desktop-check"), let path = Self.value("--artwork-evidence") {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                do { try await DesktopProbe.run(overlay: overlay, settings: settings, folder: URL(fileURLWithPath: path)) }
                catch { errors.append(error.localizedDescription) }
            }
        }
        let delay = Double(Self.value("--profile-warmup") ?? "10") ?? 10
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay)) { [weak self] in guard let self else { return }; self.warm = self.snapshot() }
        if let path = Self.value("--artwork-evidence") {
            do { try EvidenceExporter.artworkSheets(in: URL(fileURLWithPath: path, isDirectory: true)) } catch { errors.append(error.localizedDescription) }
        }
    }
    private func swing() { for id in store.value.activeIDs { overlay.play(id: id) } }
    private func churnOnce() {
        guard let folder, let pixelData else { return }
        do {
            let input = folder.appendingPathComponent("input.png")
            try pixelData.write(to: input, options: .atomic)
            let charm = try AssetImporter.importImage(input, into: folder)
            var next = store.value; next.library.append(charm)
            _ = try next.add(templateID: charm.id); _ = try next.duplicate(next.selectedID)
            store.value = next; overlay.reconcile()
            _ = cache.image(charm.assetFilename, folder: folder)
            try AssetImporter.deleteArtwork(charm.id, from: store, folder: folder); overlay.reconcile()
            cache.clear(); cycles += 1
            if cycles.isMultiple(of: 10) { settings.library.show(); settings.show(section: .characters); settings.library.window?.orderOut(nil); settings.window?.orderOut(nil) }
        } catch { errors.append(error.localizedDescription) }
    }
    /// Exercises only the isolated diagnostic store. These transitions test
    /// scheduling, retained arrangements and reusable windows without trying
    /// to claim physical desktop-input acceptance.
    private func enduranceOnce() {
        defer { enduranceCycles += 1 }
        do {
            switch enduranceCycles % 8 {
            case 0:
                enduranceActions["showHide", default: 0] += 1
                store.value.visible.toggle()
            case 1:
                enduranceActions["pauseResume", default: 0] += 1
                store.value.paused.toggle()
            case 2:
                enduranceActions["switch", default: 0] += 1
                let ids = store.value.activeIDs
                if ids.count > 1 { store.value.selectedID = ids[(enduranceCycles / 8) % ids.count] }
            case 3:
                enduranceActions["add", default: 0] += 1
                if store.value.activeIDs.count < 6 { _ = try store.value.duplicate(store.value.selectedID) }
            case 4:
                enduranceActions["remove", default: 0] += 1
                // Endurance needs a bounded add/remove loop. Normal UI removal
                // intentionally retains arrangements; this isolated harness
                // instead forgets only the disposable diagnostic instance.
                if store.value.activeIDs.count > 1 { store.perform { $0.deleteInstance($0.selectedID) } }
            case 5:
                enduranceActions["openWindows", default: 0] += 1
                settings.show(); settings.library.show()
            case 6:
                enduranceActions["closeWindows", default: 0] += 1
                settings.window?.orderOut(nil); settings.library.window?.orderOut(nil)
            default:
                enduranceActions["play", default: 0] += 1
                overlay.play()
            }
            overlay.reconcile()
        } catch { errors.append(error.localizedDescription) }
    }
    private func snapshot() -> [String: Any] {
        ["uptime": ProcessInfo.processInfo.systemUptime, "renders": overlay.renderCount, "steps": overlay.totalSteps,
         "frameCallbacks": overlay.frameCallbacks, "maximumFrameGap": overlay.maximumFrameGap,
         "active": overlay.activeSessionCount, "panels": overlay.panelCount, "inputGates": overlay.inputGateCount, "simulationTimer": overlay.isSimulating,
         "pointerTimer": overlay.isSamplingPointer, "dragging": overlay.dragging, "assetDecodes": AssetCache.shared.decodeCount,
         "onBattery": overlay.onBattery, "screenCount": NSScreen.screens.count, "screenCaptureAllowed": CGPreflightScreenCaptureAccess(),
         "accessibilityTrusted": AXIsProcessTrusted(), "reduceMotion": NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
         "increaseContrast": NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast, "voiceOverEnabled": NSWorkspace.shared.isVoiceOverEnabled,
         "scheduling": overlay.schedulingSnapshot]
    }
    func stop() {
        stimulus?.invalidate(); stimulus = nil; churn?.invalidate(); churn = nil
        let final = snapshot()
        if let path = Self.value("--diagnostics-json") {
            do {
                let data = try JSONSerialization.data(withJSONObject: ["warm": warm, "final": final, "churnCycles": cycles, "enduranceCycles": enduranceCycles, "enduranceActions": enduranceActions, "errors": errors], options: [.prettyPrinted, .sortedKeys])
                try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            } catch { NSLog("Tether diagnostics: %@", error.localizedDescription) }
        }
        cache.clear()
        if let folder { try? FileManager.default.removeItem(at: folder) }
        AssetImporter.storageOverride = nil
    }
}
